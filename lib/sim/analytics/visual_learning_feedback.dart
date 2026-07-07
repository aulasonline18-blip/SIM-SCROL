import '../auxiliary/aux_room_models.dart';
import '../classroom/classroom_models.dart';

class VisualLearningFeedbackReport {
  const VisualLearningFeedbackReport({
    required this.answeredWithImage,
    required this.correctWithImage,
    required this.incorrectWithImage,
    required this.doubtAfterImage,
    required this.currentItemHasImage,
  });

  final int answeredWithImage;
  final int correctWithImage;
  final int incorrectWithImage;
  final bool doubtAfterImage;
  final bool currentItemHasImage;

  double get accuracyAfterImage =>
      answeredWithImage == 0 ? 0 : correctWithImage / answeredWithImage;

  bool get hasLearningSignal =>
      answeredWithImage > 0 || doubtAfterImage || currentItemHasImage;
}

class VisualOperationalReport {
  const VisualOperationalReport({required this.feedback});

  final VisualLearningFeedbackReport feedback;

  bool get hasEnoughSignals => feedback.hasLearningSignal;

  bool get needsHumanReview {
    if (feedback.answeredWithImage >= 3 && feedback.accuracyAfterImage < 0.5) {
      return true;
    }
    return feedback.doubtAfterImage;
  }

  Map<String, Object> toJson() => {
    'feedback': {
      'answeredWithImage': feedback.answeredWithImage,
      'correctWithImage': feedback.correctWithImage,
      'incorrectWithImage': feedback.incorrectWithImage,
      'accuracyAfterImage': feedback.accuracyAfterImage,
      'doubtAfterImage': feedback.doubtAfterImage,
      'currentItemHasImage': feedback.currentItemHasImage,
    },
    'needsHumanReview': needsHumanReview,
  };
}

VisualLearningFeedbackReport buildVisualLearningFeedbackReport({
  required List<QuestionHistoryEntry> history,
  required DoubtState doubt,
  String? currentImageUrl,
}) {
  final imageAnswers = history
      .where(
        (entry) => entry.imageUrl != null && entry.imageUrl!.trim().isNotEmpty,
      )
      .toList();
  final correct = imageAnswers.where((entry) => entry.correct).length;
  final currentHasImage =
      currentImageUrl != null && currentImageUrl.trim().isNotEmpty;
  final doubtAfterImage =
      currentHasImage &&
      doubt.status != DoubtStatus.idle &&
      doubt.status != DoubtStatus.error;

  return VisualLearningFeedbackReport(
    answeredWithImage: imageAnswers.length,
    correctWithImage: correct,
    incorrectWithImage: imageAnswers.length - correct,
    doubtAfterImage: doubtAfterImage,
    currentItemHasImage: currentHasImage,
  );
}
