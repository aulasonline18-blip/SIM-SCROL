import 'dart:convert';

const int maxLessonSvgBytes = 64 * 1024;

String? safeLessonSvgFromDataUrl(String data) {
  final trimmed = data.trim();
  final comma = trimmed.indexOf(',');
  if (comma <= 0) return null;
  final header = trimmed.substring(0, comma).toLowerCase();
  if (!header.startsWith('data:image/svg+xml')) return null;
  final payload = trimmed.substring(comma + 1);
  String svg;
  try {
    svg = header.contains(';base64')
        ? utf8.decode(base64Decode(payload))
        : Uri.decodeComponent(payload);
  } catch (_) {
    return null;
  }
  return safeLessonSvg(svg);
}

String? safeLessonSvg(String raw) {
  final svg = raw.trim();
  if (svg.isEmpty || utf8.encode(svg).length > maxLessonSvgBytes) return null;
  final lower = svg.toLowerCase();
  if (!lower.startsWith('<svg') || !lower.contains('</svg>')) return null;
  if (_hasUnsafeSvgContent(svg)) return null;
  return svg;
}

bool isSafeLessonSvgDataUrl(String data) =>
    safeLessonSvgFromDataUrl(data) != null;

bool _hasUnsafeSvgContent(String svg) {
  final lower = svg.toLowerCase();
  const blockedTags = [
    'script',
    'foreignobject',
    'iframe',
    'object',
    'embed',
    'link',
    'meta',
    'base',
    'form',
    'input',
    'button',
    'textarea',
    'video',
    'audio',
    'canvas',
    'image',
  ];
  for (final tag in blockedTags) {
    if (RegExp('<\\s*/?\\s*$tag\\b', caseSensitive: false).hasMatch(svg)) {
      return true;
    }
  }
  final blockedPatterns = [
    RegExp(r'\son[a-z0-9_-]+\s*=', caseSensitive: false),
    RegExp(r'javascript\s*:', caseSensitive: false),
    RegExp(r'@import\b', caseSensitive: false),
    RegExp(
      r"""url\s*\(\s*["']?\s*(?:https?:|//|data:)""",
      caseSensitive: false,
    ),
    RegExp(
      r"""(?:href|xlink:href|src)\s*=\s*["']\s*(?:https?:|//|data:|javascript:)""",
      caseSensitive: false,
    ),
  ];
  return blockedPatterns.any((pattern) => pattern.hasMatch(lower));
}
