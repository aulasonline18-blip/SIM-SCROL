import 'pedagogical_visual_hierarchy.dart';
import 'pedagogical_visual_layout.dart';
import 'pedagogical_visual_palette.dart';
import 'sim_visual_identity.dart';

class PedagogicalVisualComponents {
  const PedagogicalVisualComponents({
    this.layout = PedagogicalVisualLayout.standard,
    this.hierarchy = PedagogicalVisualHierarchy.standard,
    this.identity = SimVisualIdentity.standard,
  });

  static const standard = PedagogicalVisualComponents();

  final PedagogicalVisualLayout layout;
  final PedagogicalVisualHierarchy hierarchy;
  final SimVisualIdentity identity;

  String text({
    required num x,
    required num y,
    required String text,
    required PedagogicalVisualHierarchyRole role,
    String anchor = 'middle',
    String? fill,
    int maxCharsPerLine = 16,
    int maxLines = 2,
    double lineHeight = 22,
  }) {
    return layout.svgText(
      x: x,
      y: y,
      text: text,
      attrs: hierarchy.textAttrs(role),
      anchor: anchor,
      fill: fill,
      maxCharsPerLine: maxCharsPerLine,
      maxLines: maxLines,
      lineHeight: lineHeight,
    );
  }

  String title(
    String title,
    PedagogicalVisualPalette palette, {
    num x = 450,
    num y = 58,
  }) {
    return layout.svgText(
      x: x,
      y: y,
      text: title,
      attrs:
          'font-size="${identity.titleFontSize}" font-weight="${identity.titleFontWeight}"',
      fill: palette.text,
      maxCharsPerLine: identity.titleMaxCharsPerLine,
      maxLines: identity.titleMaxLines,
      lineHeight: identity.titleLineHeight.toDouble(),
    );
  }

  String caption({
    required num x,
    required num y,
    required String text,
    required PedagogicalVisualPalette palette,
    int maxCharsPerLine = 46,
  }) {
    return this.text(
      x: x,
      y: y,
      text: text,
      role: PedagogicalVisualHierarchyRole.conclusion,
      fill: palette.mutedText,
      maxCharsPerLine: maxCharsPerLine,
      maxLines: 2,
      lineHeight: identity.captionLineHeight.toDouble(),
    );
  }

  String arrowMarker({
    String id = 'arrow',
    required PedagogicalVisualPalette palette,
    int? markerWidth,
    int? markerHeight,
    int? refX,
    int? refY,
  }) {
    final width = markerWidth ?? identity.arrowMarkerSize;
    final height = markerHeight ?? identity.arrowMarkerSize;
    final markerRefX = refX ?? identity.arrowMarkerRefX;
    final markerRefY = refY ?? identity.arrowMarkerRefY;
    return '''
<marker id="$id" markerWidth="$width" markerHeight="$height" refX="$markerRefX" refY="$markerRefY" orient="auto">
  <path d="M2 2 L$markerRefX $markerRefY L2 ${height - 2} Z" fill="${palette.connector}"/>
</marker>''';
  }

  String semanticBox({
    required num x,
    required num y,
    required num width,
    required num height,
    required PedagogicalVisualPalette palette,
    required PedagogicalVisualRole fillRole,
    required PedagogicalVisualHierarchyRole hierarchyRole,
    bool includeStroke = true,
  }) {
    final strokeAttrs = includeStroke
        ? ' stroke="${palette.strokeFor(fillRole)}" ${hierarchy.strokeAttrs(hierarchyRole)}'
        : ' ${hierarchy.strokeAttrs(hierarchyRole)}';
    return '<rect x="$x" y="$y" width="$width" height="$height" '
        'rx="${hierarchy.radius(hierarchyRole)}" '
        'fill="${palette.fillFor(fillRole)}"$strokeAttrs/>';
  }

  String semanticCircle({
    required num cx,
    required num cy,
    required num r,
    required PedagogicalVisualPalette palette,
    required PedagogicalVisualRole fillRole,
    required PedagogicalVisualHierarchyRole hierarchyRole,
  }) {
    return '<circle cx="$cx" cy="$cy" r="$r" '
        'fill="${palette.fillFor(fillRole)}" '
        'stroke="${palette.strokeFor(fillRole)}" '
        '${hierarchy.strokeAttrs(hierarchyRole)}/>';
  }

  String connectorGroup({
    required PedagogicalVisualPalette palette,
    required Iterable<String> paths,
    String? markerId,
    PedagogicalVisualHierarchyRole role =
        PedagogicalVisualHierarchyRole.connector,
  }) {
    final marker = markerId == null ? '' : ' marker-end="url(#$markerId)"';
    return '''
<g stroke="${palette.connector}" ${hierarchy.strokeAttrs(role)} fill="none"$marker>
  ${paths.join('\n  ')}
</g>''';
  }

  String badge({
    required num x,
    required num y,
    required String label,
    required PedagogicalVisualPalette palette,
  }) {
    return '<text x="$x" y="$y" font-family="${identity.fontFamily}" '
        'font-size="${identity.badgeFontSize}" font-weight="${identity.badgeFontWeight}" '
        'fill="${palette.mutedText}">$label</text>';
  }
}
