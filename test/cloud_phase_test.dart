import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/cloud/cloud_functions.dart';
import 'package:sim_mobile/sim/cloud/cloud_queue.dart';
import 'package:sim_mobile/sim/cloud/lesson_cloud_bootstrap.dart';
import 'package:sim_mobile/sim/cloud/lesson_curriculum_sync_engine.dart';
import 'package:sim_mobile/sim/cloud/student_learning_sync.dart';
import 'package:sim_mobile/sim/cloud/student_remote_vault_sync_engine.dart';
import 'package:sim_mobile/sim/cloud/supabase_student_state_cloud_storage.dart';
import 'package:sim_mobile/sim/cloud/student_lesson_cloud_progress_service.dart';
import 'package:sim_mobile/sim/cloud/student_lesson_progress_service.dart';
import 'package:sim_mobile/sim/cloud/supabase_client_contract.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';
import 'package:sim_mobile/sim/state/student_state_store_adapter.dart';

class FakeSessionProvider implements SupabaseSessionProvider {
  SupabaseSession? session = const SupabaseSession(
    accessToken: 'token',
    userId: 'u1',
  );

  @override
  Future<SupabaseSession?> currentSession() async => session;
}

class FakeCloudFunctions implements StudentStateCloudFunctions {
  int persistCalls = 0;
  int deleteCalls = 0;
  PersistStudentStateResult? nextPersist;
  Object? nextError;
  final states = <String, StudentLearningState>{};

  @override
  Future<void> deleteStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async {
    deleteCalls += 1;
  }

  StudentLearningState? remoteState;
  SupabaseSession? lastSession;
  PersistStudentStateInput? lastPersistInput;

  @override
  Future<StudentStateRow?> getStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async {
    lastSession = session;
    final state = remoteState ?? states[lessonLocalId];
    if (state == null || state.lessonLocalId != lessonLocalId) return null;
    return StudentStateRow(
      lessonLocalId: lessonLocalId,
      state: state,
      highWaterMark: scoreOfStudentLearningState(state),
      schemaVersion: studentLearningStateSchemaVersion,
    );
  }

  @override
  Future<List<StudentStateRow>> listStudentStates(
    SupabaseSession session,
  ) async {
    return const [];
  }

  @override
  Future<List<StudentStateSummaryRow>> listStudentStateSummaries(
    SupabaseSession session,
  ) async {
    return const [];
  }

  @override
  Future<PersistStudentStateResult> persistStudentState(
    PersistStudentStateInput input,
    SupabaseSession session,
  ) async {
    persistCalls += 1;
    lastSession = session;
    lastPersistInput = input;
    final error = nextError;
    nextError = null;
    if (error != null) throw error;
    final next = nextPersist;
    nextPersist = null;
    if (next != null) return next;
    states[input.lessonLocalId] = input.state;
    return PersistStudentStateResult.accepted(
      lessonLocalId: input.lessonLocalId,
      highWaterMark: input.clientScore,
      schemaVersion: input.schemaVersion,
    );
  }
}

StudentLearningState stateWithProgress({
  required String id,
  required int itemIdx,
  required LessonLayer layer,
  required int mainAdvances,
}) {
  return StudentLearningState.empty(lessonLocalId: id, now: 1).copyWith(
    updatedAt: 1,
    profile: const StudentProfile(objetivo: 'Matematica', stableLang: 'pt-BR'),
    curriculum: StudentCurriculum(
      topic: 'Matematica',
      totalItems: 3,
      generatedAt: 1,
      provisional: false,
      items: const [
        CurriculumItem(marker: 'M1', text: 'Item 1'),
        CurriculumItem(marker: 'M2', text: 'Item 2'),
        CurriculumItem(marker: 'M3', text: 'Item 3'),
      ],
    ),
    current: LessonCurrent(
      itemIdx: itemIdx,
      marker: 'M$itemIdx',
      layer: layer,
      amparoLvl: 0,
    ),
    progress: LessonProgress(
      itemIdx: itemIdx,
      layer: layer,
      erros: 0,
      amparoLvl: 0,
      historia: const [],
      mainAdvances: mainAdvances,
      concluidos: const [],
      pendentesMarkers: const [],
      totalItems: 3,
      pctAvanco: 0,
    ),
  );
}

void main() {
  test(
    'supabase cloud storage only loads through authenticated session',
    () async {
      final cloud = FakeCloudFunctions()
        ..remoteState = stateWithProgress(
          id: 'l1',
          itemIdx: 2,
          layer: LessonLayer.l3,
          mainAdvances: 2,
        );
      final sessionProvider = FakeSessionProvider();
      final storage = SupabaseStudentStateCloudStorage(
        cloudFunctions: cloud,
        sessionProvider: sessionProvider,
      );

      final loaded = await storage.loadCloud('l1');
      expect(loaded?.progress?.itemIdx, 2);
      expect(cloud.lastSession?.userId, 'u1');
    },
  );

  test(
    'supabase cloud storage is inert without authenticated session',
    () async {
      final cloud = FakeCloudFunctions();
      final sessionProvider = FakeSessionProvider()..session = null;
      final storage = SupabaseStudentStateCloudStorage(
        cloudFunctions: cloud,
        sessionProvider: sessionProvider,
      );

      expect(await storage.loadCloud('l1'), isNull);
      expect(cloud.persistCalls, 0);
    },
  );

  test('StudentLearningState serializes full snapshot for cloud sync', () {
    final state = stateWithProgress(
      id: 'l1',
      itemIdx: 1,
      layer: LessonLayer.l2,
      mainAdvances: 1,
    ).copyWith(auxRooms: {'pendingMap': []});

    final restored = StudentLearningState.fromJson(state.toJson());
    expect(restored.lessonLocalId, 'l1');
    expect(restored.progress?.layer, LessonLayer.l2);
    expect(restored.auxRooms?['pendingMap'], isA<List>());
  });

  test(
    'cloud queue persists patch and removes it after successful drain',
    () async {
      final states = StudentLearningStateService(
        seed: {
          'l1': stateWithProgress(
            id: 'l1',
            itemIdx: 1,
            layer: LessonLayer.l1,
            mainAdvances: 1,
          ),
        },
      );
      final cloud = FakeCloudFunctions();
      final queue = CloudQueue(
        storage: MemoryCloudQueueStorage(),
        stateService: states,
        sessionProvider: FakeSessionProvider(),
        cloudFunctions: cloud,
        now: () => 1000,
      );

      queue.enqueueStudentStateSync(lessonLocalId: 'l1');
      expect(queue.getQueueSnapshot(), contains('l1'));
      await queue.drainQueue();
      expect(cloud.persistCalls, 1);
      expect(queue.getQueueSnapshot(), isEmpty);
      expect(
        states.read('l1')?.events.map((event) => event.type),
        contains('REMOTE_VAULT_SYNC_CONFIRMED'),
      );
    },
  );

  test(
    'cloud queue keeps durable pending item and records error when server fails',
    () async {
      final states = StudentLearningStateService(
        seed: {
          'l1': stateWithProgress(
            id: 'l1',
            itemIdx: 1,
            layer: LessonLayer.l2,
            mainAdvances: 1,
          ),
        },
      );
      final cloud = FakeCloudFunctions()..nextError = StateError('offline');
      final queue = CloudQueue(
        storage: MemoryCloudQueueStorage(),
        stateService: states,
        sessionProvider: FakeSessionProvider(),
        cloudFunctions: cloud,
        now: () => 1000,
      );

      queue.enqueueStudentStateSync(lessonLocalId: 'l1');
      await queue.drainQueue();

      expect(queue.getQueueSnapshot(), contains('l1'));
      expect(queue.getQueueSnapshot()['l1']?.attempts, 1);
      expect(states.read('l1')?.syncStatus?.status, 'failed');
      expect(
        states.read('l1')?.events.map((event) => event.type),
        contains('REMOTE_VAULT_SYNC_FAILED'),
      );
    },
  );

  test('cloud queue keeps pending item when auth session is missing', () async {
    final states = StudentLearningStateService(
      seed: {
        'l1': stateWithProgress(
          id: 'l1',
          itemIdx: 1,
          layer: LessonLayer.l1,
          mainAdvances: 1,
        ),
      },
    );
    final session = FakeSessionProvider()..session = null;
    final queue = CloudQueue(
      storage: MemoryCloudQueueStorage(),
      stateService: states,
      sessionProvider: session,
      cloudFunctions: FakeCloudFunctions(),
      now: () => 1000,
    );

    queue.enqueueStudentStateSync(lessonLocalId: 'l1');
    await queue.drainQueue();

    expect(queue.getQueueSnapshot(), contains('l1'));
    expect(states.read('l1')?.syncStatus?.status, 'blocked');
    expect(
      states.read('l1')?.events.map((event) => event.type),
      contains('REMOTE_VAULT_SYNC_BLOCKED'),
    );
  });

  test(
    'cloud queue merges remote state when server rejects regression',
    () async {
      final local = stateWithProgress(
        id: 'l1',
        itemIdx: 0,
        layer: LessonLayer.l1,
        mainAdvances: 0,
      );
      final remote = stateWithProgress(
        id: 'l1',
        itemIdx: 2,
        layer: LessonLayer.l3,
        mainAdvances: 2,
      );
      final states = StudentLearningStateService(seed: {'l1': local});
      final cloud = FakeCloudFunctions()
        ..nextPersist = PersistStudentStateResult.rejectedRegression(
          remoteState: remote,
          remoteHighWaterMark: 2003,
        );
      final queue = CloudQueue(
        storage: MemoryCloudQueueStorage(),
        stateService: states,
        sessionProvider: FakeSessionProvider(),
        cloudFunctions: cloud,
        now: () => 1000,
      );

      queue.enqueueStudentStateSync(lessonLocalId: 'l1');
      await queue.drainQueue();
      expect(states.read('l1')?.progress?.itemIdx, 2);
      expect(queue.getQueueSnapshot(), contains('l1'));
      expect(states.read('l1')?.syncStatus?.status, 'blocked_regression');
      expect(
        states.read('l1')?.events.map((event) => event.type),
        contains('REMOTE_VAULT_SYNC_REJECTED'),
      );
    },
  );

  test(
    'remote vault sync engine restores synced progress on another device',
    () async {
      final cloud = FakeCloudFunctions();
      final session = FakeSessionProvider();
      final deviceAState =
          stateWithProgress(
            id: 'lesson-multi',
            itemIdx: 14,
            layer: LessonLayer.l3,
            mainAdvances: 15,
          ).copyWith(
            attempts: const [
              LessonAttempt(
                marker: 'M15',
                layer: LessonLayer.l3,
                letra: AnswerLetter.A,
                sinal: DecisionSignal.one,
                correct: true,
                ts: 15,
              ),
            ],
          );
      final storeA = StudentStateStore(local: MemoryStudentStateLocalStorage())
        ..writeState(deviceAState);
      final deviceA = StudentStateStoreAdapter(storeA);
      final queue = CloudQueue(
        storage: MemoryCloudQueueStorage(),
        stateService: deviceA,
        sessionProvider: session,
        cloudFunctions: cloud,
        now: () => 1000,
      );
      final engineA = StudentRemoteVaultSyncEngine(
        store: storeA,
        sync: StudentLearningSync(queue),
      );

      engineA.enqueueState(
        lessonLocalId: 'lesson-multi',
        reason: 'device_a_progressed',
      );
      await engineA.drain();

      final storeB = StudentStateStore(
        local: MemoryStudentStateLocalStorage(),
        cloud: SupabaseStudentStateCloudStorage(
          cloudFunctions: cloud,
          sessionProvider: session,
        ),
      );
      final hydrated = await storeB.hydrateFromCloud('lesson-multi');

      expect(hydrated.progress?.itemIdx, 14);
      expect(hydrated.progress?.layer, LessonLayer.l3);
      expect(hydrated.progress?.mainAdvances, 15);
      expect(hydrated.attempts.single.marker, 'M15');
    },
  );

  test('progress service picks the most advanced progress', () {
    final saved = stateWithProgress(
      id: 'l1',
      itemIdx: 1,
      layer: LessonLayer.l1,
      mainAdvances: 1,
    ).progress;
    final official = stateWithProgress(
      id: 'l1',
      itemIdx: 2,
      layer: LessonLayer.l1,
      mainAdvances: 2,
    ).progress;

    expect(pickMostAdvancedLessonProgress(saved, official), official);
  });

  test('cloud progress publishes position and enqueues sync', () {
    final states = StudentLearningStateService(
      seed: {
        'l1': stateWithProgress(
          id: 'l1',
          itemIdx: 0,
          layer: LessonLayer.l1,
          mainAdvances: 0,
        ),
      },
    );
    final queue = CloudQueue(
      storage: MemoryCloudQueueStorage(),
      stateService: states,
      sessionProvider: FakeSessionProvider(),
      cloudFunctions: FakeCloudFunctions(),
      now: () => 1000,
    );
    final service = StudentLessonCloudProgressService(
      stateService: states,
      sync: StudentLearningSync(queue),
    );

    service.publishLessonProgress(
      const LessonCloudProgressInput(
        lessonLocalId: 'l1',
        itemIdx: 1,
        layer: LessonLayer.l2,
        totalItens: 3,
        mainAdvances: 1,
        markerAtual: 'M2',
      ),
    );

    expect(states.read('l1')?.current?.marker, 'M2');
    expect(queue.getQueueSnapshot(), contains('l1'));
  });

  test(
    'lesson cloud bootstrap enqueues and drains when curriculum is ready',
    () async {
      final states = StudentLearningStateService(
        seed: {
          'local-1': stateWithProgress(
            id: 'local-1',
            itemIdx: 0,
            layer: LessonLayer.l1,
            mainAdvances: 0,
          ),
        },
      );
      final cloud = FakeCloudFunctions();
      final queue = CloudQueue(
        storage: MemoryCloudQueueStorage(),
        stateService: states,
        sessionProvider: FakeSessionProvider(),
        cloudFunctions: cloud,
        now: () => 1000,
      );
      final bootstrap = LessonCloudBootstrap(sync: StudentLearningSync(queue));
      final ok = await bootstrap.run(
        LessonCloudBootstrapInput(
          curriculum: states.read('local-1')!.curriculum,
          onboarding: {'objetivo': 'Matematica', 'lessonLocalId': 'local-1'},
          itemIdx: 0,
          layer: LessonLayer.l1,
          mainAdvances: 0,
        ),
      );

      expect(ok, true);
      expect(cloud.persistCalls, 1);
    },
  );

  test('curriculum sync settles from official state when UI has none', () {
    final states = StudentLearningStateService(
      seed: {
        'l1': stateWithProgress(
          id: 'l1',
          itemIdx: 0,
          layer: LessonLayer.l1,
          mainAdvances: 0,
        ),
      },
    );
    final engine = LessonCurriculumSyncEngine(stateService: states);

    final snap = engine.refresh(lessonLocalId: 'l1');
    expect(snap.rehydrationSettled, true);
    expect(snap.curriculum?.items.length, 3);
  });
}
