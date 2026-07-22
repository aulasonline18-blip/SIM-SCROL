import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

import 'support/memory_test_stores.dart';

void main() {
  test('drawer lesson open publishes validated route and target identity', () async {
    final storage = MemoryStudentStateLocalStorage();
    final store = StudentStateStore(local: storage);
    store.writeState(
      StudentLearningState.empty(lessonLocalId: 'lesson-b').copyWith(
        profile: const StudentProfile(
          language: 'pt-BR',
          stableLang: 'pt-BR',
          objetivo: 'Estudar algebra',
        ),
      ),
    );
    final session = LabSession(canonicalStore: store)
      ..authed = true
      ..authReady = true
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'pt-BR';
    addTearDown(session.dispose);

    final opened = await session.openDrawerLocalLesson('lesson-b');

    expect(opened, isTrue);
    expect(session.route, '/cyber/aula');
    expect(session.lessonLocalId, 'lesson-b');
    expect(session.aulaMenuLessonWaiting, isTrue);
    expect(session.aulaOpeningTransition?.targetLessonLocalId, 'lesson-b');
    expect(session.rejectedRoute, isNull);
  });

  test('openAulaRuntime without lesson id moves to safe objective route', () async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'pt-BR'
      ..route = '/cyber/aula';
    addTearDown(session.dispose);

    await session.openAulaRuntime();

    expect(session.route, '/cyber/objeto');
    expect(session.aulaSnapshot, isNull);
    expect(session.aulaMenuLessonWaiting, isFalse);
  });
}
