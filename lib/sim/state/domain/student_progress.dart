part of '../student_learning_state.dart';

class LessonCurrent {
  const LessonCurrent({
    required this.itemIdx,
    required this.marker,
    required this.layer,
    required this.amparoLvl,
  });

  final int itemIdx;
  final String? marker;
  final LessonLayer layer;
  final int amparoLvl;

  JsonMap toJson() => {
    'itemIdx': itemIdx,
    'marker': marker,
    'layer': layer.value,
    'amparoLvl': amparoLvl,
  };

  factory LessonCurrent.fromJson(JsonMap json) => LessonCurrent(
    itemIdx: (json['itemIdx'] as num?)?.toInt() ?? 0,
    marker: json['marker'] as String?,
    layer: LessonLayerValue.fromValue(json['layer']),
    amparoLvl: (json['amparoLvl'] as num?)?.toInt() ?? 0,
  );
}

class LessonProgress {
  const LessonProgress({
    required this.itemIdx,
    required this.layer,
    required this.erros,
    required this.amparoLvl,
    required this.historia,
    required this.mainAdvances,
    required this.concluidos,
    required this.pendentesMarkers,
    required this.totalItems,
    required this.pctAvanco,
  });

  final int itemIdx;
  final LessonLayer layer;
  final int erros;
  final int amparoLvl;
  final List<String> historia;
  final int mainAdvances;
  final List<String> concluidos;
  final List<String> pendentesMarkers;
  final int totalItems;
  final int pctAvanco;

  LessonProgress copyWith({
    int? itemIdx,
    LessonLayer? layer,
    int? erros,
    int? amparoLvl,
    List<String>? historia,
    int? mainAdvances,
    List<String>? concluidos,
    List<String>? pendentesMarkers,
    int? totalItems,
    int? pctAvanco,
  }) {
    return LessonProgress(
      itemIdx: itemIdx ?? this.itemIdx,
      layer: layer ?? this.layer,
      erros: erros ?? this.erros,
      amparoLvl: amparoLvl ?? this.amparoLvl,
      historia: historia ?? this.historia,
      mainAdvances: mainAdvances ?? this.mainAdvances,
      concluidos: concluidos ?? this.concluidos,
      pendentesMarkers: pendentesMarkers ?? this.pendentesMarkers,
      totalItems: totalItems ?? this.totalItems,
      pctAvanco: pctAvanco ?? this.pctAvanco,
    );
  }

  JsonMap toJson() => {
    'itemIdx': itemIdx,
    'layer': layer.value,
    'erros': erros,
    'amparoLvl': amparoLvl,
    'historia': historia,
    'mainAdvances': mainAdvances,
    'concluidos': concluidos,
    'pendentesMarkers': pendentesMarkers,
    'totalItems': totalItems,
    'pctAvanco': pctAvanco,
  };

  factory LessonProgress.fromJson(JsonMap json) => LessonProgress(
    itemIdx: (json['itemIdx'] as num?)?.toInt() ?? 0,
    layer: LessonLayerValue.fromValue(json['layer']),
    erros: (json['erros'] as num?)?.toInt() ?? 0,
    amparoLvl: (json['amparoLvl'] as num?)?.toInt() ?? 0,
    historia: (json['historia'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(),
    mainAdvances: (json['mainAdvances'] as num?)?.toInt() ?? 0,
    concluidos: (json['concluidos'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(),
    pendentesMarkers: (json['pendentesMarkers'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(),
    totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
    pctAvanco: (json['pctAvanco'] as num?)?.toInt() ?? 0,
  );
}

typedef StudentProgress = LessonProgress;

class LessonAttempt {
  const LessonAttempt({
    required this.marker,
    required this.layer,
    required this.letra,
    required this.sinal,
    required this.correct,
    required this.ts,
  });

  final String marker;
  final LessonLayer layer;
  final AnswerLetter letra;
  final DecisionSignal sinal;
  final bool correct;
  final int ts;

  JsonMap toJson() => {
    'marker': marker,
    'layer': layer.value,
    'letra': letra.name,
    'sinal': sinal.value,
    'correct': correct,
    'ts': ts,
  };

  factory LessonAttempt.fromJson(JsonMap json) => LessonAttempt(
    marker: (json['marker'] ?? '').toString(),
    layer: LessonLayerValue.fromValue(json['layer']),
    letra: AnswerLetter.values.firstWhere(
      (letter) => letter.name == json['letra'],
      orElse: () => AnswerLetter.A,
    ),
    sinal: DecisionSignalValue.fromValue(json['sinal']),
    correct: json['correct'] == true,
    ts: (json['ts'] as num?)?.toInt() ?? 0,
  );
}
