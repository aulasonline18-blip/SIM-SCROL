import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/microdeck.dart';
import 'package:sim_mobile/sim/game/pedagogical_card.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _sourcePath = 'lib/sim/game/microdeck.dart';

PedagogicalCard validCard({
  String cardId = 'card-1',
  String deckId = 'deck-1',
  String lessonLocalId = 'lesson-1',
  int itemIdx = 0,
}) => PedagogicalCard(
  cardId: cardId,
  deckId: deckId,
  lessonLocalId: lessonLocalId,
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
  contentHash: 'hash-$cardId',
  contractVersion: PedagogicalCard.supportedContractVersion,
  serverSignature: 'sig-$cardId',
);

Microdeck validDeck({int count = 3, int currentIndex = 0}) => Microdeck(
  microdeckId: 'microdeck-1',
  cards: [
    for (var index = 0; index < count; index++)
      validCard(cardId: 'card-${index + 1}', itemIdx: index),
  ],
  currentIndex: currentIndex,
);

Map<String, dynamic> validCardJson({
  String cardId = 'card-1',
  String deckId = 'deck-1',
  String lessonLocalId = 'lesson-1',
  int itemIdx = 0,
}) => validCard(
  cardId: cardId,
  deckId: deckId,
  lessonLocalId: lessonLocalId,
  itemIdx: itemIdx,
).toJson();

void expectMicrodeckFailure(void Function() run, String reason) {
  expect(run, throwsA(isA<MicrodeckContractException>()), reason: reason);
}

void expectContractFailure(void Function() run, String reason) {
  expect(
    run,
    throwsA(
      anyOf(
        isA<MicrodeckContractException>(),
        isA<PedagogicalCardContractException>(),
      ),
    ),
    reason: reason,
  );
}

String source() => File(_sourcePath).readAsStringSync();

String token(List<String> parts) => parts.join();

void main() {
  test('microdeck valido com 1 carta', () {
    final deck = validDeck(count: 1);

    expect(deck.length, 1);
    expect(deck.isEmpty, isFalse);
    expect(deck.hasCurrent, isTrue);
  });

  test('microdeck valido com 2 cartas', () {
    final deck = validDeck(count: 2);

    expect(deck.length, 2);
    expect(deck.hasNext, isTrue);
  });

  test('microdeck valido com 3 cartas', () {
    final deck = validDeck(count: Microdeck.maxCards);

    expect(deck.length, Microdeck.maxCards);
    expect(source(), contains('static const maxCards = 3'));
  });

  test('microdeck com 4 cartas falha', () {
    expectMicrodeckFailure(
      () => validDeck(count: 4),
      'microdeck_must_have_at_most_3_cards',
    );
  });

  test('microdeck vazio falha', () {
    expectMicrodeckFailure(
      () => Microdeck(
        microdeckId: 'microdeck-1',
        cards: const [],
        currentIndex: 0,
      ),
      'lista vazia nao e pacote jogavel',
    );
  });

  test('microdeckId vazio falha', () {
    expectMicrodeckFailure(
      () => Microdeck(microdeckId: ' ', cards: [validCard()], currentIndex: 0),
      'microdeck precisa de id',
    );
  });

  test('currentIndex negativo falha', () {
    expectMicrodeckFailure(
      () => Microdeck(
        microdeckId: 'microdeck-1',
        cards: [validCard()],
        currentIndex: -1,
      ),
      'indice negativo nao pode ser corrigido automaticamente',
    );
  });

  test('currentIndex fora da lista falha', () {
    expectMicrodeckFailure(
      () => Microdeck(
        microdeckId: 'microdeck-1',
        cards: [validCard()],
        currentIndex: 1,
      ),
      'indice fora da lista nao pode ser corrigido automaticamente',
    );
  });

  test('card duplicado falha', () {
    expectMicrodeckFailure(
      () => Microdeck(
        microdeckId: 'microdeck-1',
        cards: [validCard(), validCard()],
        currentIndex: 0,
      ),
      'duplicata nao pode ser deduplicada automaticamente',
    );
  });

  test('deckId diferente falha', () {
    expectMicrodeckFailure(
      () => Microdeck(
        microdeckId: 'microdeck-1',
        cards: [
          validCard(cardId: 'card-1', deckId: 'deck-1'),
          validCard(cardId: 'card-2', deckId: 'deck-2', itemIdx: 1),
        ],
        currentIndex: 0,
      ),
      'cartas do pacote precisam pertencer ao mesmo deck',
    );
  });

  test('lessonLocalId diferente falha', () {
    expectMicrodeckFailure(
      () => Microdeck(
        microdeckId: 'microdeck-1',
        cards: [
          validCard(cardId: 'card-1', lessonLocalId: 'lesson-1'),
          validCard(cardId: 'card-2', lessonLocalId: 'lesson-2', itemIdx: 1),
        ],
        currentIndex: 0,
      ),
      'cartas do pacote precisam pertencer a mesma aula local',
    );
  });

  test('carta invalida falha', () {
    final json = {
      'microdeckId': 'microdeck-1',
      'cards': [validCardJson()..remove('contentHash')],
      'currentIndex': 0,
    };

    expectContractFailure(
      () => Microdeck.fromJson(json),
      'Microdeck nao deve aceitar PedagogicalCard invalida',
    );
  });

  test('midia pesada falha via PedagogicalCard', () {
    final json = {
      'microdeckId': 'microdeck-1',
      'cards': [
        validCardJson()..['media'] = {'imageKey': 'data:image/png;base64,abcd'},
      ],
      'currentIndex': 0,
    };

    expectContractFailure(
      () => Microdeck.fromJson(json),
      'Microdeck depende da validacao de midia da PedagogicalCard',
    );
  });

  test('currentCard funciona', () {
    final deck = validDeck(count: 3, currentIndex: 1);

    expect(deck.currentCard.cardId, 'card-2');
  });

  test('nextCard funciona', () {
    final deck = validDeck(count: 3, currentIndex: 1);

    expect(deck.nextCard?.cardId, 'card-3');
  });

  test('reserveCards funciona', () {
    final deck = validDeck(count: 3);

    expect(deck.reserveCards.map((card) => card.cardId), ['card-3']);
  });

  test('reserveCards nunca inclui currentCard nem nextCard', () {
    final deck = validDeck(count: 3);
    final reservedIds = deck.reserveCards.map((card) => card.cardId);

    expect(reservedIds, isNot(contains(deck.currentCard.cardId)));
    expect(reservedIds, isNot(contains(deck.nextCard?.cardId)));
  });

  test('advance avanca', () {
    final deck = validDeck(count: 2);

    expect(deck.advance(), isTrue);
    expect(deck.currentIndex, 1);
    expect(deck.currentCard.cardId, 'card-2');
  });

  test('advance no fim retorna false e nao altera estado', () {
    final deck = validDeck(count: 1);

    expect(deck.advance(), isFalse);
    expect(deck.currentIndex, 0);
    expect(deck.currentCard.cardId, 'card-1');
  });

  test('reset volta ao inicio', () {
    final deck = validDeck(count: 3)..advance();

    expect(deck.currentIndex, 1);
    deck.reset();
    expect(deck.currentIndex, 0);
    expect(deck.currentCard.cardId, 'card-1');
  });

  test('remainingCount e coerente depois de advance e reset', () {
    final deck = validDeck(count: 3);

    expect(deck.remainingCount, 3);
    deck.advance();
    expect(deck.remainingCount, 2);
    deck.reset();
    expect(deck.remainingCount, 3);
  });

  test('cardAt retorna carta certa', () {
    final deck = validDeck(count: 3);

    expect(deck.cardAt(2).cardId, 'card-3');
  });

  test('cardAt negativo falha explicitamente', () {
    final deck = validDeck(count: 1);

    expectMicrodeckFailure(
      () => deck.cardAt(-1),
      'indice negativo deve falhar',
    );
  });

  test('cardAt length falha explicitamente', () {
    final deck = validDeck(count: 1);

    expectMicrodeckFailure(
      () => deck.cardAt(deck.length),
      'indice igual ao tamanho deve falhar',
    );
  });

  test('Microdeck nao muta PedagogicalCard', () {
    final card = validCard();
    final before = jsonEncode(card.toJson());
    final deck = Microdeck(
      microdeckId: 'microdeck-1',
      cards: [card],
      currentIndex: 0,
    );

    deck.advance();

    expect(jsonEncode(card.toJson()), before);
  });

  test('fromJson toJson preserva id indice e ordem', () {
    final deck = validDeck(count: 3, currentIndex: 1);
    final decoded =
        jsonDecode(jsonEncode(deck.toJson())) as Map<String, dynamic>;
    final roundtrip = Microdeck.fromJson(decoded);

    expect(roundtrip.microdeckId, deck.microdeckId);
    expect(roundtrip.currentIndex, deck.currentIndex);
    expect(roundtrip.cards.map((card) => card.cardId), [
      'card-1',
      'card-2',
      'card-3',
    ]);
    expect(roundtrip.toJson(), deck.toJson());
  });

  test('lista de entrada e copiada', () {
    final original = [validCard()];
    final deck = Microdeck(
      microdeckId: 'microdeck-1',
      cards: original,
      currentIndex: 0,
    );

    original.add(validCard(cardId: 'card-2', itemIdx: 1));

    expect(deck.length, 1);
    expect(deck.currentCard.cardId, 'card-1');
  });

  test('cards exposto e imutavel', () {
    final deck = validDeck(count: 1);

    expect(
      () => deck.cards.add(validCard(cardId: 'card-2', itemIdx: 1)),
      throwsUnsupportedError,
    );
  });

  test('currentIndex nao tem campo publico mutavel', () {
    final sourceText = source();

    expect(sourceText, isNot(contains('int currentIndex;')));
    expect(sourceText, contains('int get currentIndex'));
  });

  test('toJson valida antes de serializar', () {
    final sourceText = source();
    final toJsonIndex = sourceText.indexOf('Map<String, dynamic> toJson()');
    final validateIndex = sourceText.indexOf('validate();', toJsonIndex);
    final returnIndex = sourceText.indexOf('return {', toJsonIndex);

    expect(toJsonIndex, isNonNegative);
    expect(validateIndex, isNonNegative);
    expect(returnIndex, isNonNegative);
    expect(validateIndex, lessThan(returnIndex));
  });

  test('estado so muda por advance e reset', () {
    final sourceText = source();
    final assignmentLines = sourceText
        .split('\n')
        .where(
          (line) =>
              line.trim() == '_currentIndex = currentIndex;' ||
              line.trim() == '_currentIndex += 1;' ||
              line.trim() == '_currentIndex = 0;',
        )
        .toList();

    expect(assignmentLines, [
      '    _currentIndex = currentIndex;',
      '    _currentIndex += 1;',
      '    _currentIndex = 0;',
    ]);
    expect(sourceText, isNot(contains('set currentIndex')));
  });

  test('currentIndex nao e corrigido automaticamente', () {
    expectMicrodeckFailure(
      () => Microdeck(
        microdeckId: 'microdeck-1',
        cards: [validCard()],
        currentIndex: 99,
      ),
      'indice invalido precisa falhar',
    );
  });

  test('nao existe truncamento automatico para 3 cartas', () {
    expectMicrodeckFailure(
      () => validDeck(count: 4),
      'lista maior que maxCards precisa falhar, nao truncar',
    );
  });

  test('nao existe deduplicacao automatica', () {
    expectMicrodeckFailure(
      () => Microdeck(
        microdeckId: 'microdeck-1',
        cards: [validCard(), validCard()],
        currentIndex: 0,
      ),
      'duplicata precisa falhar, nao ser removida',
    );
  });

  test('nao existe ordenacao automatica e ordem recebida e preservada', () {
    final deck = Microdeck(
      microdeckId: 'microdeck-1',
      cards: [
        validCard(cardId: 'card-2', itemIdx: 1),
        validCard(cardId: 'card-1', itemIdx: 0),
      ],
      currentIndex: 0,
    );

    expect(deck.cards.map((card) => card.cardId), ['card-2', 'card-1']);
  });

  test('arquivo produtivo importa somente pedagogical_card', () {
    final imports = source()
        .split('\n')
        .where((line) => line.trimLeft().startsWith('import '))
        .toList();

    expect(imports, ["import 'pedagogical_card.dart';"]);
  });

  test('Microdeck nao importa nem chama runtime', () {
    final runtimeName = token(['Local', 'Game', 'Runtime']);

    expect(source(), isNot(contains(runtimeName)));
  });

  test('Microdeck nao importa UI', () {
    final uiTerms = ['flutter', 'Widget', 'BuildContext'];

    for (final term in uiTerms) {
      expect(source(), isNot(contains(term)));
    }
  });

  test('Microdeck nao importa HTTP', () {
    final networkTerms = ['http', 'dio', 'Client'];

    for (final term in networkTerms) {
      expect(source(), isNot(contains(term)));
    }
  });

  test('Microdeck nao referencia IA T00 T02 N3 credito ledger ou servidor', () {
    final forbidden = [
      token(['T', '00']),
      token(['T', '02']),
      token(['N', '3']),
      token(['cred', 'it']),
      token(['cred', 'ito']),
      token(['led', 'ger']),
      token(['ser', 'ver']),
      token(['Gem', 'ini']),
      token(['Open', 'AI']),
      token(['Ai', 'Cost', 'Protection', 'Gate']),
    ];

    for (final term in forbidden) {
      expect(source(), isNot(contains(term)));
    }
  });

  test('Microdeck nao usa async Future Timer storage ou stream', () {
    final forbidden = [
      token(['as', 'ync']),
      token(['Fut', 'ure']),
      token(['Tim', 'er']),
      token(['Str', 'eam']),
      token(['Shared', 'Preferences']),
      token(['Dr', 'ift']),
    ];

    for (final term in forbidden) {
      expect(source(), isNot(contains(term)));
    }
  });

  test('Microdeck nao contem numero 15 como limite produtivo', () {
    final fifteen = token(['1', '5']);

    expect(source(), isNot(contains(fifteen)));
  });

  test('Microdeck contem limite 3 explicito', () {
    final sourceText = source();

    expect(sourceText, contains('static const maxCards = 3'));
    expect(sourceText, contains('cards.length > maxCards'));
    expect(sourceText, contains('microdeck_must_have_at_most_3_cards'));
  });

  test('limite 3 nao altera janela antiga', () {
    final antiLoopDoc = File(
      'docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md',
    ).readAsStringSync();

    expect(Microdeck.maxCards, 3);
    expect(antiLoopDoc, contains('janela'));
    expect(antiLoopDoc, contains('15'));
  });
}
