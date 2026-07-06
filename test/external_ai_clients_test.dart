import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_ai_clients.dart';
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

  test(
    'T00 usa a mesma porta viva /api/bootstrap-t00 com ficha e bearer',
    () async {
      final transport = RecordingTransport()
        ..streamLines = const [
          'data: {"type":"t00_profile","profile":"ok"}',
          'data: {"type":"t00_item_partial","item":{"marker":"M1","text":"Frações"}}',
        ];
      final client = SimServerT00Client(config: config(), transport: transport);

      final chunks = await client
          .runBootstrap(
            const T00BootstrapRequest(
              lessonLocalId: 'lesson-1',
              onboarding: {'objetivo': 'Aprender frações'},
              lang: 'pt-BR',
              academic: 'ano 6',
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
      expect(chunks.map((chunk) => chunk.type), [
        't00_profile',
        't00_item_partial',
      ]);
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

  test('rota visual usa /api/visual-route e preserva SVG gratuito', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"verdict":"svg","reason":"VISUAL_ROUTE_SVG","svgDataUrl":"data:image/svg+xml;utf8,%3Csvg%3E%3C%2Fsvg%3E","requestId":"rid-vis","confidence":0.91,"pedagogicalRole":"graph_reasoning"}';
    final client = SimServerVisualRouterClient(
      config: config(),
      transport: transport,
    );

    final result = await client.routeVisual(
      n2: const VisualN2Result(
        verdict: VisualVerdict.ambiguous,
        matched: ['graph'],
        reason: 'N2_AMBIGUOUS',
      ),
      topic: 'funcao linear',
      visualType: 'graph',
      imagePrompt: 'grafico de uma reta',
      keyElements: const ['eixo x', 'eixo y'],
      pedagogicalNeed: 'important',
      highlightFocus: 'inclinação da reta',
      complexity: 'simple',
      stableLang: 'pt-BR',
    );

    expect(
      transport.lastUri.toString(),
      'https://gemini-aid-pal.lovable.app/api/visual-route',
    );
    expect(transport.lastHeaders?['authorization'], 'Bearer user-token');
    expect(transport.lastHeaders?['x-request-id'], startsWith('sim-vis-'));
    final body = transport.lastBody as Map;
    expect(body['contractVersion'], 'n3_pedagogical_v1');
    expect(body['hint'], 'ambiguous');
    expect(body['keyElements'], ['eixo x', 'eixo y']);
    expect(body['pedagogicalNeed'], 'important');
    expect(body['highlightFocus'], 'inclinação da reta');
    expect(body['complexity'], 'simple');
    expect(body['stableLang'], 'pt-BR');
    expect(
      (body['outputContract'] as Map)['format'],
      'structured_visual_route',
    );
    expect((body['outputContract'] as Map)['allowedVerdicts'], [
      'svg',
      'ai',
      'no_image',
    ]);
    expect((body['outputContract'] as Map)['paidImageIsLastResort'], isTrue);
    expect((body['qualityGate'] as Map)['preferPedagogicalSvg'], isTrue);
    expect(
      (body['qualityGate'] as Map)['avoidPaidForDiagramsGraphsTablesTimelines'],
      isTrue,
    );
    expect((body['n2'] as Map)['reason'], 'N2_AMBIGUOUS');
    expect((body['n2'] as Map)['confidence'], 0.5);
    expect(result.verdict, VisualVerdict.svg);
    expect(result.svgDataUrl, startsWith('data:image/svg+xml;utf8,'));
    expect(result.displayDataUrl, isNull);
    expect(result.confidence, 0.91);
    expect(result.pedagogicalRole, 'graph_reasoning');
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
        n2: const VisualN2Result(
          verdict: VisualVerdict.ambiguous,
          matched: ['graph'],
          reason: 'N2_AMBIGUOUS',
        ),
        topic: 'funcao linear',
        visualType: 'graph',
        imagePrompt: 'grafico de uma reta',
      );

      expect(result.verdict, VisualVerdict.svg);
      expect(result.svgDataUrl, startsWith('data:image/svg+xml;utf8,'));
      expect(result.displayDataUrl, 'data:image/webp;base64,AAAA');
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
        n2: const VisualN2Result(
          verdict: VisualVerdict.ambiguous,
          matched: ['graph'],
          reason: 'N2_AMBIGUOUS',
        ),
        topic: 'funcao linear',
        visualType: 'graph',
        imagePrompt: 'grafico de uma reta',
      );

      expect(result.verdict, VisualVerdict.svg);
      expect(result.svgDataUrl, startsWith('data:image/svg+xml;utf8,'));
      expect(result.displayDataUrl, 'data:image/webp;base64,DISPLAY');
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
      n2: const VisualN2Result(
        verdict: VisualVerdict.ambiguous,
        matched: ['server_image_pipeline'],
        reason: 'SERVER_IMAGE_PIPELINE',
      ),
      topic: 'grafico pronto',
      visualType: 'graph',
      imagePrompt: 'svg pronto',
      svgPayload: '<svg><circle cx="1" cy="1" r="1"/></svg>',
      mathTemplate: const {
        'name': 'linear_function',
        'params': {'a': 2, 'b': 1},
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
    expect(result.displayDataUrl, 'data:image/png;base64,AAAA');
  });

  test('rota visual preserva decisao no_image do N3 pedagogico', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"verdict":"no_image","reason":"TEST_NO_IMAGE","requestId":"rid-no-image","confidence":0.82,"pedagogicalRole":"concept_anchor"}';
    final client = SimServerVisualRouterClient(
      config: config(),
      transport: transport,
    );

    final result = await client.routeVisual(
      n2: const VisualN2Result(
        verdict: VisualVerdict.ambiguous,
        matched: ['diagram'],
        reason: 'N2_AMBIGUOUS',
      ),
      topic: 'conceito que nao precisa de imagem',
      visualType: 'diagram',
      imagePrompt: 'imagem pode confundir',
    );

    expect(result.verdict, VisualVerdict.noImage);
    expect(result.svgDataUrl, isNull);
    expect(result.reason, 'TEST_NO_IMAGE');
    expect(result.confidence, 0.82);
    expect(result.pedagogicalRole, 'concept_anchor');
    expect(result.requestId, 'rid-no-image');
  });

  test('rota visual preserva oferta paga decidida pelo servidor', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"verdict":"ai","reason":"SERVER_PAID_AI","paidOfferPrompt":"Prompt aprovado no servidor","paidOffer":{"prompt":"Prompt aprovado no servidor","cost":10},"requestId":"rid-paid"}';
    final client = SimServerVisualRouterClient(
      config: config(),
      transport: transport,
    );

    final result = await client.routeVisual(
      n2: const VisualN2Result(
        verdict: VisualVerdict.ai,
        matched: ['photo'],
        reason: 'LOCAL_WOULD_HAVE_STOPPED',
      ),
      topic: 'foto realista de laboratorio',
      visualType: 'photograph',
      imagePrompt: 'foto realista',
    );

    expect(transport.lastUri.toString(), endsWith('/api/visual-route'));
    expect(
      (transport.lastBody as Map)['n2']['reason'],
      'LOCAL_WOULD_HAVE_STOPPED',
    );
    expect(result.verdict, VisualVerdict.ai);
    expect(result.reason, 'SERVER_PAID_AI');
    expect(result.paidOfferPrompt, 'Prompt aprovado no servidor');
    expect(result.requestId, 'rid-paid');
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

  test('T02 usa ponte HTTP do servidor quando configurada', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"explanation":"Explique","question":"Pergunta?","options":{"A":"um","B":"dois","C":"tres"},"correct_answer":"A","why_correct":"ok","why_wrong":{"B":"nao","C":"nao"}}';
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
      ),
    );

    expect(
      transport.lastUri.toString(),
      'https://gemini-aid-pal.lovable.app/api/sim/t02',
    );
    expect((transport.lastBody as Map)['mode'], 'lesson');
    expect(material.question, 'Pergunta?');
  });

  test('T02 invalido nao vira aula falsa nem default A', () async {
    final transport = RecordingTransport()
      ..jsonBody =
          '{"explanation":"Exp","question":"Pergunta?","options":{"A":"um","B":"dois","C":"tres"},"correct_answer":"D"}';
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
