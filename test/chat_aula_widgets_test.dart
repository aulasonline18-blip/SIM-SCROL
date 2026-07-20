import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/aula_widgets.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_widgets.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  setUp(() => setSimActiveLanguage('pt-BR'));

  const tinyPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lK3QMgAAAABJRU5ErkJggg==';

  testWidgets('chat timeline renders compact lesson messages and answer taps', (
    tester,
  ) async {
    AnswerLetter? chosen;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'exp',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.explanation,
                text: 'Explicação essencial',
              ),
              ChatLessonMessage(
                id: 'options',
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
    expect(find.text('Explicação essencial'), findsOneWidget);
    expect(find.byKey(const Key('chat-answer-card-B')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-answer-card-B')));
    expect(chosen, AnswerLetter.B);
  });

  testWidgets('chat timeline keeps signal buttons tappable', (tester) async {
    int? signal;

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

    await tester.tap(find.byKey(const Key('signal-button-1')));
    expect(signal, 1);
  });

  testWidgets('chat visual blocks use controlled image rendering', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatImageBubble(
            message: const ChatLessonMessage(
              id: 'image',
              role: ChatLessonMessageRole.sim,
              kind: ChatLessonMessageKind.image,
              imageData: 'data:image/png;base64,invalid',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(LessonImageErrorView), findsOneWidget);
  });

  testWidgets('LessonImageStudySurface usa proporção 3:4 e abre zoom', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: LessonImageStudySurface(
              data: 'data:image/png;base64,$tinyPng',
              caption: 'Apoio visual da aula',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final aspect = tester.widget<AspectRatio>(find.byType(AspectRatio).first);
    expect(aspect.aspectRatio, lessonImageStudyAspectRatio);
    expect(find.byTooltip(t('aula_image_expand')), findsOneWidget);

    await tester.tap(find.byTooltip(t('aula_image_expand')));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text(t('aula_image_alt')), findsOneWidget);
    expect(find.text('Apoio visual da aula'), findsWidgets);

    await tester.tap(find.byTooltip(t('aula_image_close')));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('chat image bubble usa proporção 3:4 e abre inspector', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatImageBubble(
            message: ChatLessonMessage(
              id: 'image-ready',
              role: ChatLessonMessageRole.sim,
              kind: ChatLessonMessageKind.image,
              imageData: 'data:image/png;base64,$tinyPng',
              text: 'Diagrama da aula',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final aspect = tester.widget<AspectRatio>(find.byType(AspectRatio).first);
    expect(aspect.aspectRatio, lessonImageStudyAspectRatio);
    expect(find.byTooltip(t('aula_image_expand')), findsOneWidget);

    await tester.tap(find.byTooltip(t('aula_image_expand')));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byTooltip(t('aula_image_close')));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsNothing);
  });

  test('imagem pedagógica da aula não usa cover nem 16/10', () {
    final aulaSource = File(
      'lib/features/classroom/aula_widgets.dart',
    ).readAsStringSync();
    final chatSource = File(
      'lib/features/classroom/chat_aula_widgets.dart',
    ).readAsStringSync();
    final studySurface = RegExp(
      r'class LessonImageStudySurface[\s\S]*?class LessonMediaImageView',
    ).firstMatch(aulaSource)?.group(0);
    final mediaImageView = RegExp(
      r'class LessonMediaImageView[\s\S]*?class LessonImageErrorView',
    ).firstMatch(aulaSource)?.group(0);
    final visualBoard = RegExp(
      r'class LessonVisualBoard[\s\S]*?class LessonImageStudySurface',
    ).firstMatch(aulaSource)?.group(0);
    final chatImageBubble = RegExp(
      r'class ChatImageBubble[\s\S]*?class _TextBlock',
    ).firstMatch(chatSource)?.group(0);

    expect(studySurface, isNotNull);
    expect(visualBoard, isNotNull);
    expect(mediaImageView, isNotNull);
    expect(chatImageBubble, isNotNull);
    expect(studySurface, isNot(contains('BoxFit.cover')));
    expect(visualBoard, isNot(contains('BoxFit.cover')));
    expect(mediaImageView, isNot(contains('BoxFit.cover')));
    expect(chatImageBubble, isNot(contains('BoxFit.cover')));
    expect(chatImageBubble, isNot(contains('16 / 10')));
    expect(chatImageBubble, contains('LessonVisualBoard'));
    expect(visualBoard, contains('lessonImageStudyAspectRatio'));
  });

  testWidgets('empty timeline has explicit controlled state', (tester) async {
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
    expect(find.text(t('aula_choose_goal')), findsOneWidget);
  });

  testWidgets('timeline positions current explanation on lesson entry', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 260,
            child: ChatAulaTimeline(
              scrollController: controller,
              initialScrollToCurrent: true,
              initialScrollKey: 'lesson-scroll-a',
              messages: [
                for (var i = 0; i < 18; i++)
                  ChatLessonMessage(
                    id: 'history-$i',
                    role: ChatLessonMessageRole.sim,
                    kind: ChatLessonMessageKind.historyQuestion,
                    text: 'Histórico $i\nlinha\nlinha\nlinha',
                    isHistorical: true,
                    isActionable: false,
                  ),
                const ChatLessonMessage(
                  id: 'active-explanation',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.explanation,
                  text: 'Explicação atual que deve abrir na área de estudo.',
                ),
                const ChatLessonMessage(
                  id: 'active-question',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.question,
                  text: 'Pergunta atual?',
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

    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
    expect(
      find.text('Explicação atual que deve abrir na área de estudo.'),
      findsOneWidget,
    );
  });

  testWidgets('timeline moves to confidence signals after answer selection', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 280,
            child: ChatAulaTimeline(
              scrollController: controller,
              initialScrollToCurrent: true,
              initialScrollKey: 'lesson-scroll-b',
              messages: const [
                ChatLessonMessage(
                  id: 'explanation',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.explanation,
                  text: 'Texto longo\nlinha\nlinha\nlinha\nlinha\nlinha\nlinha',
                ),
                ChatLessonMessage(
                  id: 'question',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.question,
                  text: 'Qual alternativa?',
                ),
                ChatLessonMessage(
                  id: 'options',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.options,
                  selectedAnswer: AnswerLetter.B,
                  options: [
                    ChatLessonOption(
                      letter: AnswerLetter.A,
                      text: 'A',
                      selected: false,
                      enabled: true,
                    ),
                    ChatLessonOption(
                      letter: AnswerLetter.B,
                      text: 'B',
                      selected: true,
                      enabled: true,
                    ),
                    ChatLessonOption(
                      letter: AnswerLetter.C,
                      text: 'C',
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
                      labelKey: 'aula_sig_duvida',
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

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('signal-button-1')), findsOneWidget);
    expect(controller.offset, greaterThan(0));
  });

  testWidgets('timeline lands new rendered question near three quarters', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: ChatAulaTimeline(
              scrollController: controller,
              initialScrollToCurrent: true,
              initialScrollKey: 'lesson-scroll-question-anchor',
              padding: EdgeInsets.zero,
              messages: [
                for (var i = 0; i < 16; i++)
                  ChatLessonMessage(
                    id: 'history-anchor-$i',
                    role: ChatLessonMessageRole.sim,
                    kind: ChatLessonMessageKind.historyQuestion,
                    text: 'Histórico $i\nlinha\nlinha\nlinha',
                    isHistorical: true,
                  ),
                const ChatLessonMessage(
                  id: 'active-question-anchor',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.question,
                  text: 'Pergunta nova ancorada perto de três quartos?',
                ),
                for (var i = 0; i < 24; i++)
                  ChatLessonMessage(
                    id: 'tail-anchor-$i',
                    role: ChatLessonMessageRole.sim,
                    kind: ChatLessonMessageKind.historyAnswer,
                    text: 'Espaço posterior $i\nlinha\nlinha',
                    isHistorical: true,
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

    await tester.pumpAndSettle();

    final viewport = tester.getRect(
      find.byKey(const Key('chat-aula-timeline')),
    );
    final questionTop = tester
        .getTopLeft(find.text('Pergunta nova ancorada perto de três quartos?'))
        .dy;
    final expected = viewport.top + (viewport.height * 0.75);

    expect(controller.offset, greaterThan(0));
    expect(questionTop, closeTo(expected, 64));
  });

  testWidgets('timeline reacts when same lesson renders answer signals', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    Widget timeline(List<ChatLessonMessage> messages) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 360,
            child: ChatAulaTimeline(
              scrollController: controller,
              initialScrollToCurrent: true,
              initialScrollKey: 'same-lesson-live-scroll',
              padding: EdgeInsets.zero,
              messages: messages,
              onChooseAnswer: (_) {},
              onSignal: (_) {},
              onRetry: () {},
              onNext: () {},
              onOpenDoubt: () {},
            ),
          ),
        ),
      );
    }

    final baseMessages = [
      for (var i = 0; i < 18; i++)
        ChatLessonMessage(
          id: 'live-history-$i',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.historyQuestion,
          text: 'Histórico vivo $i\nlinha\nlinha\nlinha',
          isHistorical: true,
          isActionable: false,
        ),
      const ChatLessonMessage(
        id: 'live-question',
        role: ChatLessonMessageRole.sim,
        kind: ChatLessonMessageKind.question,
        text: 'Pergunta viva?',
        isActionable: false,
      ),
      const ChatLessonMessage(
        id: 'live-options',
        role: ChatLessonMessageRole.sim,
        kind: ChatLessonMessageKind.options,
        options: [
          ChatLessonOption(
            letter: AnswerLetter.A,
            text: 'A',
            selected: false,
            enabled: true,
          ),
          ChatLessonOption(
            letter: AnswerLetter.B,
            text: 'B',
            selected: false,
            enabled: true,
          ),
          ChatLessonOption(
            letter: AnswerLetter.C,
            text: 'C',
            selected: false,
            enabled: true,
          ),
        ],
      ),
      for (var i = 0; i < 18; i++)
        ChatLessonMessage(
          id: 'live-tail-$i',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.historyAnswer,
          text: 'Final vivo $i\nlinha',
          isHistorical: true,
          isActionable: false,
        ),
    ];

    await tester.pumpWidget(timeline(baseMessages));
    await tester.pumpAndSettle();
    final before = controller.offset;

    await tester.pumpWidget(
      timeline([
        ...baseMessages.take(19),
        const ChatLessonMessage(
          id: 'live-options',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.options,
          selectedAnswer: AnswerLetter.B,
          options: [
            ChatLessonOption(
              letter: AnswerLetter.A,
              text: 'A',
              selected: false,
              enabled: true,
            ),
            ChatLessonOption(
              letter: AnswerLetter.B,
              text: 'B',
              selected: true,
              enabled: true,
            ),
            ChatLessonOption(
              letter: AnswerLetter.C,
              text: 'C',
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
        ...baseMessages.skip(baseMessages.length - 18),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('signal-button-1')), findsOneWidget);
    expect(controller.offset, isNot(closeTo(before, 1)));
  });
}
