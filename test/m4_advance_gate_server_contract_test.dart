import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/classroom/server_advance_gate.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

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

  test('Falha remota vira pendencia e preserva evidencia sem dominio local', () {
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
    expect(pending.attempts.single.marker, 'M1');
    expect(pending.attempts.single.layer, LessonLayer.l1);
    expect(pending.attempts.single.letra, AnswerLetter.A);
    expect(pending.progress?.itemIdx, 0);
    expect(pending.progress?.layer, LessonLayer.l1);
    expect(pending.progress?.concluidos, isEmpty);
    expect(pending.events.last.payload['humanError'], contains('guardada'));
  });
}
