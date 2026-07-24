import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sim_mobile/sim/game/local_game_runtime.dart';
import 'package:sim_mobile/sim/game/pedagogical_card.dart';
import 'package:sim_mobile/sim/game/pedagogical_card_integrity_verifier.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

PedagogicalCard _unsignedCard({
  String cardId = 'card-1',
  AnswerLetter correctAnswer = AnswerLetter.A,
}) => PedagogicalCard(
  cardId: cardId,
  deckId: 'deck-1',
  lessonLocalId: 'lesson-1',
  marker: 'item-1',
  itemIdx: 0,
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
    AnswerLetter.A: 'Feedback da alternativa A',
    AnswerLetter.B: 'Feedback da alternativa B',
    AnswerLetter.C: 'Feedback da alternativa C',
  },
  qualifiers: const {
    DecisionSignal.one: 'Preciso revisar',
    DecisionSignal.two: 'Quase entendi',
    DecisionSignal.three: 'Entendi',
  },
  advancePolicy: const {
    DecisionSignal.one: 'manter',
    DecisionSignal.two: 'reforcar',
    DecisionSignal.three: 'avancar',
  },
  contentHash: 'unsigned',
  contractVersion: PedagogicalCard.supportedContractVersion,
  serverSignature: 'sig-123',
  media: const PedagogicalCardMedia(
    imageKey: 'image/card-1.png',
    audioKey: 'audio/card-1.wav',
  ),
);

PedagogicalCard validCard({
  String cardId = 'card-1',
  AnswerLetter correctAnswer = AnswerLetter.A,
}) {
  final unsigned = _unsignedCard(cardId: cardId, correctAnswer: correctAnswer);
  return PedagogicalCard(
    cardId: cardId,
    deckId: 'deck-1',
    lessonLocalId: 'lesson-1',
    marker: 'item-1',
    itemIdx: 0,
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
      AnswerLetter.A: 'Feedback da alternativa A',
      AnswerLetter.B: 'Feedback da alternativa B',
      AnswerLetter.C: 'Feedback da alternativa C',
    },
    qualifiers: const {
      DecisionSignal.one: 'Preciso revisar',
      DecisionSignal.two: 'Quase entendi',
      DecisionSignal.three: 'Entendi',
    },
    advancePolicy: const {
      DecisionSignal.one: 'manter',
      DecisionSignal.two: 'reforcar',
      DecisionSignal.three: 'avancar',
    },
    contentHash: PedagogicalCardIntegrityVerifier.contentHashForCard(unsigned),
    contractVersion: PedagogicalCard.supportedContractVersion,
    serverSignature: 'sig-123',
    media: const PedagogicalCardMedia(
      imageKey: 'image/card-1.png',
      audioKey: 'audio/card-1.wav',
    ),
  );
}

Map<String, dynamic> validJson() => validCard().toJson();

String token(List<String> parts) => parts.join();

void main() {
  test('runtime inicia com carta valida', () {
    final runtime = LocalGameRuntime(validCard());

    expect(runtime.card.cardId, 'card-1');
    expect(runtime.isReady, isTrue);
    expect(runtime.selectedAnswer, isNull);
    expect(runtime.selectedQualifier, isNull);
    expect(runtime.canShowQualifiers, isFalse);
    expect(runtime.canShowFeedback, isFalse);
    expect(runtime.completed, isFalse);
  });

  test('selectAnswer exige AnswerLetter em assinatura', () {
    final runtime = LocalGameRuntime(validCard());

    final void Function(AnswerLetter) select = runtime.selectAnswer;

    select(AnswerLetter.A);
    expect(runtime.selectedAnswer, AnswerLetter.A);
  });

  test('selectedAnswer retorna AnswerLetter nullable', () {
    final runtime = LocalGameRuntime(validCard());

    final AnswerLetter? selected = runtime.selectedAnswer;

    expect(selected, isNull);
  });

  test('selectQualifier exige DecisionSignal em assinatura', () {
    final runtime = LocalGameRuntime(validCard());

    final void Function(DecisionSignal) select = runtime.selectQualifier;

    runtime.selectAnswer(AnswerLetter.A);
    select(DecisionSignal.one);
    expect(runtime.selectedQualifier, DecisionSignal.one);
  });

  test('selectedQualifier retorna DecisionSignal nullable', () {
    final runtime = LocalGameRuntime(validCard());

    final DecisionSignal? selected = runtime.selectedQualifier;

    expect(selected, isNull);
  });

  test('runtime rejeita carta invalida', () {
    final json = validJson()..remove('contentHash');

    expect(
      () => LocalGameRuntime(PedagogicalCard.fromJson(json)),
      throwsA(isA<PedagogicalCardContractException>()),
    );
  });

  test('selectAnswer A marca A', () {
    final runtime = LocalGameRuntime(validCard());

    runtime.selectAnswer(AnswerLetter.A);

    expect(runtime.selectedAnswer, AnswerLetter.A);
    expect(runtime.hasSelectedAnswer, isTrue);
    expect(runtime.isReady, isFalse);
  });

  test('selectAnswer A habilita qualificadores', () {
    final runtime = LocalGameRuntime(validCard());

    runtime.selectAnswer(AnswerLetter.A);

    expect(runtime.canShowQualifiers, isTrue);
  });

  test('selectAnswer A nao mostra feedback ainda', () {
    final runtime = LocalGameRuntime(validCard());

    runtime.selectAnswer(AnswerLetter.A);

    expect(runtime.canShowFeedback, isFalse);
    expect(runtime.feedbackVisible, isFalse);
    expect(runtime.feedbackText, isNull);
    expect(runtime.wasCorrect, isNull);
  });

  test('selectQualifier 1 apos resposta mostra feedback', () {
    final runtime = LocalGameRuntime(validCard());

    runtime.selectAnswer(AnswerLetter.A);
    runtime.selectQualifier(DecisionSignal.one);

    expect(runtime.selectedQualifier, DecisionSignal.one);
    expect(runtime.canShowFeedback, isTrue);
    expect(runtime.feedbackText, 'Feedback da alternativa A');
    expect(runtime.completed, isTrue);
  });

  test('wasCorrect true quando resposta bate com gabarito', () {
    final runtime = LocalGameRuntime(validCard(correctAnswer: AnswerLetter.B));

    runtime.selectAnswer(AnswerLetter.B);
    runtime.selectQualifier(DecisionSignal.three);

    expect(runtime.wasCorrect, isTrue);
  });

  test('wasCorrect false quando resposta nao bate com gabarito', () {
    final runtime = LocalGameRuntime(validCard(correctAnswer: AnswerLetter.C));

    runtime.selectAnswer(AnswerLetter.A);
    runtime.selectQualifier(DecisionSignal.two);

    expect(runtime.wasCorrect, isFalse);
  });

  test('qualificador antes da resposta e rejeitado', () {
    final runtime = LocalGameRuntime(validCard());

    expect(
      () => runtime.selectQualifier(DecisionSignal.one),
      throwsA(isA<LocalGameRuntimeContractException>()),
    );
  });

  test(
    'trocar resposta antes do qualificador substitui sem empilhar estado',
    () {
      final runtime = LocalGameRuntime(validCard());

      runtime.selectAnswer(AnswerLetter.A);
      runtime.selectAnswer(AnswerLetter.B);

      expect(runtime.selectedAnswer, AnswerLetter.B);
      expect(runtime.selectedQualifier, isNull);
      expect(runtime.feedbackText, isNull);
      expect(runtime.canShowQualifiers, isTrue);
    },
  );

  test('segunda resposta depois do qualificador e rejeitada', () {
    final runtime = LocalGameRuntime(validCard());

    runtime.selectAnswer(AnswerLetter.A);
    runtime.selectQualifier(DecisionSignal.one);

    expect(
      () => runtime.selectAnswer(AnswerLetter.B),
      throwsA(isA<LocalGameRuntimeContractException>()),
    );
    expect(runtime.selectedAnswer, AnswerLetter.A);
    expect(runtime.selectedQualifier, DecisionSignal.one);
    expect(runtime.feedbackText, 'Feedback da alternativa A');
  });

  test('feedback vem da alternativa escolhida', () {
    final runtime = LocalGameRuntime(validCard(correctAnswer: AnswerLetter.A));

    runtime.selectAnswer(AnswerLetter.B);
    runtime.selectQualifier(DecisionSignal.two);

    expect(runtime.wasCorrect, isFalse);
    expect(runtime.feedbackText, 'Feedback da alternativa B');
  });

  test('resetWithCard apaga estado anterior', () {
    final runtime = LocalGameRuntime(validCard());

    runtime.selectAnswer(AnswerLetter.A);
    runtime.selectQualifier(DecisionSignal.one);
    runtime.resetWithCard(validCard(cardId: 'card-2'));

    expect(runtime.card.cardId, 'card-2');
    expect(runtime.isReady, isTrue);
    expect(runtime.selectedAnswer, isNull);
    expect(runtime.selectedQualifier, isNull);
    expect(runtime.feedbackText, isNull);
    expect(runtime.wasCorrect, isNull);
    expect(runtime.canShowQualifiers, isFalse);
    expect(runtime.canShowFeedback, isFalse);
    expect(runtime.completed, isFalse);
  });

  test('runtime nao muta PedagogicalCard', () {
    final card = validCard();
    final before = jsonEncode(card.toJson());
    final runtime = LocalGameRuntime(card);

    runtime.selectAnswer(AnswerLetter.C);
    runtime.selectQualifier(DecisionSignal.three);
    runtime.resetWithCard(card);

    expect(jsonEncode(card.toJson()), before);
  });

  test('arquivo de runtime contem somente imports permitidos', () {
    final source = File(
      'lib/sim/game/local_game_runtime.dart',
    ).readAsStringSync();
    final imports = source
        .split('\n')
        .where((line) => line.startsWith('import '))
        .toList();

    expect(imports, [
      "import '../state/student_learning_state.dart';",
      "import 'pedagogical_card.dart';",
      "import 'pedagogical_card_integrity_verifier.dart';",
    ]);
  });

  test('runtime usa chave oficial do sinal sem depender de ordem do enum', () {
    final source = File(
      'lib/sim/game/local_game_runtime.dart',
    ).readAsStringSync();

    expect(source, contains('containsKey(signal)'));
    expect(source, isNot(contains(token(['index ', '+ 1']))));
  });

  test('runtime nao expoe contrato fraco de resposta qualificador ou fase', () {
    final source = File(
      'lib/sim/game/local_game_runtime.dart',
    ).readAsStringSync();

    for (final forbidden in [
      token(['Object? ', '_selectedAnswer']),
      token(['void selectAnswer', '(Object']),
      token(['String? ', '_selectedQualifier']),
      token(['void selectQualifier', '(String']),
      token(['phase', 'Name']),
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
    'runtime nao contem termos proibidos de rede custo storage ou motor atual',
    () {
      final source = File(
        'lib/sim/game/local_game_runtime.dart',
      ).readAsStringSync();
      final forbidden = [
        token(['h', 'ttp']),
        token(['d', 'io']),
        token(['Cli', 'ent']),
        token(['T', '00']),
        token(['T', '02']),
        token(['N', '3']),
        token(['Ai', 'Cost', 'Protection', 'Gate']),
        token(['cre', 'dit']),
        token(['cre', 'dito']),
        token(['led', 'ger']),
        token(['ser', 'ver']),
        token(['I', 'A']),
        token(['Gem', 'ini']),
        token(['Open', 'AI']),
        token(['un', 'awaited']),
        token(['Ti', 'mer']),
        token(['Shared', 'Preferences']),
        token(['Dri', 'ft']),
        token(['Lab', 'Session']),
        token(['Lesson', 'Runtime', 'Engine']),
        token(['Sim', 'Organism']),
      ];

      for (final term in forbidden) {
        expect(source, isNot(contains(term)), reason: 'Forbidden token: $term');
      }
    },
  );

  test('falsos positivos de assinatura e midia ficam somente no teste', () {
    final runtimeSource = File(
      'lib/sim/game/local_game_runtime.dart',
    ).readAsStringSync();
    final testSource = File(
      'test/sim_game_local_game_runtime_contract_test.dart',
    ).readAsStringSync();

    expect(runtimeSource, isNot(contains(token(['ser', 'ver']))));
    expect(runtimeSource, isNot(contains(token(['d', 'io']))));
    expect(testSource, contains('serverSignature'));
    expect(testSource, contains('audioKey'));
  });
}
