// LessonVisualPipeline — funil de imagem do SIM App.
// Espelha o comportamento vivo do SimWeb; o provedor pago final é próprio da API do app.
import 'package:flutter/foundation.dart';

import 'blueprint_prompt.dart';
import 'image_pedagogical_critic.dart';
import 'lesson_image_api_contract.dart';
import 'lesson_visual_models.dart';
import 's12_visual_pipeline.dart';
import 'software_render_catalog.dart';
import 'visual_pedagogical_role.dart';
import 'visual_router_n2.dart';
import 'visual_router_n3.dart';
import 'visual_funnel_telemetry.dart';
import 'visual_escalation_policy.dart';
import 'visual_final_quality_evaluator.dart';
import 'image_data_url_compression.dart';
import 'math_templates/math_templates.dart';

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
  final VisualFunnelTelemetry? telemetry;
  final VisualEscalationPolicy escalationPolicy;

  /// Tenta renderizar usando math template SVG (custo zero).
  /// Retorna data URL do SVG ou null → chamador usa fallback IA.
  String? tryMathTemplate(Object? visualTrigger) {
    return tryRenderMathTemplate(visualTrigger);
  }

  /// Ponto de entrada principal: decide e executa o melhor caminho visual.
  ///
  /// Ordem de prioridade (fiel ao SIM Web):
  ///  1. render_strategy="software" + svg_payload → SVG inline (grátis)
  ///  2. math_template → SVG calculado (grátis)
  ///  3. N2 keyword router → se "svg" → N3 (AI judge) → SVG (grátis)
  ///  4. Oferta paga; a imagem só é gerada após aceite explícito.
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

    if (_prefersServerSideVisuals(visualRouterClient)) {
      return _resolveServerOnlyVisual(
        trigger: trigger,
        lessonKey: lessonKey,
        stableLang: stableLang,
        academicLevel: academicLevel,
      );
    }

    // 1. SVG inline do próprio T02 (render_strategy=software + svg_payload)
    if (trigger.renderStrategy == 'software' && trigger.svgPayload != null) {
      final svgDataUrl = sanitizeAndEncodeSvg(trigger.svgPayload);
      if (svgDataUrl != null) {
        if (_acceptFinalSoftwareSvg(
          lessonKey,
          'svg_inline',
          svgDataUrl,
          _requestFromTrigger(trigger, academicLevel: academicLevel),
        )) {
          _visualLog(
            lessonKey,
            'svg_inline',
            'accepted len=${trigger.svgPayload?.length ?? 0}',
          );
          _recordOutcome(lessonKey, 'software', 'svg_inline');
          return LessonVisualResult(
            svg: svgDataUrl,
            dataUrl: null,
            source: 'svg_inline',
          );
        }
      }
      _visualLog(
        lessonKey,
        'svg_inline',
        'rejected len=${trigger.svgPayload?.length ?? 0}',
      );
    }

    // 2. N2 router — classifica por palavras-chave (custo zero)
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

    final softwareRequest = SoftwareVisualRequest(
      n2: n2,
      topic: trigger.topic,
      visualType: trigger.visualType,
      imagePrompt: trigger.imagePrompt,
      colorLegend: trigger.colorLegend,
      keyElements: trigger.keyElements,
      highlightFocus: trigger.highlightFocus,
      complexity: trigger.complexity,
      pedagogicalNeed: trigger.pedagogicalNeed,
      academicLevel: academicLevel,
      pedagogicalGoal: trigger.highlightFocus,
    );

    final serverFirstVisuals = _prefersServerSideVisuals(visualRouterClient);
    var serverRouteAttempted = false;
    var skipLocalAfterServerDecision = false;
    if (serverFirstVisuals && n2.verdict != VisualVerdict.ai) {
      serverRouteAttempted = true;
      final serverResult = await _tryN3SoftwareVisual(
        lessonKey: lessonKey,
        n2: n2,
        trigger: trigger,
        softwareRequest: softwareRequest,
        stableLang: stableLang,
        stage: 'n3_server_first',
      );
      if (serverResult.result != null) return serverResult.result!;
      if (serverResult.transportFailed) {
        _visualLog(
          lessonKey,
          'n3_server_first_fallback',
          'transport_failed=true using local emergency fallback',
        );
      } else {
        skipLocalAfterServerDecision = true;
      }
    }

    // 3. Math template SVG. No cliente real, só roda se o servidor caiu.
    if (!skipLocalAfterServerDecision && trigger.mathTemplate != null) {
      final mathSvg = tryRenderMathTemplate(trigger.toVisualTriggerMap());
      if (mathSvg != null) {
        if (_acceptFinalSoftwareSvg(
          lessonKey,
          'math_template',
          mathSvg,
          softwareRequest,
        )) {
          _visualLog(
            lessonKey,
            'math_template',
            'accepted name=${_mathTemplateName(trigger.mathTemplate)}',
          );
          _recordOutcome(lessonKey, 'software', 'math_template');
          return LessonVisualResult(
            svg: mathSvg,
            dataUrl: null,
            source: 'math_template',
          );
        }
      }
      _visualLog(
        lessonKey,
        'math_template',
        'rejected name=${_mathTemplateName(trigger.mathTemplate)}',
      );
    }

    if (skipLocalAfterServerDecision) {
      _visualLog(
        lessonKey,
        'local_software_skipped',
        'server_side_visual_pipeline=true n2=${n2.verdict.name}/${n2.reason}',
      );
    }

    if (skipLocalAfterServerDecision) {
      if (!allowPaidImages) {
        _visualLog(
          lessonKey,
          'skip_no_paid',
          'n2=${n2.verdict.name}/${n2.reason} allowPaidImages=false topic=${_shortVisualText(trigger.topic)}',
        );
        _recordOutcome(lessonKey, 'paid_offer', 'skip_no_paid', n2.reason);
        return const LessonVisualResult(
          svg: null,
          dataUrl: null,
          source: 'skip_no_paid',
        );
      }
    }

    final localSoftware = skipLocalAfterServerDecision
        ? null
        : softwareRenderCatalog.render(softwareRequest);
    var localAccepted = false;
    if (localSoftware != null) {
      localAccepted = _acceptFinalSoftwareSvg(
        lessonKey,
        'local_software:${localSoftware.renderer}',
        localSoftware.dataUrl,
        softwareRequest,
      );
      final localDecision = escalationPolicy.decide(
        request: softwareRequest,
        localResult: localSoftware,
        localAccepted: localAccepted,
      );
      if (localDecision.acceptLocalBeforeN3) {
        _visualLog(
          lessonKey,
          'local_software',
          'renderer=${localSoftware.renderer} role=${localSoftware.role.id} policy=${localDecision.reason}',
        );
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
          n2Reason: n2.reason,
        );
      }
      if (localAccepted && localDecision.shouldCallN3) {
        _visualLog(
          lessonKey,
          'local_software_escalated',
          'renderer=${localSoftware.renderer} policy=${localDecision.reason}',
        );
      }
      if (!localAccepted) {
        _visualLog(
          lessonKey,
          'local_software',
          'rejected renderer=${localSoftware.renderer}',
        );
      }
    }
    final escalationDecision = escalationPolicy.decide(
      request: softwareRequest,
      localResult: localSoftware,
      localAccepted: localAccepted,
    );

    if (escalationDecision.shouldCallN3 && !serverRouteAttempted) {
      final n3 = await routeVisualCheapN3(
        client: visualRouterClient,
        n2: n2,
        topic: trigger.topic,
        visualType: trigger.visualType,
        imagePrompt: trigger.imagePrompt,
        keyElements: trigger.keyElements,
        pedagogicalNeed: trigger.pedagogicalNeed,
        highlightFocus: trigger.highlightFocus,
        complexity: trigger.complexity,
        stableLang: stableLang,
      );
      _visualLog(
        lessonKey,
        'n3',
        'verdict=${n3.verdict.name} reason=${_shortVisualText(n3.reason)} confidence=${n3.confidence?.toStringAsFixed(2) ?? 'n/a'} role=${n3.pedagogicalRole ?? 'n/a'} hasSvg=${n3.svgDataUrl != null}',
      );
      if (n3.verdict == VisualVerdict.svg && n3.svgDataUrl != null) {
        final n3Accepted = _acceptFinalSoftwareSvg(
          lessonKey,
          'n3_software',
          n3.svgDataUrl!,
          softwareRequest,
        );
        if (n3Accepted) {
          _recordOutcome(lessonKey, 'software', 'n3_software', n2.reason);
          return LessonVisualResult(
            svg: n3.displayDataUrl ?? n3.svgDataUrl,
            dataUrl: null,
            source: 'n3_software',
            n2Reason: n2.reason,
          );
        }
        final strictN3Result = await _retryN3WithStrictSvgContract(
          lessonKey: lessonKey,
          n2: n2,
          trigger: trigger,
          softwareRequest: softwareRequest,
          stableLang: stableLang,
          reason: n3.reason,
        );
        if (strictN3Result != null) return strictN3Result;
        if (localSoftware != null &&
            localAccepted &&
            escalationDecision.allowLocalAfterN3Failure) {
          _visualLog(
            lessonKey,
            'local_software_after_n3_quality',
            'renderer=${localSoftware.renderer} n3=${_shortVisualText(n3.reason)} policy=${escalationDecision.reason}',
          );
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
            n2Reason: n2.reason,
          );
        }
      }
      if (n3.transportFailed &&
          localSoftware != null &&
          localAccepted &&
          escalationDecision.allowLocalAfterN3Failure) {
        _visualLog(
          lessonKey,
          'local_software_after_n3_failure',
          'renderer=${localSoftware.renderer} n3=${_shortVisualText(n3.reason)} policy=${escalationDecision.reason}',
        );
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
          n2Reason: n2.reason,
        );
      }
      if (n3.verdict == VisualVerdict.noImage) {
        _recordOutcome(lessonKey, 'no_image', 'n3_no_image', n2.reason);
        return LessonVisualResult(
          svg: null,
          dataUrl: null,
          source: 'n3_no_image',
          n2Reason: n2.reason,
        );
      }
    }

    if (!allowPaidImages) {
      _visualLog(
        lessonKey,
        'skip_no_paid',
        'n2=${n2.verdict.name}/${n2.reason} allowPaidImages=false topic=${_shortVisualText(trigger.topic)}',
      );
      _recordOutcome(lessonKey, 'paid_offer', 'skip_no_paid', n2.reason);
      return const LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'skip_no_paid',
      );
    }
    if (acceptedOfferId == null || acceptedOfferId.trim().isEmpty) {
      _visualLog(
        lessonKey,
        'skip_no_offer',
        'n2=${n2.verdict.name}/${n2.reason} acceptedOfferId=missing topic=${_shortVisualText(trigger.topic)}',
      );
      _recordOutcome(lessonKey, 'paid_offer', 'skip_no_offer', n2.reason);
      return const LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'skip_no_offer',
      );
    }

    // 4. AI Blueprint (pago)
    final prompt = buildPromptForTrigger(
      topic: trigger.topic ?? '',
      trigger: trigger,
      lang: stableLang,
    );
    if (prompt.isEmpty) {
      _visualLog(lessonKey, 'skip_no_prompt', 'paid prompt empty');
      _recordOutcome(lessonKey, 'failed', 'skip_no_prompt', n2.reason);
      return const LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'skip_no_prompt',
      );
    }

    final paidImage = await fetchPaidLessonImageResponse(
      prompt,
      lessonKey,
      aspectRatio: normalizedLessonImageAspectRatio(trigger.aspectRatio),
      acceptedOfferId: acceptedOfferId,
      idempotencyKey: idempotencyKey ?? acceptedOfferId,
      visualTrigger: trigger.toVisualTriggerMap(),
      lessonContext: {
        'stableLang': stableLang,
        'topic': trigger.topic,
        'visualType': trigger.visualType,
        'pedagogicalNeed': trigger.pedagogicalNeed,
        'source': 'sim_app_flutter',
      },
    );
    if (paidImage == null) {
      _visualLog(
        lessonKey,
        'ai_failed',
        'n2=${n2.verdict.name}/${n2.reason} promptLen=${prompt.length}',
      );
      _recordOutcome(lessonKey, 'failed', 'ai_failed', n2.reason);
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'ai_failed',
        n2Reason: n2.reason,
      );
    }
    _visualLog(
      lessonKey,
      'ai_blueprint',
      'promptLen=${prompt.length} n2=${n2.verdict.name}/${n2.reason}',
    );
    _recordOutcome(lessonKey, 'paid_ready', 'ai_blueprint', n2.reason);
    return LessonVisualResult(
      svg: null,
      dataUrl: paidImage.dataUrl,
      source: 'ai_blueprint',
      n2Reason: n2.reason,
      imageMetadata: paidImage.toMetadata(),
    );
  }

  Future<LessonVisualResult> _resolveServerOnlyVisual({
    required LessonVisualTrigger trigger,
    required String lessonKey,
    required String? stableLang,
    required String? academicLevel,
  }) async {
    const serverN2 = VisualN2Result(
      verdict: VisualVerdict.ambiguous,
      matched: ['server_image_pipeline'],
      reason: 'SERVER_IMAGE_PIPELINE',
      confidence: 1,
    );
    final softwareRequest = SoftwareVisualRequest(
      n2: serverN2,
      topic: trigger.topic,
      visualType: trigger.visualType,
      imagePrompt: trigger.imagePrompt,
      colorLegend: trigger.colorLegend,
      keyElements: trigger.keyElements,
      highlightFocus: trigger.highlightFocus,
      complexity: trigger.complexity,
      pedagogicalNeed: trigger.pedagogicalNeed,
      academicLevel: academicLevel,
      pedagogicalGoal: trigger.highlightFocus,
    );
    final n3 = await routeVisualCheapN3(
      client: visualRouterClient,
      n2: serverN2,
      topic: trigger.topic,
      visualType: trigger.visualType,
      imagePrompt: trigger.imagePrompt,
      keyElements: trigger.keyElements,
      pedagogicalNeed: trigger.pedagogicalNeed,
      highlightFocus: trigger.highlightFocus,
      complexity: trigger.complexity,
      stableLang: stableLang,
    );
    _visualLog(
      lessonKey,
      'server_only',
      'verdict=${n3.verdict.name} reason=${_shortVisualText(n3.reason)} hasSvg=${n3.svgDataUrl != null} hasRaster=${n3.displayDataUrl != null} hasPaidOffer=${n3.paidOfferPrompt != null}',
    );
    if (n3.transportFailed) {
      _recordOutcome(lessonKey, 'failed', 'server_failed', n3.reason);
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'server_failed',
        n2Reason: n3.reason,
      );
    }
    if (n3.verdict == VisualVerdict.noImage) {
      _recordOutcome(lessonKey, 'no_image', 'server_no_image', n3.reason);
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'server_no_image',
        n2Reason: n3.reason,
      );
    }
    if (n3.verdict == VisualVerdict.svg && n3.svgDataUrl != null) {
      final accepted = _acceptFinalSoftwareSvg(
        lessonKey,
        'server_visual',
        n3.svgDataUrl!,
        softwareRequest,
      );
      if (accepted) {
        _recordOutcome(lessonKey, 'software', 'server_visual', n3.reason);
        return LessonVisualResult(
          svg: n3.displayDataUrl ?? n3.svgDataUrl,
          dataUrl: null,
          source: 'server_visual',
          n2Reason: n3.reason,
        );
      }
      _recordOutcome(lessonKey, 'failed', 'server_visual_rejected', n3.reason);
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'server_visual_rejected',
        n2Reason: n3.reason,
      );
    }
    if (n3.paidOfferPrompt == null || n3.paidOfferPrompt!.trim().isEmpty) {
      _recordOutcome(lessonKey, 'failed', 'server_missing_offer', n3.reason);
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'server_missing_offer',
        n2Reason: n3.reason,
      );
    }
    _recordOutcome(lessonKey, 'paid_offer', 'server_paid_offer', n3.reason);
    return LessonVisualResult(
      svg: null,
      dataUrl: null,
      source: 'server_paid_offer',
      n2Reason: n3.reason,
      paidOfferPrompt: n3.paidOfferPrompt,
    );
  }

  SoftwareVisualRequest _requestFromTrigger(
    LessonVisualTrigger trigger, {
    String? academicLevel,
    VisualN2Result? n2,
  }) {
    return SoftwareVisualRequest(
      n2:
          n2 ??
          const VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['software'],
            reason: 'PRE_N2_SOFTWARE',
          ),
      topic: trigger.topic,
      visualType: trigger.visualType,
      imagePrompt: trigger.imagePrompt,
      colorLegend: trigger.colorLegend,
      keyElements: trigger.keyElements,
      highlightFocus: trigger.highlightFocus,
      complexity: trigger.complexity,
      pedagogicalNeed: trigger.pedagogicalNeed,
      academicLevel: academicLevel,
      pedagogicalGoal: trigger.highlightFocus,
    );
  }

  Future<_N3VisualAttempt> _tryN3SoftwareVisual({
    required String lessonKey,
    required VisualN2Result n2,
    required LessonVisualTrigger trigger,
    required SoftwareVisualRequest softwareRequest,
    required String? stableLang,
    required String stage,
  }) async {
    final n3 = await routeVisualCheapN3(
      client: visualRouterClient,
      n2: n2,
      topic: trigger.topic,
      visualType: trigger.visualType,
      imagePrompt: trigger.imagePrompt,
      keyElements: trigger.keyElements,
      pedagogicalNeed: trigger.pedagogicalNeed,
      highlightFocus: trigger.highlightFocus,
      complexity: trigger.complexity,
      stableLang: stableLang,
    );
    _visualLog(
      lessonKey,
      stage,
      'verdict=${n3.verdict.name} reason=${_shortVisualText(n3.reason)} confidence=${n3.confidence?.toStringAsFixed(2) ?? 'n/a'} role=${n3.pedagogicalRole ?? 'n/a'} hasSvg=${n3.svgDataUrl != null} hasRaster=${n3.displayDataUrl != null}',
    );
    if (n3.transportFailed) {
      return const _N3VisualAttempt(transportFailed: true);
    }
    if (n3.verdict == VisualVerdict.noImage) {
      _recordOutcome(lessonKey, 'no_image', 'n3_no_image', n2.reason);
      return _N3VisualAttempt(
        result: LessonVisualResult(
          svg: null,
          dataUrl: null,
          source: 'n3_no_image',
          n2Reason: n2.reason,
        ),
      );
    }
    if (n3.verdict == VisualVerdict.svg && n3.svgDataUrl != null) {
      final n3Accepted = _acceptFinalSoftwareSvg(
        lessonKey,
        'n3_software',
        n3.svgDataUrl!,
        softwareRequest,
      );
      if (n3Accepted) {
        _recordOutcome(lessonKey, 'software', 'n3_software', n2.reason);
        return _N3VisualAttempt(
          result: LessonVisualResult(
            svg: n3.displayDataUrl ?? n3.svgDataUrl,
            dataUrl: null,
            source: 'n3_software',
            n2Reason: n2.reason,
          ),
        );
      }
      final strictN3Result = await _retryN3WithStrictSvgContract(
        lessonKey: lessonKey,
        n2: n2,
        trigger: trigger,
        softwareRequest: softwareRequest,
        stableLang: stableLang,
        reason: n3.reason,
      );
      if (strictN3Result != null) {
        return _N3VisualAttempt(result: strictN3Result);
      }
    }
    return const _N3VisualAttempt();
  }

  Future<LessonVisualResult?> _retryN3WithStrictSvgContract({
    required String lessonKey,
    required VisualN2Result n2,
    required LessonVisualTrigger trigger,
    required SoftwareVisualRequest softwareRequest,
    required String? stableLang,
    required String reason,
  }) async {
    final strictPrompt = _strictSvgRetryPrompt(trigger, reason);
    _visualLog(
      lessonKey,
      'n3_strict_retry',
      'reason=${_shortVisualText(reason)} promptLen=${strictPrompt.length}',
    );
    final retry = await routeVisualCheapN3(
      client: visualRouterClient,
      n2: n2,
      topic: trigger.topic,
      visualType: trigger.visualType,
      imagePrompt: strictPrompt,
      keyElements: trigger.keyElements,
      pedagogicalNeed: trigger.pedagogicalNeed,
      highlightFocus: trigger.highlightFocus,
      complexity: trigger.complexity,
      stableLang: stableLang,
    );
    _visualLog(
      lessonKey,
      'n3_strict_retry_result',
      'verdict=${retry.verdict.name} reason=${_shortVisualText(retry.reason)} hasSvg=${retry.svgDataUrl != null}',
    );
    if (retry.verdict != VisualVerdict.svg || retry.svgDataUrl == null) {
      return null;
    }
    final accepted = _acceptFinalSoftwareSvg(
      lessonKey,
      'n3_software_strict_retry',
      retry.svgDataUrl!,
      softwareRequest,
    );
    if (!accepted) return null;
    _recordOutcome(
      lessonKey,
      'software',
      'n3_software_strict_retry',
      n2.reason,
    );
    return LessonVisualResult(
      svg: retry.displayDataUrl ?? retry.svgDataUrl,
      dataUrl: null,
      source: 'n3_software_strict_retry',
      n2Reason: n2.reason,
    );
  }

  String _strictSvgRetryPrompt(LessonVisualTrigger trigger, String reason) {
    final base = [
      trigger.imagePrompt,
      trigger.topic,
      trigger.highlightFocus,
      ...trigger.keyElements,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join('\n');
    return '''
$base

Regenerate the visual as a complete didactic SVG. Previous SVG was rejected: ${_shortVisualText(reason)}.
Hard visual contract:
- SVG viewBox must be exactly "0 0 900 560".
- Main drawing must be centered and occupy 65% to 85% of the canvas width and at least 45% of canvas height.
- Do not leave a large blank white area around the drawing.
- Use visible shapes, arrows or diagram structure, not text alone.
- Use readable labels with font-size 14 or larger and high contrast.
- Keep all elements inside the viewBox with generous margins.
- Return a valid data:image/svg+xml data URL only.
''';
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
      'stage=$stage accepted=${critique.accepted} reason=${critique.reason} textNodes=${critique.textNodeCount}',
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
      'stage=$stage action=${finalQuality.action.name} reason=${finalQuality.reason} keyCoverage=${finalQuality.coveredKeyElements}/${finalQuality.requiredKeyElements} focus=${finalQuality.focusCovered}',
    );
    return finalQuality.accepted;
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

String _mathTemplateName(Object? mathTemplate) {
  if (mathTemplate is Map) {
    return mathTemplate['name']?.toString() ?? '<missing>';
  }
  return mathTemplate == null ? '<null>' : mathTemplate.runtimeType.toString();
}

String _shortVisualText(Object? value) {
  final text = (value ?? '').toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= 160) return text;
  return text.substring(0, 160);
}

bool _prefersServerSideVisuals(LessonVisualRouterClient client) {
  try {
    return (client as dynamic).prefersServerSideVisuals == true;
  } catch (_) {
    return false;
  }
}

class _N3VisualAttempt {
  const _N3VisualAttempt({this.result, this.transportFailed = false});

  final LessonVisualResult? result;
  final bool transportFailed;
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

  /// data URL de imagem gerada por IA (Blueprint pago) — usar se svg nulo.
  final String? dataUrl;

  /// Fonte do resultado (para diagnóstico/auditoria).
  final String source;
  final String? n2Reason;
  final LessonImageGenerationMetadata? imageMetadata;
  final String? paidOfferPrompt;

  /// Imagem útil disponível (SVG ou AI)
  bool get hasImage => svg != null || dataUrl != null;

  /// data URL para exibição (prefere SVG)
  String? get displayUrl => svg ?? dataUrl;
}
