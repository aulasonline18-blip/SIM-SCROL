import 'pedagogical_visual_hierarchy.dart';
import 'pedagogical_visual_palette.dart';

class SimVisualIdentity {
  const SimVisualIdentity();

  static const standard = SimVisualIdentity();

  String get fontFamily => 'Inter, Arial, sans-serif';
  String get monoFontFamily => 'JetBrains Mono, Consolas, monospace';

  int get canvasWidth => 900;
  int get canvasHeightDefault => 560;
  int get canvasHeightCompact => 520;
  int get canvasHeightWide => 540;

  int get titleX => 450;
  int get titleY => 58;
  int get titleFontSize => 30;
  int get titleFontWeight => 800;
  int get titleLineHeight => 34;
  int get titleMaxCharsPerLine => 38;
  int get titleMaxLines => 2;

  int get badgeFontSize => 16;
  int get badgeFontWeight => 800;
  int get captionLineHeight => 24;
  int get defaultTextLineHeight => 22;

  int get arrowMarkerSize => 12;
  int get arrowMarkerRefX => 10;
  int get arrowMarkerRefY => 6;
  int get largeArrowMarkerSize => 14;
  int get largeArrowMarkerRefX => 12;
  int get largeArrowMarkerRefY => 7;

  String canvasBackground(PedagogicalVisualPalette palette) {
    return '<rect width="$canvasWidth" height="$canvasHeightDefault" fill="${palette.background}"/>';
  }

  String compactCanvasBackground(PedagogicalVisualPalette palette) {
    return '<rect width="$canvasWidth" height="$canvasHeightCompact" fill="${palette.background}"/>';
  }

  String wideCanvasBackground(PedagogicalVisualPalette palette) {
    return '<rect width="$canvasWidth" height="$canvasHeightWide" fill="${palette.background}"/>';
  }

  String fontGroupAttrs(PedagogicalVisualPalette palette) {
    return 'font-family="$fontFamily" fill="${palette.text}"';
  }

  String strokeBaseAttrs(PedagogicalVisualHierarchy hierarchy) {
    return 'stroke-linecap="round" stroke-linejoin="round" ${hierarchy.strokeAttrs(PedagogicalVisualHierarchyRole.connector)}';
  }

  String cardShadow({String id = 'simCardShadow'}) {
    return '''
<defs>
  <filter id="$id" x="-8%" y="-8%" width="116%" height="116%">
    <feDropShadow dx="0" dy="8" stdDeviation="10" flood-color="#0F172A" flood-opacity="0.10"/>
  </filter>
</defs>''';
  }

  String softSurfaceAttrs() => 'filter="url(#simCardShadow)"';
}
