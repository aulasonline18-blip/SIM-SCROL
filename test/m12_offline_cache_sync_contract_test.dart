import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/cloud/cloud_functions.dart';
import 'package:sim_mobile/sim/cloud/cloud_queue.dart';
import 'package:sim_mobile/sim/cloud/supabase_client_contract.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

import 'support/memory_test_stores.dart';

void main() {
  test('M12 keeps offline/cache/sync runtime without old remote routes', () {
    final runtime = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(runtime, contains('StudentStateStore'));
    expect(runtime, contains('CloudQueue'));
    expect(runtime, contains('LessonMaterialCache'));
    for (final route in const [
      '/api/warmup',
      '/api/doubt',
      '/api/review',
      '/api/recovery',
      '/api/advance-gate',
    ]) {
      expect(runtime, isNot(contains(route)), reason: route);
    }
  });

  test('stale tombstone queue cannot delete a new active lesson', () async {
    const lessonLocalId = 'cyber-sistema-digestivo';
    final state =
        StudentLearningState.empty(
          lessonLocalId: lessonLocalId,
          userId: 'user-1',
          now: 1,
        ).copyWith(
          profile: const StudentProfile(
            objetivo: 'Sistema digestivo',
            stableLang: 'pt-BR',
          ),
          curriculum: const StudentCurriculum(
            topic: 'Sistema digestivo',
            totalItems: 40,
            generatedAt: 2,
            provisional: false,
            items: [CurriculumItem(marker: 'DIG01', text: 'Boca e digestao')],
          ),
          current: const LessonCurrent(
            itemIdx: 0,
            marker: 'DIG01',
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
            totalItems: 40,
            pctAvanco: 0,
          ),
        );
    final storage = MemoryCloudQueueStorage();
    final cloud = _RecordingCloud();
    final queue = CloudQueue(
      storage: storage,
      stateService: StudentLearningStateService(seed: {lessonLocalId: state}),
      sessionProvider: _Session(),
      cloudFunctions: cloud,
      now: () => 1000,
      enableRetryTimers: false,
    );

    await queue.enqueueStudentStateSync(
      lessonLocalId: lessonLocalId,
      operation: StudentLearningSyncOperation.tombstone,
    );
    await queue.flushOne(lessonLocalId, force: true);
    await queue.flushOne(lessonLocalId, force: true);

    expect(cloud.deleted, isEmpty);
    expect(cloud.persisted, [lessonLocalId]);
  });

  test('remote tombstone cannot overwrite a new active local curriculum', () {
    const lessonLocalId = 'cyber-sistema-digestivo';
    final local = _activeDigestiveLesson(lessonLocalId);
    final remoteDeleted = local.copyWith(
      extra: const {
        'deletedAt': 900,
        'syncInfo': {'deletedAt': 900, 'operation': 'tombstone'},
      },
    );

    final merged = mergeStudentLearningStateFromCloud(local, remoteDeleted);

    expect(merged.extra['deletedAt'], isNull);
    expect(merged.curriculum?.items.length, 1);
    expect(merged.progress?.totalItems, 40);
  });
}

StudentLearningState _activeDigestiveLesson(String lessonLocalId) {
  return StudentLearningState.empty(
    lessonLocalId: lessonLocalId,
    userId: 'user-1',
    now: 1,
  ).copyWith(
    profile: const StudentProfile(
      objetivo: 'Sistema digestivo',
      stableLang: 'pt-BR',
    ),
    curriculum: const StudentCurriculum(
      topic: 'Sistema digestivo',
      totalItems: 40,
      generatedAt: 2,
      provisional: false,
      items: [CurriculumItem(marker: 'DIG01', text: 'Boca e digestao')],
    ),
    current: const LessonCurrent(
      itemIdx: 0,
      marker: 'DIG01',
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
      totalItems: 40,
      pctAvanco: 0,
    ),
  );
}

class _Session implements SupabaseSessionProvider {
  @override
  Future<SupabaseSession?> currentSession() async =>
      const SupabaseSession(accessToken: 'token', userId: 'user-1');
}

class _RecordingCloud implements StudentStateCloudFunctions {
  final deleted = <String>[];
  final persisted = <String>[];

  @override
  Future<void> deleteStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async {
    deleted.add(lessonLocalId);
  }

  @override
  Future<StudentStateRow?> getStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async {
    return null;
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
    persisted.add(input.lessonLocalId);
    return PersistStudentStateResult.accepted(
      lessonLocalId: input.lessonLocalId,
      highWaterMark: input.clientScore,
      schemaVersion: input.schemaVersion,
    );
  }
}
