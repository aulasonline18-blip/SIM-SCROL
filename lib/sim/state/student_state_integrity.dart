enum StudentStateIntegrityKind { state, events }

class StudentStateIntegrityIssue {
  const StudentStateIntegrityIssue({
    required this.kind,
    required this.lessonLocalId,
    required this.code,
    required this.payload,
  });

  final StudentStateIntegrityKind kind;
  final String lessonLocalId;
  final String code;
  final String payload;
}

abstract interface class StudentStateQuarantineStorage {
  void quarantinePayload({
    required StudentStateIntegrityKind kind,
    required String lessonLocalId,
    required String payload,
    required String code,
  });

  String? readQuarantinedPayload({
    required StudentStateIntegrityKind kind,
    required String lessonLocalId,
  });
}

enum StudentStatePersistenceStatus { idle, pending, confirmed, failed }

class StudentStatePersistenceAudit {
  const StudentStatePersistenceAudit({
    required this.status,
    required this.operation,
    required this.lessonLocalId,
    this.code,
  });

  final StudentStatePersistenceStatus status;
  final String operation;
  final String lessonLocalId;
  final String? code;
}
