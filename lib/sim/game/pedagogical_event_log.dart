import 'pedagogical_event.dart';

class PedagogicalEventLogContractException implements Exception {
  const PedagogicalEventLogContractException(this.message);

  final String message;

  @override
  String toString() => 'PedagogicalEventLogContractException: $message';
}

final class PedagogicalEventLog {
  PedagogicalEventLog([List<PedagogicalEvent> initialEvents = const []]) {
    for (final event in initialEvents) {
      append(event);
    }
  }

  final List<PedagogicalEvent> _events = [];

  List<PedagogicalEvent> get events =>
      List<PedagogicalEvent>.unmodifiable(_events);

  int get length => _events.length;

  bool get isEmpty => _events.isEmpty;

  void append(PedagogicalEvent event) {
    event.validate();
    if (containsEventId(event.eventId)) {
      throw const PedagogicalEventLogContractException('eventId_duplicated');
    }
    if (containsIdempotencyKey(event.idempotencyKey)) {
      throw const PedagogicalEventLogContractException(
        'idempotencyKey_duplicated',
      );
    }
    _events.add(event);
  }

  bool containsEventId(String eventId) =>
      _events.any((event) => event.eventId == eventId);

  bool containsIdempotencyKey(String key) =>
      _events.any((event) => event.idempotencyKey == key);

  void clear() {
    _events.clear();
  }

  void validate() {
    final eventIds = <String>{};
    final idempotencyKeys = <String>{};
    for (final event in _events) {
      event.validate();
      if (!eventIds.add(event.eventId)) {
        throw const PedagogicalEventLogContractException('eventId_duplicated');
      }
      if (!idempotencyKeys.add(event.idempotencyKey)) {
        throw const PedagogicalEventLogContractException(
          'idempotencyKey_duplicated',
        );
      }
    }
  }

  Map<String, Object?> toJson() {
    validate();
    return {'events': _events.map((event) => event.toJson()).toList()};
  }

  static PedagogicalEventLog fromJson(Object? value) {
    if (value is! Map) {
      throw const PedagogicalEventLogContractException(
        'event_log_must_be_object',
      );
    }
    _rejectUnknownKeys(value, const {'events'});
    final rawEvents = value['events'];
    if (rawEvents is! List) {
      throw const PedagogicalEventLogContractException('events_required');
    }
    return PedagogicalEventLog(
      rawEvents.map(PedagogicalEvent.fromJson).toList(),
    )..validate();
  }
}

void _rejectUnknownKeys(Map value, Set<String> allowedKeys) {
  for (final key in value.keys) {
    if (!allowedKeys.contains(key)) {
      throw const PedagogicalEventLogContractException(
        'event_log_has_unknown_key',
      );
    }
  }
}
