import 'dart:async';
import 'dart:convert';

import '../external_ai/sim_ai_server_config.dart';
import '../external_ai/sim_http_transport.dart';
import '../lesson/dopamine_ready_window_engine.dart';
import '../state/student_learning_state.dart';
import 'classroom_models.dart';

const String simAdvanceGateAnswerPath = '/api/advance-gate/answer';

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

class SimServerAdvanceGateClient implements ServerAdvanceGateClient {
  SimServerAdvanceGateClient({
    required this.config,
    SimHttpTransport? transport,
    this.timeout = const Duration(seconds: 20),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final Duration timeout;

  @override
  Future<ServerAdvanceGateDecision> decide(
    ServerAdvanceGateRequest request,
  ) async {
    final response = await transport.postJson(
      config.uri(simAdvanceGateAnswerPath),
      headers: await config.jsonHeaders(),
      body: request.toJson(),
      timeout: timeout,
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const SimExternalAiException(
        'advance gate retornou resposta invalida.',
        statusCode: 502,
      );
    }
    final decision = ServerAdvanceGateDecision.fromJson(JsonMap.from(decoded));
    if (!response.ok || !decision.accepted) {
      final human = decision.humanError;
      throw SimExternalAiException(
        (human?['message'] ?? 'Nao conseguimos decidir o avanco agora.')
            .toString(),
        statusCode: response.statusCode,
        code: (decoded['reason'] ?? human?['technical']?['code'])?.toString(),
      );
    }
    return decision;
  }
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
  if (seenKeys.contains(request.idempotencyKey)) return state;
  final ts = now ?? DateTime.now().millisecondsSinceEpoch;
  final attempt = LessonAttempt(
    marker: request.marker,
    layer: request.layer,
    letra: request.selectedOption,
    sinal: request.signal,
    correct: request.correct,
    ts: ts,
  );
  final nextProgress = _progressFromDecision(
    progress,
    curriculum,
    request,
    decision,
  );
  final nextState = state.copyWith(
    updatedAt: ts,
    progress: nextProgress,
    current: LessonCurrent(
      itemIdx: nextProgress.itemIdx,
      marker: nextProgress.itemIdx < curriculum.items.length
          ? curriculum.items[nextProgress.itemIdx].marker
          : null,
      layer: nextProgress.layer,
      amparoLvl: nextProgress.amparoLvl,
    ),
    attempts: [...state.attempts, attempt],
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
        },
        'idempotencyKeys': [...seenKeys, request.idempotencyKey],
      },
    },
  );
  return nextState;
}

StudentLearningState recordPendingServerAdvanceGate({
  required StudentLearningState state,
  required ServerAdvanceGateRequest request,
  required Object error,
  int? now,
}) {
  final ts = now ?? DateTime.now().millisecondsSinceEpoch;
  final alreadyRecorded = state.attempts.any(
    (attempt) => attempt.marker == request.marker && attempt.layer == request.layer,
  );
  final attempt = LessonAttempt(
    marker: request.marker,
    layer: request.layer,
    letra: request.selectedOption,
    sinal: request.signal,
    correct: request.correct,
    ts: ts,
  );
  return state.copyWith(
    updatedAt: ts,
    attempts: alreadyRecorded ? state.attempts : [...state.attempts, attempt],
    queuedActions: [
      ...state.queuedActions,
      {
        'type': 'ADVANCE_GATE_PENDING',
        'idempotencyKey': request.idempotencyKey,
        'payload': request.toJson(),
        'createdAt': ts,
      },
    ],
    events: [
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
    final nextIdx = decision.nextItemIdx
        .clamp(0, curriculum.items.length)
        .toInt();
    final completed = progress.concluidos.contains(request.marker)
        ? progress.concluidos
        : [...progress.concluidos, request.marker];
    return progress.copyWith(
      itemIdx: nextIdx,
      layer: decision.nextLayer,
      erros: 0,
      concluidos: completed,
      mainAdvances: [
        progress.mainAdvances + 1,
        nextIdx,
      ].reduce((a, b) => a > b ? a : b),
      pctAvanco: curriculum.items.isEmpty
          ? 0
          : ((nextIdx / curriculum.items.length) * 100).round(),
    );
  }
  return progress.copyWith(layer: decision.nextLayer, erros: 0);
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
