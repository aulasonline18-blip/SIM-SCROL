import '../state/student_learning_state.dart';
import 'lesson_position_engine.dart';

class LocalAdvanceEngine {
  const LocalAdvanceEngine();

  bool hasEvidenceForCurrentPosition(
    StudentLearningState state,
    LessonPositionState position,
  ) {
    final marker = position.itemAtivo?.marker ?? state.current?.marker;
    if (marker == null || marker.trim().isEmpty) return false;
    return state.attempts.any(
      (attempt) => attempt.marker == marker && attempt.layer == position.layer,
    );
  }
}
