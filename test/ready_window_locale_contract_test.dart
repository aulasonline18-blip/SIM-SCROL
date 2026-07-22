import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/lesson/dopamine_ready_window_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/lesson/lesson_readiness_resolver.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/live_entry_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

void main() {
  group('L4 ready window com locale textual', () {
    test('hot window com 4 slots no idioma correto passa', () {
      final locale = _locale();
      final health = _inspect(
        slots: _slots(locale, count: 4),
        materials: {
          for (var idx = 0; idx < 4; idx += 1)
            preparedLessonMaterialKey(idx, 'M${idx + 1}', LessonLayer.l1):
                _material(locale, itemIdx: idx, marker: 'M${idx + 1}'),
        },
      );

      expect(health.hotTextReadyCount, 4);
      expect(health.warmTextReadyCount, 4);
      expect(health.invalidLocaleCount, 0);
    });

    test('hot window com 3 corretos e 1 idioma errado falha', () {
      final locale = _locale();
      final wrong = locale.copyWith(targetLanguage: 'Spanish').normalized();
      final health = _inspect(
        slots: _slots(locale, count: 4),
        materials: {
          for (var idx = 0; idx < 3; idx += 1)
            preparedLessonMaterialKey(idx, 'M${idx + 1}', LessonLayer.l1):
                _material(locale, itemIdx: idx, marker: 'M${idx + 1}'),
          preparedLessonMaterialKey(3, 'M4', LessonLayer.l1): _material(
            wrong,
            itemIdx: 3,
            marker: 'M4',
          ),
        },
      );

      expect(health.hotTextReadyCount, 3);
      expect(health.warmTextReadyCount, 3);
      expect(health.invalidLocaleCount, 1);
      expect(health.staleSlots.single['status'], 'staleLocale');
    });

    test('warm cache nao conta material em idioma errado', () {
      final locale = _locale();
      final wrong = locale
          .copyWith(explanationLanguage: 'English')
          .normalized();
      final health = _inspect(
        slots: _slots(locale, count: 5),
        materials: {
          preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): _material(
            locale,
            itemIdx: 0,
            marker: 'M1',
          ),
          preparedLessonMaterialKey(4, 'M5', LessonLayer.l1): _material(
            wrong,
            itemIdx: 4,
            marker: 'M5',
          ),
        },
      );

      expect(health.warmExpectedCount, 5);
      expect(health.warmTextReadyCount, 1);
      expect(health.invalidLocaleCount, 1);
      expect(health.toJson()['invalidLocaleCount'], 1);
    });
  });
}

DopamineReadyWindowHealth _inspect({
  required List<DopamineReadySlot> slots,
  required Map<String, JsonMap> materials,
}) {
  final service = StudentLearningStateService();
  service.write(
    StudentLearningState.empty(
      lessonLocalId: 'lesson-l4',
    ).copyWith(readyLessonMaterials: materials),
  );
  final health = ReadyWindowHealth(
    service: service,
    orchestrator: LessonOrchestrator(
      t02Client: _FakeT02Client(),
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
    ),
    readinessResolver: const LessonReadinessResolver(),
  );
  return health.inspectDopamineReadyWindow(
    lessonLocalId: 'lesson-l4',
    slots: slots,
    source: 'test',
  );
}

List<DopamineReadySlot> _slots(SimLocaleContract locale, {required int count}) {
  const hotSlots = ['A', 'B', 'C', 'D'];
  return List.generate(count, (idx) {
    final marker = 'M${idx + 1}';
    final params = _params(locale, itemIdx: idx, marker: marker);
    return DopamineReadySlot(
      slot: idx < hotSlots.length ? hotSlots[idx] : 'warm-$idx',
      itemIdx: idx,
      marker: marker,
      layer: LessonLayer.l1,
      params: params,
      expectedKey: preparedLessonMaterialKey(idx, marker, LessonLayer.l1),
    );
  });
}

JsonMap _material(
  SimLocaleContract locale, {
  required int itemIdx,
  required String marker,
}) {
  return preparedMaterialFromLesson(
    lesson: _lesson(locale, marker),
    itemIdx: itemIdx,
    marker: marker,
    layer: LessonLayer.l1,
  );
}

SimLocaleContract _locale() => SimLocaleContract.fromUserSelection(
  interfaceLocale: 'pt-BR',
  learningLocale: 'en',
  explanationLanguage: 'Portuguese',
  targetLanguage: 'English',
);

CompleteLessonParams _params(
  SimLocaleContract locale, {
  required int itemIdx,
  required String marker,
}) => CompleteLessonParams(
  lessonLocalId: 'lesson-l4',
  item: marker,
  lang: 'Portuguese',
  academic: 'base',
  layer: LessonLayer.l1,
  mode: LessonMode.session,
  marker: marker,
  itemIdx: itemIdx,
  localeContract: locale,
);

CompleteLesson _lesson(SimLocaleContract localeContract, String marker) =>
    CompleteLesson(
      conteudo: LessonContent(
        explanation: 'Explicacao $marker em portugues.',
        question: 'Pergunta $marker?',
        options: const {
          AnswerLetter.A: 'I am',
          AnswerLetter.B: 'I was',
          AnswerLetter.C: 'I will',
        },
        correctAnswer: AnswerLetter.A,
        whyCorrect: 'Correto.',
      ),
      imagem: null,
      audioText: 'Explicacao $marker em portugues.',
      localeContract: localeContract,
    );

class _FakeT02Client implements T02LessonClient {
  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    throw StateError('server must not be called by ready window locale tests');
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
