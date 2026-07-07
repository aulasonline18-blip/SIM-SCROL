import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/classroom/aula_widgets.dart';
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
import 'package:sim_mobile/sim/ui/sim_i18n.dart';
import 'package:sim_mobile/sim/ui/sim_theme.dart';

Finder _textAny(List<String> labels) {
  for (final label in labels) {
    final finder = find.text(label);
    if (finder.evaluate().isNotEmpty) return finder;
  }
  return find.text(labels.first);
}

void main() {
  setUp(() => setSimActiveLanguage('pt'));

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

  testWidgets('chat timeline renders a clear empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [],
            onChooseAnswer: (_) {},
            onSignal: (_) {},
            onRetry: () {},
            onNext: () {},
            onOpenDoubt: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('chat-empty-state')), findsOneWidget);
    expect(find.text(t('aula_empty_conversation')), findsOneWidget);
  });

  testWidgets('chat timeline respects reduce motion', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: ChatAulaTimeline(
              messages: const [
                ChatLessonMessage(
                  id: 'reduced-motion',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.explanation,
                  text: 'Sem animacao obrigatoria.',
                ),
                ChatLessonMessage(
                  id: 'reduced-motion-feedback',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.feedback,
                  text: 'Feedback sem depender de animacao.',
                  isCorrect: true,
                  actionKey: 'aula_next_item',
                ),
              ],
              onChooseAnswer: (_) {},
              onSignal: (_) {},
              onRetry: () {},
              onNext: () {},
              onOpenDoubt: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sem animacao obrigatoria.'), findsOneWidget);
    expect(find.text('Feedback sem depender de animacao.'), findsOneWidget);
    expect(find.byKey(const Key('chat-feedback-next-button')), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });

  testWidgets('chat timeline keeps mature width on tablet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'tablet-message',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.explanation,
                text: 'Mensagem em tablet com largura controlada.',
              ),
            ],
            onChooseAnswer: (_) {},
            onSignal: (_) {},
            onRetry: () {},
            onNext: () {},
            onOpenDoubt: () {},
          ),
        ),
      ),
    );

    final bubbleRect = tester.getRect(find.byType(ChatAulaMessageBubble));
    expect(bubbleRect.width, lessThanOrEqualTo(640));
    expect(bubbleRect.left, greaterThan(200));
  });

  testWidgets('chat timeline constrains reading width on medium and wide', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final entry in const [
      (size: Size(700, 900), maxWidth: 620.0),
      (size: Size(1024, 768), maxWidth: 620.0),
      (size: Size(1440, 900), maxWidth: 680.0),
    ]) {
      await tester.binding.setSurfaceSize(entry.size);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatAulaTimeline(
              messages: const [
                ChatLessonMessage(
                  id: 'wide-readable-message',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.explanation,
                  text:
                      'Mensagem longa para validar leitura madura em tablet e telas largas.',
                ),
              ],
              onChooseAnswer: (_) {},
              onSignal: (_) {},
              onRetry: () {},
              onNext: () {},
              onOpenDoubt: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      final bubbleRect = tester.getRect(find.byType(ChatAulaMessageBubble));
      expect(bubbleRect.width, lessThanOrEqualTo(entry.maxWidth));
      expect(
        (bubbleRect.left - ((entry.size.width - bubbleRect.width) / 2)).abs(),
        lessThan(1),
      );
    }
  });

  testWidgets('chat options open signals inline under selected answer', (
    tester,
  ) async {
    var signal = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'options',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.options,
                selectedAnswer: AnswerLetter.B,
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
                    selected: true,
                    enabled: true,
                  ),
                  ChatLessonOption(
                    letter: AnswerLetter.C,
                    text: 'Alternativa C',
                    selected: false,
                    enabled: true,
                  ),
                ],
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
            ],
            onChooseAnswer: (_) {},
            onSignal: (value) => signal = value,
            onRetry: () {},
            onNext: () {},
            onOpenDoubt: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('inline-signal-choices')), findsOneWidget);
    expect(find.text('Como voce se sente?'), findsNothing);
    expect(
      find.text(t('aula_sig_certeza'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(t('aula_sig_revisar'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(t('aula_sig_nao_sei'), skipOffstage: false),
      findsOneWidget,
    );

    await tester.tap(find.text('2'));
    expect(signal, 2);
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

    final retryFinder = find.text(t('aula_try_again_2'));
    expect(retryFinder, findsOneWidget);
    await tester.tap(retryFinder);
    expect(retries, 1);
  });

  testWidgets(
    'chat messages expose delivery status and live region semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatAulaTimeline(
              messages: const [
                ChatLessonMessage(
                  id: 'processing',
                  role: ChatLessonMessageRole.system,
                  kind: ChatLessonMessageKind.processing,
                  text: 'Preparando resposta',
                  deliveryStatus: ChatLessonDeliveryStatus.processing,
                  timestampLabel: '09:05',
                ),
              ],
              onChooseAnswer: (_) {},
              onSignal: (_) {},
              onRetry: () {},
              onNext: () {},
              onOpenDoubt: () {},
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(ChatAulaMessageBubble));
      expect(node.label, contains('Mensagem do sistema'));
      expect(node.label, contains('09:05'));
      expect(node.label, contains('Status: processando'));
      expect(node.label, contains('Preparando resposta'));
      expect(node.flagsCollection.isLiveRegion, isTrue);
      semantics.dispose();
    },
  );

  testWidgets('chat timeline renders feedback with doubt and advance actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var openedDoubt = false;
    var advanced = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'feedback',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.feedback,
                text: '✅ Exato. Você domina este ponto.',
                isCorrect: true,
                actionKey: 'aula_next_item',
              ),
            ],
            onChooseAnswer: (_) {},
            onSignal: (_) {},
            onRetry: () {},
            onNext: () => advanced = true,
            onOpenDoubt: () => openedDoubt = true,
          ),
        ),
      ),
    );

    expect(find.text('✅ Exato. Você domina este ponto.'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
    expect(find.text('Tenho dúvida sobre essa questão'), findsOneWidget);
    final nextItem = _textAny([
      'Próximo item',
      'Next topic',
      'Sujet suivant',
      'Siguiente tema',
    ]);
    expect(nextItem, findsOneWidget);
    final nextSemantics = tester.getSemantics(
      find.byKey(const Key('chat-feedback-next-button')),
    );
    expect(nextSemantics.flagsCollection.isButton, isTrue);
    expect(
      nextSemantics.flagsCollection.isEnabled.toString(),
      contains('isTrue'),
    );

    await tester.tap(find.text('Tenho dúvida sobre essa questão'));
    expect(openedDoubt, isTrue);

    await tester.tap(nextItem);
    expect(advanced, isTrue);
    semantics.dispose();
  });

  testWidgets('chat feedback actions become dead when feedback is archived', (
    tester,
  ) async {
    var openedDoubt = false;
    var advanced = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'feedback-read',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.feedback,
                text: 'Feedback antigo.',
                isCorrect: true,
                actionKey: 'aula_next_item',
                deliveryStatus: ChatLessonDeliveryStatus.read,
              ),
            ],
            onChooseAnswer: (_) {},
            onSignal: (_) {},
            onRetry: () {},
            onNext: () => advanced = true,
            onOpenDoubt: () => openedDoubt = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('chat-feedback-doubt-button')));
    await tester.tap(find.byKey(const Key('chat-feedback-next-button')));

    expect(openedDoubt, isFalse);
    expect(advanced, isFalse);
  });

  testWidgets('chat feedback pending actions block duplicate taps', (
    tester,
  ) async {
    var openedDoubt = 0;
    var advanced = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            pendingActionKeys: const {'next', 'doubt'},
            messages: const [
              ChatLessonMessage(
                id: 'feedback-pending',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.feedback,
                text: 'Feedback pronto.',
                isCorrect: true,
                actionKey: 'aula_next_item',
              ),
            ],
            onChooseAnswer: (_) {},
            onSignal: (_) {},
            onRetry: () {},
            onNext: () => advanced++,
            onOpenDoubt: () => openedDoubt++,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.tap(find.byKey(const Key('chat-feedback-doubt-button')));
    await tester.tap(find.byKey(const Key('chat-feedback-next-button')));

    expect(openedDoubt, 0);
    expect(advanced, 0);
  });

  testWidgets('chat retry pending action is visible and inactive', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            pendingActionKeys: const {'retry'},
            messages: const [
              ChatLessonMessage(
                id: 'engine-error',
                role: ChatLessonMessageRole.system,
                kind: ChatLessonMessageKind.error,
                text: 'Erro controlado',
                actionKey: 'retry',
              ),
            ],
            onChooseAnswer: (_) {},
            onSignal: (_) {},
            onRetry: () => retries++,
            onNext: () {},
            onOpenDoubt: () {},
          ),
        ),
      ),
    );

    expect(find.text(t('aula_retrying')), findsOneWidget);
    await tester.tap(find.text(t('aula_retrying')));
    expect(retries, 0);
  });

  testWidgets('chat answer and signal actions respect pending guards', (
    tester,
  ) async {
    AnswerLetter? chosen;
    var signal = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            pendingActionKeys: const {'answer', 'signal'},
            messages: const [
              ChatLessonMessage(
                id: 'options-pending',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.options,
                selectedAnswer: AnswerLetter.A,
                options: [
                  ChatLessonOption(
                    letter: AnswerLetter.A,
                    text: 'Alternativa A',
                    selected: true,
                    enabled: true,
                  ),
                ],
                signals: [
                  ChatLessonSignal(
                    value: 1,
                    labelKey: 'aula_sig_certeza',
                    enabled: true,
                  ),
                ],
              ),
            ],
            onChooseAnswer: (letter) => chosen = letter,
            onSignal: (value) => signal = value,
            onRetry: () {},
            onNext: () {},
            onOpenDoubt: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Alternativa A'));
    await tester.tap(find.text(t('aula_sig_certeza')));

    expect(chosen, isNull);
    expect(signal, 0);
  });

  testWidgets('chat aula advances only when next button is tapped', (
    tester,
  ) async {
    final session = _AutoAdvanceSession()
      ..authed = true
      ..authReady = true
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'Portuguese'
      ..route = '/cyber/aula'
      ..lessonLocalId = 'lesson-chat-auto'
      ..aulaSnapshot = _chatSnapshot(
        phase: const ClassroomPhase.completed(
          message: 'aula_fb_correct',
          wasCorrect: true,
          signal: DecisionSignal.one,
        ),
      );

    await tester.pumpWidget(
      MaterialApp(home: ChatAulaScreen(session: session)),
    );
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.text('✅ Exato. Você domina este ponto.', skipOffstage: false),
      findsOneWidget,
    );
    expect(session.autoAdvances, 0);

    await tester.pump(const Duration(milliseconds: 1379));
    expect(session.autoAdvances, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(session.autoAdvances, 0);

    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('chat-feedback-next-button'))),
      duration: Duration.zero,
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-feedback-next-button')));
    await tester.pump();
    expect(session.autoAdvances, 1);
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
      await tester.pumpAndSettle();

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
      expect(find.textContaining('Voltar ao feedback'), findsOneWidget);
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

  testWidgets(
    'chat timeline does not jump to new lesson content without explicit action',
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
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      final beforePassiveUpdate = controller.position.pixels;
      await tester.drag(
        find.byKey(const Key('chat-aula-timeline')),
        const Offset(0, 900),
      );
      await tester.pump(const Duration(milliseconds: 220));
      final afterManualDrag = controller.position.pixels;
      expect(afterManualDrag, lessThan(beforePassiveUpdate));

      key.currentState!.appendNewLessonTurn();
      await tester.pump(const Duration(milliseconds: 120));

      expect(controller.position.pixels, afterManualDrag);
      expect(find.text('Nova explicacao do item.'), findsNothing);
      expect(find.text('Nova alternativa B'), findsNothing);
      expect(
        find.byKey(const Key('chat-return-current-button')),
        findsOneWidget,
      );
      expect(find.textContaining('Voltar às alternativas'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat-return-current-button')));
      await tester.pumpAndSettle();

      expect(find.text('Nova alternativa B'), findsOneWidget);
    },
  );

  testWidgets('chat timeline auto scrolls to new explanation after advance', (
    tester,
  ) async {
    final key = GlobalKey<_ChatTimelineHarnessState>();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: _ChatTimelineHarness(key: key, scrollController: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.position.pixels, greaterThan(0));

    key.currentState!.appendMessage('Feedback para avancar');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('chat-feedback-next-button')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('chat-feedback-next-button')));
    await tester.pumpAndSettle();

    final timelineRect = tester.getRect(
      find.byKey(const Key('chat-aula-timeline')),
    );
    final explanationRect = tester.getRect(
      find.text('Nova explicacao do item.'),
    );
    expect(explanationRect.top, greaterThanOrEqualTo(timelineRect.top));
    expect(explanationRect.top, lessThan(timelineRect.top + 96));

    final optionsFinder = find.text('Nova alternativa B');
    if (optionsFinder.evaluate().isNotEmpty) {
      expect(tester.getRect(optionsFinder).top, greaterThan(timelineRect.top));
    }

    await tester.scrollUntilVisible(
      optionsFinder,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(optionsFinder, findsOneWidget);

    final beforeManualDrag = controller.position.pixels;
    await tester.drag(
      find.byKey(const Key('chat-aula-timeline')),
      const Offset(0, 120),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.position.pixels, lessThan(beforeManualDrag));
  });

  testWidgets('chat timeline scrolls to feedback after explicit signal', (
    tester,
  ) async {
    final key = GlobalKey<_ChatTimelineHarnessState>();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 520,
            child: _ChatTimelineHarness(key: key, scrollController: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    key.currentState!.appendAnsweredSignalPrompt();
    await tester.pump();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('signal-button-2'))),
      duration: Duration.zero,
      alignment: 0.5,
    );
    await tester.pump();

    final beforeSignal = controller.position.pixels;
    await tester.tap(find.byKey(const Key('signal-button-2')));
    await tester.pumpAndSettle();

    expect(controller.position.pixels, greaterThan(beforeSignal));
    expect(find.text('Feedback do qualificador 2'), findsOneWidget);
  });

  testWidgets('chat return button follows reading column on wide layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final key = GlobalKey<_ChatTimelineHarnessState>();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 520,
            child: _ChatTimelineHarness(key: key, scrollController: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('chat-aula-timeline')),
      const Offset(0, 900),
    );
    await tester.pump(const Duration(milliseconds: 220));

    key.currentState!.appendNewLessonTurn();
    await tester.pump(const Duration(milliseconds: 120));

    final buttonRect = tester.getRect(
      find.byKey(const Key('chat-return-current-button')),
    );
    expect(buttonRect.right, lessThan(1100));
    expect(buttonRect.left, greaterThan(720));
  });

  testWidgets('chat timeline supports certified keyboard navigation', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: _ChatTimelineHarness(scrollController: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(controller.position.pixels, greaterThan(0));

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(controller.position.pixels, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(controller.position.pixels, greaterThan(0));

    final beforePageUp = controller.position.pixels;
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(controller.position.pixels, lessThan(beforePageUp));

    final beforePageDown = controller.position.pixels;
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(controller.position.pixels, greaterThan(beforePageDown));
  });

  testWidgets('chat timeline manual drag is not reset by metrics updates', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: _ChatTimelineHarness(scrollController: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    final beforeDrag = controller.position.pixels;
    expect(beforeDrag, greaterThan(300));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('chat-aula-timeline'))),
    );
    await gesture.moveBy(const Offset(0, 180));

    ScrollMetricsNotification(
      metrics: controller.position,
      context: tester.element(find.byKey(const Key('chat-aula-timeline'))),
    ).dispatch(tester.element(find.byKey(const Key('chat-aula-timeline'))));

    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 260));

    final afterDrag = controller.position.pixels;
    expect(afterDrag, lessThan(beforeDrag - 40));

    final state = tester.state<_ChatTimelineHarnessState>(
      find.byType(_ChatTimelineHarness),
    );
    state.appendNewLessonTurn();
    await tester.pump();
    ScrollMetricsNotification(
      metrics: controller.position,
      context: tester.element(find.byKey(const Key('chat-aula-timeline'))),
    ).dispatch(tester.element(find.byKey(const Key('chat-aula-timeline'))));
    await tester.pump(const Duration(milliseconds: 260));

    expect(controller.position.pixels, afterDrag);
    expect(find.text('Nova explicacao do item.'), findsNothing);
    expect(find.text('Nova alternativa B'), findsNothing);
  });

  testWidgets(
    'chat timeline preserves manual context across compact to expanded resize',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 520,
              child: _ChatTimelineHarness(scrollController: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('Mensagem 12'),
        220,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.textContaining('Mensagem 12'), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(980, 520));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Mensagem 12', skipOffstage: false),
        findsOneWidget,
      );
      expect(controller.position.pixels, greaterThan(0));
    },
  );

  testWidgets(
    'chat timeline does not recenter through rotation with reduced motion',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 740),
            disableAnimations: true,
          ),
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 520,
                child: _ChatTimelineHarness(scrollController: controller),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(0);
      await tester.pump();
      final beforeResize = controller.position.pixels;

      await tester.binding.setSurfaceSize(const Size(740, 390));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(tester.takeException(), isNull);
      expect(controller.position.pixels, beforeResize);
      expect(find.byKey(const Key('chat-return-current-button')), findsNothing);
    },
  );

  testWidgets('chat timeline exposes conversation region semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: _ChatTimelineHarness(scrollController: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Conversa da aula'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Mensagem do SIM')), findsWidgets);
    semantics.dispose();
  });

  testWidgets('chat timeline exposes delivery status updates on same message', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final key = GlobalKey<_ChatTimelineHarnessState>();
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: _ChatTimelineHarness(key: key, scrollController: controller),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();

    expect(
      tester.getSemantics(find.byType(ChatAulaMessageBubble).last).label,
      contains('Status: entregue'),
    );

    await tester.pump(const Duration(milliseconds: 220));
    key.currentState!.markLastMessageFailed();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      tester.getSemantics(find.byType(ChatAulaMessageBubble).last).label,
      contains('Status: falha'),
    );
    semantics.dispose();
  });

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
                  imageData: 'data:image/png;base64,AAAA',
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

  testWidgets(
    'chat student doubt renders text and image attachment as message',
    (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatAulaTimeline(
              messages: [
                ChatLessonMessage(
                  id: 'student-doubt',
                  role: ChatLessonMessageRole.student,
                  kind: ChatLessonMessageKind.studentDoubt,
                  text: 'Nao entendi este grafico.',
                  imageData: _pngDataUrl(),
                  mediaName: 'grafico.png',
                  mediaType: 'image/png',
                  mediaSize: 2048,
                  deliveryStatus: ChatLessonDeliveryStatus.sent,
                  timestampLabel: '10:20',
                ),
              ],
              onChooseAnswer: (_) {},
              onSignal: (_) {},
              onRetry: () {},
              onNext: () {},
              onOpenDoubt: () {},
            ),
          ),
        ),
      );

      expect(find.text('Nao entendi este grafico.'), findsOneWidget);
      expect(find.text('grafico.png'), findsOneWidget);
      expect(find.text('2.0KB'), findsOneWidget);
      expect(find.byType(LessonMediaImageView), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ChatAulaMessageBubble)).label,
        contains('grafico.png'),
      );
      expect(
        tester.getSemantics(find.byType(ChatAulaMessageBubble)).label,
        contains('Status: enviada'),
      );

      semantics.dispose();
    },
  );

  testWidgets('chat history question preserves its own lesson image', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: [
              ChatLessonMessage(
                id: 'history-question',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.historyQuestion,
                text: 'Questão antiga com imagem?',
                imageData: _pngDataUrl(),
                options: [
                  ChatLessonOption(
                    letter: AnswerLetter.A,
                    text: 'Alternativa antiga A',
                    selected: true,
                    enabled: false,
                  ),
                  ChatLessonOption(
                    letter: AnswerLetter.B,
                    text: 'Alternativa antiga B',
                    selected: false,
                    enabled: false,
                  ),
                ],
              ),
              const ChatLessonMessage(
                id: 'history-answer',
                role: ChatLessonMessageRole.student,
                kind: ChatLessonMessageKind.historyAnswer,
                text: 'A',
                selectedAnswer: AnswerLetter.A,
                isCorrect: true,
              ),
            ],
            onChooseAnswer: (_) {},
            onSignal: (_) {},
            onRetry: () {},
            onNext: () {},
            onOpenDoubt: () {},
          ),
        ),
      ),
    );

    expect(find.text('Questão antiga com imagem?'), findsOneWidget);
    expect(find.byType(LessonMediaImageView), findsOneWidget);
    expect(find.text('Alternativa antiga A'), findsOneWidget);
    expect(find.text('Alternativa antiga B'), findsOneWidget);
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

  testWidgets('compact phone keeps feedback actions reachable with larger text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.6),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: ChatAulaTimeline(
              messages: const [
                ChatLessonMessage(
                  id: 'compact-feedback',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.feedback,
                  text:
                      'Feedback com explicação suficiente para validar leitura em tela estreita.',
                  isCorrect: true,
                  actionKey: 'aula_next_item',
                ),
              ],
              onChooseAnswer: (_) {},
              onSignal: (_) {},
              onRetry: () {},
              onNext: () {},
              onOpenDoubt: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 220));

    expect(tester.takeException(), isNull);
    final doubtRect = tester.getRect(
      find.byKey(const Key('chat-feedback-doubt-button')),
    );
    final nextRect = tester.getRect(
      find.byKey(const Key('chat-feedback-next-button')),
    );
    expect(doubtRect.width, lessThanOrEqualTo(288));
    expect(nextRect.width, lessThanOrEqualTo(288));
    expect(doubtRect.height, greaterThanOrEqualTo(48));
    expect(nextRect.height, greaterThanOrEqualTo(48));
    expect(nextRect.top, greaterThan(doubtRect.bottom));
  });

  testWidgets(
    'compact phone renders alternatives and inline signals without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.5),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: ChatAulaTimeline(
                messages: const [
                  ChatLessonMessage(
                    id: 'compact-options',
                    role: ChatLessonMessageRole.sim,
                    kind: ChatLessonMessageKind.options,
                    selectedAnswer: AnswerLetter.B,
                    options: [
                      ChatLessonOption(
                        letter: AnswerLetter.A,
                        text:
                            'Alternativa A com texto longo para tela pequena.',
                        selected: false,
                        enabled: true,
                      ),
                      ChatLessonOption(
                        letter: AnswerLetter.B,
                        text:
                            'Alternativa B com texto longo para validar quebra.',
                        selected: true,
                        enabled: true,
                      ),
                      ChatLessonOption(
                        letter: AnswerLetter.C,
                        text:
                            'Alternativa C com texto longo para manter leitura.',
                        selected: false,
                        enabled: true,
                      ),
                    ],
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
                ],
                onChooseAnswer: (_) {},
                onSignal: (_) {},
                onRetry: () {},
                onNext: () {},
                onOpenDoubt: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 220));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Alternativa B'), findsOneWidget);
      expect(find.byKey(const Key('inline-signal-choices')), findsOneWidget);
      for (final label in [
        t('aula_sig_certeza'),
        t('aula_sig_revisar'),
        t('aula_sig_nao_sei'),
      ]) {
        expect(find.text(label, skipOffstage: false), findsOneWidget);
      }
    },
  );

  testWidgets(
    'compact classroom top bar does not overlap timeline with largest font',
    (tester) async {
      SharedPreferences.setMockInitialValues({ClassroomTextScale.prefsKey: 5});
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final session = LabSession()
        ..authed = true
        ..authReady = true
        ..selectedLanguageCode = 'pt'
        ..stableLang = 'Portuguese'
        ..route = '/cyber/aula'
        ..credits = 3
        ..aulaSnapshot = _chatSnapshot(
          phase: const ClassroomPhase.reading(),
          headerLabel: 'aula_item_of:12/12:aula_layer_5',
        );

      await tester.pumpWidget(
        MaterialApp(
          home: SimThemeScope(
            darkMode: false,
            onToggleDarkMode: () {},
            child: ChatAulaScreen(session: session),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 220));

      expect(tester.takeException(), isNull);
      final topBarRect = tester.getRect(find.byType(AulaTopBar));
      final timelineRect = tester.getRect(find.byType(ChatAulaTimeline));
      expect(timelineRect.top, greaterThanOrEqualTo(topBarRect.bottom));
      expect(
        find.text('Qual alternativa está correta?', skipOffstage: false),
        findsOneWidget,
      );
      for (final label in [
        'Abrir menu da aula',
        'Tocar áudio da aula',
        'Modo escuro',
        'Abrir revisão',
      ]) {
        final rect = tester.getRect(find.bySemanticsLabel(label));
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
      }
    },
  );

  testWidgets(
    'chat classroom inserts late image panel between explanation and question',
    (tester) async {
      final session = LabSession()
        ..authed = true
        ..authReady = true
        ..selectedLanguageCode = 'pt'
        ..stableLang = 'Portuguese'
        ..lessonLocalId = 'lesson-chat-late-image'
        ..route = '/cyber/aula'
        ..aulaSnapshot = _chatSnapshot(phase: const ClassroomPhase.reading());

      await tester.pumpWidget(
        MaterialApp(home: ChatAulaScreen(session: session)),
      );
      await tester.pump(const Duration(milliseconds: 120));

      var timeline = tester.widget<ChatAulaTimeline>(
        find.byType(ChatAulaTimeline),
      );
      var kinds = timeline.messages.map((message) => message.kind).toList();
      expect(kinds.indexOf(ChatLessonMessageKind.image), -1);
      final initialQuestionIndex = kinds.indexOf(
        ChatLessonMessageKind.question,
      );
      final initialOptionsIndex = kinds.indexOf(ChatLessonMessageKind.options);
      expect(initialOptionsIndex, greaterThan(initialQuestionIndex));

      session.aulaRuntimeLoading = true;
      session.notifyListeners();
      await tester.pump(const Duration(milliseconds: 120));

      timeline = tester.widget<ChatAulaTimeline>(find.byType(ChatAulaTimeline));
      kinds = timeline.messages.map((message) => message.kind).toList();
      final explanationIndex = kinds.indexOf(ChatLessonMessageKind.explanation);
      final imageIndex = kinds.indexOf(ChatLessonMessageKind.image);
      final questionIndex = kinds.indexOf(ChatLessonMessageKind.question);
      final optionsIndex = kinds.indexOf(ChatLessonMessageKind.options);

      expect(imageIndex, greaterThan(explanationIndex));
      expect(questionIndex, greaterThan(imageIndex));
      expect(optionsIndex, greaterThan(questionIndex));
    },
  );

  testWidgets(
    'chat classroom renders ready raster image on the lesson screen without paid offer',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final session = LabSession()
        ..authed = true
        ..authReady = true
        ..selectedLanguageCode = 'pt'
        ..stableLang = 'Portuguese'
        ..lessonLocalId = 'lesson-chat-ready-raster'
        ..route = '/cyber/aula'
        ..aulaSnapshot = _chatSnapshot(
          phase: const ClassroomPhase.reading(),
          imagem: _pngDataUrl(),
          explanation: 'Explicacao com foto pronta do servidor.',
          question: 'Qual ponto o grafico destaca?',
        );

      await tester.pumpWidget(
        MaterialApp(home: ChatAulaScreen(session: session)),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(ChatAulaTimeline), findsOneWidget);
      expect(
        find.text('Explicacao com foto pronta do servidor.'),
        findsOneWidget,
      );
      expect(find.byType(LessonMediaImageView), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      expect(find.text('Qual ponto o grafico destaca?'), findsOneWidget);
      expect(
        find.text(
          'Esta parte da aula tem uma imagem criada por inteligência artificial.',
          skipOffstage: false,
        ),
        findsNothing,
      );

      final timeline = tester.widget<ChatAulaTimeline>(
        find.byType(ChatAulaTimeline),
      );
      final kinds = timeline.messages.map((message) => message.kind).toList();
      final explanationIndex = kinds.indexOf(ChatLessonMessageKind.explanation);
      final imageIndex = kinds.indexOf(ChatLessonMessageKind.image);
      final questionIndex = kinds.indexOf(ChatLessonMessageKind.question);
      expect(imageIndex, greaterThan(explanationIndex));
      expect(questionIndex, greaterThan(imageIndex));
    },
  );

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
          imagem: _pngDataUrl(),
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
      final imageMessages = timeline.messages
          .where((message) => message.kind == ChatLessonMessageKind.image)
          .toList();
      expect(imageMessages, hasLength(1));
      expect(imageMessages.single.imageData, _pngDataUrl());
      expect(
        timeline.messages
            .where((message) => message.text == 'Primeira pergunta preservada?')
            .length,
        1,
      );
    },
  );

  testWidgets(
    'chat classroom keeps transient loading as transcript after content arrives',
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
        contains('runtime-loading'),
      );
      expect(
        timeline.messages.map((message) => message.text),
        contains('Explicacao da aula em chat.'),
      );
    },
  );

  testWidgets('chat classroom archives repeated doubt answers as new turns', (
    tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'Portuguese'
      ..lessonLocalId = 'lesson-chat-doubt'
      ..route = '/cyber/aula'
      ..aulaSnapshot = _chatSnapshot(phase: const ClassroomPhase.reading())
      ..setDoubt(
        const DoubtState(
          status: DoubtStatus.explaining,
          progress: 100,
          response: DoubtResponse(explanation: 'Primeira resposta da dúvida.'),
        ),
      );

    await tester.pumpWidget(
      MaterialApp(home: ChatAulaScreen(session: session)),
    );
    await tester.pump(const Duration(milliseconds: 120));

    session.setDoubt(
      const DoubtState(
        status: DoubtStatus.explaining,
        progress: 100,
        response: DoubtResponse(explanation: 'Segunda resposta da dúvida.'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    final timeline = tester.widget<ChatAulaTimeline>(
      find.byType(ChatAulaTimeline),
    );
    final texts = timeline.messages.map((message) => message.text).toList();
    expect(texts, contains('Primeira resposta da dúvida.'));
    expect(texts, contains('Segunda resposta da dúvida.'));
  });

  testWidgets(
    'chat feedback keeps manual advance hidden while doubt processes',
    (tester) async {
      final session = LabSession()
        ..setDoubt(
          const DoubtState(status: DoubtStatus.processing, progress: 40),
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatAulaTimeline(
              session: session,
              messages: const [
                ChatLessonMessage(
                  id: 'feedback',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.feedback,
                  text: 'Feedback pronto.',
                  isCorrect: true,
                  actionKey: 'aula_next_item',
                ),
              ],
              onChooseAnswer: (_) {},
              onSignal: (_) {},
              onRetry: () {},
              onNext: () {},
              onOpenDoubt: () {},
            ),
          ),
        ),
      );

      expect(
        _textAny(['Próximo tópico >>', 'Next topic >>', 'Sujet suivant >>']),
        findsNothing,
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

  testWidgets('shared doubt sheet stays usable with keyboard open', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 640),
          viewInsets: EdgeInsets.only(bottom: 300),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: DoubtInputSheet(
              controller: controller,
              busy: false,
              onSubmit: (_) {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    final sendButton = find.text('Enviar dúvida').last;
    await tester.scrollUntilVisible(
      sendButton,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(sendButton, findsOneWidget);
    final buttonRect = tester.getRect(sendButton);
    expect(buttonRect.bottom, lessThanOrEqualTo(640));
  });

  testWidgets('shared doubt sheet preserves focused text across resize', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DoubtInputSheet(
            controller: controller,
            busy: false,
            onSubmit: (_) {},
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.byType(TextField).last);
    await tester.enterText(find.byType(TextField).last, 'Texto preservado');
    await tester.pump();
    expect(controller.text, 'Texto preservado');
    expect(FocusManager.instance.primaryFocus, isNotNull);

    await tester.binding.setSurfaceSize(const Size(740, 390));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(tester.takeException(), isNull);
    expect(controller.text, 'Texto preservado');
    expect(find.text('Texto preservado'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus, isNotNull);
  });

  testWidgets('chat composer submit becomes a student message in timeline', (
    tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'Portuguese'
      ..lessonLocalId = 'lesson-chat-composer'
      ..route = '/cyber/aula'
      ..aulaSnapshot = _chatSnapshot(
        phase: const ClassroomPhase.completed(
          message: 'aula_fb_correct',
          wasCorrect: true,
          signal: DecisionSignal.one,
        ),
      );

    await tester.pumpWidget(
      MaterialApp(home: ChatAulaScreen(session: session)),
    );
    await tester.pump(const Duration(milliseconds: 120));

    await tester.scrollUntilVisible(
      find.byKey(const Key('chat-feedback-doubt-button')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('chat-feedback-doubt-button'))),
      duration: Duration.zero,
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-feedback-doubt-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Pode explicar melhor?',
    );
    await tester.tap(find.text('Enviar dúvida').last);
    await tester.pump(const Duration(milliseconds: 120));

    final timeline = tester.widget<ChatAulaTimeline>(
      find.byType(ChatAulaTimeline),
    );
    expect(
      timeline.messages.where(
        (message) =>
            message.kind == ChatLessonMessageKind.studentDoubt &&
            message.text == 'Pode explicar melhor?',
      ),
      hasLength(1),
    );
    expect(
      find.text('Pode explicar melhor?', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets(
    'chat route restoration preserves dead history and student media',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final session = LabSession()
        ..authed = true
        ..authReady = true
        ..selectedLanguageCode = 'pt'
        ..stableLang = 'Portuguese'
        ..lessonLocalId = 'lesson-chat-restore-route'
        ..route = '/cyber/aula'
        ..aulaSnapshot = _chatSnapshot(
          phase: const ClassroomPhase.completed(
            message: 'aula_fb_correct',
            wasCorrect: true,
            signal: DecisionSignal.one,
          ),
        );

      await tester.pumpWidget(
        MaterialApp(home: ChatAulaScreen(session: session)),
      );
      await tester.pump(const Duration(milliseconds: 120));

      await tester.scrollUntilVisible(
        find.byKey(const Key('chat-feedback-doubt-button')),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('chat-feedback-doubt-button'))),
        duration: Duration.zero,
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat-feedback-doubt-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'Ainda tenho dúvida.',
      );
      await tester.tap(find.text('Enviar dúvida').last);
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        find.text('Ainda tenho dúvida.', skipOffstage: false),
        findsOneWidget,
      );

      session.aulaSnapshot = _chatSnapshot(
        phase: const ClassroomPhase.reading(),
        headerLabel: 'aula_item_of:1/4:aula_layer_2',
        explanation: 'Item atual restaurado.',
        question: 'Pergunta atual restaurada?',
      );
      session.notifyListeners();
      await tester.pump(const Duration(milliseconds: 160));

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 220));

      await tester.pumpWidget(
        MaterialApp(home: ChatAulaScreen(session: session)),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final timeline = tester.widget<ChatAulaTimeline>(
        find.byType(ChatAulaTimeline),
      );
      final prefs = await SharedPreferences.getInstance();
      final savedRaw = prefs.getString(
        _chatConversationPrefsKey('lesson-chat-restore-route'),
      );
      expect(savedRaw, isNot(contains('data:image')));
      final messages = timeline.messages;
      expect(
        messages.map((message) => message.text),
        contains('Ainda tenho dúvida.'),
      );
      expect(
        messages.map((message) => message.text),
        contains('Item atual restaurado.'),
      );
      expect(
        messages.map((message) => message.text),
        contains('Pergunta atual restaurada?'),
      );
      expect(
        messages.any(
          (message) =>
              message.kind == ChatLessonMessageKind.feedback &&
              message.deliveryStatus == ChatLessonDeliveryStatus.read,
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'chat app restoration restores student attachment and loading error messages',
    (tester) async {
      final savedMessages = [
        const ChatLessonMessage(
          id: 'old-feedback',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.feedback,
          text: 'Feedback antigo salvo.',
          actionKey: 'aula_next',
          deliveryStatus: ChatLessonDeliveryStatus.read,
        ),
        ChatLessonMessage(
          id: 'student-doubt-saved',
          role: ChatLessonMessageRole.student,
          kind: ChatLessonMessageKind.studentDoubt,
          text: 'Dúvida salva com foto.',
          imageData: _pngDataUrl(),
          mediaName: 'duvida.png',
          mediaType: 'image/png',
          mediaSize: 4096,
          deliveryStatus: ChatLessonDeliveryStatus.sent,
        ),
        const ChatLessonMessage(
          id: 'saved-loading',
          role: ChatLessonMessageRole.system,
          kind: ChatLessonMessageKind.loading,
          text: 'Carregamento salvo.',
          deliveryStatus: ChatLessonDeliveryStatus.processing,
        ),
        const ChatLessonMessage(
          id: 'saved-error',
          role: ChatLessonMessageRole.system,
          kind: ChatLessonMessageKind.error,
          text: 'Erro recuperável salvo.',
          actionKey: 'retry',
          deliveryStatus: ChatLessonDeliveryStatus.failed,
        ),
      ];
      SharedPreferences.setMockInitialValues({
        _chatConversationPrefsKey('lesson-chat-restore-app'): jsonEncode({
          'version': 1,
          'lessonKey': 'lesson-chat-restore-app',
          'archiveSeq': 7,
          'messages': savedMessages
              .map((message) => message.toJson(includeInlineImageData: false))
              .toList(),
        }),
      });
      final session = LabSession()
        ..authed = true
        ..authReady = true
        ..selectedLanguageCode = 'pt'
        ..stableLang = 'Portuguese'
        ..lessonLocalId = 'lesson-chat-restore-app'
        ..route = '/cyber/aula'
        ..aulaRuntimeLoading = true
        ..aulaRuntimeError = 'Falha temporária'
        ..aulaSnapshot = _chatSnapshot(phase: const ClassroomPhase.reading());

      await tester.pumpWidget(
        MaterialApp(home: ChatAulaScreen(session: session)),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final timeline = tester.widget<ChatAulaTimeline>(
        find.byType(ChatAulaTimeline),
      );
      expect(
        timeline.messages.map((message) => message.text),
        contains('Feedback antigo salvo.'),
      );
      expect(
        timeline.messages.map((message) => message.text),
        contains('Dúvida salva com foto.'),
      );
      expect(
        timeline.messages.map((message) => message.text),
        contains('Carregamento salvo.'),
      );
      expect(
        timeline.messages.map((message) => message.text),
        contains('Erro recuperável salvo.'),
      );
      expect(
        timeline.messages
            .where((message) => message.id == 'student-doubt-saved')
            .single
            .imageData,
        isNull,
      );
      expect(find.text('duvida.png', skipOffstage: false), findsOneWidget);
      expect(find.text('4.0KB', skipOffstage: false), findsOneWidget);
      expect(
        timeline.messages.any(
          (message) =>
              message.id == 'old-feedback' &&
              message.deliveryStatus == ChatLessonDeliveryStatus.read,
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'chat restored timeline return targets current item instead of old feedback',
    (tester) async {
      final key = GlobalKey<_RestoredTimelineHarnessState>();
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 320,
              child: _RestoredTimelineHarness(
                key: key,
                scrollController: controller,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.drag(
        find.byKey(const Key('chat-aula-timeline')),
        const Offset(0, 900),
      );
      await tester.pump(const Duration(milliseconds: 220));

      key.currentState!.appendRestoredStudentMessage();
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        find.byKey(const Key('chat-return-current-button')),
        findsOneWidget,
      );
      expect(find.textContaining('Voltar às alternativas'), findsOneWidget);
      expect(find.textContaining('Voltar ao feedback'), findsNothing);
    },
  );

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
        imagem: _pngDataUrl(),
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
    expect(find.byKey(const Key('inline-signal-choices')), findsOneWidget);
    expect(find.text('Como voce se sente?', skipOffstage: false), findsNothing);
    expect(
      find.text(t('aula_sig_revisar'), skipOffstage: false),
      findsOneWidget,
    );

    session.submitAulaSignal(2);
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.text(t('aula_fb_correct'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('${t('aula_next')} >>', skipOffstage: false),
      findsNothing,
    );
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

String _pngDataUrl() {
  const png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lK3QMgAAAABJRU5ErkJggg==';
  return 'data:image/png;base64,$png';
}

String _chatConversationPrefsKey(String lessonKey) {
  final encoded = base64Url.encode(utf8.encode(lessonKey));
  return 'sim.chat_aula.conversation.v1.$encoded';
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

  void appendNewLessonTurn() {
    setState(() {
      final id = _nextId++;
      _messages.addAll([
        ChatLessonMessage(
          id: 'feedback-before-new-$id',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.feedback,
          text: 'Feedback anterior.',
          actionKey: 'aula_next',
          deliveryStatus: ChatLessonDeliveryStatus.read,
        ),
        ChatLessonMessage(
          id: 'new-explanation-$id',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.explanation,
          text: 'Nova explicacao do item.',
        ),
        ChatLessonMessage(
          id: 'new-image-$id',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.image,
          imageData: _pngDataUrl(),
          imageStatus: 'ready',
        ),
        ChatLessonMessage(
          id: 'new-question-$id',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.question,
          text: 'Nova pergunta do item?',
        ),
        ChatLessonMessage(
          id: 'new-options-$id',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.options,
          options: const [
            ChatLessonOption(
              letter: AnswerLetter.A,
              text: 'Nova alternativa A',
              selected: false,
              enabled: true,
            ),
            ChatLessonOption(
              letter: AnswerLetter.B,
              text: 'Nova alternativa B',
              selected: false,
              enabled: true,
            ),
            ChatLessonOption(
              letter: AnswerLetter.C,
              text: 'Nova alternativa C',
              selected: false,
              enabled: true,
            ),
          ],
        ),
      ]);
    });
  }

  void appendAnsweredSignalPrompt() {
    setState(() {
      final id = _nextId++;
      _messages.add(
        ChatLessonMessage(
          id: 'answered-options-$id',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.options,
          selectedAnswer: AnswerLetter.A,
          options: const [
            ChatLessonOption(
              letter: AnswerLetter.A,
              text: 'Alternativa sinalizada A',
              selected: true,
              enabled: false,
            ),
            ChatLessonOption(
              letter: AnswerLetter.B,
              text: 'Alternativa sinalizada B',
              selected: false,
              enabled: false,
            ),
          ],
          signals: const [
            ChatLessonSignal(
              value: 1,
              labelKey: 'aula_sig_revisar',
              enabled: true,
            ),
            ChatLessonSignal(
              value: 2,
              labelKey: 'aula_sig_certeza',
              enabled: true,
            ),
          ],
        ),
      );
    });
  }

  void markLastMessageFailed() {
    setState(() {
      final last = _messages.removeLast();
      _messages.add(
        last.copyWith(deliveryStatus: ChatLessonDeliveryStatus.failed),
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
      onSignal: (value) => appendMessage('Feedback do qualificador $value'),
      onRetry: () {},
      onNext: appendNewLessonTurn,
      onOpenDoubt: () {},
    );
  }
}

class _RestoredTimelineHarness extends StatefulWidget {
  const _RestoredTimelineHarness({required this.scrollController, super.key});

  final ScrollController scrollController;

  @override
  State<_RestoredTimelineHarness> createState() =>
      _RestoredTimelineHarnessState();
}

class _RestoredTimelineHarnessState extends State<_RestoredTimelineHarness> {
  late final List<ChatLessonMessage> _messages = [
    for (var i = 1; i <= 24; i++)
      ChatLessonMessage(
        id: 'restored-history-$i',
        role: ChatLessonMessageRole.sim,
        kind: ChatLessonMessageKind.explanation,
        text: 'Historico restaurado $i\nLinha preservada.',
      ),
    const ChatLessonMessage(
      id: 'feedback-old-restored',
      role: ChatLessonMessageRole.sim,
      kind: ChatLessonMessageKind.feedback,
      text: 'Feedback antigo restaurado.',
      actionKey: 'aula_next',
      deliveryStatus: ChatLessonDeliveryStatus.read,
    ),
    const ChatLessonMessage(
      id: 'explanation-current-restored',
      role: ChatLessonMessageRole.sim,
      kind: ChatLessonMessageKind.explanation,
      text: 'Item atual restaurado.',
    ),
    const ChatLessonMessage(
      id: 'question-current-restored',
      role: ChatLessonMessageRole.sim,
      kind: ChatLessonMessageKind.question,
      text: 'Pergunta atual restaurada?',
    ),
    const ChatLessonMessage(
      id: 'options-current-restored',
      role: ChatLessonMessageRole.sim,
      kind: ChatLessonMessageKind.options,
      options: [
        ChatLessonOption(
          letter: AnswerLetter.A,
          text: 'Alternativa restaurada A',
          selected: false,
          enabled: true,
        ),
      ],
    ),
  ];

  void appendRestoredStudentMessage() {
    setState(() {
      _messages.add(
        const ChatLessonMessage(
          id: 'student-restored-note',
          role: ChatLessonMessageRole.student,
          kind: ChatLessonMessageKind.studentDoubt,
          text: 'Mensagem restaurada depois da volta.',
          deliveryStatus: ChatLessonDeliveryStatus.sent,
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

class _AutoAdvanceSession extends LabSession {
  int autoAdvances = 0;

  @override
  Future<void> advanceAula() async {
    autoAdvances++;
  }
}
