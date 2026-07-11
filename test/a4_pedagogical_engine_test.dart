import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/constitution/sim_constitutional_contract.dart';
import 'package:sim_mobile/sim/state/learning_decision_engine.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_lesson_executor.dart';

const _items = [
  CurriculumItem(marker: 'M1', text: 'Metade'),
  CurriculumItem(marker: 'M2', text: 'Comparar'),
];
const _contract = SimConstitutionalContract();

StudentLearningState _state({
  String lessonLocalId = 'a4-lesson',
  int itemIdx = 0,
  LessonLayer layer = LessonLayer.l1,
  List<LessonAttempt> attempts = const [],
  List<String> concluidos = const [],
  Map<String, JsonMap> readyLessonMaterials = const {},
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
    readyLessonMaterials: readyLessonMaterials,
  );
}

void main() {
  group('A4 - Motor Pedagogico Principal', () {
    test('A4.1 microitem usa marker estavel em reload, tentativa e avanco', () {
      final answered = processAnswerWithEngine(
        _state(
          readyLessonMaterials: const {
            '0:M1:L1': {'marker': 'M1', 'explanation': 'Material M1'},
            '1:M2:L1': {'marker': 'M2', 'explanation': 'Material M2'},
          },
        ),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 10,
      );

      final reloaded = StudentLearningState.fromJson(answered.toJson());
      final decisionEvent = reloaded.events.lastWhere(
        (event) => event.type == 'STUDENT_DECISION_APPLIED',
      );

      expect(reloaded.curriculum?.items[0].marker, 'M1');
      expect(reloaded.current?.marker, 'M1');
      expect(reloaded.attempts.single.marker, 'M1');
      expect(decisionEvent.payload['fromItemIdx'], 0);
      expect(decisionEvent.payload['fromLayer'], 1);
      expect(reloaded.readyLessonMaterials['0:M1:L1']?['marker'], 'M1');
      expect(reloaded.readyLessonMaterials['1:M2:L1']?['marker'], 'M2');
      expect(
        reloaded.readyLessonMaterials['0:M1:L1']?['explanation'],
        'Material M1',
      );
    });

    test('A4.2 camadas L1, L2 e L3 existem, operam e restauram', () {
      final l1 = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.two,
          correctAnswer: AnswerLetter.A,
        ),
        now: 20,
      );
      final l2 = processAnswerWithEngine(
        _state(layer: LessonLayer.l2),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.two,
          correctAnswer: AnswerLetter.A,
        ),
        now: 21,
      );
      final l3 = processAnswerWithEngine(
        _state(layer: LessonLayer.l3),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 22,
      );

      expect(l1.attempts.single.layer, LessonLayer.l1);
      expect(l1.progress?.layer, LessonLayer.l2);
      expect(l2.attempts.single.layer, LessonLayer.l2);
      expect(l2.progress?.layer, LessonLayer.l3);
      expect(l3.attempts.single.layer, LessonLayer.l3);
      expect(l3.current?.itemIdx, 1);
      expect(
        StudentLearningState.fromJson(l2.toJson()).current?.layer,
        LessonLayer.l3,
      );
    });

    test('A4.3 resposta principal aceita apenas A/B/C e grava contexto', () {
      expect(_contract.validateAnswerLetter('A'), AnswerLetter.A);
      expect(_contract.validateAnswerLetter('B'), AnswerLetter.B);
      expect(_contract.validateAnswerLetter('C'), AnswerLetter.C);
      expect(
        () => _contract.validateAnswerLetter('D'),
        throwsA(isA<SimConstitutionViolation>()),
      );

      final answered = processAnswerWithEngine(
        _state(layer: LessonLayer.l2),
        const AnswerContext(
          letra: AnswerLetter.B,
          sinal: DecisionSignal.two,
          correctAnswer: AnswerLetter.A,
        ),
        now: 30,
      );
      final attempt = answered.attempts.single;

      expect(attempt.letra, AnswerLetter.B);
      expect(attempt.marker, 'M1');
      expect(attempt.layer, LessonLayer.l2);
    });

    test('A4.4 sinal 1/2/3 e validado, salvo e participa da decisao', () {
      expect(_contract.validateDecisionSignal(1), DecisionSignal.one);
      expect(_contract.validateDecisionSignal(2), DecisionSignal.two);
      expect(_contract.validateDecisionSignal(3), DecisionSignal.three);
      expect(
        () => _contract.validateDecisionSignal(4),
        throwsA(isA<SimConstitutionViolation>()),
      );

      final strong = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 40,
      );
      final fragile = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.three,
          correctAnswer: AnswerLetter.A,
        ),
        now: 41,
      );

      expect(strong.attempts.single.sinal, DecisionSignal.one);
      expect(fragile.attempts.single.sinal, DecisionSignal.three);
      expect(strong.progress?.layer, LessonLayer.l3);
      expect(fragile.progress?.layer, LessonLayer.l2);
    });

    test('A4.5 tentativa completa exige marker, layer, letra, sinal e ts', () {
      final answered = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.C,
          sinal: DecisionSignal.three,
          correctAnswer: AnswerLetter.A,
        ),
        now: 50,
      );
      final attempt = answered.attempts.single;

      expect(_contract.validateAttempt(attempt), same(attempt));
      expect(attempt.toJson(), containsPair('marker', 'M1'));
      expect(attempt.toJson(), containsPair('layer', 1));
      expect(attempt.toJson(), containsPair('letra', 'C'));
      expect(attempt.toJson(), containsPair('sinal', 3));
      expect(attempt.toJson(), containsPair('correct', false));
      expect(attempt.toJson(), containsPair('ts', 50));
      expect(
        () => _contract.validateAttempt(
          const LessonAttempt(
            marker: '',
            layer: LessonLayer.l1,
            letra: AnswerLetter.A,
            sinal: DecisionSignal.one,
            correct: true,
            ts: 50,
          ),
        ),
        throwsA(isA<SimConstitutionViolation>()),
      );
      expect(
        () => _contract.validateAttempt(
          const LessonAttempt(
            marker: 'M1',
            layer: LessonLayer.l1,
            letra: AnswerLetter.A,
            sinal: DecisionSignal.one,
            correct: true,
            ts: 0,
          ),
        ),
        throwsA(isA<SimConstitutionViolation>()),
      );
    });

    test('A4.6 software compara resposta com gabarito e grava correct', () {
      final correct = processAnswerWithEngine(
        _state(),
        const AnswerContext(
          letra: AnswerLetter.B,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.B,
        ),
        now: 60,
      );
      final wrong = processAnswerWithEngine(
        _state(),
        const AnswerContext(
          letra: AnswerLetter.C,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.B,
        ),
        now: 61,
      );

      expect(correct.attempts.single.correct, true);
      expect(wrong.attempts.single.correct, false);
      expect(
        _contract
            .validateEvidence(
              const SimAnswerEvidence(
                marker: 'M1',
                layer: LessonLayer.l1,
                selectedAnswer: AnswerLetter.B,
                signal: DecisionSignal.one,
                correct: true,
                validatedBySoftware: true,
              ),
            )
            .validatedBySoftware,
        true,
      );
      expect(
        () => _contract.validateEvidence(
          const SimAnswerEvidence(
            marker: 'M1',
            layer: LessonLayer.l1,
            selectedAnswer: AnswerLetter.B,
            signal: DecisionSignal.one,
            correct: true,
            validatedBySoftware: false,
          ),
        ),
        throwsA(isA<SimConstitutionViolation>()),
      );
    });

    test('A4.7 decisao pedagogica fica auditavel por evento', () {
      expect(
        DecisionActionType.values,
        containsAll([
          DecisionActionType.showCurrentLesson,
          DecisionActionType.advanceLayer,
          DecisionActionType.advanceItem,
          DecisionActionType.needsReinforcement,
          DecisionActionType.noSafeDecision,
        ]),
      );

      final answered = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.C,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 70,
      );
      final decisionEvent = answered.events.lastWhere(
        (event) => event.type == 'STUDENT_DECISION_APPLIED',
      );

      expect(decisionEvent.payload['decision'], 'advanceLayer');
      expect(decisionEvent.payload['reason'], isA<String>());
      expect(decisionEvent.payload['reason'], contains('L1'));
      expect(decisionEvent.payload['fromItemIdx'], 0);
      expect(decisionEvent.payload['fromLayer'], 1);
      expect(decisionEvent.payload['toItemIdx'], 0);
      expect(decisionEvent.payload['toLayer'], 2);
      expect(decisionEvent.payload['correct'], false);
      expect(decisionEvent.payload['sinal'], 1);
    });

    test('A4.8 acerto seguro na L1 aplica regra oficial sem IA', () {
      final answered = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 80,
      );
      final attempt = answered.attempts.single;
      final decisionEvent = answered.events.lastWhere(
        (event) => event.type == 'STUDENT_DECISION_APPLIED',
      );

      expect(attempt.marker, 'M1');
      expect(attempt.layer, LessonLayer.l1);
      expect(attempt.correct, true);
      expect(attempt.sinal, DecisionSignal.one);
      expect(answered.current?.itemIdx, 0);
      expect(answered.progress?.layer, LessonLayer.l3);
      expect(
        decisionEvent.payload['reason'],
        'L1 dominada com certeza -> propor L3',
      );
    });

    test('A4.9 erro ou baixa confianca na L1 leva para L2 sem pular item', () {
      final wrong = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.B,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 90,
      );
      final lowConfidence = processAnswerWithEngine(
        _state(layer: LessonLayer.l1),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.three,
          correctAnswer: AnswerLetter.A,
        ),
        now: 91,
      );
      final wrongDecision = wrong.events.lastWhere(
        (event) => event.type == 'STUDENT_DECISION_APPLIED',
      );

      expect(wrong.current?.marker, 'M1');
      expect(wrong.progress?.layer, LessonLayer.l2);
      expect(
        wrongDecision.payload['reason'],
        'L1 precisa de intermediacao -> propor L2',
      );
      expect(lowConfidence.current?.marker, 'M1');
      expect(lowConfidence.progress?.layer, LessonLayer.l2);
      expect(lowConfidence.attempts.single.sinal, DecisionSignal.three);
    });

    test('A4.10 L2 consolidada registra tentativa e leva para L3', () {
      final answered = processAnswerWithEngine(
        _state(layer: LessonLayer.l2),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.two,
          correctAnswer: AnswerLetter.A,
        ),
        now: 100,
      );
      final decisionEvent = answered.events.lastWhere(
        (event) => event.type == 'STUDENT_DECISION_APPLIED',
      );

      expect(answered.attempts.single.layer, LessonLayer.l2);
      expect(answered.attempts.single.correct, true);
      expect(answered.current?.itemIdx, 0);
      expect(answered.current?.marker, 'M1');
      expect(answered.progress?.layer, LessonLayer.l3);
      expect(decisionEvent.payload['decision'], 'advanceLayer');
      expect(decisionEvent.payload['reason'], 'L2 encerrada -> propor L3');
    });

    test('A4.11 L3 consolidada avanca para o proximo item em L1', () {
      final answered = processAnswerWithEngine(
        _state(layer: LessonLayer.l3),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 110,
      );
      final decisionEvent = answered.events.lastWhere(
        (event) => event.type == 'STUDENT_DECISION_APPLIED',
      );

      expect(answered.attempts.single.marker, 'M1');
      expect(answered.attempts.single.layer, LessonLayer.l3);
      expect(answered.progress?.concluidos, isNot(contains('M1')));
      expect(answered.current?.itemIdx, 1);
      expect(answered.current?.marker, 'M2');
      expect(answered.current?.layer, LessonLayer.l1);
      expect(decisionEvent.payload['decision'], 'advanceItem');
      expect(decisionEvent.payload['reason'], 'L3 encerrada -> proximo item');
    });

    test(
      'A4.12 L3 avanca para o proximo item e deixa reparo para auxiliares',
      () {
        final wrong = processAnswerWithEngine(
          _state(layer: LessonLayer.l3),
          const AnswerContext(
            letra: AnswerLetter.B,
            sinal: DecisionSignal.one,
            correctAnswer: AnswerLetter.A,
          ),
          now: 120,
        );
        final fragileCorrect = processAnswerWithEngine(
          _state(layer: LessonLayer.l3),
          const AnswerContext(
            letra: AnswerLetter.A,
            sinal: DecisionSignal.three,
            correctAnswer: AnswerLetter.A,
          ),
          now: 121,
        );
        final wrongDecision = wrong.events.lastWhere(
          (event) => event.type == 'STUDENT_DECISION_APPLIED',
        );
        final fragileDecision = fragileCorrect.events.lastWhere(
          (event) => event.type == 'STUDENT_DECISION_APPLIED',
        );

        expect(wrong.attempts.single.correct, false);
        expect(wrong.current?.marker, 'M2');
        expect(wrong.current?.layer, LessonLayer.l1);
        expect(wrongDecision.payload['decision'], 'advanceItem');
        expect(wrongDecision.payload['reason'], 'L3 encerrada -> proximo item');
        expect(fragileCorrect.attempts.single.sinal, DecisionSignal.three);
        expect(fragileCorrect.current?.marker, 'M2');
        expect(fragileCorrect.current?.layer, LessonLayer.l1);
        expect(fragileDecision.payload['decision'], 'advanceItem');
      },
    );
  });
}
