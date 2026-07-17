import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/state/student_learning_governor.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

StudentLearningState _seedState() {
  const items = [
    CurriculumItem(marker: 'M1', text: 'Fracoes equivalentes'),
    CurriculumItem(marker: 'M2', text: 'Comparar fracoes'),
  ];
  return StudentLearningState.empty(lessonLocalId: 'lesson-1', now: 1).copyWith(
    curriculum: const StudentCurriculum(
      topic: 'Fracoes',
      totalItems: 2,
      generatedAt: 1,
      provisional: false,
      items: items,
    ),
    current: const LessonCurrent(
      itemIdx: 0,
      marker: 'M1',
      layer: LessonLayer.l1,
      amparoLvl: 0,
    ),
    progress: const LessonProgress(
      itemIdx: 0,
      layer: LessonLayer.l1,
      erros: 0,
      amparoLvl: 0,
      historia: [],
      mainAdvances: 0,
      concluidos: [],
      pendentesMarkers: [],
      totalItems: 2,
      pctAvanco: 0,
    ),
  );
}

void main() {
  test(
    'StudentLearningGovernor decide A/B/C+sinal localmente sem servidor',
    () {
      final store = StudentStateStore(local: MemoryStudentStateLocalStorage());
      store.writeState(_seedState());
      final governor = StudentLearningGovernor(store: store);

      final result = governor.submitAnswer(
        lessonLocalId: 'lesson-1',
        selected: AnswerLetter.A,
        correctAnswer: AnswerLetter.A,
        signal: DecisionSignal.one,
      );

      final state = store.readState('lesson-1');
      expect(result.state.lessonLocalId, 'lesson-1');
      expect(result.answerEvent.source, 'student-learning-governor');
      expect(result.masteryEvent.type, 'MASTERY_EVIDENCE_EVALUATED');
      expect(result.decisionEvent.type, 'LOCAL_ADVANCE_DECIDED');
      expect(result.nextAction.reason, isNot(contains('servidor')));
      expect(state.attempts, hasLength(1));
      expect(state.attempts.single.marker, 'M1');
      expect(state.attempts.single.correct, isTrue);
      expect(state.truth.masteryEvidence.single['marker_id'], 'M1');
      expect(
        state.truth.itemConsolidationStatus['M1'],
        result.mastery.status.name,
      );
      expect(state.progress?.itemIdx, 0);
      expect(state.progress?.layer, LessonLayer.l3);
      expect(
        store.getEventLog('lesson-1').map((event) => event.type),
        containsAll([
          'ANSWER_SUBMITTED',
          'MASTERY_EVIDENCE_EVALUATED',
          'LOCAL_ADVANCE_DECIDED',
        ]),
      );
    },
  );
}
