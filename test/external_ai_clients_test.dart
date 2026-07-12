import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_ai_clients.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
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
      expect(body['mode'], 'WARMUP_WELCOME_BRIDGE');
      expect(body['officialCurriculum'], false);
      expect(body['countsForMastery'], false);
      expect(body['interfaceLocale'], 'pt-BR');
      expect((body['ficha'] as Map)['learningLocale'], 'pt-BR');
      expect((body['ficha'] as Map)['academic_level'], 'ano 8');
      expect((body['ficha'] as Map)['mode'], 'WARMUP_WELCOME_BRIDGE');
      expect(transport.lastTimeout, const Duration(seconds: 70));
      expect(
        (body['ficha'] as Map)['objective'],
        'Aprender deslocamento em Física',
      );
      expect(lesson?.toJson()['officialCurriculum'], isFalse);
      expect(lesson?.toJson()['countsForMastery'], isFalse);
      expect(lesson?.toJson()['mode'], 'WARMUP_WELCOME_BRIDGE');
      expect(lesson?.toJson()['welcomeBridge'], isTrue);
      expect(lesson?.options.keys, ['A', 'B', 'C']);
      expect(lesson?.correctAnswer, 'A');
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
          '{"slot":{"material":{"conteudo":{"explanation":"Explique","question":"Pergunta?","options":{"A":"um","B":"dois","C":"tres"},"correct_answer":"A","why_correct":"ok","why_wrong":{"B":"nao","C":"nao"}}},"imageId":"img-1","image":{"imageId":"img-1","dataUrl":"data:image/png;base64,abc","mimeType":"image/png"}}}';
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
