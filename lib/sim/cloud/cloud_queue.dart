import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'cloud_functions.dart';
import 'supabase_client_contract.dart';

enum StudentLearningSyncOperation { patch, tombstone }

enum CloudQueueEntryStatus { queued, blocked }

class CloudQueueStorageException implements Exception {
  const CloudQueueStorageException(this.code);

  final String code;

  @override
  String toString() => code;
}

class CloudQueueEntry {
  const CloudQueueEntry({
    this.id,
    required this.lessonLocalId,
    required this.operation,
    required this.pendingSince,
    required this.attempts,
    required this.nextRetryAt,
    this.status = CloudQueueEntryStatus.queued,
    this.lastFailureCode,
  });

  final String? id;
  final String lessonLocalId;
  final StudentLearningSyncOperation operation;
  final int pendingSince;
  final int attempts;
  final int nextRetryAt;
  final CloudQueueEntryStatus status;
  final String? lastFailureCode;

  String get stableId =>
      id ??
      stableCloudQueueItemId(
        lessonLocalId: lessonLocalId,
        operation: operation,
        pendingSince: pendingSince,
      );

  CloudQueueEntry copyWith({
    String? id,
    StudentLearningSyncOperation? operation,
    int? pendingSince,
    int? attempts,
    int? nextRetryAt,
    CloudQueueEntryStatus? status,
    String? lastFailureCode,
  }) {
    return CloudQueueEntry(
      id: id ?? this.id,
      lessonLocalId: lessonLocalId,
      operation: operation ?? this.operation,
      pendingSince: pendingSince ?? this.pendingSince,
      attempts: attempts ?? this.attempts,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      status: status ?? this.status,
      lastFailureCode: lastFailureCode ?? this.lastFailureCode,
    );
  }

  JsonMap toRedactedDebugJson() => {
    'id': stableId,
    'operation': operation.name,
    'pendingSince': pendingSince,
    'attempts': attempts,
    'nextRetryAt': nextRetryAt,
    'status': status.name,
    if (lastFailureCode != null) 'lastFailureCode': lastFailureCode,
  };
}

abstract interface class CloudQueueStorage {
  Map<String, CloudQueueEntry> readQueue();
  void writeQueue(Map<String, CloudQueueEntry> queue);
  Map<String, String> readLastHashes();
  void writeLastHash(String lessonLocalId, String hash);
}

abstract interface class DurableCloudQueueStorage implements CloudQueueStorage {
  Future<void> verifyQueueWrite();
  Future<void> verifyHashWrite();
}

class MemoryCloudQueueStorage implements CloudQueueStorage {
  Map<String, CloudQueueEntry> queue = {};
  Map<String, String> hashes = {};

  @override
  Map<String, CloudQueueEntry> readQueue() => Map.of(queue);

  @override
  void writeQueue(Map<String, CloudQueueEntry> queue) {
    this.queue = Map.of(queue);
  }

  @override
  Map<String, String> readLastHashes() => Map.of(hashes);

  @override
  void writeLastHash(String lessonLocalId, String hash) {
    hashes[lessonLocalId] = hash;
  }
}

class CloudQueue with WidgetsBindingObserver {
  CloudQueue({
    required this.storage,
    required this.stateService,
    required this.sessionProvider,
    required this.cloudFunctions,
    this.now,
    this.enableRetryTimers = true,
  });

  static const int debounceMs = 1500;
  static const List<int> retryDelaysMs = [2000, 5000, 15000, 60000, 300000];
  static const int maxAttempts = 10;

  final CloudQueueStorage storage;
  final StudentLearningStateService stateService;
  final SupabaseSessionProvider sessionProvider;
  final StudentStateCloudFunctions cloudFunctions;
  final int Function()? now;
  final bool enableRetryTimers;
  bool draining = false;
  final Map<String, Timer> _retryTimers = {};
  final Set<String> _flushingIds = {};

  int get _now => now?.call() ?? DateTime.now().millisecondsSinceEpoch;

  Future<void> enqueueStudentStateSync({
    required String lessonLocalId,
    StudentLearningSyncOperation operation = StudentLearningSyncOperation.patch,
  }) async {
    if (lessonLocalId.isEmpty) return;
    final bag = storage.readQueue();
    final prev = bag[lessonLocalId];
    final pendingSince = prev?.pendingSince ?? _now;
    bag[lessonLocalId] = CloudQueueEntry(
      id:
          prev?.id ??
          stableCloudQueueItemId(
            lessonLocalId: lessonLocalId,
            operation: operation,
            pendingSince: pendingSince,
          ),
      lessonLocalId: lessonLocalId,
      operation: operation,
      pendingSince: pendingSince,
      attempts: 0,
      nextRetryAt: _now + debounceMs,
    );
    await _writeQueue(bag);
  }

  Future<void> drainQueue({bool force = true}) async {
    if (draining) return;
    draining = true;
    try {
      final ids = storage.readQueue().keys.toList(growable: false);
      for (final id in ids) {
        await flushOne(id, force: force);
      }
    } finally {
      draining = false;
    }
  }

  Future<void> flushOne(String lessonLocalId, {bool force = false}) async {
    if (_flushingIds.contains(lessonLocalId)) return;
    final entry = storage.readQueue()[lessonLocalId];
    if (entry == null) return;
    if (entry.status == CloudQueueEntryStatus.blocked) return;
    if (!force && entry.nextRetryAt > _now) return;
    _flushingIds.add(lessonLocalId);
    try {
      final session = await sessionProvider.currentSession();
      if (session == null) {
        _markSyncBlocked(
          lessonLocalId,
          entry,
          reason: 'missing_authenticated_session',
        );
        await _scheduleRetry(entry, 'SYNC_SESSION_UNAVAILABLE');
        return;
      }
      final snap = stateService.read(lessonLocalId);
      if (snap == null) {
        _markSyncFailed(lessonLocalId, entry, 'local_state_missing');
        await _scheduleRetry(entry, 'SYNC_LOCAL_STATE_MISSING');
        return;
      }
      if (entry.operation == StudentLearningSyncOperation.tombstone ||
          snap.extra['deletedAt'] != null) {
        await cloudFunctions.deleteStudentStateByLesson(lessonLocalId, session);
        await _writeLastHash(lessonLocalId, 'tombstone:${snap.updatedAt}');
        await _remove(lessonLocalId);
        return;
      }
      final remoteSnap = snap.toRemoteVaultState();
      final contentHash = stableHash(remoteSnap);
      if (storage.readLastHashes()[lessonLocalId] == contentHash) {
        await _remove(lessonLocalId);
        return;
      }
      final result = await cloudFunctions.persistStudentState(
        PersistStudentStateInput(
          lessonLocalId: lessonLocalId,
          state: remoteSnap,
          clientUpdatedAt: snap.updatedAt,
          clientScore: scoreOfStudentLearningState(remoteSnap),
          schemaVersion: remoteSnap.stateVersion,
          stateJson: snap.toRemoteVaultJson(),
        ),
        session,
      );
      if (result.rejected && result.remoteState != null) {
        stateService.write(
          _withSyncEvent(
            mergeValidatedRemoteState(snap, result.remoteState!),
            'REMOTE_VAULT_SYNC_REJECTED',
            entry,
            status: 'blocked_regression',
            message: 'remote_state_stronger',
            highWaterMark: result.remoteHighWaterMark,
          ),
          acceptServerAuthority: false,
          allowLocalHousekeeping: true,
          scheduleShadow: false,
        );
        await enqueueStudentStateSync(lessonLocalId: lessonLocalId);
        return;
      }
      stateService.write(
        _withSyncEvent(
          snap,
          'REMOTE_VAULT_SYNC_CONFIRMED',
          entry,
          status: 'synced',
          highWaterMark: result.highWaterMark,
        ),
        scheduleShadow: false,
      );
      await _writeLastHash(lessonLocalId, contentHash);
      await _remove(lessonLocalId);
    } catch (error) {
      _markSyncFailed(lessonLocalId, entry, _safeSyncFailureCode(error));
      await _scheduleRetry(entry, _safeSyncFailureCode(error));
    } finally {
      _flushingIds.remove(lessonLocalId);
    }
  }

  Map<String, CloudQueueEntry> getQueueSnapshot() => storage.readQueue();

  Map<String, JsonMap> internalDebugSnapshotForTest() => {
    for (final entry in storage.readQueue().values)
      entry.stableId: entry.toRedactedDebugJson(),
  };

  void wireCloudQueueLifecycle() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(Future.delayed(const Duration(seconds: 1), () => drainQueue()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      unawaited(drainQueue(force: true));
    }
  }

  Future<void> _remove(String lessonLocalId) async {
    final bag = storage.readQueue()..remove(lessonLocalId);
    await _writeQueue(bag);
  }

  Future<void> removeLesson(String lessonLocalId) => _remove(lessonLocalId);

  Future<void> _scheduleRetry(
    CloudQueueEntry entry, [
    String failureCode = 'SYNC_RETRYABLE_FAILURE',
  ]) async {
    final attempts = entry.attempts + 1;
    final bag = storage.readQueue();
    if (attempts > maxAttempts) {
      bag[entry.lessonLocalId] = entry.copyWith(
        attempts: attempts,
        nextRetryAt: 0,
        status: CloudQueueEntryStatus.blocked,
        lastFailureCode: failureCode,
      );
      await _writeQueue(bag);
      _markSyncBlocked(
        entry.lessonLocalId,
        entry.copyWith(attempts: attempts, lastFailureCode: failureCode),
        reason: 'SYNC_MAX_ATTEMPTS_EXCEEDED',
      );
      return;
    }
    final delay =
        retryDelaysMs[(attempts - 1).clamp(0, retryDelaysMs.length - 1)];
    bag[entry.lessonLocalId] = entry.copyWith(
      attempts: attempts,
      nextRetryAt: _now + delay,
      status: CloudQueueEntryStatus.queued,
      lastFailureCode: failureCode,
    );
    await _writeQueue(bag);
    if (!enableRetryTimers) return;
    _retryTimers[entry.lessonLocalId]?.cancel();
    _retryTimers[entry.lessonLocalId] = Timer(
      Duration(milliseconds: delay),
      () => flushOne(entry.lessonLocalId, force: false),
    );
  }

  void _markSyncFailed(
    String lessonLocalId,
    CloudQueueEntry entry,
    String message,
  ) {
    final state = stateService.read(lessonLocalId);
    if (state == null) return;
    stateService.write(
      _withSyncEvent(
        state,
        'REMOTE_VAULT_SYNC_FAILED',
        entry,
        status: 'failed',
        message: message,
      ),
      scheduleShadow: false,
    );
  }

  void _markSyncBlocked(
    String lessonLocalId,
    CloudQueueEntry entry, {
    required String reason,
  }) {
    final state = stateService.read(lessonLocalId);
    if (state == null) return;
    stateService.write(
      _withSyncEvent(
        state,
        'REMOTE_VAULT_SYNC_BLOCKED',
        entry,
        status: 'blocked',
        message: reason,
      ),
      scheduleShadow: false,
    );
  }

  StudentLearningState _withSyncEvent(
    StudentLearningState state,
    String type,
    CloudQueueEntry entry, {
    required String status,
    String? message,
    int? highWaterMark,
  }) {
    final ts = _now;
    final syncInfo = state.extra['syncInfo'] is Map
        ? Map<String, dynamic>.from(state.extra['syncInfo'] as Map)
        : <String, dynamic>{};
    return state.copyWith(
      syncStatus: StudentSyncStatus(
        status: status,
        highWaterMark: highWaterMark ?? state.syncStatus?.highWaterMark ?? 0,
        pendingJobs: status == 'synced' || status == 'blocked' ? 0 : 1,
        updatedAt: ts,
        lastSyncedAt: status == 'synced' ? ts : state.syncStatus?.lastSyncedAt,
        lastError: status == 'synced' ? null : message,
      ),
      events: [
        ...state.events,
        StudentLearningEvent(
          type: type,
          ts: ts,
          payload: {
            'lessonLocalId': entry.lessonLocalId,
            'queueId': entry.stableId,
            'operation': entry.operation.name,
            'attempts': entry.attempts,
            'pendingSince': entry.pendingSince,
            'status': status,
            ...message == null ? const {} : {'code': message},
            ...highWaterMark == null
                ? const {}
                : {'highWaterMark': highWaterMark},
          },
        ),
      ],
      extra: {
        ...state.extra,
        'syncInfo': {
          ...syncInfo,
          'status': status,
          'queueId': entry.stableId,
          'operation': entry.operation.name,
          'updatedAt': ts,
          ...message == null ? const {} : {'lastError': message},
          ...highWaterMark == null
              ? const {}
              : {'highWaterMark': highWaterMark},
        },
      },
    );
  }

  Future<void> _writeQueue(Map<String, CloudQueueEntry> queue) async {
    storage.writeQueue(queue);
    final durable = storage;
    if (durable is DurableCloudQueueStorage) {
      await durable.verifyQueueWrite();
    }
  }

  Future<void> _writeLastHash(String lessonLocalId, String hash) async {
    storage.writeLastHash(lessonLocalId, hash);
    final durable = storage;
    if (durable is DurableCloudQueueStorage) {
      await durable.verifyHashWrite();
    }
  }
}

String stableHash(StudentLearningState state) {
  final json = Map<String, dynamic>.from(state.toJson())
    ..remove('updatedAt')
    ..remove('cacheInfo')
    ..remove('syncInfo');
  final input = canonicalJsonEncode(json);
  var hash = 5381;
  for (final unit in input.codeUnits) {
    hash = ((hash << 5) + hash) ^ unit;
  }
  return (hash & 0xffffffff).toRadixString(36);
}

String stableCloudQueueItemId({
  required String lessonLocalId,
  required StudentLearningSyncOperation operation,
  required int pendingSince,
}) {
  return 'sync-${stableSmallHash(canonicalJsonEncode({'lessonLocalId': lessonLocalId, 'operation': operation.name, 'pendingSince': pendingSince}))}';
}

String stableSmallHash(String input) {
  var hash = 5381;
  for (final unit in input.codeUnits) {
    hash = ((hash << 5) + hash) ^ unit;
  }
  return (hash & 0xffffffff).toRadixString(36);
}

String canonicalJsonEncode(Object? value) => jsonEncode(_canonicalJson(value));

Object? _canonicalJson(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return {
      for (final entry in entries)
        entry.key.toString(): _canonicalJson(entry.value),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalJson).toList(growable: false);
  }
  return value;
}

String _safeSyncFailureCode(Object error) {
  if (error is CloudQueueStorageException) return error.code;
  final text = error.toString().toLowerCase();
  if (text.contains('session')) return 'SYNC_SESSION_UNAVAILABLE';
  if (text.contains('timeout')) return 'SYNC_TIMEOUT';
  if (text.contains('persist') || text.contains('storage')) {
    return 'SYNC_LOCAL_PERSIST_FAILED';
  }
  return 'SYNC_REMOTE_UNAVAILABLE';
}
