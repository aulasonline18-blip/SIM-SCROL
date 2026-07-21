import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  test('StudentLearningState deve preservar comportamento atual', () {
    final state = StudentLearningState.empty(
      lessonLocalId: 'lesson-contract',
      userId: 'student-1',
      now: 1000,
    ).copyWith(
      lessonCloudId: 'cloud-1',
      updatedAt: 2000,
      profile: const StudentProfile(
        preferredName: 'Ana',
        language: 'pt-BR',
        stableLang: 'Portuguese',
        objetivo: 'Frações',
        nivel: 'Ensino fundamental',
        academicLevel: '6 ano',
        targetTopic: 'Frações equivalentes',
        sessionGoal: 'Prova escolar',
        extra: {'attentionProfile': 'curto'},
      ),
      curriculum: StudentCurriculum(
        topic: 'Frações',
        totalItems: 2,
        generatedAt: 1500,
        provisional: false,
        items: const [
          CurriculumItem(marker: 'M1', text: 'Frações equivalentes'),
          CurriculumItem(marker: 'M2', text: 'Comparação de frações'),
        ],
        globalPlan: const CurriculumGlobalPlan(
          globalTotalItems: 4,
          batchStartItem: 1,
          batchEndItem: 2,
          nextGlobalItemToRequest: 3,
        ),
      ),
      current: const LessonCurrent(
        itemIdx: 1,
        marker: 'M2',
        layer: LessonLayer.l2,
        amparoLvl: 0,
      ),
      progress: const LessonProgress(
        itemIdx: 1,
        layer: LessonLayer.l2,
        erros: 1,
        amparoLvl: 0,
        historia: ['M1'],
        mainAdvances: 2,
        concluidos: ['M1'],
        pendentesMarkers: ['M2'],
        totalItems: 2,
        pctAvanco: 50,
      ),
      attempts: const [
        LessonAttempt(
          marker: 'M1',
          layer: LessonLayer.l1,
          letra: AnswerLetter.A,
          sinal: DecisionSignal.two,
          correct: true,
          ts: 1800,
        ),
      ],
      events: const [
        StudentLearningEvent(
          type: 'ANSWER_RECORDED',
          ts: 1800,
          payload: {'marker': 'M1'},
        ),
      ],
      readyLessonMaterials: const {
        'M2:L2': {'question': 'Quanto vale 1/2?'},
      },
      queuedActions: const [
        {'type': 'PREPARE_READY_WINDOW', 'status': 'queued'},
      ],
      inflightJobs: const [
        {'type': 'T02', 'status': 'running'},
      ],
      syncStatus: const StudentSyncStatus(
        status: 'dirty',
        pendingJobs: 1,
        highWaterMark: 10,
        updatedAt: 2000,
      ),
      extra: const {'cacheInfo': 'legacy-cache-marker'},
    );

    final json = state.toJson();
    final restored = StudentLearningState.fromJson(json);

    expect(restored.toJson(), json);
    expect(restored.hasCurriculum, isTrue);
    expect(restored.profile.preferredName, 'Ana');
    expect(restored.curriculum?.displayTotalItems, 4);
    expect(restored.curriculum?.displayItemNumberForLocalIndex(1), 2);
    expect(restored.progress?.layer, LessonLayer.l2);
    expect(restored.events.single.type, 'ANSWER_RECORDED');
    expect(restored.syncStatus?.status, 'dirty');
    expect(restored.extra['cacheInfo'], 'legacy-cache-marker');
    expect(restored.snapshot.lessonLocalId, restored.lessonLocalId);
    expect(restored.snapshot.progress?.toJson(), restored.progress?.toJson());
    expect(restored.eventLog.getRecent(1).single.type, 'ANSWER_RECORDED');
    expect(restored.syncState.highWaterMark, 10);
    expect(restored.cacheInfo.readyLessonIds, ['M2:L2']);
    expect(restored.cacheInfo.readyCount, 1);
  });
}
