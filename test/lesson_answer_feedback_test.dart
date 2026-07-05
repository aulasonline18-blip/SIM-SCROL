import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/classroom/lesson_answer_feedback.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  test('answer feedback separates correctness from confidence signal', () {
    expect(
      buildLessonAnswerFeedback(
        correct: true,
        signal: DecisionSignal.one,
        isReview: false,
      ),
      'aula_fb_correct',
    );
    expect(
      buildLessonAnswerFeedback(
        correct: true,
        signal: DecisionSignal.two,
        isReview: false,
      ),
      'aula_fb_correct_rev',
    );
    expect(
      buildLessonAnswerFeedback(
        correct: true,
        signal: DecisionSignal.three,
        isReview: false,
      ),
      'aula_fb_correct_dont_know',
    );
    expect(
      buildLessonAnswerFeedback(
        correct: false,
        signal: DecisionSignal.one,
        isReview: false,
      ),
      'aula_fb_wrong_confident',
    );
    expect(
      buildLessonAnswerFeedback(
        correct: false,
        signal: DecisionSignal.two,
        isReview: false,
      ),
      'aula_fb_wrong_uncertain',
    );
    expect(
      buildLessonAnswerFeedback(
        correct: false,
        signal: DecisionSignal.three,
        isReview: false,
      ),
      'aula_fb_wrong_dont_know',
    );
  });
}
