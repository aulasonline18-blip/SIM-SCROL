import 'dart:async';

import '../external_ai/sim_ai_server_config.dart';
import '../lesson/dopamine_ready_window_engine.dart';
import '../state/student_learning_state.dart';
import 'classroom_models.dart';

class ServerAdvanceGateRequest {
  const ServerAdvanceGateRequest({
    required this.lessonLocalId,
    required this.userId,
    required this.marker,
    required this.itemIdx,
    required this.layer,
    required this.selectedOption,
    required this.signal,
    required this.correct,
    required this.idempotencyKey,
    this.questionId,
    this.questionText,
    this.correctOption,
    this.currentState,
    this.attempts = const [],
    this.history = const [],
    this.highWaterMark,
    this.pending = const {},
  });

  final String lessonLocalId;
  final String? userId;
  final String marker;
  final int itemIdx;
  final LessonLayer layer;
  final AnswerLetter selectedOption;
  final DecisionSignal signal;
  final bool correct;
  final String idempotencyKey;
  final String? questionId;
  final String? questionText;
  final AnswerLetter? correctOption;
  final StudentLearningState? currentState;
  final List<LessonAttempt> attempts;
  final List<String> history;
  final int? highWaterMark;
  final JsonMap pending;

  JsonMap toJson() => {
    'schemaVersion': 1,
    'lessonLocalId': lessonLocalId,
    if (userId != null && userId!.trim().isNotEmpty) 'userId': userId,
    'marker': marker,
    'itemIdx': itemIdx,
    'layer': layer.value,
    'selectedOption': selectedOption.name,
    'signal': signal.value,
    'correct': correct,
    if (questionId != null && questionId!.trim().isNotEmpty)
      'questionId': questionId,
    if (questionText != null && questionText!.trim().isNotEmpty)
      'questionText': questionText,
    if (correctOption != null) 'correctOption': correctOption!.name,
    'evidence': {
      if (questionId != null && questionId!.trim().isNotEmpty)
        'questionId': questionId,
      if (questionText != null && questionText!.trim().isNotEmpty)
        'questionText': questionText,
      if (correctOption != null) 'correctOption': correctOption!.name,
      'selectedOption': selectedOption.name,
      'signal': signal.value,
      'source': 'sim_app_flutter_lesson_material',
    },
    'attempts': attempts.map((attempt) => attempt.toJson()).toList(),
    'history': history,
    if (highWaterMark != null) 'highWaterMark': highWaterMark,
    if (pending.isNotEmpty) 'pending': pending,
    'currentState': currentState?.toJson(),
    'idempotencyKey': idempotencyKey,
    'source': 'sim_app_flutter',
  };
}

class ServerAdvanceGateDecision {
  const ServerAdvanceGateDecision({
    required this.accepted,
    required this.decision,
    required this.reason,
    required this.nextItemIdx,
    required this.nextLayer,
    required this.highWaterMark,
    required this.events,
    this.nextGlobalItemNumber,
    this.nextLocalItemIdx,
    this.nextPartNumber,
    this.authoritativeRootLessonLocalId,
    this.authoritativePartLessonLocalId,
    this.authoritativeLayer,
    this.liveWindow,
    this.partStatus,
    this.nextPartStatus,
    this.conflicts = const [],
    this.recoveryAction,
    this.eventId,
    this.requestId,
    this.duplicate = false,
    this.humanError,
  });

  final bool accepted;
  final String decision;
  final String reason;
  final int nextItemIdx;
  final LessonLayer nextLayer;
  final int highWaterMark;
  final List<JsonMap> events;
  final int? nextGlobalItemNumber;
  final int? nextLocalItemIdx;
  final int? nextPartNumber;
  final String? authoritativeRootLessonLocalId;
  final String? authoritativePartLessonLocalId;
  final LessonLayer? authoritativeLayer;
  final JsonMap? liveWindow;
  final String? partStatus;
  final String? nextPartStatus;
  final List<JsonMap> conflicts;
  final JsonMap? recoveryAction;
  final String? eventId;
  final String? requestId;
  final bool duplicate;
  final JsonMap? humanError;

  bool get movesPosition =>
      decision == 'next_layer' ||
      decision == 'next_item' ||
      decision == 'complete';

  factory ServerAdvanceGateDecision.fromJson(JsonMap json) {
    final next = json['next'] is Map ? JsonMap.from(json['next'] as Map) : {};
    return ServerAdvanceGateDecision(
      accepted: json['accepted'] == true,
      decision: (json['decision'] ?? 'block').toString(),
      reason: (json['reason'] ?? '').toString(),
      nextItemIdx: (next['itemIdx'] as num?)?.toInt() ?? 0,
      nextLayer: LessonLayerValue.fromValue(next['layer']),
      highWaterMark: (json['highWaterMark'] as num?)?.toInt() ?? 0,
      nextGlobalItemNumber:
          (next['globalItemNumber'] as num?)?.toInt() ??
          (json['authoritativeGlobalItemNumber'] as num?)?.toInt(),
      nextLocalItemIdx:
          (next['localItemIdx'] as num?)?.toInt() ??
          (json['authoritativeLocalItemIdx'] as num?)?.toInt(),
      nextPartNumber: (next['partNumber'] as num?)?.toInt(),
      authoritativeRootLessonLocalId:
          (json['authoritativeRootLessonLocalId'] ?? next['rootLessonLocalId'])
              ?.toString(),
      authoritativePartLessonLocalId:
          (json['authoritativePartLessonLocalId'] ?? next['partLessonLocalId'])
              ?.toString(),
      authoritativeLayer: json['authoritativeLayer'] == null
          ? null
          : LessonLayerValue.fromValue(json['authoritativeLayer']),
      liveWindow: json['liveWindow'] is Map
          ? JsonMap.from(json['liveWindow'] as Map)
          : null,
      partStatus: json['partStatus']?.toString(),
      nextPartStatus: json['nextPartStatus']?.toString(),
      conflicts: (json['conflicts'] as List? ?? const [])
          .whereType<Map>()
          .map((conflict) => JsonMap.from(conflict))
          .toList(),
      recoveryAction: json['recoveryAction'] is Map
          ? JsonMap.from(json['recoveryAction'] as Map)
          : null,
      eventId: json['eventId']?.toString(),
      requestId: json['requestId']?.toString(),
      events: (json['events'] as List? ?? const [])
          .whereType<Map>()
          .map((event) => JsonMap.from(event))
          .toList(),
      duplicate: json['duplicate'] == true,
      humanError: json['humanError'] is Map
          ? JsonMap.from(json['humanError'] as Map)
          : null,
    );
  }
}

abstract interface class ServerAdvanceGateClient {
  Future<ServerAdvanceGateDecision> decide(ServerAdvanceGateRequest request);
}

StudentLearningState applyServerAdvanceGateDecision({
  required StudentLearningState state,
  required ServerAdvanceGateRequest request,
  required ServerAdvanceGateDecision decision,
  int? now,
}) {
  final curriculum = state.curriculum;
  final progress = state.progress;
  if (curriculum == null || progress == null) return state;
  final seenKeys = _seenServerDecisionKeys(state);
  final queuedWithoutConfirmedPending = state.queuedActions
      .where(
        (action) =>
            action['type'] != 'ADVANCE_GATE_PENDING' ||
            action['idempotencyKey'] != request.idempotencyKey,
      )
      .toList(growable: false);
  if (seenKeys.contains(request.idempotencyKey)) {
    if (queuedWithoutConfirmedPending.length == state.queuedActions.length) {
      return state;
    }
    return state.copyWith(queuedActions: queuedWithoutConfirmedPending);
  }
  final ts = now ?? DateTime.now().millisecondsSinceEpoch;
  final attemptTs = _matchingRequestAttemptTs(request) ?? ts;
  final attempt = LessonAttempt(
    marker: request.marker,
    layer: request.layer,
    letra: request.selectedOption,
    sinal: request.signal,
    correct: request.correct,
    ts: attemptTs,
  );
  final nextCurriculum = _reconcileCurriculumFromAuthoritativeDecision(
    curriculum,
    decision,
  );
  final transitionPending = _isMissingAuthoritativeGlobalItem(
    nextCurriculum,
    decision,
  );
  final nextProgress = _progressFromDecision(
    progress,
    nextCurriculum,
    request,
    decision,
  );
  final nextState = state.copyWith(
    updatedAt: ts,
    curriculum: nextCurriculum,
    progress: nextProgress,
    current: LessonCurrent(
      itemIdx: nextProgress.itemIdx,
      marker: nextProgress.itemIdx < nextCurriculum.items.length
          ? nextCurriculum.items[nextProgress.itemIdx].marker
          : null,
      layer: nextProgress.layer,
      amparoLvl: nextProgress.amparoLvl,
    ),
    attempts: _appendAttemptIfMissing(state.attempts, attempt),
    queuedActions: queuedWithoutConfirmedPending,
    events: [
      ...state.events,
      ...decision.events.map(
        (event) => StudentLearningEvent(
          type: (event['type'] ?? 'ADVANCE_GATE_DECIDED').toString(),
          ts: ts,
          payload: event,
        ),
      ),
    ],
    extra: {
      ...state.extra,
      'serverAdvanceGate': {
        ..._serverAdvanceGateMap(state),
        'lastDecision': {
          'decision': decision.decision,
          'reason': decision.reason,
          'highWaterMark': decision.highWaterMark,
          'idempotencyKey': request.idempotencyKey,
          if (decision.nextGlobalItemNumber != null)
            'globalItemNumber': decision.nextGlobalItemNumber,
          if (decision.nextLocalItemIdx != null)
            'localItemIdx': decision.nextLocalItemIdx,
          if (decision.nextPartNumber != null)
            'partNumber': decision.nextPartNumber,
          if (decision.authoritativeRootLessonLocalId != null)
            'rootLessonLocalId': decision.authoritativeRootLessonLocalId,
          if (decision.authoritativePartLessonLocalId != null)
            'partLessonLocalId': decision.authoritativePartLessonLocalId,
          if (decision.authoritativeLayer != null)
            'authoritativeLayer': decision.authoritativeLayer!.value,
          if (decision.partStatus != null) 'partStatus': decision.partStatus,
          if (decision.nextPartStatus != null)
            'nextPartStatus': decision.nextPartStatus,
          if (decision.eventId != null) 'eventId': decision.eventId,
          if (decision.requestId != null) 'requestId': decision.requestId,
        },
        if (decision.liveWindow != null) 'liveWindow': decision.liveWindow,
        if (decision.conflicts.isNotEmpty) 'conflicts': decision.conflicts,
        if (decision.recoveryAction != null)
          'recoveryAction': decision.recoveryAction,
        'idempotencyKeys': [...seenKeys, request.idempotencyKey],
      },
      if (transitionPending)
        'cgPartTransitionPending': {
          'globalItemNumber': decision.nextGlobalItemNumber,
          'localItemIdx': decision.nextLocalItemIdx,
          'partNumber': decision.nextPartNumber,
          'rootLessonLocalId': decision.authoritativeRootLessonLocalId,
          'partLessonLocalId': decision.authoritativePartLessonLocalId,
          'partStatus': decision.partStatus,
          'nextPartStatus': decision.nextPartStatus,
        },
    },
  );
  return nextState;
}

List<LessonAttempt> _appendAttemptIfMissing(
  List<LessonAttempt> attempts,
  LessonAttempt attempt,
) {
  final alreadyRecorded = attempts.any(
    (existing) =>
        existing.marker == attempt.marker &&
        existing.layer == attempt.layer &&
        existing.letra == attempt.letra &&
        existing.sinal == attempt.sinal &&
        existing.correct == attempt.correct &&
        existing.ts == attempt.ts,
  );
  if (alreadyRecorded) return attempts;
  return [...attempts, attempt];
}

int? _matchingRequestAttemptTs(ServerAdvanceGateRequest request) {
  for (final attempt in request.attempts.reversed) {
    if (attempt.marker == request.marker &&
        attempt.layer == request.layer &&
        attempt.letra == request.selectedOption &&
        attempt.sinal == request.signal &&
        attempt.correct == request.correct) {
      return attempt.ts;
    }
  }
  return null;
}

StudentLearningState recordPendingServerAdvanceGate({
  required StudentLearningState state,
  required ServerAdvanceGateRequest request,
  required Object error,
  int? now,
}) {
  final ts = now ?? DateTime.now().millisecondsSinceEpoch;
  final alreadyQueued = state.queuedActions.any(
    (action) =>
        action['type'] == 'ADVANCE_GATE_PENDING' &&
        action['idempotencyKey'] == request.idempotencyKey,
  );
  final alreadyLogged = state.events.any(
    (event) =>
        event.type == 'ADVANCE_GATE_PENDING' &&
        event.payload['idempotencyKey'] == request.idempotencyKey,
  );
  return state.copyWith(
    updatedAt: ts,
    queuedActions: alreadyQueued
        ? state.queuedActions
        : [
            ...state.queuedActions,
            {
              'type': 'ADVANCE_GATE_PENDING',
              'idempotencyKey': request.idempotencyKey,
              'payload': request.toJson(),
              'createdAt': ts,
            },
          ],
    events: alreadyLogged
        ? state.events
        : [
            ...state.events,
            StudentLearningEvent(
              type: 'ADVANCE_GATE_PENDING',
              ts: ts,
              payload: {
                'marker': request.marker,
                'layer': request.layer.value,
                'letra': request.selectedOption.name,
                'sinal': request.signal.value,
                'idempotencyKey': request.idempotencyKey,
                'humanError':
                    'Nao conseguimos confirmar o avanco agora. Sua resposta foi guardada para sincronizar.',
                'technicalCode': error is SimExternalAiException
                    ? error.code
                    : 'ADVANCE_GATE_CLIENT_FAILED',
              },
            ),
          ],
  );
}

LessonProgress _progressFromDecision(
  LessonProgress progress,
  StudentCurriculum curriculum,
  ServerAdvanceGateRequest request,
  ServerAdvanceGateDecision decision,
) {
  if (!decision.movesPosition) {
    final errors = request.correct ? progress.erros : progress.erros + 1;
    return progress.copyWith(erros: errors);
  }
  if (decision.decision == 'complete') {
    final completed = progress.concluidos.contains(request.marker)
        ? progress.concluidos
        : [...progress.concluidos, request.marker];
    return progress.copyWith(
      itemIdx: curriculum.items.length,
      layer: LessonLayer.l1,
      erros: 0,
      concluidos: completed,
      mainAdvances: curriculum.items.length,
      pctAvanco: 100,
    );
  }
  if (decision.decision == 'next_item') {
    final nextIdx = _authoritativeItemIdxForDecision(curriculum, decision);
    final globalPlan = curriculum.globalPlan;
    final completedGlobalItems = _completedGlobalItemsAfterNextItem(
      progress,
      curriculum,
      decision,
    );
    final displayTotal =
        globalPlan?.globalTotalItems ?? curriculum.items.length;
    final completed = progress.concluidos.contains(request.marker)
        ? progress.concluidos
        : [...progress.concluidos, request.marker];
    if (_isMissingAuthoritativeGlobalItem(curriculum, decision)) {
      return progress.copyWith(
        erros: 0,
        concluidos: completed,
        mainAdvances: [
          progress.mainAdvances,
          completedGlobalItems,
        ].reduce((a, b) => a > b ? a : b),
        totalItems: displayTotal,
        pctAvanco: displayTotal == 0
            ? 0
            : ((completedGlobalItems / displayTotal) * 100)
                  .round()
                  .clamp(0, 100)
                  .toInt(),
      );
    }
    return progress.copyWith(
      itemIdx: nextIdx,
      layer: decision.nextLayer,
      erros: 0,
      concluidos: completed,
      mainAdvances: [
        progress.mainAdvances + 1,
        completedGlobalItems,
      ].reduce((a, b) => a > b ? a : b),
      totalItems: displayTotal,
      pctAvanco: displayTotal == 0
          ? 0
          : ((completedGlobalItems / displayTotal) * 100)
                .round()
                .clamp(0, 100)
                .toInt(),
    );
  }
  return progress.copyWith(layer: decision.nextLayer, erros: 0);
}

bool hasPendingCgPartTransition(StudentLearningState state) =>
    state.extra['cgPartTransitionPending'] is Map;

int _completedGlobalItemsAfterNextItem(
  LessonProgress progress,
  StudentCurriculum curriculum,
  ServerAdvanceGateDecision decision,
) {
  final globalPlan = curriculum.globalPlan;
  if (globalPlan == null || decision.nextGlobalItemNumber == null) {
    return decision.nextItemIdx.clamp(0, curriculum.items.length).toInt();
  }
  final completedBeforeNext = decision.nextGlobalItemNumber! - 1;
  return completedBeforeNext.clamp(0, globalPlan.globalTotalItems).toInt();
}

StudentCurriculum _reconcileCurriculumFromAuthoritativeDecision(
  StudentCurriculum curriculum,
  ServerAdvanceGateDecision decision,
) {
  final slots = _liveWindowSlots(decision.liveWindow);
  if (slots.isEmpty) return curriculum;

  final byGlobal = <int, CurriculumItem>{};
  for (var index = 0; index < curriculum.items.length; index += 1) {
    final item = curriculum.items[index];
    byGlobal[_globalItemNumberForExistingItem(curriculum, item, index)] = item;
  }

  var changed = false;
  for (final slot in slots) {
    final itemMap = slot['item'] is Map
        ? JsonMap.from(slot['item'] as Map)
        : null;
    if (itemMap == null) continue;
    final global = _intFrom(
      itemMap['globalItemNumber'] ?? slot['globalItemNumber'],
    );
    if (global == null || global < 1) continue;
    final marker = (itemMap['marker'] ?? slot['marker'] ?? '')
        .toString()
        .trim();
    final text = (itemMap['text'] ?? itemMap['title'] ?? '').toString().trim();
    if (marker.isEmpty || text.isEmpty) continue;
    final incoming = CurriculumItem(
      marker: marker,
      text: text,
      title: itemMap['title']?.toString(),
      unit: itemMap['unit']?.toString(),
      extra: {
        ...itemMap,
        'globalItemNumber': global,
        'localItemIdx': _intFrom(
          itemMap['localItemIdx'] ?? slot['localItemIdx'],
        ),
        'partNumber': _intFrom(itemMap['partNumber'] ?? slot['partNumber']),
        'rootLessonLocalId':
            (itemMap['rootLessonLocalId'] ?? slot['rootLessonLocalId'])
                ?.toString(),
        'partLessonLocalId':
            (itemMap['partLessonLocalId'] ?? slot['partLessonLocalId'])
                ?.toString(),
      }..removeWhere((_, value) => value == null || value == ''),
    );
    final existing = byGlobal[global];
    if (existing == null || existing.text.trim().isEmpty) {
      byGlobal[global] = incoming;
      changed = true;
    }
  }

  if (!changed) return curriculum;
  final mergedItems = byGlobal.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final items = mergedItems.map((entry) => entry.value).toList();
  final maxGlobal = mergedItems.last.key;
  final plan = curriculum.globalPlan;
  final nextPlan = plan == null
      ? null
      : CurriculumGlobalPlan(
          globalTotalItems: plan.globalTotalItems,
          operationalBatchLimit: plan.operationalBatchLimit,
          batchStartItem: plan.batchStartItem,
          batchEndItem: maxGlobal > plan.batchEndItem
              ? maxGlobal
              : plan.batchEndItem,
          partNumber: plan.partNumber,
          partTitle: plan.partTitle,
          unitsCovered: plan.unitsCovered,
          unitsPending: plan.unitsPending,
          nextGlobalItemToRequest: plan.nextGlobalItemToRequest,
          continuationNeeded:
              maxGlobal < plan.globalTotalItems || plan.continuationNeeded,
          continuationInstruction: plan.continuationInstruction,
        );
  return StudentCurriculum(
    topic: curriculum.topic,
    totalItems: items.length,
    generatedAt: curriculum.generatedAt,
    provisional: curriculum.provisional,
    items: items,
    globalPlan: nextPlan,
  );
}

int _authoritativeItemIdxForDecision(
  StudentCurriculum curriculum,
  ServerAdvanceGateDecision decision,
) {
  final global = decision.nextGlobalItemNumber;
  if (global != null) {
    for (var index = 0; index < curriculum.items.length; index += 1) {
      if (_globalItemNumberForExistingItem(
            curriculum,
            curriculum.items[index],
            index,
          ) ==
          global) {
        return index;
      }
    }
  }
  return decision.nextItemIdx.clamp(0, curriculum.items.length).toInt();
}

bool _isMissingAuthoritativeGlobalItem(
  StudentCurriculum curriculum,
  ServerAdvanceGateDecision decision,
) {
  final global = decision.nextGlobalItemNumber;
  final total = curriculum.globalPlan?.globalTotalItems;
  if (global == null || total == null || global > total) return false;
  for (var index = 0; index < curriculum.items.length; index += 1) {
    if (_globalItemNumberForExistingItem(
          curriculum,
          curriculum.items[index],
          index,
        ) ==
        global) {
      return false;
    }
  }
  return true;
}

List<JsonMap> _liveWindowSlots(JsonMap? liveWindow) {
  final slots = liveWindow?['slots'];
  if (slots is! List) return const [];
  return slots.whereType<Map>().map((slot) => JsonMap.from(slot)).toList();
}

int _globalItemNumberForExistingItem(
  StudentCurriculum curriculum,
  CurriculumItem item,
  int index,
) {
  final explicit = _intFrom(
    item.extra['globalItemNumber'] ??
        item.extra['global_item_number'] ??
        item.extra['global_item_index'],
  );
  if (explicit != null && explicit > 0) return explicit;
  return curriculum.globalPlan?.globalItemNumberForLocalIndex(index) ??
      (index + 1);
}

int? _intFrom(Object? value) {
  if (value is num) return value.toInt();
  final match = RegExp(r'\d+').firstMatch(value?.toString() ?? '');
  return match == null ? null : int.tryParse(match.group(0)!);
}

JsonMap _serverAdvanceGateMap(StudentLearningState state) {
  final value = state.extra['serverAdvanceGate'];
  return value is Map ? JsonMap.from(value) : {};
}

List<String> _seenServerDecisionKeys(StudentLearningState state) {
  final server = _serverAdvanceGateMap(state);
  return (server['idempotencyKeys'] as List? ?? const [])
      .map((value) => value.toString())
      .where((value) => value.trim().isNotEmpty)
      .toList();
}

List<DopamineWindowItem> dopamineItemsFromCurriculum(
  List<PlannedItem> baseItems,
) {
  return baseItems
      .map((item) => DopamineWindowItem(text: item.text, marker: item.marker))
      .toList();
}
