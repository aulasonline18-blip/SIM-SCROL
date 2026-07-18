import 'dart:async';
import 'dart:convert';

import '../external_ai/sim_ai_server_config.dart';
import '../external_ai/sim_http_transport.dart';
import '../state/student_learning_state.dart';
import 'math_templates/math_visual_templates.dart';

const String simVisualRoutePath = '/api/visual-route';

class LessonVisualTrigger {
  const LessonVisualTrigger({
    required this.needsImage,
    this.kind,
    this.svg,
    this.mathTemplate,
    this.description,
    this.reason,
    this.raw = const {},
  });

  final bool needsImage;
  final String? kind;
  final String? svg;
  final String? mathTemplate;
  final String? description;
  final String? reason;
  final JsonMap raw;

  static LessonVisualTrigger? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = JsonMap.from(value);
    final needs = _bool(json['needs_image'] ?? json['needsImage']);
    final kind = _text(json['visual_type'] ?? json['type'] ?? json['kind']);
    return LessonVisualTrigger(
      needsImage: needs ?? kind != 'no_image',
      kind: kind,
      svg: _text(json['svg'] ?? json['svg_code'] ?? json['inline_svg']),
      mathTemplate: _text(
        json['math_template'] ?? json['mathTemplate'] ?? json['template'],
      ),
      description: _text(
        json['description'] ?? json['visual_description'] ?? json['prompt'],
      ),
      reason: _text(json['reason'] ?? json['motivo']),
      raw: json,
    );
  }
}

enum VisualRouteN2Kind { noImage, svg, mathTemplate, n3 }

class VisualRouteN2Decision {
  const VisualRouteN2Decision(this.kind, this.reason);

  final VisualRouteN2Kind kind;
  final String reason;
}

class VisualRouterN2 {
  const VisualRouterN2();

  VisualRouteN2Decision classify(LessonVisualTrigger? trigger) {
    if (trigger == null || !trigger.needsImage) {
      return const VisualRouteN2Decision(
        VisualRouteN2Kind.noImage,
        'visual_trigger_sem_imagem',
      );
    }
    if (isSafeInlineSvg(trigger.svg)) {
      return const VisualRouteN2Decision(
        VisualRouteN2Kind.svg,
        'svg_pronto_seguro',
      );
    }
    if (mathVisualTemplateSvg(trigger.mathTemplate) != null) {
      return const VisualRouteN2Decision(
        VisualRouteN2Kind.mathTemplate,
        'template_matematico_local',
      );
    }
    return const VisualRouteN2Decision(
      VisualRouteN2Kind.n3,
      'descricao_visual_para_n3',
    );
  }
}

bool isSafeInlineSvg(String? raw) {
  final svg = raw?.trim();
  if (svg == null || svg.isEmpty || svg.length > 24000) return false;
  final lower = svg.toLowerCase();
  if (!lower.startsWith('<svg') || !lower.contains('</svg>')) return false;
  if (RegExp(
    r'<script|foreignobject|javascript:|<iframe|<object|<embed|https?://|\son[a-z]+\s*=',
    caseSensitive: false,
  ).hasMatch(svg)) {
    return false;
  }
  return true;
}

class VisualRouterN3Request {
  const VisualRouterN3Request({
    required this.visualTrigger,
    required this.lessonLocalId,
    required this.itemMarker,
    required this.itemIdx,
    required this.layer,
    required this.requestId,
    required this.idioma,
  });

  final JsonMap visualTrigger;
  final String lessonLocalId;
  final String? itemMarker;
  final int? itemIdx;
  final LessonLayer layer;
  final String requestId;
  final String idioma;

  JsonMap toJson() => {
    'visual_trigger': visualTrigger,
    'lessonLocalId': lessonLocalId,
    if (itemMarker != null) 'itemMarker': itemMarker,
    if (itemMarker != null) 'itemId': itemMarker,
    if (itemIdx != null) 'itemIdx': itemIdx,
    'layer': layer.value,
    'requestId': requestId,
    'idioma': idioma,
  };
}

class VisualRouterN3Result {
  const VisualRouterN3Result({
    required this.status,
    this.dataUrl,
    this.displayDataUrl,
    this.mimeType,
    this.rasterized,
    this.reason,
    this.requestId,
  });

  final String status;
  final String? dataUrl;
  final String? displayDataUrl;
  final String? mimeType;
  final bool? rasterized;
  final String? reason;
  final String? requestId;
  String? get imageData => displayDataUrl ?? dataUrl;

  factory VisualRouterN3Result.fromJson(Object? raw) {
    if (raw is! Map) return const VisualRouterN3Result(status: 'failed');
    final json = JsonMap.from(raw);
    final data = _text(
      json['dataUrl'] ??
          json['data_url'] ??
          json['displayDataUrl'] ??
          json['display_data_url'] ??
          json['svg'],
    );
    return VisualRouterN3Result(
      status: _text(json['status']) ?? (data == null ? 'failed' : 'ready'),
      dataUrl: _text(json['dataUrl'] ?? json['data_url'] ?? json['svg']),
      displayDataUrl: _text(json['displayDataUrl'] ?? json['display_data_url']),
      mimeType: _text(json['mimeType'] ?? json['mime_type']),
      rasterized: json['rasterized'] is bool
          ? json['rasterized'] as bool
          : null,
      reason: _text(json['reason'] ?? json['n3Reason'] ?? json['error']),
      requestId: _text(json['requestId'] ?? json['request_id']),
    );
  }
}

class VisualRouterN3Client {
  VisualRouterN3Client({
    required this.config,
    SimHttpTransport? transport,
    this.timeout = const Duration(seconds: 35),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final Duration timeout;

  Future<VisualRouterN3Result> route(VisualRouterN3Request request) async {
    try {
      final response = await transport.postJson(
        config.uri(simVisualRoutePath),
        headers: await config.jsonHeaders(),
        body: request.toJson(),
        timeout: timeout,
      );
      if (!response.ok) {
        return VisualRouterN3Result(
          status: 'failed',
          reason: 'VISUAL_ROUTE_UNAVAILABLE',
          requestId: request.requestId,
        );
      }
      final result = VisualRouterN3Result.fromJson(jsonDecode(response.body));
      final image = result.imageData;
      if (image != null &&
          (isSafeInlineSvg(image) || image.startsWith('data:image/'))) {
        return result;
      }
      return VisualRouterN3Result(
        status: result.status == 'ready' ? 'failed' : result.status,
        reason: result.reason ?? 'VISUAL_ROUTE_INVALID_IMAGE',
        requestId: result.requestId ?? request.requestId,
      );
    } on Object {
      return VisualRouterN3Result(
        status: 'failed',
        reason: 'VISUAL_ROUTE_UNAVAILABLE',
        requestId: request.requestId,
      );
    }
  }
}

class S12VisualRequest {
  const S12VisualRequest({
    required this.trigger,
    required this.lessonLocalId,
    required this.marker,
    required this.itemIdx,
    required this.layer,
    required this.idioma,
  });

  final LessonVisualTrigger? trigger;
  final String lessonLocalId;
  final String? marker;
  final int? itemIdx;
  final LessonLayer layer;
  final String idioma;
}

class S12VisualResult {
  const S12VisualResult({
    required this.status,
    required this.n2Reason,
    this.imageData,
    this.mimeType,
    this.rasterized,
    this.n3Reason,
    this.requestId,
  });

  final String status;
  final String n2Reason;
  final String? imageData;
  final String? mimeType;
  final bool? rasterized;
  final String? n3Reason;
  final String? requestId;
  bool get isReady => imageData != null && imageData!.trim().isNotEmpty;
  bool get shouldCallN3 => status == 'processing';
}

class S12VisualPipeline {
  const S12VisualPipeline({this.n2 = const VisualRouterN2(), this.n3Client});

  final VisualRouterN2 n2;
  final VisualRouterN3Client? n3Client;

  S12VisualResult resolveLocal(S12VisualRequest request) {
    final decision = n2.classify(request.trigger);
    final trigger = request.trigger;
    switch (decision.kind) {
      case VisualRouteN2Kind.noImage:
        return S12VisualResult(status: 'no_image', n2Reason: decision.reason);
      case VisualRouteN2Kind.svg:
        return S12VisualResult(
          status: 'ready',
          n2Reason: decision.reason,
          imageData: trigger?.svg?.trim(),
          mimeType: 'image/svg+xml',
          rasterized: false,
        );
      case VisualRouteN2Kind.mathTemplate:
        return S12VisualResult(
          status: 'ready',
          n2Reason: decision.reason,
          imageData: mathVisualTemplateSvg(trigger?.mathTemplate),
          mimeType: 'image/svg+xml',
          rasterized: false,
        );
      case VisualRouteN2Kind.n3:
        return S12VisualResult(
          status: n3Client == null ? 'failed' : 'processing',
          n2Reason: decision.reason,
          n3Reason: n3Client == null ? 'VISUAL_ROUTE_CLIENT_UNAVAILABLE' : null,
          requestId: _requestIdFor(request),
        );
    }
  }

  Future<S12VisualResult> resolveN3(S12VisualRequest request) async {
    final client = n3Client;
    if (request.trigger == null || client == null) {
      return const S12VisualResult(
        status: 'failed',
        n2Reason: 'descricao_visual_para_n3',
        n3Reason: 'VISUAL_ROUTE_CLIENT_UNAVAILABLE',
      );
    }
    final requestId = _requestIdFor(request);
    final result = await client.route(
      VisualRouterN3Request(
        visualTrigger: request.trigger!.raw,
        lessonLocalId: request.lessonLocalId,
        itemMarker: request.marker,
        itemIdx: request.itemIdx,
        layer: request.layer,
        requestId: requestId,
        idioma: request.idioma,
      ),
    );
    final image = result.imageData;
    return S12VisualResult(
      status: image == null ? result.status : 'ready',
      n2Reason: 'descricao_visual_para_n3',
      imageData: image,
      mimeType: result.mimeType,
      rasterized: result.rasterized,
      n3Reason: result.reason,
      requestId: result.requestId ?? requestId,
    );
  }
}

bool? _bool(Object? value) {
  if (value is bool) return value;
  final text = _text(value)?.toLowerCase();
  if (text == 'true' || text == '1' || text == 'yes') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;
  return null;
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String _requestIdFor(S12VisualRequest request) {
  final basis = [
    request.lessonLocalId,
    request.marker ?? '',
    request.itemIdx ?? '',
    request.layer.value,
    request.trigger?.description ?? request.trigger?.mathTemplate ?? '',
  ].join('|');
  var hash = 5381;
  for (final unit in basis.codeUnits) {
    hash = ((hash << 5) + hash) ^ unit;
  }
  return 'sim-n3-${(hash & 0xffffffff).toRadixString(36)}';
}
