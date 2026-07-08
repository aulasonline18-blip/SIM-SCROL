import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/cloud/cloud_functions.dart';
import 'package:sim_mobile/sim/cloud/offline_sync_contract.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

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
      expect(decision.resolution, SimSyncResolution.useRemote);
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

    expect(decision.resolution, SimSyncResolution.useRemote);
    expect(decision.reason, 'remote_high_water_mark_wins');
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
