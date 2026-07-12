import 'image_pedagogical_critic.dart';
import 'pedagogical_visual_level.dart';
import 'software_render_catalog.dart';

enum VisualFinalQualityAction { accepted, needsN3, rejected }

class VisualFinalQualityResult {
  const VisualFinalQualityResult({
    required this.action,
    required this.reason,
    this.coveredKeyElements = 0,
    this.requiredKeyElements = 0,
    this.focusCovered = false,
  });

  final VisualFinalQualityAction action;
  final String reason;
  final int coveredKeyElements;
  final int requiredKeyElements;
  final bool focusCovered;

  bool get accepted => action == VisualFinalQualityAction.accepted;
  bool get needsN3 => action == VisualFinalQualityAction.needsN3;
}

class VisualFinalQualityEvaluator {
  const VisualFinalQualityEvaluator();

  static const standard = VisualFinalQualityEvaluator();

  VisualFinalQualityResult evaluateSvg({
    required String dataUrl,
    required SoftwareVisualRequest request,
    required ImagePedagogicalCritique critique,
    required String source,
  }) {
    if (!critique.accepted) {
      return VisualFinalQualityResult(
        action: VisualFinalQualityAction.rejected,
        reason: 'final_rejected_by_critic:${critique.reason}',
      );
    }

    final svg = _decodeDataUrl(dataUrl);
    if (svg == null || svg.trim().isEmpty) {
      return const VisualFinalQualityResult(
        action: VisualFinalQualityAction.rejected,
        reason: 'final_invalid_svg',
      );
    }

    final level = PedagogicalVisualLevelProfile.fromAcademicLevel(
      request.academicLevel,
    );
    final keyElements = _normalizedKeyElements(request.keyElements);
    final covered = _coveredKeyElements(svg, keyElements);
    final focusCovered = _focusCovered(svg, request.highlightFocus);
    final textNodes = critique.textNodeCount;

    if (_isDeterministicSvgSource(source) &&
        _hasDeterministicVisualEvidence(request)) {
      return VisualFinalQualityResult(
        action: VisualFinalQualityAction.accepted,
        reason: 'final_accepted_deterministic_visual',
        coveredKeyElements: covered,
        requiredKeyElements: keyElements.length,
        focusCovered: focusCovered,
      );
    }

    if (keyElements.isNotEmpty) {
      final minimum = _minimumKeyCoverage(keyElements.length, level);
      if (covered < minimum) {
        final richRequest = _isRichRequest(request, level);
        return VisualFinalQualityResult(
          action: richRequest
              ? VisualFinalQualityAction.needsN3
              : VisualFinalQualityAction.rejected,
          reason: richRequest
              ? 'final_needs_n3_key_coverage_$covered/$minimum'
              : 'final_rejected_key_coverage_$covered/$minimum',
          coveredKeyElements: covered,
          requiredKeyElements: minimum,
          focusCovered: focusCovered,
        );
      }
    }

    final focus = _norm(request.highlightFocus);
    if (focus.length >= 18 && !focusCovered && _isRichRequest(request, level)) {
      return VisualFinalQualityResult(
        action: VisualFinalQualityAction.needsN3,
        reason: 'final_needs_n3_focus_missing',
        coveredKeyElements: covered,
        requiredKeyElements: keyElements.isEmpty
            ? 0
            : _minimumKeyCoverage(keyElements.length, level),
        focusCovered: false,
      );
    }

    if (_tooSparseForLevel(textNodes, keyElements.length, level, source)) {
      return VisualFinalQualityResult(
        action: VisualFinalQualityAction.needsN3,
        reason: 'final_needs_n3_sparse_for_level',
        coveredKeyElements: covered,
        requiredKeyElements: keyElements.length,
        focusCovered: focusCovered,
      );
    }

    if (_excessiveUselessText(svg, textNodes, keyElements, request)) {
      return VisualFinalQualityResult(
        action: VisualFinalQualityAction.rejected,
        reason: 'final_rejected_useless_text_density',
        coveredKeyElements: covered,
        requiredKeyElements: keyElements.length,
        focusCovered: focusCovered,
      );
    }

    return VisualFinalQualityResult(
      action: VisualFinalQualityAction.accepted,
      reason:
          'final_accepted_keys_$covered/${keyElements.length}_focus_${focusCovered ? 'yes' : 'optional'}',
      coveredKeyElements: covered,
      requiredKeyElements: keyElements.length,
      focusCovered: focusCovered,
    );
  }

  int _minimumKeyCoverage(int keyCount, PedagogicalVisualLevelProfile level) {
    if (keyCount <= 2) return keyCount;
    switch (level.level) {
      case PedagogicalVisualLevel.child:
        return keyCount >= 2 ? 2 : keyCount;
      case PedagogicalVisualLevel.fundamental:
        return keyCount >= 3 ? 3 : keyCount;
      case PedagogicalVisualLevel.highSchool:
        return keyCount >= 4 ? 3 : keyCount;
      case PedagogicalVisualLevel.examPrep:
        return keyCount >= 5 ? 4 : keyCount;
      case PedagogicalVisualLevel.advanced:
        return keyCount >= 6 ? 4 : keyCount;
    }
  }

  bool _isRichRequest(
    SoftwareVisualRequest request,
    PedagogicalVisualLevelProfile level,
  ) {
    final text = [
      request.complexity,
      request.pedagogicalNeed,
      request.imagePrompt,
      request.highlightFocus,
    ].map(_norm).join(' ');
    return level.level == PedagogicalVisualLevel.examPrep ||
        level.level == PedagogicalVisualLevel.advanced ||
        request.keyElements.length >= 4 ||
        _hasAny(text, const [
          'alta',
          'alto',
          'high',
          'complex',
          'complexa',
          'technical',
          'técnico',
          'tecnico',
          'essential',
          'essencial',
          'rico',
          'rich',
          'camadas',
          'múltipl',
          'multipl',
          'relação',
          'relacao',
        ]);
  }

  bool _tooSparseForLevel(
    int textNodes,
    int keyCount,
    PedagogicalVisualLevelProfile level,
    String source,
  ) {
    if (!source.startsWith('local_software') &&
        !source.startsWith('n3_software')) {
      return false;
    }
    if (level.level != PedagogicalVisualLevel.advanced &&
        level.level != PedagogicalVisualLevel.examPrep) {
      return false;
    }
    if (keyCount < 5) return false;
    return textNodes < 3;
  }

  bool _isDeterministicSvgSource(String source) {
    return const {
      'local_software:LinearRenderer',
      'local_software:QuadraticRenderer',
      'local_software:KinematicsGraphRenderer',
      'local_software:ForceDiagramRenderer',
      'local_software:CircuitRenderer',
      'local_software:ChemistryReactionRenderer',
      'local_software:SyntaxTreeRenderer',
      'math_template',
    }.contains(source);
  }

  bool _hasDeterministicVisualEvidence(SoftwareVisualRequest request) {
    final text = _norm(
      [
        request.topic,
        request.visualType,
        request.imagePrompt,
        request.highlightFocus,
        ...request.keyElements,
      ].whereType<String>().join(' '),
    );
    return _hasAny(text, const [
      'f(x)',
      'h(t)',
      's(t)',
      'v(t)',
      'x²',
      'x^2',
      't²',
      't^2',
      'função',
      'funcao',
      'gráfico',
      'grafico',
      'parábola',
      'parabola',
      'força',
      'forca',
      'circuito',
      'reação',
      'reacao',
      'sintaxe',
    ]);
  }

  bool _excessiveUselessText(
    String svg,
    int textNodes,
    List<String> keyElements,
    SoftwareVisualRequest request,
  ) {
    if (textNodes < 18) return false;
    if (keyElements.isEmpty) return false;
    final covered = _coveredKeyElements(svg, keyElements);
    return covered < 2 && !_focusCovered(svg, request.highlightFocus);
  }

  int _coveredKeyElements(String svg, List<String> keyElements) {
    final normalizedSvg = _norm(svg);
    return keyElements.where((element) {
      final tokens = element.split(' ').where((token) => token.length >= 3);
      return tokens.any(normalizedSvg.contains);
    }).length;
  }

  bool _focusCovered(String svg, String? focus) {
    final focusText = _norm(focus);
    if (focusText.length < 18) return true;
    final normalizedSvg = _norm(svg);
    final tokens = focusText
        .split(' ')
        .where((token) => token.length >= 5)
        .toList(growable: false);
    if (tokens.isEmpty) return true;
    final hits = tokens.where(normalizedSvg.contains).length;
    return hits >= 1 || hits >= (tokens.length / 3).ceil();
  }

  List<String> _normalizedKeyElements(List<String> keyElements) {
    final values = <String>[];
    for (final element in keyElements) {
      final clean = _norm(element);
      if (clean.length < 3) continue;
      if (values.contains(clean)) continue;
      values.add(clean);
    }
    return values;
  }

  String? _decodeDataUrl(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return Uri.decodeFull(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  bool _hasAny(String text, List<String> values) {
    return values.any(text.contains);
  }

  String _norm(String? value) {
    return (value ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
