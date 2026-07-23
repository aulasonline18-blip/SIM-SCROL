import 'pedagogical_event.dart';
import 'pedagogical_event_log.dart';

class GameSyncContractException implements Exception {
  const GameSyncContractException(this.message);

  final String message;

  @override
  String toString() => 'GameSyncContractException: $message';
}

enum GameSyncStatus { idle, ready, acked, partial, rejected }

final class GameSyncBatch {
  GameSyncBatch({
    required this.batchId,
    required List<PedagogicalEvent> events,
    required this.createdAtMs,
  }) : events = List<PedagogicalEvent>.unmodifiable(events) {
    validate();
  }

  static const maxEvents = 50;

  final String batchId;
  final List<PedagogicalEvent> events;
  final int createdAtMs;

  void validate() {
    _requiredString(batchId, 'batchId_required');
    if (createdAtMs <= 0) {
      throw const GameSyncContractException('createdAtMs_must_be_positive');
    }
    if (events.isEmpty) {
      throw const GameSyncContractException('events_required');
    }
    if (events.length > maxEvents) {
      throw const GameSyncContractException('events_exceed_maxEvents');
    }
    _validateEvents(events);
  }

  Map<String, Object?> toJson() {
    validate();
    return {
      'batchId': batchId,
      'events': events.map((event) => event.toJson()).toList(),
      'createdAtMs': createdAtMs,
    };
  }

  static GameSyncBatch fromJson(Object? value) {
    if (value is! Map) {
      throw const GameSyncContractException('batch_must_be_object');
    }
    _rejectUnknownKeys(value, const {'batchId', 'events', 'createdAtMs'});
    final rawEvents = value['events'];
    if (rawEvents is! List) {
      throw const GameSyncContractException('events_required');
    }
    return GameSyncBatch(
      batchId: _requiredString(value['batchId'], 'batchId_required'),
      events: rawEvents.map(PedagogicalEvent.fromJson).toList(),
      createdAtMs: _requiredInt(value['createdAtMs'], 'createdAtMs_required'),
    );
  }
}

final class GameSyncResult {
  GameSyncResult({
    required this.status,
    required Set<String> acceptedEventIds,
    required Set<String> rejectedEventIds,
    required Set<String> pendingEventIds,
  }) : acceptedEventIds = Set<String>.unmodifiable(acceptedEventIds),
       rejectedEventIds = Set<String>.unmodifiable(rejectedEventIds),
       pendingEventIds = Set<String>.unmodifiable(pendingEventIds) {
    validate();
  }

  final GameSyncStatus status;
  final Set<String> acceptedEventIds;
  final Set<String> rejectedEventIds;
  final Set<String> pendingEventIds;

  void validate() {
    for (final id in acceptedEventIds) {
      _requiredString(id, 'acceptedEventId_required');
    }
    for (final id in rejectedEventIds) {
      _requiredString(id, 'rejectedEventId_required');
    }
    for (final id in pendingEventIds) {
      _requiredString(id, 'pendingEventId_required');
    }
  }
}

final class GameSyncClient {
  final List<PedagogicalEvent> _pendingEvents = [];
  final Set<String> _acceptedEventIds = {};

  List<PedagogicalEvent> get pendingEvents =>
      List<PedagogicalEvent>.unmodifiable(_pendingEvents);

  Set<String> get acceptedEventIds =>
      Set<String>.unmodifiable(_acceptedEventIds);

  int get pendingCount => _pendingEvents.length;

  int get acceptedCount => _acceptedEventIds.length;

  bool get isIdle => _pendingEvents.isEmpty && _acceptedEventIds.isEmpty;

  GameSyncStatus get status =>
      _pendingEvents.isEmpty ? GameSyncStatus.idle : GameSyncStatus.ready;

  void enqueueFromLog(PedagogicalEventLog log) {
    log.validate();
    final candidate = List<PedagogicalEvent>.of(_pendingEvents);
    for (final event in log.events) {
      event.validate();
      if (_acceptedEventIds.contains(event.eventId)) {
        continue;
      }
      if (candidate.any((pending) => pending.eventId == event.eventId)) {
        continue;
      }
      if (candidate.any(
        (pending) => pending.idempotencyKey == event.idempotencyKey,
      )) {
        continue;
      }
      candidate.add(event);
    }
    _validateEvents(candidate);
    _pendingEvents
      ..clear()
      ..addAll(candidate);
  }

  GameSyncBatch prepareBatch({
    required String batchId,
    required int createdAtMs,
  }) {
    if (_pendingEvents.isEmpty) {
      throw const GameSyncContractException('pending_events_required');
    }
    return GameSyncBatch(
      batchId: batchId,
      events: _pendingEvents.take(GameSyncBatch.maxEvents).toList(),
      createdAtMs: createdAtMs,
    );
  }

  GameSyncResult applyAck(
    GameSyncBatch batch, {
    required Set<String> acceptedEventIds,
  }) {
    batch.validate();
    final batchIds = batch.events.map((event) => event.eventId).toSet();
    final accepted = Set<String>.unmodifiable(acceptedEventIds);
    for (final id in accepted) {
      _requiredString(id, 'acceptedEventId_required');
      if (!batchIds.contains(id)) {
        throw const GameSyncContractException('acceptedEventId_not_in_batch');
      }
    }
    final rejected = batchIds.difference(accepted);
    final candidateAccepted = Set<String>.of(_acceptedEventIds)
      ..addAll(accepted);
    final candidatePending = _pendingEvents
        .where((event) => !accepted.contains(event.eventId))
        .toList();
    _validateEvents(candidatePending);
    _pendingEvents
      ..clear()
      ..addAll(candidatePending);
    _acceptedEventIds
      ..clear()
      ..addAll(candidateAccepted);
    return GameSyncResult(
      status: _statusFor(batchIds.length, accepted.length),
      acceptedEventIds: accepted,
      rejectedEventIds: rejected,
      pendingEventIds: candidatePending.map((event) => event.eventId).toSet(),
    );
  }

  void clearAccepted() {
    _acceptedEventIds.clear();
  }

  void clearAll() {
    _pendingEvents.clear();
    _acceptedEventIds.clear();
  }

  void validate() {
    _validateEvents(_pendingEvents);
    for (final id in _acceptedEventIds) {
      _requiredString(id, 'acceptedEventId_required');
      if (_pendingEvents.any((event) => event.eventId == id)) {
        throw const GameSyncContractException(
          'acceptedEventId_must_not_be_pending',
        );
      }
    }
  }

  Map<String, Object?> toJson() {
    validate();
    return {
      'pendingEvents': _pendingEvents.map((event) => event.toJson()).toList(),
      'acceptedEventIds': _acceptedEventIds.toList(),
    };
  }

  static GameSyncClient fromJson(Object? value) {
    if (value is! Map) {
      throw const GameSyncContractException('sync_client_must_be_object');
    }
    _rejectUnknownKeys(value, const {'pendingEvents', 'acceptedEventIds'});
    final rawPending = value['pendingEvents'];
    final rawAccepted = value['acceptedEventIds'];
    if (rawPending is! List) {
      throw const GameSyncContractException('pendingEvents_required');
    }
    if (rawAccepted is! List) {
      throw const GameSyncContractException('acceptedEventIds_required');
    }
    final accepted = <String>{};
    for (final id in rawAccepted) {
      final parsed = _requiredString(id, 'acceptedEventId_required');
      if (!accepted.add(parsed)) {
        throw const GameSyncContractException('acceptedEventId_duplicated');
      }
    }
    final client = GameSyncClient();
    client._pendingEvents.addAll(rawPending.map(PedagogicalEvent.fromJson));
    client._acceptedEventIds.addAll(accepted);
    client.validate();
    return client;
  }
}

void _validateEvents(List<PedagogicalEvent> events) {
  final eventIds = <String>{};
  final keys = <String>{};
  for (final event in events) {
    event.validate();
    if (!eventIds.add(event.eventId)) {
      throw const GameSyncContractException('eventId_duplicated');
    }
    if (!keys.add(event.idempotencyKey)) {
      throw const GameSyncContractException('idempotencyKey_duplicated');
    }
  }
}

GameSyncStatus _statusFor(int total, int accepted) {
  if (accepted == total) {
    return GameSyncStatus.acked;
  }
  if (accepted == 0) {
    return GameSyncStatus.rejected;
  }
  return GameSyncStatus.partial;
}

String _requiredString(Object? value, String message) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    throw GameSyncContractException(message);
  }
  return text;
}

int _requiredInt(Object? value, String message) {
  if (value is int) {
    return value;
  }
  throw GameSyncContractException(message);
}

void _rejectUnknownKeys(Map value, Set<String> allowedKeys) {
  for (final key in value.keys) {
    if (!allowedKeys.contains(key)) {
      throw const GameSyncContractException('unknown_key');
    }
  }
}
