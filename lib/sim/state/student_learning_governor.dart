import 'learning_decision_engine.dart';
import 'mastery_truth_engine.dart';
import 'student_learning_state.dart';
import 'student_lesson_executor.dart';
import 'student_state_store.dart';

class GovernedAnswerResult {
  const GovernedAnswerResult({
    required this.state,
    required this.mastery,
    required this.nextAction,
    required this.answerEvent,
    required this.masteryEvent,
    required this.decisionEvent,
  });

  final StudentLearningState state;
  final MasteryEvidence mastery;
  final DecisionResult nextAction;
  final CanonicalLearningEvent answerEvent;
  final CanonicalLearningEvent masteryEvent;
  final CanonicalLearningEvent decisionEvent;
}

class StudentLearningGovernor {
  StudentLearningGovernor({
    required this.store,
    this.truthEngine = const MasteryTruthEngine(),
  });

  final StudentStateStore store;
  final MasteryTruthEngine truthEngine;

  GovernedAnswerResult submitAnswer({
    required String lessonLocalId,
    required AnswerLetter selected,
    required AnswerLetter correctAnswer,
    required DecisionSignal signal,
    String source = 'student-learning-governor',
  }) {
    final initial = store.readState(lessonLocalId);
    final curriculum = initial.curriculum;
    final progress = initial.progress;
    if (curriculum == null || curriculum.items.isEmpty || progress == null) {
      throw StateError(
        'StudentLearningGovernor local requer curriculo e progresso ativos.',
      );
    }
    final itemIdx = progress.itemIdx;
    if (itemIdx < 0 || itemIdx >= curriculum.items.length) {
      throw StateError('StudentLearningGovernor local sem item ativo valido.');
    }
    final item = curriculum.items[itemIdx];
    final correct = selected == correctAnswer;
    final attempt = LessonAttempt(
      marker: item.marker,
      layer: progress.layer,
      letra: selected,
      sinal: signal,
      correct: correct,
      ts: store.now(),
    );

    final answerEvent = store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: 'ANSWER_SUBMITTED',
      source: source,
      payload: {
        'marker': item.marker,
        'layer': progress.layer.value,
        'letra': selected.name,
        'sinal': signal.value,
        'correct': correct,
        'attempt': attempt.toJson(),
        'remoteConfirmation': 'not_required',
      },
      mutate: (state, event) {
        return state.copyWith(attempts: [...state.attempts, attempt]);
      },
    );

    final stateAfterAnswer = store.readState(lessonLocalId);
    final mastery = truthEngine.evaluateMarker(stateAfterAnswer, item.marker);
    final masteryEvent = store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: 'MASTERY_EVIDENCE_EVALUATED',
      source: source,
      payload: {...mastery.toJson(), 'remoteConfirmation': 'not_required'},
      mutate: (state, _) => truthEngine.writeTruthToState(state, mastery),
    );

    final stateBeforeDecision = store.readState(lessonLocalId);
    final decision = decideNextActionFromState(stateBeforeDecision);
    final lastCurrentAttempt = stateBeforeDecision.attempts.reversed
        .cast<LessonAttempt?>()
        .firstWhere(
          (attempt) =>
              attempt?.marker == item.marker &&
              attempt?.layer == progress.layer,
          orElse: () => null,
        );
    final decisionEvent = store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: 'LOCAL_ADVANCE_DECIDED',
      source: source,
      payload: {
        'action': decision.actionType.name,
        'reason': decision.reason,
        'confidence': decision.confidence.name,
        'fromMarker': item.marker,
        'remoteConfirmation': 'not_required',
      },
      mutate: (state, _) {
        final currentProgress = state.progress;
        final currentCurriculum = state.curriculum;
        if (currentProgress == null || currentCurriculum == null) {
          return state;
        }
        final applied = applyStudentDecision(
          currentProgress,
          decision,
          itemIdx: currentProgress.itemIdx,
          layer: currentProgress.layer,
          totalItems: currentCurriculum.items.length,
          marker: item.marker,
          markCurrentComplete: lastCurrentAttempt?.correct == true,
        );
        if (!applied.applied) return state;
        final nextProgress = applied.nextProgress;
        final nextMarker =
            nextProgress.itemIdx >= 0 &&
                nextProgress.itemIdx < currentCurriculum.items.length
            ? currentCurriculum.items[nextProgress.itemIdx].marker
            : null;
        return state.copyWith(
          current: LessonCurrent(
            itemIdx: nextProgress.itemIdx,
            marker: nextMarker,
            layer: nextProgress.layer,
            amparoLvl: nextProgress.amparoLvl,
          ),
          progress: nextProgress,
        );
      },
    );

    return GovernedAnswerResult(
      state: store.readState(lessonLocalId),
      mastery: mastery,
      nextAction: decision,
      answerEvent: answerEvent,
      masteryEvent: masteryEvent,
      decisionEvent: decisionEvent,
    );
  }
}
