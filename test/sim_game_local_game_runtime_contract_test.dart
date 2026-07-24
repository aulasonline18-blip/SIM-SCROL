import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/local_game_runtime.dart';
import 'package:sim_mobile/sim/game/pedagogical_card.dart';
import 'package:sim_mobile/sim/game/pedagogical_card_integrity_verifier.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

PedagogicalCard _unsignedCard({String signature = 'signature-x'}) =>
    PedagogicalCard(
      cardId: 'card-1',
      deckId: 'deck-1',
      lessonLocalId: 'lesson-1',
      marker: 'm1',
      itemIdx: 0,
      layer: LessonLayer.l1,
      explanation: 'Texto pronto.',
      question: 'Pergunta pronta?',
      options: const {
        AnswerLetter.A: 'Alternativa A',
        AnswerLetter.B: 'Alternativa B',
        AnswerLetter.C: 'Alternativa C',
      },
      correctAnswer: AnswerLetter.A,
      feedback: const {
        AnswerLetter.A: 'Feedback A',
        AnswerLetter.B: 'Feedback B',
        AnswerLetter.C: 'Feedback C',
      },
      qualifiers: const {
        DecisionSignal.one: 'Tenho certeza',
        DecisionSignal.two: 'Tenho duvida',
        DecisionSignal.three: 'Estou inseguro',
      },
      advancePolicy: const {
        DecisionSignal.one: 'avancar',
        DecisionSignal.two: 'cuidado',
        DecisionSignal.three: 'revisar',
      },
      contentHash: 'unsigned',
      contractVersion: PedagogicalCard.supportedContractVersion,
      serverSignature: signature,
    );

PedagogicalCard cardWithHash({String signature = 'signature-x'}) {
  final unsigned = _unsignedCard(signature: signature);
  return PedagogicalCard(
    cardId: unsigned.cardId,
    deckId: unsigned.deckId,
    lessonLocalId: unsigned.lessonLocalId,
    marker: unsigned.marker,
    itemIdx: unsigned.itemIdx,
    layer: unsigned.layer,
    explanation: unsigned.explanation,
    question: unsigned.question,
    options: unsigned.options,
    correctAnswer: unsigned.correctAnswer,
    feedback: unsigned.feedback,
    qualifiers: unsigned.qualifiers,
    advancePolicy: unsigned.advancePolicy,
    contentHash: PedagogicalCardIntegrityVerifier.contentHashForCard(unsigned),
    contractVersion: unsigned.contractVersion,
    serverSignature: signature,
  );
}

Matcher _signatureUnavailable() => throwsA(
  isA<PedagogicalCardIntegrityException>().having(
    (error) => error.message,
    'message',
    'signatureVerificationUnavailable',
  ),
);

String source() =>
    File('lib/sim/game/local_game_runtime.dart').readAsStringSync();

void main() {
  test('LocalGameRuntime bloqueia assinatura decorativa sig-123', () {
    expect(
      () => LocalGameRuntime(cardWithHash(signature: 'sig-123')),
      _signatureUnavailable(),
    );
  });

  test('LocalGameRuntime bloqueia assinatura HMAC nao verificavel', () {
    expect(() => LocalGameRuntime(cardWithHash()), _signatureUnavailable());
  });

  test('resetWithCard tambem passa pela trava de assinatura', () {
    expect(() => LocalGameRuntime(cardWithHash()), _signatureUnavailable());
  });

  test('assinatura ausente continua falhando no contrato da carta', () {
    expect(
      () => _unsignedCard(signature: ''),
      throwsA(isA<PedagogicalCardContractException>()),
    );
  });

  test('runtime mantem tipos oficiais nas assinaturas publicas', () {
    final text = source();

    expect(text, contains('void selectAnswer(AnswerLetter answer)'));
    expect(text, contains('AnswerLetter? get selectedAnswer'));
    expect(text, contains('void selectQualifier(DecisionSignal signal)'));
    expect(text, contains('DecisionSignal? get selectedQualifier'));
  });

  test('runtime chama verifyForRuntime no construtor e reset', () {
    final text = source();

    expect(
      'PedagogicalCardIntegrityVerifier.verifyForRuntime'.allMatches(text),
      hasLength(2),
    );
  });

  test('arquivo de runtime contem somente imports permitidos', () {
    final imports = source()
        .split('\n')
        .where((line) => line.startsWith('import '))
        .toList();

    expect(imports, [
      "import '../state/student_learning_state.dart';",
      "import 'pedagogical_card.dart';",
      "import 'pedagogical_card_integrity_verifier.dart';",
    ]);
  });

  test('runtime nao contem bypass nem termos proibidos', () {
    final text = source();

    for (final forbidden in [
      'skipSignature',
      'allowUnsigned',
      'allowHashOnly',
      'testMode',
      'bypass',
      'http',
      'Dio',
      'SharedPreferences',
      'LabSession',
      'LessonRuntimeEngine',
      'ChatAulaScreen',
      'ledger',
      'credit',
      'credito',
      'prompt',
      'T00',
      'T02',
      'N3',
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
