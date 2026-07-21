part of '../dopamine_ready_window_engine.dart';

class DopamineReadyWindowHealth {
  const DopamineReadyWindowHealth({
    required this.expectedSlots,
    required this.readySlots,
    required this.queuedSlots,
    required this.missingSlots,
    required this.staleSlots,
    required this.wrongIdentitySlots,
    required this.hotTextReadyCount,
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
  final int hotTextReadyCount;
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
    'hotTextReadyCount': hotTextReadyCount,
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

    for (var index = 0; index < slots.length; index += 1) {
      final slot = slots[index];
      final slotJson = readyWindowSlotJson(slot);
      expected.add(slotJson);
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
        if ((result.lesson!.imagem ?? '').trim().isEmpty) {
          mediaPendingCount += 1;
        }
        continue;
      }
      final queuedForSlot = isSlotQueued(state, slot);
      if (queuedForSlot) queued.add(slotJson);
      if (result.status == LessonReadinessStatus.stale ||
          result.status == LessonReadinessStatus.invalid) {
        final detail = {
          ...slotJson,
          if (result.discardedKey != null) 'discardedKey': result.discardedKey,
          if (result.safeReason != null) 'reason': result.safeReason,
        };
        stale.add(detail);
        wrongIdentity.add(detail);
      }
      if (!queuedForSlot) missing.add(slotJson);
    }

    return DopamineReadyWindowHealth(
      expectedSlots: expected,
      readySlots: ready,
      queuedSlots: queued,
      missingSlots: missing,
      staleSlots: stale,
      wrongIdentitySlots: wrongIdentity,
      hotTextReadyCount: ready
          .where((slot) => const {'A', 'B', 'C', 'D'}.contains(slot['slot']))
          .length,
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
      'hotTextReadyCount': health.hotTextReadyCount,
      'readyCount': health.readyCount,
      'expectedCount': health.expectedCount,
      'mediaPendingCount': health.mediaPendingCount,
    });
  }

  bool isSlotQueued(StudentLearningState? state, DopamineReadySlot slot) {
    final jobs = state?.queuedActions ?? const <JsonMap>[];
    return jobs.any((job) {
      if (job['type'] != 'PREPARE_READY_WINDOW') return false;
      final status = job['status'];
      if (status != 'queued' && status != 'running') return false;
      final payload = job['payload'];
      if (payload is! Map) return false;
      final itemIdx = (payload['itemIdx'] as num?)?.toInt();
      final layer = LessonLayerValue.fromValue(payload['layer']);
      final marker = payload['marker'] as String?;
      if (itemIdx == null) return true;
      if (itemIdx == slot.itemIdx && layer == slot.layer) {
        return marker == null || marker.isEmpty || marker == slot.marker;
      }
      return false;
    });
  }
}
