import '../lesson/lesson_models.dart';
import '../state/student_learning_state.dart';
import 'classroom_models.dart';
import 'lesson_runtime_engine.dart';

bool hasValidPedagogicalContent(LessonContent? content) {
  if (content == null) return false;
  if (content.explanation.trim().isEmpty) return false;
  if (content.question.trim().isEmpty) return false;
  for (final letter in AnswerLetter.values) {
    if ((content.options[letter] ?? '').trim().isEmpty) return false;
  }
  return true;
}

bool hasRenderablePedagogicalAlternative(LessonRuntimeSnapshot? snapshot) {
  if (snapshot == null) return false;
  if (hasValidPedagogicalContent(snapshot.conteudo)) return true;
  if (snapshot.history.isNotEmpty) return true;

  final phase = snapshot.phase;
  if (phase.type == ClassroomPhaseType.concluido &&
      (phase.message ?? '').trim().isNotEmpty) {
    return true;
  }
  if (phase.type == ClassroomPhaseType.avancoPendente &&
      (phase.letter != null || phase.signal != null)) {
    return true;
  }
  return false;
}

bool shouldShowPreparationForCurrentPedagogicalSlot({
  required LessonRuntimeSnapshot? snapshot,
  required bool runtimeLoading,
}) {
  if (hasRenderablePedagogicalAlternative(snapshot)) return false;

  final phase = snapshot?.phase;
  if (runtimeLoading) return true;
  return phase?.type == ClassroomPhaseType.carregando ||
      phase?.type == ClassroomPhaseType.avancoPendente;
}
