import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_widgets.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  setUp(() => setSimActiveLanguage('pt-BR'));

  testWidgets('Chat aula widgets devem preservar aparencia atual', (
    tester,
  ) async {
    AnswerLetter? chosen;
    int? signal;
    var imageSettled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'contract-explanation',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.explanation,
                text: 'Explicacao de contrato visual.',
              ),
              ChatLessonMessage(
                id: 'contract-image',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.image,
                text: 'Imagem pedagogica',
                imageStatus: 'failed',
              ),
              ChatLessonMessage(
                id: 'contract-options',
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
                signals: [
                  ChatLessonSignal(
                    value: 1,
                    labelKey: 'aula_sig_certeza',
                    enabled: true,
                  ),
                ],
              ),
              ChatLessonMessage(
                id: 'contract-feedback',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.feedback,
                text: 'Feedback local vivo',
                isCorrect: true,
              ),
            ],
            onChooseAnswer: (letter) => chosen = letter,
            onSignal: (value) => signal = value,
            onRetry: () {},
            onNext: () {},
            onOpenDoubt: () {},
            onImageSettled: () => imageSettled = true,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('chat-aula-timeline')), findsOneWidget);
    expect(find.text('Explicacao de contrato visual.'), findsOneWidget);
    expect(find.byKey(const Key('chat-answer-card-A')), findsOneWidget);
    expect(find.byKey(const Key('signal-button-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-answer-card-B')));
    await tester.tap(find.byKey(const Key('signal-button-1')));
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('chat-aula-timeline')),
      const Offset(0, -500),
    );
    await tester.pump();

    expect(chosen, AnswerLetter.B);
    expect(signal, 1);
    expect(imageSettled, isTrue);
    expect(find.text('Feedback local vivo'), findsOneWidget);
  });
}
