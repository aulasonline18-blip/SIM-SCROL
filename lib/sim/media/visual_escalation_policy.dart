import 'software_render_catalog.dart';
import 'visual_router_n2.dart';

class VisualEscalationDecision {
  const VisualEscalationDecision({
    required this.acceptLocalBeforeN3,
    required this.shouldCallN3,
    required this.allowLocalAfterN3Failure,
    required this.reason,
  });

  final bool acceptLocalBeforeN3;
  final bool shouldCallN3;
  final bool allowLocalAfterN3Failure;
  final String reason;
}

class VisualEscalationPolicy {
  const VisualEscalationPolicy();

  static const standard = VisualEscalationPolicy();

  VisualEscalationDecision decide({
    required SoftwareVisualRequest request,
    required SoftwareRenderResult? localResult,
    required bool localAccepted,
  }) {
    final canCallN3 =
        request.n2.verdict == VisualVerdict.svg ||
        request.n2.verdict == VisualVerdict.ambiguous;
    if (!canCallN3) {
      return VisualEscalationDecision(
        acceptLocalBeforeN3: localAccepted && localResult != null,
        shouldCallN3: false,
        allowLocalAfterN3Failure: localAccepted && localResult != null,
        reason: 'n2_not_free_svg_route',
      );
    }

    if (localResult == null || !localAccepted) {
      return const VisualEscalationDecision(
        acceptLocalBeforeN3: false,
        shouldCallN3: true,
        allowLocalAfterN3Failure: false,
        reason: 'local_missing_or_rejected',
      );
    }

    final richness = _richnessScore(request, localResult);
    if (richness <= 1) {
      return const VisualEscalationDecision(
        acceptLocalBeforeN3: true,
        shouldCallN3: false,
        allowLocalAfterN3Failure: true,
        reason: 'local_simple_sufficient',
      );
    }

    return VisualEscalationDecision(
      acceptLocalBeforeN3: false,
      shouldCallN3: true,
      allowLocalAfterN3Failure: true,
      reason: 'n3_needed_richness_$richness',
    );
  }

  int _richnessScore(
    SoftwareVisualRequest request,
    SoftwareRenderResult local,
  ) {
    var score = 0;
    final complexity = _norm(request.complexity);
    final need = _norm(request.pedagogicalNeed);
    final focus = _norm(request.highlightFocus);
    final prompt = _norm(request.imagePrompt);
    final keyElements = request.keyElements
        .map(_norm)
        .where((value) => value.length >= 3)
        .toList();

    if (_hasAny(complexity, const [
      'alta',
      'alto',
      'high',
      'complex',
      'complexa',
      'advanced',
      'avanc',
      'technical',
      'tecnico',
      'técnico',
      'rich',
      'rica',
    ])) {
      score += 2;
    }
    if (keyElements.length >= 6) score += 2;
    if (keyElements.length >= 4) score += 1;
    if (focus.length >= 36 ||
        _hasAny(focus, const [
          'relação',
          'relacao',
          'entre',
          'compar',
          'causa',
          'efeito',
        ])) {
      score += 1;
    }
    if (_hasAny(need, const [
      'sofistic',
      'profund',
      'complex',
      'essential',
      'essencial',
      'diagnostic',
      'diagnóstico',
    ])) {
      score += 1;
    }
    if (_hasAny(prompt, const [
      'detalh',
      'camadas',
      'multipl',
      'múltipl',
      'compos',
      'especific',
      'específic',
      'contextual',
      'visual rico',
      'rich visual',
    ])) {
      score += 1;
    }

    final genericRenderer = _isGenericRenderer(local.renderer);
    final coveredKeyElements = _coveredKeyElements(local.dataUrl, keyElements);
    if (genericRenderer && keyElements.length >= 4 && coveredKeyElements < 3) {
      score += 2;
    } else if (keyElements.length >= 4 &&
        coveredKeyElements < keyElements.length ~/ 2) {
      score += 1;
    }

    return score;
  }

  int _coveredKeyElements(String dataUrl, List<String> keyElements) {
    final svg = _decodeDataUrl(dataUrl);
    if (svg == null || svg.isEmpty) return 0;
    return keyElements.where((element) => svg.contains(element)).length;
  }

  bool _isGenericRenderer(String renderer) {
    return const {
      'FlowchartRenderer',
      'ComparisonRenderer',
      'CycleRenderer',
      'ConceptMapRenderer',
      'TimelineRenderer',
      'TableRenderer',
    }.contains(renderer);
  }

  String? _decodeDataUrl(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return Uri.decodeFull(dataUrl.substring(comma + 1)).toLowerCase();
    } catch (_) {
      return null;
    }
  }

  bool _hasAny(String text, List<String> needles) {
    return needles.any(text.contains);
  }

  String _norm(String? value) {
    return (value ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
