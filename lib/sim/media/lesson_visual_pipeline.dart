import 'package:flutter/foundation.dart';

import '../billing/sim_pricing.dart';
import 'blueprint_prompt.dart';
import 'image_pedagogical_critic.dart';
import 'lesson_image_api_contract.dart';
import 'lesson_visual_models.dart';
import 'math_templates/math_templates.dart';
import 's12_visual_pipeline.dart' as s12;
import 'software_render_catalog.dart';
import 'visual_escalation_policy.dart';
import 'visual_final_quality_evaluator.dart';
import 'visual_funnel_telemetry.dart';
import 'visual_router_n2.dart';

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
    this.lessonLocalId,
    this.marker,
    this.itemIdx,
    this.layer,
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
  final String? lessonLocalId;
  final String? marker;
  final int? itemIdx;
  final int? layer;

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
      lessonLocalId: value['lessonLocalId']?.toString(),
      marker: value['marker']?.toString(),
      itemIdx: value['itemIdx'] is num
          ? (value['itemIdx'] as num).toInt()
          : null,
      layer: value['layer'] is num ? (value['layer'] as num).toInt() : null,
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
    if (lessonLocalId != null) 'lessonLocalId': lessonLocalId,
    if (marker != null) 'marker': marker,
    if (itemIdx != null) 'itemIdx': itemIdx,
    if (layer != null) 'layer': layer,
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
    String? lessonLocalId,
    String? marker,
    int? itemIdx,
    int? layer,
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
      lessonLocalId: lessonLocalId ?? this.lessonLocalId,
      marker: marker ?? this.marker,
      itemIdx: itemIdx ?? this.itemIdx,
      layer: layer ?? this.layer,
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
    ImagePedagogicalCritic? imageCritic,
    VisualFinalQualityEvaluator? finalQualityEvaluator,
    SoftwareRenderCatalog? softwareRenderCatalog,
    VisualEscalationPolicy? escalationPolicy,
    this.telemetry,
  }) : imageCritic = imageCritic ?? const ImagePedagogicalCritic(),
       finalQualityEvaluator =
           finalQualityEvaluator ?? VisualFinalQualityEvaluator.standard,
       softwareRenderCatalog =
           softwareRenderCatalog ?? const SoftwareRenderCatalog(),
       escalationPolicy = escalationPolicy ?? VisualEscalationPolicy.standard;

  final LessonImageClient imageClient;
  final LessonVisualRouterClient visualRouterClient;
  final ImagePedagogicalCritic imageCritic;
  final VisualFinalQualityEvaluator finalQualityEvaluator;
  final SoftwareRenderCatalog softwareRenderCatalog;
  final VisualEscalationPolicy escalationPolicy;
  final VisualFunnelTelemetry? telemetry;

  /// Ponto de entrada principal: servidor primeiro; fallback local barato
  /// somente quando o servidor não entrega imagem útil.
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

    final server = await _resolveServerVisual(
      trigger: trigger,
      lessonKey: lessonKey,
      stableLang: stableLang,
      academicLevel: academicLevel,
    );
    if (server.hasImage || server.source == 'server_no_image') {
      return server;
    }
    return _resolveLocalFallbackVisual(
      trigger: trigger,
      lessonKey: lessonKey,
      stableLang: stableLang,
      academicLevel: academicLevel,
      allowPaidImages: allowPaidImages,
      acceptedOfferId: acceptedOfferId,
      idempotencyKey: idempotencyKey,
      serverReason: server.routeReason,
    );
  }

  Future<LessonVisualResult> _resolveServerVisual({
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

  Future<LessonVisualResult> _resolveLocalFallbackVisual({
    required LessonVisualTrigger trigger,
    required String lessonKey,
    required String? stableLang,
    required String? academicLevel,
    required bool allowPaidImages,
    required String? acceptedOfferId,
    required String? idempotencyKey,
    required String? serverReason,
  }) async {
    if (trigger.renderStrategy == 'software' && trigger.svgPayload != null) {
      final svg = s12.sanitizeAndEncodeSvg(trigger.svgPayload);
      final request = _softwareRequestFromTrigger(
        trigger,
        n2: const VisualN2Result(
          verdict: VisualVerdict.svg,
          matched: ['svg_payload'],
          reason: 'S12_SVG_INLINE',
        ),
        academicLevel: academicLevel,
      );
      if (svg != null &&
          _acceptFinalSoftwareSvg(lessonKey, 'svg_inline', svg, request)) {
        _recordOutcome(lessonKey, 'software', 'svg_inline');
        return LessonVisualResult(
          svg: svg,
          dataUrl: null,
          source: 'svg_inline',
          routeReason: serverReason,
          imageMetadata: _metadata(
            source: 'svg_inline',
            provider: 'flutter_software',
          ),
        );
      }
      _visualLog(lessonKey, 'svg_inline', 'rejected_or_invalid');
    }

    final math = tryRenderMathTemplate(trigger.toVisualTriggerMap());
    if (math != null) {
      final request = _softwareRequestFromTrigger(
        trigger,
        n2: const VisualN2Result(
          verdict: VisualVerdict.svg,
          matched: ['math_template'],
          reason: 'MATH_TEMPLATE',
        ),
        academicLevel: academicLevel,
      );
      if (_acceptFinalSoftwareSvg(lessonKey, 'math_template', math, request)) {
        _recordOutcome(lessonKey, 'software', 'math_template');
        return LessonVisualResult(
          svg: math,
          dataUrl: null,
          source: 'math_template',
          routeReason: serverReason,
          imageMetadata: _metadata(
            source: 'math_template',
            provider: 'flutter_math_template',
          ),
        );
      }
    }

    final n2 = classifyVisualByKeywords(
      topic: trigger.topic,
      visualType: trigger.visualType,
      imagePrompt: trigger.imagePrompt,
    );
    _visualLog(
      lessonKey,
      'n2',
      'verdict=${n2.verdict.name} reason=${n2.reason} matched=${n2.matched.take(8).join('|')}',
    );
    if (n2.verdict == VisualVerdict.noImage) {
      _recordOutcome(lessonKey, 'no_image', 'n2_no_image', n2.reason);
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'n2_no_image',
        routeReason: n2.reason,
        n2Reason: n2.reason,
      );
    }

    final softwareRequest = _softwareRequestFromTrigger(
      trigger,
      n2: n2,
      academicLevel: academicLevel,
    );
    if (n2.verdict == VisualVerdict.ai) {
      _recordOutcome(lessonKey, 'paid_gate', 'n2_ai', n2.reason);
      return _resolvePaidVisualGate(
        trigger: trigger,
        lessonKey: lessonKey,
        stableLang: stableLang,
        academicLevel: academicLevel,
        allowPaidImages: allowPaidImages,
        acceptedOfferId: acceptedOfferId,
        idempotencyKey: idempotencyKey,
        serverReason: serverReason,
        n2Reason: n2.reason,
      );
    }
    if (n2.verdict == VisualVerdict.ambiguous &&
        _requestsConcreteRasterVisual(trigger)) {
      _recordOutcome(lessonKey, 'paid_gate', 'n2_ambiguous_raster', n2.reason);
      return _resolvePaidVisualGate(
        trigger: trigger,
        lessonKey: lessonKey,
        stableLang: stableLang,
        academicLevel: academicLevel,
        allowPaidImages: allowPaidImages,
        acceptedOfferId: acceptedOfferId,
        idempotencyKey: idempotencyKey,
        serverReason: serverReason,
        n2Reason: n2.reason,
      );
    }

    final localSoftware = softwareRenderCatalog.render(softwareRequest);
    var localAccepted = false;
    if (localSoftware != null) {
      localAccepted = _acceptFinalSoftwareSvg(
        lessonKey,
        'local_software:${localSoftware.renderer}',
        localSoftware.dataUrl,
        softwareRequest,
      );
      final decision = escalationPolicy.decide(
        request: softwareRequest,
        localResult: localSoftware,
        localAccepted: localAccepted,
      );
      if (decision.acceptLocalBeforeN3) {
        _recordOutcome(
          lessonKey,
          'software',
          'local_software',
          n2.reason,
          localSoftware.renderer,
        );
        return LessonVisualResult(
          svg: localSoftware.dataUrl,
          dataUrl: null,
          source: 'local_software',
          routeReason: serverReason,
          n2Reason: n2.reason,
          imageMetadata: _metadata(
            source: 'local_software',
            provider: localSoftware.renderer,
            n2Reason: n2.reason,
          ),
        );
      }
    }

    final escalationDecision = escalationPolicy.decide(
      request: softwareRequest,
      localResult: localSoftware,
      localAccepted: localAccepted,
    );
    if (escalationDecision.shouldCallN3) {
      final n3Result = await _routeCheapN3Equivalent(
        trigger: trigger,
        n2: n2,
        stableLang: stableLang,
      );
      if (n3Result != null) {
        _recordOutcome(lessonKey, 'software', 'n3_software', n2.reason);
        return LessonVisualResult(
          svg: null,
          dataUrl: n3Result.dataUrl,
          source: 'n3_software',
          routeReason: n3Result.reason,
          n2Reason: n2.reason,
          imageMetadata: _metadata(
            source: 'n3_software',
            provider: 'visual_route_n3',
            n2Reason: n2.reason,
            n3Reason: n3Result.reason,
            requestId: n3Result.requestId,
          ),
        );
      }
      if (localSoftware != null &&
          localAccepted &&
          escalationDecision.allowLocalAfterN3Failure) {
        _recordOutcome(
          lessonKey,
          'software',
          'local_software_after_n3',
          n2.reason,
          localSoftware.renderer,
        );
        return LessonVisualResult(
          svg: localSoftware.dataUrl,
          dataUrl: null,
          source: 'local_software',
          routeReason: serverReason,
          n2Reason: n2.reason,
          imageMetadata: _metadata(
            source: 'local_software',
            provider: localSoftware.renderer,
            n2Reason: n2.reason,
          ),
        );
      }
    }

    return _resolvePaidVisualGate(
      trigger: trigger,
      lessonKey: lessonKey,
      stableLang: stableLang,
      academicLevel: academicLevel,
      allowPaidImages: allowPaidImages,
      acceptedOfferId: acceptedOfferId,
      idempotencyKey: idempotencyKey,
      serverReason: serverReason,
      n2Reason: n2.reason,
    );
  }

  Future<LessonVisualResult> _resolvePaidVisualGate({
    required LessonVisualTrigger trigger,
    required String lessonKey,
    required String? stableLang,
    required String? academicLevel,
    required bool allowPaidImages,
    required String? acceptedOfferId,
    required String? idempotencyKey,
    required String? serverReason,
    required String? n2Reason,
  }) async {
    final paidPrompt = _paidPromptFor(trigger, stableLang: stableLang);
    if (paidPrompt == null) {
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'fallback_exhausted',
        routeReason: serverReason,
        n2Reason: n2Reason,
      );
    }
    if (!allowPaidImages ||
        acceptedOfferId == null ||
        acceptedOfferId.trim().isEmpty) {
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'paid_offer_required',
        routeReason: serverReason,
        n2Reason: n2Reason,
        paidOfferPrompt: paidPrompt,
        imageMetadata: _metadata(
          source: 'paid_offer_required',
          provider: 'offer_gate',
          n2Reason: n2Reason,
        ),
      );
    }

    final response = await _fetchPaidLessonImageResponse(
      prompt: paidPrompt,
      lessonKey: lessonKey,
      aspectRatio: _normalizedLessonImageAspectRatio(trigger.aspectRatio),
      acceptedOfferId: acceptedOfferId,
      idempotencyKey: idempotencyKey ?? acceptedOfferId,
      visualTrigger: trigger.toVisualTriggerMap(),
      lessonContext: {
        'stableLang': stableLang,
        'academicLevel': academicLevel,
        'source': 'sim_app_flutter_visual_fallback',
        'serverReason': serverReason,
      },
    );
    if (response == null) {
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'ai_failed',
        routeReason: serverReason,
        n2Reason: n2Reason,
      );
    }
    return LessonVisualResult(
      svg: null,
      dataUrl: response.dataUrl,
      source: 'ai_blueprint',
      routeReason: serverReason,
      n2Reason: n2Reason,
      imageMetadata: response.toMetadata().withPaidImage(
        acceptedOfferId: acceptedOfferId,
        costCredits: simPricing.imageCostCredits,
      ),
    );
  }

  SoftwareVisualRequest _softwareRequestFromTrigger(
    LessonVisualTrigger trigger, {
    required VisualN2Result n2,
    required String? academicLevel,
  }) {
    return SoftwareVisualRequest(
      n2: n2,
      topic: trigger.topic,
      visualType: trigger.visualType,
      imagePrompt: trigger.imagePrompt,
      colorLegend: _typedColorLegend(trigger.colorLegend),
      keyElements: trigger.keyElements,
      highlightFocus: trigger.highlightFocus,
      complexity: trigger.complexity,
      pedagogicalNeed: trigger.pedagogicalNeed,
      academicLevel: academicLevel,
      pedagogicalGoal: trigger.highlightFocus,
    );
  }

  bool _acceptFinalSoftwareSvg(
    String lessonKey,
    String stage,
    String dataUrl,
    SoftwareVisualRequest request,
  ) {
    final critique = imageCritic.evaluateSvgDataUrl(dataUrl);
    _visualLog(
      lessonKey,
      'image_critic',
      'stage=$stage accepted=${critique.accepted} reason=${critique.reason} textNodes=${critique.textNodeCount} shapes=${critique.shapeCount}',
    );
    if (!critique.accepted) return false;
    final finalQuality = finalQualityEvaluator.evaluateSvg(
      dataUrl: dataUrl,
      request: request,
      critique: critique,
      source: stage,
    );
    _visualLog(
      lessonKey,
      'image_final_quality',
      'stage=$stage action=${finalQuality.action.name} reason=${finalQuality.reason}',
    );
    return finalQuality.accepted;
  }

  Future<_N3EquivalentResult?> _routeCheapN3Equivalent({
    required LessonVisualTrigger trigger,
    required VisualN2Result n2,
    required String? stableLang,
  }) async {
    try {
      final route = await visualRouterClient.routeVisual(
        stableLang: stableLang,
        visualTrigger: {
          ...trigger.toVisualTriggerMap(),
          'n2_verdict': n2.verdict.name,
          'n2_reason': n2.reason,
          'n2_matched': n2.matched,
          'visual_route_stage': 'n3_cheap_equivalent',
        },
      );
      if (route.transportFailed) return null;
      if (route.readyImageDataUrl != null) {
        return _N3EquivalentResult(
          dataUrl: route.readyImageDataUrl,
          reason: route.reason,
          requestId: route.requestId,
        );
      }
      return null;
    } catch (error) {
      _visualLog('n3', 'transport_failed', _shortVisualText(error));
      return null;
    }
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

  LessonImageGenerationMetadata _metadata({
    required String source,
    String? provider,
    String? requestId,
    String? n2Reason,
    String? n3Reason,
  }) {
    return LessonImageGenerationMetadata(
      requestId: requestId,
      provider: provider,
      model: 'flutter_visual_engine',
      charged: false,
      cacheHit: false,
      retryable: false,
      source: source,
      createdAt: DateTime.now().toIso8601String(),
      n2Reason: n2Reason,
      n3Reason: n3Reason,
    );
  }

  Future<GenerateLessonImageResponse?> _fetchPaidLessonImageResponse({
    required String prompt,
    required String lessonKey,
    required String aspectRatio,
    required String acceptedOfferId,
    required String idempotencyKey,
    required Map<String, dynamic> visualTrigger,
    required Map<String, dynamic> lessonContext,
  }) async {
    if (prompt.trim().isEmpty || acceptedOfferId.trim().isEmpty) return null;
    final client = imageClient;
    if (client is LessonImageResponseClient) {
      final response = await (client as LessonImageResponseClient)
          .generateLessonImageResponse(
            prompt: prompt,
            lessonKey: lessonKey,
            aspectRatio: aspectRatio,
            acceptedOfferId: acceptedOfferId,
            idempotencyKey: idempotencyKey,
            visualTrigger: visualTrigger,
            lessonContext: lessonContext,
          );
      if (response == null || !_isUsableImageDataUrl(response.dataUrl)) {
        return null;
      }
      return response;
    }
    final dataUrl = await client.generateLessonImage(
      prompt: prompt,
      lessonKey: lessonKey,
      aspectRatio: aspectRatio,
      acceptedOfferId: acceptedOfferId,
      idempotencyKey: idempotencyKey,
      visualTrigger: visualTrigger,
      lessonContext: lessonContext,
    );
    if (!_isUsableImageDataUrl(dataUrl)) return null;
    return GenerateLessonImageResponse(
      dataUrl: dataUrl!,
      acceptedOfferId: acceptedOfferId,
      costCredits: simPricing.imageCostCredits,
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
    this.n2Reason,
    this.imageMetadata,
    this.paidOfferPrompt,
  });

  /// Mantido só para compatibilidade de tipo. O fluxo ativo do app não preenche SVG.
  final String? svg;

  /// data URL de imagem raster pronta recebida do servidor.
  final String? dataUrl;

  /// Fonte do resultado (para diagnóstico/auditoria).
  final String source;
  final String? routeReason;
  final String? n2Reason;
  final LessonImageGenerationMetadata? imageMetadata;
  final String? paidOfferPrompt;

  /// Imagem útil disponível.
  bool get hasImage => svg != null || dataUrl != null;

  /// data URL para exibição.
  String? get displayUrl => svg ?? dataUrl;
}

String? _paidPromptFor(LessonVisualTrigger trigger, {String? stableLang}) {
  final text = [
    trigger.visualType,
    trigger.topic,
    trigger.imagePrompt,
    trigger.highlightFocus,
  ].whereType<String>().join(' ').trim();
  if (text.isEmpty) return null;
  final lower = text.toLowerCase();
  if (!_containsAny(lower, const [
    'foto',
    'fotografia',
    'realista',
    'realistic',
    'anatomia',
    'histologia',
    'microscopia',
    'paisagem',
    'cena',
  ])) {
    return null;
  }
  final lang = stableLang == null ? '' : ' Idioma dos rótulos: $stableLang.';
  return 'Imagem didática realista, limpa e precisa para aula: $text.$lang Sem texto decorativo.';
}

bool _requestsConcreteRasterVisual(LessonVisualTrigger trigger) {
  final lower = [
    trigger.visualType,
    trigger.topic,
    trigger.imagePrompt,
    trigger.highlightFocus,
  ].whereType<String>().join(' ').toLowerCase();
  if (_containsAny(lower, const [
    'sem foto',
    'sem fotografia',
    'não foto',
    'nao foto',
    'no photo',
    'not photo',
    'sem realismo',
    'não realista',
    'nao realista',
    'not realistic',
  ])) {
    return false;
  }
  return _containsAny(lower, const [
    'foto',
    'fotografia',
    'photograph',
    'realista',
    'realistic',
    'photorealistic',
    'fotorrealista',
    'imagem real',
  ]);
}

bool _containsAny(String text, List<String> needles) =>
    needles.any((needle) => text.contains(needle));

bool _isUsableImageDataUrl(Object? value) {
  if (value is! String) return false;
  return RegExp(
    r'^data:image/(png|jpeg|jpg|webp);base64,',
    caseSensitive: false,
  ).hasMatch(value.trim());
}

String _normalizedLessonImageAspectRatio(Object? value) {
  final ratio = value?.toString().trim();
  const allowed = {'1:1', '16:9', '9:16', '4:3', '3:4'};
  return ratio != null && allowed.contains(ratio) ? ratio : '1:1';
}

List<BlueprintColorLegendItem> _typedColorLegend(List<Object?> raw) {
  final out = <BlueprintColorLegendItem>[];
  for (final item in raw) {
    if (item is BlueprintColorLegendItem) {
      out.add(item);
      continue;
    }
    if (item is Map) {
      final color = item['color']?.toString() ?? '';
      final label = item['label']?.toString() ?? '';
      if (color.isEmpty || label.isEmpty) continue;
      out.add(
        BlueprintColorLegendItem(
          id: item['id'] is num ? (item['id'] as num).toInt() : out.length + 1,
          label: label,
          color: color,
        ),
      );
    }
  }
  return out;
}

class _N3EquivalentResult {
  const _N3EquivalentResult({
    this.dataUrl,
    required this.reason,
    this.requestId,
  });

  final String? dataUrl;
  final String reason;
  final String? requestId;
}
