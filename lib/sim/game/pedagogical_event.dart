import '../state/student_learning_state.dart';

enum PedagogicalEventType {
  cardSeen,
  answerSelected,
  qualifierSelected,
  feedbackShown,
  cardAdvanced,
}

class PedagogicalEventContractException implements Exception {
  const PedagogicalEventContractException(this.message);

  final String message;

  @override
  String toString() => 'PedagogicalEventContractException: $message';
}

final class PedagogicalEvent {
  const PedagogicalEvent({
    required this.eventId,
    required this.lessonLocalId,
    required this.deckId,
    required this.cardId,
    required this.contentHash,
    required this.type,
    required this.sequence,
    required this.clientTimestampMs,
    this.answer,
    this.qualifier,
  });

  final String eventId;
  final String lessonLocalId;
  final String deckId;
  final String cardId;
  final String contentHash;
  final PedagogicalEventType type;
  final int sequence;
  final int clientTimestampMs;
  final AnswerLetter? answer;
  final DecisionSignal? qualifier;

  String get idempotencyKey =>
      '$lessonLocalId:$deckId:$cardId:$contentHash:$sequence:${type.name}';

  void validate() {
    _requiredString(eventId, 'eventId_required');
    _requiredKeyPart(lessonLocalId, 'lessonLocalId_required');
    _requiredKeyPart(deckId, 'deckId_required');
    _requiredKeyPart(cardId, 'cardId_required');
    _requiredKeyPart(contentHash, 'contentHash_required');
    if (sequence < 0) {
      throw const PedagogicalEventContractException(
        'sequence_must_be_nonnegative',
      );
    }
    if (clientTimestampMs <= 0) {
      throw const PedagogicalEventContractException(
        'clientTimestampMs_must_be_positive',
      );
    }

    switch (type) {
      case PedagogicalEventType.cardSeen:
      case PedagogicalEventType.cardAdvanced:
        if (answer != null) {
          throw const PedagogicalEventContractException(
            'answer_not_allowed_for_type',
          );
        }
        if (qualifier != null) {
          throw const PedagogicalEventContractException(
            'qualifier_not_allowed_for_type',
          );
        }
      case PedagogicalEventType.answerSelected:
        if (answer == null) {
          throw const PedagogicalEventContractException(
            'answer_required_for_type',
          );
        }
        if (qualifier != null) {
          throw const PedagogicalEventContractException(
            'qualifier_not_allowed_for_type',
          );
        }
      case PedagogicalEventType.qualifierSelected:
      case PedagogicalEventType.feedbackShown:
        if (answer == null) {
          throw const PedagogicalEventContractException(
            'answer_required_for_type',
          );
        }
        if (qualifier == null) {
          throw const PedagogicalEventContractException(
            'qualifier_required_for_type',
          );
        }
    }
  }

  Map<String, Object?> toJson() {
    validate();
    return {
      'eventId': eventId,
      'lessonLocalId': lessonLocalId,
      'deckId': deckId,
      'cardId': cardId,
      'contentHash': contentHash,
      'type': type.name,
      'sequence': sequence,
      'clientTimestampMs': clientTimestampMs,
      if (answer != null) 'answer': answer!.name,
      if (qualifier != null) 'qualifier': qualifier!.value,
    };
  }

  static PedagogicalEvent fromJson(Object? value) {
    if (value is! Map) {
      throw const PedagogicalEventContractException('event_must_be_object');
    }
    _rejectUnknownKeys(value, const {
      'eventId',
      'lessonLocalId',
      'deckId',
      'cardId',
      'contentHash',
      'type',
      'sequence',
      'clientTimestampMs',
      'answer',
      'qualifier',
    });
    return PedagogicalEvent(
      eventId: _requiredString(value['eventId'], 'eventId_required'),
      lessonLocalId: _requiredKeyPart(
        value['lessonLocalId'],
        'lessonLocalId_required',
      ),
      deckId: _requiredKeyPart(value['deckId'], 'deckId_required'),
      cardId: _requiredKeyPart(value['cardId'], 'cardId_required'),
      contentHash: _requiredKeyPart(
        value['contentHash'],
        'contentHash_required',
      ),
      type: _parseEventType(value['type']),
      sequence: _requiredInt(value['sequence'], 'sequence_required'),
      clientTimestampMs: _requiredInt(
        value['clientTimestampMs'],
        'clientTimestampMs_required',
      ),
      answer: _parseOptionalAnswer(value['answer']),
      qualifier: _parseOptionalQualifier(value['qualifier']),
    )..validate();
  }
}

String _requiredString(Object? value, String message) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    throw PedagogicalEventContractException(message);
  }
  return text;
}

String _requiredKeyPart(Object? value, String message) {
  final text = _requiredString(value, message);
  if (text.contains(':')) {
    throw const PedagogicalEventContractException(
      'idempotency_key_part_must_not_contain_separator',
    );
  }
  return text;
}

int _requiredInt(Object? value, String message) {
  if (value is int) {
    return value;
  }
  throw PedagogicalEventContractException(message);
}

PedagogicalEventType _parseEventType(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    throw const PedagogicalEventContractException('type_required');
  }
  return PedagogicalEventType.values.firstWhere(
    (type) => type.name == raw,
    orElse: () =>
        throw const PedagogicalEventContractException('type_not_allowed'),
  );
}

AnswerLetter? _parseOptionalAnswer(Object? value) {
  final raw = value?.toString().trim().toUpperCase();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return AnswerLetter.values.firstWhere(
    (letter) => letter.name == raw,
    orElse: () =>
        throw const PedagogicalEventContractException('answer_not_allowed'),
  );
}

DecisionSignal? _parseOptionalQualifier(Object? value) {
  if (value == null || value.toString().trim().isEmpty) {
    return null;
  }
  return switch (value) {
    1 || '1' => DecisionSignal.one,
    2 || '2' => DecisionSignal.two,
    3 || '3' => DecisionSignal.three,
    _ => throw const PedagogicalEventContractException('qualifier_not_allowed'),
  };
}

void _rejectUnknownKeys(Map value, Set<String> allowedKeys) {
  for (final key in value.keys) {
    if (!allowedKeys.contains(key)) {
      throw const PedagogicalEventContractException('event_has_unknown_key');
    }
  }
}
