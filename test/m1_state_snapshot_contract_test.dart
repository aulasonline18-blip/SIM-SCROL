import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _fixturePath =
    '/root/sim-work/sim-api/docs/contracts/m1_state_snapshot_fixture.json';

void main() {
  test('App rejects shared M1.9 empty old snapshot over rich state', () {
    final file = File(_fixturePath);
    expect(file.existsSync(), isTrue);
    final fixture = Map<String, dynamic>.from(
      jsonDecode(file.readAsStringSync()) as Map,
    );

    expect(fixture['contractName'], 'StrongStateSnapshotContract');
    expect(fixture['contractVersion'], 'sim.strong_state_snapshot.v1');

    final existing = Map<String, dynamic>.from(fixture['existing'] as Map);
    final incoming = Map<String, dynamic>.from(fixture['incoming'] as Map);
    final existingState = StudentLearningState.fromJson(
      Map<String, dynamic>.from(existing['state'] as Map),
    );
    final incomingState = StudentLearningState.fromJson(
      Map<String, dynamic>.from(incoming['state'] as Map),
    );

    expect(existingState.lessonLocalId, fixture['lessonLocalId']);
    expect(incomingState.lessonLocalId, fixture['lessonLocalId']);
    expect(_richness(existingState), greaterThan(_richness(incomingState)));
    expect(
      _progressRank(existingState),
      greaterThan(_progressRank(incomingState)),
    );
    expect(_wouldRejectRegression(existingState, incomingState), isTrue);

    final expected = Map<String, dynamic>.from(fixture['expected'] as Map);
    expect(expected['rejected'], isTrue);
    expect(expected['code'], 'STATE_RICHNESS_REGRESSION');
    expect(expected['remoteHighWaterMark'], existing['clientScore']);
  });
}

int _richness(StudentLearningState state) {
  var score = 0;
  if ((state.profile.objetivo ?? '').trim().isNotEmpty) score += 10;
  if ((state.profile.language ?? state.profile.stableLang ?? '')
      .trim()
      .isNotEmpty) {
    score += 5;
  }
  score += (state.curriculum?.items.length ?? 0) * 10;
  if (state.current != null) score += 10;
  if (state.progress != null) {
    score +=
        20 +
        state.progress!.historia.length +
        state.progress!.concluidos.length;
  }
  score += state.attempts.length * 3;
  score += state.events.length;
  if (state.currentLessonMaterial != null) score += 15;
  score += state.readyLessonMaterials.length * 10;
  return score;
}

int _progressRank(StudentLearningState state) {
  final progress = state.progress;
  final current = state.current;
  return (progress?.mainAdvances ?? 0) * 100000 +
      (progress?.itemIdx ?? current?.itemIdx ?? 0) * 1000 +
      (progress?.layer.value ?? current?.layer.value ?? 1) * 100 +
      (progress?.concluidos.length ?? 0) * 10 +
      state.attempts.length;
}

bool _wouldRejectRegression(
  StudentLearningState existing,
  StudentLearningState incoming,
) {
  return _richness(incoming) < _richness(existing) &&
      _progressRank(incoming) <= _progressRank(existing);
}
