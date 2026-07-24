import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/game_runtime_controller.dart';
import 'package:sim_mobile/sim/game/microdeck.dart';
import 'package:sim_mobile/sim/game/pedagogical_card.dart';
import 'package:sim_mobile/sim/game/pedagogical_card_integrity_verifier.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _sourcePath = 'lib/sim/game/game_runtime_controller.dart';

Matcher _signatureUnavailable() => throwsA(
  isA<PedagogicalCardIntegrityException>().having(
    (error) => error.message,
    'message',
    'signatureVerificationUnavailable',
  ),
);

String source() => File(_sourcePath).readAsStringSync();

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

  test('loadMicrodeck bloqueado por assinatura nao muta controller', () {
    final controller = GameRuntimeController();

    expect(
      () => controller.loadMicrodeck(
        const TestFixtureMicrodeck(),
        clientTimestampMs: 10,
      ),
      _signatureUnavailable(),
    );

    expect(controller.currentCard, isNull);
    expect(controller.currentCardId, isNull);
    expect(controller.hasPlayableCard, isFalse);
    expect(controller.needsMicrodeck, isTrue);
    expect(controller.eventLog.isEmpty, isTrue);
  });

  test('sem carta controller nao permite interacoes', () {
    final controller = GameRuntimeController();

    expect(
      () => controller.selectAnswer(AnswerLetter.A, clientTimestampMs: 10),
      throwsStateError,
    );
    expect(
      () =>
          controller.selectQualifier(DecisionSignal.one, clientTimestampMs: 10),
      throwsStateError,
    );
    expect(
      () => controller.advanceToNextCard(clientTimestampMs: 10),
      throwsStateError,
    );
  });

  test('fromJson com microdeck nao verificavel bloqueia', () {
    expect(
      () => GameRuntimeController.fromJson({
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

  test('controller delega ao store e nao cria runtime proprio', () {
    final text = source();

    expect(text, contains('GameStateStore _store = GameStateStore();'));
    expect(text, isNot(contains('LocalGameRuntime')));
    expect(text, isNot(contains('PedagogicalEvent(')));
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

  test('arquivo produtivo nao contem modo fraco nem termos proibidos', () {
    final text = source();

    for (final forbidden in [
      'skipSignature',
      'allowUnsigned',
      'allowHashOnly',
      'testMode',
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
