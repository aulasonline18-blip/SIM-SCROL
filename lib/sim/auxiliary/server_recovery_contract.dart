import '../state/student_learning_state.dart';

String _text(Object? value) => (value ?? '').toString().trim();

int _int(Object? value, [int fallback = 0]) {
  final parsed = value is num ? value.toInt() : int.tryParse(_text(value));
  return parsed ?? fallback;
}

JsonMap _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : {};

AnswerLetter _letter(Object? value) => switch (_text(value).toUpperCase()) {
  'B' => AnswerLetter.B,
  'C' => AnswerLetter.C,
  _ => AnswerLetter.A,
};

class ServerRecoveryQueueEntry {
  const ServerRecoveryQueueEntry({
    required this.recoveryId,
    required this.lessonLocalId,
    required this.marker,
    required this.itemIdx,
    required this.weaknessId,
    required this.reason,
    required this.severity,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.sessionId,
    this.requiredRepairEvidence = const {},
    this.attempts = const [],
  });

  final String recoveryId;
  final String lessonLocalId;
  final String? userId;
  final String? sessionId;
  final String marker;
  final int itemIdx;
  final String weaknessId;
  final String reason;
  final String severity;
  final String status;
  final JsonMap requiredRepairEvidence;
  final List<JsonMap> attempts;
  final String createdAt;
  final String updatedAt;

  bool get blocksConclusion =>
      status == 'pending' ||
      status == 'active' ||
      status == 'blocked' ||
      status == 'failed';

  factory ServerRecoveryQueueEntry.fromJson(JsonMap json) =>
      ServerRecoveryQueueEntry(
        recoveryId: _text(json['recoveryId']),
        lessonLocalId: _text(json['lessonLocalId']),
        userId: json['userId']?.toString(),
        sessionId: json['sessionId']?.toString(),
        marker: _text(json['marker']),
        itemIdx: _int(json['itemIdx']),
        weaknessId: _text(json['weaknessId']),
        reason: _text(json['reason']),
        severity: _text(json['severity']),
        status: _text(json['status']),
        requiredRepairEvidence: _map(json['requiredRepairEvidence']),
        attempts: (json['attempts'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => _map(item))
            .toList(),
        createdAt: _text(json['createdAt']),
        updatedAt: _text(json['updatedAt']),
      );
}

class ServerRecoveryItem {
  const ServerRecoveryItem({
    required this.recoveryId,
    required this.slotKey,
    required this.marker,
    required this.itemIdx,
    required this.weaknessId,
    required this.question,
    required this.options,
    required this.correctOption,
    required this.status,
    required this.schemaVersion,
    this.explanation = '',
    this.feedback = const {},
    this.humanError,
  });

  final String recoveryId;
  final String slotKey;
  final String marker;
  final int itemIdx;
  final String weaknessId;
  final String explanation;
  final String question;
  final Map<AnswerLetter, String> options;
  final AnswerLetter correctOption;
  final JsonMap feedback;
  final String status;
  final int schemaVersion;
  final JsonMap? humanError;

  bool get ready =>
      status == 'ready' &&
      question.isNotEmpty &&
      options[AnswerLetter.A]?.isNotEmpty == true &&
      options[AnswerLetter.B]?.isNotEmpty == true &&
      options[AnswerLetter.C]?.isNotEmpty == true;

  factory ServerRecoveryItem.fromJson(JsonMap json) {
    final options = _map(json['options']);
    return ServerRecoveryItem(
      recoveryId: _text(json['recoveryId']),
      slotKey: _text(json['slotKey']),
      marker: _text(json['marker']),
      itemIdx: _int(json['itemIdx']),
      weaknessId: _text(json['weaknessId']),
      explanation: _text(json['explanation']),
      question: _text(json['question']),
      options: {
        AnswerLetter.A: _text(options['A']),
        AnswerLetter.B: _text(options['B']),
        AnswerLetter.C: _text(options['C']),
      },
      correctOption: _letter(json['correctOption']),
      feedback: _map(json['feedback']),
      status: _text(json['status']),
      schemaVersion: _int(json['schemaVersion'], 1),
      humanError: json['humanError'] is Map ? _map(json['humanError']) : null,
    );
  }
}

class ServerRecoveryAnswerRequest {
  const ServerRecoveryAnswerRequest({
    required this.lessonLocalId,
    required this.recoveryId,
    required this.marker,
    required this.selectedOption,
    required this.signal,
    required this.idempotencyKey,
    required this.timestamp,
  });

  final String lessonLocalId;
  final String recoveryId;
  final String marker;
  final AnswerLetter selectedOption;
  final DecisionSignal signal;
  final String idempotencyKey;
  final String timestamp;

  JsonMap toJson() => {
    'action': 'answer',
    'lessonLocalId': lessonLocalId,
    'recoveryId': recoveryId,
    'marker': marker,
    'selectedOption': selectedOption.name,
    'signal': signal.value,
    'idempotencyKey': idempotencyKey,
    'timestamp': timestamp,
  };
}

class ServerRecoveryAnswerResult {
  const ServerRecoveryAnswerResult({
    required this.accepted,
    required this.duplicate,
    required this.correct,
    required this.repaired,
    required this.blocksConclusion,
    required this.mainProgressPreserved,
    this.humanError,
  });

  final bool accepted;
  final bool duplicate;
  final bool correct;
  final bool repaired;
  final bool blocksConclusion;
  final bool mainProgressPreserved;
  final JsonMap? humanError;

  factory ServerRecoveryAnswerResult.fromJson(JsonMap json) {
    final result = _map(json['result']);
    return ServerRecoveryAnswerResult(
      accepted: json['accepted'] == true,
      duplicate: json['duplicate'] == true,
      correct: result['correct'] == true,
      repaired: result['repaired'] == true,
      blocksConclusion: json['blocksConclusion'] == true,
      mainProgressPreserved: json['mainProgressPreserved'] != false,
      humanError: json['humanError'] is Map ? _map(json['humanError']) : null,
    );
  }
}

abstract class ServerRecoveryTransport {
  Future<JsonMap> postRecovery(JsonMap body);
}

class ServerRecoveryClient {
  const ServerRecoveryClient(this.transport);

  final ServerRecoveryTransport transport;

  Future<ServerRecoveryItem?> next({
    required String lessonLocalId,
    required String idempotencyKey,
  }) async {
    final json = await transport.postRecovery({
      'action': 'next',
      'lessonLocalId': lessonLocalId,
      'idempotencyKey': idempotencyKey,
    });
    final item = json['item'];
    if (item is! Map) return null;
    return ServerRecoveryItem.fromJson(_map(item));
  }

  Future<ServerRecoveryAnswerResult> answer(
    ServerRecoveryAnswerRequest request,
  ) async {
    final json = await transport.postRecovery(request.toJson());
    return ServerRecoveryAnswerResult.fromJson(json);
  }
}
