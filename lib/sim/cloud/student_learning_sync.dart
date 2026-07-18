import 'cloud_queue.dart';

class StudentLearningSync {
  const StudentLearningSync(this.queue);

  final CloudQueue queue;

  Future<void> enqueue({
    required String lessonLocalId,
    required StudentLearningSyncOperation operation,
  }) {
    return queue.enqueueStudentStateSync(
      lessonLocalId: lessonLocalId,
      operation: operation,
    );
  }

  Future<void> enqueuePatch(String lessonLocalId) {
    return queue.enqueueStudentStateSync(lessonLocalId: lessonLocalId);
  }

  Future<void> enqueueTombstone(String lessonLocalId) {
    return queue.enqueueStudentStateSync(
      lessonLocalId: lessonLocalId,
      operation: StudentLearningSyncOperation.tombstone,
    );
  }

  Future<void> drain() => queue.drainQueue();

  void wireLifecycle() => queue.wireCloudQueueLifecycle();

  Map<String, CloudQueueEntry> getQueueSnapshot() => queue.getQueueSnapshot();

  Map<String, Map<String, Object?>> internalDebugSnapshotForTest() =>
      queue.internalDebugSnapshotForTest();
}
