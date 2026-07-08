import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/auxiliary/server_doubt_contract.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_ai_clients.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

class FakeDoubtTransport implements ServerDoubtTransport {
  FakeDoubtTransport({this.fail = false});

  final bool fail;
  final bodies = <JsonMap>[];

  @override
  Future<JsonMap> postDoubt(JsonMap body) async {
    bodies.add(JsonMap.of(body));
    if (fail) {
      return {
        'ok': false,
        'status': 'failed',
        'duplicate': false,
        'doubtId': 'doubt-m8',
        'lessonLocalId': body['lessonLocalId'],
        'marker': body['marker'],
        'itemIdx': body['itemIdx'],
        'layer': body['layer'],
        'answerText': '',
        'followUpAllowed': false,
        'source': 'server_doubt_room',
        'createdAt': '2026-07-08T00:00:00.000Z',
        'humanError': {
          'message':
              'Nao conseguimos responder essa duvida agora. Tente novamente.',
          'action': 'try_again',
        },
        'mainProgressPreserved': true,
        'stateMutation': {
          'progressChanged': false,
          'domainChanged': false,
          'answerErased': false,
          'itemAdvanced': false,
          'layerChanged': false,
          'masteryChanged': false,
          'weaknessChanged': false,
          'conquestChanged': false,
          'truthChanged': false,
        },
        'events': [
          {'type': 'DOUBT_FAILED', 'marker': body['marker']},
        ],
      };
    }
    return {
      'ok': true,
      'status': 'ready',
      'duplicate': false,
      'doubtId': 'doubt-m8',
      'lessonLocalId': body['lessonLocalId'],
      'marker': body['marker'],
      'itemIdx': body['itemIdx'],
      'layer': body['layer'],
      'answerText': 'Resposta auxiliar do servidor.',
      'followUpAllowed': true,
      'source': 'server_doubt_room',
      'createdAt': '2026-07-08T00:00:00.000Z',
      'humanError': null,
      'mainProgressPreserved': true,
      'stateMutation': {
        'progressChanged': false,
        'domainChanged': false,
        'answerErased': false,
        'itemAdvanced': false,
        'layerChanged': false,
        'masteryChanged': false,
        'weaknessChanged': false,
        'conquestChanged': false,
        'truthChanged': false,
      },
      'events': [
        {
          'type': 'DOUBT_OPENED',
          'marker': body['marker'],
          'layer': body['layer'],
          'idempotencyKey': body['idempotencyKey'],
        },
        {
          'type': 'DOUBT_SUBMITTED',
          'marker': body['marker'],
          'layer': body['layer'],
          'idempotencyKey': body['idempotencyKey'],
        },
        {
          'type': 'DOUBT_ANSWER_READY',
          'marker': body['marker'],
          'layer': body['layer'],
          'idempotencyKey': body['idempotencyKey'],
        },
      ],
    };
  }
}

class FakeHttpTransport implements SimHttpTransport {
  Uri? uri;
  Object? body;

  @override
  Future<SimHttpResponse> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    this.uri = uri;
    this.body = body;
    return SimHttpResponse(
      statusCode: 200,
      body: jsonEncode({
        'ok': true,
        'status': 'ready',
        'doubtId': 'doubt-m8',
        'lessonLocalId': (body as Map)['lessonLocalId'],
        'marker': body['marker'],
        'itemIdx': body['itemIdx'],
        'layer': body['layer'],
        'answerText': 'Resposta pelo endpoint /api/doubt.',
        'followUpAllowed': true,
        'source': 'server_doubt_room',
        'createdAt': '2026-07-08T00:00:00.000Z',
        'stateMutation': {
          'progressChanged': false,
          'domainChanged': false,
          'answerErased': false,
          'itemAdvanced': false,
          'layerChanged': false,
        },
        'mainProgressPreserved': true,
        'events': [
          {'type': 'DOUBT_ANSWER_READY'},
        ],
      }),
    );
  }

  @override
  Stream<String> postEventStream(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 45),
  }) async* {}

  @override
  Future<SimHttpResponse> postMultipart(
    Uri uri, {
    required Map<String, String> headers,
    required String fieldName,
    required String filename,
    required String contentType,
    required List<int> bytes,
    Duration timeout = const Duration(seconds: 45),
  }) {
    throw UnimplementedError();
  }
}

ServerDoubtContext _context() => const ServerDoubtContext(
  lessonLocalId: 'lesson-m8',
  userId: 'user-1',
  sessionId: 'session-1',
  marker: 'M8-1',
  itemIdx: 2,
  layer: 2,
  currentQuestion: 'Qual alternativa explica a causa?',
  currentOptions: {'A': 'Causa', 'B': 'Cor', 'C': 'Som'},
  selectedOption: 'A',
  signal: 2,
  currentFeedback: {'status': 'needs_review'},
  studentQuestion: 'Por que A e melhor?',
  attachment: {'name': 'doubt.png', 'type': 'image/png'},
  interfaceLocale: 'pt-BR',
  learningLocale: 'pt-BR',
  explanationLanguage: 'pt-BR',
  idempotencyKey: 'm8-doubt-key',
  currentState: {
    'current': {'itemIdx': 2, 'layer': 2, 'marker': 'M8-1'},
    'attempts': [
      {'marker': 'M8-1', 'layer': 2, 'letra': 'A', 'sinal': 2, 'correct': true},
    ],
    'truth_typed': {
      'mastery_evidence': [
        {'marker': 'M8-1', 'status': 'needs_review'},
      ],
      'weakness_records': [
        {'marker': 'M8-1', 'active': true},
      ],
      'conquest_records': [],
    },
  },
  history: [
    {'type': 'ANSWER_SUBMITTED', 'marker': 'M8-1'},
  ],
);

void main() {
  test('M8 App monta contexto estruturado para /api/doubt', () {
    final json = _context().toJson();

    expect(json['lessonLocalId'], 'lesson-m8');
    expect(json['userId'], 'user-1');
    expect(json['marker'], 'M8-1');
    expect(json['itemIdx'], 2);
    expect(json['layer'], 2);
    expect(json['currentQuestion'], isNotEmpty);
    expect((json['currentOptions'] as Map)['A'], 'Causa');
    expect(json['selectedOption'], 'A');
    expect(json['signal'], 2);
    expect(json['studentQuestion'], isNotEmpty);
    expect(json['interfaceLocale'], 'pt-BR');
    expect(json['learningLocale'], 'pt-BR');
    expect(json['idempotencyKey'], 'm8-doubt-key');
  });

  test('M8 App envia dúvida e mostra resposta auxiliar do servidor', () async {
    final transport = FakeDoubtTransport();
    final client = ServerDoubtClient(transport);

    final response = await client.ask(_context());

    expect(transport.bodies, hasLength(1));
    expect(transport.bodies.single['lessonLocalId'], 'lesson-m8');
    expect(response.ok, isTrue);
    expect(response.answerText, 'Resposta auxiliar do servidor.');
    expect(response.source, 'server_doubt_room');
    expect(
      response.events.map((event) => event['type']),
      contains('DOUBT_ANSWER_READY'),
    );
  });

  test(
    'M8 App preserva item, camada, resposta e sinal ao lidar com dúvida',
    () async {
      final before = JsonMap.from(_context().currentState);
      final transport = FakeDoubtTransport();
      final client = ServerDoubtClient(transport);

      final response = await client.ask(_context());
      final after = JsonMap.from(before);

      expect(response.progressPreserved, isTrue);
      expect((after['current'] as Map)['itemIdx'], 2);
      expect((after['current'] as Map)['layer'], 2);
      final attempts = after['attempts'] as List;
      expect((attempts.single as Map)['letra'], 'A');
      expect((attempts.single as Map)['sinal'], 2);
    },
  );

  test('M8 App não altera domínio ao receber resposta de dúvida', () async {
    final beforeTruth = JsonMap.from(
      _context().currentState['truth_typed'] as Map,
    );
    final transport = FakeDoubtTransport();
    final client = ServerDoubtClient(transport);

    final response = await client.ask(_context());
    final afterTruth = JsonMap.from(beforeTruth);

    expect(response.domainPreserved, isTrue);
    expect(afterTruth['mastery_evidence'], beforeTruth['mastery_evidence']);
    expect(afterTruth['weakness_records'], beforeTruth['weakness_records']);
    expect(afterTruth['conquest_records'], beforeTruth['conquest_records']);
  });

  test('M8 erro de dúvida é humano e controlado', () async {
    final transport = FakeDoubtTransport(fail: true);
    final client = ServerDoubtClient(transport);

    final response = await client.ask(_context());

    expect(response.ok, isFalse);
    expect(response.humanError?['message'], contains('Tente novamente'));
    expect(response.humanError.toString(), isNot(contains('stack')));
    expect(response.progressPreserved, isTrue);
    expect(response.domainPreserved, isTrue);
  });

  test('M8 cliente T02 ativo envia dúvida para /api/doubt', () async {
    final transport = FakeHttpTransport();
    final client = SimServerT02Client(
      config: const SimAiServerConfig(baseUrl: 'https://sim.example'),
      transport: transport,
    );

    final material = await client.doubt(
      const T02LessonRequest(
        lessonLocalId: 'lesson-m8',
        item: 'Qual alternativa explica a causa?',
        lang: 'pt-BR',
        academic: 'ensino_medio',
        layer: LessonLayer.l2,
        mode: 'doubt',
        errCount: 0,
        history: ['conteudo atual', 'Por que A e melhor?'],
        marker: 'M8-1',
        itemIdx: 2,
        profile: {
          'student_doubt': 'Por que A e melhor?',
          'selectedOption': 'A',
          'signal': 2,
          'currentOptions': {'A': 'Causa', 'B': 'Cor', 'C': 'Som'},
          'currentState': {
            'current': {'itemIdx': 2, 'layer': 2},
          },
        },
      ),
    );

    expect(transport.uri?.path, '/api/doubt');
    final body = Map<String, Object?>.from(transport.body! as Map);
    expect(body['studentQuestion'], 'Por que A e melhor?');
    expect(body['selectedOption'], 'A');
    expect(body['signal'], 2);
    expect(body['currentState'], isA<Map>());
    expect(material.explanation, 'Resposta pelo endpoint /api/doubt.');
    expect(material.source, 'server_doubt_room');
  });
}
