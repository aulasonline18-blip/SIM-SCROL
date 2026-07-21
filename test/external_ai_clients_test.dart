import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_ai_clients.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

class RecordingTransport implements SimHttpTransport {
  Uri? lastUri;
  Map<String, String>? lastHeaders;
  Object? lastBody;
  Duration? lastTimeout;
  int statusCode = 200;
  Map<String, String> responseHeaders = const {};
  String jsonBody = '{"dataUrl":"data:image/png;base64,abc"}';
  List<String> streamLines = const [];
  bool throwTimeout = false;

  @override
  Future<SimHttpResponse> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (throwTimeout) throw TimeoutException('slow');
    lastUri = uri;
    lastHeaders = headers;
    lastBody = body;
    lastTimeout = timeout;
    return SimHttpResponse(
      statusCode: statusCode,
      body: jsonBody,
      headers: responseHeaders,
    );
  }

  @override
  Stream<String> postEventStream(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 140),
  }) async* {
    lastUri = uri;
    lastHeaders = headers;
    lastBody = body;
    for (final line in streamLines) {
      yield line;
    }
  }

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
    lastUri = uri;
    lastHeaders = headers;
    lastBody = {
      'fieldName': fieldName,
      'filename': filename,
      'contentType': contentType,
      'bytes': bytes.length,
    };
    return SimHttpResponse(
      statusCode: 200,
      body:
          '{"extractedText":"texto extraido","method":"pdf-text","charsExtracted":14}',
    );
  }
}

void main() {
  test('cliente de IA nao referencia deposito server-classroom removido', () {
    final source = File(
      'lib/sim/external_ai/sim_server_ai_clients.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('/api/server-classroom')));
    expect(source, isNot(contains('server-classroom')));
    expect(source, isNot(contains('ServerClassroom')));
  });

  SimAiServerConfig config() => SimAiServerConfig(
    baseUrl: 'https://gemini-aid-pal.lovable.app',
    accessTokenProvider: () async => 'user-token',
  );

  test('T00 consome /api/bootstrap-t00 por SSE com ficha e bearer', () async {
    final transport = RecordingTransport()
      ..streamLines = const [
        ': hb',
        'data: {"type":"t00_profile","profile":"ok","ficha_for_next":{"objetivo":"Aprender frações"}}',
        'data: {"type":"t00_item_partial","item":{"order":1,"marker":"M1","title":"Frações","purpose":"Aprender frações","text":"Frações"},"order":1,"marker":"M1"}',
        'data: {"type":"t00_partial_ready","count":1}',
        'data: {"type":"t00_final","curriculo":[{"order":1,"marker":"M1","title":"Frações","purpose":"Aprender frações","text":"Frações"}],"raw_complete":true}',
        'data: {"type":"done","ok":true}',
      ];
    final client = SimServerT00Client(config: config(), transport: transport);

    final chunks = await client
        .runBootstrap(
          const T00BootstrapRequest(
            lessonLocalId: 'lesson-1',
            onboarding: {'objetivo': 'Aprender frações'},
            lang: 'pt-BR',
            academic: 'ano 6',
            interfaceLocale: 'en',
            learningLocale: 'es',
            explanationLanguage: 'Spanish',
          ),
        )
        .toList();

    expect(
      transport.lastUri.toString(),
      'https://gemini-aid-pal.lovable.app/api/bootstrap-t00',
    );
    expect(transport.lastHeaders?['authorization'], 'Bearer user-token');
    expect(
      (transport.lastBody as Map)['ficha']['free_text'],
      'Aprender frações',
    );
    expect((transport.lastBody as Map)['ficha']['language'], 'pt-BR');
    expect((transport.lastBody as Map)['ficha']['stableLang'], 'Spanish');
    expect(chunks.map((chunk) => chunk.type), [
      't00_profile',
      't00_item_partial',
      't00_partial_ready',
      't00_final',
      'done',
    ]);
  });

  test('warmup remoto foi removido do cliente canônico do app', () {
    final source = File(
      'lib/sim/external_ai/sim_server_ai_clients.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('/api/warmup')));
    expect(source, isNot(contains('SimServerWarmupClient')));
  });

  test('audio usa /api/generate-lesson-audio e devolve dataUrl', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"dataUrl":"data:audio/wav;base64,abc","voice":"Charon","model":"gemini-2.5-flash-preview-tts"}';
    final client = SimServerGeneratedAudioClient(
      config: config(),
      transport: transport,
    );

    final dataUrl = await client.generateAudio(
      text: 'texto da aula',
      lang: 'pt-BR',
      voice: 'Charon',
      lessonKey: 'lesson-1',
    );

    expect(dataUrl, startsWith('data:audio/wav;base64,'));
    expect(
      transport.lastUri.toString(),
      'https://gemini-aid-pal.lovable.app/api/generate-lesson-audio',
    );
    expect((transport.lastBody as Map)['text'], 'texto da aula');
    expect((transport.lastBody as Map)['interfaceLocale'], 'pt-BR');
    expect((transport.lastBody as Map)['learningLocale'], 'pt-BR');
    expect((transport.lastBody as Map)['explanationLanguage'], 'Portuguese');
    expect(transport.lastHeaders?['x-request-id'], startsWith('sim-aud-'));
  });

  test('audio preserva requestId tecnico em erro controlado', () async {
    final transport = RecordingTransport()
      ..statusCode = 403
      ..jsonBody =
          '{"requestId":"rid-audio","code":"FORBIDDEN","retryable":false,"error":"sem permissao"}';
    final client = SimServerGeneratedAudioClient(
      config: config(),
      transport: transport,
    );

    await expectLater(
      client.generateAudio(
        text: 'texto',
        lang: 'pt-BR',
        voice: 'Charon',
        lessonKey: 'l1',
      ),
      throwsA(
        isA<SimExternalAiException>()
            .having((error) => error.statusCode, 'status', 403)
            .having((error) => error.requestId, 'requestId', 'rid-audio')
            .having((error) => error.code, 'code', 'AUTH_REQUIRED')
            .having((error) => error.message, 'message', 'AUTH_REQUIRED')
            .having((error) => error.retryable, 'retryable', false),
      ),
    );
  });

  test('erro publico de IA no corpo prevalece sobre status HTTP 403', () async {
    final transport = RecordingTransport()
      ..statusCode = 403
      ..jsonBody = jsonEncode({
        'ok': false,
        'status': 'failed',
        'error': 'AI_CONTRACT_INVALID',
        'retryable': false,
        'humanError': {
          'technical': {
            'code': 'AI_CONTRACT_INVALID',
            'retryable': false,
            'status': 403,
          },
        },
      });
    final client = SimServerT02Client(
      config: SimAiServerConfig(
        baseUrl: 'https://gemini-aid-pal.lovable.app',
        accessTokenProvider: () async => 'user-token',
        t02Path: '/api/complete-lesson',
      ),
      transport: transport,
    );

    await expectLater(
      client.completeLesson(
        const T02LessonRequest(
          lessonLocalId: 'lesson-menu',
          item: 'Item 45',
          lang: 'pt-BR',
          academic: 'base',
          layer: LessonLayer.l1,
          mode: 'lesson',
          errCount: 0,
          history: [],
        ),
      ),
      throwsA(
        isA<SimExternalAiException>()
            .having((error) => error.statusCode, 'status', 403)
            .having((error) => error.code, 'code', 'AI_CONTRACT_INVALID')
            .having((error) => error.message, 'message', 'AI_CONTRACT_INVALID')
            .having((error) => error.retryable, 'retryable', false),
      ),
    );
  });

  test(
    'timeout de audio vira erro retryable com requestId do cliente',
    () async {
      final transport = RecordingTransport()..throwTimeout = true;
      final client = SimServerGeneratedAudioClient(
        config: config(),
        transport: transport,
      );

      await expectLater(
        client.generateAudio(
          text: 'texto',
          lang: 'pt-BR',
          voice: 'Charon',
          lessonKey: 'l1',
        ),
        throwsA(
          isA<SimExternalAiException>()
              .having((error) => error.statusCode, 'status', 408)
              .having(
                (error) => error.requestId,
                'requestId',
                startsWith('sim-aud-'),
              )
              .having((error) => error.code, 'code', 'MEDIA_TIMEOUT')
              .having((error) => error.retryable, 'retryable', true),
        ),
      );
    },
  );

  test(
    'T02 nao inventa rota quando a ponte HTTP do servidor nao existe',
    () async {
      final client = SimServerT02Client(
        config: config(),
        transport: RecordingTransport(),
      );

      expect(
        () => client.completeLesson(
          const T02LessonRequest(
            lessonLocalId: 'lesson-1',
            item: 'Frações',
            lang: 'pt-BR',
            academic: 'ano 6',
            layer: LessonLayer.l1,
            mode: 'session',
            errCount: 0,
            history: [],
          ),
        ),
        throwsA(isA<SimExternalAiException>()),
      );
    },
  );

  test('T02 principal usa geracao direta sem server-classroom', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"conteudo":{"explanation":"Explique","question":"Pergunta?","options":{"A":"um","B":"dois","C":"tres"},"correct_answer":"A","why_correct":"ok","why_wrong":{"B":"nao","C":"nao"}}}';
    final client = SimServerT02Client(
      config: SimAiServerConfig(
        baseUrl: 'https://gemini-aid-pal.lovable.app',
        t02Path: '/api/sim/t02',
        accessTokenProvider: () async => 'user-token',
      ),
      transport: transport,
    );

    final material = await client.completeLesson(
      const T02LessonRequest(
        lessonLocalId: 'lesson-1',
        item: 'Frações',
        lang: 'pt-BR',
        academic: 'ano 6',
        layer: LessonLayer.l1,
        mode: 'session',
        errCount: 0,
        history: [],
        interfaceLocale: 'en',
        learningLocale: 'es',
        explanationLanguage: 'Spanish',
      ),
    );

    expect(
      transport.lastUri.toString(),
      'https://gemini-aid-pal.lovable.app/api/sim/t02',
    );
    expect((transport.lastBody as Map)['lessonLocalId'], 'lesson-1');
    expect((transport.lastBody as Map)['mode'], 'lesson');
    expect((transport.lastBody as Map)['idempotencyKey'], startsWith('t02:lesson:lesson-1:'));
    expect((transport.lastBody as Map)['interfaceLocale'], 'en');
    expect((transport.lastBody as Map)['learningLocale'], 'es');
    expect((transport.lastBody as Map)['explanationLanguage'], 'Spanish');
    expect((transport.lastBody as Map).containsKey('adopt'), isFalse);
    expect(material.question, 'Pergunta?');
    expect(material.source, 'sim-server-t02');
    expect(material.imageDataUrl, isNull);
  });

  test('T02 preserva Retry-After do servidor para nao reabrir tempestade', () async {
    final transport = RecordingTransport()
      ..statusCode = 429
      ..responseHeaders = const {'retry-after': '7'}
      ..jsonBody = '{"ok":false,"error":"AI_RATE_LIMIT","retryable":true}';
    final client = SimServerT02Client(
      config: SimAiServerConfig(
        baseUrl: 'https://sim.example',
        t02Path: '/api/complete-lesson',
      ),
      transport: transport,
    );

    await expectLater(
      client.completeLesson(
        const T02LessonRequest(
          lessonLocalId: 'lesson-rate',
          item: 'Função de primeiro grau',
          lang: 'pt-BR',
          academic: 'ano 9',
          layer: LessonLayer.l1,
          mode: 'session',
          errCount: 0,
          history: [],
          marker: 'M1',
          itemIdx: 0,
        ),
      ),
      throwsA(
        isA<SimExternalAiException>()
            .having((error) => error.statusCode, 'status', 429)
            .having((error) => error.code, 'code', 'AI_RATE_LIMIT')
            .having((error) => error.retryable, 'retryable', true)
            .having(
              (error) => error.retryAfter,
              'retryAfter',
              const Duration(seconds: 7),
            ),
      ),
    );
  });

  test('T02 usa timeout oficial maior que o orçamento do servidor', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"conteudo":{"explanation":"Explique","question":"Pergunta?","options":{"A":"um","B":"dois","C":"tres"},"correct_answer":"A","why_correct":"ok","why_wrong":{"B":"nao","C":"nao"}}}';
    final client = SimServerT02Client(
      config: SimAiServerConfig(
        baseUrl: 'https://sim.example',
        t02Path: '/api/complete-lesson',
      ),
      transport: transport,
    );

    await client.completeLesson(
      const T02LessonRequest(
        lessonLocalId: 'lesson-timeout',
        item: 'Frações',
        lang: 'pt-BR',
        academic: 'ano 6',
        layer: LessonLayer.l1,
        mode: 'session',
        errCount: 0,
        history: [],
      ),
    );

    expect(transport.lastTimeout, simT02LessonRequestTimeout);
    expect(simT02LessonRequestTimeout, const Duration(seconds: 140));
  });

  test('T02 timeout vira erro seguro e recuperavel', () async {
    final client = SimServerT02Client(
      config: SimAiServerConfig(
        baseUrl: 'https://sim.example',
        t02Path: '/api/complete-lesson',
      ),
      transport: RecordingTransport()..throwTimeout = true,
    );

    await expectLater(
      client.completeLesson(
        const T02LessonRequest(
          lessonLocalId: 'lesson-timeout',
          item: 'Frações',
          lang: 'pt-BR',
          academic: 'ano 6',
          layer: LessonLayer.l1,
          mode: 'session',
          errCount: 0,
          history: [],
        ),
      ),
      throwsA(
        isA<SimExternalAiException>()
            .having((error) => error.statusCode, 'status', 408)
            .having((error) => error.code, 'code', 'T02_TIMEOUT')
            .having((error) => error.retryable, 'retryable', true),
      ),
    );
  });

  test('T02 envia curriculo para geracao direta sem adotar sessao', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"conteudo":{"explanation":"Explique","question":"Pergunta?","options":{"A":"um","B":"dois","C":"tres"},"correct_answer":"A","why_correct":"ok","why_wrong":{"B":"nao","C":"nao"}}}';
    final client = SimServerT02Client(
      config: SimAiServerConfig(
        baseUrl: 'https://gemini-aid-pal.lovable.app',
        t02Path: '/api/sim/t02',
        accessTokenProvider: () async => 'user-token',
      ),
      transport: transport,
    );

    await client.completeLesson(
      const T02LessonRequest(
        lessonLocalId: 'old-lesson-1',
        item: 'Movimento uniforme',
        lang: 'pt-BR',
        academic: 'ano 9',
        layer: LessonLayer.l1,
        mode: 'session',
        errCount: 0,
        history: [],
        marker: 'M2',
        topic: 'Fisica',
        itemIdx: 1,
        profile: {'target_topic': 'Fisica'},
        interfaceLocale: 'en',
        learningLocale: 'pt-BR',
        explanationLanguage: 'Portuguese',
        curriculumItems: [
          {
            'order': 1,
            'marker': 'M1',
            'title': 'Velocidade',
            'text': 'Velocidade media',
          },
          {
            'order': 2,
            'marker': 'M2',
            'title': 'Movimento uniforme',
            'text': 'Movimento uniforme',
          },
        ],
      ),
    );

    final body = transport.lastBody as Map;
    expect(body['lessonLocalId'], 'old-lesson-1');
    expect(body['topic'], 'Fisica');
    expect(body['itemIdx'], 1);
    expect(body['marker'], 'M2');
    expect(body['interfaceLocale'], 'en');
    expect(body['learningLocale'], 'pt-BR');
    expect(body['explanationLanguage'], 'Portuguese');
    expect(body.containsKey('adopt'), isFalse);
    expect(body['curriculumItems'], hasLength(2));
    expect(body['target_topic'], 'Fisica');
  });

  test('T02 envia plano global do curriculo para geracao direta CG-1', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"conteudo":{"explanation":"Explique","question":"Pergunta?","options":{"A":"um","B":"dois","C":"tres"},"correct_answer":"A","why_correct":"ok","why_wrong":{"B":"nao","C":"nao"}}}';
    final client = SimServerT02Client(
      config: SimAiServerConfig(
        baseUrl: 'https://gemini-aid-pal.lovable.app',
        t02Path: '/api/sim/t02',
        accessTokenProvider: () async => 'user-token',
      ),
      transport: transport,
    );

    const globalPlan = {
      'globalTotalItems': 360,
      'batchStartItem': 1,
      'batchEndItem': 80,
      'partNumber': 1,
      'nextGlobalItemToRequest': 81,
      'continuationNeeded': true,
    };

    await client.completeLesson(
      const T02LessonRequest(
        lessonLocalId: 'cg-lesson-1',
        item: 'Item 80',
        lang: 'pt-BR',
        academic: 'ano 9',
        layer: LessonLayer.l2,
        mode: 'session',
        errCount: 0,
        history: [],
        marker: 'M80',
        topic: 'Matematica',
        itemIdx: 79,
        profile: {
          'target_topic': 'Matematica',
          'curriculum_global_plan': globalPlan,
        },
        curriculumItems: [
          {'order': 1, 'marker': 'M1', 'title': 'Item 1', 'text': 'Item 1'},
          {'order': 80, 'marker': 'M80', 'title': 'Item 80', 'text': 'Item 80'},
        ],
      ),
    );

    final body = transport.lastBody as Map;
    expect(body.containsKey('adopt'), isFalse);
    expect(body['curriculumItems'], hasLength(2));
    expect(body['curriculum_global_plan'], globalPlan);
  });

  test('T02 invalido nao vira aula falsa nem default A', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"conteudo":{"explanation":"Exp","question":"Pergunta?","options":{"A":"um","B":"dois","C":"tres"},"correct_answer":"D"}}';
    final client = SimServerT02Client(
      config: SimAiServerConfig(
        baseUrl: 'https://gemini-aid-pal.lovable.app',
        t02Path: '/api/sim/t02',
        accessTokenProvider: () async => 'user-token',
      ),
      transport: transport,
    );

    await expectLater(
      client.completeLesson(
        const T02LessonRequest(
          lessonLocalId: 'lesson-1',
          item: 'Frações',
          lang: 'pt-BR',
          academic: 'ano 6',
          layer: LessonLayer.l1,
          mode: 'session',
          errCount: 0,
          history: [],
        ),
      ),
      throwsA(
        isA<SimExternalAiException>().having(
          (error) => error.message,
          'message',
          'T02_CONTRACT_INVALID',
        ),
      ),
    );
  });

  test(
    'T02 preserva visual_trigger e metadados de imagem do contrato',
    () async {
      final transport = RecordingTransport()
        ..jsonBody = jsonEncode({
          'conteudo': {
            'explanation': 'Explique',
            'question': 'Pergunta?',
            'options': {'A': 'um', 'B': 'dois', 'C': 'tres'},
            'correct_answer': 'A',
            'why_correct': 'ok',
            'visual_trigger': {
              'needs_image': true,
              'visual_type': 'math_template',
              'math_template': 'linear_function',
            },
            'imageDataUrl': 'data:image/svg+xml;base64,AAAA',
            'imageStatus': 'ready',
            'imageId': 'img-1',
            'imageError': 'VISUAL_OK',
            'mimeType': 'image/svg+xml',
            'rasterized': false,
            'n2Reason': 'template_matematico_local',
            'n3Reason': 'nao_usou_n3',
          },
        });
      final client = SimServerT02Client(
        config: SimAiServerConfig(
          baseUrl: 'https://sim.example',
          t02Path: '/api/sim/t02',
        ),
        transport: transport,
      );

      final material = await client.completeLesson(
        const T02LessonRequest(
          lessonLocalId: 'lesson-visual',
          item: 'Funcao linear',
          lang: 'pt-BR',
          academic: 'ano 9',
          layer: LessonLayer.l1,
          mode: 'session',
          errCount: 0,
          history: [],
        ),
      );

      expect(material.visualTrigger?['needs_image'], isTrue);
      expect(material.visualTrigger?['math_template'], 'linear_function');
      expect(material.imageDataUrl, startsWith('data:image/svg+xml'));
      expect(material.imageStatus, 'ready');
      expect(material.imageId, 'img-1');
      expect(material.imageError, 'VISUAL_OK');
      expect(material.mimeType, 'image/svg+xml');
      expect(material.rasterized, isFalse);
      expect(material.n2Reason, 'template_matematico_local');
      expect(material.n3Reason, 'nao_usou_n3');
    },
  );
}
