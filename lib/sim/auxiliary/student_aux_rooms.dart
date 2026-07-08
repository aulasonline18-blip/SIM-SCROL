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

JsonMap createEmptyAuxRooms() => {
  'review': createEmptyReviewRoom(),
  'recovery': createEmptyRecoveryRoom(),
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
  existing['pendingMap'] = (existing['pendingMap'] as List? ?? const [])
      .whereType<Map>()
      .map((entry) => JsonMap.from(entry))
      .toList();
  return existing;
}

List<JsonMap> pendingMapOf(JsonMap auxRooms) =>
    (auxRooms['pendingMap'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => JsonMap.from(entry))
        .toList();

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
          evidence.status == MasteryStatus.reviewNeeded
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
          .where((entry) => entry['status'] == 'pending')
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
  final queue = pending
      .map((entry) => (entry['marker'] ?? '').toString())
      .where((marker) => marker.isNotEmpty)
      .toList();
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
  ).any((entry) => entry['status'] == 'pending');
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
