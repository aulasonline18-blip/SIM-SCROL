import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/experience/curriculum_utils.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  group('C2 curriculum parts', () {
    test('parser reads continuation plan and dedupes repeated batch items', () {
      final rawCurriculum = {
        'curriculum_plan': {
          'globalTotalItems': 360,
          'operationalBatchLimit': 80,
          'batchStartItem': 81,
          'batchEndItem': 160,
          'partNumber': 2,
          'partTitle': 'Matemática financeira para concurso — Parte 2',
          'unitsCovered': 'juros compostos',
          'unitsPending': 'taxas; descontos',
          'nextGlobalItemToRequest': 161,
          'continuationNeeded': true,
          'continuationInstruction': 'Continue do item 161.',
        },
        'items': [
          {
            'marker': 'M81',
            'title': 'Juros compostos',
            'microitem_for_teacher': 'Entender crescimento composto',
            'global_item_index': 81,
          },
          {
            'marker': 'M81',
            'title': 'Duplicado',
            'microitem_for_teacher': 'Não deve entrar duas vezes',
            'global_item_index': 81,
          },
          {
            'marker': 'M82',
            'title': 'Montante',
            'microitem_for_teacher': 'Calcular montante composto',
            'global_item_index': 82,
          },
        ],
      };

      final items = dedupeCurriculumBatchItems(
        normalizeCurriculumItems(rawCurriculum),
      );
      final plan = normalizeCurriculumGlobalPlan(
        rawCurriculum: rawCurriculum,
        rawQualityCheck: null,
        localItemCount: items.length,
      );

      expect(items, hasLength(2));
      expect(plan?.globalTotalItems, 360);
      expect(plan?.batchStartItem, 81);
      expect(plan?.batchEndItem, 160);
      expect(plan?.partNumber, 2);
      expect(plan?.continuationNeeded, isTrue);
    });

    test(
      'state persists global plan and old curriculum remains compatible',
      () {
        final curriculum = StudentCurriculum(
          topic: 'Matemática financeira para concurso',
          totalItems: 80,
          generatedAt: 10,
          provisional: false,
          items: const [
            CurriculumItem(marker: 'M81', text: 'Item 81'),
            CurriculumItem(marker: 'M82', text: 'Item 82'),
          ],
          globalPlan: const CurriculumGlobalPlan(
            globalTotalItems: 360,
            operationalBatchLimit: 80,
            batchStartItem: 81,
            batchEndItem: 160,
            partNumber: 2,
            partTitle: 'Parte 2',
            continuationNeeded: true,
            nextGlobalItemToRequest: 161,
            continuationInstruction: 'Continue do item 161.',
          ),
        );

        final restored = StudentCurriculum.fromJson(curriculum.toJson());
        expect(restored.displayTotalItems, 360);
        expect(restored.displayItemNumberForLocalIndex(0), 81);
        expect(restored.displayPartTitle, 'Parte 2');
        expect(restored.globalPlan?.nextGlobalItemToRequest, 161);

        final old = StudentCurriculum.fromJson({
          'topic': 'Frações',
          'totalItems': 3,
          'items': [
            {'marker': 'M1', 'text': 'Metade'},
          ],
        });
        expect(old.displayTotalItems, 3);
        expect(old.displayItemNumberForLocalIndex(0), 1);
        expect(old.globalPlan, isNull);
      },
    );

    test(
      'lesson header shows global progress instead of local batch total',
      () {
        final vm = buildLessonMainViewModel(
          baseItems: const [
            PlannedItem(marker: 'M81', text: 'Item 81'),
            PlannedItem(marker: 'M82', text: 'Item 82'),
          ],
          mainAdvances: 0,
          isReviewAtivo: false,
          itemAtivo: const PlannedItem(marker: 'M81', text: 'Item 81'),
          itemIdx: 0,
          layer: LessonLayer.l1,
          phase: const ClassroomPhase.reading(),
          conteudo: null,
          items: const [
            PlannedItem(marker: 'M81', text: 'Item 81'),
            PlannedItem(marker: 'M82', text: 'Item 82'),
          ],
          globalPlan: const CurriculumGlobalPlan(
            globalTotalItems: 360,
            batchStartItem: 81,
            batchEndItem: 160,
            partNumber: 2,
          ),
        );

        expect(vm.headerLabel, 'aula_item_of:81/360:aula_layer_1');
        expect(vm.progress, closeTo(80 / 360 * 100, 0.01));
      },
    );

    test('software can build the next batch continuation request safely', () {
      final state = StudentLearningState.empty(lessonLocalId: 'lesson-c2')
          .copyWith(
            profile: const StudentProfile(objetivo: 'Concurso'),
            curriculum: const StudentCurriculum(
              topic: 'Matemática financeira para concurso',
              totalItems: 80,
              generatedAt: 10,
              provisional: false,
              items: [CurriculumItem(marker: 'M1', text: 'Item 1')],
              globalPlan: CurriculumGlobalPlan(
                globalTotalItems: 360,
                operationalBatchLimit: 80,
                batchStartItem: 1,
                batchEndItem: 80,
                partNumber: 1,
                unitsPending: 'juros compostos; descontos',
                nextGlobalItemToRequest: 81,
                continuationNeeded: true,
                continuationInstruction:
                    'Peça o próximo lote a partir do item 81.',
              ),
            ),
          );

      final request = buildCurriculumContinuationRequest(state);
      expect(request, isNotNull);
      expect(request?['nextGlobalItemToRequest'], 81);
      expect(request?['globalTotalItems'], 360);
      expect(request?['continuationInstruction'], contains('item 81'));
      expect((request?['previousBatch'] as Map)['end'], 80);
    });
  });
}
