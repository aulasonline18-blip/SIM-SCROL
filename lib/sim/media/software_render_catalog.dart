import 'package:flutter/foundation.dart';

import 'blueprint_prompt.dart';
import 'math_templates/math_templates.dart';
import 'pedagogical_visual_components.dart';
import 'pedagogical_visual_hierarchy.dart';
import 'pedagogical_visual_level.dart';
import 'pedagogical_visual_palette.dart';
import 's12_visual_pipeline.dart' show sanitizeAndEncodeSvg;
import 'sim_visual_identity.dart';
import 'visual_pedagogical_role.dart';
import 'visual_router_n2.dart';

const _visualComponents = PedagogicalVisualComponents.standard;
const _simIdentity = SimVisualIdentity.standard;

String _vhStroke(PedagogicalVisualHierarchyRole role) =>
    _visualComponents.hierarchy.strokeAttrs(role);

int _vhRadius(PedagogicalVisualHierarchyRole role) =>
    _visualComponents.hierarchy.radius(role);

String _layoutText(
  num x,
  num y,
  String text,
  PedagogicalVisualHierarchyRole role, {
  String anchor = 'middle',
  String? fill,
  int maxCharsPerLine = 16,
  int maxLines = 2,
  double lineHeight = 22,
}) {
  return _visualComponents.text(
    x: x,
    y: y,
    text: text,
    role: role,
    anchor: anchor,
    fill: fill,
    maxCharsPerLine: maxCharsPerLine,
    maxLines: maxLines,
    lineHeight: lineHeight,
  );
}

String _titleText(
  String title,
  PedagogicalVisualPalette palette, {
  num y = 58,
}) {
  return _visualComponents.title(title, palette, y: y);
}

String _captionText(
  num x,
  num y,
  String text,
  PedagogicalVisualPalette palette, {
  int maxCharsPerLine = 46,
}) {
  return _visualComponents.caption(
    x: x,
    y: y,
    text: text,
    palette: palette,
    maxCharsPerLine: maxCharsPerLine,
  );
}

String _arrowMarker(
  PedagogicalVisualPalette palette, {
  int? markerWidth,
  int? markerHeight,
  int? refX,
  int? refY,
}) {
  return _visualComponents.arrowMarker(
    palette: palette,
    markerWidth: markerWidth,
    markerHeight: markerHeight,
    refX: refX,
    refY: refY,
  );
}

String _fontGroup(PedagogicalVisualPalette palette) {
  return _simIdentity.fontGroupAttrs(palette);
}

String _canvasBackground(PedagogicalVisualPalette palette, {int height = 560}) {
  if (height == _simIdentity.canvasHeightCompact) {
    return _simIdentity.compactCanvasBackground(palette);
  }
  if (height == _simIdentity.canvasHeightWide) {
    return _simIdentity.wideCanvasBackground(palette);
  }
  return _simIdentity.canvasBackground(palette);
}

String _roleBox({
  required num x,
  required num y,
  required num width,
  required num height,
  required PedagogicalVisualPalette palette,
  required PedagogicalVisualRole fillRole,
  required PedagogicalVisualHierarchyRole hierarchyRole,
  bool includeStroke = true,
}) {
  return _visualComponents.semanticBox(
    x: x,
    y: y,
    width: width,
    height: height,
    palette: palette,
    fillRole: fillRole,
    hierarchyRole: hierarchyRole,
    includeStroke: includeStroke,
  );
}

String _domainBadgeText(
  _VisualKnowledgeDomain domain,
  PedagogicalVisualPalette palette,
) {
  return _visualComponents.badge(
    x: 90,
    y: 118,
    label: _domainBadge(domain).toUpperCase(),
    palette: palette,
  );
}

PedagogicalVisualLevelProfile _visualLevel(SoftwareVisualRequest request) {
  return PedagogicalVisualLevelProfile.fromAcademicLevel(request.academicLevel);
}

String _levelDetailStrip(
  SoftwareVisualRequest request,
  PedagogicalVisualPalette palette, {
  num y = 438,
  int skipPrimary = 3,
}) {
  final level = _visualLevel(request);
  if (!level.showDetailStrip || level.detailSlots <= 0) return '';
  final details = _contextDetailLabels(
    request,
    skip: skipPrimary,
    count: level.detailSlots,
  );
  if (details.isEmpty) return '';

  final centers = _visualComponents.layout.evenlySpacedCenters(
    count: details.length,
    start: 185,
    end: 715,
  );
  final parts = <String>[
    '<g ${_fontGroup(palette)} data-visual-level="${level.label}">',
  ];
  for (var i = 0; i < details.length; i += 1) {
    final x = centers[i];
    parts.add(
      '<rect x="${(x - 86).toStringAsFixed(1)}" y="${(y - 22).toStringAsFixed(1)}" width="172" height="44" rx="${_vhRadius(PedagogicalVisualHierarchyRole.example)}" fill="${palette.fillFor(PedagogicalVisualRole.neutral)}" stroke="${palette.strokeFor(PedagogicalVisualRole.neutral)}" ${_vhStroke(PedagogicalVisualHierarchyRole.example)}/>',
    );
    parts.add(
      _layoutText(
        x,
        y + 7,
        details[i],
        PedagogicalVisualHierarchyRole.example,
        maxCharsPerLine: level.labelMaxChars,
        maxLines: level.maxTextLines,
        lineHeight: _simIdentity.defaultTextLineHeight.toDouble(),
      ),
    );
  }
  parts.add('</g>');
  return parts.join('\n');
}

class SoftwareVisualRequest {
  const SoftwareVisualRequest({
    required this.n2,
    this.topic,
    this.visualType,
    this.imagePrompt,
    this.colorLegend = const [],
    this.keyElements = const [],
    this.highlightFocus,
    this.complexity,
    this.pedagogicalNeed,
    this.academicLevel,
    this.pedagogicalGoal,
  });

  final VisualN2Result n2;
  final String? topic;
  final String? visualType;
  final String? imagePrompt;
  final List<BlueprintColorLegendItem> colorLegend;
  final List<String> keyElements;
  final String? highlightFocus;
  final String? complexity;
  final String? pedagogicalNeed;
  final String? academicLevel;
  final String? pedagogicalGoal;

  String get text => [topic, visualType, imagePrompt]
      .where((value) => value != null && value.trim().isNotEmpty)
      .join(' ')
      .toLowerCase();

  String get domainText =>
      [
            topic,
            visualType,
            imagePrompt,
            highlightFocus,
            pedagogicalGoal,
            academicLevel,
            pedagogicalNeed,
            complexity,
            ...keyElements,
          ]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join(' ')
          .toLowerCase();

  _VisualKnowledgeDomain get _domain => _inferKnowledgeDomain(domainText);

  VisualPedagogicalRole get role => inferVisualPedagogicalRole(
    topic: topic,
    visualType: visualType,
    imagePrompt: imagePrompt,
  );
}

class SoftwareRenderResult {
  const SoftwareRenderResult({
    required this.dataUrl,
    required this.renderer,
    required this.role,
  });

  final String dataUrl;
  final String renderer;
  final VisualPedagogicalRole role;
}

abstract class SoftwareVisualRenderer {
  const SoftwareVisualRenderer();

  String get name;
  VisualPedagogicalRole get role;
  bool accepts(SoftwareVisualRequest request);
  String? render(SoftwareVisualRequest request);
}

class SoftwareRenderCatalog {
  const SoftwareRenderCatalog();

  static const List<SoftwareVisualRenderer> _renderers = [
    _QuadraticRenderer(),
    _LinearRenderer(),
    _UnitCircleRenderer(),
    _ForceDiagramRenderer(),
    _CircuitRenderer(),
    _SyntaxTreeRenderer(),
    _FoodChainRenderer(),
    _TimelineRenderer(),
    _ProgrammingFlowRenderer(),
    _ChemistryReactionRenderer(),
    _GeographyLayersRenderer(),
    _LogicArgumentRenderer(),
    _BusinessFlowRenderer(),
    _FlowchartRenderer(),
    _ComparisonRenderer(),
    _CycleRenderer(),
    _TableRenderer(),
    _ConceptMapRenderer(),
  ];

  SoftwareRenderResult? render(SoftwareVisualRequest request) {
    final text = request.text.trim();
    if (text.isEmpty) return null;
    if (request.n2.verdict == VisualVerdict.ai ||
        request.n2.verdict == VisualVerdict.noImage) {
      return null;
    }
    if (request.n2.verdict == VisualVerdict.ambiguous &&
        request.n2.reason == 'N2_KEYWORDS_BOTH') {
      return null;
    }

    for (final renderer in _renderers) {
      if (!renderer.accepts(request)) continue;
      final dataUrl = renderer.render(request);
      if (dataUrl == null) continue;
      if (kDebugMode) {
        debugPrint(
          '[SOFTWARE_RENDER] renderer=${renderer.name} '
          'role=${renderer.role.id} n2=${request.n2.verdict.name}/${request.n2.reason}',
        );
      }
      return SoftwareRenderResult(
        dataUrl: dataUrl,
        renderer: renderer.name,
        role: renderer.role,
      );
    }
    return null;
  }
}

enum _VisualKnowledgeDomain {
  mathematics,
  physics,
  chemistry,
  biology,
  history,
  geography,
  programming,
  grammar,
  logic,
  business,
  unknown,
}

_VisualKnowledgeDomain _inferKnowledgeDomain(String text) {
  if (_containsAny(text, const [
    'programação',
    'programacao',
    'programming',
    'algoritmo',
    'algorithm',
    'código',
    'codigo',
    'code',
    'loop',
    'debug',
    'entrada processamento saída',
    'entrada processamento saida',
  ])) {
    return _VisualKnowledgeDomain.programming;
  }
  if (_containsAny(text, const [
    'gramática',
    'gramatica',
    'grammar',
    'sujeito',
    'predicado',
    'oração',
    'oracao',
    'classe gramatical',
    'análise sintática',
    'analise sintatica',
  ])) {
    return _VisualKnowledgeDomain.grammar;
  }
  if (_containsAny(text, const [
    'lógica',
    'logica',
    'logic',
    'premissa',
    'premise',
    'conclusão',
    'conclusao',
    'conclusion',
    'proposição',
    'proposicao',
    'tabela verdade',
    'truth table',
    'silogismo',
    'inferência',
    'inferencia',
  ])) {
    return _VisualKnowledgeDomain.logic;
  }
  if (_containsAny(text, const [
    'química',
    'quimica',
    'chemistry',
    'reação',
    'reacao',
    'reaction',
    'molécula',
    'molecula',
    'molecule',
    'átomo',
    'atomo',
    'atom',
    'ligação',
    'ligacao',
    'reagente',
    'produto',
    'ácido',
    'acido',
    'base',
    'ph',
  ])) {
    return _VisualKnowledgeDomain.chemistry;
  }
  if (_containsAny(text, const [
    'economia',
    'economics',
    'negócio',
    'negocio',
    'business',
    'oferta',
    'demanda',
    'mercado',
    'receita',
    'custo',
    'lucro',
    'preço',
    'preco',
    'fluxo de caixa',
    'valor',
  ])) {
    return _VisualKnowledgeDomain.business;
  }
  if (!_containsAny(text, const [
        'mapa conceitual',
        'concept map',
        'mind map',
        'mapa mental',
      ]) &&
      _containsAny(text, const [
        'geografia',
        'geography',
        'mapa',
        'relevo',
        'clima',
        'região',
        'regiao',
        'território',
        'territorio',
        'latitude',
        'longitude',
        'erosão',
        'erosao',
        'migração',
        'migracao',
      ])) {
    return _VisualKnowledgeDomain.geography;
  }
  if (_containsAny(text, const [
    'física',
    'fisica',
    'physics',
    'força',
    'forca',
    'force',
    'circuito',
    'energia',
    'velocidade',
    'aceleração',
    'aceleracao',
    'vetor',
    'newton',
    'ohm',
  ])) {
    return _VisualKnowledgeDomain.physics;
  }
  if (_containsAny(text, const [
    'biologia',
    'biology',
    'célula',
    'celula',
    'organismo',
    'cadeia alimentar',
    'fotossíntese',
    'fotossintese',
    'dna',
    'ecossistema',
    'respiração celular',
    'respiracao celular',
  ])) {
    return _VisualKnowledgeDomain.biology;
  }
  if (_containsAny(text, const [
    'história',
    'historia',
    'history',
    'revolução',
    'revolucao',
    'guerra',
    'século',
    'seculo',
    'império',
    'imperio',
    'cronologia',
    'linha do tempo',
    'evento histórico',
    'evento historico',
  ])) {
    return _VisualKnowledgeDomain.history;
  }
  if (_containsAny(text, const [
    'matemática',
    'matematica',
    'math',
    'função',
    'funcao',
    'equação',
    'equacao',
    'gráfico',
    'grafico',
    'parábola',
    'parabola',
    'álgebra',
    'algebra',
    'geometria',
    'f(x)',
    'y =',
  ])) {
    return _VisualKnowledgeDomain.mathematics;
  }
  return _VisualKnowledgeDomain.unknown;
}

String _domainBadge(_VisualKnowledgeDomain domain) {
  switch (domain) {
    case _VisualKnowledgeDomain.mathematics:
      return 'matemática';
    case _VisualKnowledgeDomain.physics:
      return 'física';
    case _VisualKnowledgeDomain.chemistry:
      return 'química';
    case _VisualKnowledgeDomain.biology:
      return 'biologia';
    case _VisualKnowledgeDomain.history:
      return 'história';
    case _VisualKnowledgeDomain.geography:
      return 'geografia';
    case _VisualKnowledgeDomain.programming:
      return 'programação';
    case _VisualKnowledgeDomain.grammar:
      return 'gramática';
    case _VisualKnowledgeDomain.logic:
      return 'lógica';
    case _VisualKnowledgeDomain.business:
      return 'economia';
    case _VisualKnowledgeDomain.unknown:
      return 'aula';
  }
}

class _QuadraticRenderer extends SoftwareVisualRenderer {
  const _QuadraticRenderer();

  @override
  String get name => 'QuadraticRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.graphReasoning;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return _containsAny(request.text, const [
      'parábola',
      'parabola',
      'quadratic',
      'quadrática',
      'quadratica',
      'função quadrática',
      'funcao quadratica',
    ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final text = request.text;
    final formula = _extractFormula(text);
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    if (formula != null) {
      final exact = tryRenderMathTemplate({
        'math_template': {
          'name': 'custom',
          'params': {
            'formula': formula,
            'x_min': -5,
            'x_max': 5,
            'labels': {
              'title': 'Parábola',
              'vertex': 'vértice',
              'x': 'x',
              'y': 'y',
            },
            'visual_palette': _mathVisualPaletteParams(palette),
            'visual_hierarchy': _mathVisualHierarchyParams(),
          },
        },
      });
      if (exact != null) return exact;
    }
    final a =
        _containsAny(text, const [
          'baixo',
          'downward',
          'concave down',
          'concavidade para baixo',
        ])
        ? -1
        : 1;
    final c = _extractYIntercept(text) ?? 0;
    return tryRenderMathTemplate({
      'math_template': {
        'name': 'quadratic_function',
        'params': {
          'a': a,
          'b': 0,
          'c': c,
          'x_min': -5,
          'x_max': 5,
          'labels': {
            'title': 'Parábola',
            'vertex': 'vértice',
            'x': 'x',
            'y': 'y',
          },
          'visual_palette': _mathVisualPaletteParams(palette),
          'visual_hierarchy': _mathVisualHierarchyParams(),
        },
      },
    });
  }
}

class _LinearRenderer extends SoftwareVisualRenderer {
  const _LinearRenderer();

  @override
  String get name => 'LinearRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.graphReasoning;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return _containsAny(request.text, const [
      'linear',
      'reta',
      'line graph',
      'linear function',
      'função linear',
      'funcao linear',
    ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final text = request.text;
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    return tryRenderMathTemplate({
      'math_template': {
        'name': 'linear_function',
        'params': {
          'a': _containsAny(text, const ['decrescente', 'negative slope'])
              ? -1
              : 1,
          'b': _extractYIntercept(text) ?? 0,
          'x_min': -5,
          'x_max': 5,
          'labels': {'title': 'Função linear', 'x': 'x', 'y': 'y'},
          'visual_palette': _mathVisualPaletteParams(palette),
          'visual_hierarchy': _mathVisualHierarchyParams(),
        },
      },
    });
  }
}

class _UnitCircleRenderer extends SoftwareVisualRenderer {
  const _UnitCircleRenderer();

  @override
  String get name => 'UnitCircleRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.spatialReasoning;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return _containsAny(request.text, const [
      'círculo unitário',
      'circulo unitario',
      'unit circle',
    ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    return tryRenderMathTemplate({
      'math_template': {
        'name': 'unit_circle',
        'params': {
          'angle_deg': _extractAngle(request.text) ?? 45,
          'labels': {'title': 'Círculo unitário'},
        },
      },
    });
  }
}

class _TimelineRenderer extends SoftwareVisualRenderer {
  const _TimelineRenderer();

  @override
  String get name => 'TimelineRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.timeline;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return _containsAny(request.text, const [
      'linha do tempo',
      'timeline',
      'cronologia',
      'chronology',
      'sequência histórica',
      'sequencia historica',
    ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    final title = _bestTitle(request.topic, 'Linha do tempo');
    final labels = _contextLabels(request, const [
      'início',
      'mudança',
      'evento-chave',
      'resultado',
    ], count: 4);
    final caption = _contextCaption(
      request,
      'ordem dos acontecimentos para orientar o raciocínio',
    );
    return sanitizeAndEncodeSvg('''
<svg width="900" height="520" viewBox="0 0 900 520" xmlns="http://www.w3.org/2000/svg">
  ${_canvasBackground(palette, height: 520)}
  ${_titleText(title, palette)}
  <line x1="110" y1="260" x2="790" y2="260" stroke="${palette.connector}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)} stroke-linecap="round"/>
  <g ${_fontGroup(palette)}>
    <g>
      <circle cx="130" cy="260" r="16" fill="${palette.fillFor(PedagogicalVisualRole.supportingContext)}" stroke="${palette.strokeFor(PedagogicalVisualRole.supportingContext)}" ${_vhStroke(PedagogicalVisualHierarchyRole.secondary)}/>
      ${_layoutText(130, 335, labels[0], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 13)}
      <path d="M130 278 V305" stroke="${palette.strokeFor(PedagogicalVisualRole.supportingContext)}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)}/>
    </g>
    <g>
      <circle cx="350" cy="260" r="23" fill="${palette.fillFor(PedagogicalVisualRole.primaryConcept)}" stroke="${palette.strokeFor(PedagogicalVisualRole.primaryConcept)}" ${_vhStroke(PedagogicalVisualHierarchyRole.primary)}/>
      ${_layoutText(350, 205, labels[1], PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: 14)}
      <path d="M350 237 V215" stroke="${palette.strokeFor(PedagogicalVisualRole.primaryConcept)}" ${_vhStroke(PedagogicalVisualHierarchyRole.primary)}/>
    </g>
    <g>
      <circle cx="570" cy="260" r="20" fill="${palette.fillFor(PedagogicalVisualRole.attention)}" stroke="${palette.strokeFor(PedagogicalVisualRole.attention)}" ${_vhStroke(PedagogicalVisualHierarchyRole.attention)}/>
      ${_layoutText(570, 335, labels[2], PedagogicalVisualHierarchyRole.attention, maxCharsPerLine: 13)}
      <path d="M570 280 V305" stroke="${palette.strokeFor(PedagogicalVisualRole.attention)}" ${_vhStroke(PedagogicalVisualHierarchyRole.attention)}/>
    </g>
    <g>
      <circle cx="770" cy="260" r="20" fill="${palette.fillFor(PedagogicalVisualRole.critical)}" stroke="${palette.strokeFor(PedagogicalVisualRole.critical)}" ${_vhStroke(PedagogicalVisualHierarchyRole.critical)}/>
      ${_layoutText(770, 205, labels[3], PedagogicalVisualHierarchyRole.critical, maxCharsPerLine: 13)}
      <path d="M770 240 V215" stroke="${palette.strokeFor(PedagogicalVisualRole.critical)}" ${_vhStroke(PedagogicalVisualHierarchyRole.critical)}/>
    </g>
  </g>
  ${_captionText(450, 430, caption, palette)}
</svg>''');
  }
}

class _ProgrammingFlowRenderer extends SoftwareVisualRenderer {
  const _ProgrammingFlowRenderer();

  @override
  String get name => 'ProgrammingFlowRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.stepVisualizer;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return request._domain == _VisualKnowledgeDomain.programming &&
        _containsAny(request.domainText, const [
          'algoritmo',
          'programação',
          'programacao',
          'programming',
          'código',
          'codigo',
          'code',
          'entrada',
          'processamento',
          'saída',
          'saida',
          'loop',
          'if',
        ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    final title = _bestTitle(request.topic, 'Algoritmo');
    final labels = _contextLabels(request, const [
      'entrada',
      'processamento',
      'decisão',
      'saída',
    ], count: 4);
    final caption = _contextCaption(
      request,
      'fluxo lógico do algoritmo sem misturar dados e decisão',
    );
    return sanitizeAndEncodeSvg('''
<svg width="900" height="560" viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">
  ${_canvasBackground(palette)}
  ${_titleText(title, palette)}
  <defs>
    ${_arrowMarker(palette)}
  </defs>
  ${_domainBadgeText(request._domain, palette)}
  <g stroke="${palette.connector}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)} fill="none" marker-end="url(#arrow)">
    <path d="M250 260 H335"/>
    <path d="M565 260 H650"/>
    <path d="M450 335 V415"/>
  </g>
  <g ${_fontGroup(palette)}>
    ${_roleBox(x: 75, y: 205, width: 185, height: 110, palette: palette, fillRole: PedagogicalVisualRole.supportingContext, hierarchyRole: PedagogicalVisualHierarchyRole.secondary)}
    ${_layoutText(168, 268, labels[0], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 13)}
    ${_roleBox(x: 335, y: 190, width: 230, height: 140, palette: palette, fillRole: PedagogicalVisualRole.primaryConcept, hierarchyRole: PedagogicalVisualHierarchyRole.primary)}
    ${_layoutText(450, 268, labels[1], PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: 16)}
    <path d="M690 200 L810 260 L690 320 L570 260 Z" fill="${palette.fillFor(PedagogicalVisualRole.attention)}" stroke="${palette.strokeFor(PedagogicalVisualRole.attention)}" ${_vhStroke(PedagogicalVisualHierarchyRole.attention)}/>
    ${_layoutText(690, 268, labels[2], PedagogicalVisualHierarchyRole.attention, maxCharsPerLine: 13)}
    ${_roleBox(x: 342, y: 415, width: 216, height: 80, palette: palette, fillRole: PedagogicalVisualRole.definition, hierarchyRole: PedagogicalVisualHierarchyRole.conclusion)}
    ${_layoutText(450, 462, labels[3], PedagogicalVisualHierarchyRole.conclusion, maxCharsPerLine: 16)}
  </g>
  ${_captionText(450, 535, caption, palette)}
</svg>''');
  }
}

class _ChemistryReactionRenderer extends SoftwareVisualRenderer {
  const _ChemistryReactionRenderer();

  @override
  String get name => 'ChemistryReactionRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.structureMap;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return request._domain == _VisualKnowledgeDomain.chemistry &&
        _containsAny(request.domainText, const [
          'reação',
          'reacao',
          'reaction',
          'molécula',
          'molecula',
          'átomo',
          'atomo',
          'reagente',
          'produto',
          'ligação',
          'ligacao',
        ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    final title = _bestTitle(request.topic, 'Reação química');
    final labels = _contextLabels(request, const [
      'reagentes',
      'condição',
      'produtos',
      'evidência',
    ], count: 4);
    final caption = _contextCaption(
      request,
      'transformação entre partículas, substâncias ou produtos',
    );
    return sanitizeAndEncodeSvg('''
<svg width="900" height="560" viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">
  ${_canvasBackground(palette)}
  ${_titleText(title, palette)}
  <defs>
    ${_arrowMarker(palette, markerWidth: 14, markerHeight: 14, refX: 12, refY: 7)}
  </defs>
  ${_domainBadgeText(request._domain, palette)}
  <g stroke="${palette.connector}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)} fill="none" marker-end="url(#arrow)">
    <path d="M340 270 H560"/>
  </g>
  <g ${_fontGroup(palette)}>
    ${_roleBox(x: 80, y: 185, width: 260, height: 170, palette: palette, fillRole: PedagogicalVisualRole.supportingContext, hierarchyRole: PedagogicalVisualHierarchyRole.secondary)}
    <circle cx="150" cy="250" r="28" fill="${palette.supportingContext}" opacity="0.88"/>
    <circle cx="208" cy="228" r="20" fill="${palette.attention}" opacity="0.78"/>
    <circle cx="230" cy="285" r="24" fill="${palette.definition}" opacity="0.72"/>
    ${_layoutText(210, 332, labels[0], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 17)}
    ${_roleBox(x: 365, y: 215, width: 170, height: 92, palette: palette, fillRole: PedagogicalVisualRole.attention, hierarchyRole: PedagogicalVisualHierarchyRole.attention)}
    ${_layoutText(450, 270, labels[1], PedagogicalVisualHierarchyRole.attention, maxCharsPerLine: 13)}
    <rect x="560" y="175" width="260" height="190" rx="${_vhRadius(PedagogicalVisualHierarchyRole.primary)}" fill="${palette.fillFor(PedagogicalVisualRole.primaryConcept)}" stroke="${palette.strokeFor(PedagogicalVisualRole.primaryConcept)}" ${_vhStroke(PedagogicalVisualHierarchyRole.primary)}/>
    <circle cx="630" cy="245" r="26" fill="${palette.primaryConcept}" opacity="0.86"/>
    <circle cx="686" cy="245" r="26" fill="${palette.primaryConcept}" opacity="0.62"/>
    <line x1="656" y1="245" x2="660" y2="245" stroke="${palette.border}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)}/>
    <circle cx="718" cy="292" r="20" fill="${palette.critical}" opacity="0.68"/>
    ${_layoutText(690, 342, labels[2], PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: 17)}
  </g>
  ${_captionText(450, 448, labels[3], palette)}
  ${_captionText(450, 500, caption, palette)}
</svg>''');
  }
}

class _GeographyLayersRenderer extends SoftwareVisualRenderer {
  const _GeographyLayersRenderer();

  @override
  String get name => 'GeographyLayersRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.spatialReasoning;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return request._domain == _VisualKnowledgeDomain.geography &&
        !_containsAny(request.domainText, const [
          'mapa conceitual',
          'concept map',
          'mind map',
          'mapa mental',
        ]) &&
        _containsAny(request.domainText, const [
          'mapa',
          'relevo',
          'clima',
          'região',
          'regiao',
          'território',
          'territorio',
          'camada',
          'fluxo',
          'migração',
          'migracao',
        ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    final title = _bestTitle(request.topic, 'Leitura geográfica');
    final labels = _contextLabels(request, const [
      'região',
      'relevo',
      'clima',
      'fluxo',
      'impacto',
    ], count: 5);
    final caption = _contextCaption(
      request,
      'camadas ajudam a separar espaço, ambiente e movimento',
    );
    return sanitizeAndEncodeSvg('''
<svg width="900" height="560" viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">
  ${_canvasBackground(palette)}
  ${_titleText(title, palette)}
  <defs>
    ${_arrowMarker(palette)}
  </defs>
  ${_domainBadgeText(request._domain, palette)}
  <rect x="95" y="150" width="520" height="295" rx="${_vhRadius(PedagogicalVisualHierarchyRole.primary)}" fill="${palette.fillFor(PedagogicalVisualRole.primaryConcept)}" stroke="${palette.strokeFor(PedagogicalVisualRole.primaryConcept)}" ${_vhStroke(PedagogicalVisualHierarchyRole.primary)}/>
  <path d="M115 375 C210 330 285 405 360 350 C450 285 520 335 595 285 V425 H115 Z" fill="${palette.supportingContextFill}" stroke="${palette.supportingContext}" ${_vhStroke(PedagogicalVisualHierarchyRole.secondary)}/>
  <path d="M130 248 C210 190 310 232 395 178 C475 130 555 165 600 145" fill="none" stroke="${palette.attention}" ${_vhStroke(PedagogicalVisualHierarchyRole.attention)}/>
  <path d="M250 215 C365 250 470 245 560 310" fill="none" stroke="${palette.connector}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)} marker-end="url(#arrow)"/>
  <g ${_fontGroup(palette)}>
    ${_layoutText(355, 205, labels[0], PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: 16)}
    ${_layoutText(265, 373, labels[1], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 14)}
    ${_layoutText(520, 168, labels[2], PedagogicalVisualHierarchyRole.attention, maxCharsPerLine: 13)}
    ${_layoutText(430, 280, labels[3], PedagogicalVisualHierarchyRole.connector, maxCharsPerLine: 13)}
    ${_roleBox(x: 660, y: 185, width: 150, height: 185, palette: palette, fillRole: PedagogicalVisualRole.definition, hierarchyRole: PedagogicalVisualHierarchyRole.conclusion)}
    ${_layoutText(735, 282, labels[4], PedagogicalVisualHierarchyRole.conclusion, maxCharsPerLine: 12)}
  </g>
  ${_captionText(450, 505, caption, palette)}
</svg>''');
  }
}

class _LogicArgumentRenderer extends SoftwareVisualRenderer {
  const _LogicArgumentRenderer();

  @override
  String get name => 'LogicArgumentRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.stepVisualizer;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return request._domain == _VisualKnowledgeDomain.logic &&
        _containsAny(request.domainText, const [
          'premissa',
          'premise',
          'conclusão',
          'conclusao',
          'proposição',
          'proposicao',
          'inferência',
          'inferencia',
          'argumento',
          'silogismo',
        ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    final title = _bestTitle(request.topic, 'Argumento lógico');
    final labels = _contextLabels(request, const [
      'premissa 1',
      'premissa 2',
      'inferência',
      'conclusão',
    ], count: 4);
    final caption = _contextCaption(
      request,
      'premissas sustentam a conclusão por uma regra de inferência',
    );
    return sanitizeAndEncodeSvg('''
<svg width="900" height="560" viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">
  ${_canvasBackground(palette)}
  ${_titleText(title, palette)}
  <defs>
    ${_arrowMarker(palette)}
  </defs>
  ${_domainBadgeText(request._domain, palette)}
  <g stroke="${palette.connector}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)} fill="none" marker-end="url(#arrow)">
    <path d="M280 220 C355 235 380 265 425 290"/>
    <path d="M280 350 C355 335 380 305 425 290"/>
    <path d="M520 290 H635"/>
  </g>
  <g ${_fontGroup(palette)}>
    <rect x="70" y="175" width="225" height="90" rx="${_vhRadius(PedagogicalVisualHierarchyRole.secondary)}" fill="${palette.fillFor(PedagogicalVisualRole.supportingContext)}" stroke="${palette.strokeFor(PedagogicalVisualRole.supportingContext)}" ${_vhStroke(PedagogicalVisualHierarchyRole.secondary)}/>
    ${_layoutText(182, 228, labels[0], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 16)}
    <rect x="70" y="305" width="225" height="90" rx="${_vhRadius(PedagogicalVisualHierarchyRole.secondary)}" fill="${palette.fillFor(PedagogicalVisualRole.supportingContext)}" stroke="${palette.strokeFor(PedagogicalVisualRole.supportingContext)}" ${_vhStroke(PedagogicalVisualHierarchyRole.secondary)}/>
    ${_layoutText(182, 358, labels[1], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 16)}
    ${_roleBox(x: 390, y: 240, width: 150, height: 100, palette: palette, fillRole: PedagogicalVisualRole.attention, hierarchyRole: PedagogicalVisualHierarchyRole.attention)}
    ${_layoutText(465, 298, labels[2], PedagogicalVisualHierarchyRole.attention, maxCharsPerLine: 12)}
    ${_roleBox(x: 635, y: 220, width: 210, height: 140, palette: palette, fillRole: PedagogicalVisualRole.primaryConcept, hierarchyRole: PedagogicalVisualHierarchyRole.primary)}
    ${_layoutText(740, 300, labels[3], PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: 15)}
  </g>
  ${_captionText(450, 475, caption, palette)}
</svg>''');
  }
}

class _BusinessFlowRenderer extends SoftwareVisualRenderer {
  const _BusinessFlowRenderer();

  @override
  String get name => 'BusinessFlowRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.comparison;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return request._domain == _VisualKnowledgeDomain.business &&
        _containsAny(request.domainText, const [
          'oferta',
          'demanda',
          'mercado',
          'receita',
          'custo',
          'lucro',
          'preço',
          'preco',
          'fluxo de caixa',
          'valor',
        ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    final title = _bestTitle(request.topic, 'Modelo econômico');
    final labels = _contextLabels(request, const [
      'oferta',
      'demanda',
      'preço',
      'equilíbrio',
      'resultado',
    ], count: 5);
    final caption = _contextCaption(
      request,
      'relações de mercado ficam claras quando entradas e resultado se separam',
    );
    return sanitizeAndEncodeSvg('''
<svg width="900" height="560" viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">
  ${_canvasBackground(palette)}
  ${_titleText(title, palette)}
  <defs>
    ${_arrowMarker(palette)}
  </defs>
  ${_domainBadgeText(request._domain, palette)}
  <g stroke="${palette.connector}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)} fill="none" marker-end="url(#arrow)">
    <path d="M285 220 C360 230 385 255 430 282"/>
    <path d="M285 360 C360 350 385 315 430 282"/>
    <path d="M545 282 H660"/>
  </g>
  <g ${_fontGroup(palette)}>
    ${_roleBox(x: 75, y: 170, width: 230, height: 105, palette: palette, fillRole: PedagogicalVisualRole.supportingContext, hierarchyRole: PedagogicalVisualHierarchyRole.secondary)}
    ${_layoutText(190, 230, labels[0], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 16)}
    ${_roleBox(x: 75, y: 315, width: 230, height: 105, palette: palette, fillRole: PedagogicalVisualRole.attention, hierarchyRole: PedagogicalVisualHierarchyRole.attention)}
    ${_layoutText(190, 375, labels[1], PedagogicalVisualHierarchyRole.attention, maxCharsPerLine: 16)}
    <circle cx="490" cy="282" r="70" fill="${palette.fillFor(PedagogicalVisualRole.primaryConcept)}" stroke="${palette.strokeFor(PedagogicalVisualRole.primaryConcept)}" ${_vhStroke(PedagogicalVisualHierarchyRole.primary)}/>
    ${_layoutText(490, 272, labels[2], PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: 11)}
    ${_layoutText(490, 306, labels[3], PedagogicalVisualHierarchyRole.conclusion, maxCharsPerLine: 11)}
    ${_roleBox(x: 660, y: 220, width: 190, height: 125, palette: palette, fillRole: PedagogicalVisualRole.definition, hierarchyRole: PedagogicalVisualHierarchyRole.conclusion)}
    ${_layoutText(755, 292, labels[4], PedagogicalVisualHierarchyRole.conclusion, maxCharsPerLine: 13)}
  </g>
  ${_captionText(450, 490, caption, palette)}
</svg>''');
  }
}

class _FlowchartRenderer extends SoftwareVisualRenderer {
  const _FlowchartRenderer();

  @override
  String get name => 'FlowchartRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.stepVisualizer;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return _containsAny(request.text, const [
      'fluxograma',
      'flowchart',
      'processo',
      'process',
      'etapas',
      'steps',
      'passos',
      'sequência',
      'sequencia',
    ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    final level = _visualLevel(request);
    final title = _bestTitle(request.topic, 'Fluxo');
    final labels = _contextLabels(request, const [
      'observar',
      'decidir',
      'aplicar',
    ], count: 3);
    final caption = _contextCaption(
      request,
      'passos visuais para não perder a ordem do pensamento',
    );
    return sanitizeAndEncodeSvg('''
<svg width="900" height="520" viewBox="0 0 900 520" xmlns="http://www.w3.org/2000/svg">
  ${_canvasBackground(palette, height: 520)}
  ${_titleText(title, palette)}
  <defs>
    ${_arrowMarker(palette)}
  </defs>
  <g ${_fontGroup(palette)} stroke="${palette.border}">
    ${_roleBox(x: 80, y: 195, width: 190, height: 90, palette: palette, fillRole: PedagogicalVisualRole.supportingContext, hierarchyRole: PedagogicalVisualHierarchyRole.secondary, includeStroke: false)}
    ${_roleBox(x: 342, y: 178, width: 216, height: 124, palette: palette, fillRole: PedagogicalVisualRole.primaryConcept, hierarchyRole: PedagogicalVisualHierarchyRole.primary, includeStroke: false)}
    ${_roleBox(x: 630, y: 195, width: 190, height: 90, palette: palette, fillRole: PedagogicalVisualRole.attention, hierarchyRole: PedagogicalVisualHierarchyRole.attention, includeStroke: false)}
    ${_layoutText(175, 248, _numberedLabel(1, labels[0]), PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: level.labelMaxChars, maxLines: level.maxTextLines)}
    ${_layoutText(450, 250, _numberedLabel(2, labels[1]), PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: level.labelMaxChars + 2, maxLines: level.maxTextLines)}
    ${_layoutText(725, 248, _numberedLabel(3, labels[2]), PedagogicalVisualHierarchyRole.attention, maxCharsPerLine: level.labelMaxChars, maxLines: level.maxTextLines)}
  </g>
  <g stroke="${palette.connector}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)} fill="none" marker-end="url(#arrow)">
    <path d="M280 240 H340"/>
    <path d="M560 240 H615"/>
  </g>
  ${_captionText(450, 390, caption, palette)}
  ${_levelDetailStrip(request, palette)}
</svg>''');
  }
}

class _ComparisonRenderer extends SoftwareVisualRenderer {
  const _ComparisonRenderer();

  @override
  String get name => 'ComparisonRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.comparison;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return _containsAny(request.text, const [
      'comparação',
      'comparacao',
      'comparison',
      'comparar',
      'versus',
      ' vs ',
      'diferença',
      'diferenca',
      'difference',
    ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    final title = _bestTitle(request.topic, 'Comparação');
    final labels = _contextLabels(request, const [
      'ideia A',
      'ideia B',
      'característica',
      'exemplo',
      'uso',
      'característica',
      'exemplo',
      'uso',
    ], count: 8);
    final caption = _contextCaption(
      request,
      'compare sem misturar as duas ideias',
    );
    return sanitizeAndEncodeSvg('''
<svg width="900" height="520" viewBox="0 0 900 520" xmlns="http://www.w3.org/2000/svg">
  ${_canvasBackground(palette, height: 520)}
  ${_titleText(title, palette)}
  <rect x="80" y="118" width="330" height="285" rx="${_vhRadius(PedagogicalVisualHierarchyRole.secondary)}" fill="${palette.fillFor(PedagogicalVisualRole.supportingContext)}" stroke="${palette.strokeFor(PedagogicalVisualRole.supportingContext)}" ${_vhStroke(PedagogicalVisualHierarchyRole.secondary)}/>
  <rect x="472" y="105" width="356" height="315" rx="${_vhRadius(PedagogicalVisualHierarchyRole.primary)}" fill="${palette.fillFor(PedagogicalVisualRole.primaryConcept)}" stroke="${palette.strokeFor(PedagogicalVisualRole.primaryConcept)}" ${_vhStroke(PedagogicalVisualHierarchyRole.primary)}/>
  <line x1="450" y1="120" x2="450" y2="400" stroke="${palette.neutral}" ${_vhStroke(PedagogicalVisualHierarchyRole.neutral)} stroke-dasharray="12 12"/>
  <g ${_fontGroup(palette)}>
    ${_layoutText(250, 165, labels[0], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 18)}
    ${_layoutText(650, 165, labels[1], PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: 18)}
    ${_layoutText(250, 230, labels[2], PedagogicalVisualHierarchyRole.example, maxCharsPerLine: 20)}
    ${_layoutText(250, 285, labels[3], PedagogicalVisualHierarchyRole.example, maxCharsPerLine: 20)}
    ${_layoutText(250, 340, labels[4], PedagogicalVisualHierarchyRole.example, maxCharsPerLine: 20)}
    ${_layoutText(650, 230, labels[5], PedagogicalVisualHierarchyRole.attention, maxCharsPerLine: 20)}
    ${_layoutText(650, 285, labels[6], PedagogicalVisualHierarchyRole.example, maxCharsPerLine: 20)}
    ${_layoutText(650, 340, labels[7], PedagogicalVisualHierarchyRole.example, maxCharsPerLine: 20)}
  </g>
  ${_captionText(450, 455, caption, palette)}
</svg>''');
  }
}

class _CycleRenderer extends SoftwareVisualRenderer {
  const _CycleRenderer();

  @override
  String get name => 'CycleRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.cycle;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return _containsAny(request.text, const [
      'ciclo',
      'cycle',
      'ciclo da água',
      'ciclo da agua',
      'water cycle',
      'carbon cycle',
      'ciclo de vida',
    ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    final title = _bestTitle(request.topic, 'Ciclo');
    final labels = _contextLabels(request, const [
      'etapa 1',
      'etapa 2',
      'etapa 3',
      'retorno',
    ], count: 4);
    return sanitizeAndEncodeSvg('''
<svg width="900" height="560" viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">
  ${_canvasBackground(palette)}
  ${_titleText(title, palette)}
  <defs>
    ${_arrowMarker(palette)}
  </defs>
  <circle cx="450" cy="295" r="145" fill="none" stroke="${palette.neutral}" ${_vhStroke(PedagogicalVisualHierarchyRole.neutral)}/>
  <g stroke="${palette.connector}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)} fill="none" marker-end="url(#arrow)">
    <path d="M450 145 C565 150 645 225 650 335"/>
    <path d="M650 335 C600 440 490 485 375 445"/>
    <path d="M375 445 C265 395 235 270 300 175"/>
    <path d="M300 175 C340 145 390 135 450 145"/>
  </g>
  <g ${_fontGroup(palette)}>
    <rect x="365" y="112" width="170" height="58" rx="${_vhRadius(PedagogicalVisualHierarchyRole.secondary)}" fill="${palette.fillFor(PedagogicalVisualRole.supportingContext)}" stroke="${palette.strokeFor(PedagogicalVisualRole.supportingContext)}" ${_vhStroke(PedagogicalVisualHierarchyRole.secondary)}/>
    ${_layoutText(450, 148, labels[0], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 14)}
    <rect x="595" y="262" width="200" height="84" rx="${_vhRadius(PedagogicalVisualHierarchyRole.primary)}" fill="${palette.fillFor(PedagogicalVisualRole.primaryConcept)}" stroke="${palette.strokeFor(PedagogicalVisualRole.primaryConcept)}" ${_vhStroke(PedagogicalVisualHierarchyRole.primary)}/>
    ${_layoutText(695, 311, labels[1], PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: 16)}
    <rect x="365" y="430" width="170" height="58" rx="${_vhRadius(PedagogicalVisualHierarchyRole.attention)}" fill="${palette.fillFor(PedagogicalVisualRole.attention)}" stroke="${palette.strokeFor(PedagogicalVisualRole.attention)}" ${_vhStroke(PedagogicalVisualHierarchyRole.attention)}/>
    ${_layoutText(450, 466, labels[2], PedagogicalVisualHierarchyRole.attention, maxCharsPerLine: 14)}
    <rect x="120" y="275" width="170" height="58" rx="${_vhRadius(PedagogicalVisualHierarchyRole.critical)}" fill="${palette.fillFor(PedagogicalVisualRole.critical)}" stroke="${palette.strokeFor(PedagogicalVisualRole.critical)}" ${_vhStroke(PedagogicalVisualHierarchyRole.critical)}/>
    ${_layoutText(205, 311, labels[3], PedagogicalVisualHierarchyRole.critical, maxCharsPerLine: 14)}
  </g>
</svg>''');
  }
}

class _TableRenderer extends SoftwareVisualRenderer {
  const _TableRenderer();

  @override
  String get name => 'TableRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.structureMap;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return _containsAny(request.text, const [
      'tabela',
      'table',
      'tabla',
      'colunas',
      'columns',
      'classes gramaticais',
      'verb table',
      'tabela verbal',
    ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    final title = _bestTitle(request.topic, 'Tabela');
    final labels = _contextLabels(request, const [
      'tipo',
      'característica',
      'exemplo',
      'A',
      'regra',
      'caso',
      'B',
      'diferença',
      'caso',
      'C',
      'atenção',
      'caso',
    ], count: 12);
    return sanitizeAndEncodeSvg('''
<svg width="900" height="520" viewBox="0 0 900 520" xmlns="http://www.w3.org/2000/svg">
  ${_canvasBackground(palette, height: 520)}
  ${_titleText(title, palette)}
  <rect x="120" y="115" width="660" height="300" rx="${_vhRadius(PedagogicalVisualHierarchyRole.neutral)}" fill="${palette.background}" stroke="${palette.border}" ${_vhStroke(PedagogicalVisualHierarchyRole.neutral)}/>
  <rect x="120" y="115" width="660" height="70" rx="${_vhRadius(PedagogicalVisualHierarchyRole.primary)}" fill="${palette.fillFor(PedagogicalVisualRole.definition)}"/>
  <line x1="340" y1="115" x2="340" y2="415" stroke="${palette.border}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)}/>
  <line x1="560" y1="115" x2="560" y2="415" stroke="${palette.border}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)}/>
  <line x1="120" y1="185" x2="780" y2="185" stroke="${palette.border}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)}/>
  <line x1="120" y1="260" x2="780" y2="260" stroke="${palette.neutral}" ${_vhStroke(PedagogicalVisualHierarchyRole.neutral)}/>
  <line x1="120" y1="335" x2="780" y2="335" stroke="${palette.neutral}" ${_vhStroke(PedagogicalVisualHierarchyRole.neutral)}/>
  <g ${_fontGroup(palette)}>
    ${_layoutText(230, 158, labels[0], PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: 14)}
    ${_layoutText(450, 158, labels[1], PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: 14)}
    ${_layoutText(670, 158, labels[2], PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: 14)}
    ${_layoutText(230, 230, labels[3], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 15)}
    ${_layoutText(450, 230, labels[4], PedagogicalVisualHierarchyRole.example, maxCharsPerLine: 15)}
    ${_layoutText(670, 230, labels[5], PedagogicalVisualHierarchyRole.example, maxCharsPerLine: 15)}
    ${_layoutText(230, 305, labels[6], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 15)}
    ${_layoutText(450, 305, labels[7], PedagogicalVisualHierarchyRole.attention, maxCharsPerLine: 15)}
    ${_layoutText(670, 305, labels[8], PedagogicalVisualHierarchyRole.example, maxCharsPerLine: 15)}
    ${_layoutText(230, 380, labels[9], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 15)}
    ${_layoutText(450, 380, labels[10], PedagogicalVisualHierarchyRole.critical, maxCharsPerLine: 15)}
    ${_layoutText(670, 380, labels[11], PedagogicalVisualHierarchyRole.example, maxCharsPerLine: 15)}
  </g>
</svg>''');
  }
}

class _ConceptMapRenderer extends SoftwareVisualRenderer {
  const _ConceptMapRenderer();

  @override
  String get name => 'ConceptMapRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.structureMap;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return _containsAny(request.text, const [
      'mapa conceitual',
      'concept map',
      'mind map',
      'mapa mental',
      'estrutura de',
      'structure of',
    ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    final title = _bestTitle(request.topic, request.visualType);
    final labels = _contextLabels(request, const [
      'conceito',
      'parte 1',
      'parte 2',
      'parte 3',
    ], count: 4);
    return sanitizeAndEncodeSvg('''
<svg width="900" height="520" viewBox="0 0 900 520" xmlns="http://www.w3.org/2000/svg">
  ${_canvasBackground(palette, height: 520)}
  ${_titleText(title, palette)}
  <g stroke="${palette.connector}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)} fill="none">
    <path d="M450 200 L250 330"/>
    <path d="M450 200 L450 350"/>
    <path d="M450 200 L650 330"/>
  </g>
  <g ${_fontGroup(palette)} stroke="${palette.border}">
    <rect x="320" y="132" width="260" height="105" rx="${_vhRadius(PedagogicalVisualHierarchyRole.primary)}" fill="${palette.fillFor(PedagogicalVisualRole.primaryConcept)}" ${_vhStroke(PedagogicalVisualHierarchyRole.primary)}/>
    ${_layoutText(450, 195, labels[0], PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: 18)}
    <rect x="120" y="315" width="260" height="80" rx="${_vhRadius(PedagogicalVisualHierarchyRole.secondary)}" fill="${palette.fillFor(PedagogicalVisualRole.supportingContext)}" ${_vhStroke(PedagogicalVisualHierarchyRole.secondary)}/>
    ${_layoutText(250, 363, labels[1], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 17)}
    <rect x="320" y="350" width="260" height="80" rx="${_vhRadius(PedagogicalVisualHierarchyRole.attention)}" fill="${palette.fillFor(PedagogicalVisualRole.attention)}" ${_vhStroke(PedagogicalVisualHierarchyRole.attention)}/>
    ${_layoutText(450, 398, labels[2], PedagogicalVisualHierarchyRole.attention, maxCharsPerLine: 17)}
    <rect x="520" y="315" width="260" height="80" rx="${_vhRadius(PedagogicalVisualHierarchyRole.example)}" fill="${palette.fillFor(PedagogicalVisualRole.definition)}" ${_vhStroke(PedagogicalVisualHierarchyRole.example)}/>
    ${_layoutText(650, 363, labels[3], PedagogicalVisualHierarchyRole.example, maxCharsPerLine: 17)}
  </g>
</svg>''');
  }
}

class _ForceDiagramRenderer extends SoftwareVisualRenderer {
  const _ForceDiagramRenderer();

  @override
  String get name => 'ForceDiagramRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.spatialReasoning;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return _containsAny(request.text, const [
      'força',
      'forca',
      'force',
      'força resultante',
      'forca resultante',
      'resultant force',
      'net force',
      'diagrama de corpo livre',
      'free body diagram',
      'plano inclinado',
      'inclined plane',
    ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    final title = _bestTitle(request.topic, 'Forças');
    final labels = _contextLabels(request, const [
      'bloco',
      'N',
      'P',
      'F',
      'atrito',
    ], count: 5);
    final caption = _contextCaption(
      request,
      'setas mostram direção e sentido das forças',
    );
    return sanitizeAndEncodeSvg('''
<svg width="900" height="560" viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">
  ${_canvasBackground(palette)}
  ${_titleText(title, palette)}
  <defs>
    ${_arrowMarker(palette, markerWidth: _simIdentity.largeArrowMarkerSize, markerHeight: _simIdentity.largeArrowMarkerSize, refX: _simIdentity.largeArrowMarkerRefX, refY: _simIdentity.largeArrowMarkerRefY)}
  </defs>
  <rect x="340" y="222" width="220" height="126" rx="${_vhRadius(PedagogicalVisualHierarchyRole.primary)}" fill="${palette.fillFor(PedagogicalVisualRole.primaryConcept)}" stroke="${palette.strokeFor(PedagogicalVisualRole.primaryConcept)}" ${_vhStroke(PedagogicalVisualHierarchyRole.primary)}/>
  ${_layoutText(450, 292, labels[0], PedagogicalVisualHierarchyRole.primary, fill: palette.text, maxCharsPerLine: 16)}
  <g stroke="${palette.connector}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)} fill="none" marker-end="url(#arrow)">
    <path d="M450 230 V140"/>
    <path d="M450 340 V440"/>
    <path d="M550 285 H700"/>
    <path d="M350 285 H210"/>
  </g>
  <g ${_fontGroup(palette)}>
    ${_layoutText(466, 150, labels[1], PedagogicalVisualHierarchyRole.secondary, anchor: 'start', maxCharsPerLine: 13)}
    ${_layoutText(466, 430, labels[2], PedagogicalVisualHierarchyRole.critical, anchor: 'start', maxCharsPerLine: 13)}
    ${_layoutText(612, 268, labels[3], PedagogicalVisualHierarchyRole.attention, anchor: 'start', maxCharsPerLine: 14)}
    ${_layoutText(258, 268, labels[4], PedagogicalVisualHierarchyRole.example, anchor: 'end', maxCharsPerLine: 14)}
  </g>
  ${_captionText(450, 500, caption, palette)}
</svg>''');
  }
}

class _CircuitRenderer extends SoftwareVisualRenderer {
  const _CircuitRenderer();

  @override
  String get name => 'CircuitRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.structureMap;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return _containsAny(request.text, const [
      'circuito',
      'circuit',
      'circuito elétrico',
      'circuito eletrico',
      'electrical circuit',
      'lei de ohm',
      'ohm',
      'resistência elétrica',
      'resistencia eletrica',
    ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    final title = _bestTitle(request.topic, 'Circuito');
    final labels = _contextLabels(request, const [
      '+',
      '-',
      'resistor',
      'lâmpada',
      'fonte',
    ], count: 5);
    final caption = _contextCaption(
      request,
      'esquema para visualizar corrente, fonte e resistência',
    );
    return sanitizeAndEncodeSvg('''
<svg width="900" height="560" viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">
  ${_canvasBackground(palette)}
  ${_titleText(title, palette)}
  <g stroke="${palette.connector}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)} fill="none" stroke-linecap="round" stroke-linejoin="round">
    <path d="M210 180 H690 V390 H210 Z"/>
    <path d="M210 255 H150 V315 H210"/>
    <path d="M385 180 l20 -35 l30 70 l30 -70 l30 70 l20 -35"/>
    <circle cx="690" cy="285" r="46" fill="${palette.fillFor(PedagogicalVisualRole.attention)}" stroke="${palette.strokeFor(PedagogicalVisualRole.attention)}" ${_vhStroke(PedagogicalVisualHierarchyRole.attention)}/>
    <path d="M663 258 L717 312"/>
    <path d="M717 258 L663 312"/>
  </g>
  <g ${_fontGroup(palette)}>
    ${_layoutText(150, 248, labels[0], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 10)}
    ${_layoutText(150, 338, labels[1], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 10)}
    ${_layoutText(450, 128, labels[2], PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: 16)}
    ${_layoutText(690, 350, labels[3], PedagogicalVisualHierarchyRole.attention, maxCharsPerLine: 14)}
    ${_layoutText(150, 370, labels[4], PedagogicalVisualHierarchyRole.conclusion, maxCharsPerLine: 12)}
  </g>
  ${_captionText(450, 480, caption, palette)}
</svg>''');
  }
}

class _SyntaxTreeRenderer extends SoftwareVisualRenderer {
  const _SyntaxTreeRenderer();

  @override
  String get name => 'SyntaxTreeRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.structureMap;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return _containsAny(request.text, const [
      'árvore sintática',
      'arvore sintatica',
      'syntax tree',
      'análise sintática',
      'analise sintatica',
      'sintaxe',
      'syntax',
      'sujeito',
      'predicado',
    ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    final title = _bestTitle(request.topic, 'Árvore sintática');
    final labels = _contextLabels(request, const [
      'oração',
      'sujeito',
      'predicado',
      'núcleo',
      'termo',
      'verbo',
      'complemento',
    ], count: 7);
    return sanitizeAndEncodeSvg('''
<svg width="900" height="560" viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">
  ${_canvasBackground(palette)}
  ${_titleText(title, palette)}
  <g stroke="${palette.connector}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)} fill="none">
    <path d="M450 145 L285 260"/>
    <path d="M450 145 L615 260"/>
    <path d="M285 260 L205 375"/>
    <path d="M285 260 L365 375"/>
    <path d="M615 260 L535 375"/>
    <path d="M615 260 L695 375"/>
  </g>
  <g ${_fontGroup(palette)} stroke="${palette.border}">
    <rect x="350" y="100" width="200" height="78" rx="${_vhRadius(PedagogicalVisualHierarchyRole.definition)}" fill="${palette.fillFor(PedagogicalVisualRole.definition)}" ${_vhStroke(PedagogicalVisualHierarchyRole.definition)}/>
    ${_layoutText(450, 148, labels[0], PedagogicalVisualHierarchyRole.definition, maxCharsPerLine: 14)}
    <rect x="185" y="230" width="200" height="70" rx="${_vhRadius(PedagogicalVisualHierarchyRole.secondary)}" fill="${palette.fillFor(PedagogicalVisualRole.supportingContext)}" ${_vhStroke(PedagogicalVisualHierarchyRole.secondary)}/>
    ${_layoutText(285, 273, labels[1], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 14)}
    <rect x="500" y="220" width="230" height="90" rx="${_vhRadius(PedagogicalVisualHierarchyRole.primary)}" fill="${palette.fillFor(PedagogicalVisualRole.primaryConcept)}" ${_vhStroke(PedagogicalVisualHierarchyRole.primary)}/>
    ${_layoutText(615, 273, labels[2], PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: 15)}
    <rect x="115" y="360" width="180" height="65" rx="${_vhRadius(PedagogicalVisualHierarchyRole.neutral)}" fill="${palette.fillFor(PedagogicalVisualRole.neutral)}" ${_vhStroke(PedagogicalVisualHierarchyRole.neutral)}/>
    ${_layoutText(205, 400, labels[3], PedagogicalVisualHierarchyRole.neutral, maxCharsPerLine: 12)}
    <rect x="315" y="360" width="180" height="65" rx="${_vhRadius(PedagogicalVisualHierarchyRole.example)}" fill="${palette.fillFor(PedagogicalVisualRole.neutral)}" ${_vhStroke(PedagogicalVisualHierarchyRole.example)}/>
    ${_layoutText(405, 400, labels[4], PedagogicalVisualHierarchyRole.example, maxCharsPerLine: 12)}
    <rect x="445" y="360" width="180" height="65" rx="${_vhRadius(PedagogicalVisualHierarchyRole.attention)}" fill="${palette.fillFor(PedagogicalVisualRole.attention)}" ${_vhStroke(PedagogicalVisualHierarchyRole.attention)}/>
    ${_layoutText(535, 400, labels[5], PedagogicalVisualHierarchyRole.attention, maxCharsPerLine: 12)}
    <rect x="645" y="360" width="180" height="65" rx="${_vhRadius(PedagogicalVisualHierarchyRole.critical)}" fill="${palette.fillFor(PedagogicalVisualRole.critical)}" ${_vhStroke(PedagogicalVisualHierarchyRole.critical)}/>
    ${_layoutText(735, 400, labels[6], PedagogicalVisualHierarchyRole.critical, maxCharsPerLine: 12)}
  </g>
</svg>''');
  }
}

class _FoodChainRenderer extends SoftwareVisualRenderer {
  const _FoodChainRenderer();

  @override
  String get name => 'FoodChainRenderer';

  @override
  VisualPedagogicalRole get role => VisualPedagogicalRole.stepVisualizer;

  @override
  bool accepts(SoftwareVisualRequest request) {
    return _containsAny(request.text, const [
      'cadeia alimentar',
      'food chain',
      'cadena alimentaria',
      'produtor',
      'consumer',
      'consumidor',
      'decompositor',
      'decomposer',
    ]);
  }

  @override
  String? render(SoftwareVisualRequest request) {
    final palette = PedagogicalVisualPalette.fromColorLegend(
      request.colorLegend,
    );
    final title = _bestTitle(request.topic, 'Cadeia alimentar');
    final labels = _contextLabels(request, const [
      'produtor',
      'consumidor',
      'primário',
      'consumidor',
      'secundário',
      'decomp.',
    ], count: 6);
    final caption = _contextCaption(
      request,
      'as setas mostram o fluxo de energia no ecossistema',
    );
    return sanitizeAndEncodeSvg('''
<svg width="900" height="540" viewBox="0 0 900 540" xmlns="http://www.w3.org/2000/svg">
  ${_canvasBackground(palette, height: 540)}
  ${_titleText(title, palette)}
  <defs>
    ${_arrowMarker(palette)}
  </defs>
  <g stroke="${palette.connector}" ${_vhStroke(PedagogicalVisualHierarchyRole.connector)} fill="none" marker-end="url(#arrow)">
    <path d="M235 260 H330"/>
    <path d="M465 260 H560"/>
    <path d="M695 260 H765"/>
  </g>
  <g ${_fontGroup(palette)} stroke="${palette.border}">
    <rect x="60" y="195" width="185" height="130" rx="${_vhRadius(PedagogicalVisualHierarchyRole.primary)}" fill="${palette.fillFor(PedagogicalVisualRole.primaryConcept)}" ${_vhStroke(PedagogicalVisualHierarchyRole.primary)}/>
    ${_layoutText(152, 268, labels[0], PedagogicalVisualHierarchyRole.primary, maxCharsPerLine: 12)}
    <rect x="330" y="210" width="165" height="100" rx="${_vhRadius(PedagogicalVisualHierarchyRole.secondary)}" fill="${palette.fillFor(PedagogicalVisualRole.supportingContext)}" ${_vhStroke(PedagogicalVisualHierarchyRole.secondary)}/>
    ${_layoutText(412, 255, labels[1], PedagogicalVisualHierarchyRole.secondary, maxCharsPerLine: 11)}
    ${_layoutText(412, 282, labels[2], PedagogicalVisualHierarchyRole.example, maxCharsPerLine: 11)}
    <rect x="560" y="210" width="165" height="100" rx="${_vhRadius(PedagogicalVisualHierarchyRole.attention)}" fill="${palette.fillFor(PedagogicalVisualRole.attention)}" ${_vhStroke(PedagogicalVisualHierarchyRole.attention)}/>
    ${_layoutText(642, 255, labels[3], PedagogicalVisualHierarchyRole.attention, maxCharsPerLine: 11)}
    ${_layoutText(642, 282, labels[4], PedagogicalVisualHierarchyRole.example, maxCharsPerLine: 11)}
    <rect x="735" y="205" width="120" height="110" rx="${_vhRadius(PedagogicalVisualHierarchyRole.critical)}" fill="${palette.fillFor(PedagogicalVisualRole.critical)}" ${_vhStroke(PedagogicalVisualHierarchyRole.critical)}/>
    ${_layoutText(795, 268, labels[5], PedagogicalVisualHierarchyRole.critical, maxCharsPerLine: 9)}
  </g>
  ${_captionText(450, 420, caption, palette)}
</svg>''');
  }
}

bool _containsAny(String text, List<String> values) {
  return values.any((value) => text.contains(value));
}

num? _extractYIntercept(String text) {
  final pair = RegExp(
    r'\(\s*0\s*,\s*(-?\d+(?:[\.,]\d+)?)\s*\)',
  ).firstMatch(text);
  if (pair != null) return _parseNum(pair.group(1));
  final yIntercept = RegExp(
    r'(?:intercepto\s*y|intercept\s*y|y-intercept)[^\d-]{0,20}(-?\d+(?:[\.,]\d+)?)',
  ).firstMatch(text);
  if (yIntercept != null) return _parseNum(yIntercept.group(1));
  return null;
}

String? _extractFormula(String text) {
  final normalized = text
      .replaceAll('−', '-')
      .replaceAll('×', '*')
      .replaceAll('·', '*');
  final match = RegExp(
    r'\b(?:f\s*\(\s*x\s*\)|y)\s*=\s*[-+0-9xX\s*/^().²³×·−]+',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (match == null) return null;
  return match.group(0)?.trim();
}

num? _extractAngle(String text) {
  final match = RegExp(
    r'(-?\d+(?:[\.,]\d+)?)\s*(?:°|graus|degrees|deg)',
  ).firstMatch(text);
  return match == null ? null : _parseNum(match.group(1));
}

num? _parseNum(String? value) {
  if (value == null) return null;
  return num.tryParse(value.replaceAll(',', '.'));
}

String _bestTitle(String? topic, String? fallback) {
  final raw =
      (topic?.trim().isNotEmpty == true ? topic : fallback) ?? 'Visual da aula';
  final oneLine = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (oneLine.length <= 64) return oneLine;
  return '${oneLine.substring(0, 61)}...';
}

List<String> _contextLabels(
  SoftwareVisualRequest request,
  List<String> fallback, {
  required int count,
}) {
  final level = _visualLevel(request);
  final hasExplicitLevel = request.academicLevel?.trim().isNotEmpty == true;
  final primaryLimit = hasExplicitLevel ? level.primaryCountFor(count) : count;
  final values = <String>[];
  void add(String? value) {
    final clean = _cleanContextLabel(value);
    if (clean == null) return;
    final key = clean.toLowerCase();
    if (values.any((existing) => existing.toLowerCase() == key)) return;
    values.add(clean);
  }

  for (final value in request.keyElements) {
    add(value);
    if (values.length >= primaryLimit) break;
  }
  for (final source in [
    request.highlightFocus,
    request.pedagogicalGoal,
    request.imagePrompt,
    request.topic,
  ]) {
    for (final value in _splitContextPhrases(source)) {
      add(value);
      if (values.length >= count) return values.take(count).toList();
    }
  }
  for (final value in fallback) {
    add(value);
    if (values.length >= count) return values.take(count).toList();
  }
  while (values.length < count) {
    values.add(fallback.isEmpty ? 'item ${values.length + 1}' : fallback.last);
  }
  return values.take(count).toList();
}

List<String> _contextDetailLabels(
  SoftwareVisualRequest request, {
  required int skip,
  required int count,
}) {
  final values = <String>[];
  void add(String? value) {
    final clean = _cleanContextLabel(value, maxLength: 44);
    if (clean == null) return;
    final key = clean.toLowerCase();
    if (values.any((existing) => existing.toLowerCase() == key)) return;
    values.add(clean);
  }

  for (final value in request.keyElements.skip(skip)) {
    add(value);
    if (values.length >= count) return values;
  }
  for (final source in [
    request.highlightFocus,
    request.pedagogicalGoal,
    request.imagePrompt,
  ]) {
    for (final value in _splitContextPhrases(source)) {
      add(value);
      if (values.length >= count) return values;
    }
  }
  return values;
}

String _contextCaption(SoftwareVisualRequest request, String fallback) {
  return _cleanContextLabel(request.highlightFocus, maxLength: 82) ??
      _cleanContextLabel(request.pedagogicalGoal, maxLength: 82) ??
      fallback;
}

Map<String, String> _mathVisualPaletteParams(PedagogicalVisualPalette palette) {
  return {
    'background': palette.background,
    'axis': palette.border,
    'grid': palette.neutralFill,
    'curve': palette.primaryConcept,
    'accent': palette.attention,
    'critical': palette.critical,
    'ghost': palette.mutedText,
    'label': palette.text,
    'badgeFill': palette.surface,
  };
}

Map<String, num> _mathVisualHierarchyParams() {
  return const {
    'titleFontSize': 17,
    'axisStrokeWidth': 1.8,
    'gridStrokeWidth': 1.0,
    'curveStrokeWidth': 4.2,
    'pointOuterRadius': 10.5,
    'pointInnerRadius': 5.8,
    'labelFontSize': 12.5,
    'axisLabelFontSize': 13,
    'tickFontSize': 11,
    'badgeStrokeWidth': 1.4,
  };
}

String _numberedLabel(int index, String label) => '$index. $label';

Iterable<String> _splitContextPhrases(String? value) sync* {
  if (value == null) return;
  final normalized = value
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('→', ';')
      .replaceAll('->', ';')
      .trim();
  if (normalized.isEmpty) return;
  for (final part in normalized.split(RegExp(r'[;|,\n.]'))) {
    final clean = _cleanContextLabel(part);
    if (clean != null) yield clean;
  }
}

String? _cleanContextLabel(String? value, {int maxLength = 28}) {
  if (value == null) return null;
  var clean = value
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\-\u2022\d\.\)\s]+'), '')
      .trim();
  if (clean.isEmpty) return null;
  clean = clean.replaceFirst(
    RegExp(
      r'^(desenhe|desenhar|mostrar|mostre|organize|compare|fluxograma|diagrama|tabela|ciclo|mapa conceitual|mapa mental|linha do tempo)\s+(de|da|do|dos|das)?\s*',
      caseSensitive: false,
    ),
    '',
  );
  clean = clean.trim();
  if (clean.isEmpty) return null;
  if (_genericVisualLabelWords.contains(clean.toLowerCase())) return null;
  if (clean.length <= maxLength) return clean;
  return '${clean.substring(0, maxLength - 3).trimRight()}...';
}

const _genericVisualLabelWords = {
  'fluxograma',
  'flowchart',
  'diagrama',
  'diagram',
  'tabela',
  'table',
  'ciclo',
  'cycle',
  'comparação',
  'comparacao',
  'comparison',
  'linha do tempo',
  'timeline',
  'mapa conceitual',
  'concept map',
  'mapa mental',
  'mind map',
};
