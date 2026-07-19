import '../lesson/lesson_models.dart';
import '../state/student_learning_state.dart';
import 'amparo_room_engine.dart' as amparo_engine;
import 'aux_room_models.dart';
import 'aux_room_t02_caller.dart';
import 'student_aux_rooms.dart' as aux_state;

class PreparedAuxRoomQuestion {
  const PreparedAuxRoomQuestion.ok(this.conteudo) : ok = true, error = null;

  const PreparedAuxRoomQuestion.failed(this.error)
    : ok = false,
      conteudo = null;

  final bool ok;
  final AuxRoomContent? conteudo;
  final String? error;
}

class StudentAuxRoomService {
  StudentAuxRoomService({
    required this.readState,
    required this.writeState,
    required this.t02Caller,
    this.auxRoomsEnabled = true,
    this.recoveryRoomEnabled = true,
  });

  final StudentLearningState Function(String lessonLocalId) readState;
  final StudentLearningState Function(StudentLearningState state) writeState;
  final AuxRoomT02Caller t02Caller;
  final bool auxRoomsEnabled;
  final bool recoveryRoomEnabled;

  List<AuxRoomItem> normalizeItems(List<AuxRoomItem> items) {
    return items
        .map(
          (item) => AuxRoomItem(
            marker: (item.marker ?? '').trim(),
            text: (item.text ?? '').trim(),
            itemIdx: item.itemIdx,
          ),
        )
        .where((item) => item.marker!.isNotEmpty && item.text!.isNotEmpty)
        .toList(growable: false);
  }

  AuxRoomItem? pickAuxRoomItem(String marker, List<AuxRoomItem> items) {
    for (final item in normalizeItems(items)) {
      if (item.marker == marker) return item;
    }
    return null;
  }

  List<String> buildReviewQueueForLesson({
    required String lessonLocalId,
    required String topic,
    required List<AuxRoomItem> items,
    required int count,
    required int fallbackStartIdx,
  }) {
    var state = readState(lessonLocalId);
    final normalized = normalizeItems(items);
    if (state.curriculum == null) {
      state = state.copyWith(
        curriculum: StudentCurriculum(
          topic: topic,
          totalItems: normalized.length,
          generatedAt: DateTime.now().millisecondsSinceEpoch,
          provisional: false,
          items: normalized
              .map(
                (item) =>
                    CurriculumItem(marker: item.marker!, text: item.text!),
              )
              .toList(growable: false),
        ),
      );
    }
    var queue = aux_state.buildReviewQueue(state, count);
    final now = DateTime.now().millisecondsSinceEpoch;
    final aux = aux_state.ensureAuxRooms(state);
    final review = JsonMap.of(aux['review'] as JsonMap)
      ..['currentQueue'] = queue
      ..['currentIndex'] = 0
      ..['requestedCount'] = count.clamp(0, 10)
      ..['sourceLessonLocalId'] = lessonLocalId
      ..['updatedAt'] = now;
    aux['review'] = review;
    state = state.copyWith(
      auxRooms: aux,
      events: [
        ...state.events,
        StudentLearningEvent(
          type: 'REVIEW_QUEUE_PREPARED',
          ts: now,
          payload: {'requestedCount': count, 'queueLength': queue.length},
        ),
      ],
    );
    writeState(state);
    if (queue.isNotEmpty) return queue.take(count).toList(growable: false);
    if (normalized.isEmpty) return const [];
    final start = fallbackStartIdx.clamp(0, normalized.length - 1);
    final fallback = <String>[];
    for (var i = start; i < normalized.length && fallback.length < count; i++) {
      fallback.add(normalized[i].marker!);
    }
    for (var i = 0; i < start && fallback.length < count; i++) {
      fallback.add(normalized[i].marker!);
    }
    return fallback;
  }

  ({List<String> queue, Map<String, DecisionSignal> signalByMarker})
  buildRecoveryQueueForLesson({
    required String lessonLocalId,
    required String topic,
    required List<AuxRoomItem> items,
  }) {
    var state = readState(lessonLocalId);
    final normalized = normalizeItems(items);
    if (state.curriculum == null) {
      state = state.copyWith(
        curriculum: StudentCurriculum(
          topic: topic,
          totalItems: normalized.length,
          generatedAt: DateTime.now().millisecondsSinceEpoch,
          provisional: false,
          items: normalized
              .map(
                (item) =>
                    CurriculumItem(marker: item.marker!, text: item.text!),
              )
              .toList(growable: false),
        ),
      );
    }
    var aux = aux_state.ensureAuxRooms(state);
    final pendingItems = aux_state.pendingMapOf(aux)
      ..retainWhere(aux_state.isStrongRecoveryPending)
      ..sort((a, b) {
        final ap = (a['priority'] ?? '').toString() == 'high' ? 0 : 1;
        final bp = (b['priority'] ?? '').toString() == 'high' ? 0 : 1;
        if (ap != bp) return ap.compareTo(bp);
        return ((a['firstRegisteredAt'] as num?)?.toInt() ?? 0).compareTo(
          (b['firstRegisteredAt'] as num?)?.toInt() ?? 0,
        );
      });
    final queue = <String>[];
    for (final entry in pendingItems) {
      final marker = (entry['marker'] ?? '').toString();
      if (marker.isNotEmpty && !queue.contains(marker)) queue.add(marker);
    }
    final signalByMarker = <String, DecisionSignal>{};
    for (final entry in pendingItems) {
      signalByMarker[(entry['marker'] ?? '').toString()] =
          DecisionSignalValue.fromValue(entry['signal']);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final existingRecovery = JsonMap.of(aux['recovery'] as JsonMap);
    final recovery = existingRecovery
      ..['currentQueue'] = queue
      ..['currentItems'] = [
        for (final entry in pendingItems)
          {
            'marker': (entry['marker'] ?? '').toString(),
            'itemIdx': entry['itemIdx'],
            'layer': entry['layer'],
            'reason': (entry['reason'] ?? '').toString(),
            'priority': (entry['priority'] ?? 'medium').toString(),
            'origin': (entry['origin'] ?? 'pending_map').toString(),
            'event': 'RECOVERY_REQUIRED',
            'timestamp': entry['lastUpdatedAt'] ?? entry['firstRegisteredAt'],
            'lessonLocalId': entry['lessonLocalId'] ?? lessonLocalId,
            'signal': entry['signal'],
          },
      ]
      ..['currentIndex'] = 0
      ..['sourceLessonLocalId'] = lessonLocalId
      ..['updatedAt'] = now;
    aux = JsonMap.of(aux)..['recovery'] = recovery;
    writeState(
      state.copyWith(
        auxRooms: aux,
        events: [
          ...state.events,
          StudentLearningEvent(
            type: 'RECOVERY_QUEUE_PREPARED',
            ts: now,
            payload: {'queueLength': queue.length},
          ),
        ],
      ),
    );
    return (queue: queue, signalByMarker: signalByMarker);
  }

  Future<PreparedAuxRoomQuestion> prepareAuxRoomQuestion({
    required String lessonLocalId,
    required AuxRoomMode mode,
    required AuxRoomProfile profile,
    required List<AuxRoomItem> items,
    required String? marker,
    required DecisionSignal signal,
  }) async {
    final picked = marker == null ? null : pickAuxRoomItem(marker, items);
    if (picked == null) {
      return const PreparedAuxRoomQuestion.failed('no item for marker');
    }
    LessonContent? content;
    try {
      final result = await t02Caller.call(
        lessonLocalId: lessonLocalId,
        mode: mode,
        profile: profile,
        marker: picked.marker!,
        item: picked.text!,
        signal: signal,
        itemIdx: picked.itemIdx,
        confirmEnabled: true,
      );
      if (!result.aborted) {
        content = result.conteudo;
      }
    } catch (_) {
      return PreparedAuxRoomQuestion.failed(
        mode == AuxRoomMode.review
            ? 'Nao consegui preparar a revisao agora. Sua aula foi preservada.'
            : 'Nao consegui preparar a recuperacao agora. Sua aula foi preservada.',
      );
    }
    if (content == null) {
      return const PreparedAuxRoomQuestion.failed('invalid aux room material');
    }
    if (content.options[AnswerLetter.A]?.isEmpty != false ||
        content.options[AnswerLetter.B]?.isEmpty != false ||
        content.options[AnswerLetter.C]?.isEmpty != false) {
      return const PreparedAuxRoomQuestion.failed('invalid aux room material');
    }
    final eventType = mode == AuxRoomMode.review
        ? 'REVIEW_QUESTION_SHOWN'
        : mode == AuxRoomMode.recovery
        ? 'RECOVERY_QUESTION_SHOWN'
        : 'AMPARO_STEP_SHOWN';
    final state = readState(lessonLocalId);
    writeState(
      state.copyWith(
        events: [
          ...state.events,
          StudentLearningEvent(
            type: eventType,
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: {'marker': picked.marker, 'signal': signal.value},
          ),
        ],
      ),
    );
    return PreparedAuxRoomQuestion.ok(AuxRoomContent.fromLesson(content));
  }

  Future<PreparedAuxRoomQuestion> prepareAmparoRoomStep({
    required AmparoRoomContext context,
    required AmparoStation station,
    required int amparoLevel,
  }) async {
    final picked = pickAuxRoomItem(context.marker ?? '', context.items);
    if (picked == null) {
      return const PreparedAuxRoomQuestion.failed('no item for amparo');
    }
    final state = readState(context.lessonLocalId);
    final amparo = aux_state.ensureAuxRooms(state)['amparo'] as Map;
    final recentAggravants =
        (amparo['triggeredAggravants'] as List? ??
                amparo['recentAggravants'] as List? ??
                const [])
            .whereType<Map>()
            .map((entry) => JsonMap.from(entry))
            .toList();
    try {
      final result = await t02Caller.call(
        lessonLocalId: context.lessonLocalId,
        mode: AuxRoomMode.amparo,
        profile: context.profile,
        marker: picked.marker!,
        item: picked.text!,
        signal: context.signal ?? DecisionSignal.three,
        itemIdx: picked.itemIdx,
        layer: station.layer,
        amparoLevel: amparoLevel,
        auxContext: {
          'amparo_step_index':
              amparo_engine.AmparoPlanEngine.stations.indexOf(station) + 1,
          'amparo_step_marker': station.marker,
          'amparo_type': station.amparoType,
          'amparo_purpose': station.purpose,
          'blockage_point': _blockagePoint(context, recentAggravants),
          'recent_aggravants': recentAggravants,
          'current_item': picked.text,
          'current_marker': picked.marker,
          'current_question': context.currentQuestion,
          'current_options': _optionsPayload(context.currentOptions),
          'student_selected_answer': context.selectedAnswer?.name,
          'correct_answer': context.correctAnswer?.name,
          'signal': context.signal?.value,
        },
        confirmEnabled: true,
      );
      final content = result.conteudo;
      if (result.aborted || content == null) {
        return const PreparedAuxRoomQuestion.failed('invalid amparo material');
      }
      if (content.options[AnswerLetter.A]?.isEmpty != false ||
          content.options[AnswerLetter.B]?.isEmpty != false ||
          content.options[AnswerLetter.C]?.isEmpty != false) {
        return const PreparedAuxRoomQuestion.failed('invalid amparo material');
      }
      _appendAuxEvent(context.lessonLocalId, 'AMPARO_STEP_SHOWN', {
        'marker': picked.marker,
        'itemIdx': picked.itemIdx,
        'layer': context.layer.value,
        'amparoLvl': amparoLevel,
        'amparoStepMarker': station.marker,
        'amparoType': station.amparoType,
      });
      return PreparedAuxRoomQuestion.ok(AuxRoomContent.fromLesson(content));
    } catch (_) {
      _appendAuxEvent(context.lessonLocalId, 'AMPARO_FAILED', {
        'marker': context.marker,
        'itemIdx': context.itemIdx,
        'layer': context.layer.value,
        'amparoLvl': amparoLevel,
      });
      return const PreparedAuxRoomQuestion.failed(
        'Nao consegui preparar o amparo agora. Sua aula foi preservada.',
      );
    }
  }

  void recordAuxRoomAnswer({
    required String lessonLocalId,
    required String marker,
    required LessonLayer layer,
    required List<AuxRoomItem> items,
    required AuxRoomContent conteudo,
    required AnswerLetter letra,
    required DecisionSignal sinal,
    required String source,
  }) {
    final state = readState(lessonLocalId);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final correct = letra == conteudo.correctAnswer;
    final aux = aux_state.ensureAuxRooms(state);
    final roomKey = source.startsWith('review')
        ? 'review'
        : source.startsWith('recovery')
        ? 'recovery'
        : source.startsWith('amparo')
        ? 'amparo'
        : 'doubt';
    final room = JsonMap.of(aux[roomKey] as JsonMap);
    final attempts = (room['attempts'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => JsonMap.from(entry))
        .toList();
    attempts.add({
      'marker': marker,
      'layer': layer.value,
      'letra': letra.name,
      'sinal': sinal.value,
      'correct': correct,
      'ts': ts,
      'source': source,
      'authoritative': false,
      'strongEffect': false,
      'writesProgress': false,
      'writesTruth': false,
      'writesMastery': false,
      'requiresServerDecision': false,
      'decisionSource': 'sim_app_local_aux_evidence',
      'auxiliary': true,
    });
    room['attempts'] = attempts;
    aux[roomKey] = room;
    final eventType = source.startsWith('review')
        ? 'REVIEW_ANSWER_RECORDED'
        : source.startsWith('recovery')
        ? 'RECOVERY_ANSWER_RECORDED'
        : source.startsWith('amparo')
        ? 'AMPARO_ANSWER_RECORDED'
        : 'AUX_ROOM_ANSWER_RECORDED';
    var nextState = state.copyWith(
      auxRooms: aux,
      events: [
        ...state.events,
        StudentLearningEvent(
          type: eventType,
          ts: ts,
          payload: {
            'marker': marker,
            'type': source.startsWith('review') ? 'review' : source,
            'slot': source,
            'layer': layer.value,
            'question': conteudo.question,
            'letra': letra.name,
            'sinal': sinal.value,
            'correct': correct,
            'authoritative': false,
            'strongEffect': false,
            'writesProgress': false,
            'writesTruth': false,
            'requiresServerDecision': false,
            'decisionSource': 'sim_app_local_aux_evidence',
            'auxiliary': true,
            'writesMastery': false,
          },
        ),
      ],
    );
    if (source.startsWith('recovery')) {
      nextState = aux_state.resolvePendingFromRecoveryAnswer(
        nextState,
        marker: marker,
        layer: layer,
        signal: sinal,
        correct: correct,
        ts: ts,
      );
    }
    writeState(nextState);
  }

  void completeReviewSession(String lessonLocalId) {
    var state = aux_state.advanceReviewCursor(readState(lessonLocalId));
    final review = aux_state.ensureAuxRooms(state)['review'] as Map?;
    state = state.copyWith(
      events: [
        ...state.events,
        StudentLearningEvent(
          type: 'REVIEW_CURSOR_UPDATED',
          ts: DateTime.now().millisecondsSinceEpoch,
          payload: {
            'sequentialCursor':
                (review?['sequentialCursor'] as num?)?.toInt() ?? 0,
            'currentIndex': (review?['currentIndex'] as num?)?.toInt() ?? 0,
          },
        ),
      ],
    );
    writeState(state);
  }

  void registerRecoveryStarted(String lessonLocalId, List<String> queue) {
    final state = readState(lessonLocalId);
    final now = DateTime.now().millisecondsSinceEpoch;
    writeState(
      state.copyWith(
        events: [
          ...state.events,
          StudentLearningEvent(
            type: 'RECOVERY_REQUIRED',
            ts: now,
            payload: {'pendingCount': queue.length},
          ),
          StudentLearningEvent(
            type: 'RECOVERY_STARTED',
            ts: now,
            payload: {'queue': queue},
          ),
          StudentLearningEvent(
            type: 'FINAL_COMPLETION_BLOCKED_BY_PENDING',
            ts: now,
            payload: {'pendingCount': queue.length},
          ),
        ],
      ),
    );
  }

  void registerAmparoStarted(
    String lessonLocalId,
    List<AmparoStation> stations,
    int amparoLevel,
  ) {
    final state = readState(lessonLocalId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final aux = aux_state.ensureAuxRooms(state);
    final amparo = JsonMap.of(aux['amparo'] as JsonMap)
      ..['active'] = true
      ..['pending'] = false
      ..['currentQueue'] = [for (final station in stations) station.marker]
      ..['currentIndex'] = 0
      ..['amparoLvl'] = amparoLevel
      ..['startedAt'] = now
      ..['updatedAt'] = now;
    aux['amparo'] = amparo;
    writeState(
      state.copyWith(
        auxRooms: aux,
        events: [
          ...state.events,
          StudentLearningEvent(
            type: 'AMPARO_STARTED',
            ts: now,
            payload: {
              'amparoLvl': amparoLevel,
              'queue': [for (final station in stations) station.marker],
              ..._auxFlags(),
            },
          ),
        ],
      ),
    );
  }

  bool shouldLessonBlockFinalCompletion(String lessonLocalId) {
    return aux_state.shouldBlockFinalCompletionForRecovery(
      readState(lessonLocalId),
      auxRoomsEnabled: auxRoomsEnabled,
      recoveryRoomEnabled: recoveryRoomEnabled,
    );
  }

  void registerFinalCompletionAllowed(String lessonLocalId) {
    final state = readState(lessonLocalId);
    writeState(
      state.copyWith(
        events: [
          ...state.events,
          StudentLearningEvent(
            type: 'FINAL_COMPLETION_ALLOWED',
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: const {},
          ),
        ],
      ),
    );
  }

  void registerRecoveryCompleted(String lessonLocalId) {
    final state = readState(lessonLocalId);
    writeState(
      state.copyWith(
        events: [
          ...state.events,
          StudentLearningEvent(
            type: 'RECOVERY_COMPLETED',
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: const {},
          ),
        ],
      ),
    );
  }

  void registerAmparoCompleted(String lessonLocalId) {
    final state = readState(lessonLocalId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final aux = aux_state.ensureAuxRooms(state);
    final amparo = JsonMap.of(aux['amparo'] as JsonMap)
      ..['active'] = false
      ..['pending'] = false
      ..['currentIndex'] = 0
      ..['sequenceCount'] = 0
      ..['sequenceMarker'] = null
      ..['sequenceLayer'] = null
      ..['recentAggravants'] = <JsonMap>[]
      ..['completedAt'] = now
      ..['updatedAt'] = now;
    aux['amparo'] = amparo;
    writeState(
      state.copyWith(
        auxRooms: aux,
        events: [
          ...state.events,
          StudentLearningEvent(
            type: 'AMPARO_COMPLETED',
            ts: now,
            payload: {
              'amparoLvl': (amparo['amparoLvl'] as num?)?.toInt() ?? 0,
              ..._auxFlags(),
            },
          ),
        ],
      ),
    );
  }

  void _appendAuxEvent(String lessonLocalId, String type, JsonMap payload) {
    final state = readState(lessonLocalId);
    writeState(
      state.copyWith(
        events: [
          ...state.events,
          StudentLearningEvent(
            type: type,
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: {...payload, ..._auxFlags()},
          ),
        ],
      ),
    );
  }
}

JsonMap _optionsPayload(Map<AnswerLetter, String> options) => {
  'A': options[AnswerLetter.A] ?? '',
  'B': options[AnswerLetter.B] ?? '',
  'C': options[AnswerLetter.C] ?? '',
};

String _blockagePoint(
  AmparoRoomContext context,
  List<JsonMap> recentAggravants,
) {
  final marker = context.marker ?? 'item';
  final question = context.currentQuestion.trim();
  if (question.isEmpty) return 'Travamento no item $marker.';
  return 'Travamento no item $marker: $question';
}

JsonMap _auxFlags() => const {
  'authoritative': false,
  'writesProgress': false,
  'writesTruth': false,
  'writesMastery': false,
  'requiresServerDecision': false,
  'decisionSource': 'sim_app_local_aux_evidence',
  'auxiliary': true,
};
