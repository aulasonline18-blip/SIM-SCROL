import 'pedagogical_visual_palette.dart';

class SimVisualIdentity {
  const SimVisualIdentity();

  static const standard = SimVisualIdentity();

  String get fontFamily => 'Inter, Arial, sans-serif';
  int get titleFontSize => 28;
  String get titleFontWeight => '800';
  int get titleMaxCharsPerLine => 42;
  int get titleMaxLines => 2;
  int get titleLineHeight => 32;
  int get captionLineHeight => 18;
  int get defaultTextLineHeight => 22;
  int get badgeFontSize => 12;
  String get badgeFontWeight => '800';
  int get arrowMarkerSize => 10;
  int get arrowMarkerRefX => 8;
  int get arrowMarkerRefY => 5;
  int get largeArrowMarkerSize => 14;
  int get largeArrowMarkerRefX => 12;
  int get largeArrowMarkerRefY => 6;
  int get canvasHeightCompact => 420;
  int get canvasHeightWide => 560;

  String fontGroupAttrs(PedagogicalVisualPalette palette) =>
      'font-family="$fontFamily" fill="${palette.text}"';

  String canvasBackground(PedagogicalVisualPalette palette) =>
      '''
<rect width="900" height="560" fill="${palette.background}"/>
<rect x="34" y="34" width="832" height="492" rx="22" fill="${palette.surface}" stroke="${palette.border}" stroke-width="1.4"/>
''';

  String compactCanvasBackground(PedagogicalVisualPalette palette) =>
      '''
<rect width="900" height="420" fill="${palette.background}"/>
<rect x="34" y="30" width="832" height="360" rx="20" fill="${palette.surface}" stroke="${palette.border}" stroke-width="1.4"/>
''';

  String wideCanvasBackground(PedagogicalVisualPalette palette) =>
      canvasBackground(palette);
}
