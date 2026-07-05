import 'dart:convert';

import 'pedagogical_visual_palette.dart';

class ImagePedagogicalCritique {
  const ImagePedagogicalCritique({
    required this.accepted,
    required this.reason,
    this.textNodeCount = 0,
  });

  final bool accepted;
  final String reason;
  final int textNodeCount;
}

class ImagePedagogicalCritic {
  const ImagePedagogicalCritic({
    this.maxTextNodes = 24,
    this.maxSvgChars = 120000,
  });

  final int maxTextNodes;
  final int maxSvgChars;

  ImagePedagogicalCritique evaluateSvgDataUrl(
    String? dataUrl, {
    String? correctAnswer,
    String? question,
  }) {
    final svg = _decodeSvgDataUrl(dataUrl);
    if (svg == null || svg.trim().isEmpty) {
      return const ImagePedagogicalCritique(
        accepted: false,
        reason: 'critic_invalid_svg',
      );
    }
    if (svg.length > maxSvgChars) {
      return ImagePedagogicalCritique(
        accepted: false,
        reason: 'critic_svg_too_large',
        textNodeCount: _textNodeCount(svg),
      );
    }
    final lowered = svg.toLowerCase();
    if (lowered.contains('<script') ||
        lowered.contains('javascript:') ||
        RegExp(r'\son[a-z]+\s*=').hasMatch(lowered) ||
        lowered.contains('<foreignobject')) {
      return ImagePedagogicalCritique(
        accepted: false,
        reason: 'critic_svg_unsafe',
        textNodeCount: _textNodeCount(svg),
      );
    }
    final textNodes = _textNodeCount(svg);
    final answer = correctAnswer?.trim().toLowerCase();
    if (answer != null &&
        answer.length > 2 &&
        lowered.contains('resposta correta') &&
        lowered.contains(answer)) {
      return ImagePedagogicalCritique(
        accepted: false,
        reason: 'critic_answer_leak',
        textNodeCount: textNodes,
      );
    }
    final qualityReason = _qualityRejectionReason(svg, textNodes);
    if (qualityReason != null) {
      return ImagePedagogicalCritique(
        accepted: false,
        reason: qualityReason,
        textNodeCount: textNodes,
      );
    }
    return ImagePedagogicalCritique(
      accepted: true,
      reason: 'critic_ok',
      textNodeCount: textNodes,
    );
  }

  int _textNodeCount(String svg) {
    return RegExp(r'<text\b', caseSensitive: false).allMatches(svg).length;
  }

  String? _qualityRejectionReason(String svg, int textNodes) {
    final textElements = _textElements(svg);
    if (textElements.any(_hasIllegibleFontSize)) {
      return 'critic_illegible_text';
    }
    if (textElements.any(_hasLowContrastText)) {
      return 'critic_low_contrast_text';
    }

    final labels = textElements.map(_extractTextContent).where((text) {
      return text.trim().isNotEmpty;
    }).toList();
    final normalizedLabels = labels.map(_normalizeLabel).where((text) {
      return text.length >= 2;
    }).toList();
    final duplicateCount = _duplicateLabelCount(normalizedLabels);
    final uniqueLabelCount = normalizedLabels.toSet().length;
    if (duplicateCount >= 3 &&
        uniqueLabelCount <= normalizedLabels.length / 3) {
      return 'critic_duplicate_text';
    }

    if (textNodes > maxTextNodes) {
      final hasVisualStructure = _hasVisualStructure(svg);
      final meaningfulLabels = normalizedLabels.where((text) {
        return text.length >= 3 && !RegExp(r'^\d+([.,]\d+)?$').hasMatch(text);
      }).length;
      final singleTokenLabels = labels.where((text) {
        final normalized = _normalizeLabel(text);
        return normalized.length <= 2;
      }).length;
      if (!hasVisualStructure || meaningfulLabels == 0) {
        return 'critic_text_without_visual_structure';
      }
      if (singleTokenLabels > meaningfulLabels * 2) {
        return 'critic_low_value_text_density';
      }
      if (_textDensityIsUnsafe(svg, textNodes) &&
          meaningfulLabels < textNodes ~/ 2) {
        return 'critic_visual_pollution';
      }
    }

    return null;
  }

  List<String> _textElements(String svg) {
    return RegExp(
      r'<text\b[^>]*>.*?</text>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(svg).map((match) => match.group(0) ?? '').toList();
  }

  bool _hasIllegibleFontSize(String textElement) {
    final fontSize = _numericAttribute(textElement, 'font-size');
    return fontSize != null && fontSize < 8;
  }

  bool _hasLowContrastText(String textElement) {
    final fill = _extractColor(textElement, 'fill');
    if (fill == null || fill == 'none' || fill == 'transparent') return false;
    final normalized = _normalizeColor(fill);
    if (normalized == null) return false;
    return contrastRatio(
          normalized,
          PedagogicalVisualPalette.standard.background,
        ) <
        3;
  }

  double? _numericAttribute(String element, String attribute) {
    final match = RegExp(
      '$attribute="([0-9]+(?:\\.[0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(element);
    if (match == null) return null;
    return double.tryParse(match.group(1) ?? '');
  }

  String? _extractColor(String element, String attribute) {
    final attrMatch = RegExp(
      '$attribute="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(element);
    if (attrMatch != null) return attrMatch.group(1)?.trim();

    final styleMatch = RegExp(
      '$attribute\\s*:\\s*([^;"]+)',
      caseSensitive: false,
    ).firstMatch(element);
    return styleMatch?.group(1)?.trim();
  }

  String? _normalizeColor(String color) {
    final value = color.trim().toLowerCase();
    if (RegExp(r'^#[0-9a-f]{6}$').hasMatch(value)) return value.toUpperCase();
    if (RegExp(r'^#[0-9a-f]{3}$').hasMatch(value)) {
      final r = value[1];
      final g = value[2];
      final b = value[3];
      return '#$r$r$g$g$b$b'.toUpperCase();
    }
    switch (value) {
      case 'black':
        return '#000000';
      case 'white':
        return '#FFFFFF';
      case 'gray':
      case 'grey':
        return '#808080';
    }
    return null;
  }

  String _extractTextContent(String textElement) {
    final withoutTags = textElement
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
    return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizeLabel(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), '')
        .trim();
  }

  int _duplicateLabelCount(List<String> labels) {
    final counts = <String, int>{};
    for (final label in labels) {
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts.values
        .where((count) => count > 1)
        .fold<int>(0, (sum, count) => sum + count);
  }

  bool _hasVisualStructure(String svg) {
    return RegExp(
      r'<(rect|circle|ellipse|line|path|polygon|polyline)\b',
      caseSensitive: false,
    ).hasMatch(svg);
  }

  bool _textDensityIsUnsafe(String svg, int textNodes) {
    final viewBox = RegExp(
      r'viewBox="\s*-?[0-9]+(?:\.[0-9]+)?\s+-?[0-9]+(?:\.[0-9]+)?\s+([0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)"',
      caseSensitive: false,
    ).firstMatch(svg);
    if (viewBox == null) return false;
    final width = double.tryParse(viewBox.group(1) ?? '');
    final height = double.tryParse(viewBox.group(2) ?? '');
    if (width == null || height == null || width <= 0 || height <= 0) {
      return false;
    }
    final area = width * height;
    if (area < 20000) return false;
    return textNodes / area * 10000 > 1.2;
  }

  String? _decodeSvgDataUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (!trimmed.startsWith('data:image/svg+xml')) return null;
    final comma = trimmed.indexOf(',');
    if (comma <= 0) return null;
    final header = trimmed.substring(0, comma);
    final payload = trimmed.substring(comma + 1);
    try {
      if (header.contains(';base64')) {
        return utf8.decode(base64Decode(payload));
      }
      return Uri.decodeComponent(payload);
    } catch (_) {
      return null;
    }
  }
}
