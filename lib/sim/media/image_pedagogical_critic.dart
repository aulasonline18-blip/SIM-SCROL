class ImagePedagogicalCritique {
  const ImagePedagogicalCritique({
    required this.accepted,
    required this.reason,
    this.textNodeCount = 0,
    this.shapeCount = 0,
  });

  final bool accepted;
  final String reason;
  final int textNodeCount;
  final int shapeCount;
}

class ImagePedagogicalCritic {
  const ImagePedagogicalCritic();

  ImagePedagogicalCritique evaluateSvgDataUrl(String? dataUrl) {
    final svg = _decodeSvgDataUrl(dataUrl);
    if (svg == null) {
      return const ImagePedagogicalCritique(
        accepted: false,
        reason: 'invalid_svg_data_url',
      );
    }
    final lower = svg.toLowerCase();
    if (!lower.trimLeft().startsWith('<svg') || !lower.contains('</svg>')) {
      return const ImagePedagogicalCritique(
        accepted: false,
        reason: 'missing_svg_root',
      );
    }
    if (lower.contains('<script') ||
        lower.contains('<foreignobject') ||
        lower.contains('javascript:') ||
        RegExp(r'\son[a-z]+\s*=').hasMatch(lower)) {
      return const ImagePedagogicalCritique(
        accepted: false,
        reason: 'unsafe_svg',
      );
    }
    if (!lower.contains('viewbox=')) {
      return const ImagePedagogicalCritique(
        accepted: false,
        reason: 'missing_viewbox',
      );
    }
    final textNodes = RegExp(
      r'<text\b',
      caseSensitive: false,
    ).allMatches(svg).length;
    final shapeCount = RegExp(
      r'<(rect|circle|ellipse|line|path|polyline|polygon)\b',
      caseSensitive: false,
    ).allMatches(svg).length;
    if (shapeCount < 2 && textNodes < 2) {
      return ImagePedagogicalCritique(
        accepted: false,
        reason: 'too_sparse',
        textNodeCount: textNodes,
        shapeCount: shapeCount,
      );
    }
    if (textNodes > 28) {
      return ImagePedagogicalCritique(
        accepted: false,
        reason: 'too_text_heavy',
        textNodeCount: textNodes,
        shapeCount: shapeCount,
      );
    }
    return ImagePedagogicalCritique(
      accepted: true,
      reason: 'accepted',
      textNodeCount: textNodes,
      shapeCount: shapeCount,
    );
  }
}

String? _decodeSvgDataUrl(String? value) {
  if (value == null) return null;
  const utf8Prefix = 'data:image/svg+xml;utf8,';
  const encodedPrefix = 'data:image/svg+xml;charset=utf-8,';
  final trimmed = value.trim();
  if (trimmed.startsWith(utf8Prefix)) {
    return Uri.decodeComponent(trimmed.substring(utf8Prefix.length));
  }
  if (trimmed.toLowerCase().startsWith(encodedPrefix)) {
    return Uri.decodeComponent(trimmed.substring(encodedPrefix.length));
  }
  return null;
}
