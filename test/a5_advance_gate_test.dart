import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/constitution/sim_constitutional_contract.dart';
import 'package:sim_mobile/sim/state/learning_decision_engine.dart';
import 'package:sim_mobile/sim/state/mastery_truth_engine.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_lesson_executor.dart';

const _items = [
  CurriculumItem(marker: 'M1', text: 'Frações'),
  CurriculumItem(marker: 'M2', text: 'Decimais'),
];
const _contract = SimConstitutionalContract();
const _truthEngine = MasteryTruthEngine();

StudentLearningState _state({
  String lessonLocalId = 'a5-lesson',
  int itemIdx = 0,
  LessonLayer layer = LessonLayer.l1,
  List<LessonAttempt> attempts = const [],
  List<String> concluidos = const [],
}) {
  final marker = itemIdx >= 0 && itemIdx < _items.length
      ? _items[itemIdx].marker
      : null;
  return StudentLearningState.empty(lessonLocalId: lessonLocalId).copyWith(
    curriculum: const StudentCurriculum(
      topic: 'Matematica',
      totalItems: 2,
      generatedAt: 1,
      provisional: false,
      items: _items,
    ),
    current: LessonCurrent(
      itemIdx: itemIdx,
      marker: marker,
      layer: layer,
      amparoLvl: 0,
    ),
    progress: LessonProgress(
      itemIdx: itemIdx,
      layer: layer,
      erros: 0,
      amparoLvl: 0,
      historia: const [],
      mainAdvances: itemIdx,
      concluidos: concluidos,
      pendentesMarkers: const [],
      totalItems: _items.length,
      pctAvanco: itemIdx == 0 ? 0 : 50,
    ),
    attempts: attempts,
  );
}

LessonAttempt _attempt({
  String marker = 'M1',
  LessonLayer layer = LessonLayer.l1,
  AnswerLetter letra = AnswerLetter.A,
  DecisionSignal sinal = DecisionSignal.one,
  bool correct = true,
  int ts = 1,
}) {
  return LessonAttempt(
    marker: marker,
    layer: layer,
    letra: letra,
    sinal: sinal,
    correct: correct,
    ts: ts,
  );
}

void main() {
  group('A5 - Advance Gate e Dominio Real', () {
    test('A5.1 Advance Gate existe separado da tela e da IA', () {
      final noStateDecision = decideNextActionFromState(null);
      expect(noStateDecision.actionType, DecisionActionType.noSafeDecision);

      final noEvidenceGate = _contract.evaluateAdvanceGate(
        evidence: null,
        masteryEvidence: null,
        aiDecision: const {'advance': true, 'reason': 'IA mandou avancar'},
      );

      expect(noEvidenceGate.allowAdvance, isFalse);
      expect(noEvidenceGate.reason, 'sem evidencia');

      final screenOnlyState = _state();
      final screenOnlyDecision = decideNextActionFromState(screenOnlyState);
      expect(
        screenOnlyDecision.actionType,
        DecisionActionType.showCurrentLesson,
      );

      void aiTryingToOwnProgress() => _contract.assertPowerBoundary(
        actor: SimPowerActor.tutor,
        action: 'decide',
        target: 'advance progress',
      );
      expect(aiTryingToOwnProgress, throwsA(isA<SimConstitutionViolation>()));
    });

    test('A5.2 Advance Gate considera acerto e erro', () {
      final correct = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 20,
      );
      final wrong = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.B,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 21,
      );

      expect(correct.attempts.single.correct, isTrue);
      expect(wrong.attempts.single.correct, isFalse);
      expect(correct.progress?.layer, LessonLayer.l3);
      expect(wrong.progress?.layer, LessonLayer.l2);

      final wrongGate = _contract.evaluateAdvanceGate(
        evidence: const SimAnswerEvidence(
          marker: 'M1',
          layer: LessonLayer.l1,
          selectedAnswer: AnswerLetter.B,
          signal: DecisionSignal.one,
          correct: false,
          validatedBySoftware: true,
        ),
        masteryEvidence: null,
      );
      final isolatedCorrectEvidence = _truthEngine.evaluateMarker(
        correct,
        'M1',
      );
      final isolatedCorrectGate = _contract.evaluateAdvanceGate(
        evidence: const SimAnswerEvidence(
          marker: 'M1',
          layer: LessonLayer.l1,
          selectedAnswer: AnswerLetter.A,
          signal: DecisionSignal.one,
          correct: true,
          validatedBySoftware: true,
        ),
        masteryEvidence: isolatedCorrectEvidence,
      );

      expect(wrongGate.allowAdvance, isFalse);
      expect(wrongGate.reason, 'resposta incorreta');
      expect(isolatedCorrectEvidence.status, MasteryStatus.learning);
      expect(isolatedCorrectGate.allowAdvance, isFalse);
      expect(isolatedCorrectGate.reason, 'dominio real ainda nao comprovado');
    });

    test('A5.3 Advance Gate considera sinal 1, 2 e 3', () {
      final signalOne = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 30,
      );
      final signalTwo = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.two,
          correctAnswer: AnswerLetter.A,
        ),
        now: 31,
      );
      final signalThree = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.three,
          correctAnswer: AnswerLetter.A,
        ),
        now: 32,
      );

      expect(signalOne.attempts.single.sinal, DecisionSignal.one);
      expect(signalTwo.attempts.single.sinal, DecisionSignal.two);
      expect(signalThree.attempts.single.sinal, DecisionSignal.three);
      expect(signalOne.progress?.layer, LessonLayer.l3);
      expect(signalTwo.progress?.layer, LessonLayer.l2);
      expect(signalThree.progress?.layer, LessonLayer.l2);

      final fragileEvidence = _truthEngine.evaluateMarker(signalThree, 'M1');
      final fragileGate = _contract.evaluateAdvanceGate(
        evidence: const SimAnswerEvidence(
          marker: 'M1',
          layer: LessonLayer.l1,
          selectedAnswer: AnswerLetter.A,
          signal: DecisionSignal.three,
          correct: true,
          validatedBySoftware: true,
        ),
        masteryEvidence: fragileEvidence,
      );

      expect(fragileEvidence.status, MasteryStatus.learning);
      expect(fragileEvidence.needsReview, isTrue);
      expect(fragileGate.allowAdvance, isFalse);
    });

    test('A5.4 Advance Gate considera a camada atual', () {
      final l1Strong = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 40,
      );
      final l1Weak = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.three,
          correctAnswer: AnswerLetter.A,
        ),
        now: 41,
      );
      final l2Strong = processAnswerWithEngine(
        _state(layer: LessonLayer.l2),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.two,
          correctAnswer: AnswerLetter.A,
        ),
        now: 42,
      );
      final l2Weak = processAnswerWithEngine(
        _state(layer: LessonLayer.l2),
        const AnswerContext(
          letra: AnswerLetter.C,
          sinal: DecisionSignal.two,
          correctAnswer: AnswerLetter.A,
        ),
        now: 43,
      );
      final l3Strong = processAnswerWithEngine(
        _state(layer: LessonLayer.l3),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 44,
      );
      final l3Weak = processAnswerWithEngine(
        _state(layer: LessonLayer.l3),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.three,
          correctAnswer: AnswerLetter.A,
        ),
        now: 45,
      );

      expect(l1Strong.progress?.layer, LessonLayer.l3);
      expect(l1Weak.progress?.layer, LessonLayer.l2);
      expect(l2Strong.progress?.layer, LessonLayer.l3);
      expect(l2Weak.progress?.layer, LessonLayer.l2);
      expect(l2Weak.events.last.payload['decision'], 'needsReinforcement');
      expect(
        l2Weak.events.last.payload['reason'],
        'L2 sem evidencia suficiente para propor L3',
      );
      expect(l3Strong.progress?.itemIdx, 1);
      expect(l3Strong.progress?.layer, LessonLayer.l1);
      expect(l3Weak.progress?.itemIdx, 0);
      expect(l3Weak.progress?.layer, LessonLayer.l3);
      expect(l3Weak.events.last.payload['decision'], 'needsReinforcement');
      expect(
        l3Weak.events.last.payload['reason'],
        'L3 sem evidencia suficiente para concluir item',
      );
    });

    test(
      'A5.5 Advance Gate considera historico isolado por marker e camada',
      () {
        final contaminatedHistory = _state(
          itemIdx: 0,
          layer: LessonLayer.l1,
          attempts: [
            _attempt(
              marker: 'M2',
              layer: LessonLayer.l1,
              correct: true,
              ts: 50,
            ),
            _attempt(
              marker: 'M1',
              layer: LessonLayer.l2,
              correct: true,
              ts: 51,
            ),
          ],
        );
        final withoutCurrentEvidence = decideNextActionFromState(
          contaminatedHistory,
        );

        expect(
          withoutCurrentEvidence.actionType,
          DecisionActionType.showCurrentLesson,
        );
        expect(
          withoutCurrentEvidence.reason,
          'manter posicao corrente (sem evidencia para avancar)',
        );

        final isolatedHistory = _state(
          itemIdx: 0,
          layer: LessonLayer.l1,
          attempts: [
            _attempt(
              marker: 'M2',
              layer: LessonLayer.l1,
              correct: true,
              ts: 52,
            ),
            _attempt(
              marker: 'M1',
              layer: LessonLayer.l2,
              correct: true,
              ts: 53,
            ),
            _attempt(
              marker: 'M1',
              layer: LessonLayer.l1,
              correct: true,
              ts: 54,
            ),
          ],
        );
        final withCurrentEvidence = decideNextActionFromState(isolatedHistory);

        expect(withCurrentEvidence.actionType, DecisionActionType.advanceLayer);
        expect(withCurrentEvidence.proposedMarker, 'M1');
        expect(withCurrentEvidence.proposedLayer, LessonLayer.l3);
      },
    );

    test('A5.6 acerto unico nao vira dominio pleno', () {
      final answeredOnce = processAnswerWithEngine(
        _state(layer: LessonLayer.l3),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 60,
      );
      final evidence = _truthEngine.evaluateMarker(answeredOnce, 'M1');
      final gate = _contract.evaluateAdvanceGate(
        evidence: const SimAnswerEvidence(
          marker: 'M1',
          layer: LessonLayer.l3,
          selectedAnswer: AnswerLetter.A,
          signal: DecisionSignal.one,
          correct: true,
          validatedBySoftware: true,
        ),
        masteryEvidence: evidence,
      );

      expect(evidence.status, MasteryStatus.learning);
      expect(evidence.reason, 'um acerto isolado nao prova dominio');
      expect(evidence.needsReview, isTrue);
      expect(gate.allowAdvance, isFalse);
      expect(answeredOnce.progress?.concluidos, isNot(contains('M1')));
      expect(answeredOnce.attempts.single.marker, 'M1');
    });

    test('A5.7 erro com sinal 1 registra falsa maestria', () {
      final wrongWithConfidence = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.B,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 70,
      );
      final evidence = _truthEngine.evaluateMarker(wrongWithConfidence, 'M1');
      final withTruth = _truthEngine.writeTruthToState(
        wrongWithConfidence,
        evidence,
      );

      expect(wrongWithConfidence.attempts.single.correct, isFalse);
      expect(wrongWithConfidence.attempts.single.sinal, DecisionSignal.one);
      expect(evidence.status, MasteryStatus.falseMastery);
      expect(evidence.needsReview, isTrue);
      expect(evidence.needsReinforcement, isTrue);
      expect(withTruth.truth.falseMasteryFlags, contains('M1'));
      expect(withTruth.progress?.itemIdx, 0);
      expect(withTruth.progress?.concluidos, isNot(contains('M1')));
      expect(
        wrongWithConfidence.events.last.payload['reason'],
        'L1 precisa de intermediacao -> propor L2',
      );
    });

    test('A5.8 erro repetido registra fragilidade', () {
      final repeatedFailures = _state(
        itemIdx: 0,
        layer: LessonLayer.l2,
        attempts: [
          _attempt(
            marker: 'M1',
            layer: LessonLayer.l2,
            letra: AnswerLetter.B,
            sinal: DecisionSignal.two,
            correct: false,
            ts: 80,
          ),
          _attempt(
            marker: 'M1',
            layer: LessonLayer.l2,
            letra: AnswerLetter.C,
            sinal: DecisionSignal.three,
            correct: false,
            ts: 81,
          ),
        ],
      );
      final evidence = _truthEngine.evaluateMarker(repeatedFailures, 'M1');
      final withTruth = _truthEngine.writeTruthToState(
        repeatedFailures,
        evidence,
      );
      final decision = decideNextActionFromState(repeatedFailures);

      expect(evidence.status, MasteryStatus.weak);
      expect(evidence.reason, 'erro repetido duas vezes');
      expect(evidence.consecutiveWrong, 2);
      expect(evidence.needsReinforcement, isTrue);
      expect(withTruth.truth.itemConsolidationStatus['M1'], 'weak');
      expect(decision.actionType, DecisionActionType.needsReinforcement);
      expect(decision.reason, 'L2 sem evidencia suficiente para propor L3');
    });

    test('A5.9 revisao pendente participa da decisao', () {
      final answeredOnce = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 90,
      );
      final evidence = _truthEngine.evaluateMarker(answeredOnce, 'M1');
      final withReview = _truthEngine.writeTruthToState(answeredOnce, evidence);
      final gate = _contract.evaluateAdvanceGate(
        evidence: const SimAnswerEvidence(
          marker: 'M1',
          layer: LessonLayer.l1,
          selectedAnswer: AnswerLetter.A,
          signal: DecisionSignal.one,
          correct: true,
          validatedBySoftware: true,
        ),
        masteryEvidence: evidence,
      );

      expect(evidence.status, MasteryStatus.learning);
      expect(evidence.needsReview, isTrue);
      expect(withReview.truth.needsRetestFlags, contains('M1'));
      expect(withReview.attempts.single.marker, 'M1');
      expect(gate.allowAdvance, isFalse);
      expect(gate.reason, 'dominio real ainda nao comprovado');

      final afterLayerMove = processAnswerWithEngine(
        withReview,
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.two,
          correctAnswer: AnswerLetter.A,
        ),
        now: 91,
      );

      expect(afterLayerMove.truth.needsRetestFlags, contains('M1'));
      expect(afterLayerMove.progress?.concluidos, isNot(contains('M1')));
    });

    test('A5.10 recuperacao pendente participa da decisao', () {
      final fragileL3 = processAnswerWithEngine(
        _state(layer: LessonLayer.l3),
        const AnswerContext(
          letra: AnswerLetter.B,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 100,
      );
      final evidence = _truthEngine.evaluateMarker(fragileL3, 'M1');
      final withRecovery = _truthEngine.writeTruthToState(fragileL3, evidence);

      expect(evidence.status, MasteryStatus.falseMastery);
      expect(evidence.needsReinforcement, isTrue);
      expect(withRecovery.truth.falseMasteryFlags, contains('M1'));
      expect(withRecovery.attempts.single.marker, 'M1');
      expect(withRecovery.attempts.single.correct, isFalse);
      expect(withRecovery.progress?.itemIdx, 0);
      expect(withRecovery.progress?.layer, LessonLayer.l3);
      expect(
        withRecovery.events.last.payload['decision'],
        'needsReinforcement',
      );
      expect(
        withRecovery.events.last.payload['reason'],
        'L3 sem evidencia suficiente para concluir item',
      );
    });

    test('A5.11 conquista so acontece com evidencia suficiente', () {
      final isolatedL3Correct = processAnswerWithEngine(
        _state(layer: LessonLayer.l3),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 110,
      );
      final isolatedEvidence = _truthEngine.evaluateMarker(
        isolatedL3Correct,
        'M1',
      );
      final rejectedGate = _contract.evaluateAdvanceGate(
        evidence: const SimAnswerEvidence(
          marker: 'M1',
          layer: LessonLayer.l3,
          selectedAnswer: AnswerLetter.A,
          signal: DecisionSignal.one,
          correct: true,
          validatedBySoftware: true,
        ),
        masteryEvidence: isolatedEvidence,
        aiDecision: const {'markMastery': true},
      );

      expect(isolatedL3Correct.progress?.concluidos, isEmpty);
      expect(isolatedEvidence.status, MasteryStatus.learning);
      expect(rejectedGate.allowAdvance, isFalse);

      final masteredEvidence = _truthEngine.evaluateMarker(
        _state(
          attempts: [
            _attempt(correct: true, ts: 111),
            _attempt(correct: true, ts: 112),
            _attempt(correct: true, ts: 113),
          ],
        ),
        'M1',
      );
      final acceptedGate = _contract.evaluateAdvanceGate(
        evidence: const SimAnswerEvidence(
          marker: 'M1',
          layer: LessonLayer.l3,
          selectedAnswer: AnswerLetter.A,
          signal: DecisionSignal.one,
          correct: true,
          validatedBySoftware: true,
        ),
        masteryEvidence: masteredEvidence,
        aiDecision: const {'markMastery': false},
      );
      final aiOnlyGate = _contract.evaluateAdvanceGate(
        evidence: null,
        masteryEvidence: masteredEvidence,
        aiDecision: const {'markMastery': true},
      );

      expect(masteredEvidence.status, MasteryStatus.mastered);
      expect(acceptedGate.allowAdvance, isTrue);
      expect(acceptedGate.reason, 'software validou evidencia e dominio');
      expect(aiOnlyGate.allowAdvance, isFalse);
    });

    test('A5.12 decisao final deixa rastro auditavel completo', () {
      final blocked = processAnswerWithEngine(
        _state(layer: LessonLayer.l3),
        const AnswerContext(
          letra: AnswerLetter.C,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 120,
      );
      final blockEvent = blocked.events.lastWhere(
        (event) => event.type == 'STUDENT_DECISION_APPLIED',
      );

      expect(blockEvent.payload['marker'], 'M1');
      expect(blockEvent.payload['fromLayer'], 3);
      expect(blockEvent.payload['letra'], 'C');
      expect(blockEvent.payload['sinal'], 1);
      expect(blockEvent.payload['correct'], isFalse);
      expect(blockEvent.payload['decision'], 'needsReinforcement');
      expect(
        blockEvent.payload['reason'],
        'L3 sem evidencia suficiente para concluir item',
      );
      expect(blockEvent.payload['advanced'], isFalse);
      expect(blockEvent.payload['review'], isTrue);
      expect(blockEvent.payload['recovery'], isTrue);
      expect(blockEvent.payload['blocked'], isTrue);

      final advanced = processAnswerWithEngine(
        _state(layer: LessonLayer.l3),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 121,
      );
      final advanceEvent = advanced.events.lastWhere(
        (event) => event.type == 'STUDENT_DECISION_APPLIED',
      );

      expect(advanceEvent.payload['marker'], 'M1');
      expect(advanceEvent.payload['letra'], 'A');
      expect(advanceEvent.payload['correct'], isTrue);
      expect(advanceEvent.payload['decision'], 'advanceItem');
      expect(advanceEvent.payload['advanced'], isTrue);
      expect(advanceEvent.payload['review'], isTrue);
      expect(advanceEvent.payload['recovery'], isFalse);
      expect(advanceEvent.payload['blocked'], isFalse);
    });
  });
}
