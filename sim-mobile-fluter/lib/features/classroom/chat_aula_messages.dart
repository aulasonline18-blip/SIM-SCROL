import '../../sim/state/student_learning_state.dart';

enum ChatLessonMessageRole { sim, student, system }

enum ChatLessonMessageKind {
  loading,
  historyQuestion,
  historyAnswer,
  explanation,
  image,
  question,
  options,
  studentAnswer,
  signals,
  studentSignal,
  doubtAction,
  processing,
  feedback,
  error,
}

class ChatLessonOption {
  const ChatLessonOption({
    required this.letter,
    required this.text,
    required this.selected,
    required this.enabled,
  });

  final AnswerLetter letter;
  final String text;
  final bool selected;
  final bool enabled;
}

class ChatLessonSignal {
  const ChatLessonSignal({
    required this.value,
    required this.labelKey,
    required this.enabled,
  });

  final int value;
  final String labelKey;
  final bool enabled;
}

class ChatLessonMessage {
  const ChatLessonMessage({
    required this.id,
    required this.role,
    required this.kind,
    this.text,
    this.options = const [],
    this.signals = const [],
    this.imageData,
    this.selectedAnswer,
    this.selectedSignal,
    this.isCorrect,
    this.actionKey,
    this.imageStatus = 'idle',
    this.hasPaidImageOffer = false,
    this.progress,
  });

  final String id;
  final ChatLessonMessageRole role;
  final ChatLessonMessageKind kind;
  final String? text;
  final List<ChatLessonOption> options;
  final List<ChatLessonSignal> signals;
  final String? imageData;
  final AnswerLetter? selectedAnswer;
  final DecisionSignal? selectedSignal;
  final bool? isCorrect;
  final String? actionKey;
  final String imageStatus;
  final bool hasPaidImageOffer;
  final int? progress;

  bool get hasInteractiveOptions =>
      kind == ChatLessonMessageKind.options && options.isNotEmpty;

  bool get hasInteractiveSignals =>
      kind == ChatLessonMessageKind.signals && signals.isNotEmpty;
}
