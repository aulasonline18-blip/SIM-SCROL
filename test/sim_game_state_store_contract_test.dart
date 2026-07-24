import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/game_state_store.dart';
import 'package:sim_mobile/sim/game/microdeck.dart';
import 'package:sim_mobile/sim/game/pedagogical_card.dart';
import 'package:sim_mobile/sim/game/pedagogical_card_integrity_verifier.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _sourcePath = 'lib/sim/game/game_state_store.dart';

Matcher _signatureUnavailable() => throwsA(
  isA<PedagogicalCardIntegrityException>().having(
    (error) => error.message,
    'message',
    'signatureVerificationUnavailable',
  ),
);

String source() => File(_sourcePath).readAsStringSync();

void main() {
  test('GameStateStore e final class', () {
    expect(source(), contains('final class GameStateStore'));
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

  test('loadMicrodeck bloqueado por assinatura nao muta estado', () {
    final store = GameStateStore();

    expect(
      () => store.loadMicrodeck(
        const TestFixtureMicrodeck(),
        clientTimestampMs: 10,
      ),
      _signatureUnavailable(),
    );

    expect(store.currentCard, isNull);
    expect(store.currentCardId, isNull);
    expect(store.currentIndex, isNull);
    expect(store.hasPlayableCard, isFalse);
    expect(store.needsMicrodeck, isTrue);
    expect(store.eventLog.isEmpty, isTrue);
  });

  test('sem carta nenhuma interacao local e permitida', () {
    final store = GameStateStore();

    expect(store.canSelectAnswer, isFalse);
    expect(store.canSelectQualifier, isFalse);
    expect(store.canShowFeedback, isFalse);
    expect(
      () => store.selectAnswer(AnswerLetter.A, clientTimestampMs: 10),
      throwsStateError,
    );
    expect(
      () => store.selectQualifier(DecisionSignal.one, clientTimestampMs: 10),
      throwsStateError,
    );
    expect(
      () => store.advanceToNextCard(clientTimestampMs: 10),
      throwsStateError,
    );
  });

  test('fromJson com microdeck nao verificavel tambem bloqueia', () {
    expect(
      () => GameStateStore.fromJson({
        'microdeck': {
          'microdeckId': 'deck-1',
          'cards': [unverifiableCardJson()],
          'currentIndex': 0,
        },
        'eventLog': {'events': const []},
        'needsMicrodeck': false,
        'nextSequence': 0,
      }),
      _signatureUnavailable(),
    );
  });

  test('imports continuam exatamente os permitidos', () {
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

  test('arquivo produtivo nao contem modo fraco nem termos proibidos', () {
    final text = source();

    for (final forbidden in [
      'skipSignature',
      'allowUnsigned',
      'allowHashOnly',
      'testMode',
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
    expect(
      text,
      isNot(
        contains(
          'by'
          'pass',
        ),
      ),
    );
  });
}

final class TestFixtureMicrodeck implements Microdeck {
  const TestFixtureMicrodeck();

  @override
  void validate() {
    throw const PedagogicalCardIntegrityException(
      'signatureVerificationUnavailable',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, Object?> unverifiableCardJson() {
  final card = PedagogicalCard(
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
    serverSignature: 'signature-x',
  );
  return {
    ...card.toJson(),
    'contentHash': PedagogicalCardIntegrityVerifier.contentHashForCard(card),
  };
}
