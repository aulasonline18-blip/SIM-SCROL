import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/game_state_store.dart';
import 'package:sim_mobile/sim/game/microdeck.dart';
import 'package:sim_mobile/sim/game/pedagogical_card.dart';
import 'package:sim_mobile/sim/game/pedagogical_event.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _sourcePath = 'lib/sim/game/game_state_store.dart';

PedagogicalCard validCard({
  String cardId = 'card-1',
  String deckId = 'deck-1',
  String lessonLocalId = 'lesson-1',
  int itemIdx = 0,
  AnswerLetter correctAnswer = AnswerLetter.A,
}) => PedagogicalCard(
  cardId: cardId,
  deckId: deckId,
  lessonLocalId: lessonLocalId,
  marker: 'm$itemIdx',
  itemIdx: itemIdx,
  layer: LessonLayer.l1,
  explanation: 'Texto pronto.',
  question: 'Pergunta pronta?',
  options: const {
    AnswerLetter.A: 'Alternativa A',
    AnswerLetter.B: 'Alternativa B',
    AnswerLetter.C: 'Alternativa C',
  },
  correctAnswer: correctAnswer,
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
  contentHash: 'hash-$cardId',
  contractVersion: PedagogicalCard.supportedContractVersion,
  serverSignature: 'sig-$cardId',
);

Microdeck validDeck({int count = 2, int currentIndex = 0}) => Microdeck(
  microdeckId: 'microdeck-1',
  cards: [
    for (var index = 0; index < count; index++)
      validCard(cardId: 'card-${index + 1}', itemIdx: index),
  ],
  currentIndex: currentIndex,
);

String source() => File(_sourcePath).readAsStringSync();

String token(List<String> parts) => parts.join();

List<PedagogicalEventType> eventTypes(GameStateStore store) =>
    store.eventLog.events.map((event) => event.type).toList();

void main() {
  test('GameStateStore e final class', () {
    expect(source(), contains('final class GameStateStore'));
  });

  test('campos internos nao sao publicos mutaveis', () {
    final text = source();

    for (final forbidden in [
      'Microdeck? get microdeck',
      'LocalGameRuntime? get runtime',
      'Microdeck? microdeck;',
      'LocalGameRuntime? runtime;',
      'PedagogicalEventLog eventLog;',
      'int sequence;',
      'bool needsMicrodeck;',
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
    for (final required in [
      'Microdeck? _microdeck;',
      'LocalGameRuntime? _runtime;',
      'PedagogicalEventLog _eventLog',
      'bool _needsMicrodeck',
      'int _nextSequence',
    ]) {
      expect(text, contains(required), reason: required);
    }
  });

  test('imports sao exatamente os permitidos', () {
    final imports = source()
        .split('\n')
        .where((line) => line.startsWith('import '))
        .toList();

    expect(imports, [
      "import '../state/student_learning_state.dart';",
      "import 'local_game_runtime.dart';",
      "import 'microdeck.dart';",
      "import 'pedagogical_card.dart';",
      "import 'pedagogical_event.dart';",
      "import 'pedagogical_event_log.dart';",
    ]);
  });

  test('store inicia vazio e exige microdeck', () {
    final store = GameStateStore();

    expect(store.eventLog.isEmpty, isTrue);
    expect(store.currentCard, isNull);
    expect(store.currentCardId, isNull);
    expect(store.currentIndex, isNull);
    expect(store.selectedAnswer, isNull);
    expect(store.selectedQualifier, isNull);
    expect(store.feedbackText, isNull);
    expect(store.hasPlayableCard, isFalse);
    expect(store.needsMicrodeck, isTrue);
    expect(store.canSelectAnswer, isFalse);
    expect(store.canSelectQualifier, isFalse);
    expect(store.canShowFeedback, isFalse);
  });

  test(
    'loadMicrodeck cria runtime da carta atual e registra apenas cardSeen',
    () {
      final store = GameStateStore();

      store.loadMicrodeck(validDeck(count: 2), clientTimestampMs: 10);

      expect(store.currentCard?.cardId, 'card-1');
      expect(store.currentCardId, 'card-1');
      expect(store.currentIndex, 0);
      expect(store.hasPlayableCard, isTrue);
      expect(store.needsMicrodeck, isFalse);
      expect(eventTypes(store), [PedagogicalEventType.cardSeen]);
    },
  );

  test('getters microdeck e runtime nao existem como objetos vivos', () {
    final text = source();

    expect(text, isNot(contains('get microdeck => _microdeck')));
    expect(text, isNot(contains('get runtime => _runtime')));
  });

  test('loadMicrodeck duplicado com jogo ativo falha sem cardSeen falso', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    expect(
      () => store.loadMicrodeck(validDeck(count: 1), clientTimestampMs: 11),
      throwsStateError,
    );

    expect(store.currentCardId, 'card-1');
    expect(eventTypes(store), [PedagogicalEventType.cardSeen]);
  });

  test('loadMicrodeck com timestamp zero falha e mantem vazio', () {
    final store = GameStateStore();

    expect(
      () => store.loadMicrodeck(validDeck(count: 1), clientTimestampMs: 0),
      throwsA(anything),
    );

    expect(store.currentCard, isNull);
    expect(store.needsMicrodeck, isTrue);
    expect(store.eventLog.isEmpty, isTrue);
  });

  test('sem carta canSelectAnswer false e selectAnswer falha', () {
    final store = GameStateStore();

    expect(store.canSelectAnswer, isFalse);
    expect(
      () => store.selectAnswer(AnswerLetter.A, clientTimestampMs: 10),
      throwsStateError,
    );
  });

  test('com carta canSelectAnswer true', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    expect(store.canSelectAnswer, isTrue);
  });

  test('selectAnswer A registra apenas answerSelected', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    store.selectAnswer(AnswerLetter.A, clientTimestampMs: 11);

    expect(store.selectedAnswer, AnswerLetter.A);
    expect(eventTypes(store), [
      PedagogicalEventType.cardSeen,
      PedagogicalEventType.answerSelected,
    ]);
    expect(store.eventLog.events.last.answer, AnswerLetter.A);
  });

  test('selectAnswer com timestamp zero falha e nao marca resposta', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    expect(
      () => store.selectAnswer(AnswerLetter.A, clientTimestampMs: 0),
      throwsA(anything),
    );

    expect(store.selectedAnswer, isNull);
    expect(store.canSelectQualifier, isFalse);
    expect(eventTypes(store), [PedagogicalEventType.cardSeen]);
  });

  test('depois de A B ou C qualificadores ficam disponiveis', () {
    for (final answer in AnswerLetter.values) {
      final store = GameStateStore()
        ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

      store.selectAnswer(answer, clientTimestampMs: 11);

      expect(store.canSelectQualifier, isTrue, reason: answer.name);
      expect(store.canShowFeedback, isFalse, reason: answer.name);
    }
  });

  test('selectAnswer nao mostra feedback ainda', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    store.selectAnswer(AnswerLetter.A, clientTimestampMs: 11);

    expect(store.canShowFeedback, isFalse);
    expect(store.feedbackText, isNull);
  });

  test('selectQualifier 1 registra qualifierSelected depois feedbackShown', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10)
      ..selectAnswer(AnswerLetter.A, clientTimestampMs: 11);

    store.selectQualifier(DecisionSignal.one, clientTimestampMs: 12);

    expect(store.selectedQualifier, DecisionSignal.one);
    expect(eventTypes(store), [
      PedagogicalEventType.cardSeen,
      PedagogicalEventType.answerSelected,
      PedagogicalEventType.qualifierSelected,
      PedagogicalEventType.feedbackShown,
    ]);
    expect(store.eventLog.events[2].qualifier, DecisionSignal.one);
    expect(store.eventLog.events[3].qualifier, DecisionSignal.one);
    expect(store.canShowFeedback, isTrue);
  });

  test(
    'selectQualifier com timestamp zero falha sem qualificador feedback',
    () {
      final store = GameStateStore()
        ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10)
        ..selectAnswer(AnswerLetter.A, clientTimestampMs: 11);

      expect(
        () => store.selectQualifier(DecisionSignal.one, clientTimestampMs: 0),
        throwsA(anything),
      );

      expect(store.selectedAnswer, AnswerLetter.A);
      expect(store.selectedQualifier, isNull);
      expect(store.canShowFeedback, isFalse);
      expect(store.feedbackText, isNull);
      expect(eventTypes(store), [
        PedagogicalEventType.cardSeen,
        PedagogicalEventType.answerSelected,
      ]);
    },
  );

  test('sem resposta selectQualifier falha explicitamente', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    expect(
      () => store.selectQualifier(DecisionSignal.one, clientTimestampMs: 11),
      throwsA(anything),
    );
    expect(eventTypes(store), [PedagogicalEventType.cardSeen]);
  });

  test('depois de feedback nova resposta e rejeitada via runtime', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10)
      ..selectAnswer(AnswerLetter.A, clientTimestampMs: 11)
      ..selectQualifier(DecisionSignal.one, clientTimestampMs: 12);

    expect(
      () => store.selectAnswer(AnswerLetter.B, clientTimestampMs: 13),
      throwsA(anything),
    );
    expect(store.selectedAnswer, AnswerLetter.A);
  });

  test('advanceToNextCard avanca e registra cardAdvanced depois cardSeen', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 2), clientTimestampMs: 10);

    store.advanceToNextCard(clientTimestampMs: 11);

    expect(store.currentIndex, 1);
    expect(store.currentCard?.cardId, 'card-2');
    expect(eventTypes(store), [
      PedagogicalEventType.cardSeen,
      PedagogicalEventType.cardAdvanced,
      PedagogicalEventType.cardSeen,
    ]);
    expect(store.eventLog.events[1].cardId, 'card-1');
    expect(store.eventLog.events[2].cardId, 'card-2');
  });

  test('advanceToNextCard sem proxima carta marca needsMicrodeck', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    store.advanceToNextCard(clientTimestampMs: 11);

    expect(store.needsMicrodeck, isTrue);
    expect(store.hasPlayableCard, isFalse);
    expect(store.currentCard, isNull);
    expect(store.canSelectAnswer, isFalse);
    expect(store.selectedAnswer, isNull);
    expect(eventTypes(store), [PedagogicalEventType.cardSeen]);
  });

  test('advanceToNextCard sem proxima carta nao registra cardAdvanced', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    store.advanceToNextCard(clientTimestampMs: 11);

    expect(store.needsMicrodeck, isTrue);
    expect(
      store.eventLog.events.where(
        (event) => event.type == PedagogicalEventType.cardAdvanced,
      ),
      isEmpty,
    );
    expect(eventTypes(store), [PedagogicalEventType.cardSeen]);
  });

  test('advanceToNextCard sem carta falha explicitamente', () {
    final store = GameStateStore();

    expect(
      () => store.advanceToNextCard(clientTimestampMs: 10),
      throwsStateError,
    );
  });

  test('sem proxima carta nao inventa cardSeen falso', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    store.advanceToNextCard(clientTimestampMs: 11);

    expect(
      store.eventLog.events
          .where((event) => event.type == PedagogicalEventType.cardSeen)
          .length,
      1,
    );
  });

  test('eventos mantem ordem', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 2), clientTimestampMs: 10)
      ..selectAnswer(AnswerLetter.B, clientTimestampMs: 11)
      ..selectQualifier(DecisionSignal.two, clientTimestampMs: 12)
      ..advanceToNextCard(clientTimestampMs: 13);

    expect(store.eventLog.events.map((event) => event.sequence), [
      0,
      1,
      2,
      3,
      4,
      5,
    ]);
    expect(store.eventLog.events.map((event) => event.type), [
      PedagogicalEventType.cardSeen,
      PedagogicalEventType.answerSelected,
      PedagogicalEventType.qualifierSelected,
      PedagogicalEventType.feedbackShown,
      PedagogicalEventType.cardAdvanced,
      PedagogicalEventType.cardSeen,
    ]);
  });

  test('estado e eventLog sempre caminham juntos', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 2), clientTimestampMs: 10);

    expect(
      () => store.selectAnswer(AnswerLetter.A, clientTimestampMs: 0),
      throwsA(anything),
    );
    expect(store.selectedAnswer, isNull);
    expect(eventTypes(store), [PedagogicalEventType.cardSeen]);

    store.selectAnswer(AnswerLetter.A, clientTimestampMs: 11);
    expect(store.selectedAnswer, AnswerLetter.A);
    expect(eventTypes(store), [
      PedagogicalEventType.cardSeen,
      PedagogicalEventType.answerSelected,
    ]);

    expect(
      () => store.selectQualifier(DecisionSignal.one, clientTimestampMs: 0),
      throwsA(anything),
    );
    expect(store.selectedQualifier, isNull);
    expect(store.canShowFeedback, isFalse);
    expect(eventTypes(store), [
      PedagogicalEventType.cardSeen,
      PedagogicalEventType.answerSelected,
    ]);
  });

  test('eventos duplicados sao rejeitados pelo log', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);
    final exposed = store.eventLog;
    final first = exposed.events.first;

    expect(() => exposed.append(first), throwsA(anything));
  });

  test('eventLog exposto nao quebra invariantes internas', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);
    final exposed = store.eventLog;

    exposed.clear();

    expect(exposed.isEmpty, isTrue);
    expect(store.eventLog.length, 1);
    expect(store.hasPlayableCard, isTrue);
  });

  test(
    'toJson fromJson preserva microdeck e eventos sem duplicar cardSeen',
    () {
      final store = GameStateStore()
        ..loadMicrodeck(validDeck(count: 2), clientTimestampMs: 10)
        ..selectAnswer(AnswerLetter.A, clientTimestampMs: 11);
      final decoded =
          jsonDecode(jsonEncode(store.toJson())) as Map<String, Object?>;

      final roundtrip = GameStateStore.fromJson(decoded);

      expect(roundtrip.toJson()['microdeck'], store.toJson()['microdeck']);
      expect(roundtrip.eventLog.toJson(), store.eventLog.toJson());
      expect(eventTypes(roundtrip), [
        PedagogicalEventType.cardSeen,
        PedagogicalEventType.answerSelected,
      ]);
    },
  );

  test('fromJson nao registra evento novo e preserva ordem', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 2), clientTimestampMs: 10)
      ..selectAnswer(AnswerLetter.A, clientTimestampMs: 11)
      ..selectQualifier(DecisionSignal.one, clientTimestampMs: 12);
    final before = store.eventLog.events.map((event) => event.eventId).toList();

    final roundtrip = GameStateStore.fromJson(
      jsonDecode(jsonEncode(store.toJson())),
    );

    expect(roundtrip.eventLog.events.map((event) => event.eventId), before);
  });

  test('fromJson preserva nextSequence', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);
    final roundtrip = GameStateStore.fromJson(
      jsonDecode(jsonEncode(store.toJson())),
    );

    roundtrip.selectAnswer(AnswerLetter.C, clientTimestampMs: 11);

    expect(roundtrip.eventLog.events.last.sequence, 1);
    expect(
      roundtrip.eventLog.events.last.eventId,
      'game-state:1:answerSelected:card-1',
    );
  });

  test('toJson chama validate antes do retorno', () {
    final text = source();
    final toJsonIndex = text.indexOf('Map<String, Object?> toJson()');
    final validateIndex = text.indexOf('validate();', toJsonIndex);
    final returnIndex = text.indexOf('return {', toJsonIndex);

    expect(toJsonIndex, isNonNegative);
    expect(validateIndex, inInclusiveRange(toJsonIndex, returnIndex));
  });

  test('fromJson rejeita chave desconhecida e runtime', () {
    final json = GameStateStore().toJson();

    expect(
      () => GameStateStore.fromJson({...json, 'unknown': true}),
      throwsStateError,
    );
    expect(
      () => GameStateStore.fromJson({...json, 'runtime': {}}),
      throwsStateError,
    );
  });

  test('fromJson rejeita payload metadata extra', () {
    final json = GameStateStore().toJson();

    for (final key in ['payload', 'metadata', 'extra']) {
      expect(
        () => GameStateStore.fromJson({...json, key: {}}),
        throwsStateError,
        reason: key,
      );
    }
  });

  test('toJson nao serializa runtime', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    expect(store.toJson().keys, isNot(contains('runtime')));
  });

  test('evento gerado usa identidade da carta atual', () {
    final card = validCard(
      cardId: 'card-x',
      deckId: 'deck-x',
      lessonLocalId: 'lesson-x',
    );
    final deck = Microdeck(
      microdeckId: 'microdeck-x',
      cards: [card],
      currentIndex: 0,
    );
    final store = GameStateStore()
      ..loadMicrodeck(deck, clientTimestampMs: 10)
      ..selectAnswer(AnswerLetter.A, clientTimestampMs: 11)
      ..selectQualifier(DecisionSignal.three, clientTimestampMs: 12);

    for (final event in store.eventLog.events) {
      expect(event.lessonLocalId, 'lesson-x');
      expect(event.deckId, 'deck-x');
      expect(event.cardId, 'card-x');
      expect(event.contentHash, 'hash-card-x');
    }
  });

  test('eventos gerados usam tipos oficiais', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10)
      ..selectAnswer(AnswerLetter.B, clientTimestampMs: 11)
      ..selectQualifier(DecisionSignal.two, clientTimestampMs: 12);

    expect(store.eventLog.events[1].answer, isA<AnswerLetter>());
    expect(store.eventLog.events[2].qualifier, isA<DecisionSignal>());
  });

  test('eventId e deterministico entre stores iguais', () {
    final first = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10)
      ..selectAnswer(AnswerLetter.A, clientTimestampMs: 11);
    final second = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 20)
      ..selectAnswer(AnswerLetter.A, clientTimestampMs: 21);

    expect(
      first.eventLog.events.map((event) => event.eventId),
      second.eventLog.events.map((event) => event.eventId),
    );
    expect(first.eventLog.events.first.eventId, 'game-state:0:cardSeen:card-1');
  });

  test('clear limpa tudo e volta ao estado inicial', () {
    final store = GameStateStore()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10)
      ..selectAnswer(AnswerLetter.A, clientTimestampMs: 11);

    store.clear();

    expect(store.currentCard, isNull);
    expect(store.currentIndex, isNull);
    expect(store.selectedAnswer, isNull);
    expect(store.selectedQualifier, isNull);
    expect(store.feedbackText, isNull);
    expect(store.eventLog.isEmpty, isTrue);
    expect(store.needsMicrodeck, isTrue);
    expect(store.hasPlayableCard, isFalse);
  });

  test('arquivo produtivo nao contem termos proibidos', () {
    final text = source();
    final forbidden = [
      token(['h', 'ttp']),
      token(['d', 'io']),
      token(['Cli', 'ent']),
      token(['ser', 'ver']),
      token(['sy', 'nc']),
      token(['re', 'try']),
      token(['fl', 'ush']),
      token(['up', 'load']),
      token(['re', 'mote']),
      token(['T', '00']),
      token(['T', '02']),
      token(['N', '3']),
      token(['Ai', 'Cost', 'Protection', 'Gate']),
      token(['cre', 'dit']),
      token(['cre', 'dito']),
      token(['led', 'ger']),
      token(['bill', 'ing']),
      token(['co', 'st']),
      token(['Gem', 'ini']),
      token(['Open', 'AI']),
      token(['Shared', 'Preferences']),
      token(['Dr', 'ift']),
      token(['Ti', 'mer']),
      token(['Fut', 'ure']),
      token(['Str', 'eam']),
      token(['Widget']),
      token(['Build', 'Context']),
      token(['Lab', 'Session']),
      token(['Lesson', 'Runtime', 'Engine']),
      token(['Chat', 'Aula', 'Screen']),
      token(['time', 'line']),
      token(['ca', 'che']),
      token(['stor', 'age']),
      token(['Fi', 'le']),
      token(['Dir', 'ectory']),
      token(['pay', 'load']),
      token(['meta', 'data']),
      token(['ex', 'tra']),
      token(['Map<String, ', 'dynamic>']),
      token(['1', '5']),
    ];

    for (final term in forbidden) {
      expect(text, isNot(contains(term)), reason: term);
    }
  });

  test('arquivo produtivo nao contem tipos paralelos de resposta sinal', () {
    final text = source();

    expect(text, contains('AnswerLetter'));
    expect(text, contains('DecisionSignal'));
    for (final forbidden in [
      token(['Game', 'Answer']),
      token(['Game', 'Signal']),
      token(['Pedagogical', 'Answer']),
      token(['Pedagogical', 'Signal']),
      'String answer',
      'int signal',
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('arquivo produtivo nao importa LabSession ou LessonRuntimeEngine', () {
    final imports = source()
        .split('\n')
        .where((line) => line.startsWith('import '))
        .join('\n');

    expect(imports, isNot(contains(token(['Lab', 'Session']))));
    expect(imports, isNot(contains(token(['Lesson', 'Runtime', 'Engine']))));
  });
}
