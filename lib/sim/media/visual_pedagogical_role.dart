enum VisualPedagogicalRole {
  conceptAnchor,
  stepVisualizer,
  errorRepair,
  comparison,
  timeline,
  cycle,
  structureMap,
  graphReasoning,
  spatialReasoning,
  memoryHook,
  realisticReference,
}

extension VisualPedagogicalRoleId on VisualPedagogicalRole {
  String get id {
    switch (this) {
      case VisualPedagogicalRole.conceptAnchor:
        return 'concept_anchor';
      case VisualPedagogicalRole.stepVisualizer:
        return 'step_visualizer';
      case VisualPedagogicalRole.errorRepair:
        return 'error_repair';
      case VisualPedagogicalRole.comparison:
        return 'comparison';
      case VisualPedagogicalRole.timeline:
        return 'timeline';
      case VisualPedagogicalRole.cycle:
        return 'cycle';
      case VisualPedagogicalRole.structureMap:
        return 'structure_map';
      case VisualPedagogicalRole.graphReasoning:
        return 'graph_reasoning';
      case VisualPedagogicalRole.spatialReasoning:
        return 'spatial_reasoning';
      case VisualPedagogicalRole.memoryHook:
        return 'memory_hook';
      case VisualPedagogicalRole.realisticReference:
        return 'realistic_reference';
    }
  }
}

VisualPedagogicalRole inferVisualPedagogicalRole({
  String? topic,
  String? visualType,
  String? imagePrompt,
}) {
  final text = [topic, visualType, imagePrompt]
      .where((value) => value != null && value.trim().isNotEmpty)
      .join(' ')
      .toLowerCase();

  if (_hasAny(text, const [
    'linha do tempo',
    'timeline',
    'cronologia',
    'chronology',
    'antes e depois',
    'before and after',
  ])) {
    return VisualPedagogicalRole.timeline;
  }
  if (_hasAny(text, const [
    'ciclo',
    'cycle',
    'ciclo da agua',
    'ciclo da água',
    'water cycle',
    'carbon cycle',
    'ciclo de vida',
  ])) {
    return VisualPedagogicalRole.cycle;
  }
  if (_hasAny(text, const [
    'comparacao',
    'comparação',
    'comparison',
    'versus',
    ' vs ',
    'diferença',
    'diferenca',
    'difference',
  ])) {
    return VisualPedagogicalRole.comparison;
  }
  if (_hasAny(text, const [
    'fluxograma',
    'flowchart',
    'processo',
    'process',
    'etapas',
    'steps',
    'passos',
    'sequencia',
    'sequência',
  ])) {
    return VisualPedagogicalRole.stepVisualizer;
  }
  if (_hasAny(text, const [
    'grafico',
    'gráfico',
    'graph',
    'funcao',
    'função',
    'parabola',
    'parábola',
    'reta',
    'linear',
    'eixo',
  ])) {
    return VisualPedagogicalRole.graphReasoning;
  }
  if (_hasAny(text, const [
    'geometria',
    'geometry',
    'angulo',
    'ângulo',
    'triangulo',
    'triângulo',
    'espacial',
    'spatial',
  ])) {
    return VisualPedagogicalRole.spatialReasoning;
  }
  if (_hasAny(text, const [
    'estrutura',
    'structure',
    'partes de',
    'parts of',
    'sistema',
    'system',
    'mapa conceitual',
    'concept map',
  ])) {
    return VisualPedagogicalRole.structureMap;
  }
  if (_hasAny(text, const [
    'foto',
    'photo',
    'realista',
    'realistic',
    'anatomia',
    'anatomy',
    'paisagem',
    'landscape',
  ])) {
    return VisualPedagogicalRole.realisticReference;
  }
  return VisualPedagogicalRole.conceptAnchor;
}

bool _hasAny(String text, List<String> values) {
  return values.any(text.contains);
}
