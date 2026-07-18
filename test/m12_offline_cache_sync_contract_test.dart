import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/cloud/cloud_functions.dart';
import 'package:sim_mobile/sim/cloud/cloud_queue.dart';
import 'package:sim_mobile/sim/cloud/offline_sync_contract.dart';
import 'package:sim_mobile/sim/cloud/shared_prefs_cloud_queue_storage.dart';
import 'package:sim_mobile/sim/cloud/supabase_client_contract.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/shared_prefs_state_storage.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const policy = SimOfflineSyncPolicy();

  test(
    'M12 local snapshot restores reading without replacing richer remote',
    () {
      final local = _state(itemIdx: 0, layer: LessonLayer.l1, advances: 0);
      final remote = _state(itemIdx: 2, layer: LessonLayer.l3, advances: 2);
      final snapshot = SimOfflineSnapshotContract.fromState(
        local,
        pendingEvents: [_answerEvent(idempotencyKey: 'answer-1')],
        cacheMetadata: const {'cacheOnly': true},
      );

      expect(snapshot.hasStrongIdentity, isTrue);
      expect(snapshot.canRestoreForReading, isTrue);
      expect(snapshot.pendingEvents.single['idempotencyKey'], 'answer-1');

      final decision = policy.decide(local: local, remote: remote);
      expect(decision.resolution, SimSyncResolution.mergeValidatedRemote);
      expect(decision.auditEvent, SimSyncAuditEvent.syncBlockedRegression);
    },
  );

  test('M12 empty local snapshot cannot overwrite rich remote state', () {
    final empty = StudentLearningState.empty(lessonLocalId: 'lesson-m12');
    final remote = _state(itemIdx: 2, layer: LessonLayer.l2, advances: 2);

    expect(
      scoreOfStudentLearningState(empty),
      lessThan(scoreOfStudentLearningState(remote)),
    );
    final decision = policy.decide(local: empty, remote: remote);

    expect(decision.resolution, SimSyncResolution.mergeValidatedRemote);
    expect(decision.reason, 'remote_restore_requires_validated_merge');
  });

  test('T7 equal state without local pending keeps local synced', () {
    final local = _state(itemIdx: 1, layer: LessonLayer.l2, advances: 1);
    final remote = _state(itemIdx: 1, layer: LessonLayer.l2, advances: 1);

    final decision = policy.decide(local: local, remote: remote);

    expect(decision.resolution, SimSyncResolution.keepLocalSynced);
    expect(decision.reason, 'equal_state_no_local_pending_change');
    expect(decision.reason, isNot('server_source_of_truth'));
  });

  test('T6 resolveConflict does not choose cloud only by updatedAt tie', () {
    final store = StudentStateStore(local: MemoryStudentStateLocalStorage());
    final local = _state(
      itemIdx: 1,
      layer: LessonLayer.l1,
      advances: 1,
    ).copyWith(updatedAt: 100);
    final cloud = _state(
      itemIdx: 1,
      layer: LessonLayer.l1,
      advances: 1,
    ).copyWith(updatedAt: 999);

    expect(store.resolveConflict(local, cloud), StateConflictResolution.equal);
  });

  test('M12 offline queue dedupes repeated student events', () {
    final first = _answerEvent(idempotencyKey: 'same-answer');
    final duplicate = _answerEvent(
      eventId: 'event-2',
      idempotencyKey: 'same-answer',
    );
    final other = _answerEvent(
      eventId: 'event-3',
      idempotencyKey: 'other-answer',
    );

    final deduped = policy.dedupeEvents([first, duplicate, other]);

    expect(deduped.map((event) => event.eventId), ['event-1', 'event-3']);
    expect(deduped.every((event) => event.isValid), isTrue);
  });

  test('M12 bad network queues event with human sync error', () {
    final decision = policy.decide(
      local: _state(itemIdx: 1, layer: LessonLayer.l1, advances: 1),
      remote: null,
      networkAvailable: false,
      localHasPendingEvents: true,
    );

    expect(decision.resolution, SimSyncResolution.queueLocalEvent);
    expect(decision.auditEvent, SimSyncAuditEvent.offlineEventQueued);
    expect(decision.humanMessage, contains('conexao parece instavel'));
    expect(
      policy.humanSyncError(
        Exception('HTTP 500 {"error":"session_not_found"}'),
      ),
      isNot(contains('HTTP')),
    );
  });

  test(
    'M12 conflict keeps the strongest state and replays pending local events',
    () {
      final local = _state(itemIdx: 3, layer: LessonLayer.l1, advances: 3);
      final remote = _state(itemIdx: 2, layer: LessonLayer.l3, advances: 2);

      final decision = policy.decide(
        local: local,
        remote: remote,
        localHasPendingEvents: true,
      );

      expect(decision.resolution, SimSyncResolution.mergeAndRetry);
      expect(decision.auditEvent, SimSyncAuditEvent.offlineEventReplayed);
    },
  );

  test(
    'M12 cache trim is bounded and does not remove protected active lesson first',
    () {
      final entries = [
        for (var i = 0; i < 6; i++)
          SimOfflineCacheEntry(
            cacheKey: 'cache-$i',
            lessonLocalId: i == 0 ? 'active' : 'lesson-$i',
            marker: 'M$i',
            layer: 1,
            savedAt: i,
          ),
      ];

      final trimmed = policy.trimCache(
        entries,
        maxEntries: 3,
        protectedLessonLocalId: 'active',
      );

      expect(trimmed, hasLength(3));
      expect(trimmed.first.lessonLocalId, 'active');
      expect(trimmed.map((entry) => entry.cacheKey), contains('cache-5'));
    },
  );

  test(
    'M12 clearing material cache is cache-only and media must match slot',
    () {
      const media = SimOfflineCacheEntry(
        cacheKey: 'image-1',
        lessonLocalId: 'lesson-m12',
        marker: 'M2',
        layer: 2,
        savedAt: 10,
        mediaType: 'image',
      );

      expect(
        policy.mediaCanRenderForSlot(
          media,
          lessonLocalId: 'lesson-m12',
          marker: 'M2',
          layer: 2,
        ),
        isTrue,
      );
      expect(
        policy.mediaCanRenderForSlot(
          media,
          lessonLocalId: 'lesson-m12',
          marker: 'M3',
          layer: 2,
        ),
        isFalse,
      );

      final decision = policy.decide(local: null, remote: null);
      expect(decision.resolution, SimSyncResolution.clearCacheOnly);
    },
  );

  test(
    'T7 corrupt queue JSON fails closed instead of becoming empty',
    () async {
      SharedPreferences.setMockInitialValues({
        'sim-student-state-queue-v1': '{"lesson":',
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPrefsCloudQueueStorage(prefs);

      expect(
        storage.readQueue,
        throwsA(
          isA<CloudQueueStorageException>().having(
            (error) => error.code,
            'code',
            'SYNC_QUEUE_CORRUPTED',
          ),
        ),
      );
    },
  );

  test(
    'T7 queue persistence verifies SharedPreferences write success',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPrefsCloudQueueStorage(prefs);
      final queue = CloudQueue(
        storage: storage,
        stateService: StudentLearningStateService(
          seed: {'lesson-m12': _state0()},
        ),
        sessionProvider: _Session(),
        cloudFunctions: _FailingCloudFunctions(),
        now: () => 1000,
        enableRetryTimers: false,
      );

      await queue.enqueueStudentStateSync(lessonLocalId: 'lesson-m12');

      final stored = prefs.getString('sim-student-state-queue-v1');
      expect(stored, isNotNull);
      expect(jsonDecode(stored!) as Map, contains('lesson-m12'));
      expect(storage.readQueue()['lesson-m12']?.stableId, isNotEmpty);
    },
  );

  test('T7 canonical queue hash is stable across JSON field order', () {
    final first = stableSmallHash(
      canonicalJsonEncode({
        'b': 2,
        'a': {'d': 4, 'c': 3},
      }),
    );
    final second = stableSmallHash(
      canonicalJsonEncode({
        'a': {'c': 3, 'd': 4},
        'b': 2,
      }),
    );

    expect(first, second);
    expect(canonicalJsonEncode({'b': 1, 'a': 2}), '{"a":2,"b":1}');
  });

  test('T7 maxAttempts blocks item without infinite retry loop', () async {
    final storage = MemoryCloudQueueStorage()
      ..writeQueue({
        'lesson-m12': const CloudQueueEntry(
          lessonLocalId: 'lesson-m12',
          operation: StudentLearningSyncOperation.patch,
          pendingSince: 1,
          attempts: CloudQueue.maxAttempts,
          nextRetryAt: 0,
        ),
      });
    final service = StudentLearningStateService(
      seed: {'lesson-m12': _state0()},
    );
    final queue = CloudQueue(
      storage: storage,
      stateService: service,
      sessionProvider: _Session(),
      cloudFunctions: _FailingCloudFunctions(),
      now: () => 1000,
      enableRetryTimers: false,
    );

    await queue.flushOne('lesson-m12', force: true);

    final entry = queue.getQueueSnapshot()['lesson-m12']!;
    expect(entry.status, CloudQueueEntryStatus.blocked);
    expect(entry.nextRetryAt, 0);
    expect(entry.lastFailureCode, 'SYNC_REMOTE_UNAVAILABLE');
    expect(
      service.read('lesson-m12')?.syncStatus?.lastError,
      'SYNC_MAX_ATTEMPTS_EXCEEDED',
    );
  });

  test('T7 lesson cache refuses ready entry without real material', () {
    final cache = LessonMaterialCache();
    final params = _lessonParams();

    expect(cache.putForParams(params, _lesson(explanation: '')), isFalse);
    expect(cache.peek(lessonKeyFor(params)), isNull);
  });

  test('T7 expired warm cache entry demotes to cold index', () async {
    final cache = LessonMaterialCache(ttlMs: 1);
    final params = _lessonParams();
    final key = lessonKeyFor(params);
    cache.putForParams(params, _lesson());

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cache.get(key), isNull);
    final cold = cache.coldEntry(key);
    expect(cold, isNotNull);
    expect(cold?.lessonKey, key);
    expect(cold?.marker, 'M1');
    expect(cold?.layer, LessonLayer.l1);
    expect(cold?.status, 'cold-index');
    expect(cold?.hadMaterial, isTrue);
    expect(cache.peek(key), isNull);
  });

  test('T7 cache corruption and persist status are observable', () async {
    SharedPreferences.setMockInitialValues({
      'sim-lesson-text-cache-v1': '{"warm":',
    });
    final prefs = await SharedPreferences.getInstance();
    final cache = LessonMaterialCache();

    final hydrate = cache.hydrateFromPreferences(prefs);
    expect(hydrate.ok, isFalse);
    expect(hydrate.code, 'CACHE_CORRUPTED_JSON');

    final persist = await cache.persistNow();
    expect(persist.ok, isTrue);
    expect(persist.code, 'CACHE_PERSISTED');
  });

  test('T7 cold index preserves history without declaring material ready', () {
    final cache = LessonMaterialCache(maxLessons: 0);
    final params = _lessonParams();
    cache.putForParams(params, _lesson());
    cache.trimWarmCache();

    final cold = cache.coldEntry(lessonKeyFor(params));
    expect(cold, isNotNull);
    expect(cold!.hadMaterial, isTrue);
    expect(cache.peek(lessonKeyFor(params)), isNull);
  });

  test(
    'T7 cleanup removes state, events, material cache and queue item',
    () async {
      final local = MemoryStudentStateLocalStorage();
      final store = StudentStateStore(local: local)..writeState(_state0());
      store.appendEvent(
        lessonLocalId: 'lesson-m12',
        type: 'ANSWER_SUBMITTED',
        payload: const {'letter': 'A'},
        source: 'test',
      );
      final cache = LessonMaterialCache()
        ..putForParams(_lessonParams(), _lesson());
      final queue = CloudQueue(
        storage: MemoryCloudQueueStorage(),
        stateService: StudentLearningStateService(
          seed: {'lesson-m12': _state0()},
        ),
        sessionProvider: _Session(),
        cloudFunctions: _FailingCloudFunctions(),
        now: () => 1000,
        enableRetryTimers: false,
      );
      await queue.enqueueStudentStateSync(lessonLocalId: 'lesson-m12');

      store.removeLocalLessonData('lesson-m12');
      cache.removeForLesson('lesson-m12');
      await queue.removeLesson('lesson-m12');

      expect(local.readState('lesson-m12'), isNull);
      expect(local.readEvents('lesson-m12'), isNull);
      expect(cache.peek(lessonKeyFor(_lessonParams())), isNull);
      expect(queue.getQueueSnapshot(), isEmpty);
    },
  );

  test(
    'T7 debugSnapshot redacts lesson ids and queued payload shape',
    () async {
      final queue = CloudQueue(
        storage: MemoryCloudQueueStorage(),
        stateService: StudentLearningStateService(
          seed: {'lesson-m12': _state0()},
        ),
        sessionProvider: _Session(),
        cloudFunctions: _FailingCloudFunctions(),
        now: () => 1000,
        enableRetryTimers: false,
      );
      await queue.enqueueStudentStateSync(lessonLocalId: 'lesson-m12');

      final encoded = jsonEncode(queue.internalDebugSnapshotForTest());

      expect(encoded.contains('lesson-m12'), isFalse);
      expect(encoded.contains('payload'), isFalse);
      expect(encoded.contains('operation'), isTrue);
    },
  );

  test(
    'T7 SharedPreferences state storage exposes durable validation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = SharedPrefsStudentStateLocalStorage(prefs);

      storage.writeState('lesson-m12', '{"ok":true}');
      storage.writeEvents('lesson-m12', '[{"type":"ANSWER"}]');
      await storage.verifyLastStateWrite();
      await storage.verifyLastEventsWrite();
      storage.deleteState('lesson-m12');
      storage.deleteEvents('lesson-m12');
      await storage.verifyLastDelete();

      expect(storage.readState('lesson-m12'), isNull);
      expect(storage.readEvents('lesson-m12'), isNull);
    },
  );

  test('T7 Drift storage does not ignore critical writes/deletes', () {
    final source = File(
      'lib/sim/state/drift_student_state_storage.dart',
    ).readAsStringSync();

    expect(source.contains('.ignore()'), isFalse);
    expect(source.contains('writeStateDurably'), isTrue);
    expect(source.contains('deleteStateDurably'), isTrue);
  });
}

class _Session implements SupabaseSessionProvider {
  @override
  Future<SupabaseSession?> currentSession() async =>
      const SupabaseSession(accessToken: 'token', userId: 'u1');
}

class _FailingCloudFunctions implements StudentStateCloudFunctions {
  @override
  Future<void> deleteStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async {}

  @override
  Future<StudentStateRow?> getStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async => null;

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
  ) async {
    throw StateError('network failed with technical detail');
  }
}

StudentLearningState _state({
  required int itemIdx,
  required LessonLayer layer,
  required int advances,
}) {
  final marker = 'M$itemIdx';
  return StudentLearningState.empty(
    lessonLocalId: 'lesson-m12',
    userId: 'user-m12',
    now: 1,
  ).copyWith(
    updatedAt: 10 + advances,
    stateVersion: studentLearningStateSchemaVersion,
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
      pendentesMarkers: const [],
      totalItems: 4,
      pctAvanco: advances * 25,
    ),
    currentLessonMaterial: {
      'for_marker': marker,
      'for_itemIdx': itemIdx,
      'for_layer': layer.value,
      'text_status': 'ready',
    },
    syncStatus: StudentSyncStatus(
      status: 'pending',
      pendingJobs: 1,
      highWaterMark: advances * 1000 + itemIdx * 10 + layer.value,
      updatedAt: 10 + advances,
    ),
  );
}

StudentLearningState _state0() =>
    _state(itemIdx: 1, layer: LessonLayer.l1, advances: 1);

CompleteLessonParams _lessonParams() => const CompleteLessonParams(
  lessonLocalId: 'lesson-m12',
  item: 'Item M12',
  lang: 'pt-BR',
  academic: 'medio',
  layer: LessonLayer.l1,
  mode: LessonMode.session,
  marker: 'M1',
  itemIdx: 1,
);

CompleteLesson _lesson({String explanation = 'Explicacao valida'}) {
  final content = LessonContent(
    explanation: explanation,
    question: 'Pergunta valida?',
    options: const {
      AnswerLetter.A: 'A',
      AnswerLetter.B: 'B',
      AnswerLetter.C: 'C',
    },
    correctAnswer: AnswerLetter.A,
  );
  return CompleteLesson(
    conteudo: content,
    imagem: null,
    audioText: content.audioText,
  );
}

SimOfflineQueueEvent _answerEvent({
  String eventId = 'event-1',
  required String idempotencyKey,
}) {
  return SimOfflineQueueEvent(
    eventId: eventId,
    idempotencyKey: idempotencyKey,
    lessonLocalId: 'lesson-m12',
    marker: 'M1',
    layer: 1,
    type: 'ANSWER_SUBMITTED',
    payload: const {'letter': 'A', 'signal': 2},
    createdAt: 10,
  );
}
