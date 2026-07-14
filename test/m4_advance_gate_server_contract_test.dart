import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/classroom/server_advance_gate.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_lesson_executor.dart';

class RecordingTransport implements SimHttpTransport {
  Uri? lastUri;
  Map<String, String>? lastHeaders;
  Object? lastBody;
  int statusCode = 200;
  String body = jsonEncode({
    'accepted': true,
    'decision': 'next_layer',
    'reason': 'secure_correct_next_layer',
    'next': {'itemIdx': 0, 'layer': 2},
    'highWaterMark': 2,
    'events': [
      {
        'type': 'ADVANCE_GATE_DECIDED',
        'marker': 'M1',
        'layer': 1,
        'letra': 'A',
        'sinal': 1,
        'decision': 'next_layer',
        'reason': 'secure_correct_next_layer',
        'before': {'itemIdx': 0, 'layer': 1},
        'after': {'itemIdx': 0, 'layer': 2},
        'timestamp': '2026-07-08T00:00:00.000Z',
        'idempotencyKey': 'idem-1',
      },
    ],
  });

  @override
  Future<SimHttpResponse> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    lastUri = uri;
    lastHeaders = headers;
    lastBody = body;
    return SimHttpResponse(statusCode: statusCode, body: this.body);
  }

  @override
  Stream<String> postEventStream(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 140),
  }) async* {}

  @override
  Future<SimHttpResponse> postMultipart(
    Uri uri, {
    required Map<String, String> headers,
    required String fieldName,
    required String filename,
    required String contentType,
    required List<int> bytes,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    throw UnimplementedError();
  }
}

StudentLearningState _state() {
  const items = [
    CurriculumItem(marker: 'M1', text: 'Item 1'),
    CurriculumItem(marker: 'M2', text: 'Item 2'),
  ];
  return StudentLearningState.empty(
    lessonLocalId: 'lesson-m4',
    userId: 'user-m4',
    now: 1,
  ).copyWith(
    profile: const StudentProfile(objetivo: 'Aprender M4', stableLang: 'pt-BR'),
    curriculum: const StudentCurriculum(
      topic: 'Aprender M4',
      totalItems: 2,
      generatedAt: null,
      provisional: false,
      items: items,
    ),
    current: const LessonCurrent(
      itemIdx: 0,
      marker: 'M1',
      layer: LessonLayer.l1,
      amparoLvl: 0,
    ),
    progress: const LessonProgress(
      itemIdx: 0,
      layer: LessonLayer.l1,
      erros: 0,
      amparoLvl: 0,
      historia: [],
      mainAdvances: 0,
      concluidos: [],
      pendentesMarkers: [],
      totalItems: 2,
      pctAvanco: 0,
    ),
  );
}

ServerAdvanceGateRequest _request(StudentLearningState state) {
  return ServerAdvanceGateRequest(
    lessonLocalId: state.lessonLocalId,
    userId: state.userId,
    marker: 'M1',
    itemIdx: 0,
    layer: LessonLayer.l1,
    selectedOption: AnswerLetter.A,
    signal: DecisionSignal.one,
    correct: true,
    questionId: 'M1:layer-1:Quanto e 1+1?',
    questionText: 'Quanto e 1+1?',
    correctOption: AnswerLetter.A,
    attempts: state.attempts,
    history: const [],
    currentState: state,
    highWaterMark: 1,
    idempotencyKey: 'idem-1',
  );
}

void main() {
  test('App envia resposta+sinal para o contrato do servidor', () async {
    final transport = RecordingTransport();
    final client = SimServerAdvanceGateClient(
      config: SimAiServerConfig(
        baseUrl: 'https://sim.example',
        accessTokenProvider: () async => 'token',
      ),
      transport: transport,
    );

    final decision = await client.decide(_request(_state()));

    expect(
      transport.lastUri.toString(),
      'https://sim.example/api/advance-gate/answer',
    );
    expect(transport.lastHeaders?['authorization'], 'Bearer token');
    final body = transport.lastBody as Map;
    expect(body['lessonLocalId'], 'lesson-m4');
    expect(body['marker'], 'M1');
    expect(body['itemIdx'], 0);
    expect(body['layer'], 1);
    expect(body['selectedOption'], 'A');
    expect(body['signal'], 1);
    expect(body['correct'], isTrue);
    expect(body['questionId'], 'M1:layer-1:Quanto e 1+1?');
    expect(body['questionText'], 'Quanto e 1+1?');
    expect(body['correctOption'], 'A');
    expect(body['evidence'], isA<Map>());
    expect((body['evidence'] as Map)['correctOption'], 'A');
    expect(
      (body['evidence'] as Map)['source'],
      'sim_app_flutter_lesson_material',
    );
    expect(body['idempotencyKey'], 'idem-1');
    expect(decision.decision, 'next_layer');
  });

  test(
    'App obedece rejeicao do servidor e nao fabrica decisao local',
    () async {
      final transport = RecordingTransport()
        ..statusCode = 409
        ..body = jsonEncode({
          'accepted': false,
          'decision': 'block',
          'reason': 'ADVANCE_GATE_INVALID_CONTRACT',
          'humanError': {
            'message': 'Nao conseguimos validar sua resposta agora.',
            'technical': {'code': 'ADVANCE_GATE_INVALID_CONTRACT'},
          },
        });
      final client = SimServerAdvanceGateClient(
        config: SimAiServerConfig(
          baseUrl: 'https://sim.example',
          accessTokenProvider: () async => 'token',
        ),
        transport: transport,
      );

      expect(
        () => client.decide(_request(_state())),
        throwsA(isA<SimExternalAiException>()),
      );
    },
  );

  test('App aplica decisao do servidor sem marcar dominio final sozinho', () {
    final state = _state();
    final request = _request(state);
    const decision = ServerAdvanceGateDecision(
      accepted: true,
      decision: 'next_item',
      reason: 'secure_correct_next_item_without_full_mastery',
      nextItemIdx: 1,
      nextLayer: LessonLayer.l1,
      highWaterMark: 3,
      events: [
        {
          'type': 'ADVANCE_GATE_DECIDED',
          'decision': 'next_item',
          'reason': 'secure_correct_next_item_without_full_mastery',
          'marker': 'M1',
          'layer': 3,
          'letra': 'A',
          'sinal': 1,
        },
      ],
    );

    final next = applyServerAdvanceGateDecision(
      state: state,
      request: request,
      decision: decision,
      now: 2,
    );

    expect(next.progress?.itemIdx, 1);
    expect(next.progress?.concluidos, contains('M1'));
    expect(next.truth.masteryEvidence, isEmpty);
    expect(next.events.last.type, 'ADVANCE_GATE_DECIDED');
  });

  test('App nao conclui curriculo global ao atravessar borda de parte', () {
    final items = List<CurriculumItem>.generate(
      80,
      (index) =>
          CurriculumItem(marker: 'M${index + 1}', text: 'Item ${index + 1}'),
    );
    final state =
        StudentLearningState.empty(
          lessonLocalId: 'lesson-cg',
          userId: 'user-m4',
          now: 1,
        ).copyWith(
          curriculum: StudentCurriculum(
            topic: 'Curriculo grande',
            totalItems: 80,
            generatedAt: null,
            provisional: false,
            items: items,
            globalPlan: const CurriculumGlobalPlan(
              globalTotalItems: 180,
              batchStartItem: 1,
              batchEndItem: 80,
              operationalBatchLimit: 80,
              partNumber: 1,
              nextGlobalItemToRequest: 81,
              continuationNeeded: true,
            ),
          ),
          current: const LessonCurrent(
            itemIdx: 79,
            marker: 'M80',
            layer: LessonLayer.l3,
            amparoLvl: 0,
          ),
          progress: const LessonProgress(
            itemIdx: 79,
            layer: LessonLayer.l3,
            erros: 0,
            amparoLvl: 0,
            historia: [],
            mainAdvances: 79,
            concluidos: [],
            pendentesMarkers: [],
            totalItems: 180,
            pctAvanco: 43,
          ),
        );
    final request = ServerAdvanceGateRequest(
      lessonLocalId: state.lessonLocalId,
      userId: state.userId,
      marker: 'M80',
      itemIdx: 79,
      layer: LessonLayer.l3,
      selectedOption: AnswerLetter.A,
      signal: DecisionSignal.two,
      correct: true,
      questionText: 'Pergunta 80?',
      correctOption: AnswerLetter.A,
      currentState: state,
      idempotencyKey: 'cg-boundary-80-81',
    );
    const decision = ServerAdvanceGateDecision(
      accepted: true,
      decision: 'next_item',
      reason: 'l3_to_next_item',
      nextItemIdx: 80,
      nextLayer: LessonLayer.l1,
      nextGlobalItemNumber: 81,
      nextLocalItemIdx: 0,
      nextPartNumber: 2,
      authoritativeRootLessonLocalId: 'lesson-cg',
      authoritativePartLessonLocalId: 'lesson-cg::part-2',
      authoritativeLayer: LessonLayer.l1,
      partStatus: 'ready',
      nextPartStatus: 'ready',
      liveWindow: {
        'version': 1,
        'policy': 'current_plus_next_three',
        'slots': [
          {
            'itemIdx': 80,
            'layer': 1,
            'rootLessonLocalId': 'lesson-cg',
            'partLessonLocalId': 'lesson-cg::part-2',
            'partNumber': 2,
            'globalItemNumber': 81,
            'localItemIdx': 0,
            'item': {
              'itemIdx': 80,
              'localItemIdx': 0,
              'globalItemNumber': 81,
              'partNumber': 2,
              'rootLessonLocalId': 'lesson-cg',
              'partLessonLocalId': 'lesson-cg::part-2',
              'marker': 'M81',
              'title': 'Item 81',
              'text': 'Item 81',
            },
          },
        ],
      },
      highWaterMark: 80,
      events: [
        {'type': 'ADVANCE_GATE_DECIDED', 'decision': 'next_item'},
      ],
    );

    final next = applyServerAdvanceGateDecision(
      state: state,
      request: request,
      decision: decision,
      now: 2,
    );

    expect(next.progress?.mainAdvances, 80);
    expect(next.progress?.itemIdx, 80);
    expect(next.current?.marker, 'M81');
    expect(next.progress?.totalItems, 180);
    expect(next.progress?.pctAvanco, lessThan(100));
    expect(next.progress?.pctAvanco, 44);
    expect(next.curriculum?.items, hasLength(81));
    expect(next.curriculum?.items[80].marker, 'M81');
    expect(
      next.curriculum?.items[80].extra['partLessonLocalId'],
      'lesson-cg::part-2',
    );
    expect(activeLessonView(next)?.ended, isFalse);
    expect(next.extra['serverAdvanceGate']?['lastDecision']?['partNumber'], 2);
    expect(
      next.extra['serverAdvanceGate']?['lastDecision']?['partLessonLocalId'],
      'lesson-cg::part-2',
    );
    expect(
      next.extra['serverAdvanceGate']?['lastDecision']?['partStatus'],
      'ready',
    );
    expect(
      next.extra['serverAdvanceGate']?['liveWindow']?['slots'],
      isA<List>(),
    );
  });

  test('App parseia envelope CG-1 autoritativo do Advance Gate', () {
    final decision = ServerAdvanceGateDecision.fromJson({
      'accepted': true,
      'decision': 'next_item',
      'reason': 'l3_to_next_item',
      'next': {
        'itemIdx': 80,
        'layer': 1,
        'globalItemNumber': 81,
        'localItemIdx': 0,
        'partNumber': 2,
        'rootLessonLocalId': 'lesson-cg',
        'partLessonLocalId': 'lesson-cg::part-2',
      },
      'authoritativeRootLessonLocalId': 'lesson-cg',
      'authoritativePartLessonLocalId': 'lesson-cg::part-2',
      'authoritativeGlobalItemNumber': 81,
      'authoritativeLocalItemIdx': 0,
      'authoritativeLayer': 1,
      'partStatus': 'ready',
      'nextPartStatus': 'preparing',
      'eventId': 'evt-cg-81',
      'requestId': 'req-cg-81',
      'liveWindow': {
        'slots': [
          {'globalItemNumber': 81, 'localItemIdx': 0, 'partNumber': 2},
        ],
      },
      'conflicts': [
        {'code': 'none'},
      ],
      'recoveryAction': {'action': 'none'},
      'highWaterMark': 80,
    });

    expect(decision.nextGlobalItemNumber, 81);
    expect(decision.nextLocalItemIdx, 0);
    expect(decision.authoritativeLayer, LessonLayer.l1);
    expect(decision.partStatus, 'ready');
    expect(decision.nextPartStatus, 'preparing');
    expect(decision.eventId, 'evt-cg-81');
    expect(decision.requestId, 'req-cg-81');
    expect(decision.liveWindow?['slots'], isA<List>());
    expect(decision.conflicts.single['code'], 'none');
    expect(decision.recoveryAction?['action'], 'none');
  });

  test('App trata proxima parte ausente como pendencia recuperavel CG-1', () {
    final items = List<CurriculumItem>.generate(
      80,
      (index) =>
          CurriculumItem(marker: 'M${index + 1}', text: 'Item ${index + 1}'),
    );
    final state =
        StudentLearningState.empty(
          lessonLocalId: 'lesson-cg-pending',
          userId: 'user-m4',
          now: 1,
        ).copyWith(
          curriculum: StudentCurriculum(
            topic: 'Curriculo grande',
            totalItems: 80,
            generatedAt: null,
            provisional: false,
            items: items,
            globalPlan: const CurriculumGlobalPlan(
              globalTotalItems: 180,
              batchStartItem: 1,
              batchEndItem: 80,
              operationalBatchLimit: 80,
              partNumber: 1,
              nextGlobalItemToRequest: 81,
              continuationNeeded: true,
            ),
          ),
          current: const LessonCurrent(
            itemIdx: 79,
            marker: 'M80',
            layer: LessonLayer.l3,
            amparoLvl: 0,
          ),
          progress: const LessonProgress(
            itemIdx: 79,
            layer: LessonLayer.l3,
            erros: 0,
            amparoLvl: 0,
            historia: [],
            mainAdvances: 79,
            concluidos: [],
            pendentesMarkers: [],
            totalItems: 180,
            pctAvanco: 43,
          ),
        );
    final request = ServerAdvanceGateRequest(
      lessonLocalId: state.lessonLocalId,
      userId: state.userId,
      marker: 'M80',
      itemIdx: 79,
      layer: LessonLayer.l3,
      selectedOption: AnswerLetter.A,
      signal: DecisionSignal.one,
      correct: true,
      idempotencyKey: 'cg-boundary-pending',
      currentState: state,
    );
    const decision = ServerAdvanceGateDecision(
      accepted: true,
      decision: 'next_item',
      reason: 'l3_to_next_item',
      nextItemIdx: 80,
      nextLayer: LessonLayer.l1,
      nextGlobalItemNumber: 81,
      nextLocalItemIdx: 0,
      nextPartNumber: 2,
      authoritativeRootLessonLocalId: 'lesson-cg-pending',
      authoritativePartLessonLocalId: 'lesson-cg-pending::part-2',
      authoritativeLayer: LessonLayer.l1,
      partStatus: 'preparing',
      nextPartStatus: 'preparing',
      liveWindow: {
        'slots': [
          {
            'itemIdx': 80,
            'layer': 1,
            'globalItemNumber': 81,
            'localItemIdx': 0,
            'partNumber': 2,
            'partLessonLocalId': 'lesson-cg-pending::part-2',
            'status': 'pending',
            'textStatus': 'pending',
          },
        ],
      },
      highWaterMark: 80,
      events: [
        {'type': 'ADVANCE_GATE_DECIDED', 'decision': 'next_item'},
      ],
    );

    final next = applyServerAdvanceGateDecision(
      state: state,
      request: request,
      decision: decision,
      now: 2,
    );

    expect(next.curriculum?.items, hasLength(80));
    expect(next.progress?.itemIdx, 79);
    expect(next.progress?.mainAdvances, 80);
    expect(next.progress?.pctAvanco, 44);
    expect(activeLessonView(next)?.ended, isFalse);
    expect(hasPendingCgPartTransition(next), isTrue);
    expect(
      next.extra['cgPartTransitionPending']?['partLessonLocalId'],
      'lesson-cg-pending::part-2',
    );
  });

  test('App nao duplica avanco quando retry usa mesma idempotencyKey', () {
    final state = _state();
    final request = _request(state);
    const decision = ServerAdvanceGateDecision(
      accepted: true,
      decision: 'next_layer',
      reason: 'secure_correct_next_layer',
      nextItemIdx: 0,
      nextLayer: LessonLayer.l2,
      highWaterMark: 2,
      events: [
        {'type': 'ADVANCE_GATE_DECIDED'},
      ],
    );

    final first = applyServerAdvanceGateDecision(
      state: state,
      request: request,
      decision: decision,
      now: 2,
    );
    final second = applyServerAdvanceGateDecision(
      state: first,
      request: request,
      decision: decision,
      now: 3,
    );

    expect(first.progress?.layer, LessonLayer.l2);
    expect(second.attempts.length, first.attempts.length);
    expect(second.events.length, first.events.length);
    expect(second.progress?.layer, LessonLayer.l2);
  });

  test(
    'Falha remota vira pendencia e preserva evidencia sem dominio local',
    () {
      final state = _state();
      final pending = recordPendingServerAdvanceGate(
        state: state,
        request: _request(state),
        error: const SimExternalAiException(
          'Servidor indisponivel',
          code: 'ADVANCE_GATE_TIMEOUT',
        ),
        now: 2,
      );

      expect(pending.queuedActions.single['type'], 'ADVANCE_GATE_PENDING');
      expect(pending.attempts, isEmpty);
      final payload = pending.queuedActions.single['payload'] as Map;
      expect(payload['marker'], 'M1');
      expect(payload['layer'], 1);
      expect(payload['selectedOption'], 'A');
      expect(pending.progress?.itemIdx, 0);
      expect(pending.progress?.layer, LessonLayer.l1);
      expect(pending.progress?.concluidos, isEmpty);
      expect(pending.events.last.payload['humanError'], contains('guardada'));
    },
  );
}
