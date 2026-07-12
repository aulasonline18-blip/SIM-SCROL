import 'sim_visual_identity.dart';

class PedagogicalVisualLayout {
  const PedagogicalVisualLayout({this.identity = SimVisualIdentity.standard});

  static const standard = PedagogicalVisualLayout();

  final SimVisualIdentity identity;

  List<String> wrapLabel(
    String text, {
    int maxCharsPerLine = 16,
    int maxLines = 2,
  }) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return const [''];
    final safeMaxChars = maxCharsPerLine < 4 ? 4 : maxCharsPerLine;
    final safeMaxLines = maxLines < 1 ? 1 : maxLines;
    final words = clean.split(' ');
    final lines = <String>[];
    var current = '';

    for (final word in words) {
      final safeWord = _fitToken(word, safeMaxChars);
      final candidate = current.isEmpty ? safeWord : '$current $safeWord';
      if (candidate.length <= safeMaxChars) {
        current = candidate;
        continue;
      }
      if (current.isNotEmpty) lines.add(current);
      current = safeWord;
      if (lines.length == safeMaxLines) break;
    }

    if (lines.length < safeMaxLines && current.isNotEmpty) {
      lines.add(current);
    }
    if (lines.isEmpty) lines.add(_fitToken(clean, safeMaxChars));

    final consumed = lines.join(' ').replaceAll('...', '').trim();
    final truncated =
        lines.length >= safeMaxLines && consumed.length < clean.length;
    if (truncated) {
      lines[lines.length - 1] = _markTruncated(lines.last, safeMaxChars);
    }
    return lines.take(safeMaxLines).toList(growable: false);
  }

  String compactLabel(String text, {int maxChars = 32}) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= maxChars) return clean;
    return _ellipsis(clean, maxChars);
  }

  List<double> evenlySpacedCenters({
    required int count,
    required double start,
    required double end,
  }) {
    if (count <= 0) return const [];
    if (count == 1) return [(start + end) / 2];
    final step = (end - start) / (count - 1);
    return List<double>.generate(count, (index) => start + step * index);
  }

  List<double> alternatingOffsets(
    int count, {
    double upper = -56,
    double lower = 72,
  }) {
    return List<double>.generate(
      count,
      (index) => index.isEven ? lower : upper,
    );
  }

  String svgText({
    required num x,
    required num y,
    required String text,
    required String attrs,
    String anchor = 'middle',
    String? fill,
    String? fontFamily,
    int maxCharsPerLine = 16,
    int maxLines = 2,
    double lineHeight = 22,
  }) {
    final lines = wrapLabel(
      text,
      maxCharsPerLine: maxCharsPerLine,
      maxLines: maxLines,
    );
    final fillAttr = fill == null ? '' : ' fill="$fill"';
    final resolvedFont = fontFamily ?? identity.fontFamily;
    if (lines.length == 1) {
      return '<text x="$x" y="$y" text-anchor="$anchor" '
          'font-family="$resolvedFont" $attrs$fillAttr>${_escapeXml(lines.first)}</text>';
    }
    final firstDy = -((lines.length - 1) * lineHeight / 2);
    final spans = <String>[];
    for (var i = 0; i < lines.length; i += 1) {
      final dy = i == 0 ? firstDy : lineHeight;
      spans.add(
        '<tspan x="$x" dy="${dy.toStringAsFixed(1)}">${_escapeXml(lines[i])}</tspan>',
      );
    }
    return '<text x="$x" y="$y" text-anchor="$anchor" '
        'font-family="$resolvedFont" $attrs$fillAttr>${spans.join()}</text>';
  }
}

String _fitToken(String token, int maxChars) {
  if (token.length <= maxChars) return token;
  return _ellipsis(token, maxChars);
}

String _ellipsis(String value, int maxChars) {
  if (maxChars <= 3) return '.'.padRight(maxChars, '.');
  final clean = value.trim();
  if (clean.length <= maxChars) return clean;
  return '${clean.substring(0, maxChars - 3).trimRight()}...';
}

String _markTruncated(String value, int maxChars) {
  final clean = value.trim();
  if (clean.endsWith('...')) return clean;
  if (clean.length + 3 <= maxChars) return '$clean...';
  return _ellipsis(clean, maxChars);
}

String _escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
