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

  factory VisualLearningFeedbackReport.fromLesson({
    required List<QuestionHistoryEntry> history,
    required DoubtState doubt,
    String? currentImageUrl,
  }) {
    final imageAnswers = history
        .where((entry) => (entry.imageUrl ?? '').trim().isNotEmpty)
        .toList();
    final correct = imageAnswers.where((entry) => entry.correct).length;
    final currentHasImage = (currentImageUrl ?? '').trim().isNotEmpty;
    return VisualLearningFeedbackReport(
      answeredWithImage: imageAnswers.length,
      correctWithImage: correct,
      incorrectWithImage: imageAnswers.length - correct,
      doubtAfterImage:
          currentHasImage &&
          doubt.status != DoubtStatus.idle &&
          doubt.status != DoubtStatus.error,
      currentItemHasImage: currentHasImage,
    );
  }

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
  bool get needsHumanReview =>
      (feedback.answeredWithImage >= 3 && feedback.accuracyAfterImage < 0.5) ||
      feedback.doubtAfterImage;

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
