import '../state/student_learning_state.dart';
import '../state/mastery_truth_engine.dart';

JsonMap createEmptyReviewRoom() => {
  'enabled': false,
  'active': false,
  'requestedCount': 0,
  'currentQueue': <String>[],
  'currentIndex': 0,
  'sequentialCursor': 0,
  'sourceLessonLocalId': null,
  'startedAt': null,
  'updatedAt': null,
  'completedAt': null,
};

JsonMap createEmptyRecoveryRoom() => {
  'enabled': false,
  'active': false,
  'currentQueue': <String>[],
  'currentItems': <JsonMap>[],
  'currentIndex': 0,
  'sourceLessonLocalId': null,
  'startedAt': null,
  'updatedAt': null,
  'completedAt': null,
};

JsonMap createEmptyAmparoRoom() => {
  'enabled': true,
  'active': false,
  'pending': false,
  'currentQueue': <String>[],
  'currentIndex': 0,
  'amparoLvl': 0,
  'completedCycles': 0,
  'sequenceCount': 0,
  'sequenceMarker': null,
  'sequenceLayer': null,
  'recentAggravants': <JsonMap>[],
  'triggeredAggravants': <JsonMap>[],
  'lastTriggeredMarker': null,
  'lastTriggeredLayer': null,
  'lastTriggeredAt': null,
  'startedAt': null,
  'updatedAt': null,
  'completedAt': null,
};

JsonMap createEmptyAuxRooms() => {
  'review': createEmptyReviewRoom(),
  'recovery': createEmptyRecoveryRoom(),
  'amparo': createEmptyAmparoRoom(),
  'doubt': {'history': <JsonMap>[]},
  'pendingMap': <JsonMap>[],
};

JsonMap ensureAuxRooms(StudentLearningState state) {
  final existing = state.auxRooms == null
      ? createEmptyAuxRooms()
      : JsonMap.of(state.auxRooms!);
  existing['review'] = JsonMap.of(
    (existing['review'] as Map?)?.cast<String, dynamic>() ??
        createEmptyReviewRoom(),
  );
  existing['recovery'] = JsonMap.of(
    (existing['recovery'] as Map?)?.cast<String, dynamic>() ??
        createEmptyRecoveryRoom(),
  );
  existing['amparo'] = JsonMap.of(
    (existing['amparo'] as Map?)?.cast<String, dynamic>() ??
        createEmptyAmparoRoom(),
  );
  existing['amparo']['recentAggravants'] =
      (existing['amparo']['recentAggravants'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => JsonMap.from(entry))
          .toList();
  existing['amparo']['triggeredAggravants'] =
      (existing['amparo']['triggeredAggravants'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => JsonMap.from(entry))
          .toList();
  existing['doubt'] = JsonMap.of(
    (existing['doubt'] as Map?)?.cast<String, dynamic>() ??
        const {'history': <JsonMap>[]},
  );
  existing['doubt']['history'] =
      (existing['doubt']['history'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => JsonMap.from(entry))
          .toList();
  existing['pendingMap'] = (existing['pendingMap'] as List? ?? const [])
      .whereType<Map>()
      .map((entry) => JsonMap.from(entry))
      .toList();
  return existing;
}

StudentLearningState recordDoubtAuxiliaryEvent(
  StudentLearningState state, {
  required String type,
  required JsonMap payload,
}) {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final aux = ensureAuxRooms(state);
  final doubt = JsonMap.of(aux['doubt'] as JsonMap);
  final history = (doubt['history'] as List? ?? const [])
      .whereType<Map>()
      .map((entry) => JsonMap.from(entry))
      .toList();
  history.add({
    ...payload,
    'eventType': type,
    'ts': ts,
    'source': 'doubt',
    'authoritative': false,
    'writesProgress': false,
    'writesTruth': false,
    'writesMastery': false,
    'auxiliary': true,
    'itemAdvanced': false,
    'layerChanged': false,
    'nextAction': 'return_to_lesson',
  });
  doubt['history'] = history;
  aux['doubt'] = doubt;
  return state.copyWith(
    auxRooms: aux,
    events: [
      ...state.events,
      StudentLearningEvent(
        type: type,
        ts: ts,
        payload: {
          ...payload,
          'source': 'doubt',
          'authoritative': false,
          'writesProgress': false,
          'writesTruth': false,
          'writesMastery': false,
          'auxiliary': true,
          'itemAdvanced': false,
          'layerChanged': false,
          'nextAction': 'return_to_lesson',
        },
      ),
    ],
  );
}

List<JsonMap> pendingMapOf(JsonMap auxRooms) =>
    (auxRooms['pendingMap'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => JsonMap.from(entry))
        .toList();

bool isStrongRecoveryPending(JsonMap entry) {
  if (entry['status'] != 'pending') return false;
  final signal = DecisionSignalValue.fromValue(entry['signal']);
  final priority = (entry['priority'] ?? '').toString();
  final reason = (entry['reason'] ?? '').toString();
  final masteryStatus = (entry['masteryStatus'] ?? '').toString();
  return priority == 'high' ||
      signal == DecisionSignal.three ||
      {
        'wrong',
        'wrong_answer',
        'false_mastery',
        'falseMastery',
        'low_confidence_heavy',
        'review_failed',
        'needsReinforcement',
      }.contains(reason) ||
      masteryStatus == MasteryStatus.falseMastery.name ||
      masteryStatus == 'needsReinforcement';
}

StudentLearningState mirrorAttemptToAuxRooms(
  StudentLearningState state,
  LessonAttempt attempt,
) {
  if (attempt.sinal == DecisionSignal.one && attempt.correct) {
    return clearPendingIfSignalOne(state, attempt.marker, attempt.layer);
  }
  return registerPendingFromAttempt(state, attempt);
}

StudentLearningState registerPendingFromAttempt(
  StudentLearningState state,
  LessonAttempt attempt,
) {
  if (attempt.marker.trim().isEmpty) return state;
  final signal = attempt.correct == false
      ? DecisionSignal.three
      : attempt.sinal;
  if (signal == DecisionSignal.one) return state;
  final aux = ensureAuxRooms(state);
  final pending = pendingMapOf(aux);
  final now = attempt.ts;
  final layerValue = attempt.layer.value;
  final existingIndex = pending.indexWhere(
    (entry) =>
        entry['marker'] == attempt.marker &&
        entry['status'] == 'pending' &&
        entry['layer'] == layerValue,
  );
  final reason = attempt.correct == false
      ? 'wrong'
      : signal == DecisionSignal.two
      ? 'low_confidence_light'
      : 'low_confidence_heavy';
  final entry = {
    'marker': attempt.marker,
    'itemIdx': null,
    'layer': layerValue,
    'signal': signal.value,
    'reason': reason,
    'priority': signal == DecisionSignal.three ? 'high' : 'medium',
    'origin': 'answer_attempt',
    'lessonLocalId': state.lessonLocalId,
    'firstRegisteredAt': existingIndex >= 0
        ? pending[existingIndex]['firstRegisteredAt']
        : now,
    'lastUpdatedAt': now,
    'clearedAt': null,
    'status': 'pending',
  };
  if (existingIndex >= 0) {
    pending[existingIndex] = entry;
  } else {
    pending.add(entry);
  }
  aux['pendingMap'] = pending;
  return state.copyWith(
    auxRooms: aux,
    events: [
      ...state.events,
      StudentLearningEvent(
        type: 'PENDING_REGISTERED',
        ts: now,
        payload: {
          'marker': attempt.marker,
          'layer': layerValue,
          'signal': signal.value,
          'reason': reason,
        },
      ),
      StudentLearningEvent(
        type: 'REVIEW_SCHEDULED',
        ts: now,
        payload: {
          'marker': attempt.marker,
          'layer': layerValue,
          'signal': signal.value,
          'reason': reason,
          'priority': signal == DecisionSignal.three ? 'high' : 'medium',
        },
      ),
    ],
  );
}

StudentLearningState scheduleReviewFromEvidence(
  StudentLearningState state,
  MasteryEvidence evidence, {
  required LessonLayer layer,
  required DecisionSignal signal,
  int? now,
}) {
  if (!evidence.needsReview || evidence.marker.trim().isEmpty) return state;
  final ts = now ?? DateTime.now().millisecondsSinceEpoch;
  final aux = ensureAuxRooms(state);
  final pending = pendingMapOf(aux);
  final layerValue = layer.value;
  final existingIndex = pending.indexWhere(
    (entry) =>
        entry['marker'] == evidence.marker &&
        entry['status'] == 'pending' &&
        entry['layer'] == layerValue,
  );
  final priority =
      signal == DecisionSignal.three ||
          evidence.status == MasteryStatus.falseMastery ||
          evidence.needsReinforcement
      ? 'high'
      : 'medium';
  final entry = {
    'marker': evidence.marker,
    'itemIdx': null,
    'layer': layerValue,
    'signal': signal.value,
    'reason': evidence.reason,
    'origin': 'mastery_evidence',
    'lessonLocalId': state.lessonLocalId,
    'firstRegisteredAt': existingIndex >= 0
        ? pending[existingIndex]['firstRegisteredAt']
        : ts,
    'lastUpdatedAt': ts,
    'clearedAt': null,
    'status': 'pending',
    'priority': priority,
    'masteryStatus': evidence.status.name,
  };
  if (existingIndex >= 0) {
    pending[existingIndex] = entry;
  } else {
    pending.add(entry);
  }
  aux['pendingMap'] = pending;
  return state.copyWith(
    auxRooms: aux,
    events: [
      ...state.events,
      StudentLearningEvent(
        type: 'REVIEW_SCHEDULED',
        ts: ts,
        payload: {
          'marker': evidence.marker,
          'layer': layerValue,
          'signal': signal.value,
          'reason': evidence.reason,
          'masteryStatus': evidence.status.name,
          'priority': priority,
        },
      ),
    ],
  );
}

StudentLearningState clearPendingIfSignalOne(
  StudentLearningState state,
  String marker,
  LessonLayer? layer,
) {
  final aux = ensureAuxRooms(state);
  final pending = pendingMapOf(aux);
  final now = DateTime.now().millisecondsSinceEpoch;
  var cleared = false;
  final updated = pending.map((entry) {
    final sameMarker = entry['marker'] == marker;
    final sameLayer = layer == null || entry['layer'] == layer.value;
    if (sameMarker && sameLayer && entry['status'] == 'pending') {
      cleared = true;
      return {
        ...entry,
        'status': 'cleared',
        'clearedAt': now,
        'lastUpdatedAt': now,
      };
    }
    return entry;
  }).toList();
  if (!cleared) return state;
  aux['pendingMap'] = updated;
  return state.copyWith(
    auxRooms: aux,
    events: [
      ...state.events,
      StudentLearningEvent(
        type: 'RECOVERY_PENDING_CLEARED',
        ts: now,
        payload: {'marker': marker, 'layer': layer?.value},
      ),
    ],
  );
}

StudentLearningState resolvePendingFromRecoveryAnswer(
  StudentLearningState state, {
  required String marker,
  required LessonLayer layer,
  required DecisionSignal signal,
  required bool correct,
  required int ts,
}) {
  final aux = ensureAuxRooms(state);
  final pending = pendingMapOf(aux);
  var changed = false;
  final layerValue = layer.value;

  if (correct && signal != DecisionSignal.three) {
    final updated = pending.map((entry) {
      final sameMarker = entry['marker'] == marker;
      final sameLayer = entry['layer'] == null || entry['layer'] == layerValue;
      if (sameMarker && sameLayer && entry['status'] == 'pending') {
        changed = true;
        return {
          ...entry,
          'status': 'cleared',
          'clearedAt': ts,
          'lastUpdatedAt': ts,
          'clearedBy': 'recovery_answer',
        };
      }
      return entry;
    }).toList();
    if (!changed) return state;
    aux['pendingMap'] = updated;
    return state.copyWith(
      auxRooms: aux,
      events: [
        ...state.events,
        StudentLearningEvent(
          type: 'RECOVERY_PENDING_CLEARED',
          ts: ts,
          payload: {
            'marker': marker,
            'layer': layerValue,
            'signal': signal.value,
            'reason': 'minimum_repair_sufficient',
          },
        ),
      ],
    );
  }

  final existingIndex = pending.indexWhere(
    (entry) =>
        entry['marker'] == marker &&
        entry['status'] == 'pending' &&
        (entry['layer'] == null || entry['layer'] == layerValue),
  );
  final entry = {
    'marker': marker,
    'itemIdx': existingIndex >= 0 ? pending[existingIndex]['itemIdx'] : null,
    'layer': layerValue,
    'signal': DecisionSignal.three.value,
    'reason': correct ? 'low_confidence_heavy' : 'recovery_failed',
    'priority': 'high',
    'origin': 'recovery_answer',
    'lessonLocalId': state.lessonLocalId,
    'firstRegisteredAt': existingIndex >= 0
        ? pending[existingIndex]['firstRegisteredAt']
        : ts,
    'lastUpdatedAt': ts,
    'clearedAt': null,
    'status': 'pending',
  };
  if (existingIndex >= 0) {
    pending[existingIndex] = entry;
  } else {
    pending.add(entry);
  }
  aux['pendingMap'] = pending;
  return state.copyWith(
    auxRooms: aux,
    events: [
      ...state.events,
      StudentLearningEvent(
        type: 'PENDING_REGISTERED',
        ts: ts,
        payload: {
          'marker': marker,
          'layer': layerValue,
          'signal': DecisionSignal.three.value,
          'reason': entry['reason'],
          'priority': 'high',
          'origin': 'recovery_answer',
        },
      ),
    ],
  );
}

List<String> buildReviewQueue(StudentLearningState state, int requestedCount) {
  final aux = ensureAuxRooms(state);
  final count = requestedCount.clamp(0, 10);
  if (count == 0) return const [];
  final pendingMarkers =
      pendingMapOf(aux).where((entry) => entry['status'] == 'pending').toList()
        ..sort(
          (a, b) => ((a['firstRegisteredAt'] as num?)?.toInt() ?? 0).compareTo(
            (b['firstRegisteredAt'] as num?)?.toInt() ?? 0,
          ),
        );
  final queue = <String>[];
  for (final pending in pendingMarkers) {
    final marker = (pending['marker'] ?? '').toString();
    if (marker.isNotEmpty && !queue.contains(marker)) queue.add(marker);
    if (queue.length >= count) break;
  }
  final review = JsonMap.of(aux['review'] as JsonMap);
  if (queue.isEmpty) {
    final items = state.curriculum?.items ?? const <CurriculumItem>[];
    var cursor = (review['sequentialCursor'] as num?)?.toInt() ?? 0;
    var safety = items.length + 1;
    while (queue.length < count && items.isNotEmpty && safety-- > 0) {
      final marker = items[cursor % items.length].marker;
      if (!queue.contains(marker)) queue.add(marker);
      cursor += 1;
    }
  }
  review
    ..['currentQueue'] = queue
    ..['currentIndex'] = 0
    ..['requestedCount'] = count
    ..['sourceLessonLocalId'] = state.lessonLocalId
    ..['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
  aux['review'] = review;
  return queue;
}

List<String> buildRecoveryQueue(StudentLearningState state) {
  final aux = ensureAuxRooms(state);
  final pending =
      pendingMapOf(aux)
          .where(isStrongRecoveryPending)
          .map((entry) => JsonMap.from(entry))
          .toList()
        ..sort((a, b) {
          final ap = (a['priority'] ?? '').toString() == 'high' ? 0 : 1;
          final bp = (b['priority'] ?? '').toString() == 'high' ? 0 : 1;
          if (ap != bp) return ap.compareTo(bp);
          return ((a['firstRegisteredAt'] as num?)?.toInt() ?? 0).compareTo(
            (b['firstRegisteredAt'] as num?)?.toInt() ?? 0,
          );
        });
  final queue = <String>[];
  for (final entry in pending) {
    final marker = (entry['marker'] ?? '').toString();
    if (marker.isNotEmpty && !queue.contains(marker)) queue.add(marker);
  }
  final currentItems = pending.map((entry) {
    return {
      'marker': (entry['marker'] ?? '').toString(),
      'itemIdx': entry['itemIdx'],
      'layer': entry['layer'],
      'reason': (entry['reason'] ?? '').toString(),
      'priority': (entry['priority'] ?? 'medium').toString(),
      'origin': (entry['origin'] ?? 'pending_map').toString(),
      'event': 'RECOVERY_REQUIRED',
      'timestamp': entry['lastUpdatedAt'] ?? entry['firstRegisteredAt'],
      'lessonLocalId': entry['lessonLocalId'] ?? state.lessonLocalId,
      'signal': entry['signal'],
    };
  }).toList();
  final recovery = JsonMap.of(aux['recovery'] as JsonMap)
    ..['currentQueue'] = queue
    ..['currentItems'] = currentItems
    ..['currentIndex'] = 0
    ..['sourceLessonLocalId'] = state.lessonLocalId
    ..['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
  aux['recovery'] = recovery;
  return queue;
}

bool shouldBlockFinalCompletionForRecovery(
  StudentLearningState state, {
  bool auxRoomsEnabled = true,
  bool recoveryRoomEnabled = true,
}) {
  final hasPending = pendingMapOf(
    ensureAuxRooms(state),
  ).any(isStrongRecoveryPending);
  if (!auxRoomsEnabled && !recoveryRoomEnabled) return false;
  return hasPending;
}

StudentLearningState advanceReviewCursor(StudentLearningState state) {
  final aux = ensureAuxRooms(state);
  final review = JsonMap.of(aux['review'] as JsonMap);
  final total = state.curriculum?.items.length ?? 1;
  final nextSequential =
      (((review['sequentialCursor'] as num?)?.toInt() ?? 0) + 1) %
      (total == 0 ? 1 : total);
  review
    ..['sequentialCursor'] = nextSequential
    ..['currentIndex'] = ((review['currentIndex'] as num?)?.toInt() ?? 0) + 1
    ..['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
  aux['review'] = review;
  return state.copyWith(auxRooms: aux);
}
