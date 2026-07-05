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

  Map<String, Object?> toJson() => {
    'letter': letter.name,
    'text': text,
    'selected': selected,
    'enabled': enabled,
  };

  static ChatLessonOption? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final letter = _enumByName(AnswerLetter.values, raw['letter']);
    final text = raw['text'];
    final selected = raw['selected'];
    final enabled = raw['enabled'];
    if (letter == null || text is! String) return null;
    return ChatLessonOption(
      letter: letter,
      text: text,
      selected: selected is bool ? selected : false,
      enabled: enabled is bool ? enabled : false,
    );
  }
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

  Map<String, Object?> toJson() => {
    'value': value,
    'labelKey': labelKey,
    'enabled': enabled,
  };

  static ChatLessonSignal? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final value = raw['value'];
    final labelKey = raw['labelKey'];
    final enabled = raw['enabled'];
    if (value is! int || labelKey is! String) return null;
    return ChatLessonSignal(
      value: value,
      labelKey: labelKey,
      enabled: enabled is bool ? enabled : false,
    );
  }
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

  Map<String, Object?> toJson({bool includeInlineImageData = true}) => {
    'id': id,
    'role': role.name,
    'kind': kind.name,
    'text': text,
    'options': options.map((option) => option.toJson()).toList(),
    'signals': signals.map((signal) => signal.toJson()).toList(),
    'imageData': includeInlineImageData ? imageData : null,
    'mediaName': mediaName,
    'mediaType': mediaType,
    'mediaSize': mediaSize,
    'selectedAnswer': selectedAnswer?.name,
    'selectedSignal': selectedSignal?.name,
    'isCorrect': isCorrect,
    'actionKey': actionKey,
    'imageStatus': imageStatus,
    'hasPaidImageOffer': hasPaidImageOffer,
    'progress': progress,
    'deliveryStatus': deliveryStatus.name,
    'timestampLabel': timestampLabel,
    'sequenceIndex': sequenceIndex,
  };

  static ChatLessonMessage? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final role = _enumByName(ChatLessonMessageRole.values, raw['role']);
    final kind = _enumByName(ChatLessonMessageKind.values, raw['kind']);
    if (id is! String || role == null || kind == null) return null;
    return ChatLessonMessage(
      id: id,
      role: role,
      kind: kind,
      text: _stringOrNull(raw['text']),
      options: _listOf(raw['options'], ChatLessonOption.fromJson),
      signals: _listOf(raw['signals'], ChatLessonSignal.fromJson),
      imageData: _stringOrNull(raw['imageData']),
      mediaName: _stringOrNull(raw['mediaName']),
      mediaType: _stringOrNull(raw['mediaType']),
      mediaSize: _intOrNull(raw['mediaSize']),
      selectedAnswer: _enumByName(AnswerLetter.values, raw['selectedAnswer']),
      selectedSignal: _enumByName(DecisionSignal.values, raw['selectedSignal']),
      isCorrect: raw['isCorrect'] is bool ? raw['isCorrect'] as bool : null,
      actionKey: _stringOrNull(raw['actionKey']),
      imageStatus: _stringOrNull(raw['imageStatus']) ?? 'idle',
      hasPaidImageOffer: raw['hasPaidImageOffer'] is bool
          ? raw['hasPaidImageOffer'] as bool
          : false,
      progress: _intOrNull(raw['progress']),
      deliveryStatus:
          _enumByName(ChatLessonDeliveryStatus.values, raw['deliveryStatus']) ??
          ChatLessonDeliveryStatus.delivered,
      timestampLabel: _stringOrNull(raw['timestampLabel']),
      sequenceIndex: _intOrNull(raw['sequenceIndex']),
    );
  }
}

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

String? _stringOrNull(Object? value) => value is String ? value : null;

int? _intOrNull(Object? value) => value is int ? value : null;

List<T> _listOf<T>(Object? raw, T? Function(Object? item) parse) {
  if (raw is! List) return const [];
  return raw.map(parse).whereType<T>().toList(growable: false);
}
