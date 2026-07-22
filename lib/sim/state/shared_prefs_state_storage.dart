import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'student_state_store.dart';

class SharedPrefsStudentStateLocalStorage
    implements DurableStudentStateLocalStorage, StudentStateQuarantineStorage {
  SharedPrefsStudentStateLocalStorage(this._prefs, {this.activeLessonLocalId});

  final SharedPreferences _prefs;
  String? _lastStateLessonId;
  String? _lastStatePayload;
  String? _lastEventsLessonId;
  String? _lastEventsPayload;
  String? _lastDeletedLessonId;

  // Set by the caller to protect the active lesson from LRU eviction (I.7)
  String? activeLessonLocalId;

  // Keys must match Web's studentLearningState.store.ts exactly (Planta-Mãe I.6)
  static const String _stateKeyPrefix = 'sim-student-learning-state-v1:lesson:';
  static const String _eventsKeyPrefix = 'sim-events-v1-';
  // Legacy prefix used before I.6 migration — kept for read fallback
  static const String _legacyStatePrefix = 'sim-state-v1-';
  static const String _quarantinePrefix =
      'sim-student-learning-state-v1:quarantine:';
  static const String indexKey = 'sim-student-learning-state-v1:index-v2';
  // I.7: keep at most this many recent lessons in local storage
  static const int _keepRecentLessons = 24;

  String _stateKey(String lessonLocalId) =>
      '$_stateKeyPrefix${Uri.encodeComponent(lessonLocalId)}';

  @override
  String? readState(String lessonLocalId) {
    final v = _prefs.getString(_stateKey(lessonLocalId));
    if (v != null) return v;
    // Migrate from legacy key on first read
    return _prefs.getString('$_legacyStatePrefix$lessonLocalId');
  }

  @override
  void writeState(String lessonLocalId, String encoded) {
    _lastStateLessonId = lessonLocalId;
    _lastStatePayload = encoded;
    _prefs.setString(_stateKey(lessonLocalId), encoded);
    _updateIndexAndReclaim(lessonLocalId);
  }

  @override
  String? readEvents(String lessonLocalId) {
    return _prefs.getString('$_eventsKeyPrefix$lessonLocalId');
  }

  @override
  void writeEvents(String lessonLocalId, String encoded) {
    _lastEventsLessonId = lessonLocalId;
    _lastEventsPayload = encoded;
    _prefs.setString('$_eventsKeyPrefix$lessonLocalId', encoded);
  }

  @override
  void deleteEvents(String lessonLocalId) {
    _lastDeletedLessonId = lessonLocalId;
    _prefs.remove('$_eventsKeyPrefix$lessonLocalId');
  }

  @override
  void deleteState(String lessonLocalId) {
    _lastDeletedLessonId = lessonLocalId;
    _prefs.remove(_stateKey(lessonLocalId));
    _prefs.remove('$_legacyStatePrefix$lessonLocalId');
    final ids = readIndex().where((id) => id != lessonLocalId).toList();
    _prefs.setStringList(indexKey, ids);
  }

  @override
  void quarantinePayload({
    required StudentStateIntegrityKind kind,
    required String lessonLocalId,
    required String payload,
    required String code,
  }) {
    _prefs.setString(
      _quarantineKey(kind, lessonLocalId),
      jsonEncode({
        'kind': kind.name,
        'lessonLocalId': lessonLocalId,
        'code': code,
        'payload': payload,
      }),
    );
  }

  @override
  String? readQuarantinedPayload({
    required StudentStateIntegrityKind kind,
    required String lessonLocalId,
  }) {
    final raw = _prefs.getString(_quarantineKey(kind, lessonLocalId));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded['payload']?.toString();
    } catch (_) {}
    return raw;
  }

  @override
  Future<void> verifyLastStateWrite() async {
    final id = _lastStateLessonId;
    final payload = _lastStatePayload;
    if (id == null || payload == null) return;
    final stateOk = await _prefs.setString(_stateKey(id), payload);
    final index = readIndex().toSet()..add(id);
    final indexOk = await _prefs.setStringList(indexKey, index.toList());
    if (!stateOk ||
        !indexOk ||
        _prefs.getString(_stateKey(id)) != payload ||
        !readIndex().contains(id)) {
      throw const StudentStateStorageException('STATE_LOCAL_PERSIST_FAILED');
    }
  }

  @override
  Future<void> verifyLastEventsWrite() async {
    final id = _lastEventsLessonId;
    final payload = _lastEventsPayload;
    if (id == null || payload == null) return;
    final ok = await _prefs.setString('$_eventsKeyPrefix$id', payload);
    if (!ok || _prefs.getString('$_eventsKeyPrefix$id') != payload) {
      throw const StudentStateStorageException('STATE_EVENTS_PERSIST_FAILED');
    }
  }

  @override
  Future<void> verifyLastDelete() async {
    final id = _lastDeletedLessonId;
    if (id == null) return;
    final stateOk = await _prefs.remove(_stateKey(id));
    final legacyOk = await _prefs.remove('$_legacyStatePrefix$id');
    final eventsOk = await _prefs.remove('$_eventsKeyPrefix$id');
    final ids = readIndex().where((value) => value != id).toList();
    final indexOk = await _prefs.setStringList(indexKey, ids);
    if (!stateOk ||
        !legacyOk ||
        !eventsOk ||
        !indexOk ||
        readIndex().contains(id)) {
      throw const StudentStateStorageException('STATE_LOCAL_DELETE_FAILED');
    }
  }

  @override
  List<String> listStateIds() => readIndex();

  List<String> readIndex() {
    final raw = _prefs.getStringList(indexKey);
    return raw ?? const [];
  }

  void _updateIndexAndReclaim(String lessonLocalId) {
    final ids = readIndex().toSet()..add(lessonLocalId);
    if (ids.length <= _keepRecentLessons) {
      _prefs.setStringList(indexKey, ids.toList());
      return;
    }
    // I.7: LRU reclaim — remove excess lessons by updatedAt ascending
    // Protected: the lesson being written + the active lesson
    final protected = <String>{lessonLocalId};
    if (activeLessonLocalId != null) protected.add(activeLessonLocalId!);

    final removable = ids.where((id) => !protected.contains(id)).toList();
    // Sort by updatedAt ascending (oldest first) using stored state
    removable.sort((a, b) {
      final aTs = _readUpdatedAt(a);
      final bTs = _readUpdatedAt(b);
      return aTs.compareTo(bTs);
    });

    final excess = ids.length - _keepRecentLessons;
    final toRemove = removable.take(excess).toSet();
    for (final id in toRemove) {
      _prefs.remove(_stateKey(id));
      _prefs.remove('$_eventsKeyPrefix$id');
      _prefs.remove('$_legacyStatePrefix$id');
      ids.remove(id);
    }
    _prefs.setStringList(indexKey, ids.toList());
  }

  int _readUpdatedAt(String lessonLocalId) {
    final raw = _prefs.getString(_stateKey(lessonLocalId));
    if (raw == null) return 0;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return (decoded['updatedAt'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  String _quarantineKey(StudentStateIntegrityKind kind, String lessonLocalId) =>
      '$_quarantinePrefix${kind.name}:${Uri.encodeComponent(lessonLocalId)}';
}
