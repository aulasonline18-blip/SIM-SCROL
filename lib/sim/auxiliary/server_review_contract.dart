import '../state/student_learning_state.dart';

String _text(Object? value) => (value ?? '').toString().trim();

int _int(Object? value, [int fallback = 0]) {
  final parsed = value is num ? value.toInt() : int.tryParse(_text(value));
  return parsed ?? fallback;
}

JsonMap _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : {};

JsonMap _safeStateEffect(Object? value) {
  final parsed = _map(value);
  return {
    'strongAdvance': parsed['strongAdvance'] == true,
    'writesProgress': parsed['writesProgress'] == true,
    'preservesCurrent': parsed['preservesCurrent'] != false,
    'preservesMainLesson': parsed['preservesMainLesson'] != false,
  };
}

AnswerLetter _letter(Object? value) => switch (_text(value).toUpperCase()) {
  'B' => AnswerLetter.B,
  'C' => AnswerLetter.C,
  _ => AnswerLetter.A,
};

class ServerReviewSchedule {
  const ServerReviewSchedule({
    required this.reviewId,
    required this.lessonLocalId,
    required this.marker,
    required this.itemIdx,
    required this.dueAt,
    required this.reviewType,
    required this.priority,
    required this.reason,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.sessionId,
    this.sourceEvidence = const {},
  });

  final String reviewId;
  final String lessonLocalId;
  final String? userId;
  final String? sessionId;
  final String marker;
  final int itemIdx;
  final String dueAt;
  final String reviewType;
  final String priority;
  final String reason;
  final JsonMap sourceEvidence;
  final bool completed;
  final String createdAt;
  final String updatedAt;

  factory ServerReviewSchedule.fromJson(JsonMap json) => ServerReviewSchedule(
    reviewId: _text(json['reviewId']),
    lessonLocalId: _text(json['lessonLocalId']),
    userId: json['userId']?.toString(),
    sessionId: json['sessionId']?.toString(),
    marker: _text(json['marker']),
    itemIdx: _int(json['itemIdx']),
    dueAt: _text(json['dueAt']),
    reviewType: _text(json['reviewType']),
    priority: _text(json['priority']),
    reason: _text(json['reason']),
    sourceEvidence: _map(json['sourceEvidence']),
    completed: json['completed'] == true,
    createdAt: _text(json['createdAt']),
    updatedAt: _text(json['updatedAt']),
  );
}

class ServerReviewItem {
  const ServerReviewItem({
    required this.reviewId,
    required this.slotKey,
    required this.marker,
    required this.itemIdx,
    required this.question,
    required this.options,
    required this.correctOption,
    required this.status,
    required this.schemaVersion,
    required this.updatedAt,
    this.explanation = '',
    this.feedback = const {},
    this.contractVersion = 'sim.auxiliary.review.v1',
    this.flow = 'review',
    this.nextAction = 'show_aux_room',
    this.stateEffect = const {},
    this.humanError,
  });

  final String reviewId;
  final String slotKey;
  final String marker;
  final int itemIdx;
  final String question;
  final Map<AnswerLetter, String> options;
  final AnswerLetter correctOption;
  final String explanation;
  final JsonMap feedback;
  final String contractVersion;
  final String flow;
  final String nextAction;
  final JsonMap stateEffect;
  final String status;
  final int schemaVersion;
  final String updatedAt;
  final JsonMap? humanError;

  bool get ready =>
      status == 'ready' &&
      question.isNotEmpty &&
      options[AnswerLetter.A]?.isNotEmpty == true &&
      options[AnswerLetter.B]?.isNotEmpty == true &&
      options[AnswerLetter.C]?.isNotEmpty == true;

  factory ServerReviewItem.fromJson(JsonMap json) {
    final rawOptions = _map(json['options']);
    return ServerReviewItem(
      reviewId: _text(json['reviewId']),
      slotKey: _text(json['slotKey']),
      marker: _text(json['marker']),
      itemIdx: _int(json['itemIdx']),
      question: _text(json['question']),
      options: {
        AnswerLetter.A: _text(rawOptions['A']),
        AnswerLetter.B: _text(rawOptions['B']),
        AnswerLetter.C: _text(rawOptions['C']),
      },
      correctOption: _letter(json['correctOption']),
      explanation: _text(json['explanation']),
      feedback: _map(json['feedback']),
      contractVersion: _text(json['contractVersion']).isEmpty
          ? 'sim.auxiliary.review.v1'
          : _text(json['contractVersion']),
      flow: _text(json['flow']).isEmpty ? 'review' : _text(json['flow']),
      nextAction: _text(json['nextAction']).isEmpty
          ? 'show_aux_room'
          : _text(json['nextAction']),
      stateEffect: _safeStateEffect(json['stateEffect']),
      status: _text(json['status']),
      schemaVersion: _int(json['schemaVersion'], 1),
      updatedAt: _text(json['updatedAt']),
      humanError: json['humanError'] is Map ? _map(json['humanError']) : null,
    );
  }
}

class ServerReviewAnswerRequest {
  const ServerReviewAnswerRequest({
    required this.lessonLocalId,
    required this.reviewId,
    required this.marker,
    required this.selectedOption,
    required this.signal,
    required this.idempotencyKey,
    required this.timestamp,
  });

  final String lessonLocalId;
  final String reviewId;
  final String marker;
  final AnswerLetter selectedOption;
  final DecisionSignal signal;
  final String idempotencyKey;
  final String timestamp;

  JsonMap toJson() => {
    'action': 'answer',
    'lessonLocalId': lessonLocalId,
    'reviewId': reviewId,
    'marker': marker,
    'selectedOption': selectedOption.name,
    'signal': signal.value,
    'idempotencyKey': idempotencyKey,
    'timestamp': timestamp,
  };
}

class ServerReviewAnswerResult {
  const ServerReviewAnswerResult({
    required this.accepted,
    required this.duplicate,
    required this.correct,
    required this.mainProgressPreserved,
    this.humanError,
    this.contractVersion = 'sim.auxiliary.review.v1',
    this.flow = 'review',
    this.nextAction = 'return_to_lesson',
    this.stateEffect = const {},
  });

  final bool accepted;
  final bool duplicate;
  final bool correct;
  final bool mainProgressPreserved;
  final JsonMap? humanError;
  final String contractVersion;
  final String flow;
  final String nextAction;
  final JsonMap stateEffect;

  factory ServerReviewAnswerResult.fromJson(JsonMap json) {
    final result = _map(json['result']);
    return ServerReviewAnswerResult(
      accepted: json['accepted'] == true,
      duplicate: json['duplicate'] == true,
      correct: result['correct'] == true,
      mainProgressPreserved: json['mainProgressPreserved'] != false,
      humanError: json['humanError'] is Map ? _map(json['humanError']) : null,
      contractVersion: _text(json['contractVersion']).isEmpty
          ? 'sim.auxiliary.review.v1'
          : _text(json['contractVersion']),
      flow: _text(json['flow']).isEmpty ? 'review' : _text(json['flow']),
      nextAction: _text(json['nextAction']).isEmpty
          ? 'return_to_lesson'
          : _text(json['nextAction']),
      stateEffect: _safeStateEffect(json['stateEffect']),
    );
  }
}

abstract class ServerReviewTransport {
  Future<JsonMap> postReview(JsonMap body);
}

class ServerReviewClient {
  const ServerReviewClient(this.transport);

  final ServerReviewTransport transport;

  Future<ServerReviewItem?> next({
    required String lessonLocalId,
    required String idempotencyKey,
  }) async {
    final json = await transport.postReview({
      'action': 'next',
      'lessonLocalId': lessonLocalId,
      'idempotencyKey': idempotencyKey,
    });
    final item = json['item'];
    if (item is! Map) return null;
    return ServerReviewItem.fromJson(_map(item));
  }

  Future<ServerReviewAnswerResult> answer(
    ServerReviewAnswerRequest request,
  ) async {
    final json = await transport.postReview(request.toJson());
    return ServerReviewAnswerResult.fromJson(json);
  }
}
