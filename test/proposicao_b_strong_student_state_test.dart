import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/cloud/cloud_functions.dart';
import 'package:sim_mobile/sim/cloud/cloud_queue.dart';
import 'package:sim_mobile/sim/cloud/supabase_client_contract.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

void main() {
  test('B local vazio nao apaga estado local rico ja salvo', () {
    final store = StudentStateStore(
      local: MemoryStudentStateLocalStorage(),
      now: () => 100,
    );
    store.writeState(_state(itemIdx: 2, layer: LessonLayer.l3, advances: 2));

    final protected = store.writeState(
      StudentLearningState.empty(lessonLocalId: 'lesson-b', now: 1),
    );

    expect(protected.progress?.itemIdx, 2);
    expect(protected.currentLessonMaterial?['source'], 'server');
    expect(protected.readyLessonMaterials, contains('slot-shared'));
    expect(protected.truth.masteryEvidence, isNotEmpty);
  });

  test('B backup antigo nao rebaixa snapshot rico existente', () {
    final store = StudentStateStore(
      local: MemoryStudentStateLocalStorage(),
      now: () => 200,
    );
    final rich = _state(itemIdx: 2, layer: LessonLayer.l3, advances: 2);
    final old = _state(itemIdx: 0, layer: LessonLayer.l1, advances: 0).copyWith(
      updatedAt: 1,
      attempts: const [],
      events: const [],
      currentLessonMaterial: const {'source': 'old-backup'},
      readyLessonMaterials: const {},
    );
    store.writeState(rich);

    final imported = store.importBackup({
      'kind': 'sim-student-learning-backup',
      'schema_version': studentLearningStateSchemaVersion,
      'state': old.toJson(),
      'events': const [],
    });

    expect(imported.progress?.itemIdx, 2);
    expect(imported.progress?.layer, LessonLayer.l3);
    expect(imported.currentLessonMaterial?['source'], 'server');
    expect(imported.readyLessonMaterials, contains('slot-shared'));
  });

  test(
    'B merge comum preserva riqueza e material remoto vence cache local',
    () {
      final local = _state(itemIdx: 2, layer: LessonLayer.l2, advances: 2)
          .copyWith(
            currentLessonMaterial: const {'source': 'cache-local'},
            readyLessonMaterials: const {
              'slot-shared': {'source': 'cache-local'},
              'slot-local': {'source': 'cache-local'},
            },
          );
      final remote = _state(itemIdx: 1, layer: LessonLayer.l3, advances: 1)
          .copyWith(
            currentLessonMaterial: const {'source': 'server'},
            readyLessonMaterials: const {
              'slot-shared': {'source': 'server'},
              'slot-remote': {'source': 'server'},
            },
          );

      final merged = mergeStudentLearningStateFromCloud(local, remote);

      expect(merged.currentLessonMaterial?['source'], 'server');
      expect(merged.readyLessonMaterials['slot-shared']?['source'], 'server');
      expect(merged.readyLessonMaterials, contains('slot-local'));
      expect(merged.readyLessonMaterials, contains('slot-remote'));
    },
  );

  test(
    'B 409 restaura remoteState como base e nao deixa local atrasado mandar',
    () async {
      const localAttempt = LessonAttempt(
        marker: 'M3',
        layer: LessonLayer.l1,
        letra: AnswerLetter.A,
        sinal: DecisionSignal.one,
        correct: false,
        ts: 30,
      );
      final local = _state(itemIdx: 3, layer: LessonLayer.l1, advances: 3)
          .copyWith(
            attempts: const [localAttempt],
            currentLessonMaterial: const {'source': 'cache-local'},
            readyLessonMaterials: const {
              'slot-shared': {'source': 'cache-local'},
            },
          );
      final remote = _state(itemIdx: 1, layer: LessonLayer.l3, advances: 1)
          .copyWith(
            attempts: const [],
            currentLessonMaterial: const {'source': 'server'},
            readyLessonMaterials: const {
              'slot-shared': {'source': 'server'},
            },
          );
      final states = StudentLearningStateService(seed: {'lesson-b': local});
      final queue = CloudQueue(
        storage: MemoryCloudQueueStorage(),
        stateService: states,
        sessionProvider: _Session(),
        cloudFunctions: _RejectingCloud(remote),
        now: () => 1000,
      );

      queue.enqueueStudentStateSync(lessonLocalId: 'lesson-b');
      await queue.drainQueue();

      final restored = states.read('lesson-b')!;
      expect(restored.progress?.itemIdx, 1);
      expect(restored.progress?.layer, LessonLayer.l3);
      expect(restored.currentLessonMaterial?['source'], 'server');
      expect(restored.readyLessonMaterials['slot-shared']?['source'], 'server');
      expect(
        restored.attempts.map((attempt) => attempt.marker),
        contains('M3'),
      );
      expect(queue.getQueueSnapshot(), contains('lesson-b'));
    },
  );

  test(
    'B merge preserva eventos com mesmo tipo e ts mas payload diferente',
    () {
      final local = _state(itemIdx: 2, layer: LessonLayer.l2, advances: 2)
          .copyWith(
            events: const [
              StudentLearningEvent(
                type: 'ANSWER_SUBMITTED',
                ts: 10,
                payload: {'marker': 'M2', 'source': 'local'},
              ),
            ],
          );
      final remote = _state(itemIdx: 2, layer: LessonLayer.l2, advances: 2)
          .copyWith(
            events: const [
              StudentLearningEvent(
                type: 'ANSWER_SUBMITTED',
                ts: 10,
                payload: {'marker': 'M1', 'source': 'remote'},
              ),
            ],
          );

      final merged = mergeStudentLearningStateFromServerAuthority(
        local,
        remote,
      );

      expect(merged.events, hasLength(2));
      expect(
        merged.events.map((event) => event.payload['source']),
        containsAll(['local', 'remote']),
      );
    },
  );
}

StudentLearningState _state({
  required int itemIdx,
  required LessonLayer layer,
  required int advances,
}) {
  final marker = 'M$itemIdx';
  return StudentLearningState.empty(
    lessonLocalId: 'lesson-b',
    userId: 'user-b',
    now: 10 + advances,
  ).copyWith(
    updatedAt: 10 + advances,
    profile: const StudentProfile(objetivo: 'Matematica', stableLang: 'pt-BR'),
    curriculum: const StudentCurriculum(
      topic: 'Matematica',
      totalItems: 4,
      generatedAt: 1,
      provisional: false,
      items: [
        CurriculumItem(marker: 'M0', text: 'Zero'),
        CurriculumItem(marker: 'M1', text: 'Um'),
        CurriculumItem(marker: 'M2', text: 'Dois'),
        CurriculumItem(marker: 'M3', text: 'Tres'),
      ],
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
      historia: const ['M0'],
      mainAdvances: advances,
      concluidos: advances > 0 ? const ['M0'] : const [],
      pendentesMarkers: const ['M2'],
      totalItems: 4,
      pctAvanco: advances * 25,
    ),
    events: [
      StudentLearningEvent(
        type: 'ANSWER_SUBMITTED',
        ts: 10 + advances,
        payload: {'marker': marker},
      ),
    ],
    currentLessonMaterial: const {'source': 'server'},
    readyLessonMaterials: const {
      'slot-shared': {'source': 'server'},
    },
    truth: const StudentMasteryTruth(
      itemConsolidationStatus: {'M0': 'conquered'},
      masteryEvidence: [
        {'marker': 'M0', 'status': 'conquered'},
      ],
      weaknessRecords: [
        {'marker': 'M2', 'reason': 'low_confidence'},
      ],
      conquestRecords: [
        {'marker': 'M0', 'status': 'conquered'},
      ],
    ),
  );
}

class _Session implements SupabaseSessionProvider {
  @override
  Future<SupabaseSession?> currentSession() async =>
      const SupabaseSession(accessToken: 'token', userId: 'user-b');
}

class _RejectingCloud implements StudentStateCloudFunctions {
  _RejectingCloud(this.remoteState);

  final StudentLearningState remoteState;

  @override
  Future<void> deleteStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async {}

  @override
  Future<StudentStateRow?> getStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async => StudentStateRow(
    lessonLocalId: lessonLocalId,
    state: remoteState,
    highWaterMark: scoreOfStudentLearningState(remoteState),
    schemaVersion: studentLearningStateSchemaVersion,
  );

  @override
  Future<List<StudentStateRow>> listStudentStates(
    SupabaseSession session,
  ) async => const [];

  @override
  Future<List<StudentStateSummaryRow>> listStudentStateSummaries(
    SupabaseSession session,
  ) async => const [];

  @override
  Future<PersistStudentStateResult> persistStudentState(
    PersistStudentStateInput input,
    SupabaseSession session,
  ) async => PersistStudentStateResult.rejectedRegression(
    remoteState: remoteState,
    remoteHighWaterMark: scoreOfStudentLearningState(remoteState),
  );
}
