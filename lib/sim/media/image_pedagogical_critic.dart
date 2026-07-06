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
    final footprint = _visualFootprint(svg, textElements);
    if (footprint != null) {
      if (footprint.visibleRatio < 0.6) {
        return 'critic_visual_out_of_frame';
      }
      if (footprint.canvasArea >= 20000 &&
          footprint.areaRatio < 0.1 &&
          (footprint.widthRatio < 0.42 || footprint.heightRatio < 0.34)) {
        return 'critic_tiny_visual_footprint';
      }
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
    final viewBox = _parseViewBox(svg);
    if (viewBox == null) return false;
    final area = viewBox.width * viewBox.height;
    if (area < 20000) return false;
    return textNodes / area * 10000 > 1.2;
  }

  _SvgBox? _parseViewBox(String svg) {
    final match = RegExp(
      r'viewBox="\s*(-?[0-9]+(?:\.[0-9]+)?)\s+(-?[0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)\s+([0-9]+(?:\.[0-9]+)?)"',
      caseSensitive: false,
    ).firstMatch(svg);
    if (match == null) return null;
    final x = double.tryParse(match.group(1) ?? '');
    final y = double.tryParse(match.group(2) ?? '');
    final width = double.tryParse(match.group(3) ?? '');
    final height = double.tryParse(match.group(4) ?? '');
    if (x == null ||
        y == null ||
        width == null ||
        height == null ||
        width <= 0 ||
        height <= 0) {
      return null;
    }
    return _SvgBox(x, y, x + width, y + height);
  }

  _SvgFootprint? _visualFootprint(String svg, List<String> textElements) {
    final viewBox = _parseViewBox(svg);
    if (viewBox == null) return null;
    final boxes = <_SvgBox>[];
    boxes.addAll(_rectBoxes(svg));
    boxes.addAll(_circleBoxes(svg));
    boxes.addAll(_ellipseBoxes(svg));
    boxes.addAll(_lineBoxes(svg));
    boxes.addAll(_pathBoxes(svg));
    boxes.addAll(_polyBoxes(svg));
    boxes.addAll(_textBoxes(textElements));
    if (boxes.isEmpty) return null;
    final content = boxes.reduce((value, box) => value.union(box));
    if (content.width <= 0 || content.height <= 0) return null;
    final visible = content.intersection(viewBox);
    final visibleRatio = visible == null ? 0.0 : visible.area / content.area;
    return _SvgFootprint(
      canvasArea: viewBox.area,
      areaRatio: visible == null ? 0 : visible.area / viewBox.area,
      widthRatio: visible == null ? 0 : visible.width / viewBox.width,
      heightRatio: visible == null ? 0 : visible.height / viewBox.height,
      visibleRatio: visibleRatio,
    );
  }

  Iterable<_SvgBox> _rectBoxes(String svg) {
    return RegExp(
      r'<rect\b[^>]*>',
      caseSensitive: false,
    ).allMatches(svg).map((match) => match.group(0) ?? '').map((element) {
      final x = _numericAttribute(element, 'x') ?? 0;
      final y = _numericAttribute(element, 'y') ?? 0;
      final width = _numericAttribute(element, 'width');
      final height = _numericAttribute(element, 'height');
      if (width == null || height == null || width <= 0 || height <= 0) {
        return null;
      }
      return _SvgBox(x, y, x + width, y + height);
    }).whereType<_SvgBox>();
  }

  Iterable<_SvgBox> _circleBoxes(String svg) {
    return RegExp(
      r'<circle\b[^>]*>',
      caseSensitive: false,
    ).allMatches(svg).map((match) => match.group(0) ?? '').map((element) {
      final cx = _numericAttribute(element, 'cx');
      final cy = _numericAttribute(element, 'cy');
      final r = _numericAttribute(element, 'r');
      if (cx == null || cy == null || r == null || r <= 0) return null;
      return _SvgBox(cx - r, cy - r, cx + r, cy + r);
    }).whereType<_SvgBox>();
  }

  Iterable<_SvgBox> _ellipseBoxes(String svg) {
    return RegExp(
      r'<ellipse\b[^>]*>',
      caseSensitive: false,
    ).allMatches(svg).map((match) => match.group(0) ?? '').map((element) {
      final cx = _numericAttribute(element, 'cx');
      final cy = _numericAttribute(element, 'cy');
      final rx = _numericAttribute(element, 'rx');
      final ry = _numericAttribute(element, 'ry');
      if (cx == null ||
          cy == null ||
          rx == null ||
          ry == null ||
          rx <= 0 ||
          ry <= 0) {
        return null;
      }
      return _SvgBox(cx - rx, cy - ry, cx + rx, cy + ry);
    }).whereType<_SvgBox>();
  }

  Iterable<_SvgBox> _lineBoxes(String svg) {
    return RegExp(
      r'<line\b[^>]*>',
      caseSensitive: false,
    ).allMatches(svg).map((match) => match.group(0) ?? '').map((element) {
      final x1 = _numericAttribute(element, 'x1');
      final y1 = _numericAttribute(element, 'y1');
      final x2 = _numericAttribute(element, 'x2');
      final y2 = _numericAttribute(element, 'y2');
      if (x1 == null || y1 == null || x2 == null || y2 == null) {
        return null;
      }
      return _SvgBox.fromPoints([x1, y1, x2, y2]).inflate(2);
    }).whereType<_SvgBox>();
  }

  Iterable<_SvgBox> _pathBoxes(String svg) {
    return RegExp(
      r'<path\b[^>]*>',
      caseSensitive: false,
    ).allMatches(svg).map((match) => match.group(0) ?? '').map((element) {
      final d = RegExp(
        r'\sd="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(element)?.group(1);
      if (d == null) return null;
      return _SvgBox.fromNumbers(_numbersIn(d))?.inflate(2);
    }).whereType<_SvgBox>();
  }

  Iterable<_SvgBox> _polyBoxes(String svg) {
    return RegExp(
      r'<(?:polygon|polyline)\b[^>]*>',
      caseSensitive: false,
    ).allMatches(svg).map((match) => match.group(0) ?? '').map((element) {
      final points = RegExp(
        r'\spoints="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(element)?.group(1);
      if (points == null) return null;
      return _SvgBox.fromNumbers(_numbersIn(points))?.inflate(2);
    }).whereType<_SvgBox>();
  }

  Iterable<_SvgBox> _textBoxes(List<String> textElements) {
    return textElements.map((element) {
      final x = _numericAttribute(element, 'x');
      final y = _numericAttribute(element, 'y');
      if (x == null || y == null) return null;
      final fontSize = _numericAttribute(element, 'font-size') ?? 16;
      final text = _extractTextContent(element);
      final width = (text.length.clamp(1, 48) * fontSize * 0.56).toDouble();
      final height = fontSize * 1.25;
      final anchor =
          RegExp(
            r'text-anchor="([^"]+)"',
            caseSensitive: false,
          ).firstMatch(element)?.group(1)?.toLowerCase() ??
          '';
      final left = anchor == 'middle'
          ? x - width / 2
          : anchor == 'end'
          ? x - width
          : x;
      return _SvgBox(left, y - height, left + width, y + height * 0.25);
    }).whereType<_SvgBox>();
  }

  List<double> _numbersIn(String value) {
    return RegExp(
      r'-?[0-9]+(?:\.[0-9]+)?',
    ).allMatches(value).map((m) => double.parse(m.group(0)!)).toList();
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

class _SvgFootprint {
  const _SvgFootprint({
    required this.canvasArea,
    required this.areaRatio,
    required this.widthRatio,
    required this.heightRatio,
    required this.visibleRatio,
  });

  final double canvasArea;
  final double areaRatio;
  final double widthRatio;
  final double heightRatio;
  final double visibleRatio;
}

class _SvgBox {
  const _SvgBox(this.left, this.top, this.right, this.bottom);

  factory _SvgBox.fromPoints(List<double> points) {
    final xs = <double>[];
    final ys = <double>[];
    for (var i = 0; i + 1 < points.length; i += 2) {
      xs.add(points[i]);
      ys.add(points[i + 1]);
    }
    return _SvgBox(
      xs.reduce((a, b) => a < b ? a : b),
      ys.reduce((a, b) => a < b ? a : b),
      xs.reduce((a, b) => a > b ? a : b),
      ys.reduce((a, b) => a > b ? a : b),
    );
  }

  static _SvgBox? fromNumbers(List<double> numbers) {
    if (numbers.length < 2) return null;
    return _SvgBox.fromPoints(numbers);
  }

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get area => width <= 0 || height <= 0 ? 0 : width * height;

  _SvgBox union(_SvgBox other) {
    return _SvgBox(
      left < other.left ? left : other.left,
      top < other.top ? top : other.top,
      right > other.right ? right : other.right,
      bottom > other.bottom ? bottom : other.bottom,
    );
  }

  _SvgBox inflate(double value) {
    return _SvgBox(left - value, top - value, right + value, bottom + value);
  }

  _SvgBox? intersection(_SvgBox other) {
    final l = left > other.left ? left : other.left;
    final t = top > other.top ? top : other.top;
    final r = right < other.right ? right : other.right;
    final b = bottom < other.bottom ? bottom : other.bottom;
    if (r <= l || b <= t) return null;
    return _SvgBox(l, t, r, b);
  }
}
