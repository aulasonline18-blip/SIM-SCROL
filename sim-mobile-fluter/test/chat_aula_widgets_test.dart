import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_widgets.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

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
          ),
        ),
      ),
    );

    await tester.tap(find.text('2'));
    expect(signal, 2);

    await tester.tap(find.text('Tentar novamente'));
    expect(retries, 1);
  });
}
