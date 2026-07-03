import 'package:flutter/foundation.dart';

import 'math_templates/math_templates.dart';
import 's12_visual_pipeline.dart' show sanitizeAndEncodeSvg;
import 'visual_pedagogical_role.dart';
import 'visual_router_n2.dart';

class SoftwareVisualRequest {
  const SoftwareVisualRequest({
    required this.n2,
    this.topic,
    this.visualType,
    this.imagePrompt,
  });

  final VisualN2Result n2;
  final String? topic;
  final String? visualType;
  final String? imagePrompt;

  String get text => [topic, visualType, imagePrompt]
      .where((value) => value != null && value.trim().isNotEmpty)
      .join(' ')
      .toLowerCase();

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
    _TimelineRenderer(),
    _FlowchartRenderer(),
    _ComparisonRenderer(),
    _CycleRenderer(),
    _TableRenderer(),
    _ForceDiagramRenderer(),
    _CircuitRenderer(),
    _SyntaxTreeRenderer(),
    _FoodChainRenderer(),
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
    final title = _escapeSvgLabel(_bestTitle(request.topic, 'Linha do tempo'));
    return sanitizeAndEncodeSvg('''
<svg width="900" height="520" viewBox="0 0 900 520" xmlns="http://www.w3.org/2000/svg">
  <rect width="900" height="520" fill="#FFFFFF"/>
  <text x="450" y="58" text-anchor="middle" font-family="Arial, sans-serif" font-size="28" font-weight="700" fill="#0F172A">$title</text>
  <line x1="110" y1="260" x2="790" y2="260" stroke="#111827" stroke-width="5" stroke-linecap="round"/>
  <g font-family="Arial, sans-serif" fill="#0F172A">
    <g>
      <circle cx="130" cy="260" r="18" fill="#E0F2FE" stroke="#0284C7" stroke-width="4"/>
      <text x="130" y="335" text-anchor="middle" font-size="20" font-weight="700">início</text>
      <path d="M130 278 V305" stroke="#0284C7" stroke-width="3"/>
    </g>
    <g>
      <circle cx="350" cy="260" r="18" fill="#DCFCE7" stroke="#16A34A" stroke-width="4"/>
      <text x="350" y="205" text-anchor="middle" font-size="20" font-weight="700">mudança</text>
      <path d="M350 242 V215" stroke="#16A34A" stroke-width="3"/>
    </g>
    <g>
      <circle cx="570" cy="260" r="18" fill="#FEF3C7" stroke="#D97706" stroke-width="4"/>
      <text x="570" y="335" text-anchor="middle" font-size="20" font-weight="700">evento-chave</text>
      <path d="M570 278 V305" stroke="#D97706" stroke-width="3"/>
    </g>
    <g>
      <circle cx="770" cy="260" r="18" fill="#FCE7F3" stroke="#DB2777" stroke-width="4"/>
      <text x="770" y="205" text-anchor="middle" font-size="20" font-weight="700">resultado</text>
      <path d="M770 242 V215" stroke="#DB2777" stroke-width="3"/>
    </g>
  </g>
  <text x="450" y="430" text-anchor="middle" font-family="Arial, sans-serif" font-size="19" fill="#475569">ordem dos acontecimentos para orientar o raciocínio</text>
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
    final title = _escapeSvgLabel(_bestTitle(request.topic, 'Fluxo'));
    return sanitizeAndEncodeSvg('''
<svg width="900" height="520" viewBox="0 0 900 520" xmlns="http://www.w3.org/2000/svg">
  <rect width="900" height="520" fill="#FFFFFF"/>
  <text x="450" y="58" text-anchor="middle" font-family="Arial, sans-serif" font-size="28" font-weight="700" fill="#0F172A">$title</text>
  <defs>
    <marker id="arrow" markerWidth="12" markerHeight="12" refX="10" refY="6" orient="auto">
      <path d="M2 2 L10 6 L2 10 Z" fill="#111827"/>
    </marker>
  </defs>
  <g font-family="Arial, sans-serif" font-size="22" font-weight="700" fill="#0F172A" stroke="#111827" stroke-width="3">
    <rect x="80" y="190" width="190" height="100" rx="18" fill="#F8FAFC"/>
    <rect x="355" y="190" width="190" height="100" rx="18" fill="#F8FAFC"/>
    <rect x="630" y="190" width="190" height="100" rx="18" fill="#F8FAFC"/>
    <text x="175" y="248" text-anchor="middle">1. observar</text>
    <text x="450" y="248" text-anchor="middle">2. decidir</text>
    <text x="725" y="248" text-anchor="middle">3. aplicar</text>
  </g>
  <g stroke="#111827" stroke-width="4" fill="none" marker-end="url(#arrow)">
    <path d="M280 240 H340"/>
    <path d="M555 240 H615"/>
  </g>
  <text x="450" y="390" text-anchor="middle" font-family="Arial, sans-serif" font-size="19" fill="#475569">passos visuais para não perder a ordem do pensamento</text>
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
    final title = _escapeSvgLabel(_bestTitle(request.topic, 'Comparação'));
    return sanitizeAndEncodeSvg('''
<svg width="900" height="520" viewBox="0 0 900 520" xmlns="http://www.w3.org/2000/svg">
  <rect width="900" height="520" fill="#FFFFFF"/>
  <text x="450" y="58" text-anchor="middle" font-family="Arial, sans-serif" font-size="28" font-weight="700" fill="#0F172A">$title</text>
  <rect x="80" y="110" width="340" height="300" rx="24" fill="#EFF6FF" stroke="#2563EB" stroke-width="4"/>
  <rect x="480" y="110" width="340" height="300" rx="24" fill="#F0FDF4" stroke="#16A34A" stroke-width="4"/>
  <line x1="450" y1="120" x2="450" y2="400" stroke="#CBD5E1" stroke-width="4" stroke-dasharray="12 12"/>
  <g font-family="Arial, sans-serif" fill="#0F172A">
    <text x="250" y="165" text-anchor="middle" font-size="25" font-weight="700">ideia A</text>
    <text x="650" y="165" text-anchor="middle" font-size="25" font-weight="700">ideia B</text>
    <text x="250" y="230" text-anchor="middle" font-size="20">característica</text>
    <text x="250" y="285" text-anchor="middle" font-size="20">exemplo</text>
    <text x="250" y="340" text-anchor="middle" font-size="20">uso</text>
    <text x="650" y="230" text-anchor="middle" font-size="20">característica</text>
    <text x="650" y="285" text-anchor="middle" font-size="20">exemplo</text>
    <text x="650" y="340" text-anchor="middle" font-size="20">uso</text>
  </g>
  <text x="450" y="455" text-anchor="middle" font-family="Arial, sans-serif" font-size="19" fill="#475569">compare sem misturar as duas ideias</text>
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
    final title = _escapeSvgLabel(_bestTitle(request.topic, 'Ciclo'));
    return sanitizeAndEncodeSvg('''
<svg width="900" height="560" viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">
  <rect width="900" height="560" fill="#FFFFFF"/>
  <text x="450" y="58" text-anchor="middle" font-family="Arial, sans-serif" font-size="28" font-weight="700" fill="#0F172A">$title</text>
  <defs>
    <marker id="arrow" markerWidth="12" markerHeight="12" refX="10" refY="6" orient="auto">
      <path d="M2 2 L10 6 L2 10 Z" fill="#111827"/>
    </marker>
  </defs>
  <circle cx="450" cy="295" r="145" fill="none" stroke="#CBD5E1" stroke-width="6"/>
  <g stroke="#111827" stroke-width="5" fill="none" marker-end="url(#arrow)">
    <path d="M450 145 C565 150 645 225 650 335"/>
    <path d="M650 335 C600 440 490 485 375 445"/>
    <path d="M375 445 C265 395 235 270 300 175"/>
    <path d="M300 175 C340 145 390 135 450 145"/>
  </g>
  <g font-family="Arial, sans-serif" font-size="20" font-weight="700" fill="#0F172A">
    <rect x="365" y="112" width="170" height="58" rx="16" fill="#E0F2FE" stroke="#0284C7" stroke-width="3"/>
    <text x="450" y="148" text-anchor="middle">etapa 1</text>
    <rect x="610" y="275" width="170" height="58" rx="16" fill="#DCFCE7" stroke="#16A34A" stroke-width="3"/>
    <text x="695" y="311" text-anchor="middle">etapa 2</text>
    <rect x="365" y="430" width="170" height="58" rx="16" fill="#FEF3C7" stroke="#D97706" stroke-width="3"/>
    <text x="450" y="466" text-anchor="middle">etapa 3</text>
    <rect x="120" y="275" width="170" height="58" rx="16" fill="#FCE7F3" stroke="#DB2777" stroke-width="3"/>
    <text x="205" y="311" text-anchor="middle">retorno</text>
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
    final title = _escapeSvgLabel(_bestTitle(request.topic, 'Tabela'));
    return sanitizeAndEncodeSvg('''
<svg width="900" height="520" viewBox="0 0 900 520" xmlns="http://www.w3.org/2000/svg">
  <rect width="900" height="520" fill="#FFFFFF"/>
  <text x="450" y="58" text-anchor="middle" font-family="Arial, sans-serif" font-size="28" font-weight="700" fill="#0F172A">$title</text>
  <rect x="120" y="115" width="660" height="300" rx="20" fill="#FFFFFF" stroke="#111827" stroke-width="4"/>
  <rect x="120" y="115" width="660" height="70" rx="20" fill="#E0F2FE"/>
  <line x1="340" y1="115" x2="340" y2="415" stroke="#111827" stroke-width="3"/>
  <line x1="560" y1="115" x2="560" y2="415" stroke="#111827" stroke-width="3"/>
  <line x1="120" y1="185" x2="780" y2="185" stroke="#111827" stroke-width="3"/>
  <line x1="120" y1="260" x2="780" y2="260" stroke="#CBD5E1" stroke-width="3"/>
  <line x1="120" y1="335" x2="780" y2="335" stroke="#CBD5E1" stroke-width="3"/>
  <g font-family="Arial, sans-serif" fill="#0F172A" font-size="20">
    <text x="230" y="158" text-anchor="middle" font-weight="700">tipo</text>
    <text x="450" y="158" text-anchor="middle" font-weight="700">característica</text>
    <text x="670" y="158" text-anchor="middle" font-weight="700">exemplo</text>
    <text x="230" y="230" text-anchor="middle">A</text>
    <text x="450" y="230" text-anchor="middle">regra</text>
    <text x="670" y="230" text-anchor="middle">caso</text>
    <text x="230" y="305" text-anchor="middle">B</text>
    <text x="450" y="305" text-anchor="middle">diferença</text>
    <text x="670" y="305" text-anchor="middle">caso</text>
    <text x="230" y="380" text-anchor="middle">C</text>
    <text x="450" y="380" text-anchor="middle">atenção</text>
    <text x="670" y="380" text-anchor="middle">caso</text>
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
    final title = _escapeSvgLabel(
      _bestTitle(request.topic, request.visualType),
    );
    return sanitizeAndEncodeSvg('''
<svg width="900" height="520" viewBox="0 0 900 520" xmlns="http://www.w3.org/2000/svg">
  <rect width="900" height="520" fill="#FFFFFF"/>
  <text x="450" y="58" text-anchor="middle" font-family="Arial, sans-serif" font-size="28" font-weight="700" fill="#0F172A">$title</text>
  <g stroke="#111827" stroke-width="4" fill="none">
    <path d="M450 200 L250 330"/>
    <path d="M450 200 L450 350"/>
    <path d="M450 200 L650 330"/>
  </g>
  <g font-family="Arial, sans-serif" font-size="21" font-weight="700" fill="#0F172A" stroke="#111827" stroke-width="3">
    <rect x="335" y="145" width="230" height="90" rx="22" fill="#E0F2FE"/>
    <text x="450" y="198" text-anchor="middle">conceito</text>
    <rect x="120" y="315" width="260" height="80" rx="20" fill="#F8FAFC"/>
    <text x="250" y="363" text-anchor="middle">parte 1</text>
    <rect x="320" y="350" width="260" height="80" rx="20" fill="#F8FAFC"/>
    <text x="450" y="398" text-anchor="middle">parte 2</text>
    <rect x="520" y="315" width="260" height="80" rx="20" fill="#F8FAFC"/>
    <text x="650" y="363" text-anchor="middle">parte 3</text>
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
    final title = _escapeSvgLabel(_bestTitle(request.topic, 'Forças'));
    return sanitizeAndEncodeSvg('''
<svg width="900" height="560" viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">
  <rect width="900" height="560" fill="#FFFFFF"/>
  <text x="450" y="58" text-anchor="middle" font-family="Arial, sans-serif" font-size="28" font-weight="700" fill="#0F172A">$title</text>
  <defs>
    <marker id="arrow" markerWidth="14" markerHeight="14" refX="12" refY="7" orient="auto">
      <path d="M2 2 L12 7 L2 12 Z" fill="#111827"/>
    </marker>
  </defs>
  <rect x="350" y="230" width="200" height="110" rx="18" fill="#F8FAFC" stroke="#111827" stroke-width="4"/>
  <text x="450" y="292" text-anchor="middle" font-family="Arial, sans-serif" font-size="24" font-weight="700" fill="#0F172A">bloco</text>
  <g stroke="#111827" stroke-width="5" fill="none" marker-end="url(#arrow)" font-family="Arial, sans-serif">
    <path d="M450 230 V140"/>
    <path d="M450 340 V440"/>
    <path d="M550 285 H700"/>
    <path d="M350 285 H210"/>
  </g>
  <g font-family="Arial, sans-serif" font-size="22" font-weight="700" fill="#0F172A">
    <text x="466" y="150">N</text>
    <text x="466" y="430">P</text>
    <text x="612" y="268">F</text>
    <text x="258" y="268">atrito</text>
  </g>
  <text x="450" y="500" text-anchor="middle" font-family="Arial, sans-serif" font-size="19" fill="#475569">setas mostram direção e sentido das forças</text>
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
    final title = _escapeSvgLabel(_bestTitle(request.topic, 'Circuito'));
    return sanitizeAndEncodeSvg('''
<svg width="900" height="560" viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">
  <rect width="900" height="560" fill="#FFFFFF"/>
  <text x="450" y="58" text-anchor="middle" font-family="Arial, sans-serif" font-size="28" font-weight="700" fill="#0F172A">$title</text>
  <g stroke="#111827" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round">
    <path d="M210 180 H690 V390 H210 Z"/>
    <path d="M210 255 H150 V315 H210"/>
    <path d="M385 180 l20 -35 l30 70 l30 -70 l30 70 l20 -35"/>
    <circle cx="690" cy="285" r="42" fill="#FEF3C7"/>
    <path d="M663 258 L717 312"/>
    <path d="M717 258 L663 312"/>
  </g>
  <g font-family="Arial, sans-serif" font-size="21" font-weight="700" fill="#0F172A">
    <text x="150" y="248" text-anchor="middle">+</text>
    <text x="150" y="338" text-anchor="middle">-</text>
    <text x="450" y="128" text-anchor="middle">resistor</text>
    <text x="690" y="350" text-anchor="middle">lâmpada</text>
    <text x="150" y="370" text-anchor="middle">fonte</text>
  </g>
  <text x="450" y="480" text-anchor="middle" font-family="Arial, sans-serif" font-size="19" fill="#475569">esquema para visualizar corrente, fonte e resistência</text>
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
    final title = _escapeSvgLabel(
      _bestTitle(request.topic, 'Árvore sintática'),
    );
    return sanitizeAndEncodeSvg('''
<svg width="900" height="560" viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">
  <rect width="900" height="560" fill="#FFFFFF"/>
  <text x="450" y="58" text-anchor="middle" font-family="Arial, sans-serif" font-size="28" font-weight="700" fill="#0F172A">$title</text>
  <g stroke="#111827" stroke-width="4" fill="none">
    <path d="M450 145 L285 260"/>
    <path d="M450 145 L615 260"/>
    <path d="M285 260 L205 375"/>
    <path d="M285 260 L365 375"/>
    <path d="M615 260 L535 375"/>
    <path d="M615 260 L695 375"/>
  </g>
  <g font-family="Arial, sans-serif" font-size="21" font-weight="700" fill="#0F172A" stroke="#111827" stroke-width="3">
    <rect x="360" y="105" width="180" height="70" rx="18" fill="#E0F2FE"/>
    <text x="450" y="148" text-anchor="middle">oração</text>
    <rect x="185" y="230" width="200" height="70" rx="18" fill="#F8FAFC"/>
    <text x="285" y="273" text-anchor="middle">sujeito</text>
    <rect x="515" y="230" width="200" height="70" rx="18" fill="#F8FAFC"/>
    <text x="615" y="273" text-anchor="middle">predicado</text>
    <rect x="115" y="360" width="180" height="65" rx="16" fill="#F0FDF4"/>
    <text x="205" y="400" text-anchor="middle">núcleo</text>
    <rect x="315" y="360" width="180" height="65" rx="16" fill="#F0FDF4"/>
    <text x="405" y="400" text-anchor="middle">termo</text>
    <rect x="445" y="360" width="180" height="65" rx="16" fill="#FEF3C7"/>
    <text x="535" y="400" text-anchor="middle">verbo</text>
    <rect x="645" y="360" width="180" height="65" rx="16" fill="#FEF3C7"/>
    <text x="735" y="400" text-anchor="middle">complemento</text>
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
    final title = _escapeSvgLabel(
      _bestTitle(request.topic, 'Cadeia alimentar'),
    );
    return sanitizeAndEncodeSvg('''
<svg width="900" height="540" viewBox="0 0 900 540" xmlns="http://www.w3.org/2000/svg">
  <rect width="900" height="540" fill="#FFFFFF"/>
  <text x="450" y="58" text-anchor="middle" font-family="Arial, sans-serif" font-size="28" font-weight="700" fill="#0F172A">$title</text>
  <defs>
    <marker id="arrow" markerWidth="12" markerHeight="12" refX="10" refY="6" orient="auto">
      <path d="M2 2 L10 6 L2 10 Z" fill="#111827"/>
    </marker>
  </defs>
  <g stroke="#111827" stroke-width="4" fill="none" marker-end="url(#arrow)">
    <path d="M235 260 H330"/>
    <path d="M465 260 H560"/>
    <path d="M695 260 H765"/>
  </g>
  <g font-family="Arial, sans-serif" font-size="20" font-weight="700" fill="#0F172A" stroke="#111827" stroke-width="3">
    <rect x="70" y="205" width="165" height="110" rx="20" fill="#DCFCE7"/>
    <text x="152" y="268" text-anchor="middle">produtor</text>
    <rect x="330" y="205" width="165" height="110" rx="20" fill="#E0F2FE"/>
    <text x="412" y="255" text-anchor="middle">consumidor</text>
    <text x="412" y="282" text-anchor="middle">primário</text>
    <rect x="560" y="205" width="165" height="110" rx="20" fill="#FEF3C7"/>
    <text x="642" y="255" text-anchor="middle">consumidor</text>
    <text x="642" y="282" text-anchor="middle">secundário</text>
    <rect x="735" y="205" width="120" height="110" rx="20" fill="#FCE7F3"/>
    <text x="795" y="268" text-anchor="middle">decomp.</text>
  </g>
  <text x="450" y="420" text-anchor="middle" font-family="Arial, sans-serif" font-size="19" fill="#475569">as setas mostram o fluxo de energia no ecossistema</text>
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

String _escapeSvgLabel(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
