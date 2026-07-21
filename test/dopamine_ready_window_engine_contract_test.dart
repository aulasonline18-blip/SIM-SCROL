import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/lesson/dopamine_ready_window_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/live_entry_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

void main() {
  test('DopamineReadyWindowEngine deve preservar comportamento atual', () {
    const lessonId = 'dopamine-contract';
    final prepared = preparedMaterialFromLesson(
      lesson: CompleteLesson(
        conteudo: const LessonContent(
          explanation: 'Texto',
          question: 'Pergunta?',
          options: {
            AnswerLetter.A: 'A',
            AnswerLetter.B: 'B',
            AnswerLetter.C: 'C',
          },
          correctAnswer: AnswerLetter.A,
          whyCorrect: 'Correto.',
        ),
        imagem: null,
        audioText: 'Texto. Pergunta?',
      ),
      itemIdx: 0,
      marker: 'M1',
      layer: LessonLayer.l1,
    );
    final service = StudentLearningStateService(
      seed: {
        lessonId: StudentLearningState.empty(lessonLocalId: lessonId, now: 1000)
            .copyWith(
              readyLessonMaterials: {
                preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): prepared,
              },
            ),
      },
    );
    final engine = DopamineReadyWindowEngine(
      service: service,
      orchestrator: LessonOrchestrator(
        t02Client: _ContractT02Client(),
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
      ),
    );
    final items = List.generate(
      6,
      (index) => DopamineWindowItem(
        text: 'Item ${index + 1}',
        marker: 'M${index + 1}',
      ),
    );

    final plan = engine.buildDopamineWindowPlan(
      fromIdx: 0,
      layer: LessonLayer.l1,
      items: items,
    );
    expect(plan, hasLength(15));
    expect(plan.take(4).map((slot) => slot.idx), [0, 0, 0, 1]);
    expect(plan.take(4).map((slot) => slot.layer), [
      LessonLayer.l1,
      LessonLayer.l2,
      LessonLayer.l3,
      LessonLayer.l1,
    ]);

    final oneItemPlan = engine.buildDopamineWindowPlan(
      fromIdx: 0,
      layer: LessonLayer.l1,
      items: const [DopamineWindowItem(text: 'Item 1', marker: 'M1')],
    );
    expect(oneItemPlan.map((slot) => slot.layer), [
      LessonLayer.l1,
      LessonLayer.l2,
      LessonLayer.l3,
    ]);

    final slots = engine.buildDopamineReadySlots(
      lessonLocalId: lessonId,
      source: 'contract',
      items: items,
      currentItemIdx: 0,
      currentLayer: LessonLayer.l1,
      buildParams: (item, layer) => CompleteLessonParams(
        lessonLocalId: lessonId,
        item: item.text,
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: layer,
        mode: LessonMode.session,
        marker: item.marker,
        itemIdx: items.indexOf(item),
      ),
    );
    final health = engine.inspectDopamineReadyWindow(
      lessonLocalId: lessonId,
      slots: slots,
      source: 'contract',
    );
    expect(health.expectedCount, 15);
    expect(health.readyCount, 1);
    expect(health.hotTextReadyCount, 1);
    expect(health.windowStart?['marker'], 'M1');
  });
}

class _ContractT02Client implements T02LessonClient {
  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    return T02LessonMaterial(
      explanation: 'Explicacao ${request.item}',
      question: 'Pergunta?',
      options: const {
        AnswerLetter.A: 'A',
        AnswerLetter.B: 'B',
        AnswerLetter.C: 'C',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'Correto.',
      whyWrong: const {AnswerLetter.B: 'Erro B.', AnswerLetter.C: 'Erro C.'},
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'contract',
    );
  }

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) =>
      completeLesson(request);
}
