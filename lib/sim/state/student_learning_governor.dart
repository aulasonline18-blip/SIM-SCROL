import 'learning_decision_engine.dart';
import 'mastery_truth_engine.dart';
import 'student_learning_state.dart';
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
    throw StateError(
      'StudentLearningGovernor local esta bloqueado: respostas A/B/C + sinal devem passar pelo SimServidor.',
    );
  }
}
