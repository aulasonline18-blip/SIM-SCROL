import '../localization/sim_locale_contract.dart';

const String lessonVisualSupportRule =
    'Toda aula precisa de um apoio visual pedagogico util, adequado ao '
    'conteudo, leve, seguro, acessivel e nao decorativo.';

enum LessonVisualSupportType {
  none,
  pedagogicalImage,
  diagram,
  chart,
  table,
  visualStepByStep,
  visualComparison,
  timeline,
  conceptMap,
  futureMicroAnimation,
  futureMicroSimulation,
}

extension LessonVisualSupportTypeName on LessonVisualSupportType {
  String get wireName {
    switch (this) {
      case LessonVisualSupportType.none:
        return 'none';
      case LessonVisualSupportType.pedagogicalImage:
        return 'pedagogical_image';
      case LessonVisualSupportType.diagram:
        return 'diagram';
      case LessonVisualSupportType.chart:
        return 'chart';
      case LessonVisualSupportType.table:
        return 'table';
      case LessonVisualSupportType.visualStepByStep:
        return 'visual_step_by_step';
      case LessonVisualSupportType.visualComparison:
        return 'visual_comparison';
      case LessonVisualSupportType.timeline:
        return 'timeline';
      case LessonVisualSupportType.conceptMap:
        return 'concept_map';
      case LessonVisualSupportType.futureMicroAnimation:
        return 'future_micro_animation';
      case LessonVisualSupportType.futureMicroSimulation:
        return 'future_micro_simulation';
    }
  }

  String get pedagogicalLabel {
    switch (this) {
      case LessonVisualSupportType.none:
        return 'sem visual';
      case LessonVisualSupportType.pedagogicalImage:
        return 'imagem pedagogica';
      case LessonVisualSupportType.diagram:
        return 'diagrama';
      case LessonVisualSupportType.chart:
        return 'grafico';
      case LessonVisualSupportType.table:
        return 'tabela';
      case LessonVisualSupportType.visualStepByStep:
        return 'passo a passo visual';
      case LessonVisualSupportType.visualComparison:
        return 'comparacao visual';
      case LessonVisualSupportType.timeline:
        return 'linha do tempo';
      case LessonVisualSupportType.conceptMap:
        return 'mapa conceitual';
      case LessonVisualSupportType.futureMicroAnimation:
        return 'microanimacao futura';
      case LessonVisualSupportType.futureMicroSimulation:
        return 'microssimulacao futura';
    }
  }
}

class LessonVisualSupportCandidate {
  const LessonVisualSupportCandidate({
    required this.needsVisual,
    this.typeHint,
    this.subject,
    this.explanation,
    this.question,
    this.options = const [],
    this.marker,
    this.itemIdx,
    this.layer,
    this.description,
    this.reason,
    this.svg,
    this.hasLocalTemplate = false,
    this.raw = const {},
  });

  final bool needsVisual;
  final Object? typeHint;
  final String? subject;
  final String? explanation;
  final String? question;
  final Iterable<String> options;
  final String? marker;
  final int? itemIdx;
  final Object? layer;
  final String? description;
  final String? reason;
  final String? svg;
  final bool hasLocalTemplate;
  final Map<String, dynamic> raw;
}

class LessonVisualTypeSelection {
  const LessonVisualTypeSelection({
    required this.type,
    required this.intention,
    required this.reason,
    this.fromExplicitTrigger = false,
  });

  final LessonVisualSupportType type;
  final String intention;
  final String reason;
  final bool fromExplicitTrigger;

  String get visualType {
    switch (type) {
      case LessonVisualSupportType.none:
        return 'no_visual';
      case LessonVisualSupportType.pedagogicalImage:
        return 'static_image';
      case LessonVisualSupportType.diagram:
        return 'diagram';
      case LessonVisualSupportType.chart:
        return 'chart';
      case LessonVisualSupportType.table:
        return 'table';
      case LessonVisualSupportType.visualStepByStep:
        return 'step_by_step';
      case LessonVisualSupportType.visualComparison:
        return 'comparison';
      case LessonVisualSupportType.timeline:
        return 'timeline';
      case LessonVisualSupportType.conceptMap:
        return 'concept_map';
      case LessonVisualSupportType.futureMicroAnimation:
        return 'future_micro_animation';
      case LessonVisualSupportType.futureMicroSimulation:
        return 'future_micro_simulation';
    }
  }
}

class LessonVisualTypeSelector {
  const LessonVisualTypeSelector();

  LessonVisualTypeSelection select(LessonVisualSupportCandidate candidate) {
    final explicit = _explicitVisualType(candidate.typeHint);
    if (explicit != null) {
      return LessonVisualTypeSelection(
        type: explicit,
        intention: _intentionFor(explicit, candidate),
        reason: 'visual_type_explicit_trigger',
        fromExplicitTrigger: true,
      );
    }
    if (candidate.hasLocalTemplate) {
      return LessonVisualTypeSelection(
        type: LessonVisualSupportType.visualStepByStep,
        intention: _intentionFor(
          LessonVisualSupportType.visualStepByStep,
          candidate,
        ),
        reason: 'visual_type_math_template',
      );
    }
    if (_nonEmptyText(candidate.svg) != null) {
      return LessonVisualTypeSelection(
        type: LessonVisualSupportType.diagram,
        intention: _intentionFor(LessonVisualSupportType.diagram, candidate),
        reason: 'visual_type_safe_svg_candidate',
      );
    }
    if (!_hasLessonText(candidate)) {
      return LessonVisualTypeSelection(
        type: LessonVisualSupportType.pedagogicalImage,
        intention: _intentionFor(
          LessonVisualSupportType.pedagogicalImage,
          candidate,
        ),
        reason: 'visual_type_default_without_lesson_text',
      );
    }

    final text = _lessonText(candidate);
    final math = _score(text, const [
      'calcule',
      'calcular',
      'calculo',
      'equacao',
      'funcao',
      'formula',
      'porcentagem',
      'fracao',
      'razao',
      'proporcao',
      'grafico',
      'eixo',
      'taxa',
    ]);
    final timeline = _score(text, const [
      'data',
      'datas',
      'ano',
      'seculo',
      'cronologia',
      'linha do tempo',
      'antes',
      'depois',
      'durante',
      'idade media',
      'revolucao',
      'periodo',
    ]);
    final chart = _score(text, const [
      'grafico',
      'tendencia',
      'proporcao',
      'porcentagem',
      'percentual',
      'taxa',
      'media',
      'dados',
      'valor',
      'valores',
      'crescimento',
      'queda',
    ]);
    final comparison = _score(text, const [
      'compare',
      'comparar',
      'comparacao',
      'diferenca',
      'semelhanca',
      'versus',
      ' vs ',
      'entre',
      'maior que',
      'menor que',
      'vantagem',
      'desvantagem',
    ]);
    final table = _score(text, const [
      'tabela',
      'coluna',
      'linha',
      'classifique',
      'categorize',
      'categorias',
    ]);
    final stepByStep = _score(text, const [
      'processo',
      'ciclo',
      'sequencia',
      'sequencia',
      'etapa',
      'etapas',
      'passo',
      'passos',
      'transformacao',
      'transforma',
      'como ocorre',
      'procedimento',
      'fluxo',
    ]);
    final diagram = _score(text, const [
      'diagrama',
      'estrutura',
      'partes',
      'parte',
      'anatomia',
      'sistema',
      'orgao',
      'celula',
      'circuito',
      'camadas',
      'componente',
      'componentes',
    ]);
    final conceptMap = _score(text, const [
      'conceito',
      'conceitos',
      'relacao',
      'relacoes',
      'causa',
      'efeito',
      'conecta',
      'conexao',
      'ideias',
      'mapa conceitual',
      'dependencia',
    ]);
    final language = _score(text, const [
      'idioma',
      'vocabulario',
      'palavra',
      'frase',
      'traducao',
      'traduzir',
      'gramatica',
      'pronome',
      'verbo',
    ]);

    if (timeline >= 2) {
      return _selection(LessonVisualSupportType.timeline, candidate, 'tempo');
    }
    if (chart >= 2 || (math >= 2 && chart >= 1)) {
      return _selection(LessonVisualSupportType.chart, candidate, 'numeros');
    }
    if (table >= 2 || (comparison >= 2 && table >= 1)) {
      return _selection(LessonVisualSupportType.table, candidate, 'tabela');
    }
    if (comparison >= 2 || language >= 2) {
      return _selection(
        LessonVisualSupportType.visualComparison,
        candidate,
        'comparacao',
      );
    }
    if (stepByStep >= 2 || math >= 2) {
      return _selection(
        LessonVisualSupportType.visualStepByStep,
        candidate,
        'processo',
      );
    }
    if (diagram >= 2) {
      return _selection(
        LessonVisualSupportType.diagram,
        candidate,
        'estrutura',
      );
    }
    if (diagram >= 1 && _triggerTextHas(candidate, const ['diagrama'])) {
      return _selection(
        LessonVisualSupportType.diagram,
        candidate,
        'diagrama_trigger',
      );
    }
    if (conceptMap >= 2) {
      return _selection(
        LessonVisualSupportType.conceptMap,
        candidate,
        'conceitos',
      );
    }
    if (_hasExplicitVisualGainWord(text)) {
      return _selection(
        LessonVisualSupportType.pedagogicalImage,
        candidate,
        'apoio_visual_generico',
      );
    }
    return _selection(
      LessonVisualSupportType.none,
      candidate,
      'sem_ganho_visual_claro',
    );
  }

  LessonVisualTypeSelection _selection(
    LessonVisualSupportType type,
    LessonVisualSupportCandidate candidate,
    String reason,
  ) {
    return LessonVisualTypeSelection(
      type: type,
      intention: _intentionFor(type, candidate),
      reason: 'visual_type_$reason',
    );
  }
}

const lessonVisualTypeSelector = LessonVisualTypeSelector();

class LessonVisualLocalTemplateResult {
  const LessonVisualLocalTemplateResult({
    required this.status,
    required this.type,
    required this.title,
    required this.accessibilityDescription,
    required this.pedagogicalReason,
    this.svg,
  });

  final String status;
  final LessonVisualSupportType type;
  final String title;
  final String accessibilityDescription;
  final String pedagogicalReason;
  final String? svg;

  bool get isLocalTemplate =>
      status == 'local_template' && svg != null && svg!.trim().isNotEmpty;
}

class LessonVisualLocalTemplates {
  const LessonVisualLocalTemplates();

  LessonVisualLocalTemplateResult render(
    LessonVisualTypeSelection selection,
    LessonVisualSupportCandidate candidate,
  ) {
    if (selection.type == LessonVisualSupportType.none) {
      return _noTemplate(selection.type, 'sem_visual');
    }
    if (selection.type == LessonVisualSupportType.chart ||
        selection.type == LessonVisualSupportType.futureMicroAnimation ||
        selection.type == LessonVisualSupportType.futureMicroSimulation) {
      return _noTemplate(selection.type, 'tipo_exige_n3_ou_fase_futura');
    }

    final title = _titleFor(selection, candidate);
    final description = selection.intention;
    final lines = _candidateLines(candidate);
    switch (selection.type) {
      case LessonVisualSupportType.visualComparison:
        final pairs = _comparisonPairs(candidate, lines);
        if (pairs.length < 2) {
          return _noTemplate(selection.type, 'pares_insuficientes');
        }
        return _svgResult(
          type: selection.type,
          title: title,
          description: description,
          reason: 'comparacao_local_duas_colunas',
          svg: _comparisonSvg(title, pairs.take(4).toList()),
        );
      case LessonVisualSupportType.table:
        final rows = _tableRows(candidate, lines);
        if (rows.length < 2) {
          return _noTemplate(selection.type, 'linhas_insuficientes');
        }
        return _svgResult(
          type: selection.type,
          title: title,
          description: description,
          reason: 'tabela_local_simples',
          svg: _tableSvg(title, rows.take(4).toList()),
        );
      case LessonVisualSupportType.visualStepByStep:
        final steps = _steps(lines);
        if (steps.length < 3) {
          return _noTemplate(selection.type, 'passos_insuficientes');
        }
        return _svgResult(
          type: selection.type,
          title: title,
          description: description,
          reason: 'sequencia_local_simples',
          svg: _stepsSvg(title, steps.take(5).toList()),
        );
      case LessonVisualSupportType.conceptMap:
        final concepts = _concepts(candidate, lines);
        if (concepts.length < 3) {
          return _noTemplate(selection.type, 'conceitos_insuficientes');
        }
        return _svgResult(
          type: selection.type,
          title: title,
          description: description,
          reason: 'mapa_conceitual_local_simples',
          svg: _conceptMapSvg(title, concepts.take(3).toList()),
        );
      case LessonVisualSupportType.diagram:
        final parts = _diagramParts(lines);
        if (parts.length < 2 || _looksComplexForLocalDiagram(candidate)) {
          return _noTemplate(
            selection.type,
            'diagrama_complexo_ou_insuficiente',
          );
        }
        return _svgResult(
          type: selection.type,
          title: title,
          description: description,
          reason: 'diagrama_local_simples',
          svg: _diagramSvg(title, parts.take(4).toList()),
        );
      case LessonVisualSupportType.pedagogicalImage:
      case LessonVisualSupportType.timeline:
      case LessonVisualSupportType.none:
      case LessonVisualSupportType.chart:
      case LessonVisualSupportType.futureMicroAnimation:
      case LessonVisualSupportType.futureMicroSimulation:
        return _noTemplate(selection.type, 'sem_template_local_suficiente');
    }
  }

  LessonVisualLocalTemplateResult _svgResult({
    required LessonVisualSupportType type,
    required String title,
    required String description,
    required String reason,
    required String svg,
  }) {
    if (!_isSafeLocalTemplateSvg(svg)) {
      return _noTemplate(type, 'svg_local_inseguro');
    }
    return LessonVisualLocalTemplateResult(
      status: 'local_template',
      type: type,
      title: title,
      accessibilityDescription: description,
      pedagogicalReason: reason,
      svg: svg,
    );
  }

  LessonVisualLocalTemplateResult _noTemplate(
    LessonVisualSupportType type,
    String reason,
  ) {
    return LessonVisualLocalTemplateResult(
      status: 'no_local_template',
      type: type,
      title: type.pedagogicalLabel,
      accessibilityDescription:
          'sem template local seguro para ${type.pedagogicalLabel}',
      pedagogicalReason: reason,
    );
  }
}

const lessonVisualLocalTemplates = LessonVisualLocalTemplates();

class LessonVisualSupportDecision {
  const LessonVisualSupportDecision({
    required this.needsVisual,
    required this.type,
    required this.useful,
    required this.safe,
    required this.light,
    required this.accessible,
    required this.decorative,
    required this.canShowWithoutBlockingLesson,
    required this.reason,
    this.accessibilityDescription,
    this.typeSelection,
  });

  final bool needsVisual;
  final LessonVisualSupportType type;
  final bool useful;
  final bool safe;
  final bool light;
  final bool accessible;
  final bool decorative;
  final bool canShowWithoutBlockingLesson;
  final String reason;
  final String? accessibilityDescription;
  final LessonVisualTypeSelection? typeSelection;

  bool get accepted =>
      needsVisual &&
      useful &&
      safe &&
      light &&
      accessible &&
      !decorative &&
      canShowWithoutBlockingLesson;
}

class LessonVisualSupportAuthority {
  const LessonVisualSupportAuthority({
    this.maxInlinePayloadChars = 24000,
    this.typeSelector = lessonVisualTypeSelector,
  });

  final int maxInlinePayloadChars;
  final LessonVisualTypeSelector typeSelector;

  LessonVisualSupportDecision evaluate(LessonVisualSupportCandidate candidate) {
    if (!candidate.needsVisual) {
      return const LessonVisualSupportDecision(
        needsVisual: false,
        type: LessonVisualSupportType.none,
        useful: false,
        safe: true,
        light: true,
        accessible: true,
        decorative: false,
        canShowWithoutBlockingLesson: true,
        reason: 'visual_nao_solicitado',
        typeSelection: LessonVisualTypeSelection(
          type: LessonVisualSupportType.none,
          intention: 'sem visual pedagogico',
          reason: 'visual_nao_solicitado',
        ),
      );
    }

    final selection = typeSelector.select(candidate);
    final type = selection.type;
    if (type == LessonVisualSupportType.none) {
      return LessonVisualSupportDecision(
        needsVisual: false,
        type: LessonVisualSupportType.none,
        useful: false,
        safe: true,
        light: true,
        accessible: true,
        decorative: false,
        canShowWithoutBlockingLesson: true,
        reason: selection.reason,
        accessibilityDescription: selection.intention,
        typeSelection: selection,
      );
    }

    final textBasis = [
      candidate.typeHint,
      candidate.description,
      candidate.reason,
      candidate.raw['visual_type'],
      candidate.raw['purpose'],
    ].whereType<Object>().map((value) => value.toString()).join(' ');
    final decorative = _looksDecorative(textBasis);
    final colorOnly = _dependsOnlyOnColor(textBasis);
    final safe = _safeVisualCandidate(candidate);
    final light = _lightVisualCandidate(candidate, maxInlinePayloadChars);
    final description = _visualAccessibilityDescription(candidate, type);
    final accessible = description != null && !colorOnly;
    final useful = !decorative && _looksPedagogicallyUseful(candidate, type);
    final accepted = useful && safe && light && accessible;

    return LessonVisualSupportDecision(
      needsVisual: true,
      type: type,
      useful: useful,
      safe: safe,
      light: light,
      accessible: accessible,
      decorative: decorative,
      canShowWithoutBlockingLesson: true,
      reason: accepted
          ? 'apoio_visual_pedagogico_aceito'
          : _visualRejectionReason(
              decorative: decorative,
              useful: useful,
              safe: safe,
              light: light,
              accessible: accessible,
            ),
      accessibilityDescription: description,
      typeSelection: selection,
    );
  }
}

const lessonVisualSupportAuthority = LessonVisualSupportAuthority();

LessonVisualSupportType lessonVisualSupportTypeFrom(Object? raw) {
  final value = _normalizeVisualToken(raw);
  if (value == null) return LessonVisualSupportType.pedagogicalImage;
  if (const {'none', 'no_image', 'sem_visual', 'no_visual'}.contains(value)) {
    return LessonVisualSupportType.none;
  }
  if (const {
    'image',
    'imagem',
    'static_image',
    'pedagogical_image',
    'imagem_pedagogica',
    'photo',
    'picture',
  }.contains(value)) {
    return LessonVisualSupportType.pedagogicalImage;
  }
  if (const {'diagram', 'diagrama', 'schema', 'esquema'}.contains(value)) {
    return LessonVisualSupportType.diagram;
  }
  if (const {'chart', 'graph', 'grafico', 'grafico_visual'}.contains(value)) {
    return LessonVisualSupportType.chart;
  }
  if (const {'table', 'tabela'}.contains(value)) {
    return LessonVisualSupportType.table;
  }
  if (const {
    'step_by_step',
    'visual_step_by_step',
    'passo_a_passo',
    'process',
    'processo',
  }.contains(value)) {
    return LessonVisualSupportType.visualStepByStep;
  }
  if (const {
    'comparison',
    'visual_comparison',
    'comparacao',
    'comparacao_visual',
  }.contains(value)) {
    return LessonVisualSupportType.visualComparison;
  }
  if (const {'timeline', 'linha_do_tempo'}.contains(value)) {
    return LessonVisualSupportType.timeline;
  }
  if (const {
    'map',
    'concept_map',
    'mapa',
    'mapa_conceitual',
    'conceito',
  }.contains(value)) {
    return LessonVisualSupportType.conceptMap;
  }
  if (const {
    'micro_animation',
    'microanimacao',
    'future_micro_animation',
  }.contains(value)) {
    return LessonVisualSupportType.futureMicroAnimation;
  }
  if (const {
    'micro_simulation',
    'microssimulacao',
    'future_micro_simulation',
  }.contains(value)) {
    return LessonVisualSupportType.futureMicroSimulation;
  }
  return LessonVisualSupportType.pedagogicalImage;
}

class LessonImageGenerationMetadata {
  const LessonImageGenerationMetadata({
    this.cacheKey,
    this.cacheKeyHash,
    this.requestId,
    this.mimeType,
    this.provider,
    this.model,
    this.charged,
    this.cacheHit,
    this.retryable,
    this.lessonLocalId,
    this.marker,
    this.itemIdx,
    this.layer,
    this.mediaType,
    this.status,
    this.source,
    this.createdAt,
    this.n2Reason,
    this.n3Reason,
    this.localeContract,
    this.mediaTextLanguage,
    this.explanationLanguage,
    this.targetLanguage,
    this.visualTextPolicy,
  });

  final String? cacheKey;
  final String? cacheKeyHash;
  final String? requestId;
  final String? mimeType;
  final String? provider;
  final String? model;
  final bool? charged;
  final bool? cacheHit;
  final bool? retryable;
  final String? lessonLocalId;
  final String? marker;
  final int? itemIdx;
  final int? layer;
  final String? mediaType;
  final String? status;
  final String? source;
  final String? createdAt;
  final String? n2Reason;
  final String? n3Reason;
  final SimLocaleContract? localeContract;
  final String? mediaTextLanguage;
  final String? explanationLanguage;
  final String? targetLanguage;
  final String? visualTextPolicy;

  bool get isEmpty =>
      cacheKey == null &&
      cacheKeyHash == null &&
      requestId == null &&
      mimeType == null &&
      provider == null &&
      model == null &&
      charged == null &&
      cacheHit == null &&
      retryable == null &&
      lessonLocalId == null &&
      marker == null &&
      itemIdx == null &&
      layer == null &&
      mediaType == null &&
      status == null &&
      source == null &&
      createdAt == null &&
      n2Reason == null &&
      n3Reason == null &&
      localeContract == null &&
      mediaTextLanguage == null &&
      explanationLanguage == null &&
      targetLanguage == null &&
      visualTextPolicy == null;

  Map<String, Object?> toJson() => {
    'cacheKeyHash': cacheKeyHash ?? _hashString(cacheKey),
    'requestId': requestId,
    'mimeType': mimeType,
    'charged': charged,
    'cacheHit': cacheHit,
    'retryable': retryable,
    'lessonLocalId': lessonLocalId,
    'marker': marker,
    'itemIdx': itemIdx,
    'layer': layer,
    'mediaType': mediaType,
    'status': status,
    'source': source,
    'createdAt': createdAt,
    'n2Reason': n2Reason,
    'n3Reason': n3Reason,
    if (localeContract != null) 'localeContract': localeContract!.toJson(),
    'mediaTextLanguage': mediaTextLanguage,
    'explanationLanguage': explanationLanguage,
    'targetLanguage': targetLanguage,
    'visualTextPolicy': visualTextPolicy,
  };

  LessonImageGenerationMetadata withSlot({
    required String lessonLocalId,
    required String marker,
    required int itemIdx,
    required int layer,
    required String cacheKey,
    String status = 'ready',
    String mediaType = 'image',
    String? source,
    String? createdAt,
  }) {
    return LessonImageGenerationMetadata(
      cacheKeyHash: cacheKeyHash ?? _hashString(cacheKey),
      requestId: requestId,
      mimeType: mimeType,
      charged: charged,
      cacheHit: cacheHit,
      retryable: retryable,
      lessonLocalId: lessonLocalId,
      marker: marker,
      itemIdx: itemIdx,
      layer: layer,
      mediaType: mediaType,
      status: status,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      n2Reason: n2Reason,
      n3Reason: n3Reason,
      localeContract: localeContract,
      mediaTextLanguage: mediaTextLanguage,
      explanationLanguage: explanationLanguage,
      targetLanguage: targetLanguage,
      visualTextPolicy: visualTextPolicy,
    );
  }

  static LessonImageGenerationMetadata? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final rawCacheKey = raw['cacheKey']?.toString();
    final metadata = LessonImageGenerationMetadata(
      cacheKeyHash: raw['cacheKeyHash']?.toString() ?? _hashString(rawCacheKey),
      requestId: raw['requestId']?.toString(),
      mimeType: raw['mimeType']?.toString(),
      charged: raw['charged'] is bool ? raw['charged'] as bool : null,
      cacheHit: raw['cacheHit'] is bool ? raw['cacheHit'] as bool : null,
      retryable: raw['retryable'] is bool ? raw['retryable'] as bool : null,
      lessonLocalId: raw['lessonLocalId']?.toString(),
      marker: raw['marker']?.toString(),
      itemIdx: raw['itemIdx'] is num ? (raw['itemIdx'] as num).toInt() : null,
      layer: raw['layer'] is num ? (raw['layer'] as num).toInt() : null,
      mediaType: raw['mediaType']?.toString(),
      status: raw['status']?.toString(),
      source: raw['source']?.toString(),
      createdAt: raw['createdAt']?.toString(),
      n2Reason: raw['n2Reason']?.toString(),
      n3Reason: raw['n3Reason']?.toString(),
      localeContract: _localeContractFromJson(raw['localeContract']),
      mediaTextLanguage: raw['mediaTextLanguage']?.toString(),
      explanationLanguage: raw['explanationLanguage']?.toString(),
      targetLanguage: raw['targetLanguage']?.toString(),
      visualTextPolicy: raw['visualTextPolicy']?.toString(),
    );
    return metadata.isEmpty ? null : metadata;
  }
}

String? _hashString(String? input) {
  if (input == null || input.trim().isEmpty) return null;
  var hash = 5381;
  for (final unit in input.codeUnits) {
    hash = ((hash << 5) + hash) ^ unit;
  }
  return (hash & 0xffffffff).toRadixString(36);
}

SimLocaleContract? _localeContractFromJson(Object? raw) {
  if (raw is! Map) return null;
  return SimLocaleContract.fromJson(Map<String, dynamic>.from(raw));
}

String? _normalizeVisualToken(Object? raw) {
  final text = raw
      ?.toString()
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return text == null || text.isEmpty ? null : text;
}

LessonVisualSupportType? _explicitVisualType(Object? raw) {
  final value = _normalizeVisualToken(raw);
  if (value == null ||
      value == 'image' ||
      value == 'imagem' ||
      value == 'static_image' ||
      value == 'pedagogical_image' ||
      value == 'imagem_pedagogica' ||
      value == 'photo' ||
      value == 'picture') {
    return null;
  }
  return lessonVisualSupportTypeFrom(value);
}

String? _nonEmptyText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool _hasLessonText(LessonVisualSupportCandidate candidate) {
  return _nonEmptyText(candidate.subject) != null ||
      _nonEmptyText(candidate.explanation) != null ||
      _nonEmptyText(candidate.question) != null ||
      candidate.options.any((option) => _nonEmptyText(option) != null);
}

String _lessonText(LessonVisualSupportCandidate candidate) {
  final parts = [
    candidate.subject,
    candidate.description,
    candidate.reason,
    candidate.explanation,
    candidate.question,
    ...candidate.options,
  ];
  return _foldText(parts.whereType<String>().join(' '));
}

String _foldText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[áàâãä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôõö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c');
}

int _score(String text, List<String> signals) {
  var score = 0;
  for (final signal in signals) {
    if (text.contains(_foldText(signal))) score++;
  }
  return score;
}

bool _hasExplicitVisualGainWord(String text) {
  return _score(text, const [
        'visualize',
        'observe',
        'imagem',
        'figura',
        'desenho',
        'modelo',
        'representacao',
      ]) >=
      1;
}

bool _triggerTextHas(
  LessonVisualSupportCandidate candidate,
  List<String> signals,
) {
  final text = _foldText(
    [candidate.description, candidate.reason].whereType<String>().join(' '),
  );
  return _score(text, signals) >= 1;
}

String _intentionFor(
  LessonVisualSupportType type,
  LessonVisualSupportCandidate candidate,
) {
  final anchor =
      _nonEmptyText(candidate.subject) ??
      _nonEmptyText(candidate.question) ??
      _nonEmptyText(candidate.description) ??
      _nonEmptyText(candidate.explanation) ??
      'conceito da aula';
  final compactAnchor = anchor.length > 96
      ? '${anchor.substring(0, 96)}...'
      : anchor;
  if (type == LessonVisualSupportType.none) {
    return 'sem visual pedagogico para $compactAnchor';
  }
  return '${type.pedagogicalLabel} de $compactAnchor';
}

String _titleFor(
  LessonVisualTypeSelection selection,
  LessonVisualSupportCandidate candidate,
) {
  final anchor =
      _nonEmptyText(candidate.subject) ??
      _nonEmptyText(candidate.question) ??
      _nonEmptyText(candidate.description) ??
      selection.type.pedagogicalLabel;
  return _compact(_stripQuestion(anchor), 48);
}

List<String> _candidateLines(LessonVisualSupportCandidate candidate) {
  final raw = [
    candidate.explanation,
    candidate.question,
    candidate.description,
    candidate.reason,
    ...candidate.options,
  ].whereType<String>().join('. ');
  return raw
      .split(RegExp(r'[.;\n]|\s(?:->|→)\s'))
      .map((part) => _compact(part.trim(), 72))
      .where((part) => part.length >= 3)
      .toList();
}

List<List<String>> _comparisonPairs(
  LessonVisualSupportCandidate candidate,
  List<String> lines,
) {
  final options = candidate.options
      .map((option) => _compact(option, 48))
      .where((option) => option.isNotEmpty)
      .take(3)
      .toList();
  if (options.length >= 2) {
    return [
      ['A', options[0]],
      ['B', options[1]],
      if (options.length > 2) ['C', options[2]],
    ];
  }
  final text = [
    candidate.explanation,
    candidate.question,
    candidate.description,
  ].whereType<String>().join(' ');
  final versus = text.split(
    RegExp(r'\s(?:versus|vs\.?|x)\s', caseSensitive: false),
  );
  if (versus.length >= 2) {
    return [
      ['1', _compact(versus.first, 48)],
      ['2', _compact(versus[1], 48)],
    ];
  }
  final folded = _foldText(text);
  if (lines.length >= 2 &&
      (folded.contains('antes') || folded.contains('depois'))) {
    return [
      ['Antes', lines[0]],
      ['Depois', lines[1]],
    ];
  }
  return const [];
}

List<List<String>> _tableRows(
  LessonVisualSupportCandidate candidate,
  List<String> lines,
) {
  final options = candidate.options
      .map((option) => _compact(option, 54))
      .where((option) => option.isNotEmpty)
      .take(4)
      .toList();
  if (options.length >= 2) {
    return [
      for (var i = 0; i < options.length; i++) ['${i + 1}', options[i]],
    ];
  }
  if (lines.length >= 2) {
    return [
      for (var i = 0; i < lines.take(4).length; i++) ['${i + 1}', lines[i]],
    ];
  }
  return const [];
}

List<String> _steps(List<String> lines) {
  final filtered = lines
      .where((line) => !_foldText(line).contains('qual alternativa'))
      .map((line) => _compact(line, 58))
      .toList();
  if (filtered.length >= 3) return filtered;
  return const [];
}

List<String> _concepts(
  LessonVisualSupportCandidate candidate,
  List<String> lines,
) {
  final fromOptions = candidate.options
      .map((option) => _compact(option, 40))
      .where((option) => option.isNotEmpty)
      .take(3)
      .toList();
  if (fromOptions.length >= 3) return fromOptions;
  final nouns = <String>[];
  for (final line in lines) {
    for (final part in line.split(RegExp(r',|\se\s|\sou\s'))) {
      final compact = _compact(part, 40);
      if (compact.length >= 4 && !nouns.contains(compact)) nouns.add(compact);
      if (nouns.length == 3) return nouns;
    }
  }
  return nouns;
}

List<String> _diagramParts(List<String> lines) {
  final out = <String>[];
  for (final line in lines) {
    final folded = _foldText(line);
    if (folded.contains('sistema') ||
        folded.contains('parte') ||
        folded.contains('estrutura') ||
        folded.contains('componente') ||
        folded.contains('camada')) {
      out.add(_compact(line, 44));
    }
  }
  return out;
}

bool _looksComplexForLocalDiagram(LessonVisualSupportCandidate candidate) {
  final text = _lessonText(candidate);
  return _score(text, const [
        'anatomia detalhada',
        'mapa detalhado',
        'circuito complexo',
        'orgao especifico',
        'desenho especifico',
        'precisao anatomica',
      ]) >=
      1;
}

String _comparisonSvg(String title, List<List<String>> pairs) {
  final left = pairs.first[1];
  final right = pairs.length > 1 ? pairs[1][1] : '';
  return _svgFrame(title, [
    '<rect x="48" y="144" width="240" height="420" rx="18" fill="#F8FAFC" stroke="#2563EB" stroke-width="2"/>',
    '<rect x="352" y="144" width="240" height="420" rx="18" fill="#F0FDF4" stroke="#16A34A" stroke-width="2"/>',
    _svgText('A', 76, 194, 24, '#2563EB', weight: '700'),
    _svgMultiline(left, 76, 244, 34, 30, '#111827'),
    _svgText('B', 380, 194, 24, '#16A34A', weight: '700'),
    _svgMultiline(right, 380, 244, 34, 30, '#111827'),
  ]);
}

String _tableSvg(String title, List<List<String>> rows) {
  final elements = <String>[
    '<rect x="48" y="132" width="544" height="432" rx="18" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="2"/>',
    '<line x1="160" y1="132" x2="160" y2="564" stroke="#CBD5E1" stroke-width="2"/>',
  ];
  const rowHeight = 96.0;
  for (var i = 0; i < rows.length; i++) {
    final y = 132 + i * rowHeight;
    if (i > 0) {
      elements.add(
        '<line x1="48" y1="$y" x2="592" y2="$y" stroke="#E2E8F0" stroke-width="2"/>',
      );
    }
    elements
      ..add(_svgText(rows[i][0], 84, y + 58, 22, '#2563EB', weight: '700'))
      ..add(_svgMultiline(rows[i][1], 188, y + 40, 32, 24, '#111827'));
  }
  return _svgFrame(title, elements);
}

String _stepsSvg(String title, List<String> steps) {
  final elements = <String>[];
  for (var i = 0; i < steps.length; i++) {
    final y = 138 + i * 84;
    elements
      ..add('<circle cx="84" cy="$y" r="24" fill="#2563EB"/>')
      ..add(_svgText('${i + 1}', 76, y + 8, 20, '#FFFFFF', weight: '700'))
      ..add(
        '<rect x="128" y="${y - 32}" width="432" height="64" rx="16" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="2"/>',
      )
      ..add(_svgMultiline(steps[i], 152, y - 2, 44, 21, '#111827'));
    if (i < steps.length - 1) {
      elements.add(
        '<line x1="84" y1="${y + 26}" x2="84" y2="${y + 58}" stroke="#94A3B8" stroke-width="3"/>',
      );
    }
  }
  return _svgFrame(title, elements);
}

String _conceptMapSvg(String title, List<String> concepts) {
  final center = _compact(title, 28);
  final positions = const [
    [80, 210],
    [374, 210],
    [226, 428],
  ];
  final elements = <String>[
    '<ellipse cx="320" cy="328" rx="112" ry="58" fill="#EFF6FF" stroke="#2563EB" stroke-width="2"/>',
    _svgMultiline(center, 260, 316, 20, 20, '#111827'),
  ];
  for (var i = 0; i < concepts.length; i++) {
    final x = positions[i][0];
    final y = positions[i][1];
    elements
      ..add(
        '<line x1="320" y1="328" x2="${x + 92}" y2="${y + 42}" stroke="#94A3B8" stroke-width="2"/>',
      )
      ..add(
        '<rect x="$x" y="$y" width="184" height="84" rx="18" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="2"/>',
      )
      ..add(_svgMultiline(concepts[i], x + 18, y + 40, 22, 20, '#111827'));
  }
  return _svgFrame(title, elements);
}

String _diagramSvg(String title, List<String> parts) {
  final elements = <String>[
    '<rect x="96" y="152" width="448" height="360" rx="28" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="2"/>',
  ];
  for (var i = 0; i < parts.length; i++) {
    final y = 196 + i * 72;
    elements
      ..add('<circle cx="156" cy="$y" r="18" fill="#F59E0B"/>')
      ..add(_svgText('${i + 1}', 150, y + 7, 18, '#111827', weight: '700'))
      ..add(_svgMultiline(parts[i], 196, y + 2, 38, 21, '#111827'));
  }
  return _svgFrame(title, elements);
}

String _svgFrame(String title, List<String> children) {
  final safeTitle = _xml(title);
  return '<svg viewBox="0 0 600 800" role="img" aria-label="$safeTitle">'
      '<rect width="600" height="800" rx="0" fill="#FFFFFF"/>'
      '<rect x="24" y="24" width="552" height="752" rx="24" fill="#FFFFFF" stroke="#E2E8F0" stroke-width="2"/>'
      '${_svgMultiline(title, 64, 86, 38, 26, '#111827', weight: '700')}'
      '${children.join()}'
      '</svg>';
}

String _svgText(
  String text,
  num x,
  num y,
  num size,
  String color, {
  String weight = '500',
}) {
  return '<text x="$x" y="$y" fill="$color" font-family="Arial, sans-serif" font-size="$size" font-weight="$weight">${_xml(text)}</text>';
}

String _svgMultiline(
  String text,
  num x,
  num y,
  int maxChars,
  num size,
  String color, {
  String weight = '500',
}) {
  final words = _xml(text).split(RegExp(r'\s+'));
  final lines = <String>[];
  var current = '';
  for (final word in words) {
    final next = current.isEmpty ? word : '$current $word';
    if (next.length > maxChars && current.isNotEmpty) {
      lines.add(current);
      current = word;
    } else {
      current = next;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return [
    for (var i = 0; i < lines.take(3).length; i++)
      '<text x="$x" y="${y + i * (size + 5)}" fill="$color" font-family="Arial, sans-serif" font-size="$size" font-weight="$weight">${lines[i]}</text>',
  ].join();
}

String _compact(String value, int max) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.length <= max) return text;
  return '${text.substring(0, max - 3).trim()}...';
}

String _stripQuestion(String value) => value.replaceAll(RegExp(r'\?$'), '');

String _xml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

bool _isSafeLocalTemplateSvg(String svg) {
  final lower = svg.toLowerCase();
  if (!lower.startsWith('<svg') || !lower.contains('</svg>')) return false;
  return !RegExp(
    r'<script|foreignobject|<image|webview|javascript:|https?://|href=|xlink:href=|<iframe|<object|<embed|\son[a-z]+\s*=',
    caseSensitive: false,
  ).hasMatch(svg);
}

bool _looksDecorative(String text) {
  final normalized = text.toLowerCase();
  return RegExp(
    r'\b(decorativo|decorativa|decoracao|enfeite|ornamento|ornamental|wallpaper|stock|hero|fundo_bonito|background_only|pretty|embelezar)\b',
  ).hasMatch(normalized);
}

bool _dependsOnlyOnColor(String text) {
  final normalized = text.toLowerCase();
  return normalized.contains('apenas cor') ||
      normalized.contains('so por cor') ||
      normalized.contains('somente cor') ||
      normalized.contains('only color') ||
      normalized.contains('color only');
}

bool _looksPedagogicallyUseful(
  LessonVisualSupportCandidate candidate,
  LessonVisualSupportType type,
) {
  if (type == LessonVisualSupportType.none) return false;
  if (_nonEmptyText(candidate.description) != null ||
      _nonEmptyText(candidate.reason) != null ||
      _nonEmptyText(candidate.svg) != null ||
      candidate.hasLocalTemplate) {
    return true;
  }
  if (_hasLessonText(candidate)) return true;
  return type != LessonVisualSupportType.pedagogicalImage ||
      _nonEmptyText(candidate.typeHint) != null;
}

bool _safeVisualCandidate(LessonVisualSupportCandidate candidate) {
  final svg = _nonEmptyText(candidate.svg);
  if (svg != null && !_isSafeInlineSvg(svg)) return false;
  final text = _rawValues(candidate.raw).join(' ').toLowerCase();
  final unsafe = RegExp(
    r'<script|javascript:|<iframe|<object|<embed|foreignobject',
  );
  if (unsafe.hasMatch(text)) return false;
  if (RegExp(r'https?://').hasMatch(text) && svg != null) return false;
  return true;
}

bool _isSafeInlineSvg(String raw) {
  final svg = raw.trim();
  if (svg.isEmpty || svg.length > 24000) return false;
  final lower = svg.toLowerCase();
  if (!lower.startsWith('<svg') || !lower.contains('</svg>')) return false;
  return !RegExp(
    r'<script|foreignobject|javascript:|<iframe|<object|<embed|https?://|\son[a-z]+\s*=',
    caseSensitive: false,
  ).hasMatch(svg);
}

bool _lightVisualCandidate(
  LessonVisualSupportCandidate candidate,
  int maxInlinePayloadChars,
) {
  for (final entry in candidate.raw.entries) {
    final key = entry.key.toString().toLowerCase();
    final value = entry.value?.toString() ?? '';
    final storesHeavyPayload =
        key.contains('base64') ||
        key.contains('blob') ||
        key.contains('dataurl') ||
        key.contains('data_url');
    if (storesHeavyPayload && value.isNotEmpty) return false;
    if (value.length > maxInlinePayloadChars) return false;
  }
  final svg = candidate.svg;
  if (svg != null && svg.length > maxInlinePayloadChars) return false;
  return true;
}

String? _visualAccessibilityDescription(
  LessonVisualSupportCandidate candidate,
  LessonVisualSupportType type,
) {
  return _nonEmptyText(candidate.description) ??
      _nonEmptyText(candidate.reason) ??
      _nonEmptyText(candidate.raw['alt']) ??
      _nonEmptyText(candidate.raw['alt_text']) ??
      _nonEmptyText(candidate.raw['accessibilityLabel']) ??
      type.pedagogicalLabel;
}

String _visualRejectionReason({
  required bool decorative,
  required bool useful,
  required bool safe,
  required bool light,
  required bool accessible,
}) {
  if (decorative || !useful) return 'apoio_visual_sem_funcao_pedagogica';
  if (!safe) return 'apoio_visual_inseguro';
  if (!light) return 'apoio_visual_pesado';
  if (!accessible) return 'apoio_visual_sem_acessibilidade_minima';
  return 'apoio_visual_indisponivel';
}

Iterable<Object> _rawValues(Object? value) sync* {
  if (value is Map) {
    for (final entry in value.entries) {
      yield entry.key;
      yield* _rawValues(entry.value);
    }
    return;
  }
  if (value is Iterable) {
    for (final item in value) {
      yield* _rawValues(item);
    }
    return;
  }
  if (value != null) yield value;
}
