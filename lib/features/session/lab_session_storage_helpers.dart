part of 'lab_session.dart';

bool _isFlutterTestEnvironment() {
  return Platform.environment['FLUTTER_TEST'] == 'true' ||
      WidgetsBinding.instance.runtimeType.toString().contains('Test');
}

StudentStateLocalStorage _studentStateStorageForSession(
  SharedPreferences? prefs,
) {
  if (_isFlutterTestEnvironment()) {
    return _TestOnlyVolatileStudentStateStorage();
  }
  if (prefs != null) {
    throw const StudentStateStorageException(
      'CANONICAL_STUDENT_STATE_STORE_REQUIRED',
    );
  }
  return _ExplicitStudentStateStorageRequired();
}

PaymentReturnStorage _paymentReturnStorageForSession(SharedPreferences? prefs) {
  if (prefs != null) return SharedPrefsPaymentReturnStorage(prefs);
  if (_isFlutterTestEnvironment()) {
    return _TestOnlyVolatilePaymentReturnStorage();
  }
  throw StateError('PAYMENT_RETURN_STORAGE_REQUIRED');
}

AudioPreferenceStorage _audioPreferenceStorageForSession(
  SharedPreferences? prefs,
) {
  if (prefs != null) return SharedPrefsAudioPreferenceStorage(prefs);
  if (_isFlutterTestEnvironment()) {
    return _TestOnlyVolatileAudioPreferenceStorage();
  }
  throw StateError('AUDIO_PREFERENCE_STORAGE_REQUIRED');
}

CloudQueueStorage _cloudQueueStorageForSession(CloudQueueStorage? storage) {
  if (storage != null) return storage;
  if (_isFlutterTestEnvironment()) return _TestOnlyVolatileCloudQueueStorage();
  throw const CloudQueueStorageException('CLOUD_QUEUE_STORAGE_REQUIRED');
}

class _TestOnlyVolatileCloudQueueStorage implements CloudQueueStorage {
  final Map<String, CloudQueueEntry> _queue = {};
  final Map<String, String> _hashes = {};

  @override
  Map<String, CloudQueueEntry> readQueue() => Map.of(_queue);

  @override
  void writeQueue(Map<String, CloudQueueEntry> queue) {
    _queue
      ..clear()
      ..addAll(queue);
  }

  @override
  Map<String, String> readLastHashes() => Map.of(_hashes);

  @override
  void writeLastHash(String lessonLocalId, String hash) {
    _hashes[lessonLocalId] = hash;
  }
}

class _ExplicitStudentStateStorageRequired implements StudentStateLocalStorage {
  Never _fail() => throw const StudentStateStorageException(
    'STUDENT_STATE_STORAGE_REQUIRED',
  );

  @override
  void deleteEvents(String lessonLocalId) => _fail();

  @override
  void deleteState(String lessonLocalId) => _fail();

  @override
  List<String> listStateIds() => _fail();

  @override
  String? readEvents(String lessonLocalId) => _fail();

  @override
  String? readState(String lessonLocalId) => _fail();

  @override
  void writeEvents(String lessonLocalId, String encoded) => _fail();

  @override
  void writeState(String lessonLocalId, String encoded) => _fail();
}

class _TestOnlyVolatileStudentStateStorage implements StudentStateLocalStorage {
  final Map<String, String> _states = {};
  final Map<String, String> _events = {};

  @override
  void deleteEvents(String lessonLocalId) {
    _events.remove(lessonLocalId);
  }

  @override
  void deleteState(String lessonLocalId) {
    _states.remove(lessonLocalId);
  }

  @override
  List<String> listStateIds() => _states.keys.toList();

  @override
  String? readEvents(String lessonLocalId) => _events[lessonLocalId];

  @override
  String? readState(String lessonLocalId) => _states[lessonLocalId];

  @override
  void writeEvents(String lessonLocalId, String encoded) {
    _events[lessonLocalId] = encoded;
  }

  @override
  void writeState(String lessonLocalId, String encoded) {
    _states[lessonLocalId] = encoded;
  }
}

class _TestOnlyVolatilePaymentReturnStorage implements PaymentReturnStorage {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  void remove(String key) {
    _values.remove(key);
  }

  @override
  void write(String key, String value) {
    _values[key] = value;
  }
}

class _TestOnlyVolatileAudioPreferenceStorage
    implements AudioPreferenceStorage {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) {
    _values[key] = value;
  }
}
