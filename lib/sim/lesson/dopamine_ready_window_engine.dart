import 'dart:async';

import '../experience/curriculum_utils.dart';
import '../state/live_entry_state.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'lesson_models.dart';
import 'lesson_orchestrator.dart';
import 'lesson_readiness_resolver.dart';

const int offlineWarmCacheSize = 15;
const int localLessonTraySize = offlineWarmCacheSize;

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
    final selected = slots
        .take(maxSlots ?? (returnMode ? 2 : localLessonTraySize))
        .toList();
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
    _queueSecondaryMedia(lessonLocalId, source, mediaSlots);
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
      maxSlots: maxSlots ?? (returnMode ? 2 : localLessonTraySize),
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

  CompleteLesson _prepareMediaFromCachedLesson({
    required String lessonLocalId,
    required String source,
    required DopamineReadySlot slot,
    required CompleteLesson lesson,
  }) {
    _event(lessonLocalId, 'DOPAMINE_SLOT_MEDIA_REFRESH_REQUESTED', {
      'source': source,
      'slot': slot.slot,
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
      orchestrator.queueAudioForReadyLesson(entry.slot.params, entry.lesson);
      _event(lessonLocalId, 'DOPAMINE_SLOT_AUDIO_QUEUED', {
        'source': source,
        'slot': entry.slot.slot,
        'priority': 'current',
      });
    }
    for (final entry in current) {
      orchestrator.queueImageForReadyLesson(entry.slot.params, entry.lesson);
      _event(lessonLocalId, 'DOPAMINE_SLOT_IMAGE_QUEUED', {
        'source': source,
        'slot': entry.slot.slot,
        'priority': 'current',
      });
    }
    for (final entry in next) {
      orchestrator.queueAudioForReadyLesson(entry.slot.params, entry.lesson);
      _event(lessonLocalId, 'DOPAMINE_SLOT_AUDIO_QUEUED', {
        'source': source,
        'slot': entry.slot.slot,
        'priority': 'next',
      });
    }
    for (final entry in next) {
      orchestrator.queueImageForReadyLesson(entry.slot.params, entry.lesson);
      _event(lessonLocalId, 'DOPAMINE_SLOT_IMAGE_QUEUED', {
        'source': source,
        'slot': entry.slot.slot,
        'priority': 'next',
      });
    }
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
