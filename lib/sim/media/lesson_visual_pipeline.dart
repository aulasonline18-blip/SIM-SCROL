// LessonVisualPipeline — funil de imagem do SIM App.
// Espelha o comportamento vivo do SimWeb; o provedor pago final é próprio da API do app.
import 'package:flutter/foundation.dart';

import 'blueprint_prompt.dart';
import 'image_pedagogical_critic.dart';
import 'lesson_image_api_contract.dart';
import 'lesson_visual_models.dart';
import 'software_render_catalog.dart';
import 'visual_router_n2.dart';
import 'visual_router_n3.dart';
import 'visual_funnel_telemetry.dart';
import 'visual_escalation_policy.dart';
import 'visual_final_quality_evaluator.dart';
import 'image_data_url_compression.dart';

export 's12_visual_pipeline.dart'
    show
        sanitizeAndEncodeSvg,
        decideVisualGeneration,
        VisualDecision,
        VisualDecisionContext;
export 'visual_router_n2.dart'
    show classifyVisualByKeywords, VisualVerdict, VisualN2Result;
export 'visual_router_n3.dart'
    show routeVisualCheapN3, VisualN3Result, LessonVisualRouterClient;
export 'visual_pedagogical_role.dart'
    show
        VisualPedagogicalRole,
        VisualPedagogicalRoleId,
        inferVisualPedagogicalRole;
export 'image_pedagogical_critic.dart'
    show ImagePedagogicalCritic, ImagePedagogicalCritique;
export 'visual_funnel_telemetry.dart'
    show VisualFunnelTelemetry, VisualFunnelEvent, VisualFunnelSnapshot;
export 'visual_final_quality_evaluator.dart'
    show
        VisualFinalQualityEvaluator,
        VisualFinalQualityResult,
        VisualFinalQualityAction;

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

/// Modelo completo do visual_trigger do T02 (todos os campos do contrato).
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
  final List<BlueprintColorLegendItem> colorLegend;
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
      colorLegend: colorLegendFromJson(value['color_legend']),
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
      'color_legend': colorLegend
          .map((c) => {'id': c.id, 'label': c.label, 'color': c.color})
          .toList(),
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
    List<BlueprintColorLegendItem>? colorLegend,
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

class LessonVisualPipeline {
  LessonVisualPipeline({
    required this.imageClient,
    required this.visualRouterClient,
    ImagePedagogicalCritic? imageCritic,
    VisualFinalQualityEvaluator? finalQualityEvaluator,
    SoftwareRenderCatalog? softwareRenderCatalog,
    this.telemetry,
    VisualEscalationPolicy? escalationPolicy,
  });

  final LessonImageClient imageClient;
  final LessonVisualRouterClient visualRouterClient;
  final VisualFunnelTelemetry? telemetry;

  /// Ponto de entrada principal: o app só encaminha o visual_trigger ao
  /// servidor e recebe foto raster pronta. Desenho, decisão, SVG, N2/N3 e
  /// oferta paga pertencem ao servidor.
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
      _recordOutcome(lessonKey, 'no_image', 'skip');
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
    final VisualN3Result serverImage;
    try {
      serverImage = await visualRouterClient.routeVisual(
        n2: const VisualN2Result(
          verdict: VisualVerdict.ambiguous,
          matched: ['server_ready_image'],
          reason: 'SERVER_READY_IMAGE_REQUEST',
          confidence: 1,
        ),
        topic: trigger.topic,
        visualType: trigger.visualType,
        imagePrompt: trigger.imagePrompt,
        keyElements: trigger.keyElements,
        pedagogicalNeed: trigger.pedagogicalNeed,
        highlightFocus: trigger.highlightFocus,
        complexity: trigger.complexity,
        stableLang: stableLang,
        svgPayload: trigger.svgPayload,
        mathTemplate: trigger.mathTemplate,
        visualTrigger: trigger.toVisualTriggerMap(),
      );
    } catch (error) {
      final reason =
          'SERVER_IMAGE_TRANSPORT_FAILED: ${_shortVisualText(error)}';
      _visualLog(lessonKey, 'server_photo', reason);
      _recordOutcome(lessonKey, 'failed', 'server_failed', reason);
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'server_failed',
        n2Reason: reason,
      );
    }
    _visualLog(
      lessonKey,
      'server_photo',
      'verdict=${serverImage.verdict.name} reason=${_shortVisualText(serverImage.reason)} hasRaster=${serverImage.displayDataUrl != null}',
    );
    if (serverImage.transportFailed) {
      _recordOutcome(lessonKey, 'failed', 'server_failed', serverImage.reason);
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'server_failed',
        n2Reason: serverImage.reason,
      );
    }
    if (serverImage.verdict == VisualVerdict.noImage) {
      _recordOutcome(
        lessonKey,
        'no_image',
        'server_no_image',
        serverImage.reason,
      );
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'server_no_image',
        n2Reason: serverImage.reason,
      );
    }
    if (serverImage.displayDataUrl != null) {
      _recordOutcome(
        lessonKey,
        'software',
        'server_raster',
        serverImage.reason,
      );
      return LessonVisualResult(
        svg: null,
        dataUrl: serverImage.displayDataUrl,
        source: 'server_raster',
        n2Reason: serverImage.reason,
      );
    }
    _recordOutcome(
      lessonKey,
      'failed',
      'server_missing_raster',
      serverImage.reason,
    );
    return LessonVisualResult(
      svg: null,
      dataUrl: null,
      source: 'server_missing_raster',
      n2Reason: serverImage.reason,
    );
  }

  void _recordOutcome(
    String lessonKey,
    String outcome,
    String source, [
    String? n2Reason,
    String? detail,
  ]) {
    telemetry?.record(
      VisualFunnelEvent(
        lessonKey: lessonKey,
        outcome: outcome,
        source: source,
        n2Reason: n2Reason,
        detail: detail,
      ),
    );
  }

  Future<GenerateLessonImageResponse?> fetchPaidLessonImageResponse(
    String prompt,
    String lessonKey, {
    String aspectRatio = '1:1',
    String? acceptedOfferId,
    String? idempotencyKey,
    Map<String, dynamic>? visualTrigger,
    Map<String, dynamic>? lessonContext,
  }) async {
    if (prompt.trim().isEmpty) return null;
    if (acceptedOfferId == null || acceptedOfferId.trim().isEmpty) return null;
    final normalizedAspectRatio = normalizedLessonImageAspectRatio(aspectRatio);
    final client = imageClient;
    if (client is LessonImageResponseClient) {
      final responseClient = client as LessonImageResponseClient;
      final response = await responseClient.generateLessonImageResponse(
        prompt: prompt,
        lessonKey: lessonKey,
        aspectRatio: normalizedAspectRatio,
        acceptedOfferId: acceptedOfferId,
        idempotencyKey: idempotencyKey ?? acceptedOfferId,
        visualTrigger: visualTrigger,
        lessonContext: lessonContext,
      );
      if (response == null || !isUsableImageDataUrl(response.dataUrl)) {
        return null;
      }
      return GenerateLessonImageResponse(
        dataUrl: compressImageDataUrl(response.dataUrl),
        cacheKey: response.cacheKey,
        requestId: response.requestId,
        mimeType: response.mimeType,
        provider: response.provider,
        model: response.model,
        charged: response.charged,
        cacheHit: response.cacheHit,
        retryable: response.retryable,
      );
    }
    final dataUrl = await client.generateLessonImage(
      prompt: prompt,
      lessonKey: lessonKey,
      aspectRatio: normalizedAspectRatio,
      acceptedOfferId: acceptedOfferId,
      idempotencyKey: idempotencyKey ?? acceptedOfferId,
      visualTrigger: visualTrigger,
      lessonContext: lessonContext,
    );
    if (!isUsableImageDataUrl(dataUrl)) return null;
    return GenerateLessonImageResponse(dataUrl: compressImageDataUrl(dataUrl!));
  }

  Future<String?> fetchPaidLessonImage(
    String prompt,
    String lessonKey, {
    String aspectRatio = '1:1',
    String? acceptedOfferId,
    String? idempotencyKey,
    Map<String, dynamic>? visualTrigger,
    Map<String, dynamic>? lessonContext,
  }) async {
    final response = await fetchPaidLessonImageResponse(
      prompt,
      lessonKey,
      aspectRatio: aspectRatio,
      acceptedOfferId: acceptedOfferId,
      idempotencyKey: idempotencyKey,
      visualTrigger: visualTrigger,
      lessonContext: lessonContext,
    );
    return response?.dataUrl;
  }

  String buildPromptForTrigger({
    required String topic,
    required LessonVisualTrigger trigger,
    String? lang,
  }) {
    final teacherPrompt = trigger.imagePrompt ?? '';
    if (trigger.colorLegend.length >= 2) {
      return buildNaturalImagePrompt(
        topic: topic,
        teacherPrompt: teacherPrompt,
        lang: lang,
        colorLegend: trigger.colorLegend,
      );
    }
    return buildNaturalImagePrompt(
      topic: topic,
      teacherPrompt: teacherPrompt,
      lang: lang,
    );
  }
}

String normalizedLessonImageAspectRatio(Object? value) {
  final ratio = value?.toString().trim();
  const allowed = {'1:1', '16:9', '9:16', '4:3', '3:4'};
  return ratio != null && allowed.contains(ratio) ? ratio : '1:1';
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
    this.n2Reason,
    this.imageMetadata,
    this.paidOfferPrompt,
  });

  /// data URL de SVG inline (grátis) — usar se não nulo.
  final String? svg;

  /// data URL de imagem raster pronta (servidor/Blueprint pago) — usar primeiro.
  final String? dataUrl;

  /// Fonte do resultado (para diagnóstico/auditoria).
  final String source;
  final String? n2Reason;
  final LessonImageGenerationMetadata? imageMetadata;
  final String? paidOfferPrompt;

  /// Imagem útil disponível (raster ou SVG)
  bool get hasImage => svg != null || dataUrl != null;

  /// data URL para exibição (prefere raster pronto)
  String? get displayUrl => dataUrl ?? svg;
}
