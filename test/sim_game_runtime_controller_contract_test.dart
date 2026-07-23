import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/game_runtime_controller.dart';
import 'package:sim_mobile/sim/game/game_state_store.dart';
import 'package:sim_mobile/sim/game/microdeck.dart';
import 'package:sim_mobile/sim/game/pedagogical_card.dart';
import 'package:sim_mobile/sim/game/pedagogical_event.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _sourcePath = 'lib/sim/game/game_runtime_controller.dart';
const _cardSourcePath = 'lib/sim/game/pedagogical_card.dart';

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

Microdeck validDeck({int count = 2}) => Microdeck(
  microdeckId: 'microdeck-1',
  cards: [
    for (var index = 0; index < count; index++)
      validCard(cardId: 'card-${index + 1}', itemIdx: index),
  ],
  currentIndex: 0,
);

String source() => File(_sourcePath).readAsStringSync();

String cardSource() => File(_cardSourcePath).readAsStringSync();

String token(List<String> parts) => parts.join();

List<PedagogicalEventType> eventTypes(GameRuntimeController controller) =>
    controller.eventLog.events.map((event) => event.type).toList();

Map<String, Object?> decodedJson(Object value) =>
    jsonDecode(jsonEncode(value)) as Map<String, Object?>;

void expectControllerMatchesStore(
  GameRuntimeController controller,
  GameStateStore store,
) {
  expect(controller.currentCardId, store.currentCardId);
  expect(controller.currentIndex, store.currentIndex);
  expect(controller.selectedAnswer, store.selectedAnswer);
  expect(controller.selectedQualifier, store.selectedQualifier);
  expect(controller.feedbackText, store.feedbackText);
  expect(controller.hasPlayableCard, store.hasPlayableCard);
  expect(controller.needsMicrodeck, store.needsMicrodeck);
  expect(controller.canSelectAnswer, store.canSelectAnswer);
  expect(controller.canSelectQualifier, store.canSelectQualifier);
  expect(controller.canShowFeedback, store.canShowFeedback);
  expect(controller.eventLog.toJson(), store.eventLog.toJson());
  expect(controller.toJson(), store.toJson());
}

void main() {
  test('GameRuntimeController e final class', () {
    expect(source(), contains('final class GameRuntimeController'));
  });

  test('Controller inicia sem carta e needsMicrodeck true', () {
    final controller = GameRuntimeController();

    expect(controller.currentCard, isNull);
    expect(controller.currentCardId, isNull);
    expect(controller.currentIndex, isNull);
    expect(controller.selectedAnswer, isNull);
    expect(controller.selectedQualifier, isNull);
    expect(controller.feedbackText, isNull);
    expect(controller.hasPlayableCard, isFalse);
    expect(controller.needsMicrodeck, isTrue);
    expect(controller.canSelectAnswer, isFalse);
    expect(controller.canSelectQualifier, isFalse);
    expect(controller.canShowFeedback, isFalse);
  });

  test('currentCard pode ser exposto porque PedagogicalCard e imutavel', () {
    final text = cardSource();

    for (final required in [
      'final String cardId;',
      'final String deckId;',
      'final String lessonLocalId;',
      'final String contentHash;',
      'final Map<AnswerLetter, String> options;',
      'final Map<AnswerLetter, String> feedback;',
      'final Map<DecisionSignal, String> qualifiers;',
      'final Map<DecisionSignal, String> advancePolicy;',
      'Map.unmodifiable(options)',
      'Map.unmodifiable(feedback)',
      'Map.unmodifiable(qualifiers)',
      'Map.unmodifiable(advancePolicy)',
    ]) {
      expect(text, contains(required), reason: required);
    }
  });

  test('loadMicrodeck mostra carta atual', () {
    final controller = GameRuntimeController();

    controller.loadMicrodeck(validDeck(count: 2), clientTimestampMs: 10);

    expect(controller.currentCard?.cardId, 'card-1');
    expect(controller.currentCardId, 'card-1');
    expect(controller.currentIndex, 0);
    expect(controller.hasPlayableCard, isTrue);
  });

  test('loadMicrodeck registra cardSeen', () {
    final controller = GameRuntimeController()
      ..loadMicrodeck(validDeck(count: 2), clientTimestampMs: 10);

    expect(eventTypes(controller), [PedagogicalEventType.cardSeen]);
  });

  test('selectAnswer A registra answerSelected', () {
    final controller = GameRuntimeController()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    controller.selectAnswer(AnswerLetter.A, clientTimestampMs: 11);

    expect(controller.selectedAnswer, AnswerLetter.A);
    expect(eventTypes(controller), [
      PedagogicalEventType.cardSeen,
      PedagogicalEventType.answerSelected,
    ]);
  });

  test('depois de A B C qualificadores ficam disponiveis', () {
    for (final answer in AnswerLetter.values) {
      final controller = GameRuntimeController()
        ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

      controller.selectAnswer(answer, clientTimestampMs: 11);

      expect(controller.canSelectQualifier, isTrue, reason: answer.name);
    }
  });

  test('selectAnswer nao mostra feedback', () {
    final controller = GameRuntimeController()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    controller.selectAnswer(AnswerLetter.A, clientTimestampMs: 11);

    expect(controller.canShowFeedback, isFalse);
    expect(controller.feedbackText, isNull);
  });

  test('selectQualifier 1 registra qualifierSelected', () {
    final controller = GameRuntimeController()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10)
      ..selectAnswer(AnswerLetter.A, clientTimestampMs: 11);

    controller.selectQualifier(DecisionSignal.one, clientTimestampMs: 12);

    expect(controller.selectedQualifier, DecisionSignal.one);
    expect(
      eventTypes(controller),
      contains(PedagogicalEventType.qualifierSelected),
    );
  });

  test('selectQualifier 1 registra feedbackShown', () {
    final controller = GameRuntimeController()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10)
      ..selectAnswer(AnswerLetter.A, clientTimestampMs: 11);

    controller.selectQualifier(DecisionSignal.one, clientTimestampMs: 12);

    expect(eventTypes(controller), [
      PedagogicalEventType.cardSeen,
      PedagogicalEventType.answerSelected,
      PedagogicalEventType.qualifierSelected,
      PedagogicalEventType.feedbackShown,
    ]);
  });

  test('depois do qualificador feedback fica disponivel', () {
    final controller = GameRuntimeController()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10)
      ..selectAnswer(AnswerLetter.A, clientTimestampMs: 11)
      ..selectQualifier(DecisionSignal.one, clientTimestampMs: 12);

    expect(controller.canShowFeedback, isTrue);
    expect(controller.feedbackText, 'Feedback A');
  });

  test('advanceToNextCard avanca quando ha proxima carta', () {
    final controller = GameRuntimeController()
      ..loadMicrodeck(validDeck(count: 2), clientTimestampMs: 10);

    controller.advanceToNextCard(clientTimestampMs: 11);

    expect(controller.currentCardId, 'card-2');
    expect(controller.currentIndex, 1);
    expect(eventTypes(controller), [
      PedagogicalEventType.cardSeen,
      PedagogicalEventType.cardAdvanced,
      PedagogicalEventType.cardSeen,
    ]);
  });

  test('sem proxima carta marca needsMicrodeck', () {
    final controller = GameRuntimeController()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    controller.advanceToNextCard(clientTimestampMs: 11);

    expect(controller.needsMicrodeck, isTrue);
    expect(controller.hasPlayableCard, isFalse);
    expect(controller.currentCard, isNull);
  });

  test('sem proxima carta nao registra cardAdvanced falso', () {
    final controller = GameRuntimeController()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    controller.advanceToNextCard(clientTimestampMs: 11);

    expect(eventTypes(controller), [PedagogicalEventType.cardSeen]);
  });

  test('eventLog exposto nao permite quebrar estado interno', () {
    final controller = GameRuntimeController()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);
    final exposed = controller.eventLog;

    exposed.clear();

    expect(exposed.isEmpty, isTrue);
    expect(controller.eventLog.length, 1);
    expect(controller.hasPlayableCard, isTrue);
  });

  test('toJson fromJson preserva estado leve', () {
    final controller = GameRuntimeController()
      ..loadMicrodeck(validDeck(count: 2), clientTimestampMs: 10)
      ..selectAnswer(AnswerLetter.A, clientTimestampMs: 11)
      ..selectQualifier(DecisionSignal.one, clientTimestampMs: 12);
    final roundtrip = GameRuntimeController.fromJson(
      decodedJson(controller.toJson()),
    );

    expect(roundtrip.currentCardId, controller.currentCardId);
    expect(roundtrip.currentIndex, controller.currentIndex);
    expect(roundtrip.selectedAnswer, isNull);
    expect(roundtrip.selectedQualifier, isNull);
    expect(roundtrip.eventLog.toJson(), controller.eventLog.toJson());
    expect(roundtrip.toJson(), controller.toJson());
  });

  test('toJson chama validate', () {
    final text = source();
    final toJsonIndex = text.indexOf('Map<String, Object?> toJson()');
    final validateIndex = text.indexOf('validate();', toJsonIndex);
    final returnIndex = text.indexOf('return _store.toJson();', toJsonIndex);

    expect(toJsonIndex, isNonNegative);
    expect(validateIndex, inInclusiveRange(toJsonIndex, returnIndex));
  });

  test('fromJson rejeita chave desconhecida', () {
    expect(
      () => GameRuntimeController.fromJson({
        'microdeck': null,
        'eventLog': {'events': <Object?>[]},
        'needsMicrodeck': true,
        'nextSequence': 0,
        'unknown': true,
      }),
      throwsStateError,
    );
  });

  test('fromJson nao registra evento novo', () {
    final controller = GameRuntimeController()
      ..loadMicrodeck(validDeck(count: 2), clientTimestampMs: 10)
      ..selectAnswer(AnswerLetter.A, clientTimestampMs: 11);
    final before = controller.eventLog.toJson();

    final roundtrip = GameRuntimeController.fromJson(
      decodedJson(controller.toJson()),
    );

    expect(roundtrip.eventLog.toJson(), before);
  });

  test('controller e store nao divergem no mesmo fluxo', () {
    final store = GameStateStore();
    final controller = GameRuntimeController();
    final deck = validDeck(count: 2);

    store.loadMicrodeck(deck, clientTimestampMs: 10);
    controller.loadMicrodeck(deck, clientTimestampMs: 10);
    expectControllerMatchesStore(controller, store);

    store.selectAnswer(AnswerLetter.A, clientTimestampMs: 11);
    controller.selectAnswer(AnswerLetter.A, clientTimestampMs: 11);
    expectControllerMatchesStore(controller, store);

    store.selectQualifier(DecisionSignal.one, clientTimestampMs: 12);
    controller.selectQualifier(DecisionSignal.one, clientTimestampMs: 12);
    expectControllerMatchesStore(controller, store);

    store.advanceToNextCard(clientTimestampMs: 13);
    controller.advanceToNextCard(clientTimestampMs: 13);
    expectControllerMatchesStore(controller, store);
  });

  test('loadMicrodeck timestamp invalido falha e continua vazio', () {
    final controller = GameRuntimeController();

    expect(
      () => controller.loadMicrodeck(validDeck(count: 1), clientTimestampMs: 0),
      throwsA(anything),
    );

    expect(controller.hasPlayableCard, isFalse);
    expect(controller.needsMicrodeck, isTrue);
    expect(controller.eventLog.isEmpty, isTrue);
  });

  test('selectAnswer timestamp invalido falha e nao marca resposta', () {
    final controller = GameRuntimeController()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    expect(
      () => controller.selectAnswer(AnswerLetter.A, clientTimestampMs: 0),
      throwsA(anything),
    );

    expect(controller.selectedAnswer, isNull);
    expect(controller.canSelectQualifier, isFalse);
    expect(eventTypes(controller), [PedagogicalEventType.cardSeen]);
  });

  test('selectQualifier timestamp invalido falha sem feedback', () {
    final controller = GameRuntimeController()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10)
      ..selectAnswer(AnswerLetter.A, clientTimestampMs: 11);

    expect(
      () =>
          controller.selectQualifier(DecisionSignal.one, clientTimestampMs: 0),
      throwsA(anything),
    );

    expect(controller.selectedQualifier, isNull);
    expect(controller.canShowFeedback, isFalse);
    expect(eventTypes(controller), [
      PedagogicalEventType.cardSeen,
      PedagogicalEventType.answerSelected,
    ]);
  });

  test('advanceToNextCard sem proxima nao registra cardAdvanced', () {
    final controller = GameRuntimeController()
      ..loadMicrodeck(validDeck(count: 1), clientTimestampMs: 10);

    controller.advanceToNextCard(clientTimestampMs: 11);

    expect(
      controller.eventLog.events.where(
        (event) => event.type == PedagogicalEventType.cardAdvanced,
      ),
      isEmpty,
    );
  });

  test('controller possui somente estado store', () {
    final text = source();

    expect(text, contains('GameStateStore _store = GameStateStore();'));
    for (final forbidden in [
      'Microdeck? _microdeck',
      'LocalGameRuntime? _runtime',
      'PedagogicalEventLog _eventLog',
      'int _nextSequence',
      'bool _needsMicrodeck',
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('controller nao instancia eventos log runtime nem avanca deck', () {
    final text = source();

    for (final forbidden in [
      token(['Pedagogical', 'Event(']),
      token(['Pedagogical', 'Event', 'Log(']),
      token(['Local', 'Game', 'Runtime(']),
      '.advance()',
      '.selectAnswer(',
      '.selectQualifier(',
    ]) {
      if (forbidden == '.selectAnswer(') {
        expect(
          text.split('\n').where((line) => line.contains(forbidden)).toList(),
          [
            '    _store.selectAnswer(answer, clientTimestampMs: clientTimestampMs);',
          ],
        );
      } else if (forbidden == '.selectQualifier(') {
        expect(
          text.split('\n').where((line) => line.contains(forbidden)).toList(),
          [
            '    _store.selectQualifier(signal, clientTimestampMs: clientTimestampMs);',
          ],
        );
      } else {
        expect(text, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });

  test('controller nao recebe GameStateStore externo nem expoe store', () {
    final text = source();

    expect(text, isNot(contains('GameRuntimeController(GameStateStore')));
    expect(text, isNot(contains('GameRuntimeController(this._store')));
    expect(text, isNot(contains('this._store')));
    expect(text, isNot(contains('get store')));
  });

  test('arquivo produtivo nao contem HTTP servidor IA custo storage UI', () {
    final text = source();
    final forbidden = [
      token(['ht', 'tp']),
      token(['di', 'o']),
      token(['Cli', 'ent']),
      token(['ser', 'ver']),
      token(['sy', 'nc']),
      token(['sto', 'rage']),
      token(['ca', 'che']),
      token(['File']),
      token(['Directory']),
      token(['T', '00']),
      token(['T', '02']),
      token(['N', '3']),
      token(['prompt']),
      token(['adendo']),
      token(['Ai', 'Cost', 'Protection', 'Gate']),
      token(['cred', 'it']),
      token(['cred', 'ito']),
      token(['led', 'ger']),
      token(['co', 'st']),
      token(['bill', 'ing']),
      token(['Gem', 'ini']),
      token(['Open', 'AI']),
      token(['Shared', 'Preferences']),
      token(['Widget']),
      token(['Build', 'Context']),
      token(['Lab', 'Session']),
      token(['Lesson', 'Runtime', 'Engine']),
      token(['Chat', 'Aula', 'Screen']),
      token(['timeline']),
    ];

    for (final term in forbidden) {
      expect(text, isNot(contains(term)), reason: term);
    }
  });

  test('arquivo produtivo nao contem Future Timer Stream async', () {
    final text = source();

    for (final forbidden in [
      token(['Fut', 'ure']),
      token(['Tim', 'er']),
      token(['Str', 'eam']),
      token(['as', 'ync']),
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('arquivo produtivo nao contem Map String dynamic', () {
    expect(source(), isNot(contains('Map<String, dynamic>')));
  });

  test('nao cria tipos paralelos de resposta ou sinal', () {
    final text = source();

    expect(text, contains('AnswerLetter'));
    expect(text, contains('DecisionSignal'));
    for (final forbidden in [
      token(['Game', 'Answer']),
      token(['Game', 'Signal']),
      token(['Pedagogical', 'Answer']),
      token(['Pedagogical', 'Signal']),
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('imports sao os permitidos', () {
    final imports = source()
        .split('\n')
        .where((line) => line.startsWith('import '))
        .toList();

    expect(imports, [
      "import '../state/student_learning_state.dart';",
      "import 'game_state_store.dart';",
      "import 'microdeck.dart';",
      "import 'pedagogical_card.dart';",
      "import 'pedagogical_event_log.dart';",
    ]);
  });
}
