import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/onboarding/preparation_and_placement.dart';
import 'package:sim_mobile/features/classroom/chat_aula_timeline_builder.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/auxiliary/doubt_input_sheet.dart';
import 'package:sim_mobile/sim/config/sim_environment.dart';
import 'package:sim_mobile/sim/experience/student_experience_types.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_ai_clients.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

class CountingAulaLabSession extends LabSession {
  CountingAulaLabSession({
    super.experiencePreparerOverride,
  });

  int aulaOpenCalls = 0;

  @override
  Future<void> openAulaRuntime() async {
    aulaOpenCalls += 1;
  }
}

void main() {
  test('default API URL points to the official Scroll API host', () {
    expect(SimEnvironment.apiBaseUrl, 'http://167.179.109.137:3000');
    expect(SimEnvironment.assertProductionSafe, returnsNormally);
  });

  test(
    'curriculo tenta preparar aula sem redirecionar para login antes do T00',
    () async {
      var called = false;
      final session =
          LabSession(
              experiencePreparerOverride: (args) async {
                called = true;
                args.onStage?.call(StudentExperienceRouteStage.curriculum);
                args.onStage?.call(StudentExperienceRouteStage.lesson);
                args.onStage?.call(StudentExperienceRouteStage.ready);
                return const StudentExperienceResult(
                  destination: '/cyber/aula',
                  curriculum: StudentCurriculum(
                    topic: 'Matematica',
                    totalItems: 1,
                    generatedAt: null,
                    provisional: false,
                    items: [CurriculumItem(marker: 'M1', text: 'Frações')],
                  ),
                  startMarker: 'M1',
                  startItemIndex: 0,
                );
              },
            )
            ..selectedLanguageCode = 'pt'
            ..stableLang = 'pt-BR'
            ..freeText = 'Quero aprender frações começando do zero.';

      expect(session.saveObjectiveEntry(), isTrue);
      expect(session.route, '/cyber/curriculo');
      expect(session.authed, isFalse);
      expect(session.authReady, isFalse);

      await session.launchExperience();

      expect(called, isTrue);
      expect(session.entryStatus, 'primeira_aula_pronta');
      expect(session.entryError, isNull);
      expect(session.route, '/cyber/aula');
    },
  );

  test(
    'preparacao real sem sessao nao chama servidor protegido e manda para login',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = LabSession(prefs: prefs)
        ..selectedLanguageCode = 'pt'
        ..stableLang = 'pt-BR'
        ..freeText = 'Quero aprender frações começando do zero.';

      expect(session.saveObjectiveEntry(), isTrue);
      await session.launchExperience();

      expect(session.route, '/login');
      expect(session.returnTo, '/cyber/curriculo');
      expect(session.entryStatus, 'erro');
      expect(session.entryError, contains('Entre novamente'));
    },
  );

  test(
    'erro de auth vindo do preparo fica no curriculo com retry do proprio app',
    () async {
      var attempts = 0;
      final session =
          LabSession(
              experiencePreparerOverride: (_) async {
                attempts += 1;
                throw const StudentExperienceEngineException(
                  StudentExperienceErrorInfo(
                    kind: StudentExperienceErrorKind.auth,
                    message:
                        'HTTP 401: {"error":"Unauthorized","reason":"invalid token"}',
                  ),
                );
              },
            )
            ..selectedLanguageCode = 'pt'
            ..stableLang = 'pt-BR'
            ..freeText = 'Quero aprender frações começando do zero.'
            ..authReady = true
            ..authed = true;

      expect(session.saveObjectiveEntry(), isTrue);
      await session.launchExperience();

      expect(attempts, 2);
      expect(session.route, '/cyber/curriculo');
      expect(session.entryStatus, 'erro');
      expect(session.entryError, contains('HTTP 401'));
      expect(session.returnTo, '/');
      expect(session.authed, isTrue);
    },
  );

  test(
    'onboarding renova auth logicamente e repete T00 uma vez quando servidor devolve 401',
    () async {
      var attempts = 0;
      final session =
          LabSession(
              experiencePreparerOverride: (args) async {
                attempts += 1;
                if (attempts == 1) {
                  throw const StudentExperienceEngineException(
                    StudentExperienceErrorInfo(
                      kind: StudentExperienceErrorKind.auth,
                      message:
                          'HTTP 401: {"error":"Unauthorized","reason":"invalid token"}',
                    ),
                  );
                }
                args.onStage?.call(StudentExperienceRouteStage.curriculum);
                args.onStage?.call(StudentExperienceRouteStage.lesson);
                args.onStage?.call(StudentExperienceRouteStage.ready);
                return const StudentExperienceResult(
                  destination: '/cyber/aula',
                  curriculum: StudentCurriculum(
                    topic: 'Matematica',
                    totalItems: 1,
                    generatedAt: null,
                    provisional: false,
                    items: [CurriculumItem(marker: 'M1', text: 'Frações')],
                  ),
                  startMarker: 'M1',
                  startItemIndex: 0,
                );
              },
            )
            ..selectedLanguageCode = 'pt'
            ..stableLang = 'pt-BR'
            ..freeText = 'Quero aprender frações começando do zero.'
            ..authReady = true
            ..authed = true;

      expect(session.saveObjectiveEntry(), isTrue);
      await session.launchExperience();

      expect(attempts, 2);
      expect(session.entryStatus, 'primeira_aula_pronta');
      expect(session.entryError, isNull);
      expect(session.route, '/cyber/aula');
    },
  );

  test('escolha de nivelamento abre warmup antes da aula oficial', () async {
    final session = LabSession()
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'pt-BR'
      ..freeText = 'Quero aprender deslocamento em física começando do zero.';

    expect(session.saveObjectiveEntry(), isTrue);
    session.entryStatus = 't02_running';

    session.skipPlacement();

    expect(session.route, '/cyber/warmup');
    expect(session.entryStatus, 't02_running');

    session.chooseWarmupAnswer('A');
    await session.continueFromWarmupToAula();

    expect(session.route, '/cyber/warmup');
    expect(session.warmupWaitingForOfficialLesson, isTrue);
  });

  test(
    'entrada coordena warmup e aula oficial com uma navegacao unica',
    () async {
      final officialReady = Completer<void>();
      final session =
          CountingAulaLabSession(
              experiencePreparerOverride: (args) async {
                args.onStage?.call(StudentExperienceRouteStage.curriculum);
                args.onStage?.call(StudentExperienceRouteStage.lesson);
                await officialReady.future;
                args.onStage?.call(StudentExperienceRouteStage.ready);
                return const StudentExperienceResult(
                  destination: '/cyber/aula',
                  curriculum: StudentCurriculum(
                    topic: 'Fisica',
                    totalItems: 1,
                    generatedAt: null,
                    provisional: false,
                    items: [CurriculumItem(marker: 'M1', text: 'Força')],
                  ),
                  startMarker: 'M1',
                  startItemIndex: 0,
                );
              },
            )
            ..selectedLanguageCode = 'pt'
            ..stableLang = 'pt-BR'
            ..freeText = 'Quero aprender deslocamento em física começando do zero.';

      expect(session.saveObjectiveEntry(), isTrue);
      final launch = session.launchExperience();
      await Future<void>.delayed(Duration.zero);

      session.openWarmupBridge();
      await session.continueFromWarmupToAula();
      expect(session.route, '/cyber/warmup');
      expect(session.warmupWaitingForOfficialLesson, isTrue);
      expect(session.aulaOpenCalls, 0);

      officialReady.complete();
      await launch;
      await Future<void>.delayed(Duration.zero);

      expect(session.route, '/cyber/aula');
      expect(session.warmupWaitingForOfficialLesson, isFalse);
      expect(session.aulaOpenCalls, 1);

      await session.continueFromWarmupToAula();
      expect(session.aulaOpenCalls, 1);
    },
  );

  test(
    'warmup T02 pronto abre ponte diretamente enquanto aula oficial prepara',
    () async {
      final session = LabSession()
        ..selectedLanguageCode = 'pt'
        ..stableLang = 'pt-BR'
        ..freeText = 'Quero aprender deslocamento em física começando do zero.'
        ..authReady = true
        ..authed = true;

      session.warmupLesson = const SimWarmupLesson(
        explanation: 'Welcome bridge.',
        question: 'What should happen first?',
        options: {'A': 'Begin gently', 'B': 'Grade now', 'C': 'Block'},
        correctAnswer: 'A',
      );
      session.route = '/cyber/curriculo';

      session.openWarmupBridge();

      expect(session.route, '/cyber/warmup');
      expect(session.warmupLesson?.toJson()['officialCurriculum'], isFalse);
      expect(session.warmupLesson?.toJson()['countsForMastery'], isFalse);
    },
  );

  testWidgets('warmup bridge renders welcome T02 microlesson safely', (
    tester,
  ) async {
    final session = LabSession()
      ..warmupLesson = const SimWarmupLesson(
        explanation:
            'Hello, Joel. While I prepare your full lesson, let us begin with a simple first contact.',
        question: 'Which first step fits Kiribati conversation?',
        options: {
          'A': 'Build a useful greeting',
          'B': 'Take a final exam now',
          'C': 'Block the lesson',
        },
        correctAnswer: 'A',
        whyCorrect:
            'Good start. A useful greeting is a gentle bridge into real conversation.',
        whyWrong: {'B': 'No exam is needed here.'},
      )
      ..route = '/cyber/warmup';

    await tester.pumpWidget(
      MaterialApp(home: WarmupBridgeScreen(session: session)),
    );

    expect(find.text('Boas-vindas enquanto preparo sua aula'), findsOneWidget);
    expect(find.textContaining('Hello, Joel'), findsOneWidget);
    expect(
      find.text('Which first step fits Kiribati conversation?'),
      findsOneWidget,
    );
    expect(find.text('Build a useful greeting'), findsOneWidget);
    expect(session.warmupLesson?.toJson()['officialCurriculum'], isFalse);
    expect(session.warmupLesson?.toJson()['countsForMastery'], isFalse);
    expect(session.warmupLesson?.toJson()['mode'], 'WARMUP_WELCOME_BRIDGE');

    await tester.tap(find.text('Build a useful greeting'));
    await tester.pumpWidget(
      MaterialApp(home: WarmupBridgeScreen(session: session)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Good start. A useful greeting'),
      findsOneWidget,
    );
    expect(find.text('Continuar para a aula'), findsOneWidget);
  });

  testWidgets(
    'warmup bridge shows controlled loading while official lesson prepares',
    (tester) async {
      final session = LabSession()
        ..route = '/cyber/warmup'
        ..warmupLoading = true;

      await tester.pumpWidget(
        MaterialApp(home: WarmupBridgeScreen(session: session)),
      );

      expect(
        find.text('Preparando uma ponte de boas-vindas...'),
        findsOneWidget,
      );
      expect(
        find.text('A aula oficial continua sendo preparada.'),
        findsOneWidget,
      );
      expect(find.text('Questão de aquecimento'), findsNothing);
    },
  );

  testWidgets(
    'erro do onboarding respeita idioma portugues nos botoes de retry',
    (tester) async {
      setSimActiveLanguage('pt');
      final session = LabSession()
        ..authReady = true
        ..authed = true
        ..selectedLanguageCode = 'pt'
        ..stableLang = 'pt-BR'
        ..entryStatus = 'erro'
        ..entryError =
            'O servidor recusou a preparacao da aula. Detalhe tecnico: HTTP 401 invalid token';

      await tester.pumpWidget(
        MaterialApp(home: PhaseBoundaryScreen(session: session)),
      );

      expect(find.text('Não consegui preparar agora.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('Trocar objetivo'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    },
  );

  testWidgets(
    'curriculo espera authReady/authed antes de chamar T00',
    (tester) async {
      var called = false;
      final session =
          LabSession(
              experiencePreparerOverride: (args) async {
                called = true;
                args.onStage?.call(StudentExperienceRouteStage.curriculum);
                args.onStage?.call(StudentExperienceRouteStage.lesson);
                args.onStage?.call(StudentExperienceRouteStage.ready);
                return const StudentExperienceResult(
                  destination: '/cyber/aula',
                  curriculum: StudentCurriculum(
                    topic: 'Matematica',
                    totalItems: 1,
                    generatedAt: null,
                    provisional: false,
                    items: [CurriculumItem(marker: 'M1', text: 'Frações')],
                  ),
                  startMarker: 'M1',
                  startItemIndex: 0,
                );
              },
            )
            ..selectedLanguageCode = 'pt'
            ..stableLang = 'pt-BR'
            ..freeText = 'Quero aprender frações começando do zero.';

      expect(session.saveObjectiveEntry(), isTrue);

      await tester.pumpWidget(
        MaterialApp(home: PhaseBoundaryScreen(session: session)),
      );
      await tester.pump();
      expect(called, isFalse);

      session
        ..authReady = true
        ..authed = true;
      session.setFreeText(session.freeText);

      await tester.pump();
      await tester.pump();

      expect(called, isTrue);
      expect(session.route, '/cyber/aula');
    },
  );

  test('erros técnicos de auth e aula sem id são saneados no chat', () {
    final messages = buildChatLessonMessages(
      const ChatLessonTimelineInput(
        snapshot: null,
        runtimeError:
            'SimExternalAiException HTTP 401: {"error":"Unauthorized","reason":"invalid token"}',
      ),
    );
    expect(
      messages.single.text,
      'Sua sessão expirou. Entre novamente para continuar a aula.',
    );

    final noLesson = buildChatLessonMessages(
      const ChatLessonTimelineInput(
        snapshot: null,
        runtimeError:
            'Bad state: lessonLocalId ausente para abrir organismo SIM.',
      ),
    );
    expect(noLesson.single.text, 'Escolha um objetivo para abrir a aula.');
  });

  test(
    'startNewLessonFromDrawer clears stale aula media and audio UI state',
    () {
      final session = LabSession()
        ..lessonLocalId = 'lesson-old'
        ..imageStatus = 'error'
        ..imageError = 'erro anterior'
        ..audioPlaying = true
        ..audioLoading = true
        ..aulaSnapshot = const LessonRuntimeSnapshot(
          authReady: true,
          authed: true,
          hasCurriculum: true,
          isDone: false,
          viewModel: LessonMainViewModel(
            progress: 0,
            headerLabel: 'aula_item_of:1/1:aula_layer_1',
            options: [],
            locked: false,
            nextLabel: '',
          ),
          phase: ClassroomPhase.reading(),
          history: [],
          conteudo: LessonContent(
            explanation: 'Explicacao',
            question: 'Pergunta?',
            options: {
              AnswerLetter.A: 'A',
              AnswerLetter.B: 'B',
              AnswerLetter.C: 'C',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: 'data:image/png;base64,AAAA',
          itemMarker: 'M1',
          itemText: 'Item antigo',
        );

      session.startNewLessonFromDrawer();

      expect(session.lessonLocalId, isNull);
      expect(session.aulaSnapshot, isNull);
      expect(session.imageStatus, 'idle');
      expect(session.imageError, isNull);
      expect(session.audioPlaying, isFalse);
      expect(session.audioLoading, isFalse);
      expect(session.route, '/cyber/objeto');
    },
  );

  test('submitDoubt ignores duplicate submission while processing', () async {
    final session = LabSession()
      ..setDoubt(
        const DoubtState(status: DoubtStatus.processing, progress: 15),
      );

    await session.submitDoubt(const DoubtInputDraft(text: 'Nao entendi.'));

    expect(session.doubt.status, DoubtStatus.processing);
    expect(session.doubt.progress, 15);
  });

  test('LessonRuntimeSnapshot.copyWith can override and clear every field', () {
    final original = const LessonRuntimeSnapshot(
      authReady: true,
      authed: true,
      hasCurriculum: true,
      isDone: false,
      viewModel: LessonMainViewModel(
        progress: 20,
        headerLabel: 'aula_item_of:1/5:aula_layer_1',
        options: [],
        locked: false,
        nextLabel: '',
      ),
      phase: ClassroomPhase.reading(),
      history: [],
      conteudo: LessonContent(
        explanation: 'Explicacao',
        question: 'Pergunta?',
        options: {
          AnswerLetter.A: 'A',
          AnswerLetter.B: 'B',
          AnswerLetter.C: 'C',
        },
        correctAnswer: AnswerLetter.A,
      ),
      imagem: 'data:image/png;base64,AAAA',
      itemMarker: 'M1',
      itemText: 'Item 1',
    );

    final updated = original.copyWith(
      authReady: false,
      authed: false,
      hasCurriculum: false,
      isDone: true,
      viewModel: null,
      phase: const ClassroomPhase.loading(),
      history: const [
        QuestionHistoryEntry(
          id: 'q1',
          text: 'Q?',
          options: [],
          chosenOptionId: AnswerLetter.B,
          correct: false,
        ),
      ],
      conteudo: null,
      imagem: null,
      itemMarker: null,
      itemText: null,
    );

    expect(updated.authReady, isFalse);
    expect(updated.authed, isFalse);
    expect(updated.hasCurriculum, isFalse);
    expect(updated.isDone, isTrue);
    expect(updated.viewModel, isNull);
    expect(updated.phase.type, ClassroomPhaseType.carregando);
    expect(updated.history, hasLength(1));
    expect(updated.conteudo, isNull);
    expect(updated.imagem, isNull);
    expect(updated.itemMarker, isNull);
    expect(updated.itemText, isNull);
  });
}
