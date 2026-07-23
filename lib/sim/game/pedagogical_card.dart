import '../state/student_learning_state.dart';

class PedagogicalCardContractException implements Exception {
  const PedagogicalCardContractException(this.message);

  final String message;

  @override
  String toString() => 'PedagogicalCardContractException: $message';
}

class PedagogicalCardMedia {
  const PedagogicalCardMedia({this.imageKey, this.audioKey});

  static const int maxKeyLength = 512;

  final String? imageKey;
  final String? audioKey;

  Map<String, dynamic> toJson() => {
    if (imageKey != null) 'imageKey': imageKey,
    if (audioKey != null) 'audioKey': audioKey,
  };

  static PedagogicalCardMedia? fromJson(Object? value) {
    if (value == null) return null;
    if (value is! Map) {
      throw const PedagogicalCardContractException('media_must_be_object');
    }
    return PedagogicalCardMedia(
      imageKey: _optionalMediaKey(value['imageKey'], 'imageKey'),
      audioKey: _optionalMediaKey(value['audioKey'], 'audioKey'),
    );
  }

  void validate() {
    _validateMediaKey(imageKey, 'imageKey');
    _validateMediaKey(audioKey, 'audioKey');
  }
}

class PedagogicalCard {
  PedagogicalCard({
    required this.cardId,
    required this.deckId,
    required this.lessonLocalId,
    required this.marker,
    required this.itemIdx,
    required this.layer,
    required this.explanation,
    required this.question,
    required Map<AnswerLetter, String> options,
    required this.correctAnswer,
    required Map<AnswerLetter, String> feedback,
    required Map<DecisionSignal, String> qualifiers,
    required Map<DecisionSignal, String> advancePolicy,
    required this.contentHash,
    required this.contractVersion,
    required this.serverSignature,
    this.media,
  }) : options = Map.unmodifiable(options),
       feedback = Map.unmodifiable(feedback),
       qualifiers = Map.unmodifiable(qualifiers),
       advancePolicy = Map.unmodifiable(advancePolicy) {
    validate();
  }

  static const int supportedContractVersion = 1;

  final String cardId;
  final String deckId;
  final String lessonLocalId;
  final String marker;
  final int itemIdx;
  final LessonLayer layer;
  final String explanation;
  final String question;
  final Map<AnswerLetter, String> options;
  final AnswerLetter correctAnswer;
  final Map<AnswerLetter, String> feedback;
  final Map<DecisionSignal, String> qualifiers;
  final Map<DecisionSignal, String> advancePolicy;
  final String contentHash;
  final int contractVersion;
  final String serverSignature;
  final PedagogicalCardMedia? media;

  bool get isValid {
    validate();
    return true;
  }

  void validate() {
    _requiredString(cardId, 'cardId_required');
    _requiredString(deckId, 'deckId_required');
    _requiredString(lessonLocalId, 'lessonLocalId_required');
    _requiredString(marker, 'marker_required');
    if (itemIdx < 0) {
      throw const PedagogicalCardContractException(
        'itemIdx_must_be_nonnegative',
      );
    }
    _requiredString(explanation, 'explanation_required');
    _requiredString(question, 'question_required');
    _validateAnswerTextMap(options, 'options');
    _validateAnswerTextMap(feedback, 'feedback');
    if (!options.containsKey(correctAnswer)) {
      throw const PedagogicalCardContractException(
        'correctAnswer_must_be_A_B_or_C',
      );
    }
    _validateSignalTextMap(qualifiers, 'qualifiers');
    _validateSignalTextMap(advancePolicy, 'advancePolicy');
    _requiredString(contentHash, 'contentHash_required');
    _requiredString(serverSignature, 'serverSignature_required');
    if (contractVersion <= 0) {
      throw const PedagogicalCardContractException(
        'contractVersion_must_be_positive',
      );
    }
    media?.validate();
  }

  Map<String, dynamic> toJson() => {
    'cardId': cardId,
    'deckId': deckId,
    'lessonLocalId': lessonLocalId,
    'marker': marker,
    'itemIdx': itemIdx,
    'layer': layer.value,
    'explanation': explanation,
    'question': question,
    'options': _answerMapToJson(options),
    'correctAnswer': correctAnswer.name,
    'feedback': _answerMapToJson(feedback),
    'qualifiers': _signalMapToJson(qualifiers),
    'advancePolicy': _signalMapToJson(advancePolicy),
    'contentHash': contentHash,
    'contractVersion': contractVersion,
    'serverSignature': serverSignature,
    if (media != null) 'media': media!.toJson(),
  };

  static PedagogicalCard fromJson(Object? value) {
    if (value is! Map) {
      throw const PedagogicalCardContractException('card_must_be_object');
    }
    return PedagogicalCard(
      cardId: _requiredString(value['cardId'], 'cardId_required'),
      deckId: _requiredString(value['deckId'], 'deckId_required'),
      lessonLocalId: _requiredString(
        value['lessonLocalId'],
        'lessonLocalId_required',
      ),
      marker: _requiredString(value['marker'], 'marker_required'),
      itemIdx: _requiredNonNegativeInt(value['itemIdx'], 'itemIdx_required'),
      layer: _parseLessonLayer(value['layer']),
      explanation: _requiredString(
        value['explanation'],
        'explanation_required',
      ),
      question: _requiredString(value['question'], 'question_required'),
      options: _parseAnswerTextMap(value['options'], 'options'),
      correctAnswer: _parseAnswerLetter(
        value['correctAnswer'] ?? value['correct_answer'],
      ),
      feedback: _parseAnswerTextMap(value['feedback'], 'feedback'),
      qualifiers: _parseSignalTextMap(value['qualifiers'], 'qualifiers'),
      advancePolicy: _parseSignalTextMap(
        value['advancePolicy'] ?? value['advance_policy'],
        'advancePolicy',
      ),
      contentHash: _requiredString(
        value['contentHash'],
        'contentHash_required',
      ),
      contractVersion: _requiredPositiveInt(
        value['contractVersion'],
        'contractVersion_required',
      ),
      serverSignature: _requiredString(
        value['serverSignature'],
        'serverSignature_required',
      ),
      media: PedagogicalCardMedia.fromJson(value['media']),
    );
  }
}

Map<String, String> _answerMapToJson(Map<AnswerLetter, String> value) => {
  for (final letter in AnswerLetter.values) letter.name: value[letter]!,
};

Map<String, String> _signalMapToJson(Map<DecisionSignal, String> value) => {
  for (final signal in DecisionSignal.values) '${signal.value}': value[signal]!,
};

Map<AnswerLetter, String> _parseAnswerTextMap(Object? value, String field) {
  if (value is! Map) {
    throw PedagogicalCardContractException('${field}_required');
  }
  return {
    for (final letter in AnswerLetter.values)
      letter: _requiredString(
        value[letter.name] ?? value[letter.name.toLowerCase()],
        '${field}_${letter.name}_required',
      ),
  };
}

Map<DecisionSignal, String> _parseSignalTextMap(Object? value, String field) {
  if (value is! Map) {
    throw PedagogicalCardContractException('${field}_required');
  }
  return {
    for (final signal in DecisionSignal.values)
      signal: _requiredString(
        value['${signal.value}'],
        '${field}_${signal.value}_required',
      ),
  };
}

void _validateAnswerTextMap(Map<AnswerLetter, String> value, String field) {
  if (value.length != AnswerLetter.values.length) {
    throw PedagogicalCardContractException('${field}_must_have_A_B_C');
  }
  for (final letter in AnswerLetter.values) {
    _requiredString(value[letter], '${field}_${letter.name}_required');
  }
}

void _validateSignalTextMap(Map<DecisionSignal, String> value, String field) {
  if (value.length != DecisionSignal.values.length) {
    throw PedagogicalCardContractException('${field}_must_have_1_2_3');
  }
  for (final signal in DecisionSignal.values) {
    _requiredString(value[signal], '${field}_${signal.value}_required');
  }
}

AnswerLetter _parseAnswerLetter(Object? value) {
  final raw = value?.toString().trim().toUpperCase();
  if (raw == null || raw.isEmpty) {
    throw const PedagogicalCardContractException('correctAnswer_required');
  }
  return AnswerLetter.values.firstWhere(
    (letter) => letter.name == raw,
    orElse: () => throw const PedagogicalCardContractException(
      'correctAnswer_must_be_A_B_or_C',
    ),
  );
}

LessonLayer _parseLessonLayer(Object? value) {
  final raw = value?.toString().trim().toLowerCase();
  return switch (raw) {
    '1' || 'l1' => LessonLayer.l1,
    '2' || 'l2' => LessonLayer.l2,
    '3' || 'l3' => LessonLayer.l3,
    _ => throw const PedagogicalCardContractException('layer_must_be_1_2_or_3'),
  };
}

String _requiredString(Object? value, String message) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    throw PedagogicalCardContractException(message);
  }
  return text;
}

int _requiredPositiveInt(Object? value, String message) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null || parsed <= 0) {
    throw PedagogicalCardContractException(message);
  }
  return parsed;
}

int _requiredNonNegativeInt(Object? value, String message) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null || parsed < 0) {
    throw PedagogicalCardContractException(message);
  }
  return parsed;
}

String? _optionalMediaKey(Object? value, String field) {
  if (value == null) return null;
  final key = _requiredString(value, '${field}_must_not_be_empty');
  _validateMediaKey(key, field);
  return key;
}

void _validateMediaKey(String? value, String field) {
  if (value == null) return;
  final key = value.trim();
  if (key.isEmpty) {
    throw PedagogicalCardContractException('${field}_must_not_be_empty');
  }
  if (key.length > PedagogicalCardMedia.maxKeyLength) {
    throw PedagogicalCardContractException('${field}_too_large');
  }
  final lowered = key.toLowerCase();
  if (lowered.startsWith('data:') ||
      lowered.contains('base64,') ||
      lowered.contains('<svg') ||
      lowered.contains('<?xml') ||
      lowered.contains('<xml')) {
    throw PedagogicalCardContractException('${field}_must_be_light_key');
  }
}
