part of '../dopamine_ready_window_engine.dart';

class DopamineReadyWindowHealth {
  const DopamineReadyWindowHealth({
    required this.expectedSlots,
    required this.readySlots,
    required this.queuedSlots,
    required this.missingSlots,
    required this.staleSlots,
    required this.wrongIdentitySlots,
    required this.expectedHotCount,
    required this.hotTextReadyCount,
    required this.hotQueuedCount,
    required this.hotMissingCount,
    required this.warmExpectedCount,
    required this.warmTextReadyCount,
    required this.warmQueuedCount,
    required this.warmRunningCount,
    required this.warmMissingCount,
    required this.warmInvalidCount,
    required this.invalidLocaleCount,
    required this.invalidMediaLocaleCount,
    required this.warmMediaPendingCount,
    required this.warmMediaReadyCount,
    required this.warmMediaFailedCount,
    required this.warmNoVisualCount,
    required this.mediaPendingCount,
    required this.windowStart,
    required this.source,
    required this.reason,
  });

  final List<JsonMap> expectedSlots;
  final List<JsonMap> readySlots;
  final List<JsonMap> queuedSlots;
  final List<JsonMap> missingSlots;
  final List<JsonMap> staleSlots;
  final List<JsonMap> wrongIdentitySlots;
  final int expectedHotCount;
  final int hotTextReadyCount;
  final int hotQueuedCount;
  final int hotMissingCount;
  final int warmExpectedCount;
  final int warmTextReadyCount;
  final int warmQueuedCount;
  final int warmRunningCount;
  final int warmMissingCount;
  final int warmInvalidCount;
  final int invalidLocaleCount;
  final int invalidMediaLocaleCount;
  final int warmMediaPendingCount;
  final int warmMediaReadyCount;
  final int warmMediaFailedCount;
  final int warmNoVisualCount;
  final int mediaPendingCount;
  final JsonMap? windowStart;
  final String source;
  final String? reason;

  int get expectedCount => expectedSlots.length;
  int get readyCount => readySlots.length;
  bool get exhaustedAtCurriculumEnd =>
      expectedSlots.length < localLessonTraySize && missingSlots.isEmpty;

  JsonMap toJson() => {
    'expectedSlots': expectedSlots,
    'readySlots': readySlots,
    'queuedSlots': queuedSlots,
    'missingSlots': missingSlots,
    'staleSlots': staleSlots,
    'wrongIdentitySlots': wrongIdentitySlots,
    'expectedCount': expectedCount,
    'readyCount': readyCount,
    'queuedCount': queuedSlots.length,
    'missingCount': missingSlots.length,
    'staleCount': staleSlots.length,
    'wrongIdentityCount': wrongIdentitySlots.length,
    'expectedHotCount': expectedHotCount,
    'hotTextReadyCount': hotTextReadyCount,
    'hotQueuedCount': hotQueuedCount,
    'hotMissingCount': hotMissingCount,
    'warmExpectedCount': warmExpectedCount,
    'warmTextReadyCount': warmTextReadyCount,
    'warmQueuedCount': warmQueuedCount,
    'warmRunningCount': warmRunningCount,
    'warmMissingCount': warmMissingCount,
    'warmInvalidCount': warmInvalidCount,
    'invalidLocaleCount': invalidLocaleCount,
    'invalidMediaLocaleCount': invalidMediaLocaleCount,
    'warmMediaPendingCount': warmMediaPendingCount,
    'warmMediaReadyCount': warmMediaReadyCount,
    'warmMediaFailedCount': warmMediaFailedCount,
    'warmNoVisualCount': warmNoVisualCount,
    'mediaPendingCount': mediaPendingCount,
    if (windowStart != null) 'windowStart': windowStart,
    'source': source,
    if (reason != null) 'reason': reason,
    'exhaustedAtCurriculumEnd': exhaustedAtCurriculumEnd,
  };
}

class ReadyWindowHealth {
  const ReadyWindowHealth({
    required this.service,
    required this.orchestrator,
    required this.readinessResolver,
  });

  final StudentLearningStateService service;
  final LessonOrchestrator orchestrator;
  final LessonReadinessResolver readinessResolver;

  DopamineReadyWindowHealth inspectDopamineReadyWindow({
    required String lessonLocalId,
    required List<DopamineReadySlot> slots,
    required String source,
    String? reason,
  }) {
    final state = service.read(lessonLocalId);
    final expected = <JsonMap>[];
    final ready = <JsonMap>[];
    final queued = <JsonMap>[];
    final missing = <JsonMap>[];
    final stale = <JsonMap>[];
    final wrongIdentity = <JsonMap>[];
    var mediaPendingCount = 0;
    var expectedHotCount = 0;
    var hotTextReadyCount = 0;
    var hotQueuedCount = 0;
    var hotMissingCount = 0;
    var warmQueuedCount = 0;
    var warmRunningCount = 0;
    var warmMissingCount = 0;
    var warmInvalidCount = 0;
    var invalidLocaleCount = 0;
    var invalidMediaLocaleCount = 0;
    var warmMediaPendingCount = 0;
    var warmMediaReadyCount = 0;
    var warmMediaFailedCount = 0;
    var warmNoVisualCount = 0;

    for (var index = 0; index < slots.length; index += 1) {
      final slot = slots[index];
      final isHot = _isHotTextSlot(slot);
      final slotJson = readyWindowSlotJson(slot);
      expected.add(slotJson);
      if (isHot) expectedHotCount += 1;
      final result = readinessResolver.resolve(
        state: state,
        orchestrator: orchestrator,
        identity: LessonReadinessIdentity(
          lessonLocalId: lessonLocalId,
          itemIdx: slot.itemIdx,
          marker: slot.marker,
          layer: slot.layer,
        ),
        params: slot.params,
      );
      if (result.isReady && result.lesson != null) {
        ready.add({...slotJson, 'source': result.status.name});
        if (isHot) hotTextReadyCount += 1;
        if (slotHasInvalidMediaLocale(state, slot)) {
          invalidMediaLocaleCount += 1;
        }
        final mediaState = _mediaStateFor(result.lesson!);
        switch (mediaState) {
          case _ReadyWindowMediaState.ready:
            warmMediaReadyCount += 1;
          case _ReadyWindowMediaState.failed:
            warmMediaFailedCount += 1;
          case _ReadyWindowMediaState.noVisual:
            warmNoVisualCount += 1;
          case _ReadyWindowMediaState.pending:
            warmMediaPendingCount += 1;
        }
        if (mediaState == _ReadyWindowMediaState.pending) {
          mediaPendingCount += 1;
        }
        continue;
      }
      final jobStatus = slotJobStatus(state, slot);
      final queuedForSlot = jobStatus != null;
      if (queuedForSlot) queued.add(slotJson);
      if (jobStatus == 'running') {
        warmRunningCount += 1;
      } else if (jobStatus == 'queued') {
        warmQueuedCount += 1;
      }
      if (isHot && queuedForSlot) hotQueuedCount += 1;
      if (result.status == LessonReadinessStatus.stale ||
          result.status == LessonReadinessStatus.invalid ||
          result.status == LessonReadinessStatus.staleLocale ||
          result.status == LessonReadinessStatus.legacyLocale) {
        final detail = {
          ...slotJson,
          if (result.discardedKey != null) 'discardedKey': result.discardedKey,
          if (result.safeReason != null) 'reason': result.safeReason,
          'status': result.status.name,
        };
        stale.add(detail);
        wrongIdentity.add(detail);
        warmInvalidCount += 1;
        if (result.status == LessonReadinessStatus.staleLocale ||
            result.status == LessonReadinessStatus.legacyLocale) {
          invalidLocaleCount += 1;
        }
      }
      if (!queuedForSlot) {
        missing.add(slotJson);
        warmMissingCount += 1;
        if (isHot) hotMissingCount += 1;
      }
    }

    return DopamineReadyWindowHealth(
      expectedSlots: expected,
      readySlots: ready,
      queuedSlots: queued,
      missingSlots: missing,
      staleSlots: stale,
      wrongIdentitySlots: wrongIdentity,
      expectedHotCount: expectedHotCount,
      hotTextReadyCount: hotTextReadyCount,
      hotQueuedCount: hotQueuedCount,
      hotMissingCount: hotMissingCount,
      warmExpectedCount: expected.length,
      warmTextReadyCount: ready.length,
      warmQueuedCount: warmQueuedCount,
      warmRunningCount: warmRunningCount,
      warmMissingCount: warmMissingCount,
      warmInvalidCount: warmInvalidCount,
      invalidLocaleCount: invalidLocaleCount,
      invalidMediaLocaleCount: invalidMediaLocaleCount,
      warmMediaPendingCount: warmMediaPendingCount,
      warmMediaReadyCount: warmMediaReadyCount,
      warmMediaFailedCount: warmMediaFailedCount,
      warmNoVisualCount: warmNoVisualCount,
      mediaPendingCount: mediaPendingCount,
      windowStart: expected.isEmpty ? null : expected.first,
      source: source,
      reason: reason,
    );
  }

  bool isWindowHealthy(List<DopamineReadySlot> positions) {
    return getMissingPositions(positions).isEmpty;
  }

  int getReadyCount(List<DopamineReadySlot> positions) {
    return positions.length - getMissingPositions(positions).length;
  }

  double getWindowHealthScore(List<DopamineReadySlot> positions) {
    if (positions.isEmpty) return 1;
    return getReadyCount(positions) / positions.length;
  }

  List<DopamineReadySlot> getMissingPositions(
    List<DopamineReadySlot> positions,
  ) {
    final state = positions.isEmpty
        ? null
        : service.read(positions.first.params.lessonLocalId);
    return positions
        .where((slot) {
          final result = readinessResolver.resolve(
            state: state,
            orchestrator: orchestrator,
            identity: LessonReadinessIdentity(
              lessonLocalId: slot.params.lessonLocalId,
              itemIdx: slot.itemIdx,
              marker: slot.marker,
              layer: slot.layer,
            ),
            params: slot.params,
          );
          return !result.isReady && !isSlotQueued(state, slot);
        })
        .toList(growable: false);
  }

  bool needsRefill(List<DopamineReadySlot> positions, int targetSize) {
    return positions.length < targetSize || !isWindowHealthy(positions);
  }

  void emitHealth(
    void Function(String lessonLocalId, String type, JsonMap payload) emit,
    String lessonLocalId,
    DopamineReadyWindowHealth health,
  ) {
    emit(lessonLocalId, 'DOPAMINE_WINDOW_HEALTH_CHECKED', health.toJson());
    emit(lessonLocalId, 'DOPAMINE_WINDOW_TEXT_READY_COUNT', {
      'source': health.source,
      if (health.reason != null) 'reason': health.reason,
      'expectedHotCount': health.expectedHotCount,
      'hotTextReadyCount': health.hotTextReadyCount,
      'hotQueuedCount': health.hotQueuedCount,
      'hotMissingCount': health.hotMissingCount,
      'warmExpectedCount': health.warmExpectedCount,
      'warmTextReadyCount': health.warmTextReadyCount,
      'warmQueuedCount': health.warmQueuedCount,
      'warmRunningCount': health.warmRunningCount,
      'warmMissingCount': health.warmMissingCount,
      'warmInvalidCount': health.warmInvalidCount,
      'invalidLocaleCount': health.invalidLocaleCount,
      'invalidMediaLocaleCount': health.invalidMediaLocaleCount,
      'warmMediaPendingCount': health.warmMediaPendingCount,
      'warmMediaReadyCount': health.warmMediaReadyCount,
      'warmMediaFailedCount': health.warmMediaFailedCount,
      'warmNoVisualCount': health.warmNoVisualCount,
      'readyCount': health.readyCount,
      'expectedCount': health.expectedCount,
      'mediaPendingCount': health.mediaPendingCount,
    });
  }

  bool isSlotQueued(StudentLearningState? state, DopamineReadySlot slot) {
    return slotJobStatus(state, slot) != null;
  }

  String? slotJobStatus(StudentLearningState? state, DopamineReadySlot slot) {
    final jobs = state?.queuedActions ?? const <JsonMap>[];
    for (final job in jobs) {
      if (job['type'] != 'PREPARE_READY_WINDOW') continue;
      final status = job['status'];
      if (status != 'queued' && status != 'running') continue;
      final payload = job['payload'];
      if (payload is! Map) continue;
      final itemIdx = (payload['itemIdx'] as num?)?.toInt();
      final layer = LessonLayerValue.fromValue(payload['layer']);
      final marker = payload['marker'] as String?;
      final hotSlots = payload['hotSlots'];
      if (hotSlots is Iterable) {
        final queuedExactSlot = hotSlots.any((raw) {
          if (raw is! Map) return false;
          final hotItemIdx = (raw['itemIdx'] as num?)?.toInt();
          final hotLayer = LessonLayerValue.fromValue(raw['layer']);
          final hotMarker = raw['marker'] as String?;
          return hotItemIdx == slot.itemIdx &&
              hotLayer == slot.layer &&
              hotMarker == slot.marker;
        });
        if (queuedExactSlot) return status as String;
      }
      if (itemIdx == null || marker == null || marker.isEmpty) {
        continue;
      }
      if (itemIdx == slot.itemIdx && layer == slot.layer) {
        if (marker == slot.marker) return status as String;
      }
    }
    return null;
  }

  bool _isHotTextSlot(DopamineReadySlot slot) {
    return const {'A', 'B', 'C', 'D'}.contains(slot.slot);
  }

  _ReadyWindowMediaState _mediaStateFor(CompleteLesson lesson) {
    final image = lesson.imagem;
    if (image != null && image.trim().isNotEmpty) {
      return _ReadyWindowMediaState.ready;
    }
    final status = lesson.imageMetadata?.status?.trim().toLowerCase();
    if (status == 'failed' || status == 'error') {
      return _ReadyWindowMediaState.failed;
    }
    if (status == 'no_visual' || status == 'no_image' || status == 'none') {
      return _ReadyWindowMediaState.noVisual;
    }
    return _ReadyWindowMediaState.pending;
  }
}

enum _ReadyWindowMediaState { pending, ready, failed, noVisual }
