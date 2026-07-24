import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/microdeck.dart';
import 'package:sim_mobile/sim/game/pedagogical_card.dart';
import 'package:sim_mobile/sim/game/pedagogical_card_integrity_verifier.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

PedagogicalCard _unsignedCard({
  String cardId = 'card-1',
  int itemIdx = 0,
  String signature = 'signature-x',
}) => PedagogicalCard(
  cardId: cardId,
  deckId: 'deck-1',
  lessonLocalId: 'lesson-1',
  marker: 'm$itemIdx',
  itemIdx: itemIdx,
  layer: LessonLayer.l1,
  explanation: 'Explicacao curta.',
  question: 'Qual alternativa representa a ideia?',
  options: const {
    AnswerLetter.A: 'Alternativa A',
    AnswerLetter.B: 'Alternativa B',
    AnswerLetter.C: 'Alternativa C',
  },
  correctAnswer: AnswerLetter.A,
  feedback: const {
    AnswerLetter.A: 'A preserva a ideia principal.',
    AnswerLetter.B: 'B troca o conceito.',
    AnswerLetter.C: 'C falta uma parte essencial.',
  },
  qualifiers: const {
    DecisionSignal.one: 'Tenho certeza.',
    DecisionSignal.two: 'Acho que sim.',
    DecisionSignal.three: 'Estou inseguro.',
  },
  advancePolicy: const {
    DecisionSignal.one: 'seguir_com_evidencia',
    DecisionSignal.two: 'seguir_com_cuidado',
    DecisionSignal.three: 'nao_consolidar',
  },
  contentHash: 'unsigned',
  contractVersion: PedagogicalCard.supportedContractVersion,
  serverSignature: signature,
);

PedagogicalCard cardWithHash({
  String cardId = 'card-1',
  int itemIdx = 0,
  String signature = 'signature-x',
}) {
  final unsigned = _unsignedCard(
    cardId: cardId,
    itemIdx: itemIdx,
    signature: signature,
  );
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

String source() => File('lib/sim/game/microdeck.dart').readAsStringSync();

void main() {
  test('Microdeck bloqueia assinatura decorativa sig-123', () {
    expect(
      () => Microdeck(
        microdeckId: 'deck-1',
        cards: [cardWithHash(signature: 'sig-123')],
        currentIndex: 0,
      ),
      _signatureUnavailable(),
    );
  });

  test('Microdeck bloqueia assinatura HMAC nao verificavel', () {
    expect(
      () => Microdeck(
        microdeckId: 'deck-1',
        cards: [cardWithHash()],
        currentIndex: 0,
      ),
      _signatureUnavailable(),
    );
  });

  test('Microdeck.fromJson tambem bloqueia assinatura nao verificavel', () {
    expect(
      () => Microdeck.fromJson({
        'microdeckId': 'deck-1',
        'cards': [cardWithHash().toJson()],
        'currentIndex': 0,
      }),
      _signatureUnavailable(),
    );
  });

  test('microdeck vazio falha antes de assinatura', () {
    expect(
      () => Microdeck(microdeckId: 'deck-1', cards: const [], currentIndex: 0),
      throwsA(isA<MicrodeckContractException>()),
    );
  });

  test('microdeckId vazio falha antes de assinatura', () {
    expect(
      () =>
          Microdeck(microdeckId: ' ', cards: [cardWithHash()], currentIndex: 0),
      throwsA(isA<MicrodeckContractException>()),
    );
  });

  test('assinatura ausente continua falhando no contrato da carta', () {
    expect(
      () => _unsignedCard(signature: ''),
      throwsA(isA<PedagogicalCardContractException>()),
    );
  });

  test('arquivo produtivo importa somente dependencias permitidas', () {
    final imports = source()
        .split('\n')
        .where((line) => line.trimLeft().startsWith('import '))
        .toList();

    expect(imports, [
      "import 'pedagogical_card.dart';",
      "import 'pedagogical_card_integrity_verifier.dart';",
    ]);
  });

  test('Microdeck preserva limite 3 e nao usa janela 15', () {
    final text = source();

    expect(text, contains('static const maxCards = 3;'));
    expect(text, isNot(contains('= 15')));
    expect(text, isNot(contains('> 15')));
  });

  test('Microdeck chama verifyForRuntime ao validar cartas', () {
    expect(
      source(),
      contains('PedagogicalCardIntegrityVerifier.verifyForRuntime(card);'),
    );
  });

  test('Microdeck nao contem bypass nem termos proibidos', () {
    final text = source();

    for (final forbidden in [
      'skipSignature',
      'allowUnsigned',
      'allowHashOnly',
      'testMode',
      'bypass',
      'LocalGameRuntime',
      'http',
      'Dio',
      'Future',
      'Timer',
      'Stream',
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
