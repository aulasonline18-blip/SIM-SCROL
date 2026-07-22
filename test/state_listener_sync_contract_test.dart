import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/runtime/sim_runtime_audit.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';
import 'package:sim_mobile/sim/state/student_state_store_adapter.dart';

import 'support/memory_test_stores.dart';

void main() {
  setUp(() {
    SimRuntimeAudit.clearForTesting();
    final previous = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = previous);
  });

  test(
    'state listener failure is reported and later listeners still receive write',
    () {
      final service = StudentLearningStateService();
      final delivered = <String>[];

      service.subscribe((_) => throw StateError('listener failed'));
      service.subscribe(delivered.add);

      service.write(StudentLearningState.empty(lessonLocalId: 'lesson-sync'));

      expect(delivered, ['lesson-sync']);
      expect(SimRuntimeAudit.events, hasLength(1));
      expect(SimRuntimeAudit.events.single.code, 'listener_failed');
      expect(
        SimRuntimeAudit.events.single.details['lessonLocalId'],
        'lesson-sync',
      );
    },
  );

  test('late subscribe receives current state when replay is requested', () {
    final service = StudentLearningStateService();
    service.write(StudentLearningState.empty(lessonLocalId: 'lesson-replay'));
    final delivered = <String>[];

    service.subscribe(
      delivered.add,
      replayCurrent: true,
      lessonLocalId: 'lesson-replay',
    );

    expect(delivered, ['lesson-replay']);
  });

  test('late subscribe without replay keeps legacy behavior', () {
    final service = StudentLearningStateService();
    service.write(StudentLearningState.empty(lessonLocalId: 'lesson-legacy'));
    final delivered = <String>[];

    service.subscribe(delivered.add);

    expect(delivered, isEmpty);
  });

  test(
    'store adapter listener failure is reported and second listener still receives write',
    () {
      final store = StudentStateStore(local: MemoryStudentStateLocalStorage());
      final adapter = StudentStateStoreAdapter(store);
      final delivered = <String>[];

      adapter.subscribe((_) => throw StateError('adapter listener failed'));
      adapter.subscribe(delivered.add);

      adapter.write(StudentLearningState.empty(lessonLocalId: 'adapter-sync'));

      expect(delivered, ['adapter-sync']);
      expect(SimRuntimeAudit.events, hasLength(1));
      expect(SimRuntimeAudit.events.single.code, 'listener_failed');
      expect(
        SimRuntimeAudit.events.single.details['lessonLocalId'],
        'adapter-sync',
      );
    },
  );

  test(
    'lesson event bus replays latest event to late subscriber after bad listener',
    () {
      final bus = LessonEventBus();
      final delivered = <CompleteLesson>[];
      final lesson = const CompleteLesson(
        conteudo: LessonContent(
          explanation: 'Explicacao.',
          question: 'Pergunta?',
          options: {
            AnswerLetter.A: 'A',
            AnswerLetter.B: 'B',
            AnswerLetter.C: 'C',
          },
          correctAnswer: AnswerLetter.A,
        ),
        imagem: null,
        audioText: 'Explicacao. Pergunta?',
      );

      bus.subscribe('key', (_) => throw StateError('listener failed'));
      bus.notify('key', lesson);
      bus.subscribe('key', delivered.add);

      expect(delivered, [lesson]);
      expect(SimRuntimeAudit.events, hasLength(1));
      expect(SimRuntimeAudit.events.single.code, 'listener_failed');
      expect(SimRuntimeAudit.events.single.details['key'], 'key');
    },
  );
}
