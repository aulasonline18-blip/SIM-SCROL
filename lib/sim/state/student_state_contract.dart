import 'student_learning_state.dart';

class StudentStateContract {
  const StudentStateContract();

  int richnessScore(StudentLearningState state) {
    final progress = state.progress;
    var score = 0;
    if ((state.profile.objetivo ?? '').trim().isNotEmpty) score += 10;
    if ((state.profile.language ?? state.profile.stableLang ?? '')
        .trim()
        .isNotEmpty) {
      score += 5;
    }
    if (state.curriculum?.items.isNotEmpty == true) {
      score += 20 + state.curriculum!.items.length;
    }
    if (state.current != null) score += 10;
    if (progress != null) {
      score +=
          20 +
          progress.historia.length +
          progress.concluidos.length +
          progress.pendentesMarkers.length +
          progress.mainAdvances;
    }
    score += state.attempts.length * 3;
    score += state.events.length;
    if (state.currentLessonMaterial != null) score += 15;
    score += state.readyLessonMaterials.length * 10;
    if (state.auxRooms != null) score += 5;
    if (state.truth.masteryEvidence.isNotEmpty ||
        state.truth.itemConsolidationStatus.isNotEmpty) {
      score += 5;
    }
    return score;
  }

  bool isRegression({
    required StudentLearningState existing,
    required StudentLearningState incoming,
  }) {
    return richnessScore(incoming) < richnessScore(existing) &&
        _progressRank(incoming) <= _progressRank(existing);
  }

  int _progressRank(StudentLearningState state) {
    final progress = state.progress;
    final current = state.current;
    final itemIdx = progress?.itemIdx ?? current?.itemIdx ?? 0;
    final layer = progress?.layer ?? current?.layer ?? LessonLayer.l1;
    final mainAdvances = progress?.mainAdvances ?? 0;
    final completed = progress?.concluidos.length ?? 0;
    return mainAdvances * 100000 +
        itemIdx * 1000 +
        layer.value * 100 +
        completed * 10 +
        state.attempts.length;
  }
}
