import '../state/student_learning_state.dart';
import 'pedagogical_card.dart';

enum DomainDecisionKind { continueLesson, review, recovery, support, doubt }

final class DomainDecision {
  const DomainDecision({
    required this.kind,
    required this.wasCorrect,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.qualifier,
    required this.layer,
    required this.reason,
  });

  final DomainDecisionKind kind;
  final bool wasCorrect;
  final AnswerLetter selectedAnswer;
  final AnswerLetter correctAnswer;
  final DecisionSignal qualifier;
  final LessonLayer layer;
  final String reason;
}

final class DomainPolicyException implements Exception {
  const DomainPolicyException(this.message);

  final String message;

  @override
  String toString() => 'DomainPolicyException: $message';
}

final class DomainPolicy {
  const DomainPolicy();

  DomainDecision decideAfterQualifier({
    required PedagogicalCard card,
    required AnswerLetter selectedAnswer,
    required DecisionSignal qualifier,
  }) {
    card.validate();
    if (!card.options.containsKey(selectedAnswer)) {
      throw const DomainPolicyException('answer_not_available');
    }
    if (!card.qualifiers.containsKey(qualifier)) {
      throw const DomainPolicyException('qualifier_not_available');
    }

    final wasCorrect = selectedAnswer == card.correctAnswer;
    if (!wasCorrect) {
      return DomainDecision(
        kind: DomainDecisionKind.recovery,
        wasCorrect: false,
        selectedAnswer: selectedAnswer,
        correctAnswer: card.correctAnswer,
        qualifier: qualifier,
        layer: card.layer,
        reason: 'incorrect_answer_requires_recovery',
      );
    }

    if (card.layer == LessonLayer.l3) {
      return DomainDecision(
        kind: DomainDecisionKind.continueLesson,
        wasCorrect: true,
        selectedAnswer: selectedAnswer,
        correctAnswer: card.correctAnswer,
        qualifier: qualifier,
        layer: card.layer,
        reason: 'layer_3_correct_continues_without_new_layer',
      );
    }

    if (qualifier == DecisionSignal.one) {
      return DomainDecision(
        kind: DomainDecisionKind.continueLesson,
        wasCorrect: true,
        selectedAnswer: selectedAnswer,
        correctAnswer: card.correctAnswer,
        qualifier: qualifier,
        layer: card.layer,
        reason: 'correct_signal_1_continue_lesson',
      );
    }

    if (qualifier == DecisionSignal.two) {
      return DomainDecision(
        kind: DomainDecisionKind.review,
        wasCorrect: true,
        selectedAnswer: selectedAnswer,
        correctAnswer: card.correctAnswer,
        qualifier: qualifier,
        layer: card.layer,
        reason: 'correct_signal_2_review',
      );
    }

    return DomainDecision(
      kind: DomainDecisionKind.support,
      wasCorrect: true,
      selectedAnswer: selectedAnswer,
      correctAnswer: card.correctAnswer,
      qualifier: qualifier,
      layer: card.layer,
      reason: 'correct_signal_3_support',
    );
  }
}
