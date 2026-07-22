part of '../dopamine_ready_window_engine.dart';

class ReadyWindowExecutor {
  ReadyWindowExecutor({
    required this.service,
    required this.orchestrator,
    required this.readinessResolver,
    required this.planner,
    required this.health,
    required this.media,
  });

  final StudentLearningStateService service;
  final LessonOrchestrator orchestrator;
  final LessonReadinessResolver readinessResolver;
  final ReadyWindowPlanner planner;
  final ReadyWindowHealth health;
  final ReadyWindowMedia media;
  final Map<String, Future<List<bool>>> _inflight = {};

  Future<List<bool>> maintainDopamineReadyWindow({
    required String lessonLocalId,
    required String source,
    required List<DopamineReadySlot> slots,
    String? topic,
    bool returnMode = false,
    int? maxSlots,
  }) async {
    final windowLimit = _boundedWindowLimit(maxSlots, returnMode: returnMode);
    final selected = slots.take(windowLimit).toList();
    if (maxSlots != null && maxSlots > windowLimit) {
      _event(lessonLocalId, 'DOPAMINE_WINDOW_REQUEST_CAPPED', {
        'source': source,
        'requested': maxSlots,
        'accepted': windowLimit,
        'limit': returnMode ? 2 : localLessonTraySize,
      });
    }
    final beforeHealth = health.inspectDopamineReadyWindow(
      lessonLocalId: lessonLocalId,
      slots: selected,
      source: source,
      reason: 'before_refill',
    );
    _emitHealth(lessonLocalId, beforeHealth);
    orchestrator.protectWarmCachedLessons(
      selected.map((slot) => lessonKeyFor(slot.params)),
    );
    _event(lessonLocalId, 'DOPAMINE_WINDOW_REQUESTED', {
      'source': source,
      'returnMode': returnMode,
      'slots': selected
          .map(
            (slot) => {
              'slot': slot.slot,
              'itemIdx': slot.itemIdx,
              'marker': slot.marker,
              'layer': slot.layer.value,
            },
          )
          .toList(),
    });

    final results = <bool>[];
    final mediaSlots = <ReadyWindowMediaSlot>[];
    for (var index = 0; index < selected.length; index++) {
      final slot = selected[index];
      final key = lessonKeyFor(slot.params);
      // IV.3 step 1: key parity check
      if (slot.expectedKey != null && key != slot.expectedKey) {
        _event(lessonLocalId, 'DOPAMINE_KEY_MISMATCH', {
          'source': source,
          'slot': slot.slot,
          'expectedKey': slot.expectedKey,
          'actualKey': key,
        });
        results.add(false);
        continue;
      }
      final readiness = readinessResolver.resolve(
        state: service.read(lessonLocalId),
        orchestrator: orchestrator,
        identity: LessonReadinessIdentity(
          lessonLocalId: lessonLocalId,
          itemIdx: slot.itemIdx,
          marker: slot.marker,
          layer: slot.layer,
        ),
        params: slot.params,
      );
      if (readiness.status == LessonReadinessStatus.stale ||
          readiness.status == LessonReadinessStatus.invalid ||
          readiness.status == LessonReadinessStatus.staleLocale ||
          readiness.status == LessonReadinessStatus.legacyLocale) {
        _discardStaleReadyMaterial(
          lessonLocalId: lessonLocalId,
          slot: slot,
          result: readiness,
          source: source,
        );
      }
      if (readiness.status == LessonReadinessStatus.readyFromState &&
          readiness.lesson != null) {
        final lesson = media.prepareMediaFromCachedLesson(
          lessonLocalId: lessonLocalId,
          source: source,
          slot: slot,
          lesson: readiness.lesson!,
          emit: _event,
        );
        mediaSlots.add(ReadyWindowMediaSlot(slot: slot, lesson: lesson));
        _markFirstLessonIfNeeded(lessonLocalId, slot);
        _event(lessonLocalId, 'DOPAMINE_SLOT_ALREADY_READY', {
          'source': source,
          'slot': slot.slot,
          'storage': 'student_state',
        });
        results.add(true);
        continue;
      }

      if (readiness.status == LessonReadinessStatus.readyFromMemoryCache &&
          readiness.lesson != null) {
        _mirrorPreparedLesson(
          lessonLocalId: lessonLocalId,
          slot: slot,
          lesson: readiness.lesson!,
          model: 'DopamineReadyWindowEngine-cache',
        );
        final lesson = media.prepareMediaFromCachedLesson(
          lessonLocalId: lessonLocalId,
          source: source,
          slot: slot,
          lesson: readiness.lesson!,
          emit: _event,
        );
        mediaSlots.add(ReadyWindowMediaSlot(slot: slot, lesson: lesson));
        _markFirstLessonIfNeeded(lessonLocalId, slot);
        _event(lessonLocalId, 'DOPAMINE_SLOT_ALREADY_READY', {
          'source': source,
          'slot': slot.slot,
          'storage': 'cache',
        });
        results.add(true);
        continue;
      }

      if (_isFirstLessonSlot(slot)) {
        updateLiveEntryState(
          service,
          lessonLocalId,
          status: LiveEntryStatus.t02FirstLessonRunning,
          firstItemMarker: slot.marker,
          firstLessonMaterialKey: firstLessonMaterialKey(slot.marker),
          firstLessonStartedAt: DateTime.now().millisecondsSinceEpoch,
        );
      }
      final slotPriority = _priorityForSlot(slot);
      _event(lessonLocalId, 'DOPAMINE_SLOT_REQUESTED', {
        'source': source,
        'slot': slot.slot,
        'itemIdx': slot.itemIdx,
        'marker': slot.marker,
        'layer': slot.layer.value,
        'priority': slotPriority,
      });
      _event(lessonLocalId, 'DOPAMINE_WINDOW_SLOT_MISSING', {
        'source': source,
        ...readyWindowSlotJson(slot),
        'priority': slotPriority,
      });

      try {
        final lesson = await orchestrator.prefetchCompleteLesson(
          slot.params,
          priority: slotPriority,
          deferMedia: true,
        );
        _mirrorPreparedLesson(
          lessonLocalId: lessonLocalId,
          slot: slot,
          lesson: lesson,
          model: 'DopamineReadyWindowEngine',
        );
        mediaSlots.add(ReadyWindowMediaSlot(slot: slot, lesson: lesson));
        _markFirstLessonIfNeeded(lessonLocalId, slot);
        _event(lessonLocalId, 'DOPAMINE_SLOT_READY', {
          'source': source,
          'slot': slot.slot,
          'itemIdx': slot.itemIdx,
          'marker': slot.marker,
          'layer': slot.layer.value,
        });
        results.add(true);
      } catch (error) {
        if (_isFirstLessonSlot(slot)) {
          updateLiveEntryState(
            service,
            lessonLocalId,
            status: LiveEntryStatus.failedT02,
            error: 'DOPAMINE_SLOT_FAILED',
            firstItemMarker: slot.marker,
            firstLessonMaterialKey: firstLessonMaterialKey(slot.marker),
          );
          _event(lessonLocalId, 'DOPAMINE_SLOT_FAILED', {
            'source': source,
            'slot': slot.slot,
            'error_code': 'DOPAMINE_SLOT_FAILED',
          });
          rethrow;
        }
        _event(lessonLocalId, 'DOPAMINE_SLOT_FAILED', {
          'source': source,
          'slot': slot.slot,
          'error_code': 'DOPAMINE_SLOT_FAILED',
        });
        results.add(false);
      }
    }

    _event(lessonLocalId, 'DOPAMINE_WINDOW_READY', {
      'source': source,
      'ready': results.where((ready) => ready).length,
      'requested': selected.length,
    });
    final afterHealth = health.inspectDopamineReadyWindow(
      lessonLocalId: lessonLocalId,
      slots: selected,
      source: source,
      reason: 'after_refill',
    );
    _emitHealth(lessonLocalId, afterHealth);
    _event(lessonLocalId, 'DOPAMINE_WINDOW_REFILLED', {
      'source': source,
      'requested': selected.length,
      'ready': afterHealth.readyCount,
      'missing': afterHealth.missingSlots.length,
      'hotTextReadyCount': afterHealth.hotTextReadyCount,
    });
    if (afterHealth.exhaustedAtCurriculumEnd) {
      _event(lessonLocalId, 'DOPAMINE_WINDOW_EXHAUSTED_AT_CURRICULUM_END', {
        'source': source,
        'expected': afterHealth.expectedCount,
        'ready': afterHealth.readyCount,
      });
    }
    media.queueSecondaryMedia(
      lessonLocalId: lessonLocalId,
      source: source,
      mediaSlots: mediaSlots,
      emit: _event,
    );
    return results;
  }

  Future<List<bool>> runDopamineReadyWindowFromStudentState({
    required String lessonLocalId,
    required String source,
    int? maxSlots,
    bool returnMode = false,
    int? itemIdx,
    LessonLayer? layer,
    String? marker,
    String? topic,
  }) {
    final inflightKey = _inflightKey(
      lessonLocalId: lessonLocalId,
      source: source,
      maxSlots: maxSlots,
      returnMode: returnMode,
      itemIdx: itemIdx,
      layer: layer,
      marker: marker,
    );
    final existing = _inflight[inflightKey];
    if (existing != null) return existing;
    final promise = () async {
      try {
        return await _runDopamineReadyWindowFromStudentState(
          lessonLocalId: lessonLocalId,
          source: source,
          maxSlots: maxSlots,
          returnMode: returnMode,
          itemIdx: itemIdx,
          layer: layer,
          marker: marker,
          topic: topic,
        );
      } finally {
        _inflight.remove(inflightKey);
      }
    }();
    _inflight[inflightKey] = promise;
    return promise;
  }

  Future<List<bool>> _runDopamineReadyWindowFromStudentState({
    required String lessonLocalId,
    required String source,
    int? maxSlots,
    bool returnMode = false,
    int? itemIdx,
    LessonLayer? layer,
    String? marker,
    String? topic,
  }) async {
    final state = service.read(lessonLocalId);
    final curriculumItems =
        state?.curriculum?.items ?? const <CurriculumItem>[];
    final items = curriculumItems
        .map(
          (item) =>
              DopamineWindowItem(text: itemText(item), marker: item.marker),
        )
        .where((item) => item.text.isNotEmpty)
        .toList();
    if (state == null || items.isEmpty) {
      _event(lessonLocalId, 'DOPAMINE_SLOT_FAILED', {
        'source': source,
        'reason': 'state_has_no_curriculum_items',
      });
      return const [];
    }

    final markerIdx = marker == null
        ? -1
        : items.indexWhere((item) => item.marker == marker);
    final currentItemIdx = itemIdx != null
        ? itemIdx.clamp(0, items.length - 1)
        : markerIdx >= 0
        ? markerIdx
        : state.current?.itemIdx ?? state.progress?.itemIdx ?? 0;
    final currentLayer =
        layer ??
        state.current?.layer ??
        state.progress?.layer ??
        LessonLayer.l1;
    final profile = state.profile.toJson();
    final lang = _langFromProfile(profile);
    final academic = _academicFromProfile(profile);
    final curriculumSnapshot = _curriculumSnapshot(state.curriculum);
    final topicSnapshot =
        topic ?? state.profile.objetivo ?? state.curriculum?.topic;

    final slots = planner.buildDopamineReadySlots(
      lessonLocalId: lessonLocalId,
      source: source,
      items: items,
      currentItemIdx: currentItemIdx,
      currentLayer: currentLayer,
      buildParams: (item, slotLayer) => CompleteLessonParams(
        lessonLocalId: lessonLocalId,
        item: item.text,
        lang: lang,
        academic: academic,
        layer: slotLayer,
        mode: item.isReview ? LessonMode.reforco : LessonMode.session,
        marker: item.marker,
        curriculumItems: curriculumSnapshot,
        topic: topicSnapshot,
        itemIdx: items.indexOf(item),
        pedagogicalEnvelope: _pedagogicalEnvelope(profile),
        localeContract: state.localeContract,
      ),
      maxSlots: _boundedWindowLimit(maxSlots, returnMode: returnMode),
    );

    return maintainDopamineReadyWindow(
      lessonLocalId: lessonLocalId,
      source: source,
      slots: slots,
      topic: topic ?? state.profile.objetivo ?? state.curriculum?.topic,
      returnMode: returnMode,
      maxSlots: maxSlots,
    );
  }

  String _inflightKey({
    required String lessonLocalId,
    required String source,
    required int? maxSlots,
    required bool returnMode,
    required int? itemIdx,
    required LessonLayer? layer,
    required String? marker,
  }) {
    return [
      lessonLocalId,
      'slots-${maxSlots ?? (returnMode ? 2 : localLessonTraySize)}',
      'item-${itemIdx ?? 'state'}',
      'layer-${layer?.value ?? 'state'}',
      'marker-${marker ?? 'state'}',
      'return-$returnMode',
      'source-$source',
    ].join('|');
  }

  bool _isHotSlot(DopamineReadySlot slot) => true;

  void _mirrorPreparedLesson({
    required String lessonLocalId,
    required DopamineReadySlot slot,
    required CompleteLesson lesson,
    required String model,
  }) {
    if (!_isHotSlot(slot)) return;
    final key = preparedLessonMaterialKey(
      slot.itemIdx,
      slot.marker,
      slot.layer,
    );
    service.mutate(lessonLocalId, (state) {
      return state.copyWith(
        readyLessonMaterials: {
          ...state.readyLessonMaterials,
          key: {
            ...preparedMaterialFromLesson(
              lesson: lesson,
              itemIdx: slot.itemIdx,
              marker: slot.marker,
              layer: slot.layer,
            ),
            'model': model,
          },
        },
      );
    });
  }

  void _discardStaleReadyMaterial({
    required String lessonLocalId,
    required DopamineReadySlot slot,
    required LessonReadinessResult result,
    required String source,
  }) {
    final key = result.discardedKey;
    if (key == null) return;
    service.mutate(lessonLocalId, (state) {
      final next = {...state.readyLessonMaterials}..remove(key);
      return state.copyWith(readyLessonMaterials: next);
    }, allowLocalHousekeeping: true);
    _event(lessonLocalId, 'DOPAMINE_WINDOW_SLOT_STALE_DISCARDED', {
      'source': source,
      ...readyWindowSlotJson(slot),
      'discardedKey': key,
      if (result.safeReason != null) 'reason': result.safeReason,
    });
  }

  void _markFirstLessonIfNeeded(String lessonLocalId, DopamineReadySlot slot) {
    if (!_isFirstLessonSlot(slot)) return;
    updateLiveEntryState(
      service,
      lessonLocalId,
      status: LiveEntryStatus.firstLessonReady,
      firstItemMarker: slot.marker,
      firstLessonMaterialKey: firstLessonMaterialKey(slot.marker),
      firstLessonReadyAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool _isFirstLessonSlot(DopamineReadySlot slot) {
    return slot.slot == 'A' &&
        slot.itemIdx == 0 &&
        slot.layer == LessonLayer.l1;
  }

  void _event(String lessonLocalId, String type, JsonMap payload) {
    service.appendEvent(
      lessonLocalId,
      StudentLearningEvent(
        type: type,
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: payload,
      ),
    );
  }

  void _emitHealth(String lessonLocalId, DopamineReadyWindowHealth result) {
    health.emitHealth(_event, lessonLocalId, result);
  }

  int _boundedWindowLimit(int? maxSlots, {required bool returnMode}) {
    final ceiling = returnMode ? 2 : localLessonTraySize;
    final requested = maxSlots ?? ceiling;
    if (requested <= 0) return 0;
    return requested > ceiling ? ceiling : requested;
  }

  String _priorityForSlot(DopamineReadySlot slot) {
    return const {'A', 'B', 'C', 'D'}.contains(slot.slot)
        ? 'hot-local'
        : 'background';
  }
}
