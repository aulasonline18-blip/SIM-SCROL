part of '../chat_aula_widgets.dart';

class _ChatOptions extends StatelessWidget {
  const _ChatOptions({
    required this.message,
    required this.onChooseAnswer,
    required this.onSignal,
  });

  final ChatLessonMessage message;
  final void Function(AnswerLetter letter) onChooseAnswer;
  final void Function(int value) onSignal;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final option in message.options)
        AnswerButton(
          key: Key('chat-answer-card-${option.letter.name}'),
          letter: option.letter.name,
          text: option.text,
          selected: option.selected,
          enabled: option.enabled,
          onTap: option.enabled ? () => onChooseAnswer(option.letter) : null,
        ),
      if (message.signals.isNotEmpty) const SizedBox(height: 8),
      if (message.signals.isNotEmpty)
        _ChatSignals(message: message, onSignal: onSignal),
    ],
  );
}
