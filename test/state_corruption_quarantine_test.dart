import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

import 'support/memory_test_stores.dart';

void main() {
  test('estado corrompido fica em quarentena e nao vira empty persistido', () {
    final storage = MemoryStudentStateLocalStorage()
      ..states['lesson-bad'] = '{"lessonLocalId":';
    final store = StudentStateStore(local: storage, now: () => 1000);

    final recovered = store.readState('lesson-bad');

    expect(recovered.lessonLocalId, 'lesson-bad');
    expect(recovered.extra['stateIntegrity'], isA<Map>());
    expect(storage.states['lesson-bad'], '{"lessonLocalId":');
    expect(
      storage.readQuarantinedPayload(
        kind: StudentStateIntegrityKind.state,
        lessonLocalId: 'lesson-bad',
      ),
      '{"lessonLocalId":',
    );
    expect(store.integrityIssues.single.code, 'STATE_LOCAL_CORRUPTED');
  });

  test('eventos corrompidos ficam em quarentena e nao viram vazio normal', () {
    final storage = MemoryStudentStateLocalStorage()
      ..events['lesson-events'] = 'not-json';
    final store = StudentStateStore(local: storage);

    final events = store.getEventLog('lesson-events');

    expect(events, isEmpty);
    expect(
      storage.readQuarantinedPayload(
        kind: StudentStateIntegrityKind.events,
        lessonLocalId: 'lesson-events',
      ),
      'not-json',
    );
    expect(store.integrityIssues.single.code, 'STATE_EVENTS_CORRUPTED');
  });
}
