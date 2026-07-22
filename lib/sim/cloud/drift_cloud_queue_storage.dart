import 'dart:async';
import 'dart:convert';

import '../state/drift_student_state_storage.dart';
import 'cloud_queue.dart';

class DriftCloudQueueStorage implements DurableCloudQueueStorage {
  DriftCloudQueueStorage._(this._db);

  final StudentStateDriftDatabase _db;
  final Map<String, CloudQueueEntry> _queue = {};
  final Map<String, String> _hashes = {};
  Map<String, CloudQueueEntry>? _lastQueuePayload;
  String? _lastHashLessonId;
  String? _lastHashPayload;
  int _queueWriteRevision = 0;
  int _hashWriteRevision = 0;

  StudentStateDriftDatabase get debugDatabaseForTest => _db;

  static Future<DriftCloudQueueStorage> open(
    String name, {
    CloudQueueStorage? legacy,
  }) async {
    final db = await StudentStateDriftDatabase.open(name);
    return fromDatabase(db, legacy: legacy);
  }

  static Future<DriftCloudQueueStorage> memory({
    CloudQueueStorage? legacy,
  }) async {
    return fromDatabase(StudentStateDriftDatabase.memory(), legacy: legacy);
  }

  static Future<DriftCloudQueueStorage> fromDatabase(
    StudentStateDriftDatabase db, {
    CloudQueueStorage? legacy,
  }) async {
    final storage = DriftCloudQueueStorage._(db);
    await storage._initialize();
    await storage._migrateLegacy(legacy);
    return storage;
  }

  @override
  Map<String, CloudQueueEntry> readQueue() => Map.of(_queue);

  @override
  void writeQueue(Map<String, CloudQueueEntry> queue) {
    _queue
      ..clear()
      ..addAll(queue);
    _lastQueuePayload = Map.of(queue);
    _queueWriteRevision += 1;
    unawaited(writeQueueDurably(queue));
  }

  @override
  Map<String, String> readLastHashes() => Map.of(_hashes);

  @override
  void writeLastHash(String lessonLocalId, String hash) {
    _hashes[lessonLocalId] = hash;
    _lastHashLessonId = lessonLocalId;
    _lastHashPayload = hash;
    _hashWriteRevision += 1;
    unawaited(writeLastHashDurably(lessonLocalId, hash));
  }

  Future<void> writeQueueDurably(Map<String, CloudQueueEntry> queue) {
    return _db.transaction(() async {
      await _db.customStatement('DELETE FROM cloud_queue_entries');
      for (final entry in queue.entries) {
        await _db.customStatement(
          '''
          INSERT INTO cloud_queue_entries
            (lesson_local_id, encoded_entry, updated_at)
          VALUES (?, ?, ?)
          ON CONFLICT(lesson_local_id) DO UPDATE SET
            encoded_entry = excluded.encoded_entry,
            updated_at = excluded.updated_at
          ''',
          [
            entry.key,
            jsonEncode(_entryToJson(entry.value)),
            DateTime.now().millisecondsSinceEpoch,
          ],
        );
      }
    });
  }

  Future<void> writeLastHashDurably(String lessonLocalId, String hash) {
    return _db.customStatement(
      '''
      INSERT INTO cloud_queue_hashes (lesson_local_id, content_hash, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT(lesson_local_id) DO UPDATE SET
        content_hash = excluded.content_hash,
        updated_at = excluded.updated_at
      ''',
      [lessonLocalId, hash, DateTime.now().millisecondsSinceEpoch],
    );
  }

  @override
  Future<void> verifyQueueWrite() async {
    final payload = _lastQueuePayload;
    if (payload == null) return;
    final revision = _queueWriteRevision;
    await writeQueueDurably(payload);
    if (_queueWriteRevision != revision) return;
    await _reloadQueue();
    if (_queue.length != payload.length) {
      throw const CloudQueueStorageException('SYNC_LOCAL_PERSIST_FAILED');
    }
    for (final entry in payload.entries) {
      final stored = _queue[entry.key];
      if (stored == null || stored.stableId != entry.value.stableId) {
        throw const CloudQueueStorageException('SYNC_LOCAL_PERSIST_FAILED');
      }
    }
  }

  @override
  Future<void> verifyHashWrite() async {
    final lessonLocalId = _lastHashLessonId;
    final hash = _lastHashPayload;
    if (lessonLocalId == null || hash == null) return;
    final revision = _hashWriteRevision;
    await writeLastHashDurably(lessonLocalId, hash);
    if (_hashWriteRevision != revision) return;
    await _reloadHashes();
    if (_hashes[lessonLocalId] != hash) {
      throw const CloudQueueStorageException('SYNC_LOCAL_PERSIST_FAILED');
    }
  }

  Future<void> _initialize() async {
    await _ensureSchema();
    await _reloadQueue();
    await _reloadHashes();
  }

  Future<void> _ensureSchema() async {
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS cloud_queue_entries (
        lesson_local_id TEXT PRIMARY KEY NOT NULL,
        encoded_entry TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0
      );
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS cloud_queue_hashes (
        lesson_local_id TEXT PRIMARY KEY NOT NULL,
        content_hash TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0
      );
    ''');
  }

  Future<void> _reloadQueue() async {
    _queue.clear();
    final rows = await _db
        .customSelect(
          'SELECT lesson_local_id, encoded_entry FROM cloud_queue_entries',
        )
        .get();
    for (final row in rows) {
      final lessonLocalId = row.read<String>('lesson_local_id');
      final raw = row.read<String>('encoded_entry');
      _queue[lessonLocalId] = _entryFromJson(lessonLocalId, jsonDecode(raw));
    }
  }

  Future<void> _reloadHashes() async {
    _hashes.clear();
    final rows = await _db
        .customSelect(
          'SELECT lesson_local_id, content_hash FROM cloud_queue_hashes',
        )
        .get();
    for (final row in rows) {
      _hashes[row.read<String>('lesson_local_id')] = row.read<String>(
        'content_hash',
      );
    }
  }

  Future<void> _migrateLegacy(CloudQueueStorage? legacy) async {
    if (legacy == null) return;
    if (_queue.isEmpty) {
      final legacyQueue = legacy.readQueue();
      if (legacyQueue.isNotEmpty) {
        writeQueue(legacyQueue);
        await verifyQueueWrite();
        legacy.writeQueue(const {});
      }
    }
    if (_hashes.isEmpty) {
      final legacyHashes = legacy.readLastHashes();
      if (legacyHashes.isNotEmpty) {
        for (final entry in legacyHashes.entries) {
          writeLastHash(entry.key, entry.value);
          await verifyHashWrite();
        }
      }
    }
  }

  Map<String, Object?> _entryToJson(CloudQueueEntry entry) => {
    'id': entry.stableId,
    'lessonLocalId': entry.lessonLocalId,
    'operation': entry.operation.name,
    'pendingSince': entry.pendingSince,
    'attempts': entry.attempts,
    'nextRetryAt': entry.nextRetryAt,
    'status': entry.status.name,
    if (entry.lastFailureCode != null) 'lastFailureCode': entry.lastFailureCode,
  };

  CloudQueueEntry _entryFromJson(String lessonLocalId, Object? decoded) {
    if (decoded is! Map) {
      throw const CloudQueueStorageException('SYNC_QUEUE_CORRUPTED');
    }
    final opRaw = decoded['operation']?.toString();
    return CloudQueueEntry(
      id: decoded['id']?.toString(),
      lessonLocalId: decoded['lessonLocalId']?.toString() ?? lessonLocalId,
      operation: opRaw == 'tombstone'
          ? StudentLearningSyncOperation.tombstone
          : StudentLearningSyncOperation.patch,
      pendingSince: (decoded['pendingSince'] as num?)?.toInt() ?? 0,
      attempts: (decoded['attempts'] as num?)?.toInt() ?? 0,
      nextRetryAt: (decoded['nextRetryAt'] as num?)?.toInt() ?? 0,
      status: decoded['status']?.toString() == 'blocked'
          ? CloudQueueEntryStatus.blocked
          : CloudQueueEntryStatus.queued,
      lastFailureCode: decoded['lastFailureCode']?.toString(),
    );
  }
}
