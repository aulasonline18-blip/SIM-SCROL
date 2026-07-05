import '../../sim/state/student_learning_state.dart';

enum ChatLessonMessageRole { sim, student, system }

enum ChatLessonDeliveryStatus {
  sending,
  sent,
  delivered,
  read,
  processing,
  failed,
}

enum ChatLessonMessageKind {
  loading,
  historyQuestion,
  historyAnswer,
  studentDoubt,
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
    this.mediaName,
    this.mediaType,
    this.mediaSize,
    this.selectedAnswer,
    this.selectedSignal,
    this.isCorrect,
    this.actionKey,
    this.imageStatus = 'idle',
    this.hasPaidImageOffer = false,
    this.progress,
    this.deliveryStatus = ChatLessonDeliveryStatus.delivered,
    this.timestampLabel,
    this.sequenceIndex,
  });

  final String id;
  final ChatLessonMessageRole role;
  final ChatLessonMessageKind kind;
  final String? text;
  final List<ChatLessonOption> options;
  final List<ChatLessonSignal> signals;
  final String? imageData;
  final String? mediaName;
  final String? mediaType;
  final int? mediaSize;
  final AnswerLetter? selectedAnswer;
  final DecisionSignal? selectedSignal;
  final bool? isCorrect;
  final String? actionKey;
  final String imageStatus;
  final bool hasPaidImageOffer;
  final int? progress;
  final ChatLessonDeliveryStatus deliveryStatus;
  final String? timestampLabel;
  final int? sequenceIndex;

  bool get hasInteractiveOptions =>
      kind == ChatLessonMessageKind.options && options.isNotEmpty;

  bool get hasInteractiveSignals =>
      kind == ChatLessonMessageKind.signals && signals.isNotEmpty;

  ChatLessonMessage copyWith({
    String? id,
    ChatLessonMessageRole? role,
    ChatLessonMessageKind? kind,
    String? text,
    List<ChatLessonOption>? options,
    List<ChatLessonSignal>? signals,
    String? imageData,
    String? mediaName,
    String? mediaType,
    int? mediaSize,
    AnswerLetter? selectedAnswer,
    DecisionSignal? selectedSignal,
    bool? isCorrect,
    String? actionKey,
    String? imageStatus,
    bool? hasPaidImageOffer,
    int? progress,
    ChatLessonDeliveryStatus? deliveryStatus,
    String? timestampLabel,
    int? sequenceIndex,
  }) {
    return ChatLessonMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      kind: kind ?? this.kind,
      text: text ?? this.text,
      options: options ?? this.options,
      signals: signals ?? this.signals,
      imageData: imageData ?? this.imageData,
      mediaName: mediaName ?? this.mediaName,
      mediaType: mediaType ?? this.mediaType,
      mediaSize: mediaSize ?? this.mediaSize,
      selectedAnswer: selectedAnswer ?? this.selectedAnswer,
      selectedSignal: selectedSignal ?? this.selectedSignal,
      isCorrect: isCorrect ?? this.isCorrect,
      actionKey: actionKey ?? this.actionKey,
      imageStatus: imageStatus ?? this.imageStatus,
      hasPaidImageOffer: hasPaidImageOffer ?? this.hasPaidImageOffer,
      progress: progress ?? this.progress,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      timestampLabel: timestampLabel ?? this.timestampLabel,
      sequenceIndex: sequenceIndex ?? this.sequenceIndex,
    );
  }
}
