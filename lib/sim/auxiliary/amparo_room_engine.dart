import '../state/student_learning_state.dart';
import 'aux_room_models.dart';
import 'student_aux_rooms.dart';

class AmparoPlanEngine {
  const AmparoPlanEngine();

  static const stations = [
    AmparoStation(
      marker: 'AMPARO_001',
      title: 'Reestablishment',
      purpose: 'Restore orientation and reduce failure feeling',
      layer: LessonLayer.l1,
      amparoType: 'reestablishment',
    ),
    AmparoStation(
      marker: 'AMPARO_002',
      title: 'Reconnection',
      purpose: 'Show where the path veered and put student back on track',
      layer: LessonLayer.l1,
      amparoType: 'reconnection',
    ),
    AmparoStation(
      marker: 'AMPARO_003',
      title: 'Capacity Recovery',
      purpose: 'Restore sense of control and prepare return to main flow',
      layer: LessonLayer.l2,
      amparoType: 'recovery_of_capacity',
    ),
  ];

  List<AmparoStation> buildStations() => stations;
}

class AmparoGate {
  const AmparoGate();

  static const threshold = 3;
  static const maxCycles = 3;

  StudentLearningState recordOfficialAttempt(
    StudentLearningState state,
    LessonAttempt attempt, {
    int? itemIdx,
  }) {
    if (attempt.marker.trim().isEmpty) return state;
    final now = attempt.ts;
    final aux = ensureAuxRooms(state);
    final amparo = JsonMap.of(aux['amparo'] as JsonMap);
    final events = <StudentLearningEvent>[];
    final layerValue = attempt.layer.value;

    StudentLearningState commit() =>
        state.copyWith(auxRooms: aux, events: [...state.events, ...events]);

    void resetSequence(String reason) {
      final previousCount = (amparo['sequenceCount'] as num?)?.toInt() ?? 0;
      amparo
        ..['sequenceCount'] = 0
        ..['sequenceMarker'] = null
        ..['sequenceLayer'] = null
        ..['recentAggravants'] = <JsonMap>[]
        ..['updatedAt'] = now;
      if (previousCount > 0) {
        events.add(
          StudentLearningEvent(
            type: 'AMPARO_SEQUENCE_RESET',
            ts: now,
            payload: {
              'marker': attempt.marker,
              'layer': layerValue,
              'reason': reason,
              ..._auxiliaryFlags(),
            },
          ),
        );
      }
    }

    if (attempt.correct) {
      resetSequence('correct_answer');
      aux['amparo'] = amparo;
      return commit();
    }

    final sameScope =
        amparo['sequenceMarker'] == attempt.marker &&
        amparo['sequenceLayer'] == layerValue;
    if (!sameScope) resetSequence('scope_changed');

    final recent = (amparo['recentAggravants'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => JsonMap.from(entry))
        .toList();
    recent.add({
      'marker': attempt.marker,
      'itemIdx': itemIdx,
      'layer': layerValue,
      'letra': attempt.letra.name,
      'sinal': attempt.sinal.value,
      'correct': false,
      'ts': now,
      'unit': 1,
    });
    final nextCount = ((amparo['sequenceCount'] as num?)?.toInt() ?? 0) + 1;
    amparo
      ..['sequenceCount'] = nextCount
      ..['sequenceMarker'] = attempt.marker
      ..['sequenceLayer'] = layerValue
      ..['recentAggravants'] = recent.length > threshold
          ? recent.sublist(recent.length - threshold)
          : recent
      ..['updatedAt'] = now;
    events.add(
      StudentLearningEvent(
        type: 'AMPARO_AGGRAVANT_RECORDED',
        ts: now,
        payload: {
          'marker': attempt.marker,
          'itemIdx': itemIdx,
          'layer': layerValue,
          'sinal': attempt.sinal.value,
          'correct': false,
          'sequenceCount': nextCount,
          'aggravantUnit': 1,
          ..._auxiliaryFlags(),
        },
      ),
    );

    final completedCycles = (amparo['completedCycles'] as num?)?.toInt() ?? 0;
    if (nextCount >= threshold && completedCycles < maxCycles) {
      final nextLevel = (completedCycles + 1).clamp(1, maxCycles);
      amparo
        ..['active'] = false
        ..['pending'] = true
        ..['currentQueue'] = [
          for (final station in const AmparoPlanEngine().buildStations())
            station.marker,
        ]
        ..['currentIndex'] = 0
        ..['amparoLvl'] = nextLevel
        ..['completedCycles'] = nextLevel
        ..['triggeredAggravants'] = amparo['recentAggravants']
        ..['lastTriggeredMarker'] = attempt.marker
        ..['lastTriggeredLayer'] = layerValue
        ..['lastTriggeredAt'] = now;
      events.add(
        StudentLearningEvent(
          type: 'AMPARO_TRIGGERED',
          ts: now,
          payload: {
            'marker': attempt.marker,
            'itemIdx': itemIdx,
            'layer': layerValue,
            'amparoLvl': nextLevel,
            'recentAggravants': amparo['recentAggravants'],
            ..._auxiliaryFlags(),
          },
        ),
      );
      resetSequence('amparo_triggered');
    }

    aux['amparo'] = amparo;
    return commit();
  }
}

JsonMap _auxiliaryFlags() => const {
  'authoritative': false,
  'writesProgress': false,
  'writesTruth': false,
  'writesMastery': false,
  'requiresServerDecision': false,
  'decisionSource': 'sim_app_local_aux_evidence',
  'auxiliary': true,
};
