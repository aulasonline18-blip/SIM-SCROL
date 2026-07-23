import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/domain_policy.dart';
import 'package:sim_mobile/sim/game/pedagogical_card.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  group('DomainPolicy contract', () {
    test('DomainPolicy e final class', () {
      expect(_source(), contains('final class DomainPolicy'));
    });

    test('DomainDecision e final class e imutavel', () {
      final source = _source();

      expect(source, contains('final class DomainDecision'));
      expect(source, contains('const DomainDecision({'));
      expect(source, contains('final DomainDecisionKind kind;'));
      expect(source, contains('final bool wasCorrect;'));
      expect(source, contains('final AnswerLetter selectedAnswer;'));
      expect(source, contains('final AnswerLetter correctAnswer;'));
      expect(source, contains('final DecisionSignal qualifier;'));
      expect(source, contains('final LessonLayer layer;'));
      expect(source, contains('final String reason;'));
      expect(source, contains('final bool shouldContinue;'));
      expect(source, contains('final bool scheduleReview;'));
      expect(source, contains('final bool requiresRecovery;'));
      expect(source, contains('final bool offerSupport;'));
      expect(source, contains('final bool falseConfidence;'));
      expect(source, contains('final bool protectSelfEsteem;'));
      expect(source, contains('final bool requiresCheck;'));
      expect(source, contains('final bool canConsolidate;'));
      expect(source, isNot(contains('set ')));
    });

    test('DomainDecisionKind contem exatamente os destinos permitidos', () {
      expect(DomainDecisionKind.values.map((kind) => kind.name), [
        'continueLesson',
        'review',
        'recovery',
        'support',
        'doubt',
      ]);
    });

    test('usa tipos oficiais de resposta sinal camada e carta', () {
      final decision = const DomainPolicy().decideAfterQualifier(
        card: _card(),
        selectedAnswer: AnswerLetter.A,
        qualifier: DecisionSignal.one,
      );

      expect(decision.selectedAnswer, isA<AnswerLetter>());
      expect(decision.correctAnswer, isA<AnswerLetter>());
      expect(decision.qualifier, isA<DecisionSignal>());
      expect(decision.layer, isA<LessonLayer>());
    });

    test('nao cria enum paralelo de resposta sinal ou camada', () {
      final source = _source();

      expect(source, isNot(contains('PedagogicalAnswer')));
      expect(source, isNot(contains('GameAnswer')));
      expect(source, isNot(contains('AnswerSignal')));
      expect(source, isNot(contains('SignalValue')));
      expect(source, isNot(contains('LayerValue')));
    });

    test('errado com sinal 1 identifica falsa confianca e recovery', () {
      final decision = const DomainPolicy().decideAfterQualifier(
        card: _card(correctAnswer: AnswerLetter.B),
        selectedAnswer: AnswerLetter.A,
        qualifier: DecisionSignal.one,
      );

      expect(decision.kind, DomainDecisionKind.recovery);
      expect(decision.wasCorrect, isFalse);
      expect(decision.requiresRecovery, isTrue);
      expect(decision.offerSupport, isTrue);
      expect(decision.falseConfidence, isTrue);
      expect(decision.protectSelfEsteem, isFalse);
      expect(decision.shouldContinue, isFalse);
      expect(decision.scheduleReview, isTrue);
      expect(decision.requiresCheck, isTrue);
      expect(decision.canConsolidate, isFalse);
    });

    test('errado com sinal 2 retorna support com recuperacao', () {
      final decision = const DomainPolicy().decideAfterQualifier(
        card: _card(correctAnswer: AnswerLetter.B),
        selectedAnswer: AnswerLetter.A,
        qualifier: DecisionSignal.two,
      );

      expect(decision.kind, DomainDecisionKind.support);
      expect(decision.wasCorrect, isFalse);
      expect(decision.requiresRecovery, isTrue);
      expect(decision.offerSupport, isTrue);
      expect(decision.falseConfidence, isFalse);
      expect(decision.protectSelfEsteem, isTrue);
      expect(decision.shouldContinue, isFalse);
      expect(decision.scheduleReview, isTrue);
      expect(decision.requiresCheck, isTrue);
      expect(decision.canConsolidate, isFalse);
    });

    test('errado com sinal 3 retorna support protegendo autoestima', () {
      final decision = const DomainPolicy().decideAfterQualifier(
        card: _card(correctAnswer: AnswerLetter.B),
        selectedAnswer: AnswerLetter.A,
        qualifier: DecisionSignal.three,
      );

      expect(decision.kind, DomainDecisionKind.support);
      expect(decision.wasCorrect, isFalse);
      expect(decision.requiresRecovery, isTrue);
      expect(decision.offerSupport, isTrue);
      expect(decision.falseConfidence, isFalse);
      expect(decision.protectSelfEsteem, isTrue);
      expect(decision.shouldContinue, isFalse);
      expect(decision.scheduleReview, isTrue);
      expect(decision.requiresCheck, isTrue);
      expect(decision.canConsolidate, isFalse);
    });

    test('todo erro exige recuperacao e nunca consolida', () {
      for (final layer in LessonLayer.values) {
        for (final qualifier in DecisionSignal.values) {
          final decision = const DomainPolicy().decideAfterQualifier(
            card: _card(layer: layer, correctAnswer: AnswerLetter.B),
            selectedAnswer: AnswerLetter.A,
            qualifier: qualifier,
          );

          expect(decision.kind, isNot(DomainDecisionKind.continueLesson));
          expect(decision.wasCorrect, isFalse);
          expect(decision.requiresRecovery, isTrue);
          expect(decision.canConsolidate, isFalse);
          expect(decision.shouldContinue, isFalse);
        }
      }
    });

    test('correto com sinal 1 continua, agenda revisao e consolida', () {
      for (final layer in LessonLayer.values) {
        final decision = const DomainPolicy().decideAfterQualifier(
          card: _card(layer: layer),
          selectedAnswer: AnswerLetter.A,
          qualifier: DecisionSignal.one,
        );

        expect(decision.kind, DomainDecisionKind.continueLesson);
        expect(decision.wasCorrect, isTrue);
        expect(decision.shouldContinue, isTrue);
        expect(decision.scheduleReview, isTrue);
        expect(decision.requiresRecovery, isFalse);
        expect(decision.offerSupport, isFalse);
        expect(decision.falseConfidence, isFalse);
        expect(decision.protectSelfEsteem, isFalse);
        expect(decision.requiresCheck, isFalse);
        expect(decision.canConsolidate, isTrue);
      }
    });

    test(
      'correto com sinal 2 agenda revisao, exige checagem e nao consolida',
      () {
        for (final layer in LessonLayer.values) {
          final decision = const DomainPolicy().decideAfterQualifier(
            card: _card(layer: layer),
            selectedAnswer: AnswerLetter.A,
            qualifier: DecisionSignal.two,
          );

          expect(decision.kind, DomainDecisionKind.review);
          expect(decision.wasCorrect, isTrue);
          expect(decision.shouldContinue, isTrue);
          expect(decision.scheduleReview, isTrue);
          expect(decision.requiresRecovery, isFalse);
          expect(decision.offerSupport, isFalse);
          expect(decision.falseConfidence, isFalse);
          expect(decision.protectSelfEsteem, isFalse);
          expect(decision.requiresCheck, isTrue);
          expect(decision.canConsolidate, isFalse);
        }
      },
    );

    test(
      'correto com sinal 3 oferece suporte e nao continua automaticamente',
      () {
        for (final layer in LessonLayer.values) {
          final decision = const DomainPolicy().decideAfterQualifier(
            card: _card(layer: layer),
            selectedAnswer: AnswerLetter.A,
            qualifier: DecisionSignal.three,
          );

          expect(decision.kind, DomainDecisionKind.support);
          expect(decision.wasCorrect, isTrue);
          expect(decision.shouldContinue, isFalse);
          expect(decision.scheduleReview, isTrue);
          expect(decision.requiresRecovery, isFalse);
          expect(decision.offerSupport, isTrue);
          expect(decision.falseConfidence, isFalse);
          expect(decision.protectSelfEsteem, isTrue);
          expect(decision.requiresCheck, isTrue);
          expect(decision.canConsolidate, isFalse);
        }
      },
    );

    test('doubt existe mas nao e retornado automaticamente', () {
      expect(DomainDecisionKind.values, contains(DomainDecisionKind.doubt));

      for (final layer in LessonLayer.values) {
        for (final answer in AnswerLetter.values) {
          for (final qualifier in DecisionSignal.values) {
            final decision = const DomainPolicy().decideAfterQualifier(
              card: _card(layer: layer, correctAnswer: AnswerLetter.A),
              selectedAnswer: answer,
              qualifier: qualifier,
            );

            expect(decision.kind, isNot(DomainDecisionKind.doubt));
          }
        }
      }
    });

    test('layer 3 correta com sinal 1 continua sem criar L4', () {
      final decision = const DomainPolicy().decideAfterQualifier(
        card: _card(layer: LessonLayer.l3),
        selectedAnswer: AnswerLetter.A,
        qualifier: DecisionSignal.one,
      );

      expect(decision.kind, DomainDecisionKind.continueLesson);
      expect(decision.layer, LessonLayer.l3);
      expect(decision.canConsolidate, isTrue);
      expect(
        LessonLayer.values.map((layer) => layer.name),
        isNot(contains('l4')),
      );
    });

    test('layer 3 correta com sinal 2 nao consolida', () {
      final decision = const DomainPolicy().decideAfterQualifier(
        card: _card(layer: LessonLayer.l3),
        selectedAnswer: AnswerLetter.A,
        qualifier: DecisionSignal.two,
      );

      expect(decision.kind, DomainDecisionKind.review);
      expect(decision.shouldContinue, isTrue);
      expect(decision.scheduleReview, isTrue);
      expect(decision.requiresCheck, isTrue);
      expect(decision.canConsolidate, isFalse);
    });

    test('layer 3 correta com sinal 3 nao consolida nem continua', () {
      final decision = const DomainPolicy().decideAfterQualifier(
        card: _card(layer: LessonLayer.l3),
        selectedAnswer: AnswerLetter.A,
        qualifier: DecisionSignal.three,
      );

      expect(decision.kind, DomainDecisionKind.support);
      expect(decision.shouldContinue, isFalse);
      expect(decision.offerSupport, isTrue);
      expect(decision.requiresCheck, isTrue);
      expect(decision.canConsolidate, isFalse);
    });

    test('layer 3 errada nunca continua nem consolida', () {
      for (final qualifier in DecisionSignal.values) {
        final decision = const DomainPolicy().decideAfterQualifier(
          card: _card(layer: LessonLayer.l3, correctAnswer: AnswerLetter.B),
          selectedAnswer: AnswerLetter.A,
          qualifier: qualifier,
        );

        expect(decision.kind, isNot(DomainDecisionKind.continueLesson));
        expect(decision.shouldContinue, isFalse);
        expect(decision.canConsolidate, isFalse);
        expect(decision.layer, LessonLayer.l3);
      }
    });

    test('carta invalida e rejeitada sem decisao neutra', () {
      expect(
        () => const DomainPolicy().decideAfterQualifier(
          card: PedagogicalCard.fromJson(_validJson()..['question'] = ''),
          selectedAnswer: AnswerLetter.A,
          qualifier: DecisionSignal.one,
        ),
        throwsA(isA<PedagogicalCardContractException>()),
      );
    });

    test('qualificador ausente na carta e rejeitado sem fallback', () {
      final card = _CardWithoutQualifier();

      expect(
        () => const DomainPolicy().decideAfterQualifier(
          card: card,
          selectedAnswer: AnswerLetter.A,
          qualifier: DecisionSignal.three,
        ),
        throwsA(isA<PedagogicalCardContractException>()),
      );
    });

    test('resposta ausente na carta e rejeitada sem fallback', () {
      final card = _CardWithoutAnswer();

      expect(
        () => const DomainPolicy().decideAfterQualifier(
          card: card,
          selectedAnswer: AnswerLetter.C,
          qualifier: DecisionSignal.one,
        ),
        throwsA(isA<PedagogicalCardContractException>()),
      );
    });

    test('reason nunca e vazio e e deterministico', () {
      final first = const DomainPolicy().decideAfterQualifier(
        card: _card(),
        selectedAnswer: AnswerLetter.A,
        qualifier: DecisionSignal.two,
      );
      final second = const DomainPolicy().decideAfterQualifier(
        card: _card(),
        selectedAnswer: AnswerLetter.A,
        qualifier: DecisionSignal.two,
      );

      expect(first.reason, isNotEmpty);
      expect(first.reason, second.reason);
      expect(first.reason, isNot(contains('prompt')));
      expect(first.reason, isNot(contains('T00')));
      expect(first.reason, isNot(contains('T02')));
      expect(first.reason, isNot(contains('N3')));
    });

    test('metodo nao modifica PedagogicalCard', () {
      final card = _card();
      final before = card.toJson().toString();

      const DomainPolicy().decideAfterQualifier(
        card: card,
        selectedAnswer: AnswerLetter.A,
        qualifier: DecisionSignal.three,
      );

      expect(card.toJson().toString(), before);
    });

    test('DomainPolicy nao tem campos de instancia', () {
      final body = _source()
          .split('final class DomainPolicy {')
          .last
          .split('DomainDecision decideAfterQualifier')
          .first;

      expect(body, isNot(contains(RegExp(r'\n\s*final\s+'))));
      expect(body, isNot(contains(RegExp(r'\n\s*late\s+'))));
      expect(body, isNot(contains(RegExp(r'\n\s*var\s+'))));
      expect(body, isNot(contains(RegExp(r'\n\s*List<'))));
      expect(body, isNot(contains(RegExp(r'\n\s*Set<'))));
    });

    test('metodo e sincrono por assinatura', () {
      final source = _source();

      expect(source, contains('DomainDecision decideAfterQualifier({'));
      expect(source, isNot(contains('Future<DomainDecision>')));
      expect(source, isNot(contains('async')));
    });

    test('arquivo produtivo nao contem imports proibidos', () {
      final imports = RegExp(
        r"^import .+;$",
        multiLine: true,
      ).allMatches(_source()).map((match) => match.group(0)).toList();

      expect(imports, [
        "import '../state/student_learning_state.dart';",
        "import 'pedagogical_card.dart';",
      ]);
    });

    test('arquivo produtivo nao contem termos proibidos', () {
      final source = _source();
      const forbidden = [
        'http',
        'dio',
        'Client',
        'server',
        'servidor',
        'IA',
        'Gemini',
        'OpenAI',
        'T00',
        'T02',
        'N3',
        'prompt',
        'adendo',
        'credit',
        'credito',
        'ledger',
        'billing',
        'cost',
        'AiCostProtectionGate',
        'rate limit',
        'Retry-After',
        'single-flight',
        'SharedPreferences',
        'Drift',
        'storage',
        'cache',
        'sync',
        'Future',
        'async',
        'Timer',
        'Stream',
        'DateTime',
        'Random',
        'uuid',
        'now',
        'timestamp',
        'Widget',
        'Material',
        'BuildContext',
        'LabSession',
        'LessonRuntimeEngine',
        'GameRuntimeController',
        'GameStateStore',
        'LocalGameRuntime',
        'Microdeck',
        'PedagogicalEvent',
        'PedagogicalEventLog',
        'Navigator',
        'route',
        'Room',
        'room',
        'reforco',
        'reforço',
        'Reforco',
        'reinforcement',
        'Reinforcement',
        'supportRoom',
        'recoveryRoom',
        'reviewRoom',
        'Map<String, dynamic>',
        'dynamic',
        'Object',
        'catch (_)',
        'toJson',
        'fromJson',
        'copyWith',
      ];

      for (final token in forbidden) {
        expect(source, isNot(contains(token)), reason: token);
      }
    });

    test('nao existe fallback de resposta ou qualificador', () {
      final source = _source();

      expect(source, isNot(contains('AnswerLetter.A;')));
      expect(source, isNot(contains('DecisionSignal.one;')));
      expect(source, isNot(contains('fromValue')));
      expect(source, isNot(contains('orElse')));
    });

    test('nao cria sala rota fluxo ou destino inventado', () {
      final source = _source();

      expect(source, isNot(contains('Room')));
      expect(source, isNot(contains('room')));
      expect(source, isNot(contains('route')));
      expect(source, isNot(contains('flow')));
      expect(source, isNot(contains('path')));
    });

    test('nao existe teste dependente de estado git local', () {
      final forbiddenGitStateCommand = ['git', 'ls-files'].join(' ');

      expect(
        File(
          'test/sim_game_domain_policy_contract_test.dart',
        ).readAsStringSync(),
        isNot(contains(forbiddenGitStateCommand)),
      );
    });
  });
}

class _CardWithoutQualifier extends PedagogicalCard {
  _CardWithoutQualifier()
    : super(
        cardId: 'card-1',
        deckId: 'deck-1',
        lessonLocalId: 'lesson-1',
        marker: 'M1',
        itemIdx: 0,
        layer: LessonLayer.l1,
        explanation: 'Explicacao',
        question: 'Pergunta?',
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
          DecisionSignal.one: 'seguir',
          DecisionSignal.two: 'revisar',
          DecisionSignal.three: 'amparar',
        },
        contentHash: 'hash-1',
        contractVersion: PedagogicalCard.supportedContractVersion,
        serverSignature: 'signature-1',
      ) {
    _hideQualifier = true;
  }

  bool _hideQualifier = false;

  @override
  Map<DecisionSignal, String> get qualifiers => _hideQualifier
      ? const {
          DecisionSignal.one: 'Tenho certeza',
          DecisionSignal.two: 'Tenho duvida',
        }
      : super.qualifiers;
}

class _CardWithoutAnswer extends PedagogicalCard {
  _CardWithoutAnswer()
    : super(
        cardId: 'card-1',
        deckId: 'deck-1',
        lessonLocalId: 'lesson-1',
        marker: 'M1',
        itemIdx: 0,
        layer: LessonLayer.l1,
        explanation: 'Explicacao',
        question: 'Pergunta?',
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
          DecisionSignal.one: 'seguir',
          DecisionSignal.two: 'revisar',
          DecisionSignal.three: 'amparar',
        },
        contentHash: 'hash-1',
        contractVersion: PedagogicalCard.supportedContractVersion,
        serverSignature: 'signature-1',
      ) {
    _hideAnswer = true;
  }

  bool _hideAnswer = false;

  @override
  Map<AnswerLetter, String> get options => _hideAnswer
      ? const {AnswerLetter.A: 'Alternativa A', AnswerLetter.B: 'Alternativa B'}
      : super.options;
}

PedagogicalCard _card({
  AnswerLetter correctAnswer = AnswerLetter.A,
  LessonLayer layer = LessonLayer.l1,
}) {
  return PedagogicalCard(
    cardId: 'card-1',
    deckId: 'deck-1',
    lessonLocalId: 'lesson-1',
    marker: 'M1',
    itemIdx: 0,
    layer: layer,
    explanation: 'Explicacao',
    question: 'Pergunta?',
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
      DecisionSignal.one: 'seguir',
      DecisionSignal.two: 'revisar',
      DecisionSignal.three: 'amparar',
    },
    contentHash: 'hash-1',
    contractVersion: PedagogicalCard.supportedContractVersion,
    serverSignature: 'signature-1',
  );
}

Map<String, Object?> _validJson() => {
  'cardId': 'card-1',
  'deckId': 'deck-1',
  'lessonLocalId': 'lesson-1',
  'marker': 'M1',
  'itemIdx': 0,
  'layer': 1,
  'explanation': 'Explicacao',
  'question': 'Pergunta?',
  'options': {'A': 'Alternativa A', 'B': 'Alternativa B', 'C': 'Alternativa C'},
  'correctAnswer': 'A',
  'feedback': {'A': 'Feedback A', 'B': 'Feedback B', 'C': 'Feedback C'},
  'qualifiers': {'1': 'Tenho certeza', '2': 'Tenho duvida', '3': 'Inseguro'},
  'advancePolicy': {'1': 'seguir', '2': 'revisar', '3': 'amparar'},
  'contentHash': 'hash-1',
  'contractVersion': PedagogicalCard.supportedContractVersion,
  'serverSignature': 'signature-1',
};

String _source() => File('lib/sim/game/domain_policy.dart').readAsStringSync();
