import 'dart:convert';

import 'package:cryptography/dart.dart';

import '../state/student_learning_state.dart';
import 'pedagogical_card.dart';

final class PedagogicalCardIntegrityException implements Exception {
  const PedagogicalCardIntegrityException(this.message);

  final String message;

  @override
  String toString() => 'PedagogicalCardIntegrityException: $message';
}

final class PedagogicalCardIntegrityVerifier {
  const PedagogicalCardIntegrityVerifier._();

  static String contentHashForCard(PedagogicalCard card) {
    final payload = _essentialCardPayload(card);
    final hash = const DartSha256().hashSync(
      utf8.encode(_stableStringify(payload)),
    );
    return _hex(hash.bytes);
  }

  static void verifyContentHash(PedagogicalCard card) {
    card.validate();
    final expected = contentHashForCard(card);
    if (card.contentHash != expected) {
      throw const PedagogicalCardIntegrityException('contentHash_mismatch');
    }
  }

  static void requireServerSignature(PedagogicalCard card) {
    card.validate();
    if (card.serverSignature.trim().isEmpty) {
      throw const PedagogicalCardIntegrityException('serverSignature_required');
    }
  }

  static void verifyForRuntime(PedagogicalCard card) {
    verifyContentHash(card);
    requireServerSignature(card);
  }

  static void verifyServerSignature(PedagogicalCard card) {
    requireServerSignature(card);
    throw const PedagogicalCardIntegrityException(
      'signatureVerificationUnavailable',
    );
  }

  static String stableStringifyForTest(Object? value) =>
      _stableStringify(value);
}

Map<String, Object?> _essentialCardPayload(PedagogicalCard card) => {
  'cardId': card.cardId,
  'deckId': card.deckId,
  'lessonLocalId': card.lessonLocalId,
  'marker': card.marker,
  'itemIdx': card.itemIdx,
  'layer': card.layer.value,
  'explanation': card.explanation,
  'question': card.question,
  'options': {
    'A': card.options[AnswerLetter.A],
    'B': card.options[AnswerLetter.B],
    'C': card.options[AnswerLetter.C],
  },
  'correctAnswer': card.correctAnswer.name,
  'feedback': {
    'A': card.feedback[AnswerLetter.A],
    'B': card.feedback[AnswerLetter.B],
    'C': card.feedback[AnswerLetter.C],
  },
  'qualifiers': {
    '1': card.qualifiers[DecisionSignal.one],
    '2': card.qualifiers[DecisionSignal.two],
    '3': card.qualifiers[DecisionSignal.three],
  },
  'advancePolicy': {
    '1': card.advancePolicy[DecisionSignal.one],
    '2': card.advancePolicy[DecisionSignal.two],
    '3': card.advancePolicy[DecisionSignal.three],
  },
  'media': card.media == null
      ? null
      : {'imageKey': card.media!.imageKey, 'audioKey': card.media!.audioKey},
  'contractVersion': card.contractVersion,
};

String _stableStringify(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return jsonEncode(value);
  }
  if (value is List) {
    return '[${value.map(_stableStringify).join(',')}]';
  }
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_stableStringify(value[key])}').join(',')}}';
  }
  throw const PedagogicalCardIntegrityException('unsupported_hash_value');
}

String _hex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
