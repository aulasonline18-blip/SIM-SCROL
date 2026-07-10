import '../state/student_learning_state.dart';
import '../lesson/lesson_models.dart';
import 'classroom_models.dart';
import 'lesson_answer_feedback.dart';

class LessonOptionModel {
  const LessonOptionModel({required this.letter, required this.text});

  final AnswerLetter letter;
  final String text;
}

class LessonMainViewModel {
  const LessonMainViewModel({
    required this.progress,
    required this.headerLabel,
    required this.options,
    required this.locked,
    required this.nextLabel,
  });

  final double progress;
  final String headerLabel;
  final List<LessonOptionModel> options;
  final bool locked;
  final String nextLabel;
}

LessonMainViewModel buildLessonMainViewModel({
  required List<PlannedItem> baseItems,
  required int mainAdvances,
  required bool isReviewAtivo,
  required PlannedItem? itemAtivo,
  required int itemIdx,
  required LessonLayer layer,
  required ClassroomPhase phase,
  required LessonContent? conteudo,
  required List<PlannedItem> items,
  CurriculumGlobalPlan? globalPlan,
}) {
  final totalBase = baseItems.length;
  final concluidosBase = mainAdvances > totalBase ? totalBase : mainAdvances;
  final displayTotal = globalPlan?.globalTotalItems ?? totalBase;
  final displayAdvances = globalPlan == null
      ? concluidosBase
      : (globalPlan.batchStartItem - 1 + concluidosBase)
            .clamp(0, displayTotal)
            .toInt();
  final progress = displayTotal == 0
      ? 0.0
      : (displayAdvances / displayTotal) * 100;
  final nivelStr = isReviewAtivo
      ? 'aula_review_lbl_${itemAtivo?.reviewLayer?.value ?? 1}'
      : 'aula_layer_${layer.value}';
  final safeIdx = totalBase == 0
      ? concluidosBase + 1
      : (concluidosBase + 1 > totalBase ? totalBase : concluidosBase + 1);
  final displayIdx = globalPlan == null
      ? safeIdx
      : globalPlan.globalItemNumberForLocalIndex(
          (safeIdx - 1).clamp(0, totalBase == 0 ? 0 : totalBase - 1).toInt(),
        );
  final headerLabel = isReviewAtivo
      ? 'aula_review_review:$nivelStr'
      : 'aula_item_of:$displayIdx/$displayTotal:$nivelStr';
  final options = conteudo == null
      ? <LessonOptionModel>[]
      : [
          LessonOptionModel(
            letter: AnswerLetter.A,
            text: conteudo.options[AnswerLetter.A] ?? '',
          ),
          LessonOptionModel(
            letter: AnswerLetter.B,
            text: conteudo.options[AnswerLetter.B] ?? '',
          ),
          LessonOptionModel(
            letter: AnswerLetter.C,
            text: conteudo.options[AnswerLetter.C] ?? '',
          ),
        ];
  final nextLabel = phase.type == ClassroomPhaseType.concluido
      ? nextButtonLabel(
          isReview: isReviewAtivo,
          layer: layer,
          itemIdx: itemIdx,
          plannedLen: items.length,
          wasCorrect: phase.wasCorrect,
          signal: phase.signal,
        )
      : '';
  return LessonMainViewModel(
    progress: progress,
    headerLabel: headerLabel,
    options: options,
    locked:
        phase.type == ClassroomPhaseType.concluido ||
        phase.type == ClassroomPhaseType.processando,
    nextLabel: nextLabel,
  );
}
