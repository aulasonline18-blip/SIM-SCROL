import '../state/student_learning_state.dart';
import '../state/student_state_store.dart';
import 'cloud_queue.dart';
import 'student_learning_sync.dart';

class StudentRemoteVaultSyncEngine {
  const StudentRemoteVaultSyncEngine({required this.store, required this.sync});

  final StudentStateStore store;
  final StudentLearningSync sync;

  void enqueueState({
    required String lessonLocalId,
    String reason = 'state_changed',
  }) {
    if (lessonLocalId.trim().isEmpty) return;
    _markQueued(lessonLocalId, reason);
    sync.enqueuePatch(lessonLocalId);
  }

  void enqueueTombstone({
    required String lessonLocalId,
    String reason = 'lesson_deleted',
  }) {
    if (lessonLocalId.trim().isEmpty) return;
    _markQueued(lessonLocalId, reason);
    sync.enqueueTombstone(lessonLocalId);
  }

  Future<void> drain() => sync.drain();

  Future<StudentLearningState> hydrate({required String lessonLocalId}) async {
    final state = await store.hydrateFromCloud(lessonLocalId);
    return store.writeState(
      _withRemoteVaultEvent(
        state,
        'REMOTE_VAULT_HYDRATED',
        status: 'hydrated',
        reason: 'remote_vault_bootstrap',
      ),
      acceptServerAuthority: true,
    );
  }

  Map<String, CloudQueueEntry> debugQueue() => sync.debugSnapshot();

  void _markQueued(String lessonLocalId, String reason) {
    final state = store.readState(lessonLocalId);
    store.writeState(
      _withRemoteVaultEvent(
        state,
        'REMOTE_VAULT_SYNC_QUEUED',
        status: 'queued',
        reason: reason,
      ),
    );
  }

  StudentLearningState _withRemoteVaultEvent(
    StudentLearningState state,
    String type, {
    required String status,
    required String reason,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final syncInfo = state.extra['syncInfo'] is Map
        ? Map<String, dynamic>.from(state.extra['syncInfo'] as Map)
        : <String, dynamic>{};
    return state.copyWith(
      syncStatus: StudentSyncStatus(
        status: status,
        pendingJobs: status == 'queued' ? 1 : 0,
        highWaterMark: state.syncStatus?.highWaterMark ?? 0,
        updatedAt: ts,
        lastSyncedAt: state.syncStatus?.lastSyncedAt,
        lastError: state.syncStatus?.lastError,
      ),
      events: [
        ...state.events,
        StudentLearningEvent(
          type: type,
          ts: ts,
          payload: {
            'lessonLocalId': state.lessonLocalId,
            'status': status,
            'reason': reason,
          },
        ),
      ],
      extra: {
        ...state.extra,
        'syncInfo': {
          ...syncInfo,
          'status': status,
          'reason': reason,
          'updatedAt': ts,
        },
      },
    );
  }
}
