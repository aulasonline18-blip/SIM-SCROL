import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_ai_clients.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/media/lesson_visual_pipeline.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

class RecordingTransport implements SimHttpTransport {
  Uri? lastUri;
  Map<String, String>? lastHeaders;
  Object? lastBody;
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

  test(
    'warmup usa /api/warmup como sala paralela sem curriculo oficial',
    () async {
      final transport = RecordingTransport()
        ..jsonBody =
            '{"ok":true,"warmup":{"type":"warmup","officialCurriculum":false,"countsForMastery":false,"explanation":"Antes da aula oficial, pense no deslocamento como a distância entre começo e fim.","question":"Um ciclista sai do km 0 e chega ao km 10. Qual é o deslocamento?","options":{"A":"10 km","B":"0 km","C":"20 km"},"correct_answer":"A","why_correct":"A posição final está 10 km depois do início.","why_wrong":{"B":"0 km seria voltar ao ponto inicial.","C":"20 km não é a distância entre início e fim."}}}';
      final client = SimServerWarmupClient(
        config: config(),
        transport: transport,
      );

      final lesson = await client.generate(
        lessonLocalId: 'lesson-warmup-1',
        objective: 'Aprender deslocamento em Física',
        ficha: const {'free_text': 'Aprender deslocamento em Física'},
        locale: const SimLocaleContract(
          interfaceLocale: 'pt-BR',
          learningLocale: 'pt-BR',
          explanationLanguage: 'Portuguese',
        ),
        academic: 'ano 8',
      );

      expect(
        transport.lastUri.toString(),
        'https://gemini-aid-pal.lovable.app/api/warmup',
      );
      expect(transport.lastHeaders?['authorization'], 'Bearer user-token');
      final body = transport.lastBody as Map;
      expect(body['lessonLocalId'], 'lesson-warmup-1');
      expect(body['objective'], 'Aprender deslocamento em Física');
      expect(body['interfaceLocale'], 'pt-BR');
      expect((body['ficha'] as Map)['learningLocale'], 'pt-BR');
      expect((body['ficha'] as Map)['academic_level'], 'ano 8');
      expect(lesson?.toJson()['officialCurriculum'], isFalse);
      expect(lesson?.toJson()['countsForMastery'], isFalse);
      expect(lesson?.options.keys, ['A', 'B', 'C']);
      expect(lesson?.correctAnswer, 'A');
    },
  );

  test('imagem usa /api/generate-lesson-image sem chave de provedor', () async {
    final transport = RecordingTransport();
    final client = SimServerLessonImageClient(
      config: config(),
      transport: transport,
    );

    final dataUrl = await client.generateLessonImage(
      prompt: 'uma figura didática',
      lessonKey: 'lesson-1',
      acceptedOfferId: 'offer-1',
      idempotencyKey: 'offer-1',
      visualTrigger: const {'needs_image': true, 'visual_type': 'graph'},
      lessonContext: const {'stableLang': 'pt-BR', 'itemMarker': 'M1'},
    );

    expect(dataUrl, startsWith('data:image/'));
    expect(
      transport.lastUri.toString(),
      'https://gemini-aid-pal.lovable.app/api/generate-lesson-image',
    );
    expect(
      (transport.lastBody as Map).keys,
      containsAll([
        'prompt',
        'lessonKey',
        'aspectRatio',
        'acceptedOfferId',
        'idempotencyKey',
        'visual_trigger',
        'lessonContext',
        'source',
        'contractVersion',
      ]),
    );
    final body = transport.lastBody as Map;
    expect((body['visual_trigger'] as Map)['visual_type'], 'graph');
    expect((body['lessonContext'] as Map)['stableLang'], 'pt-BR');
    expect(body['source'], 'sim_app_flutter');
    expect(body['contractVersion'], 'lesson_image_paid_v1');
    expect(transport.lastHeaders.toString(), isNot(contains('GEMINI_API_KEY')));
    expect(
      transport.lastHeaders.toString(),
      isNot(contains('LOVABLE_API_KEY')),
    );
    expect(transport.lastHeaders?['x-request-id'], startsWith('sim-img-'));
  });

  test('imagem preserva metadados tecnicos de sucesso', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"dataUrl":"data:image/png;base64,abc","cacheKey":"image:user:key","requestId":"rid-ok","charged":true,"cache_hit":false,"mime_type":"image/png","provider":"gemini","model":"gemini-image"}';
    final client = SimServerLessonImageClient(
      config: config(),
      transport: transport,
    );

    final response = await client.generateLessonImageResponse(
      prompt: 'uma figura didática',
      lessonKey: 'lesson-1',
      acceptedOfferId: 'offer-1',
      idempotencyKey: 'offer-1',
    );

    expect(response?.dataUrl, startsWith('data:image/png;base64,'));
    expect(response?.cacheKey, 'image:user:key');
    expect(response?.requestId, 'rid-ok');
    expect(response?.charged, isTrue);
    expect(response?.cacheHit, isFalse);
    expect(response?.mimeType, 'image/png');
    expect(response?.provider, 'gemini');
    expect(response?.model, 'gemini-image');
  });

  test('rota visual envia visual_trigger para /api/visual-route', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"verdict":"svg","reason":"VISUAL_ROUTE_SVG","displayDataUrl":"data:image/png;base64,AAAA","requestId":"rid-vis"}';
    final client = SimServerVisualRouterClient(
      config: config(),
      transport: transport,
    );

    final result = await client.routeVisual(
      stableLang: 'pt-BR',
      visualTrigger: const {
        'interfaceLocale': 'en',
        'learningLocale': 'pt-BR',
        'explanationLanguage': 'Portuguese',
        'needs_image': true,
        'pedagogical_need': 'important',
        'topic': 'funcao linear',
        'visual_type': 'graph',
        'image_prompt': 'grafico de uma reta',
        'key_elements': ['eixo x', 'eixo y'],
        'highlight_focus': 'inclinação da reta',
        'complexity': 'simple',
      },
    );

    expect(
      transport.lastUri.toString(),
      'https://gemini-aid-pal.lovable.app/api/visual-route',
    );
    expect(transport.lastHeaders?['authorization'], 'Bearer user-token');
    expect(transport.lastHeaders?['x-request-id'], startsWith('sim-vis-'));
    final body = transport.lastBody as Map;
    expect(body['contractVersion'], 'server_ready_image_v1');
    expect(body['keyElements'], ['eixo x', 'eixo y']);
    expect(body['pedagogicalNeed'], 'important');
    expect(body['highlightFocus'], 'inclinação da reta');
    expect(body['complexity'], 'simple');
    expect(body['stableLang'], 'pt-BR');
    expect(body['interfaceLocale'], 'en');
    expect(body['learningLocale'], 'pt-BR');
    expect(body['explanationLanguage'], 'Portuguese');
    expect((body['outputContract'] as Map)['format'], 'ready_raster_image');
    expect(body.containsKey('hint'), isFalse);
    expect(body.containsKey('qualityGate'), isFalse);
    expect((body['visual_trigger'] as Map)['topic'], 'funcao linear');
    expect((body['visual_trigger'] as Map)['learningLocale'], 'pt-BR');
    expect(result.verdict, ServerVisualRouteVerdict.image);
    expect(result.readyImageDataUrl, 'data:image/png;base64,AAAA');
    expect(result.requestId, 'rid-vis');
  });

  test(
    'rota visual prefere imagem raster pronta quando servidor envia',
    () async {
      final transport = RecordingTransport()
        ..jsonBody =
            '{"verdict":"svg","reason":"VISUAL_ROUTE_SVG","svgDataUrl":"data:image/svg+xml;utf8,%3Csvg%3E%3C%2Fsvg%3E","displayDataUrl":"data:image/webp;base64,AAAA","rasterized":true,"requestId":"rid-vis"}';
      final client = SimServerVisualRouterClient(
        config: config(),
        transport: transport,
      );

      final result = await client.routeVisual(
        visualTrigger: const {
          'needs_image': true,
          'topic': 'funcao linear',
          'visual_type': 'graph',
          'image_prompt': 'grafico de uma reta',
        },
      );

      expect(result.verdict, ServerVisualRouteVerdict.image);
      expect(result.readyImageDataUrl, 'data:image/webp;base64,AAAA');
    },
  );

  test(
    'rota visual prioriza displayDataUrl sobre dataUrl image_data_url e svgDataUrl',
    () async {
      final transport = RecordingTransport()
        ..jsonBody =
            '{"verdict":"svg","reason":"VISUAL_ROUTE_SVG","svgDataUrl":"data:image/svg+xml;utf8,%3Csvg%3E%3C%2Fsvg%3E","displayDataUrl":"data:image/webp;base64,DISPLAY","dataUrl":"data:image/png;base64,DATA","image_data_url":"data:image/jpeg;base64,IMAGE","requestId":"rid-vis"}';
      final client = SimServerVisualRouterClient(
        config: config(),
        transport: transport,
      );

      final result = await client.routeVisual(
        visualTrigger: const {
          'needs_image': true,
          'topic': 'funcao linear',
          'visual_type': 'graph',
          'image_prompt': 'grafico de uma reta',
        },
      );

      expect(result.verdict, ServerVisualRouteVerdict.image);
      expect(result.readyImageDataUrl, 'data:image/webp;base64,DISPLAY');
    },
  );

  test('rota visual envia svg_payload e math_template para o servidor', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"verdict":"svg","reason":"T02_READY_SVG_RASTERIZED","svgDataUrl":"data:image/svg+xml;utf8,%3Csvg%3E%3C%2Fsvg%3E","displayDataUrl":"data:image/png;base64,AAAA","requestId":"rid-vis"}';
    final client = SimServerVisualRouterClient(
      config: config(),
      transport: transport,
    );

    final result = await client.routeVisual(
      visualTrigger: const {
        'needs_image': true,
        'topic': 'grafico pronto',
        'visual_type': 'graph',
        'image_prompt': 'svg pronto',
        'svg_payload': '<svg><circle cx="1" cy="1" r="1"/></svg>',
        'math_template': {
          'name': 'linear_function',
          'params': {'a': 2, 'b': 1},
        },
      },
    );

    final body = transport.lastBody as Map;
    expect(body['svgPayload'], '<svg><circle cx="1" cy="1" r="1"/></svg>');
    expect(body['mathTemplate'], {
      'name': 'linear_function',
      'params': {'a': 2, 'b': 1},
    });
    expect((body['visual_trigger'] as Map)['svg_payload'], body['svgPayload']);
    expect(
      (body['visual_trigger'] as Map)['math_template'],
      body['mathTemplate'],
    );
    expect(result.readyImageDataUrl, 'data:image/png;base64,AAAA');
  });

  test('rota visual preserva no_image do servidor', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"verdict":"no_image","reason":"TEST_NO_IMAGE","requestId":"rid-no-image","confidence":0.82,"pedagogicalRole":"concept_anchor"}';
    final client = SimServerVisualRouterClient(
      config: config(),
      transport: transport,
    );

    final result = await client.routeVisual(
      visualTrigger: const {
        'needs_image': true,
        'topic': 'conceito que nao precisa de imagem',
        'visual_type': 'diagram',
        'image_prompt': 'imagem pode confundir',
      },
    );

    expect(result.verdict, ServerVisualRouteVerdict.noImage);
    expect(result.readyImageDataUrl, isNull);
    expect(result.reason, 'TEST_NO_IMAGE');
    expect(result.requestId, 'rid-no-image');
  });

  test(
    'rota visual sem foto pronta vira missingRaster sem oferta no app',
    () async {
      final transport = RecordingTransport()
        ..jsonBody =
            '{"verdict":"ai","reason":"SERVER_PAID_AI","requestId":"rid-paid"}';
      final client = SimServerVisualRouterClient(
        config: config(),
        transport: transport,
      );

      final result = await client.routeVisual(
        visualTrigger: const {
          'needs_image': true,
          'topic': 'foto realista de laboratorio',
          'visual_type': 'photograph',
          'image_prompt': 'foto realista',
        },
      );

      expect(transport.lastUri.toString(), endsWith('/api/visual-route'));
      expect(result.verdict, ServerVisualRouteVerdict.missingRaster);
      expect(result.reason, 'SERVER_PAID_AI');
      expect(result.readyImageDataUrl, isNull);
      expect(result.requestId, 'rid-paid');
    },
  );

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

  test(
    'imagem preserva status requestId code e retryable no erro HTTP',
    () async {
      final transport = RecordingTransport()
        ..statusCode = 500
        ..responseHeaders = {'x-request-id': 'rid-header'}
        ..jsonBody =
            '{"requestId":"rid-body","error":{"code":"GEMINI_DOWN","message":"provedor fora","retryable":true}}';
      final client = SimServerLessonImageClient(
        config: config(),
        transport: transport,
      );

      await expectLater(
        client.generateLessonImage(prompt: 'p', lessonKey: 'l1'),
        throwsA(
          isA<SimExternalAiException>()
              .having((error) => error.statusCode, 'status', 500)
              .having((error) => error.requestId, 'requestId', 'rid-body')
              .having((error) => error.code, 'code', 'GEMINI_DOWN')
              .having((error) => error.retryable, 'retryable', true)
              .having((error) => error.message, 'message', 'provedor fora'),
        ),
      );
    },
  );

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
            .having((error) => error.code, 'code', 'FORBIDDEN')
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

  test('T02 principal usa slot pronto do server-classroom', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"slot":{"material":{"conteudo":{"explanation":"Explique","question":"Pergunta?","options":{"A":"um","B":"dois","C":"tres"},"correct_answer":"A","why_correct":"ok","why_wrong":{"B":"nao","C":"nao"},"visual_trigger":{"needs_image":true,"pedagogical_need":"important","render_strategy":"software","visual_type":"diagram","topic":"Frações","image_prompt":"desenhar frações"}}},"imageId":"img-1","image":{"imageId":"img-1","dataUrl":"data:image/png;base64,abc","mimeType":"image/png"}}}';
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
      'https://gemini-aid-pal.lovable.app/api/server-classroom/slot',
    );
    expect((transport.lastBody as Map)['lessonLocalId'], 'lesson-1');
    expect((transport.lastBody as Map)['interfaceLocale'], 'en');
    expect((transport.lastBody as Map)['learningLocale'], 'es');
    expect((transport.lastBody as Map)['explanationLanguage'], 'Spanish');
    expect(material.question, 'Pergunta?');
    expect(material.imageDataUrl, 'data:image/png;base64,abc');
    expect(material.imageId, 'img-1');
  });

  test(
    'T02 envia curriculo antigo para server-classroom adotar sessao',
    () async {
      final transport = RecordingTransport()
        ..jsonBody =
            '{"slot":{"material":{"conteudo":{"explanation":"Explique","question":"Pergunta?","options":{"A":"um","B":"dois","C":"tres"},"correct_answer":"A","why_correct":"ok","why_wrong":{"B":"nao","C":"nao"}}}}}';
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
      expect((body['adopt'] as Map)['topic'], 'Fisica');
      expect((body['adopt'] as Map)['profile'], {
        'target_topic': 'Fisica',
        'interfaceLocale': 'en',
        'learningLocale': 'pt-BR',
        'explanationLanguage': 'Portuguese',
      });
      expect((body['adopt'] as Map)['curriculumItems'], hasLength(2));
    },
  );

  test('T02 invalido nao vira aula falsa nem default A', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"slot":{"material":{"conteudo":{"explanation":"Exp","question":"Pergunta?","options":{"A":"um","B":"dois","C":"tres"},"correct_answer":"D"}}}}';
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
          contains('contrato invalido'),
        ),
      ),
    );
  });
}
