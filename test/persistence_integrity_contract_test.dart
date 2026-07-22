import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

void main() {
  test('escrita critica expõe falha duravel de forma auditavel', () async {
    final local = _FailingDurableStorage(failStateWrite: true);
    final store = StudentStateStore(local: local);

    store.writeState(StudentLearningState.empty(lessonLocalId: 'lesson-write'));
    await Future<void>.delayed(Duration.zero);

    expect(store.lastPersistenceAudit.operation, 'write_state');
    expect(
      store.lastPersistenceAudit.status,
      StudentStatePersistenceStatus.failed,
    );
    expect(store.lastPersistenceAudit.code, 'STATE_LOCAL_PERSIST_FAILED');
  });

  test('delete critico expõe falha duravel de forma auditavel', () async {
    final local = _FailingDurableStorage(failDelete: true)
      ..states['lesson-delete'] = '{}';
    final store = StudentStateStore(local: local);

    store.removeLocalLessonData('lesson-delete');
    await Future<void>.delayed(Duration.zero);

    expect(store.lastPersistenceAudit.operation, 'delete');
    expect(
      store.lastPersistenceAudit.status,
      StudentStatePersistenceStatus.failed,
    );
    expect(store.lastPersistenceAudit.code, 'STATE_LOCAL_DELETE_FAILED');
  });
}

class _FailingDurableStorage
    implements DurableStudentStateLocalStorage, StudentStateQuarantineStorage {
  _FailingDurableStorage({
    this.failStateWrite = false,
    this.failDelete = false,
  });

  final bool failStateWrite;
  final bool failDelete;
  final Map<String, String> states = {};
  final Map<String, String> events = {};
  final Map<String, String> quarantine = {};

  @override
  String? readState(String lessonLocalId) => states[lessonLocalId];

  @override
  void writeState(String lessonLocalId, String encoded) {
    states[lessonLocalId] = encoded;
  }

  @override
  String? readEvents(String lessonLocalId) => events[lessonLocalId];

  @override
  void writeEvents(String lessonLocalId, String encoded) {
    events[lessonLocalId] = encoded;
  }

  @override
  void deleteState(String lessonLocalId) {
    states.remove(lessonLocalId);
  }

  @override
  void deleteEvents(String lessonLocalId) {
    events.remove(lessonLocalId);
  }

  @override
  List<String> listStateIds() => states.keys.toList(growable: false);

  @override
  Future<void> verifyLastStateWrite() async {
    if (failStateWrite) {
      throw const StudentStateStorageException('STATE_LOCAL_PERSIST_FAILED');
    }
  }

  @override
  Future<void> verifyLastEventsWrite() async {}

  @override
  Future<void> verifyLastDelete() async {
    if (failDelete) {
      throw const StudentStateStorageException('STATE_LOCAL_DELETE_FAILED');
    }
  }

  @override
  void quarantinePayload({
    required StudentStateIntegrityKind kind,
    required String lessonLocalId,
    required String payload,
    required String code,
  }) {
    quarantine['${kind.name}:$lessonLocalId'] = payload;
  }

  @override
  String? readQuarantinedPayload({
    required StudentStateIntegrityKind kind,
    required String lessonLocalId,
  }) {
    return quarantine['${kind.name}:$lessonLocalId'];
  }
}
