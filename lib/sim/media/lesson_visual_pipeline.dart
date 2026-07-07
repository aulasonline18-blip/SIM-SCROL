import 'package:flutter/foundation.dart';

import 'lesson_image_api_contract.dart';
import 'lesson_visual_models.dart';

export 'lesson_visual_models.dart'
    show
        ServerVisualRouteResult,
        ServerVisualRouteVerdict,
        LessonVisualRouterClient;

abstract interface class LessonImageClient {
  Future<String?> generateLessonImage({
    required String prompt,
    required String lessonKey,
    String aspectRatio = '1:1',
    String? acceptedOfferId,
    String? idempotencyKey,
    Map<String, dynamic>? visualTrigger,
    Map<String, dynamic>? lessonContext,
  });
}

abstract interface class LessonImageResponseClient {
  Future<GenerateLessonImageResponse?> generateLessonImageResponse({
    required String prompt,
    required String lessonKey,
    String aspectRatio = '1:1',
    String? acceptedOfferId,
    String? idempotencyKey,
    Map<String, dynamic>? visualTrigger,
    Map<String, dynamic>? lessonContext,
  });
}

/// Modelo mínimo do visual_trigger do T02. O app só carrega e repassa a ficha.
class LessonVisualTrigger {
  const LessonVisualTrigger({
    this.needsImage = false,
    this.pedagogicalNeed,
    this.topic,
    this.visualType,
    this.keyElements = const [],
    this.colorLegend = const [],
    this.highlightFocus,
    this.complexity,
    this.imagePrompt,
    this.mathTemplate,
    this.renderStrategy,
    this.svgPayload,
    this.aspectRatio,
  });

  final bool needsImage;
  final String?
  pedagogicalNeed; // "none" | "helpful" | "important" | "essential"
  final String? topic;
  final String? visualType;
  final List<String> keyElements;
  final List<Object?> colorLegend;
  final String? highlightFocus;
  final String? complexity; // "simple" | "moderate" | "technical"
  final String? imagePrompt;
  final Object? mathTemplate;
  final String? renderStrategy; // "software" | "ai"
  final String? svgPayload;
  final String? aspectRatio;

  factory LessonVisualTrigger.fromJson(Object? value) {
    if (value is! Map) return const LessonVisualTrigger();
    final needs = value['needs_image'] == true || value['needsImage'] == true;
    return LessonVisualTrigger(
      needsImage: needs,
      pedagogicalNeed: value['pedagogical_need']?.toString(),
      topic: value['topic']?.toString(),
      visualType: value['visual_type']?.toString(),
      keyElements: _parseStringList(value['key_elements']),
      colorLegend: _parseObjectList(value['color_legend']),
      highlightFocus: value['highlight_focus']?.toString(),
      complexity: value['complexity']?.toString(),
      imagePrompt:
          value['image_prompt']?.toString() ??
          value['teacher_prompt']?.toString() ??
          value['teacherPrompt']?.toString() ??
          value['prompt']?.toString(),
      mathTemplate: value['math_template'],
      renderStrategy:
          value['render_strategy']?.toString() ??
          value['renderStrategy']?.toString(),
      svgPayload: value['svg_payload']?.toString(),
      aspectRatio:
          value['aspect_ratio']?.toString() ??
          value['aspectRatio']?.toString() ??
          value['image_aspect_ratio']?.toString(),
    );
  }

  Map<String, dynamic> toVisualTriggerMap() => {
    'needs_image': needsImage,
    if (pedagogicalNeed != null) 'pedagogical_need': pedagogicalNeed,
    if (topic != null) 'topic': topic,
    if (visualType != null) 'visual_type': visualType,
    if (keyElements.isNotEmpty) 'key_elements': keyElements,
    if (colorLegend.isNotEmpty)
      'color_legend': colorLegend.where((c) => c != null).toList(),
    if (highlightFocus != null) 'highlight_focus': highlightFocus,
    if (complexity != null) 'complexity': complexity,
    if (imagePrompt != null) 'image_prompt': imagePrompt,
    if (mathTemplate != null) 'math_template': mathTemplate,
    if (renderStrategy != null) 'render_strategy': renderStrategy,
    if (svgPayload != null) 'svg_payload': svgPayload,
    if (aspectRatio != null) 'aspect_ratio': aspectRatio,
  };

  LessonVisualTrigger copyWith({
    bool? needsImage,
    String? pedagogicalNeed,
    String? topic,
    String? visualType,
    List<String>? keyElements,
    List<Object?>? colorLegend,
    String? highlightFocus,
    String? complexity,
    String? imagePrompt,
    Object? mathTemplate,
    String? renderStrategy,
    String? svgPayload,
    String? aspectRatio,
  }) {
    return LessonVisualTrigger(
      needsImage: needsImage ?? this.needsImage,
      pedagogicalNeed: pedagogicalNeed ?? this.pedagogicalNeed,
      topic: topic ?? this.topic,
      visualType: visualType ?? this.visualType,
      keyElements: keyElements ?? this.keyElements,
      colorLegend: colorLegend ?? this.colorLegend,
      highlightFocus: highlightFocus ?? this.highlightFocus,
      complexity: complexity ?? this.complexity,
      imagePrompt: imagePrompt ?? this.imagePrompt,
      mathTemplate: mathTemplate ?? this.mathTemplate,
      renderStrategy: renderStrategy ?? this.renderStrategy,
      svgPayload: svgPayload ?? this.svgPayload,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }
}

List<String> _parseStringList(Object? v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return const [];
}

List<Object?> _parseObjectList(Object? v) {
  if (v is List) return v;
  return const [];
}

class LessonVisualPipeline {
  LessonVisualPipeline({
    required this.imageClient,
    required this.visualRouterClient,
  });

  final LessonImageClient imageClient;
  final LessonVisualRouterClient visualRouterClient;

  /// Ponto de entrada principal: o app só encaminha o visual_trigger ao
  /// servidor e recebe foto raster pronta. Desenho, decisão, SVG e
  /// oferta visual pertencem ao servidor.
  Future<LessonVisualResult> resolveVisual({
    required LessonVisualTrigger trigger,
    required String lessonKey,
    String? stableLang,
    String? academicLevel,
    bool allowPaidImages = false,
    String? acceptedOfferId,
    String? idempotencyKey,
  }) async {
    if (!trigger.needsImage || trigger.pedagogicalNeed == 'none') {
      _visualLog(
        lessonKey,
        'skip',
        'needsImage=${trigger.needsImage} pedagogicalNeed=${trigger.pedagogicalNeed}',
      );
      return const LessonVisualResult(svg: null, dataUrl: null, source: 'skip');
    }

    return _resolveServerOnlyVisual(
      trigger: trigger,
      lessonKey: lessonKey,
      stableLang: stableLang,
      academicLevel: academicLevel,
    );
  }

  Future<LessonVisualResult> _resolveServerOnlyVisual({
    required LessonVisualTrigger trigger,
    required String lessonKey,
    required String? stableLang,
    required String? academicLevel,
  }) async {
    final ServerVisualRouteResult serverImage;
    try {
      serverImage = await visualRouterClient.routeVisual(
        stableLang: stableLang,
        visualTrigger: trigger.toVisualTriggerMap(),
      );
    } catch (error) {
      final reason =
          'SERVER_IMAGE_TRANSPORT_FAILED: ${_shortVisualText(error)}';
      _visualLog(lessonKey, 'server_photo', reason);
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'server_failed',
        routeReason: reason,
      );
    }
    _visualLog(
      lessonKey,
      'server_photo',
      'verdict=${serverImage.verdict.name} reason=${_shortVisualText(serverImage.reason)} hasRaster=${serverImage.readyImageDataUrl != null}',
    );
    if (serverImage.transportFailed) {
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'server_failed',
        routeReason: serverImage.reason,
      );
    }
    if (serverImage.verdict == ServerVisualRouteVerdict.noImage) {
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'server_no_image',
        routeReason: serverImage.reason,
      );
    }
    if (serverImage.readyImageDataUrl != null) {
      return LessonVisualResult(
        svg: null,
        dataUrl: serverImage.readyImageDataUrl,
        source: 'server_raster',
        routeReason: serverImage.reason,
      );
    }
    return LessonVisualResult(
      svg: null,
      dataUrl: null,
      source: 'server_missing_raster',
      routeReason: serverImage.reason,
    );
  }
}

void _visualLog(String lessonKey, String stage, String detail) {
  if (kDebugMode) {
    debugPrint('[VISUAL_PIPELINE] key=$lessonKey stage=$stage $detail');
  }
}

String _shortVisualText(Object? value) {
  final text = (value ?? '').toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= 160) return text;
  return text.substring(0, 160);
}

class LessonVisualResult {
  const LessonVisualResult({
    required this.svg,
    required this.dataUrl,
    required this.source,
    this.routeReason,
    this.imageMetadata,
  });

  /// Mantido só para compatibilidade de tipo. O fluxo ativo do app não preenche SVG.
  final String? svg;

  /// data URL de imagem raster pronta recebida do servidor.
  final String? dataUrl;

  /// Fonte do resultado (para diagnóstico/auditoria).
  final String source;
  final String? routeReason;
  final LessonImageGenerationMetadata? imageMetadata;

  /// Imagem útil disponível. No fluxo ativo, só raster pronto é aceito.
  bool get hasImage => dataUrl != null;

  /// data URL para exibição.
  String? get displayUrl => dataUrl;
}
