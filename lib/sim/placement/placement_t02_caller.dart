import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
import 'placement_addendum.dart';
import 'placement_blocks.dart';
import 'placement_payload.dart';
import 'placement_plan_engine.dart';

const String placementAssessmentGuidanceReference = placementAssessmentAddendum;

class PlacementT02Result {
  const PlacementT02Result({required this.blocks, this.raw});

  final List<PlacementBlock> blocks;
  final Object? raw;
}

class PlacementT02Caller {
  PlacementT02Caller({required this.t02Client, required this.enabled});

  final T02LessonClient t02Client;
  final bool enabled;

  Future<PlacementT02Result?> callPlacementT02(PlacementContext context) async {
    if (!enabled) return null;
    if (context.curriculumItems.isEmpty) return null;
    final plan = const PlacementPlanEngine().build(context.curriculumItems);
    return callPlacementT02ForPlan(context, plan);
  }

  Future<PlacementT02Result?> callPlacementT02ForPlan(
    PlacementContext context,
    PlacementPlan plan,
  ) async {
    if (!enabled) return null;
    if (plan.waitingForCurriculum || plan.gates.isEmpty) return null;

    final blocks = <PlacementBlock>[];
    final raw = <Object>[];
    for (final gate in plan.gates.take(plan.maxQuestions)) {
      final material = await t02Client.placement(
        T02LessonRequest(
          lessonLocalId: context.lessonLocalId,
          item: gate.text,
          lang: context.language,
          academic: context.academicLevel ?? '',
          layer: LessonLayer.l1,
          mode: 'placement',
          errCount: 0,
          history: const [],
          marker: gate.marker,
          itemIdx: gate.itemIdx,
          profile: {
            ...context.profile,
            'student_profile_internal':
                context.studentProfileInternal ?? context.profile,
            'guidance_for_T02': placementAssessmentAddendum,
            'target_topic': context.objetivo,
            'placement_strategy': plan.strategy,
            'gate_reason': gate.reason,
            'official_curriculum_progress': false,
          },
          addendum: placementAssessmentAddendum,
        ),
      );
      final options = material.options;
      if ((options[AnswerLetter.A] ?? '').isEmpty ||
          (options[AnswerLetter.B] ?? '').isEmpty ||
          (options[AnswerLetter.C] ?? '').isEmpty ||
          material.question.trim().isEmpty) {
        return null;
      }
      final id = 'placement-${gate.itemIdx}-${gate.marker}';
      blocks.add(
        PlacementBlock(
          id: id,
          marker: gate.marker,
          prompt: material.question,
          choices: AnswerLetter.values.map((letter) {
            return PlacementChoice(
              id: '$id-${letter.name.toLowerCase()}',
              label: options[letter] ?? '',
              correct: letter == material.correctAnswer,
            );
          }).toList(),
        ),
      );
      raw.add(material);
    }
    return blocks.isEmpty ? null : PlacementT02Result(blocks: blocks, raw: raw);
  }
}
