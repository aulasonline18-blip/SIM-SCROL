import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/classroom/chat_aula_screen.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_widgets.dart';
import 'package:sim_mobile/features/classroom/doubt_input_sheet_widget.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/auxiliary/doubt_input_sheet.dart';
import 'package:sim_mobile/sim/classroom/classroom_text_scale.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_theme.dart';

void main() {
  testWidgets('chat timeline renders messages and answer callbacks', (
    tester,
  ) async {
    AnswerLetter? chosen;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'm1',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.explanation,
                text: 'Explicacao',
              ),
              ChatLessonMessage(
                id: 'm2',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.options,
                options: [
                  ChatLessonOption(
                    letter: AnswerLetter.A,
                    text: 'Alternativa A',
                    selected: false,
                    enabled: true,
                  ),
                  ChatLessonOption(
                    letter: AnswerLetter.B,
                    text: 'Alternativa B',
                    selected: false,
                    enabled: true,
                  ),
                  ChatLessonOption(
                    letter: AnswerLetter.C,
                    text: 'Alternativa C',
                    selected: false,
                    enabled: true,
                  ),
                ],
              ),
            ],
            onChooseAnswer: (letter) => chosen = letter,
            onSignal: (_) {},
            onRetry: () {},
            onNext: () {},
            onOpenDoubt: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('chat-aula-timeline')), findsOneWidget);
    expect(find.text('Explicacao'), findsOneWidget);
    expect(find.text('Alternativa B'), findsOneWidget);

    await tester.tap(find.text('Alternativa B'));
    expect(chosen, AnswerLetter.B);
  });

  testWidgets('chat timeline renders signal callbacks and retry action', (
    tester,
  ) async {
    var signal = 0;
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'signals',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.signals,
                signals: [
                  ChatLessonSignal(
                    value: 1,
                    labelKey: 'aula_sig_certeza',
                    enabled: true,
                  ),
                  ChatLessonSignal(
                    value: 2,
                    labelKey: 'aula_sig_revisar',
                    enabled: true,
                  ),
                  ChatLessonSignal(
                    value: 3,
                    labelKey: 'aula_sig_nao_sei',
                    enabled: true,
                  ),
                ],
              ),
              ChatLessonMessage(
                id: 'error',
                role: ChatLessonMessageRole.system,
                kind: ChatLessonMessageKind.error,
                text: 'Erro controlado',
                actionKey: 'retry',
              ),
            ],
            onChooseAnswer: (_) {},
            onSignal: (value) => signal = value,
            onRetry: () => retries++,
            onNext: () {},
            onOpenDoubt: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('2'));
    expect(signal, 2);

    await tester.tap(find.text('Tentar novamente'));
    expect(retries, 1);
  });

  testWidgets('chat timeline renders feedback advance action', (tester) async {
    var advances = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'feedback',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.feedback,
                text: 'Exato! Você domina este ponto.',
                isCorrect: true,
                actionKey: 'aula_next_item',
              ),
            ],
            onChooseAnswer: (_) {},
            onSignal: (_) {},
            onRetry: () {},
            onNext: () => advances++,
            onOpenDoubt: () {},
          ),
        ),
      ),
    );

    expect(find.text('Exato! Você domina este ponto.'), findsOneWidget);
    await tester.tap(find.text('Próximo tópico'));
    expect(advances, 1);
  });

  testWidgets(
    'chat timeline preserves reader scroll and returns to current lesson',
    (tester) async {
      final key = GlobalKey<_ChatTimelineHarnessState>();
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 320,
              child: _ChatTimelineHarness(
                key: key,
                scrollController: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.scrollUntilVisible(
        find.textContaining('Mensagem 32'),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.textContaining('Mensagem 32'), findsOneWidget);

      key.currentState!.appendMessage('Mensagem nova');
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('Mensagem nova'), findsOneWidget);
      expect(find.byKey(const Key('chat-return-current-button')), findsNothing);
      expect(controller.position.maxScrollExtent, greaterThan(96));

      unawaited(
        controller.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
      await tester.pump(const Duration(milliseconds: 220));

      key.currentState!.appendMessage('Mensagem mais nova');
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        find.byKey(const Key('chat-return-current-button')),
        findsOneWidget,
      );
      expect(find.text('Mensagem mais nova'), findsNothing);

      final buttonRect = tester.getRect(
        find.byKey(const Key('chat-return-current-button')),
      );
      expect(buttonRect.height, greaterThanOrEqualTo(48));

      await tester.tap(find.byKey(const Key('chat-return-current-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chat-return-current-button')), findsNothing);
      expect(find.text('Mensagem mais nova'), findsOneWidget);
    },
  );

  testWidgets('chat timeline renders doubt action callback', (tester) async {
    var opened = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'doubt-action',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.doubtAction,
                text: 'Dúvida',
                actionKey: 'open-doubt',
              ),
            ],
            onChooseAnswer: (_) {},
            onSignal: (_) {},
            onRetry: () {},
            onNext: () {},
            onOpenDoubt: () => opened++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Dúvida'));
    expect(opened, 1);
  });

  testWidgets('chat image bubble renders media states without actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ChatImageBubble(
                message: ChatLessonMessage(
                  id: 'ready',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.image,
                  imageData: 'data:image/svg+xml,%3Csvg%2F%3E',
                  imageStatus: 'ready',
                ),
              ),
              ChatImageBubble(
                message: ChatLessonMessage(
                  id: 'loading',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.image,
                  imageStatus: 'loading',
                ),
              ),
              ChatImageBubble(
                message: ChatLessonMessage(
                  id: 'error',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.image,
                  text: 'Imagem falhou sem bloquear.',
                  imageStatus: 'error',
                ),
              ),
              ChatImageBubble(
                message: ChatLessonMessage(
                  id: 'offer',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.image,
                  imageStatus: 'offer',
                  hasPaidImageOffer: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Imagem da aula pronta'), findsOneWidget);
    expect(find.text('Gerando imagem da aula...'), findsOneWidget);
    expect(find.text('Imagem falhou sem bloquear.'), findsOneWidget);
    expect(
      find.text(
        'Esta parte da aula tem uma imagem criada por inteligência artificial.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('chat classroom keeps question visible while image loads', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'Portuguese'
      ..route = '/cyber/aula'
      ..aulaRuntimeLoading = true
      ..aulaSnapshot = _chatSnapshot(phase: const ClassroomPhase.reading());

    await tester.pumpWidget(
      MaterialApp(home: ChatAulaScreen(session: session)),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.text('Gerando imagem da aula...', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Qual alternativa está correta?', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Alternativa A', skipOffstage: false), findsOneWidget);
  });

  testWidgets(
    'chat classroom preserves previous lesson messages as transcript',
    (tester) async {
      final session = LabSession()
        ..authed = true
        ..authReady = true
        ..selectedLanguageCode = 'pt'
        ..stableLang = 'Portuguese'
        ..lessonLocalId = 'lesson-chat-transcript'
        ..route = '/cyber/aula'
        ..aulaSnapshot = _chatSnapshot(
          phase: const ClassroomPhase.reading(),
          headerLabel: 'aula_item_of:1/4:aula_layer_1',
          explanation: 'Primeira explicacao preservada.',
          question: 'Primeira pergunta preservada?',
        );

      await tester.pumpWidget(
        MaterialApp(home: ChatAulaScreen(session: session)),
      );
      await tester.pump(const Duration(milliseconds: 120));

      var timeline = tester.widget<ChatAulaTimeline>(
        find.byType(ChatAulaTimeline),
      );
      expect(
        timeline.messages.map((message) => message.text),
        containsAll([
          'Primeira explicacao preservada.',
          'Primeira pergunta preservada?',
        ]),
      );

      session.aulaSnapshot = _chatSnapshot(
        phase: const ClassroomPhase.reading(),
        headerLabel: 'aula_item_of:1/4:aula_layer_2',
        explanation: 'Segunda explicacao nova.',
        question: 'Segunda pergunta nova?',
      );
      session.notifyListeners();
      await tester.pump(const Duration(milliseconds: 120));

      timeline = tester.widget<ChatAulaTimeline>(find.byType(ChatAulaTimeline));
      final texts = timeline.messages.map((message) => message.text).toList();
      expect(texts, contains('Primeira explicacao preservada.'));
      expect(texts, contains('Primeira pergunta preservada?'));
      expect(texts, contains('Segunda explicacao nova.'));
      expect(texts, contains('Segunda pergunta nova?'));
      expect(
        timeline.messages
            .where((message) => message.text == 'Primeira pergunta preservada?')
            .length,
        1,
      );
    },
  );

  testWidgets(
    'chat classroom removes transient loading after content arrives',
    (tester) async {
      final session = LabSession()
        ..authed = true
        ..authReady = true
        ..selectedLanguageCode = 'pt'
        ..stableLang = 'Portuguese'
        ..lessonLocalId = 'lesson-chat-loading'
        ..route = '/cyber/aula'
        ..aulaRuntimeLoading = true;

      await tester.pumpWidget(
        MaterialApp(home: ChatAulaScreen(session: session)),
      );
      await tester.pump(const Duration(milliseconds: 120));

      var timeline = tester.widget<ChatAulaTimeline>(
        find.byType(ChatAulaTimeline),
      );
      expect(
        timeline.messages.map((message) => message.id),
        contains('runtime-loading'),
      );

      session
        ..aulaRuntimeLoading = false
        ..aulaSnapshot = _chatSnapshot(phase: const ClassroomPhase.reading());
      session.notifyListeners();
      await tester.pump(const Duration(milliseconds: 120));

      timeline = tester.widget<ChatAulaTimeline>(find.byType(ChatAulaTimeline));
      expect(
        timeline.messages.map((message) => message.id),
        isNot(contains('runtime-loading')),
      );
      expect(
        timeline.messages.map((message) => message.text),
        contains('Explicacao da aula em chat.'),
      );
    },
  );

  testWidgets('chat classroom shows audio bubble and stops audio on tap', (
    tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'Portuguese'
      ..route = '/cyber/aula'
      ..audioEnabled = true
      ..audioPlaying = true
      ..aulaSnapshot = _chatSnapshot(phase: const ClassroomPhase.reading());

    await tester.pumpWidget(
      MaterialApp(home: ChatAulaScreen(session: session)),
    );
    await tester.pump(const Duration(milliseconds: 120));

    final bubble = find.bySemanticsLabel('Áudio tocando');
    expect(bubble, findsOneWidget);
    await tester.tap(bubble);
    await tester.pump();
    expect(session.audioPlaying, isFalse);
  });

  testWidgets(
    'chat classroom preserves menu credits dark mode and font scale',
    (tester) async {
      SharedPreferences.setMockInitialValues({ClassroomTextScale.prefsKey: 4});
      await tester.binding.setSurfaceSize(const Size(390, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var darkToggles = 0;
      final session = LabSession()
        ..authed = true
        ..authReady = true
        ..selectedLanguageCode = 'pt'
        ..stableLang = 'Portuguese'
        ..route = '/cyber/aula'
        ..credits = 3
        ..aulaSnapshot = _chatSnapshot(phase: const ClassroomPhase.reading());

      await tester.pumpWidget(
        MaterialApp(
          home: SimThemeScope(
            darkMode: false,
            onToggleDarkMode: () => darkToggles++,
            child: ChatAulaScreen(session: session),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.bySemanticsLabel('Abrir menu da aula'), findsOneWidget);
      expect(find.bySemanticsLabel('Modo escuro'), findsOneWidget);
      expect(find.byKey(const Key('chat-font-scale-button')), findsOneWidget);
      expect(find.text('4/5'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat-font-scale-button')));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('5/5'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(ClassroomTextScale.prefsKey), 5);

      await tester.tap(find.bySemanticsLabel('Modo escuro'));
      await tester.pump();
      expect(darkToggles, 1);

      await tester.tap(find.bySemanticsLabel('Abrir menu da aula'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
      expect(find.text('Recarregar créditos'), findsOneWidget);

      await tester.tap(find.text('Recarregar créditos'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 120));
      expect(session.route, '/creditos?returnTo=/cyber/aula');
      expect(session.returnTo, '/cyber/aula');
      await tester.pump(const Duration(milliseconds: 2300));
    },
  );

  testWidgets('shared doubt sheet preserves text and photo menu', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    DoubtInputDraft? submitted;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DoubtInputSheet(
            controller: controller,
            busy: false,
            onSubmit: (draft) => submitted = draft,
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.text('Enviar dúvida'), findsWidgets);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('Escolher imagem'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Nao entendi.');
    await tester.tap(find.text('Enviar dúvida').last);
    await tester.pump();

    expect(submitted?.cleanText, 'Nao entendi.');
    expect(submitted?.image, isNull);
  });

  testWidgets('chat classroom covers normal flow through feedback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'Portuguese'
      ..route = '/cyber/aula'
      ..aulaSnapshot = _chatSnapshot(
        phase: const ClassroomPhase.reading(),
        imagem: _svgDataUrl(),
      );

    await tester.pumpWidget(
      MaterialApp(home: ChatAulaScreen(session: session)),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);

    expect(find.byKey(const Key('chat-aula-timeline')), findsOneWidget);
    final timeline = tester.widget<ChatAulaTimeline>(
      find.byType(ChatAulaTimeline),
    );
    expect(
      timeline.messages.map((message) => message.kind),
      containsAllInOrder([
        ChatLessonMessageKind.explanation,
        ChatLessonMessageKind.image,
        ChatLessonMessageKind.question,
        ChatLessonMessageKind.options,
      ]),
    );
    expect(
      find.byType(ChatAulaMessageBubble, skipOffstage: false),
      findsWidgets,
    );
    expect(
      find.text('Explicacao da aula em chat.', skipOffstage: false),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Alternativa B'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Qual alternativa está correta?'), findsOneWidget);
    final optionB = find.text('Alternativa B');
    expect(optionB, findsOneWidget);

    await tester.tap(optionB);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('B', skipOffstage: false), findsWidgets);
    final signalPrompt = find.text('Como voce se sente?', skipOffstage: false);
    expect(signalPrompt, findsOneWidget);

    final signal2 = find.text('2', skipOffstage: false);
    await tester.ensureVisible(signal2);
    await tester.tap(signal2);
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.text('Exato! Você domina este ponto.', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Próximo', skipOffstage: false), findsOneWidget);
  });

  testWidgets(
    'chat classroom keeps current review room and returns to lesson',
    (tester) async {
      final session = LabSession()
        ..authed = true
        ..authReady = true
        ..selectedLanguageCode = 'pt'
        ..stableLang = 'Portuguese'
        ..route = '/cyber/aula'
        ..aulaSnapshot = _chatSnapshot(phase: const ClassroomPhase.reading());
      session.setReviewRoom(
        const ReviewRoomView(
          status: ReviewRoomStatus.choose,
          count: 5,
          queue: ['M1'],
          idx: 0,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: ChatAulaScreen(session: session)),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('Quantas questões de revisão?'), findsOneWidget);
      expect(find.byKey(const Key('chat-aula-timeline')), findsNothing);
      expect(session.aulaSnapshot?.itemMarker, 'M1');

      await tester.tap(find.text('Voltar'));
      await tester.pump(const Duration(milliseconds: 120));

      expect(session.reviewRoom, isNull);
      expect(session.aulaSnapshot?.itemMarker, 'M1');
      expect(find.byKey(const Key('chat-aula-timeline')), findsOneWidget);
      expect(
        find.text('Qual alternativa está correta?', skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'chat classroom keeps current recovery room and returns to lesson',
    (tester) async {
      final session = LabSession()
        ..authed = true
        ..authReady = true
        ..selectedLanguageCode = 'pt'
        ..stableLang = 'Portuguese'
        ..route = '/cyber/aula'
        ..aulaSnapshot = _chatSnapshot(phase: const ClassroomPhase.reading());
      session.setRecoveryRoom(
        const RecoveryRoomView(
          status: RecoveryRoomStatus.failed,
          queue: ['M1'],
          idx: 0,
          errMsg: 'Falha controlada da recuperação',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: ChatAulaScreen(session: session)),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('Falha controlada da recuperação'), findsOneWidget);
      expect(find.byKey(const Key('chat-aula-timeline')), findsNothing);
      expect(session.aulaSnapshot?.itemMarker, 'M1');

      await tester.tap(find.text('Concluir'));
      await tester.pump(const Duration(milliseconds: 120));

      expect(session.recoveryRoom, isNull);
      expect(session.aulaSnapshot?.itemMarker, 'M1');
      expect(find.byKey(const Key('chat-aula-timeline')), findsOneWidget);
      expect(
        find.text('Qual alternativa está correta?', skipOffstage: false),
        findsOneWidget,
      );
    },
  );
}

LessonRuntimeSnapshot _chatSnapshot({
  required ClassroomPhase phase,
  String? imagem,
  String headerLabel = 'aula_item_of:1/4:aula_layer_1',
  String explanation = 'Explicacao da aula em chat.',
  String question = 'Qual alternativa está correta?',
}) {
  return LessonRuntimeSnapshot(
    authReady: true,
    authed: true,
    hasCurriculum: true,
    isDone: false,
    viewModel: LessonMainViewModel(
      progress: 25,
      headerLabel: headerLabel,
      options: const [],
      locked:
          phase.type == ClassroomPhaseType.processando ||
          phase.type == ClassroomPhaseType.concluido ||
          phase.type == ClassroomPhaseType.carregando,
      nextLabel: phase.type == ClassroomPhaseType.concluido ? 'aula_next' : '',
    ),
    phase: phase,
    history: const [],
    conteudo: LessonContent(
      explanation: explanation,
      question: question,
      options: const {
        AnswerLetter.A: 'Alternativa A',
        AnswerLetter.B: 'Alternativa B',
        AnswerLetter.C: 'Alternativa C',
      },
      correctAnswer: AnswerLetter.B,
    ),
    imagem: imagem,
    itemMarker: 'M1',
    itemText: 'Item de teste',
  );
}

String _svgDataUrl() {
  final svg = Uri.encodeComponent(
    '<svg viewBox="0 0 120 80"><rect width="120" height="80" fill="#fff"/>'
    '<circle cx="60" cy="40" r="20" fill="#111827"/></svg>',
  );
  return 'data:image/svg+xml;utf8,$svg';
}

class _ChatTimelineHarness extends StatefulWidget {
  const _ChatTimelineHarness({required this.scrollController, super.key});

  final ScrollController scrollController;

  @override
  State<_ChatTimelineHarness> createState() => _ChatTimelineHarnessState();
}

class _ChatTimelineHarnessState extends State<_ChatTimelineHarness> {
  late final List<ChatLessonMessage> _messages = [
    for (var i = 1; i <= 32; i++)
      ChatLessonMessage(
        id: 'msg-$i',
        role: ChatLessonMessageRole.sim,
        kind: ChatLessonMessageKind.explanation,
        text: 'Mensagem $i\nLinha de apoio para simular aula longa.',
      ),
  ];

  var _nextId = 33;

  void appendMessage(String text) {
    setState(() {
      _messages.add(
        ChatLessonMessage(
          id: 'msg-${_nextId++}',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.feedback,
          text: text,
          actionKey: 'aula_next',
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChatAulaTimeline(
      messages: _messages,
      scrollController: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      onChooseAnswer: (_) {},
      onSignal: (_) {},
      onRetry: () {},
      onNext: () {},
      onOpenDoubt: () {},
    );
  }
}
