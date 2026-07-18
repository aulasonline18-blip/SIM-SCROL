import '../state/student_learning_state.dart';
import 'cloud_functions.dart';

const int simOfflineSnapshotSchemaVersion = 1;
const int simOfflineQueueMaxEvents = 500;
const int simOfflineCacheMaxLessons = 24;
const int simOfflineMediaCacheMaxEntries = 80;

enum SimOfflineEventStatus { queued, replaying, synced, failed, blocked }

enum SimSyncResolution {
  restoreValidatedRemote,
  useLocal,
  keepLocalSynced,
  mergeValidatedRemote,
  mergeAndRetry,
  queueLocalEvent,
  clearCacheOnly,
}

enum SimSyncAuditEvent {
  syncStarted,
  syncCompleted,
  syncFailed,
  syncBlockedRegression,
  offlineEventQueued,
  offlineEventReplayed,
  technicalCacheCleared,
}

class SimOfflineSnapshotContract {
  const SimOfflineSnapshotContract({
    required this.lessonLocalId,
    required this.schemaVersion,
    required this.stateVersion,
    required this.highWaterMark,
    required this.current,
    required this.progress,
    required this.pendingEvents,
    required this.cacheMetadata,
    this.userId,
    this.sessionId,
    this.lastSyncedAt,
  });

  final String lessonLocalId;
  final String? userId;
  final String? sessionId;
  final int schemaVersion;
  final int stateVersion;
  final int highWaterMark;
  final int? lastSyncedAt;
  final JsonMap? current;
  final JsonMap? progress;
  final List<JsonMap> pendingEvents;
  final JsonMap cacheMetadata;

  factory SimOfflineSnapshotContract.fromState(
    StudentLearningState state, {
    int? lastSyncedAt,
    List<SimOfflineQueueEvent> pendingEvents = const [],
    JsonMap cacheMetadata = const {},
  }) {
    return SimOfflineSnapshotContract(
      lessonLocalId: state.lessonLocalId,
      userId: state.userId,
      schemaVersion: simOfflineSnapshotSchemaVersion,
      stateVersion: state.stateVersion,
      highWaterMark: scoreOfStudentLearningState(state),
      lastSyncedAt: lastSyncedAt,
      current: state.current?.toJson(),
      progress: state.progress?.toJson(),
      pendingEvents: pendingEvents.map((event) => event.toJson()).toList(),
      cacheMetadata: cacheMetadata,
    );
  }

  bool get hasStrongIdentity =>
      lessonLocalId.trim().isNotEmpty &&
      ((userId ?? '').trim().isNotEmpty || (sessionId ?? '').trim().isNotEmpty);

  bool get canRestoreForReading =>
      schemaVersion == simOfflineSnapshotSchemaVersion &&
      lessonLocalId.trim().isNotEmpty &&
      stateVersion >= 1 &&
      current != null &&
      progress != null;
}

class SimOfflineQueueEvent {
  const SimOfflineQueueEvent({
    required this.eventId,
    required this.idempotencyKey,
    required this.lessonLocalId,
    required this.marker,
    required this.layer,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.status = SimOfflineEventStatus.queued,
  });

  final String eventId;
  final String idempotencyKey;
  final String lessonLocalId;
  final String marker;
  final int layer;
  final String type;
  final JsonMap payload;
  final int createdAt;
  final SimOfflineEventStatus status;

  JsonMap toJson() => {
    'eventId': eventId,
    'idempotencyKey': idempotencyKey,
    'lessonLocalId': lessonLocalId,
    'marker': marker,
    'layer': layer,
    'type': type,
    'payload': payload,
    'createdAt': createdAt,
    'status': status.name,
  };

  bool get isValid =>
      eventId.trim().isNotEmpty &&
      idempotencyKey.trim().isNotEmpty &&
      lessonLocalId.trim().isNotEmpty &&
      marker.trim().isNotEmpty &&
      layer >= 1 &&
      type.trim().isNotEmpty &&
      createdAt > 0;

  bool sameIdempotency(SimOfflineQueueEvent other) =>
      lessonLocalId == other.lessonLocalId &&
      idempotencyKey == other.idempotencyKey;
}

class SimOfflineSyncDecision {
  const SimOfflineSyncDecision({
    required this.resolution,
    required this.reason,
    required this.auditEvent,
    this.humanMessage,
  });

  final SimSyncResolution resolution;
  final String reason;
  final SimSyncAuditEvent auditEvent;
  final String? humanMessage;
}

class SimOfflineCacheEntry {
  const SimOfflineCacheEntry({
    required this.cacheKey,
    required this.lessonLocalId,
    required this.marker,
    required this.layer,
    required this.savedAt,
    this.mediaType,
  });

  final String cacheKey;
  final String lessonLocalId;
  final String marker;
  final int layer;
  final int savedAt;
  final String? mediaType;

  bool belongsToSlot({
    required String lessonLocalId,
    required String marker,
    required int layer,
  }) {
    return this.lessonLocalId == lessonLocalId &&
        this.marker == marker &&
        this.layer == layer;
  }
}

class SimOfflineSyncPolicy {
  const SimOfflineSyncPolicy();

  List<SimOfflineQueueEvent> dedupeEvents(
    Iterable<SimOfflineQueueEvent> events,
  ) {
    final seen = <String>{};
    final result = <SimOfflineQueueEvent>[];
    for (final event in events) {
      if (!event.isValid) continue;
      final key = '${event.lessonLocalId}:${event.idempotencyKey}';
      if (seen.add(key)) result.add(event);
    }
    return result;
  }

  SimOfflineSyncDecision decide({
    required StudentLearningState? local,
    required StudentLearningState? remote,
    bool networkAvailable = true,
    bool localHasPendingEvents = false,
  }) {
    if (!networkAvailable) {
      return const SimOfflineSyncDecision(
        resolution: SimSyncResolution.queueLocalEvent,
        reason: 'network_unavailable',
        auditEvent: SimSyncAuditEvent.offlineEventQueued,
        humanMessage:
            'Sua conexao parece instavel. Salvamos sua resposta e vamos tentar enviar novamente.',
      );
    }
    if (remote == null && local != null) {
      return const SimOfflineSyncDecision(
        resolution: SimSyncResolution.useLocal,
        reason: 'remote_empty',
        auditEvent: SimSyncAuditEvent.syncStarted,
      );
    }
    if (remote != null && local == null) {
      return const SimOfflineSyncDecision(
        resolution: SimSyncResolution.restoreValidatedRemote,
        reason: 'local_empty_restore_validated',
        auditEvent: SimSyncAuditEvent.syncCompleted,
      );
    }
    if (remote == null && local == null) {
      return const SimOfflineSyncDecision(
        resolution: SimSyncResolution.clearCacheOnly,
        reason: 'no_state_available',
        auditEvent: SimSyncAuditEvent.syncFailed,
        humanMessage:
            'Nao encontramos uma aula salva neste dispositivo. Conecte-se para restaurar seu progresso.',
      );
    }
    final localScore = scoreOfStudentLearningState(local);
    final remoteScore = scoreOfStudentLearningState(remote);
    if (remoteScore > localScore) {
      return const SimOfflineSyncDecision(
        resolution: SimSyncResolution.mergeValidatedRemote,
        reason: 'remote_restore_requires_validated_merge',
        auditEvent: SimSyncAuditEvent.syncBlockedRegression,
      );
    }
    if (localScore > remoteScore && localHasPendingEvents) {
      return const SimOfflineSyncDecision(
        resolution: SimSyncResolution.mergeAndRetry,
        reason: 'local_has_pending_events',
        auditEvent: SimSyncAuditEvent.offlineEventReplayed,
      );
    }
    return const SimOfflineSyncDecision(
      resolution: SimSyncResolution.keepLocalSynced,
      reason: 'equal_state_no_local_pending_change',
      auditEvent: SimSyncAuditEvent.syncCompleted,
    );
  }

  List<SimOfflineCacheEntry> trimCache(
    Iterable<SimOfflineCacheEntry> entries, {
    required int maxEntries,
    String? protectedLessonLocalId,
  }) {
    final sorted = entries.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final protected = protectedLessonLocalId == null
        ? const <SimOfflineCacheEntry>[]
        : sorted
              .where((entry) => entry.lessonLocalId == protectedLessonLocalId)
              .toList();
    final rest = sorted
        .where((entry) => entry.lessonLocalId != protectedLessonLocalId)
        .toList();
    return [...protected, ...rest].take(maxEntries).toList(growable: false);
  }

  bool mediaCanRenderForSlot(
    SimOfflineCacheEntry media, {
    required String lessonLocalId,
    required String marker,
    required int layer,
  }) {
    return media.belongsToSlot(
      lessonLocalId: lessonLocalId,
      marker: marker,
      layer: layer,
    );
  }

  String humanSyncError(Object error) {
    final raw = error.toString();
    final forbidden = [
      'JSON',
      'HTTP',
      'stack',
      'Exception',
      'SocketException',
      'session_not_found',
    ];
    if (forbidden.any(raw.contains)) {
      return 'Sua conexao parece instavel. Salvamos sua resposta e vamos tentar enviar novamente.';
    }
    return raw.trim().isEmpty
        ? 'Nao foi possivel sincronizar agora. Vamos tentar novamente.'
        : raw;
  }
}
