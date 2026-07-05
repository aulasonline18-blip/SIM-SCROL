// Helpers compartilhados pelos templates matemáticos.
// Port fiel do src/cyber/math-templates/shared.ts do SIM Web.
import 'dart:math' as math;

const cyberBg = '#FFFFFF';
const cyberAxis = '#1a1a1a';
const cyberGrid = 'rgba(0,0,0,0.08)';
const cyberCurve = '#1a1a1a';
const cyberCurveAlt = '#5A6B7B';
const cyberAccent = '#374151';
const cyberCritical = '#111827';
const cyberGhost = 'rgba(0,0,0,0.55)';
const cyberLabel = '#0F172A';
const cyberMonoFont =
    'JetBrains Mono, ui-monospace, SFMono-Regular, Menlo, monospace';

const int canvasW = 800;
const int canvasH = 500;
const int plotX0 = 80;
const int plotX1 = 760;
const int plotY0 = 60;
const int plotY1 = 420;
const int plotW = 680; // plotX1 - plotX0
const int plotH = 360; // plotY1 - plotY0

class MathVisualPalette {
  const MathVisualPalette({
    this.background = cyberBg,
    this.axis = cyberAxis,
    this.grid = cyberGrid,
    this.curve = cyberCurve,
    this.accent = cyberAccent,
    this.critical = cyberCritical,
    this.ghost = cyberGhost,
    this.label = cyberLabel,
    this.badgeFill = 'rgba(255,255,255,0.92)',
  });

  final String background;
  final String axis;
  final String grid;
  final String curve;
  final String accent;
  final String critical;
  final String ghost;
  final String label;
  final String badgeFill;

  static MathVisualPalette? fromParams(Object? raw) {
    if (raw is! Map) return null;
    return MathVisualPalette(
      background: _safeColor(raw['background']) ?? cyberBg,
      axis: _safeColor(raw['axis']) ?? cyberAxis,
      grid: _safeColor(raw['grid']) ?? cyberGrid,
      curve: _safeColor(raw['curve']) ?? cyberCurve,
      accent: _safeColor(raw['accent']) ?? cyberAccent,
      critical: _safeColor(raw['critical']) ?? cyberCritical,
      ghost: _safeColor(raw['ghost']) ?? cyberGhost,
      label: _safeColor(raw['label']) ?? cyberLabel,
      badgeFill: _safeColor(raw['badgeFill']) ?? 'rgba(255,255,255,0.92)',
    );
  }
}

class MathVisualHierarchy {
  const MathVisualHierarchy({
    this.titleFontSize = 17,
    this.axisStrokeWidth = 1.8,
    this.gridStrokeWidth = 1.0,
    this.curveStrokeWidth = 4.2,
    this.pointOuterRadius = 10.5,
    this.pointInnerRadius = 5.8,
    this.labelFontSize = 12.5,
    this.axisLabelFontSize = 13.0,
    this.tickFontSize = 11.0,
    this.badgeStrokeWidth = 1.4,
  });

  final double titleFontSize;
  final double axisStrokeWidth;
  final double gridStrokeWidth;
  final double curveStrokeWidth;
  final double pointOuterRadius;
  final double pointInnerRadius;
  final double labelFontSize;
  final double axisLabelFontSize;
  final double tickFontSize;
  final double badgeStrokeWidth;

  static MathVisualHierarchy? fromParams(Object? raw) {
    if (raw is! Map) return null;
    return MathVisualHierarchy(
      titleFontSize: _safePositiveDouble(raw['titleFontSize']) ?? 17,
      axisStrokeWidth: _safePositiveDouble(raw['axisStrokeWidth']) ?? 1.8,
      gridStrokeWidth: _safePositiveDouble(raw['gridStrokeWidth']) ?? 1.0,
      curveStrokeWidth: _safePositiveDouble(raw['curveStrokeWidth']) ?? 4.2,
      pointOuterRadius: _safePositiveDouble(raw['pointOuterRadius']) ?? 10.5,
      pointInnerRadius: _safePositiveDouble(raw['pointInnerRadius']) ?? 5.8,
      labelFontSize: _safePositiveDouble(raw['labelFontSize']) ?? 12.5,
      axisLabelFontSize: _safePositiveDouble(raw['axisLabelFontSize']) ?? 13.0,
      tickFontSize: _safePositiveDouble(raw['tickFontSize']) ?? 11.0,
      badgeStrokeWidth: _safePositiveDouble(raw['badgeStrokeWidth']) ?? 1.4,
    );
  }
}

double? _safePositiveDouble(Object? raw) {
  if (raw is num && raw.isFinite && raw > 0) return raw.toDouble();
  return null;
}

String? _safeColor(Object? raw) {
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) return null;
  if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) return value;
  if (RegExp(
    r'^rgba\(\d{1,3},\d{1,3},\d{1,3},(?:0|1|0?\.\d+)\)$',
  ).hasMatch(value)) {
    return value;
  }
  return null;
}

class Scale {
  const Scale({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
  });
  final double xMin, xMax, yMin, yMax;

  double toX(double x) => plotX0 + ((x - xMin) / (xMax - xMin)) * plotW;
  double toY(double y) => plotY1 - ((y - yMin) / (yMax - yMin)) * plotH;
}

Scale makeScale(double xMin, double xMax, double yMin, double yMax) {
  double x0 = xMin, x1 = xMax, y0 = yMin, y1 = yMax;
  if (x1 == x0) x1 = x0 + 1;
  if (y1 == y0) y1 = y0 + 1;
  return Scale(xMin: x0, xMax: x1, yMin: y0, yMax: y1);
}

double niceStep(double range, {int targetTicks = 8}) {
  if (range <= 0) return 1;
  final rough = range / targetTicks;
  final exp = math.log(rough) / math.log(10);
  final pow = math.pow(10, exp.floor()).toDouble();
  final norm = rough / pow;
  double step;
  if (norm < 1.5) {
    step = 1;
  } else if (norm < 3) {
    step = 2;
  } else if (norm < 7) {
    step = 5;
  } else {
    step = 10;
  }
  return step * pow;
}

String escapeXml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String fmtNum(double n) {
  if (!n.isFinite) return '—';
  final abs = n.abs();
  if (abs == 0) return '0';
  if (abs >= 100) return n.toStringAsFixed(0);
  if (abs >= 10) return _trimZeros(n.toStringAsFixed(1));
  if (abs >= 1) return _trimZeros(n.toStringAsFixed(2));
  return _trimZeros(n.toStringAsFixed(3));
}

String _trimZeros(String s) {
  if (!s.contains('.')) return s;
  s = s.replaceAll(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

double _ceilToStep(double value, double step) {
  if (step <= 0) return value;
  return (value / step).ceil() * step;
}

String renderAxes(
  Scale s, {
  String? xLabel,
  String? yLabel,
  MathVisualPalette palette = const MathVisualPalette(),
  MathVisualHierarchy hierarchy = const MathVisualHierarchy(),
}) {
  final xStep = niceStep(s.xMax - s.xMin);
  final yStep = niceStep(s.yMax - s.yMin);
  final parts = <String>[];

  // Grid vertical
  for (double x = _ceilToStep(s.xMin, xStep); x <= s.xMax + 1e-9; x += xStep) {
    final px = s.toX(x);
    parts.add(
      '<line x1="${px.toStringAsFixed(2)}" y1="$plotY0" x2="${px.toStringAsFixed(2)}" y2="$plotY1" stroke="${palette.grid}" stroke-width="${hierarchy.gridStrokeWidth.toStringAsFixed(1)}"/>',
    );
  }
  for (double y = _ceilToStep(s.yMin, yStep); y <= s.yMax + 1e-9; y += yStep) {
    final py = s.toY(y);
    parts.add(
      '<line x1="$plotX0" y1="${py.toStringAsFixed(2)}" x2="$plotX1" y2="${py.toStringAsFixed(2)}" stroke="${palette.grid}" stroke-width="${hierarchy.gridStrokeWidth.toStringAsFixed(1)}"/>',
    );
  }

  final axisXd = (s.yMin <= 0 && s.yMax >= 0) ? s.toY(0) : plotY1.toDouble();
  final axisYd = (s.xMin <= 0 && s.xMax >= 0) ? s.toX(0) : plotX0.toDouble();
  final ax = axisXd.toStringAsFixed(2);
  final ay = axisYd.toStringAsFixed(2);

  parts.add(
    '<line x1="$plotX0" y1="$ax" x2="$plotX1" y2="$ax" stroke="${palette.axis}" stroke-width="${hierarchy.axisStrokeWidth.toStringAsFixed(1)}"/>',
  );
  parts.add(
    '<line x1="$ay" y1="$plotY0" x2="$ay" y2="$plotY1" stroke="${palette.axis}" stroke-width="${hierarchy.axisStrokeWidth.toStringAsFixed(1)}"/>',
  );

  // Setas
  parts.add(
    '<polygon points="$plotX1,$ax ${plotX1 - 10},${(axisXd - 5).toStringAsFixed(2)} ${plotX1 - 10},${(axisXd + 5).toStringAsFixed(2)}" fill="${palette.axis}"/>',
  );
  parts.add(
    '<polygon points="$ay,$plotY0 ${(axisYd - 5).toStringAsFixed(2)},${plotY0 + 10} ${(axisYd + 5).toStringAsFixed(2)},${plotY0 + 10}" fill="${palette.axis}"/>',
  );

  // Ticks eixo X
  for (double x = _ceilToStep(s.xMin, xStep); x <= s.xMax + 1e-9; x += xStep) {
    if (x.abs() < 1e-9 && s.xMin <= 0 && s.xMax >= 0) continue;
    final px = s.toX(x);
    parts.add(
      '<line x1="${px.toStringAsFixed(2)}" y1="${(axisXd - 4).toStringAsFixed(2)}" x2="${px.toStringAsFixed(2)}" y2="${(axisXd + 4).toStringAsFixed(2)}" stroke="${palette.axis}" stroke-width="${math.max(1.2, hierarchy.axisStrokeWidth - 0.4).toStringAsFixed(1)}"/>',
    );
    parts.add(
      '<text x="${px.toStringAsFixed(2)}" y="${(axisXd + 18).toStringAsFixed(2)}" fill="${palette.ghost}" font-family="$cyberMonoFont" font-size="${hierarchy.tickFontSize.toStringAsFixed(1)}" text-anchor="middle">${fmtNum(x)}</text>',
    );
  }
  // Ticks eixo Y
  for (double y = _ceilToStep(s.yMin, yStep); y <= s.yMax + 1e-9; y += yStep) {
    if (y.abs() < 1e-9 && s.yMin <= 0 && s.yMax >= 0) continue;
    final py = s.toY(y);
    parts.add(
      '<line x1="${(axisYd - 4).toStringAsFixed(2)}" y1="${py.toStringAsFixed(2)}" x2="${(axisYd + 4).toStringAsFixed(2)}" y2="${py.toStringAsFixed(2)}" stroke="${palette.axis}" stroke-width="${math.max(1.2, hierarchy.axisStrokeWidth - 0.4).toStringAsFixed(1)}"/>',
    );
    parts.add(
      '<text x="${(axisYd - 8).toStringAsFixed(2)}" y="${(py + 4).toStringAsFixed(2)}" fill="${palette.ghost}" font-family="$cyberMonoFont" font-size="${hierarchy.tickFontSize.toStringAsFixed(1)}" text-anchor="end">${fmtNum(y)}</text>',
    );
  }

  if (xLabel != null) {
    parts.add(
      '<text x="${plotX1 + 6}" y="${(axisXd + 4).toStringAsFixed(2)}" fill="${palette.label}" font-family="$cyberMonoFont" font-size="${hierarchy.axisLabelFontSize.toStringAsFixed(1)}" font-weight="700">${escapeXml(xLabel)}</text>',
    );
  }
  if (yLabel != null) {
    parts.add(
      '<text x="${(axisYd - 4).toStringAsFixed(2)}" y="${plotY0 - 12}" fill="${palette.label}" font-family="$cyberMonoFont" font-size="${hierarchy.axisLabelFontSize.toStringAsFixed(1)}" font-weight="700" text-anchor="end">${escapeXml(yLabel)}</text>',
    );
  }

  return parts.join('');
}

String labelTag(
  double cx,
  double cy,
  String text, {
  String? color,
  String? bg,
  String anchor = 'center',
  MathVisualHierarchy hierarchy = const MathVisualHierarchy(),
}) {
  final c = color ?? cyberLabel;
  final b = bg ?? 'rgba(255,255,255,0.92)';
  final safeText = _fitMathLabel(text, maxChars: 28);
  const padX = 8.0;
  const h = 22.0;
  const charW = 7.2;
  final w = math.max(28.0, safeText.length * charW + padX * 2);
  double x = cx - w / 2;
  double y = cy - h / 2;
  if (anchor == 'above') {
    y = cy - h - 12;
  } else if (anchor == 'below') {
    y = cy + 12;
  } else if (anchor == 'right') {
    x = cx + 12;
    y = cy - h / 2;
  } else if (anchor == 'left') {
    x = cx - w - 12;
    y = cy - h / 2;
  }
  return '''
    <g>
      <rect x="${x.toStringAsFixed(2)}" y="${y.toStringAsFixed(2)}" width="${w.toStringAsFixed(2)}" height="${h.toStringAsFixed(2)}" rx="6" ry="6" fill="$b" stroke="$c" stroke-width="1.2" stroke-opacity="0.9"/>
      <text x="${(x + w / 2).toStringAsFixed(2)}" y="${(y + h / 2 + 4).toStringAsFixed(2)}" fill="$c" font-family="$cyberMonoFont" font-size="${hierarchy.labelFontSize.toStringAsFixed(1)}" font-weight="700" text-anchor="middle">${escapeXml(safeText)}</text>
    </g>''';
}

String highlightPoint(
  double cx,
  double cy, {
  String color = cyberCritical,
  MathVisualHierarchy hierarchy = const MathVisualHierarchy(),
}) {
  return '''
    <circle cx="${cx.toStringAsFixed(2)}" cy="${cy.toStringAsFixed(2)}" r="${hierarchy.pointOuterRadius.toStringAsFixed(1)}" fill="$color" fill-opacity="0.15"/>
    <circle cx="${cx.toStringAsFixed(2)}" cy="${cy.toStringAsFixed(2)}" r="${hierarchy.pointInnerRadius.toStringAsFixed(1)}" fill="$color" stroke="#FFFFFF" stroke-width="1.5"/>''';
}

String wrapSvg(
  String? title,
  String body, {
  MathVisualPalette palette = const MathVisualPalette(),
  MathVisualHierarchy hierarchy = const MathVisualHierarchy(),
}) {
  final titleNode = title != null && title.isNotEmpty
      ? '<text x="${canvasW / 2}" y="32" fill="${palette.label}" font-family="$cyberMonoFont" font-size="${hierarchy.titleFontSize.toStringAsFixed(1)}" font-weight="800" text-anchor="middle" letter-spacing="0.5">${escapeXml(title)}</text>'
      : '';
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $canvasW $canvasH" width="100%" height="auto" role="img">\n'
      '  <rect x="0" y="0" width="$canvasW" height="$canvasH" fill="${palette.background}"/>\n'
      '  $titleNode\n'
      '  $body\n'
      '</svg>';
}

String equationBadge(
  String text, {
  double minW = 120,
  MathVisualPalette palette = const MathVisualPalette(),
  MathVisualHierarchy hierarchy = const MathVisualHierarchy(),
}) {
  const x = plotX1 - 10.0;
  const y = plotY0 + 6.0;
  final safeText = _fitMathLabel(text, maxChars: 34);
  final w = math.max(minW, safeText.length * 8.2 + 24);
  return '''
    <g>
      <rect x="${(x - w).toStringAsFixed(2)}" y="${y.toStringAsFixed(2)}" width="${w.toStringAsFixed(2)}" height="26" rx="6" fill="${palette.badgeFill}" stroke="${palette.curve}" stroke-width="${hierarchy.badgeStrokeWidth.toStringAsFixed(1)}" stroke-opacity="0.6"/>
      <text x="${(x - w / 2).toStringAsFixed(2)}" y="${(y + 17).toStringAsFixed(2)}" fill="${palette.label}" font-family="$cyberMonoFont" font-size="12" font-weight="600" text-anchor="middle">${escapeXml(safeText)}</text>
    </g>''';
}

String _fitMathLabel(String text, {required int maxChars}) {
  final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (clean.length <= maxChars) return clean;
  if (maxChars <= 3) return '.'.padRight(maxChars, '.');
  return '${clean.substring(0, maxChars - 3).trimRight()}...';
}

String fmt(double n) {
  if (!n.isFinite) return '—';
  final r = (n * 100).round() / 100;
  if (r == r.roundToDouble()) return r.toInt().toString();
  return _trimZeros(r.toStringAsFixed(2));
}
