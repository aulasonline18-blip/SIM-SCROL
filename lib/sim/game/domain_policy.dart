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
    required this.shouldContinue,
    required this.scheduleReview,
    required this.requiresRecovery,
    required this.offerSupport,
    required this.falseConfidence,
    required this.protectSelfEsteem,
    required this.requiresCheck,
    required this.canConsolidate,
  });

  final DomainDecisionKind kind;
  final bool wasCorrect;
  final AnswerLetter selectedAnswer;
  final AnswerLetter correctAnswer;
  final DecisionSignal qualifier;
  final LessonLayer layer;
  final String reason;
  final bool shouldContinue;
  final bool scheduleReview;
  final bool requiresRecovery;
  final bool offerSupport;
  final bool falseConfidence;
  final bool protectSelfEsteem;
  final bool requiresCheck;
  final bool canConsolidate;
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

    if (selectedAnswer != card.correctAnswer) {
      if (qualifier == DecisionSignal.one) {
        return DomainDecision(
          kind: DomainDecisionKind.recovery,
          wasCorrect: false,
          selectedAnswer: selectedAnswer,
          correctAnswer: card.correctAnswer,
          qualifier: qualifier,
          layer: card.layer,
          reason: 'incorrect_signal_1_false_confidence',
          shouldContinue: false,
          scheduleReview: true,
          requiresRecovery: true,
          offerSupport: true,
          falseConfidence: true,
          protectSelfEsteem: false,
          requiresCheck: true,
          canConsolidate: false,
        );
      }

      return DomainDecision(
        kind: DomainDecisionKind.support,
        wasCorrect: false,
        selectedAnswer: selectedAnswer,
        correctAnswer: card.correctAnswer,
        qualifier: qualifier,
        layer: card.layer,
        reason: qualifier == DecisionSignal.two
            ? 'incorrect_signal_2_normal_support'
            : 'incorrect_signal_3_protect_self_esteem',
        shouldContinue: false,
        scheduleReview: true,
        requiresRecovery: true,
        offerSupport: true,
        falseConfidence: false,
        protectSelfEsteem: true,
        requiresCheck: true,
        canConsolidate: false,
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
        reason: card.layer == LessonLayer.l3
            ? 'layer_3_correct_signal_1_continue'
            : 'correct_signal_1_continue_lesson',
        shouldContinue: true,
        scheduleReview: true,
        requiresRecovery: false,
        offerSupport: false,
        falseConfidence: false,
        protectSelfEsteem: false,
        requiresCheck: false,
        canConsolidate: true,
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
        reason: card.layer == LessonLayer.l3
            ? 'layer_3_correct_signal_2_review_check'
            : 'correct_signal_2_review_check',
        shouldContinue: true,
        scheduleReview: true,
        requiresRecovery: false,
        offerSupport: false,
        falseConfidence: false,
        protectSelfEsteem: false,
        requiresCheck: true,
        canConsolidate: false,
      );
    }

    return DomainDecision(
      kind: DomainDecisionKind.support,
      wasCorrect: true,
      selectedAnswer: selectedAnswer,
      correctAnswer: card.correctAnswer,
      qualifier: qualifier,
      layer: card.layer,
      reason: card.layer == LessonLayer.l3
          ? 'layer_3_correct_signal_3_support_check'
          : 'correct_signal_3_support_check',
      shouldContinue: false,
      scheduleReview: true,
      requiresRecovery: false,
      offerSupport: true,
      falseConfidence: false,
      protectSelfEsteem: true,
      requiresCheck: true,
      canConsolidate: false,
    );
  }
}
