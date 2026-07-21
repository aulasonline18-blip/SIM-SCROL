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
  review,
  recovery,
  itemIntro,
  explanation,
  image,
  practiceAction,
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

enum AulaConversationBlockType {
  itemIntro,
  explanation,
  visual,
  practiceAction,
  question,
  answerOptions,
  signalOptions,
  studentAnswer,
  studentSignal,
  feedback,
  advanceAction,
  loading,
  recoverableError,
  studentDoubt,
  doubtAnswer,
  review,
  recovery,
  historyQuestion,
  unsupported,
}

enum AulaConversationAction {
  chooseAnswer,
  submitSignal,
  advance,
  retry,
  openDoubt,
}

class AulaConversationBlock {
  const AulaConversationBlock({
    required this.id,
    required this.type,
    required this.role,
    required this.active,
    required this.deliveryStatus,
    required this.message,
    this.text,
    this.imageData,
    this.options = const [],
    this.signals = const [],
    this.action,
    this.metadata = const {},
  });

  final String id;
  final AulaConversationBlockType type;
  final ChatLessonMessageRole role;
  final bool active;
  final ChatLessonDeliveryStatus deliveryStatus;
  final ChatLessonMessage message;
  final String? text;
  final String? imageData;
  final List<ChatLessonOption> options;
  final List<ChatLessonSignal> signals;
  final AulaConversationAction? action;
  final Map<String, Object?> metadata;

  bool get isHistorical => !active;

  static AulaConversationBlock fromMessage(ChatLessonMessage message) {
    final type = _typeFor(message);
    return AulaConversationBlock(
      id: 'aula-block-${message.id}',
      type: type,
      role: message.role,
      active: message.isActionable && !message.isHistorical,
      deliveryStatus: message.deliveryStatus,
      message: message,
      text: message.text,
      imageData: message.imageData,
      options: message.options,
      signals: message.signals,
      action: _actionFor(message, type),
      metadata: {
        'messageId': message.id,
        'kind': message.kind.name,
        'lessonLocalId': message.lessonLocalId,
        'marker': message.marker,
        'itemIdx': message.itemIdx,
        'layer': message.layer,
        'actionKey': message.actionKey,
      },
    );
  }

  static AulaConversationBlockType _typeFor(ChatLessonMessage message) {
    return switch (message.kind) {
      ChatLessonMessageKind.itemIntro => AulaConversationBlockType.itemIntro,
      ChatLessonMessageKind.explanation =>
        AulaConversationBlockType.explanation,
      ChatLessonMessageKind.image => AulaConversationBlockType.visual,
      ChatLessonMessageKind.practiceAction =>
        AulaConversationBlockType.practiceAction,
      ChatLessonMessageKind.question => AulaConversationBlockType.question,
      ChatLessonMessageKind.options => AulaConversationBlockType.answerOptions,
      ChatLessonMessageKind.signals => AulaConversationBlockType.signalOptions,
      ChatLessonMessageKind.studentAnswer ||
      ChatLessonMessageKind.historyAnswer =>
        AulaConversationBlockType.studentAnswer,
      ChatLessonMessageKind.studentSignal =>
        AulaConversationBlockType.studentSignal,
      ChatLessonMessageKind.feedback =>
        (message.actionKey ?? '').isEmpty && !message.id.startsWith('feedback-')
            ? AulaConversationBlockType.doubtAnswer
            : AulaConversationBlockType.feedback,
      ChatLessonMessageKind.doubtAction =>
        AulaConversationBlockType.advanceAction,
      ChatLessonMessageKind.loading ||
      ChatLessonMessageKind.processing => AulaConversationBlockType.loading,
      ChatLessonMessageKind.error => AulaConversationBlockType.recoverableError,
      ChatLessonMessageKind.studentDoubt =>
        AulaConversationBlockType.studentDoubt,
      ChatLessonMessageKind.review => AulaConversationBlockType.review,
      ChatLessonMessageKind.recovery => AulaConversationBlockType.recovery,
      ChatLessonMessageKind.historyQuestion =>
        AulaConversationBlockType.historyQuestion,
    };
  }

  static AulaConversationAction? _actionFor(
    ChatLessonMessage message,
    AulaConversationBlockType type,
  ) {
    if (!message.isActionable || message.isHistorical) return null;
    return switch (type) {
      AulaConversationBlockType.answerOptions =>
        AulaConversationAction.chooseAnswer,
      AulaConversationBlockType.signalOptions =>
        AulaConversationAction.submitSignal,
      AulaConversationBlockType.feedback => null,
      AulaConversationBlockType.advanceAction =>
        message.kind == ChatLessonMessageKind.doubtAction
            ? AulaConversationAction.openDoubt
            : null,
      AulaConversationBlockType.practiceAction => AulaConversationAction.advance,
      AulaConversationBlockType.recoverableError => null,
      _ => null,
    };
  }
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
    this.lessonLocalId,
    this.marker,
    this.unit,
    this.title,
    this.itemIdx,
    this.layer,
    this.createdAt,
    this.isHistorical = false,
    this.isActionable = true,
    this.imageStatus = 'idle',
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
  final String? lessonLocalId;
  final String? marker;
  final String? unit;
  final String? title;
  final int? itemIdx;
  final int? layer;
  final int? createdAt;
  final bool isHistorical;
  final bool isActionable;
  final String imageStatus;
  final int? progress;
  final ChatLessonDeliveryStatus deliveryStatus;
  final String? timestampLabel;
  final int? sequenceIndex;

  bool get hasInteractiveOptions =>
      isActionable &&
      kind == ChatLessonMessageKind.options &&
      options.any((option) => option.enabled);

  bool get hasInteractiveSignals =>
      isActionable &&
      kind == ChatLessonMessageKind.signals &&
      signals.any((signal) => signal.enabled);

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
    String? lessonLocalId,
    String? marker,
    String? unit,
    String? title,
    int? itemIdx,
    int? layer,
    int? createdAt,
    bool? isHistorical,
    bool? isActionable,
    String? imageStatus,
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
      lessonLocalId: lessonLocalId ?? this.lessonLocalId,
      marker: marker ?? this.marker,
      unit: unit ?? this.unit,
      title: title ?? this.title,
      itemIdx: itemIdx ?? this.itemIdx,
      layer: layer ?? this.layer,
      createdAt: createdAt ?? this.createdAt,
      isHistorical: isHistorical ?? this.isHistorical,
      isActionable: isActionable ?? this.isActionable,
      imageStatus: imageStatus ?? this.imageStatus,
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
    'lessonLocalId': lessonLocalId,
    'marker': marker,
    'unit': unit,
    'title': title,
    'itemIdx': itemIdx,
    'layer': layer,
    'createdAt': createdAt,
    'isHistorical': isHistorical,
    'isActionable': isActionable,
    'imageStatus': imageStatus,
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
      lessonLocalId: _stringOrNull(raw['lessonLocalId']),
      marker: _stringOrNull(raw['marker']),
      unit: _stringOrNull(raw['unit']),
      title: _stringOrNull(raw['title']),
      itemIdx: _intOrNull(raw['itemIdx']),
      layer: _intOrNull(raw['layer']),
      createdAt: _intOrNull(raw['createdAt']),
      isHistorical: raw['isHistorical'] is bool
          ? raw['isHistorical'] as bool
          : false,
      isActionable: raw['isActionable'] is bool
          ? raw['isActionable'] as bool
          : true,
      imageStatus: _stringOrNull(raw['imageStatus']) ?? 'idle',
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
