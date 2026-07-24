import '../state/student_learning_state.dart';
import 'pedagogical_card.dart';

final class PedagogicalCardFactoryAdapterException implements Exception {
  const PedagogicalCardFactoryAdapterException(this.message);

  final String message;

  @override
  String toString() => 'PedagogicalCardFactoryAdapterException: $message';
}

final class PedagogicalCardSource {
  PedagogicalCardSource({
    required this.lessonLocalId,
    required this.deckId,
    required this.cardId,
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
    required this.serverSignature,
    required this.generationOperationId,
    required this.contractVersion,
    this.media,
  }) : options = Map<AnswerLetter, String>.unmodifiable(options),
       feedback = Map<AnswerLetter, String>.unmodifiable(feedback),
       qualifiers = Map<DecisionSignal, String>.unmodifiable(qualifiers),
       advancePolicy = Map<DecisionSignal, String>.unmodifiable(advancePolicy) {
    validate();
  }

  final String lessonLocalId;
  final String deckId;
  final String cardId;
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
  final PedagogicalCardMedia? media;
  final String contentHash;
  final String serverSignature;
  final String generationOperationId;
  final int contractVersion;

  static PedagogicalCardSource fromJson(Map<String, Object?> value) {
    _rejectUnknownKeys(value, _sourceKeys);
    return PedagogicalCardSource(
      lessonLocalId: _requiredString(
        value['lessonLocalId'],
        'lessonLocalId_required',
      ),
      deckId: _requiredString(value['deckId'], 'deckId_required'),
      cardId: _requiredString(value['cardId'], 'cardId_required'),
      marker: _requiredString(value['marker'], 'marker_required'),
      itemIdx: _requiredNonNegativeInt(
        value['itemIdx'],
        'itemIdx_required',
        'itemIdx_must_be_nonnegative',
      ),
      layer: _parseLessonLayer(value['layer']),
      explanation: _requiredString(
        value['explanation'],
        'explanation_required',
      ),
      question: _requiredString(value['question'], 'question_required'),
      options: _parseAnswerTextMap(value['options'], 'options'),
      correctAnswer: _parseAnswerLetter(value['correctAnswer']),
      feedback: _parseAnswerTextMap(value['feedback'], 'feedback'),
      qualifiers: _parseSignalTextMap(value['qualifiers'], 'qualifiers'),
      advancePolicy: _parseSignalTextMap(
        value['advancePolicy'],
        'advancePolicy',
      ),
      media: _parseMedia(value['media']),
      contentHash: _requiredString(
        value['contentHash'],
        'contentHash_required',
      ),
      serverSignature: _requiredString(
        value['serverSignature'],
        'serverSignature_required',
      ),
      generationOperationId: _requiredString(
        value['generationOperationId'],
        'generationOperationId_required',
      ),
      contractVersion: _requiredContractVersion(value['contractVersion']),
    );
  }

  void validate() {
    _requiredString(lessonLocalId, 'lessonLocalId_required');
    _requiredString(deckId, 'deckId_required');
    _requiredString(cardId, 'cardId_required');
    _requiredString(marker, 'marker_required');
    if (itemIdx < 0) {
      throw const PedagogicalCardFactoryAdapterException(
        'itemIdx_must_be_nonnegative',
      );
    }
    _requiredString(explanation, 'explanation_required');
    _requiredString(question, 'question_required');
    _validateAnswerTextMap(options, 'options');
    if (!options.containsKey(correctAnswer)) {
      throw const PedagogicalCardFactoryAdapterException(
        'correctAnswer_must_be_A_B_or_C',
      );
    }
    _validateAnswerTextMap(feedback, 'feedback');
    _validateSignalTextMap(qualifiers, 'qualifiers');
    _validateSignalTextMap(advancePolicy, 'advancePolicy');
    media?.validate();
    _requiredString(contentHash, 'contentHash_required');
    _requiredString(serverSignature, 'serverSignature_required');
    _requiredString(generationOperationId, 'generationOperationId_required');
    if (contractVersion != PedagogicalCard.supportedContractVersion) {
      throw const PedagogicalCardFactoryAdapterException(
        'contractVersion_unsupported',
      );
    }
  }
}

final class PedagogicalCardFactoryAdapter {
  const PedagogicalCardFactoryAdapter();

  PedagogicalCard adapt(PedagogicalCardSource source) {
    source.validate();
    final card = PedagogicalCard(
      cardId: source.cardId,
      deckId: source.deckId,
      lessonLocalId: source.lessonLocalId,
      marker: source.marker,
      itemIdx: source.itemIdx,
      layer: source.layer,
      explanation: source.explanation,
      question: source.question,
      options: source.options,
      correctAnswer: source.correctAnswer,
      feedback: source.feedback,
      qualifiers: source.qualifiers,
      advancePolicy: source.advancePolicy,
      contentHash: source.contentHash,
      contractVersion: source.contractVersion,
      serverSignature: source.serverSignature,
      media: source.media,
    );
    card.validate();
    return card;
  }
}

const Set<String> _sourceKeys = {
  'lessonLocalId',
  'deckId',
  'cardId',
  'marker',
  'itemIdx',
  'layer',
  'explanation',
  'question',
  'options',
  'correctAnswer',
  'feedback',
  'qualifiers',
  'advancePolicy',
  'media',
  'contentHash',
  'serverSignature',
  'generationOperationId',
  'contractVersion',
};

const Set<String> _mediaKeys = {'imageKey', 'audioKey'};
const Set<String> _answerKeys = {'A', 'B', 'C'};
const Set<String> _signalKeys = {'1', '2', '3'};

void _rejectUnknownKeys(Map<String, Object?> value, Set<String> allowed) {
  for (final key in value.keys) {
    if (!allowed.contains(key)) {
      throw const PedagogicalCardFactoryAdapterException('unknown_field');
    }
  }
}

String _requiredString(Object? value, String message) {
  if (value is! String) {
    throw PedagogicalCardFactoryAdapterException(message);
  }
  final text = value.trim();
  if (text.isEmpty) {
    throw PedagogicalCardFactoryAdapterException(message);
  }
  return text;
}

int _requiredNonNegativeInt(
  Object? value,
  String requiredMessage,
  String rangeMessage,
) {
  if (value is! int) {
    throw PedagogicalCardFactoryAdapterException(requiredMessage);
  }
  if (value < 0) {
    throw PedagogicalCardFactoryAdapterException(rangeMessage);
  }
  return value;
}

int _requiredContractVersion(Object? value) {
  if (value != PedagogicalCard.supportedContractVersion) {
    throw const PedagogicalCardFactoryAdapterException(
      'contractVersion_unsupported',
    );
  }
  return PedagogicalCard.supportedContractVersion;
}

LessonLayer _parseLessonLayer(Object? value) {
  return switch (value) {
    1 || '1' || 'l1' => LessonLayer.l1,
    2 || '2' || 'l2' => LessonLayer.l2,
    3 || '3' || 'l3' => LessonLayer.l3,
    _ => throw const PedagogicalCardFactoryAdapterException(
      'layer_must_be_1_2_or_3',
    ),
  };
}

AnswerLetter _parseAnswerLetter(Object? value) {
  return switch (value) {
    'A' => AnswerLetter.A,
    'B' => AnswerLetter.B,
    'C' => AnswerLetter.C,
    _ => throw const PedagogicalCardFactoryAdapterException(
      'correctAnswer_must_be_A_B_or_C',
    ),
  };
}

Map<AnswerLetter, String> _parseAnswerTextMap(Object? value, String field) {
  if (value is! Map<String, Object?>) {
    throw PedagogicalCardFactoryAdapterException('${field}_required');
  }
  _rejectUnknownKeys(value, _answerKeys);
  return {
    AnswerLetter.A: _requiredString(value['A'], '${field}_A_required'),
    AnswerLetter.B: _requiredString(value['B'], '${field}_B_required'),
    AnswerLetter.C: _requiredString(value['C'], '${field}_C_required'),
  };
}

Map<DecisionSignal, String> _parseSignalTextMap(Object? value, String field) {
  if (value is! Map<String, Object?>) {
    throw PedagogicalCardFactoryAdapterException('${field}_required');
  }
  _rejectUnknownKeys(value, _signalKeys);
  return {
    DecisionSignal.one: _requiredString(value['1'], '${field}_1_required'),
    DecisionSignal.two: _requiredString(value['2'], '${field}_2_required'),
    DecisionSignal.three: _requiredString(value['3'], '${field}_3_required'),
  };
}

void _validateAnswerTextMap(Map<AnswerLetter, String> value, String field) {
  if (value.length != AnswerLetter.values.length) {
    throw PedagogicalCardFactoryAdapterException('${field}_must_have_A_B_C');
  }
  for (final letter in AnswerLetter.values) {
    _requiredString(value[letter], '${field}_${letter.name}_required');
  }
}

void _validateSignalTextMap(Map<DecisionSignal, String> value, String field) {
  if (value.length != DecisionSignal.values.length) {
    throw PedagogicalCardFactoryAdapterException('${field}_must_have_1_2_3');
  }
  for (final signal in DecisionSignal.values) {
    _requiredString(value[signal], '${field}_${signal.value}_required');
  }
}

PedagogicalCardMedia? _parseMedia(Object? value) {
  if (value == null) return null;
  if (value is! Map<String, Object?>) {
    throw const PedagogicalCardFactoryAdapterException('media_must_be_object');
  }
  _rejectUnknownKeys(value, _mediaKeys);
  return PedagogicalCardMedia(
    imageKey: _optionalMediaKey(value['imageKey'], 'imageKey'),
    audioKey: _optionalMediaKey(value['audioKey'], 'audioKey'),
  );
}

String? _optionalMediaKey(Object? value, String field) {
  if (value == null) return null;
  final key = _requiredString(value, '${field}_must_not_be_empty');
  if (key.length > PedagogicalCardMedia.maxKeyLength) {
    throw PedagogicalCardFactoryAdapterException('${field}_too_large');
  }
  final lowered = key.toLowerCase();
  if (lowered.startsWith('data:') ||
      lowered.contains('base64') ||
      lowered.contains('<svg') ||
      lowered.contains('<xml') ||
      lowered.contains('<?xml') ||
      lowered.contains('<html') ||
      lowered.startsWith(['ht', 'tp://'].join()) ||
      lowered.startsWith(['ht', 'tps://'].join())) {
    throw PedagogicalCardFactoryAdapterException('${field}_must_be_light_key');
  }
  return key;
}
