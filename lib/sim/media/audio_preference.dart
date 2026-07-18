import 'package:shared_preferences/shared_preferences.dart';

typedef AudioPreferenceListener = void Function(bool enabled);

const String audioPreferenceStorageKey = 'sim-audio-enabled-v1';
const bool defaultAudioEnabled = true;

abstract interface class AudioPreferenceStorage {
  String? read(String key);
  void write(String key, String value);
}

/// SharedPreferences-backed storage — persists across app restarts.
class SharedPrefsAudioPreferenceStorage implements AudioPreferenceStorage {
  SharedPrefsAudioPreferenceStorage(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? read(String key) => _prefs.getString(key);

  @override
  void write(String key, String value) {
    _prefs.setString(key, value);
  }

  static Future<SharedPrefsAudioPreferenceStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPrefsAudioPreferenceStorage(prefs);
  }
}

class _ExplicitAudioPreferenceStorageRequired
    implements AudioPreferenceStorage {
  const _ExplicitAudioPreferenceStorageRequired();

  Never _missing() {
    throw StateError('AUDIO_PREFERENCE_STORAGE_REQUIRED');
  }

  @override
  String? read(String key) => _missing();

  @override
  void write(String key, String value) {
    _missing();
  }
}

class AudioPreference {
  AudioPreference({AudioPreferenceStorage? storage})
    : storage = storage ?? const _ExplicitAudioPreferenceStorageRequired();

  final AudioPreferenceStorage storage;
  final Set<AudioPreferenceListener> _listeners = {};

  bool getAudioEnabled() {
    final raw = storage.read(audioPreferenceStorageKey);
    if (raw == null) return defaultAudioEnabled;
    return raw == '1' || raw == 'true';
  }

  void setAudioEnabled(bool next) {
    storage.write(audioPreferenceStorageKey, next ? '1' : '0');
    for (final listener in List<AudioPreferenceListener>.from(_listeners)) {
      listener(next);
    }
  }

  void subscribe(AudioPreferenceListener listener) {
    _listeners.add(listener);
  }

  void unsubscribe(AudioPreferenceListener listener) {
    _listeners.remove(listener);
  }
}
