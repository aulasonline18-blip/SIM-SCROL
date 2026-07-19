import '../state/student_learning_state.dart';
import 'placement_blocks.dart';

class PlacementScoringEngine {
  const PlacementScoringEngine();

  PlacementResult? score({
    required List<CurriculumItem> curriculumItems,
    required List<PlacementBlock> blocks,
    required List<PlacementAnswer> answers,
    int? now,
  }) {
    if (curriculumItems.isEmpty) return null;
    if (blocks.isEmpty || answers.isEmpty) {
      return PlacementResult(
        startMarker: curriculumItems.first.marker,
        startItemIdx: 0,
        masteredMarkers: const [],
        failedMarkers: const [],
        uncertainMarkers: const [],
        testedMarkers: const [],
        confidence: 'low',
        reason: 'Dados insuficientes; inicio seguro no começo.',
        source: 'adaptive_t02',
        scoredAt: now ?? DateTime.now().millisecondsSinceEpoch,
      );
    }

    final answerByMarker = {
      for (final answer in answers) answer.marker: answer,
    };
    final testedMarkers = answers.map((answer) => answer.marker).toList();
    final mastered = <String>[];
    final failed = <String>[];
    final uncertain = <String>[];

    for (final block in blocks) {
      final answer = answerByMarker[block.marker];
      if (answer == null) {
        continue;
      } else if (answer.correct && answer.signal != 3) {
        mastered.add(block.marker);
      } else if (answer.correct) {
        uncertain.add(block.marker);
      } else {
        failed.add(block.marker);
      }
    }

    final markerToIndex = {
      for (var i = 0; i < curriculumItems.length; i++)
        curriculumItems[i].marker: i,
    };
    final failedIndexes =
        failed.map((marker) => markerToIndex[marker]).whereType<int>().toList()
          ..sort();
    final masteredIndexes =
        mastered
            .map((marker) => markerToIndex[marker])
            .whereType<int>()
            .toList()
          ..sort();
    final uncertainIndexes =
        uncertain
            .map((marker) => markerToIndex[marker])
            .whereType<int>()
            .toList()
          ..sort();

    var startIdx = 0;
    var confidence = 'low';
    var reason = 'Dados fracos; inicio seguro no começo.';

    if (failedIndexes.isNotEmpty) {
      final firstFailed = failedIndexes.first;
      final lastMasteredBeforeFailure = masteredIndexes
          .where((index) => index < firstFailed)
          .fold<int>(-1, (a, b) => a > b ? a : b);
      startIdx = lastMasteredBeforeFailure < 0
          ? 0
          : (lastMasteredBeforeFailure + 1).clamp(0, firstFailed);
      confidence = firstFailed == 0 ? 'high' : 'medium';
      reason =
          'Aluno dominou ate antes da primeira lacuna provavel e falhou em ${curriculumItems[firstFailed].marker}; inicio seguro em ${curriculumItems[startIdx].marker}.';
    } else if (uncertainIndexes.isNotEmpty) {
      final firstUncertain = uncertainIndexes.first;
      final lastMasteredBeforeUncertain = masteredIndexes
          .where((index) => index < firstUncertain)
          .fold<int>(-1, (a, b) => a > b ? a : b);
      startIdx = lastMasteredBeforeUncertain < 0
          ? 0
          : (lastMasteredBeforeUncertain + 1).clamp(0, firstUncertain);
      confidence = 'medium';
      reason =
          'Houve incerteza em ${curriculumItems[firstUncertain].marker}; inicio um pouco antes para evitar falso positivo.';
    } else if (masteredIndexes.isNotEmpty) {
      final firstTested = testedMarkers
          .map((marker) => markerToIndex[marker])
          .whereType<int>()
          .fold<int>(curriculumItems.length, (a, b) => a < b ? a : b);
      final hasConfirmedBase = firstTested == 0;
      final lastMastered = masteredIndexes.last;
      startIdx = hasConfirmedBase
          ? (lastMastered + 1).clamp(0, curriculumItems.length - 1)
          : 0;
      confidence = hasConfirmedBase ? 'high' : 'low';
      reason = hasConfirmedBase
          ? 'Padrao coerente de dominio; inicio no proximo ponto seguro.'
          : 'Acerto avancado isolado nao confirma a base; inicio seguro no começo.';
    }

    final startMarker = curriculumItems[startIdx].marker;
    return PlacementResult(
      startMarker: startMarker,
      startItemIdx: startIdx,
      masteredMarkers: mastered,
      failedMarkers: failed,
      uncertainMarkers: uncertain,
      testedMarkers: testedMarkers,
      confidence: confidence,
      reason: reason,
      source: 'adaptive_t02',
      scoredAt: now ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool shouldStopEarly({
    required List<CurriculumItem> curriculumItems,
    required List<PlacementBlock> blocks,
    required List<PlacementAnswer> answers,
  }) {
    if (answers.isEmpty) return false;
    if (answers.length >= blocks.length) return true;
    if (answers.length >= 7) return true;
    final current = score(
      curriculumItems: curriculumItems,
      blocks: blocks.take(answers.length).toList(growable: false),
      answers: answers,
    );
    if (current == null) return false;
    return current.confidence == 'high' && current.failedMarkers.isNotEmpty;
  }
}
