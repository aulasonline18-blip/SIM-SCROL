import 'dart:convert';

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
        lowered.contains('<foreignobject')) {
      return ImagePedagogicalCritique(
        accepted: false,
        reason: 'critic_svg_unsafe',
        textNodeCount: _textNodeCount(svg),
      );
    }
    final textNodes = _textNodeCount(svg);
    if (textNodes > maxTextNodes) {
      return ImagePedagogicalCritique(
        accepted: false,
        reason: 'critic_too_much_text',
        textNodeCount: textNodes,
      );
    }
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
    return ImagePedagogicalCritique(
      accepted: true,
      reason: 'critic_ok',
      textNodeCount: textNodes,
    );
  }

  int _textNodeCount(String svg) {
    return RegExp(r'<text\b', caseSensitive: false).allMatches(svg).length;
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
