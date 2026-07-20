import 'dart:async';

import '../experience/curriculum_utils.dart';
import '../media/slot_media_contract.dart';
import '../state/live_entry_state.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'lesson_models.dart';
import 'lesson_orchestrator.dart';
import 'lesson_readiness_resolver.dart';

const int offlineWarmCacheSize = 15;
const int localLessonTraySize = offlineWarmCacheSize;

List<StudentLearningEvent> dopamineWindowServiceEvents({
  required int ts,
  required String lessonLocalId,
  required String source,
  required String reason,
  required int currentItemIdx,
  required LessonLayer currentLayer,
  required List<
    ({int offset, int idx, DopamineWindowItem item, LessonLayer layer})
  >
  window,
  required Map<String, JsonMap> readyMaterials,
  required bool promotedHot,
  required String idempotencyKey,
  required String? marker,
}) {
  final missing = (window.length - readyMaterials.length).clamp(
    0,
    window.length,
  );
  final mediaPending = readyMaterials.values.where((material) {
    final image = material['imagem'] as String?;
    return image == null || image.trim().isEmpty;
  }).length;
  return [
    StudentLearningEvent(
      type: 'CACHE_WINDOW_UPDATED',
      ts: ts,
      payload: {
        'lessonLocalId': lessonLocalId,
        'currentItemIdx': currentItemIdx,
        'currentLayer': currentLayer.value,
        'windowMarkers': window
            .map(
              (slot) => {
                'marker': slot.item.marker,
                'layer': slot.layer.value,
                'offset': slot.offset,
              },
            )
            .toList(growable: false),
        'windowSize': window.length,
        'cachedCount': window.length,
      },
    ),
    StudentLearningEvent(
      type: 'DOPAMINE_WINDOW_HEALTH_CHECKED',
      ts: ts,
      payload: {
        'source': source,
        'reason': reason,
        'expectedCount': window.length,
        'readyCount': readyMaterials.length,
        'queuedCount': 1,
        'missingCount': missing,
        'hotTextReadyCount': readyMaterials.length.clamp(0, 4),
        'mediaPendingCount': mediaPending,
        if (window.isNotEmpty)
          'windowStart': {
            'itemIdx': window.first.idx,
            'marker': window.first.item.marker,
            'layer': window.first.layer.value,
          },
      },
    ),
    StudentLearningEvent(
      type: 'DOPAMINE_WINDOW_REFILLED',
      ts: ts,
      payload: {
        'source': source,
        'reason': reason,
        'requested': window.length,
        'ready': readyMaterials.length,
        'missing': missing,
      },
    ),
    if (promotedHot)
      StudentLearningEvent(
        type: 'DOPAMINE_WINDOW_HOT_PROMOTED',
        ts: ts,
        payload: {
          'source': source,
          'idempotencyKey': idempotencyKey,
          'itemIdx': currentItemIdx,
          'marker': marker,
          'layer': currentLayer.value,
        },
      ),
  ];
}

class DopamineWindowItem {
  const DopamineWindowItem({
    required this.text,
    this.marker,
    this.isReview = false,
    this.reviewLayer,
  });

  final String text;
  final String? marker;
  final bool isReview;
  final LessonLayer? reviewLayer;
}

class DopamineReadySlot {
  const DopamineReadySlot({
    required this.slot,
    required this.itemIdx,
    required this.marker,
    required this.layer,
    required this.params,
    this.expectedKey,
  });

  final String slot;
  final int itemIdx;
  final String? marker;
  final LessonLayer layer;
  final CompleteLessonParams params;
  final String? expectedKey;
}

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

class DopamineReadyWindowEngine {
  DopamineReadyWindowEngine({
    required this.service,
    required this.orchestrator,
    this.readinessResolver = const LessonReadinessResolver(),
  });

  final StudentLearningStateService service;
  final LessonOrchestrator orchestrator;
  final LessonReadinessResolver readinessResolver;
  final Map<String, Future<List<bool>>> _inflight = {};
  final Set<String> _queuedSecondaryMediaKeys = {};
  final Set<String> _mediaRefreshKeys = {};

  List<({int offset, int idx, DopamineWindowItem item, LessonLayer layer})>
  buildDopamineWindowPlan({
    required int fromIdx,
    required LessonLayer layer,
    required List<DopamineWindowItem> items,
    int maxSlots = localLessonTraySize,
  }) {
    if (fromIdx < 0 || fromIdx >= items.length) return const [];
    final first = items[fromIdx];
    final firstLayer = first.isReview
        ? first.reviewLayer ?? LessonLayer.l1
        : layer;
    final window =
        <({int offset, int idx, DopamineWindowItem item, LessonLayer layer})>[
          (offset: 0, idx: fromIdx, item: first, layer: firstLayer),
        ];
    var cursor = (idx: fromIdx, layer: firstLayer);
    while (window.length < maxSlots) {
      final next = _nextSlot(cursor.idx, cursor.layer, items);
      if (next == null || next.itemIdx < 0 || next.itemIdx >= items.length) {
        break;
      }
      final item = items[next.itemIdx];
      window.add((
        offset: window.length,
        idx: next.itemIdx,
        item: item,
        layer: next.layer,
      ));
      cursor = (idx: next.itemIdx, layer: next.layer);
    }
    return window;
  }

  List<DopamineReadySlot> buildDopamineReadySlots({
    required String lessonLocalId,
    required String source,
    required List<DopamineWindowItem> items,
    required int currentItemIdx,
    required LessonLayer currentLayer,
    required CompleteLessonParams Function(
      DopamineWindowItem item,
      LessonLayer layer,
    )
    buildParams,
    int maxSlots = localLessonTraySize,
  }) {
    final slots = <DopamineReadySlot>[];
    final planned = buildDopamineWindowPlan(
      fromIdx: currentItemIdx < 0 ? 0 : currentItemIdx,
      layer: currentLayer,
      items: items,
      maxSlots: maxSlots,
    );
    for (final plan in planned) {
      final params = buildParams(plan.item, plan.layer);
      slots.add(
        DopamineReadySlot(
          slot: _slotName(plan.offset),
          itemIdx: plan.idx,
          marker: plan.item.marker,
          layer: plan.layer,
          params: params,
          expectedKey: lessonKeyFor(params),
        ),
      );
    }
    return slots;
  }

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
    final beforeHealth = inspectDopamineReadyWindow(
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
    final mediaSlots = <_ReadyWindowMediaSlot>[];
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
          readiness.status == LessonReadinessStatus.invalid) {
        _discardStaleReadyMaterial(
          lessonLocalId: lessonLocalId,
          slot: slot,
          result: readiness,
          source: source,
        );
      }
      if (readiness.status == LessonReadinessStatus.readyFromState &&
          readiness.lesson != null) {
        final lesson = _prepareMediaFromCachedLesson(
          lessonLocalId: lessonLocalId,
          source: source,
          slot: slot,
          lesson: readiness.lesson!,
        );
        mediaSlots.add(_ReadyWindowMediaSlot(slot: slot, lesson: lesson));
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
        final lesson = _prepareMediaFromCachedLesson(
          lessonLocalId: lessonLocalId,
          source: source,
          slot: slot,
          lesson: readiness.lesson!,
        );
        mediaSlots.add(_ReadyWindowMediaSlot(slot: slot, lesson: lesson));
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
      _event(lessonLocalId, 'DOPAMINE_SLOT_REQUESTED', {
        'source': source,
        'slot': slot.slot,
        'itemIdx': slot.itemIdx,
        'marker': slot.marker,
        'layer': slot.layer.value,
        'priority': index == 0 ? 'hot-local' : 'background',
      });
      _event(lessonLocalId, 'DOPAMINE_WINDOW_SLOT_MISSING', {
        'source': source,
        ..._slotJson(slot),
        'priority': index == 0 ? 'hot-local' : 'background',
      });

      try {
        final lesson = await orchestrator.prefetchCompleteLesson(
          slot.params,
          priority: index == 0 ? 'hot-local' : 'background',
          deferMedia: true,
        );
        _mirrorPreparedLesson(
          lessonLocalId: lessonLocalId,
          slot: slot,
          lesson: lesson,
          model: 'DopamineReadyWindowEngine',
        );
        mediaSlots.add(_ReadyWindowMediaSlot(slot: slot, lesson: lesson));
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
    final afterHealth = inspectDopamineReadyWindow(
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
    _queueSecondaryMedia(lessonLocalId, source, mediaSlots);
    return results;
  }

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
      final slotJson = _slotJson(slot);
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
      final queuedForSlot = _isSlotQueued(state, slot);
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

    final slots = buildDopamineReadySlots(
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

  String _slotName(int index) {
    const hot = ['A', 'B', 'C', 'D'];
    if (index >= 0 && index < hot.length) return hot[index];
    return 'W${index + 1}';
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

  ({int itemIdx, LessonLayer layer})? _nextSlot(
    int itemIdx,
    LessonLayer layer,
    List<DopamineWindowItem> items,
  ) {
    final item = items[itemIdx];
    if (!item.isReview && layer != LessonLayer.l3) {
      return (
        itemIdx: itemIdx,
        layer: layer == LessonLayer.l1 ? LessonLayer.l2 : LessonLayer.l3,
      );
    }
    final nextIdx = itemIdx + 1;
    if (nextIdx >= items.length) return null;
    final next = items[nextIdx];
    return (itemIdx: nextIdx, layer: next.reviewLayer ?? LessonLayer.l1);
  }

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
      ..._slotJson(slot),
      'discardedKey': key,
      if (result.safeReason != null) 'reason': result.safeReason,
    });
  }

  CompleteLesson _prepareMediaFromCachedLesson({
    required String lessonLocalId,
    required String source,
    required DopamineReadySlot slot,
    required CompleteLesson lesson,
  }) {
    final state = service.read(lessonLocalId);
    final mediaKey = _slotMediaKey(lessonLocalId, slot, SlotMediaType.image);
    if (_mediaRefreshKeys.contains(mediaKey) ||
        _slotMediaAlreadyRequested(state, slot, SlotMediaType.image)) {
      return lesson;
    }
    _mediaRefreshKeys.add(mediaKey);
    _event(lessonLocalId, 'DOPAMINE_SLOT_MEDIA_REFRESH_REQUESTED', {
      'source': source,
      'slot': slot.slot,
      'itemIdx': slot.itemIdx,
      'marker': slot.marker,
      'layer': slot.layer.value,
      'mediaKey': mediaKey,
      'storage': 'cache',
    });
    return orchestrator.ensureVisualForReadyLesson(
      slot.params,
      lesson.conteudo,
      priority: 'background',
      initialImage: lesson.imagem,
      deferMedia: true,
    );
  }

  void _queueSecondaryMedia(
    String lessonLocalId,
    String source,
    List<_ReadyWindowMediaSlot> mediaSlots,
  ) {
    if (mediaSlots.isEmpty) return;
    final current = mediaSlots
        .where((entry) => entry.slot.slot == 'A')
        .toList(growable: false);
    final next = mediaSlots
        .where((entry) => entry.slot.slot != 'A')
        .toList(growable: false);

    for (final entry in current) {
      _queueSecondaryMediaType(
        lessonLocalId,
        source,
        entry,
        SlotMediaType.audio,
        'current',
      );
    }
    for (final entry in current) {
      _queueSecondaryMediaType(
        lessonLocalId,
        source,
        entry,
        SlotMediaType.image,
        'current',
      );
    }
    for (final entry in next) {
      _queueSecondaryMediaType(
        lessonLocalId,
        source,
        entry,
        SlotMediaType.audio,
        'next',
      );
    }
    for (final entry in next) {
      _queueSecondaryMediaType(
        lessonLocalId,
        source,
        entry,
        SlotMediaType.image,
        'next',
      );
    }
  }

  void _queueSecondaryMediaType(
    String lessonLocalId,
    String source,
    _ReadyWindowMediaSlot entry,
    SlotMediaType mediaType,
    String priority,
  ) {
    final mediaKey = _slotMediaKey(lessonLocalId, entry.slot, mediaType);
    final state = service.read(lessonLocalId);
    if (_queuedSecondaryMediaKeys.contains(mediaKey) ||
        _slotMediaAlreadyRequested(state, entry.slot, mediaType)) {
      return;
    }
    _queuedSecondaryMediaKeys.add(mediaKey);
    if (mediaType == SlotMediaType.audio) {
      orchestrator.queueAudioForReadyLesson(entry.slot.params, entry.lesson);
    } else {
      orchestrator.queueImageForReadyLesson(entry.slot.params, entry.lesson);
    }
    _event(
      lessonLocalId,
      mediaType == SlotMediaType.audio
          ? 'DOPAMINE_SLOT_AUDIO_QUEUED'
          : 'DOPAMINE_SLOT_IMAGE_QUEUED',
      {
        'source': source,
        'slot': entry.slot.slot,
        'priority': priority,
        'itemIdx': entry.slot.itemIdx,
        'marker': entry.slot.marker,
        'layer': entry.slot.layer.value,
        'mediaKey': mediaKey,
      },
    );
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

  void _emitHealth(String lessonLocalId, DopamineReadyWindowHealth health) {
    _event(lessonLocalId, 'DOPAMINE_WINDOW_HEALTH_CHECKED', health.toJson());
    _event(lessonLocalId, 'DOPAMINE_WINDOW_TEXT_READY_COUNT', {
      'source': health.source,
      if (health.reason != null) 'reason': health.reason,
      'hotTextReadyCount': health.hotTextReadyCount,
      'readyCount': health.readyCount,
      'expectedCount': health.expectedCount,
      'mediaPendingCount': health.mediaPendingCount,
    });
  }

  bool _isSlotQueued(StudentLearningState? state, DopamineReadySlot slot) {
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

  int _boundedWindowLimit(int? maxSlots, {required bool returnMode}) {
    final ceiling = returnMode ? 2 : localLessonTraySize;
    final requested = maxSlots ?? ceiling;
    if (requested <= 0) return 0;
    return requested > ceiling ? ceiling : requested;
  }

  bool _slotMediaAlreadyRequested(
    StudentLearningState? state,
    DopamineReadySlot slot,
    SlotMediaType mediaType,
  ) {
    final expectedKey = _slotMediaKey(
      slot.params.lessonLocalId,
      slot,
      mediaType,
    );
    final acceptedTypes = mediaType == SlotMediaType.audio
        ? const {'AUDIO_STARTED', 'AUDIO_READY'}
        : const {'IMAGE_STARTED', 'IMAGE_READY', 'NO_IMAGE'};
    return (state?.events ?? const <StudentLearningEvent>[]).any((event) {
      if (!acceptedTypes.contains(event.type)) return false;
      final payload = event.payload;
      final slotMedia = payload['slotMedia'];
      if (slotMedia is Map && slotMedia['cacheKey'] == expectedKey) {
        return true;
      }
      if (payload['mediaKey'] == expectedKey) return true;
      final marker = payload['marker'] ?? payload['itemMarker'];
      final rawLayer = payload['layer'];
      final layer = rawLayer is num
          ? rawLayer.toInt()
          : int.tryParse(rawLayer?.toString() ?? '');
      final rawItemIdx = payload['itemIdx'];
      final itemIdx = rawItemIdx is num
          ? rawItemIdx.toInt()
          : int.tryParse(rawItemIdx?.toString() ?? '');
      final sameMarker = marker == null || marker == slot.marker;
      final sameLayer = layer == null || layer == slot.layer.value;
      final sameItem = itemIdx == null || itemIdx == slot.itemIdx;
      return sameMarker && sameLayer && sameItem;
    });
  }

  String _slotMediaKey(
    String lessonLocalId,
    DopamineReadySlot slot,
    SlotMediaType mediaType,
  ) {
    return slotMediaCacheKey(
      lessonLocalId: lessonLocalId,
      marker: slot.marker ?? 'no-marker',
      itemIdx: slot.itemIdx,
      layer: slot.layer,
      mediaType: mediaType,
    );
  }

  JsonMap _slotJson(DopamineReadySlot slot) => {
    'slot': slot.slot,
    'lessonLocalId': slot.params.lessonLocalId,
    'itemIdx': slot.itemIdx,
    'marker': slot.marker,
    'layer': slot.layer.value,
    'mode': slot.params.mode.name,
    'topic': slot.params.topic,
    'lessonKey': lessonKeyFor(slot.params),
    'preparedKey': preparedLessonMaterialKey(
      slot.itemIdx,
      slot.marker,
      slot.layer,
    ),
    if (slot.expectedKey != null) 'expectedKey': slot.expectedKey,
  };
}

class _ReadyWindowMediaSlot {
  const _ReadyWindowMediaSlot({required this.slot, required this.lesson});

  final DopamineReadySlot slot;
  final CompleteLesson lesson;
}

String _pickProfileString(JsonMap profile, List<String> keys) {
  for (final key in keys) {
    final value = profile[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}

String _langFromProfile(JsonMap profile) {
  final direct = _pickProfileString(profile, [
    'stableLang',
    'STABLE_LANG',
    'language',
    'idioma',
  ]);
  const map = {
    'pt': 'Portuguese',
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'ja': 'Japanese',
  };
  return map[direct] ?? (direct.isEmpty ? 'English' : direct);
}

String _academicFromProfile(JsonMap profile) {
  final direct = _pickProfileString(profile, [
    'academicLevel',
    'academic_level',
    'ACADEMIC_LEVEL',
  ]);
  if (direct.isNotEmpty) return direct;
  final nivel = _pickProfileString(profile, ['nivel']);
  return switch (nivel) {
    'zero' => 'iniciante absoluto (zero conhecimento)',
    'pouco' => 'iniciante (algum contato previo)',
    'base' => 'intermediario (base solida)',
    'avancado' => 'avancado',
    _ => 'iniciante (nivel incerto, ajustar)',
  };
}

List<JsonMap> _curriculumSnapshot(StudentCurriculum? curriculum) {
  final items = curriculum?.items ?? const <CurriculumItem>[];
  return [
    for (var index = 0; index < items.length; index += 1)
      {
        ...items[index].extra,
        'order': index + 1,
        'marker': items[index].marker,
        if ((items[index].unit ?? '').trim().isNotEmpty)
          'unit': items[index].unit!.trim(),
        'title': items[index].title ?? items[index].text,
        'text': items[index].text,
        'purpose': items[index].teacherText,
        'microitem_for_teacher': items[index].teacherText,
      },
  ];
}

JsonMap _pedagogicalEnvelope(JsonMap profile) {
  return {
    if (profile['student_profile_internal'] != null)
      'student_profile_internal': profile['student_profile_internal'],
    if (profile['guidance_for_T02'] != null)
      'guidance_for_T02': profile['guidance_for_T02'],
    if (_pickProfileString(profile, ['preferred_name']).isNotEmpty)
      'preferred_name': _pickProfileString(profile, ['preferred_name']),
    if (_pickProfileString(profile, ['student_profile_notes']).isNotEmpty)
      'student_profile_notes': _pickProfileString(profile, [
        'student_profile_notes',
      ]),
    if (profile['interpreted_fields'] != null)
      'interpreted_fields': profile['interpreted_fields'],
    if (profile['curriculum_global_plan'] != null)
      'curriculum_global_plan': profile['curriculum_global_plan'],
    if (_pickProfileString(profile, [
      'target_topic',
      'TARGET_TOPIC',
    ]).isNotEmpty)
      'target_topic': _pickProfileString(profile, [
        'target_topic',
        'TARGET_TOPIC',
      ]),
    if (_pickProfileString(profile, ['subject']).isNotEmpty)
      'subject': _pickProfileString(profile, ['subject']),
    if (_pickProfileString(profile, ['exam_goal']).isNotEmpty)
      'exam_goal': _pickProfileString(profile, ['exam_goal']),
    if (_pickProfileString(profile, [
      'session_goal',
      'SESSION_GOAL',
    ]).isNotEmpty)
      'session_goal': _pickProfileString(profile, [
        'session_goal',
        'SESSION_GOAL',
      ]),
    if (_pickProfileString(profile, [
      'geographic_zone',
      'GEOGRAPHIC_ZONE',
    ]).isNotEmpty)
      'geographic_zone': _pickProfileString(profile, [
        'geographic_zone',
        'GEOGRAPHIC_ZONE',
      ]),
    if (_pickProfileString(profile, ['country_or_curriculum']).isNotEmpty)
      'country_or_curriculum': _pickProfileString(profile, [
        'country_or_curriculum',
      ]),
    if (_pickProfileString(profile, [
      'original_text_preserved',
      'objetivo',
    ]).isNotEmpty)
      'original_text_preserved': _pickProfileString(profile, [
        'original_text_preserved',
        'objetivo',
      ]),
  };
}
