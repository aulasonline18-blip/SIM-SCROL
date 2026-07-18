import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/classroom/chat_aula_screen.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/classroom_text_scale.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

LabSession _readyAulaSession() {
  setSimActiveLanguage('pt');
  final session = LabSession()
    ..authed = true
    ..authReady = true
    ..credits = 3
    ..selectedLanguageCode = 'pt'
    ..stableLang = 'Portuguese'
    ..freeText = 'Fracoes equivalentes com enunciado longo para testar tela.';
  expect(session.saveObjectiveEntry(), isTrue);
  session.route = '/cyber/aula';
  return session;
}

Future<LabSession> _pumpAula(WidgetTester tester) async {
  final session = _readyAulaSession();
  await session.openAulaRuntime();
  await tester.pumpWidget(MaterialApp(home: ChatAulaScreen(session: session)));
  await tester.pump(const Duration(milliseconds: 250));
  return session;
}

LabSession _snapshotSession({
  String? image,
  ClassroomPhase phase = const ClassroomPhase.reading(),
}) {
  setSimActiveLanguage('pt');
  return LabSession()
    ..authed = true
    ..authReady = true
    ..selectedLanguageCode = 'pt'
    ..stableLang = 'Portuguese'
    ..route = '/cyber/aula'
    ..lessonLocalId = 'lesson-health'
    ..aulaSnapshot = LessonRuntimeSnapshot(
      authReady: true,
      authed: true,
      hasCurriculum: true,
      isDone: false,
      viewModel: const LessonMainViewModel(
        progress: 0.25,
        headerLabel: 'aula_item_of:1/1:aula_layer_1',
        options: [],
        locked: false,
        nextLabel: '',
      ),
      phase: phase,
      history: const [],
      conteudo: const LessonContent(
        explanation: 'Observe o desenho da curva antes de responder.',
        question: 'Qual curva representa o crescimento?',
        options: {
          AnswerLetter.A: 'Linha reta',
          AnswerLetter.B: 'Curva',
          AnswerLetter.C: 'Ponto isolado',
        },
        correctAnswer: AnswerLetter.B,
      ),
      imagem: image,
      itemMarker: 'M1',
      itemText: 'Funções',
    );
}

void main() {
  testWidgets('aula advance pending does not expose retry signal action', (
    tester,
  ) async {
    setSimActiveLanguage('pt');
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'Portuguese'
      ..route = '/cyber/aula'
      ..lessonLocalId = 'lesson-pending'
      ..aulaSnapshot = LessonRuntimeSnapshot(
        authReady: true,
        authed: true,
        hasCurriculum: true,
        isDone: false,
        viewModel: const LessonMainViewModel(
          progress: 0.25,
          headerLabel: 'aula_item_of:1/2:aula_layer_1',
          options: [],
          locked: false,
          nextLabel: '',
        ),
        phase: const ClassroomPhase.advancePending(
          message: 'aula_advance_preparing',
          letter: AnswerLetter.B,
          signal: DecisionSignal.two,
        ),
        history: const [],
        conteudo: const LessonContent(
          explanation: 'Explicacao pronta.',
          question: 'Qual alternativa confirma?',
          options: {
            AnswerLetter.A: 'A',
            AnswerLetter.B: 'B',
            AnswerLetter.C: 'C',
          },
          correctAnswer: AnswerLetter.B,
        ),
        imagem: null,
        itemMarker: 'M1',
        itemText: 'Item de teste',
      );

    await tester.pumpWidget(
      MaterialApp(home: ChatAulaScreen(session: session)),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text(t('aula_try_again_2')), findsNothing);
    expect(find.byType(ChatAulaScreen), findsOneWidget);
  });

  test(
    'submitAulaSignal in advance pending does not resend answer or retry manually',
    () async {
      final session = LabSession()
        ..aulaSnapshot = const LessonRuntimeSnapshot(
          authReady: true,
          authed: true,
          hasCurriculum: true,
          isDone: false,
          viewModel: null,
          phase: ClassroomPhase.advancePending(
            message: 'aula_advance_preparing',
            letter: AnswerLetter.B,
            signal: DecisionSignal.two,
          ),
          history: [],
          conteudo: null,
          imagem: null,
          itemMarker: 'M1',
          itemText: 'Item',
        );

      await session.submitAulaSignal(2);

      expect(
        session.aulaSnapshot?.phase.type,
        ClassroomPhaseType.avancoPendente,
      );
      expect(session.aulaRuntimeError, isNull);
    },
  );

  testWidgets('chat aula font control has five levels and persists choice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAula(tester);

    expect(find.byKey(const Key('chat-font-scale-button')), findsOneWidget);
    expect(find.byKey(const Key('chat-font-scale-level')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('chat-font-scale-button')),
        matching: find.text('2/5'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('chat-font-scale-button')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.descendant(
        of: find.byKey(const Key('chat-font-scale-button')),
        matching: find.text('3/5'),
      ),
      findsOneWidget,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(ClassroomTextScale.prefsKey), 3);
  });

  testWidgets('chat aula accepts A/B/C and opens local signal choices', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final session = _snapshotSession(
      phase: const ClassroomPhase.expanded(AnswerLetter.B),
    );
    await tester.pumpWidget(
      MaterialApp(home: ChatAulaScreen(session: session)),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const Key('chat-answer-card-B')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('2'), findsAtLeastNWidgets(1));
  });

  testWidgets('chat aula shows text before media and survives image update', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final session = _snapshotSession();
    await tester.pumpWidget(
      MaterialApp(home: ChatAulaScreen(session: session)),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.text('Observe o desenho da curva antes de responder.'),
      findsOneWidget,
    );

    session.aulaSnapshot = session.aulaSnapshot!.copyWith(
      imagem: 'data:image/png;base64,AAAA',
    );
    session.notifyListeners();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text(t('aula_image_ready')), findsOneWidget);
    expect(find.byType(ChatAulaScreen), findsOneWidget);
  });

  testWidgets('audio bubble is complementary to the chat classroom', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final session = await _pumpAula(tester);
    expect(find.bySemanticsLabel('Áudio tocando'), findsNothing);

    session.audioEnabled = true;
    session.audioPlaying = true;
    session.notifyListeners();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.bySemanticsLabel('Áudio tocando'), findsOneWidget);
    expect(find.byType(ChatAulaScreen), findsOneWidget);
  });
}
