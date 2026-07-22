import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/lesson/dopamine_ready_window_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/lesson/student_lesson_material_service.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

void main() {
  test('ready window nao deduplica jobs de idiomas diferentes', () {
    final service = StudentLearningStateService();
    final t02 = _FakeT02Client();
    final orchestrator = LessonOrchestrator(
      t02Client: t02,
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
    );
    final material = StudentLessonMaterialService(
      stateService: service,
      orchestrator: orchestrator,
      readyWindowEngine: DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      ),
    );
    final pt = SimLocaleContract.fromUserSelection(
      interfaceLocale: 'pt-BR',
      learningLocale: 'en',
      explanationLanguage: 'Portuguese',
      targetLanguage: 'English',
    );
    final en = pt.copyWith(explanationLanguage: 'English').normalized();
    service.write(
      StudentLearningState.empty(
        lessonLocalId: 'lesson-locale-window',
      ).copyWith(localeContract: pt),
    );

    material.maintainLessonReadyWindow(
      lessonLocalId: 'lesson-locale-window',
      topic: 'Topic',
      itemIdx: 0,
      layer: LessonLayer.l1,
      source: 'test',
      items: const [DopamineWindowItem(text: 'Item 1', marker: 'M1')],
    );
    service.mutate(
      'lesson-locale-window',
      (state) => state.copyWith(localeContract: en),
    );
    material.maintainLessonReadyWindow(
      lessonLocalId: 'lesson-locale-window',
      topic: 'Topic',
      itemIdx: 0,
      layer: LessonLayer.l1,
      source: 'test',
      items: const [DopamineWindowItem(text: 'Item 1', marker: 'M1')],
    );

    final jobs = service.read('lesson-locale-window')!.queuedActions;
    final keys = jobs.map((job) => job['idempotency_key']).toSet();

    expect(jobs, hasLength(2));
    expect(keys, hasLength(2));
    expect(keys.join('\n'), contains(pt.cacheIdentity()));
    expect(keys.join('\n'), contains(en.cacheIdentity()));
    expect(t02.calls, 0);
  });
}

class _FakeT02Client implements T02LessonClient {
  int calls = 0;

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    calls += 1;
    throw StateError('T02 must not be called by ready window identity test');
  }

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) =>
      completeLesson(request);
}
