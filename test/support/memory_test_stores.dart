import 'package:sim_mobile/sim/cloud/cloud_queue.dart';
import 'package:sim_mobile/sim/billing/payment_return_store.dart';
import 'package:sim_mobile/sim/media/audio_preference.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

class MemoryStudentStateLocalStorage implements StudentStateLocalStorage {
  final Map<String, String> states = {};
  final Map<String, String> events = {};

  @override
  String? readEvents(String lessonLocalId) => events[lessonLocalId];

  @override
  String? readState(String lessonLocalId) => states[lessonLocalId];

  @override
  List<String> listStateIds() => states.keys.toList(growable: false);

  @override
  void writeEvents(String lessonLocalId, String encoded) {
    events[lessonLocalId] = encoded;
  }

  @override
  void writeState(String lessonLocalId, String encoded) {
    states[lessonLocalId] = encoded;
  }

  @override
  void deleteEvents(String lessonLocalId) {
    events.remove(lessonLocalId);
  }

  @override
  void deleteState(String lessonLocalId) {
    states.remove(lessonLocalId);
  }
}

class MemoryStudentStateCloudStorage implements StudentStateCloudStorage {
  final Map<String, StudentLearningState> states = {};

  @override
  Future<StudentLearningState?> loadCloud(String lessonLocalId) async {
    return states[lessonLocalId];
  }
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

class MemoryPaymentReturnStorage implements PaymentReturnStorage {
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

class MemoryAudioPreferenceStorage implements AudioPreferenceStorage {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) {
    _values[key] = value;
  }
}
