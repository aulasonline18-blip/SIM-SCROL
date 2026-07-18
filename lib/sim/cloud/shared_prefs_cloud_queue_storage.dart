import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_queue.dart';

class SharedPrefsCloudQueueStorage implements DurableCloudQueueStorage {
  SharedPrefsCloudQueueStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _queueKey = 'sim-student-state-queue-v1';
  static const String _hashKey = 'sim-student-state-queue-hash-v1';
  String? _lastQueuePayload;
  String? _lastHashPayload;
  int _queueWriteRevision = 0;
  int _hashWriteRevision = 0;

  @override
  Map<String, CloudQueueEntry> readQueue() {
    final raw = _prefs.getString(_queueKey);
    if (raw == null || raw.trim().isEmpty) return {};
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const CloudQueueStorageException('SYNC_QUEUE_CORRUPTED');
    }
    if (decoded is! Map) {
      throw const CloudQueueStorageException('SYNC_QUEUE_CORRUPTED');
    }
    final result = <String, CloudQueueEntry>{};
    for (final entry in decoded.entries) {
      final id = entry.key.toString();
      final value = entry.value;
      if (value is! Map) {
        throw const CloudQueueStorageException('SYNC_QUEUE_CORRUPTED');
      }
      final opRaw = value['operation']?.toString();
      final op = opRaw == 'tombstone'
          ? StudentLearningSyncOperation.tombstone
          : StudentLearningSyncOperation.patch;
      result[id] = CloudQueueEntry(
        id: value['id']?.toString(),
        lessonLocalId: id,
        operation: op,
        pendingSince: (value['pendingSince'] as num?)?.toInt() ?? 0,
        attempts: (value['attempts'] as num?)?.toInt() ?? 0,
        nextRetryAt: (value['nextRetryAt'] as num?)?.toInt() ?? 0,
        status: value['status']?.toString() == 'blocked'
            ? CloudQueueEntryStatus.blocked
            : CloudQueueEntryStatus.queued,
        lastFailureCode: value['lastFailureCode']?.toString(),
      );
    }
    return result;
  }

  @override
  void writeQueue(Map<String, CloudQueueEntry> queue) {
    final map = <String, dynamic>{};
    for (final entry in queue.entries) {
      map[entry.key] = {
        'id': entry.value.stableId,
        'lessonLocalId': entry.value.lessonLocalId,
        'operation':
            entry.value.operation == StudentLearningSyncOperation.tombstone
            ? 'tombstone'
            : 'patch',
        'pendingSince': entry.value.pendingSince,
        'attempts': entry.value.attempts,
        'nextRetryAt': entry.value.nextRetryAt,
        'status': entry.value.status.name,
        if (entry.value.lastFailureCode != null)
          'lastFailureCode': entry.value.lastFailureCode,
      };
    }
    _lastQueuePayload = jsonEncode(map);
    _queueWriteRevision += 1;
    _prefs.setString(_queueKey, _lastQueuePayload!);
  }

  @override
  Map<String, String> readLastHashes() {
    final raw = _prefs.getString(_hashKey);
    if (raw == null || raw.trim().isEmpty) return {};
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const CloudQueueStorageException('SYNC_HASH_INDEX_CORRUPTED');
    }
    if (decoded is! Map) {
      throw const CloudQueueStorageException('SYNC_HASH_INDEX_CORRUPTED');
    }
    return Map<String, String>.fromEntries(
      decoded.entries.map(
        (e) => MapEntry(e.key.toString(), e.value.toString()),
      ),
    );
  }

  @override
  void writeLastHash(String lessonLocalId, String hash) {
    final hashes = readLastHashes();
    hashes[lessonLocalId] = hash;
    _lastHashPayload = jsonEncode(hashes);
    _hashWriteRevision += 1;
    _prefs.setString(_hashKey, _lastHashPayload!);
  }

  @override
  Future<void> verifyQueueWrite() async {
    final payload = _lastQueuePayload;
    if (payload == null) return;
    final revision = _queueWriteRevision;
    final ok = await _prefs.setString(_queueKey, payload);
    if (_queueWriteRevision != revision) return;
    if (!ok || _prefs.getString(_queueKey) != payload) {
      throw const CloudQueueStorageException('SYNC_LOCAL_PERSIST_FAILED');
    }
  }

  @override
  Future<void> verifyHashWrite() async {
    final payload = _lastHashPayload;
    if (payload == null) return;
    final revision = _hashWriteRevision;
    final ok = await _prefs.setString(_hashKey, payload);
    if (_hashWriteRevision != revision) return;
    if (!ok || _prefs.getString(_hashKey) != payload) {
      throw const CloudQueueStorageException('SYNC_LOCAL_PERSIST_FAILED');
    }
  }
}
