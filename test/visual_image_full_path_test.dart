import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sim_mobile/features/classroom/aula_widgets.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_ai_clients.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/media/lesson_image_api_contract.dart';
import 'package:sim_mobile/sim/media/lesson_visual_pipeline.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _pngBytesBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lK3QMgAAAABJRU5ErkJggg==';
const _webpDataUrl = 'data:image/webp;base64,$_pngBytesBase64';
const _pngDataUrl = 'data:image/png;base64,$_pngBytesBase64';
const _jpegDataUrl = 'data:image/jpeg;base64,$_pngBytesBase64';
const _svgDataUrl =
    'data:image/svg+xml;utf8,%3Csvg%20viewBox%3D%220%200%20900%20560%22%3E%3Crect%20width%3D%22900%22%20height%3D%22560%22%20fill%3D%22%23F8FAFC%22%2F%3E%3Ctext%20x%3D%2280%22%20y%3D%2290%22%20font-size%3D%2218%22%3Eentrada%3C%2Ftext%3E%3Ctext%20x%3D%2280%22%20y%3D%22130%22%20font-size%3D%2218%22%3Eprocesso%3C%2Ftext%3E%3Ctext%20x%3D%2280%22%20y%3D%22170%22%20font-size%3D%2218%22%3Esaida%3C%2Ftext%3E%3C%2Fsvg%3E';

void main() {
  test(
    'SimServerVisualRouterClient envia svgPayload e escolhe raster pronto',
    () async {
      final transport = _RecordingTransport()
        ..jsonBody = jsonEncode({
          'verdict': 'svg',
          'reason': 'SERVER_RASTERIZED',
          'svgDataUrl': _svgDataUrl,
          'displayDataUrl': _webpDataUrl,
          'dataUrl': _pngDataUrl,
          'image_data_url': _jpegDataUrl,
          'requestId': 'rid-vis',
        });
      final client = SimServerVisualRouterClient(
        config: _config(),
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
      );

      final body = transport.lastBody as Map;
      expect(body['svgPayload'], '<svg><circle cx="1" cy="1" r="1"/></svg>');
      expect(
        (body['visual_trigger'] as Map)['svg_payload'],
        body['svgPayload'],
      );
      expect(result.svgDataUrl, _svgDataUrl);
      expect(result.displayDataUrl, _webpDataUrl);
    },
  );

  test(
    'SimServerVisualRouterClient ignora raster invalido e preserva SVG como fallback',
    () async {
      final transport = _RecordingTransport()
        ..jsonBody = jsonEncode({
          'verdict': 'svg',
          'reason': 'SERVER_RASTERIZED',
          'svgDataUrl': _svgDataUrl,
          'displayDataUrl': 'data:image/svg+xml;utf8,%3Csvg%3E%3C%2Fsvg%3E',
          'dataUrl': 'data:text/plain;base64,AAAA',
          'image_data_url': _jpegDataUrl,
          'requestId': 'rid-vis',
        });
      final client = SimServerVisualRouterClient(
        config: _config(),
        transport: transport,
      );

      final result = await client.routeVisual(
        n2: const VisualN2Result(
          verdict: VisualVerdict.ambiguous,
          matched: ['graph'],
          reason: 'N2_AMBIGUOUS',
        ),
      );

      expect(result.svgDataUrl, _svgDataUrl);
      expect(result.displayDataUrl, _jpegDataUrl);
    },
  );

  testWidgets(
    'T02 SVG pronto vai ao servidor volta raster e aparece como Image.memory',
    (tester) async {
      final transport = _RecordingTransport()
        ..jsonBody = jsonEncode({
          'verdict': 'svg',
          'reason': 'T02_READY_SVG_RASTERIZED',
          'svgDataUrl': _svgDataUrl,
          'displayDataUrl': _webpDataUrl,
          'requestId': 'rid-t02',
        });
      final harness = _buildHarness(
        visualTransport: transport,
        visualTrigger: const {
          'needs_image': true,
          'pedagogical_need': 'important',
          'render_strategy': 'software',
          'visual_type': 'graph',
          'topic': 'grafico pronto',
          'image_prompt': 'svg pronto para rasterizar',
          'svg_payload': '<svg><circle cx="1" cy="1" r="1"/></svg>',
        },
      );

      final lesson = await harness.resolveImage();
      await _pumpImage(tester, lesson.imagem!);

      final body = transport.lastBody as Map;
      expect(body['svgPayload'], '<svg><circle cx="1" cy="1" r="1"/></svg>');
      expect(lesson.imagem, _webpDataUrl);
      expect(harness.cache.peek(harness.key)?.imagem, _webpDataUrl);
      _expectRasterImageShown();
    },
  );

  testWidgets('N3 SVG rasterizado pelo servidor aparece como Image.memory', (
    tester,
  ) async {
    final harness = _buildHarness(
      visualTransport: _RecordingTransport()
        ..jsonBody = jsonEncode({
          'verdict': 'svg',
          'reason': 'N3_SVG_RASTERIZED',
          'svgDataUrl': _svgDataUrl,
          'displayDataUrl': _pngDataUrl,
          'requestId': 'rid-n3',
        }),
      visualTrigger: const {
        'needs_image': true,
        'pedagogical_need': 'essential',
        'visual_type': 'flowchart',
        'topic': 'fluxograma',
        'image_prompt': 'fluxograma de entrada processo saida',
        'key_elements': ['entrada', 'processo', 'saida'],
      },
    );

    final lesson = await harness.resolveImage();
    await _pumpImage(tester, lesson.imagem!);

    expect(lesson.imagem, _pngDataUrl);
    expect(harness.cache.peek(harness.key)?.imagem, _pngDataUrl);
    _expectRasterImageShown();
  });

  testWidgets('AI paga devolve imagem pronta e aparece como Image.memory', (
    tester,
  ) async {
    final harness = _buildHarness(
      visualTransport: _RecordingTransport()
        ..jsonBody = jsonEncode({
          'verdict': 'ai',
          'reason': 'REALISTIC_IMAGE_REQUIRED',
          'paidOfferPrompt': 'imagem realista de anatomia',
          'requestId': 'rid-ai',
        }),
      imageClient: _FakePaidImageClient(_jpegDataUrl),
      visualTrigger: const {
        'needs_image': true,
        'pedagogical_need': 'essential',
        'visual_type': 'realistic',
        'topic': 'anatomia',
        'image_prompt': 'foto realista de anatomia',
      },
    );

    await harness.resolveImage(expectImage: false);
    await harness.waitForPaidImageOffer();
    final metadata = await harness.orchestrator.acceptPaidImageOffer(
      harness.key,
    );
    final lesson = harness.cache.peek(harness.key)!;
    await _pumpImage(tester, lesson.imagem!);

    expect(metadata, isNotNull);
    expect(lesson.imagem, _jpegDataUrl);
    _expectRasterImageShown();
  });

  test('no_image nao tenta mostrar imagem quebrada e aula segue', () async {
    final harness = _buildHarness(
      visualTransport: _RecordingTransport()
        ..jsonBody = jsonEncode({
          'verdict': 'no_image',
          'reason': 'NO_IMAGE_NEEDED',
          'requestId': 'rid-no-image',
        }),
      visualTrigger: const {
        'needs_image': true,
        'pedagogical_need': 'important',
        'visual_type': 'none',
        'topic': 'conceito textual',
        'image_prompt': 'sem imagem',
      },
    );

    final lesson = await harness.resolveImage(expectImage: false);

    expect(lesson.imagem, isNull);
    expect(lesson.conteudo.explanation, contains('Explicacao'));
    expect(harness.cache.peek(harness.key)?.imagem, isNull);
  });

  testWidgets('base64 invalido mostra erro controlado sem quebrar', (
    tester,
  ) async {
    await _pumpImage(tester, 'data:image/png;base64,%%%');

    expect(find.byType(LessonImageErrorView), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(SvgPicture), findsNothing);
  });
}

SimAiServerConfig _config() => SimAiServerConfig(
  baseUrl: 'https://sim.test',
  accessTokenProvider: () async => 'token',
);

_FullPathHarness _buildHarness({
  required _RecordingTransport visualTransport,
  required Map<String, Object?> visualTrigger,
  _FakePaidImageClient? imageClient,
}) {
  final params = const CompleteLessonParams(
    lessonLocalId: 'visual-full-path',
    item: 'Imagem pedagogica',
    lang: 'pt-BR',
    academic: 'ano 6',
    layer: LessonLayer.l1,
    mode: LessonMode.session,
  );
  final cache = LessonMaterialCache();
  final bus = LessonEventBus();
  final visualClient = SimServerVisualRouterClient(
    config: _config(),
    transport: visualTransport,
  );
  final orchestrator = LessonOrchestrator(
    t02Client: _FakeT02Client(visualTrigger),
    cache: cache,
    bus: bus,
    visualPipeline: LessonVisualPipeline(
      imageClient: imageClient ?? _FakePaidImageClient(_jpegDataUrl),
      visualRouterClient: visualClient,
    ),
  );
  return _FullPathHarness(
    params: params,
    cache: cache,
    bus: bus,
    orchestrator: orchestrator,
  );
}

Future<void> _pumpImage(WidgetTester tester, String dataUrl) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 220,
          height: 160,
          child: LessonMediaImageView(data: dataUrl),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectRasterImageShown() {
  expect(find.byType(Image), findsOneWidget);
  expect(find.byType(SvgPicture), findsNothing);
  expect(find.byType(LessonImageErrorView), findsNothing);
}

class _FullPathHarness {
  const _FullPathHarness({
    required this.params,
    required this.cache,
    required this.bus,
    required this.orchestrator,
  });

  final CompleteLessonParams params;
  final LessonMaterialCache cache;
  final LessonEventBus bus;
  final LessonOrchestrator orchestrator;

  String get key => lessonKeyFor(params);

  Future<CompleteLesson> resolveImage({bool expectImage = true}) async {
    final completer = Completer<CompleteLesson>();
    final cancel = bus.subscribe(key, (lesson) {
      if (!completer.isCompleted &&
          (expectImage
              ? lesson.imagem?.trim().isNotEmpty == true
              : cache.peek(key) != null)) {
        completer.complete(lesson);
      }
    });
    final base = await orchestrator.prefetchCompleteLesson(
      params,
      priority: 'active',
      forceRefresh: true,
    );
    if (!expectImage) {
      await Future<void>.value();
      await Future<void>.value();
      cancel();
      return cache.peek(key) ?? base;
    }
    try {
      return await completer.future.timeout(const Duration(seconds: 2));
    } finally {
      cancel();
    }
  }

  Future<LessonPaidImageOffer> waitForPaidImageOffer() {
    final completer = Completer<LessonPaidImageOffer>();
    late void Function() cancel;
    cancel = bus.subscribePaidImageOffer(key, (offer) {
      if (offer != null && !completer.isCompleted) {
        completer.complete(offer);
      }
    });
    return completer.future
        .timeout(const Duration(seconds: 2))
        .whenComplete(cancel);
  }
}

class _FakeT02Client implements T02LessonClient {
  const _FakeT02Client(this.visualTrigger);

  final Map<String, Object?> visualTrigger;

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    return T02LessonMaterial(
      explanation: 'Explicacao ${request.item}',
      question: 'Pergunta?',
      options: const {
        AnswerLetter.A: 'A',
        AnswerLetter.B: 'B',
        AnswerLetter.C: 'C',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'Correto.',
      whyWrong: null,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'fake-t02',
      visualTrigger: visualTrigger,
    );
  }

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) =>
      completeLesson(request);
}

class _FakePaidImageClient
    implements LessonImageClient, LessonImageResponseClient {
  const _FakePaidImageClient(this.dataUrl);

  final String dataUrl;

  @override
  Future<String?> generateLessonImage({
    required String prompt,
    required String lessonKey,
    String aspectRatio = '1:1',
    String? acceptedOfferId,
    String? idempotencyKey,
    Map<String, dynamic>? visualTrigger,
    Map<String, dynamic>? lessonContext,
  }) async {
    return dataUrl;
  }

  @override
  Future<GenerateLessonImageResponse?> generateLessonImageResponse({
    required String prompt,
    required String lessonKey,
    String aspectRatio = '1:1',
    String? acceptedOfferId,
    String? idempotencyKey,
    Map<String, dynamic>? visualTrigger,
    Map<String, dynamic>? lessonContext,
  }) async {
    return GenerateLessonImageResponse(dataUrl: dataUrl);
  }
}

class _RecordingTransport implements SimHttpTransport {
  Uri? lastUri;
  Map<String, String>? lastHeaders;
  Object? lastBody;
  String jsonBody = '{}';

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
    return SimHttpResponse(statusCode: 200, body: jsonBody);
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
