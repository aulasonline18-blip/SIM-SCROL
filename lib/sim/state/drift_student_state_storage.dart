import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'student_state_store.dart';

class StudentStateDriftDatabase extends GeneratedDatabase {
  StudentStateDriftDatabase(super.executor);

  factory StudentStateDriftDatabase.memory() {
    return StudentStateDriftDatabase(NativeDatabase.memory());
  }

  static Future<StudentStateDriftDatabase> open(String name) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, '$name.sqlite'));
    return StudentStateDriftDatabase(NativeDatabase.createInBackground(file));
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;

  Future<void> ensureSchema() {
    return customStatement('''
      CREATE TABLE IF NOT EXISTS student_states (
        lesson_local_id TEXT PRIMARY KEY NOT NULL,
        encoded_state TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0
      );
    ''');
  }

  Future<void> ensureEventSchema() {
    return customStatement('''
      CREATE TABLE IF NOT EXISTS student_events (
        lesson_local_id TEXT PRIMARY KEY NOT NULL,
        encoded_events TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0
      );
    ''');
  }
}

class DriftStudentStateLocalStorage
    implements DurableStudentStateLocalStorage, StudentStateQuarantineStorage {
  DriftStudentStateLocalStorage._(this._db);

  final StudentStateDriftDatabase _db;
  final Map<String, String> _states = {};
  final Map<String, String> _events = {};
  final Map<String, String> _quarantine = {};
  String? _lastStateLessonId;
  String? _lastStatePayload;
  String? _lastEventsLessonId;
  String? _lastEventsPayload;
  String? _lastDeletedLessonId;

  static Future<DriftStudentStateLocalStorage> open(
    String name, {
    StudentStateLocalStorage? legacy,
  }) async {
    final db = await StudentStateDriftDatabase.open(name);
    return fromDatabase(db, legacy: legacy);
  }

  static Future<DriftStudentStateLocalStorage> memory({
    StudentStateLocalStorage? legacy,
  }) async {
    return fromDatabase(StudentStateDriftDatabase.memory(), legacy: legacy);
  }

  static Future<DriftStudentStateLocalStorage> fromDatabase(
    StudentStateDriftDatabase db, {
    StudentStateLocalStorage? legacy,
  }) async {
    final storage = DriftStudentStateLocalStorage._(db);
    await storage._initialize();
    await storage._migrateLegacy(legacy);
    return storage;
  }

  @override
  String? readEvents(String lessonLocalId) => _events[lessonLocalId];

  @override
  String? readState(String lessonLocalId) => _states[lessonLocalId];

  @override
  List<String> listStateIds() => _states.keys.toList(growable: false);

  @override
  void writeEvents(String lessonLocalId, String encoded) {
    _events[lessonLocalId] = encoded;
    _lastEventsLessonId = lessonLocalId;
    _lastEventsPayload = encoded;
    unawaited(writeEventsDurably(lessonLocalId, encoded));
  }

  @override
  void writeState(String lessonLocalId, String encoded) {
    _states[lessonLocalId] = encoded;
    _lastStateLessonId = lessonLocalId;
    _lastStatePayload = encoded;
    unawaited(writeStateDurably(lessonLocalId, encoded));
  }

  @override
  void deleteEvents(String lessonLocalId) {
    _events.remove(lessonLocalId);
    _lastDeletedLessonId = lessonLocalId;
    unawaited(deleteEventsDurably(lessonLocalId));
  }

  @override
  void deleteState(String lessonLocalId) {
    _states.remove(lessonLocalId);
    _lastDeletedLessonId = lessonLocalId;
    unawaited(deleteStateDurably(lessonLocalId));
  }

  @override
  void quarantinePayload({
    required StudentStateIntegrityKind kind,
    required String lessonLocalId,
    required String payload,
    required String code,
  }) {
    _quarantine[_quarantineKey(kind, lessonLocalId)] = payload;
  }

  @override
  String? readQuarantinedPayload({
    required StudentStateIntegrityKind kind,
    required String lessonLocalId,
  }) {
    return _quarantine[_quarantineKey(kind, lessonLocalId)];
  }

  Future<void> writeStateDurably(String lessonLocalId, String encoded) {
    return _db.customStatement(
      '''
          INSERT INTO student_states (lesson_local_id, encoded_state, updated_at)
          VALUES (?, ?, ?)
          ON CONFLICT(lesson_local_id) DO UPDATE SET
            encoded_state = excluded.encoded_state,
            updated_at = excluded.updated_at
        ''',
      [lessonLocalId, encoded, DateTime.now().millisecondsSinceEpoch],
    );
  }

  Future<void> writeEventsDurably(String lessonLocalId, String encoded) {
    return _db.customStatement(
      '''
          INSERT INTO student_events (lesson_local_id, encoded_events, updated_at)
          VALUES (?, ?, ?)
          ON CONFLICT(lesson_local_id) DO UPDATE SET
            encoded_events = excluded.encoded_events,
            updated_at = excluded.updated_at
        ''',
      [lessonLocalId, encoded, DateTime.now().millisecondsSinceEpoch],
    );
  }

  Future<void> deleteStateDurably(String lessonLocalId) {
    return _db.customStatement(
      'DELETE FROM student_states WHERE lesson_local_id = ?',
      [lessonLocalId],
    );
  }

  Future<void> deleteEventsDurably(String lessonLocalId) {
    return _db.customStatement(
      'DELETE FROM student_events WHERE lesson_local_id = ?',
      [lessonLocalId],
    );
  }

  @override
  Future<void> verifyLastStateWrite() async {
    final id = _lastStateLessonId;
    final payload = _lastStatePayload;
    if (id == null || payload == null) return;
    await writeStateDurably(id, payload);
  }

  @override
  Future<void> verifyLastEventsWrite() async {
    final id = _lastEventsLessonId;
    final payload = _lastEventsPayload;
    if (id == null || payload == null) return;
    await writeEventsDurably(id, payload);
  }

  @override
  Future<void> verifyLastDelete() async {
    final id = _lastDeletedLessonId;
    if (id == null) return;
    await deleteStateDurably(id);
    await deleteEventsDurably(id);
  }

  Future<void> _initialize() async {
    await _db.ensureSchema();
    await _db.ensureEventSchema();
    final stateRows = await _db
        .customSelect(
          'SELECT lesson_local_id, encoded_state FROM student_states',
        )
        .get();
    for (final row in stateRows) {
      _states[row.read<String>('lesson_local_id')] = row.read<String>(
        'encoded_state',
      );
    }
    final eventRows = await _db
        .customSelect(
          'SELECT lesson_local_id, encoded_events FROM student_events',
        )
        .get();
    for (final row in eventRows) {
      _events[row.read<String>('lesson_local_id')] = row.read<String>(
        'encoded_events',
      );
    }
  }

  Future<void> _migrateLegacy(StudentStateLocalStorage? legacy) async {
    if (legacy == null) return;
    for (final id in legacy.listStateIds()) {
      if (_states.containsKey(id)) continue;
      final state = legacy.readState(id);
      if (state == null || state.trim().isEmpty) continue;
      writeState(id, state);
      final events = legacy.readEvents(id);
      if (events != null && events.trim().isNotEmpty) {
        writeEvents(id, events);
      }
    }
  }

  String _quarantineKey(StudentStateIntegrityKind kind, String lessonLocalId) =>
      '${kind.name}:$lessonLocalId';
}
