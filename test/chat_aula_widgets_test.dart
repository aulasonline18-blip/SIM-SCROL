import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/aula_widgets.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_widgets.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  setUp(() => setSimActiveLanguage('pt-BR'));

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
}
