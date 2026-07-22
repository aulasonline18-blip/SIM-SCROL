import 'dart:async';

import '../experience/curriculum_utils.dart';
// ignore: unused_import
import '../localization/sim_locale_contract.dart';
import '../media/slot_media_contract.dart';
import '../state/live_entry_state.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'lesson_content_validator.dart';
import 'lesson_models.dart';
import 'lesson_orchestrator.dart';
import 'lesson_readiness_resolver.dart';

part 'ready_window/ready_window_planner.dart';
part 'ready_window/ready_window_health.dart';
part 'ready_window/ready_window_media.dart';
part 'ready_window/ready_window_executor.dart';

const int offlineWarmCacheSize = 15;
const int localLessonTraySize = offlineWarmCacheSize;
const int hotTextWindowSize = 4;

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
  required bool windowQueued,
  required String idempotencyKey,
  required String? marker,
}) {
  final hotWindow = window.take(hotTextWindowSize).toList(growable: false);
  final readyHotMaterials = <String, JsonMap>{};
  final missingHotSlots = <JsonMap>[];
  var mediaPending = 0;
  for (final slot in hotWindow) {
    final key = preparedLessonMaterialKey(
      slot.idx,
      slot.item.marker,
      slot.layer,
    );
    final material = readyMaterials[key];
    if (material != null &&
        _isReadyMaterialForWindowSlot(material: material, slot: slot)) {
      readyHotMaterials[key] = material;
      final image = material['imagem'] as String?;
      if (image == null || image.trim().isEmpty) mediaPending += 1;
    } else {
      missingHotSlots.add({
        'itemIdx': slot.idx,
        'marker': slot.item.marker,
        'layer': slot.layer.value,
        'preparedKey': key,
      });
    }
  }
  final hotQueuedCount = windowQueued ? missingHotSlots.length : 0;
  final hotMissingCount = windowQueued ? 0 : missingHotSlots.length;
  final readyWarmCount = readyMaterials.entries.where((entry) {
    return window.any((slot) {
      final key = preparedLessonMaterialKey(
        slot.idx,
        slot.item.marker,
        slot.layer,
      );
      return key == entry.key &&
          _isReadyMaterialForWindowSlot(material: entry.value, slot: slot);
    });
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
        'cachedCount': readyWarmCount,
        'expectedHotCount': hotWindow.length,
        'hotTextReadyCount': readyHotMaterials.length,
        'hotQueuedCount': hotQueuedCount,
        'hotMissingCount': hotMissingCount,
        'hotMissingSlots': windowQueued ? const <JsonMap>[] : missingHotSlots,
      },
    ),
    StudentLearningEvent(
      type: 'DOPAMINE_WINDOW_HEALTH_CHECKED',
      ts: ts,
      payload: {
        'source': source,
        'reason': reason,
        'expectedCount': window.length,
        'readyCount': readyWarmCount,
        'queuedCount': windowQueued ? 1 : 0,
        'missingCount': windowQueued
            ? 0
            : (window.length - readyWarmCount).clamp(0, window.length),
        'expectedHotCount': hotWindow.length,
        'hotTextReadyCount': readyHotMaterials.length,
        'hotQueuedCount': hotQueuedCount,
        'hotMissingCount': hotMissingCount,
        'hotMissingSlots': windowQueued ? const <JsonMap>[] : missingHotSlots,
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
        'ready': readyWarmCount,
        'queued': windowQueued ? 1 : 0,
        'missing': windowQueued
            ? 0
            : (window.length - readyWarmCount).clamp(0, window.length),
        'expectedHotCount': hotWindow.length,
        'hotTextReadyCount': readyHotMaterials.length,
        'hotQueuedCount': hotQueuedCount,
        'hotMissingCount': hotMissingCount,
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

bool _isReadyMaterialForWindowSlot({
  required JsonMap material,
  required ({int offset, int idx, DopamineWindowItem item, LessonLayer layer})
  slot,
}) {
  if (material['text_status'] != 'ready') return false;
  if (material['for_itemIdx'] != slot.idx) return false;
  if (material['for_layer'] != slot.layer.name) return false;
  if ((material['for_marker'] as String?) != slot.item.marker) return false;
  try {
    validatedLessonContentFromJson(material);
    return true;
  } on LessonContentValidationException {
    return false;
  }
}

class DopamineReadyWindowEngine {
  DopamineReadyWindowEngine({
    required this.service,
    required this.orchestrator,
    this.readinessResolver = const LessonReadinessResolver(),
    ReadyWindowPlanner? planner,
    ReadyWindowHealth? health,
    ReadyWindowMedia? media,
  }) : _planner = planner ?? const ReadyWindowPlanner(),
       _health =
           health ??
           ReadyWindowHealth(
             service: service,
             orchestrator: orchestrator,
             readinessResolver: readinessResolver,
           ),
       _media =
           media ??
           ReadyWindowMedia(service: service, orchestrator: orchestrator);

  final StudentLearningStateService service;
  final LessonOrchestrator orchestrator;
  final LessonReadinessResolver readinessResolver;
  final ReadyWindowPlanner _planner;
  final ReadyWindowHealth _health;
  final ReadyWindowMedia _media;
  late final ReadyWindowExecutor _executor = ReadyWindowExecutor(
    service: service,
    orchestrator: orchestrator,
    readinessResolver: readinessResolver,
    planner: _planner,
    health: _health,
    media: _media,
  );

  List<({int offset, int idx, DopamineWindowItem item, LessonLayer layer})>
  buildDopamineWindowPlan({
    required int fromIdx,
    required LessonLayer layer,
    required List<DopamineWindowItem> items,
    int maxSlots = localLessonTraySize,
  }) {
    return _planner.buildDopamineWindowPlan(
      fromIdx: fromIdx,
      layer: layer,
      items: items,
      maxSlots: maxSlots,
    );
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
    return _planner.buildDopamineReadySlots(
      lessonLocalId: lessonLocalId,
      source: source,
      items: items,
      currentItemIdx: currentItemIdx,
      currentLayer: currentLayer,
      buildParams: buildParams,
      maxSlots: maxSlots,
    );
  }

  Future<List<bool>> maintainDopamineReadyWindow({
    required String lessonLocalId,
    required String source,
    required List<DopamineReadySlot> slots,
    String? topic,
    bool returnMode = false,
    int? maxSlots,
  }) async {
    return _executor.maintainDopamineReadyWindow(
      lessonLocalId: lessonLocalId,
      source: source,
      slots: slots,
      topic: topic,
      returnMode: returnMode,
      maxSlots: maxSlots,
    );
  }

  DopamineReadyWindowHealth inspectDopamineReadyWindow({
    required String lessonLocalId,
    required List<DopamineReadySlot> slots,
    required String source,
    String? reason,
  }) {
    return _health.inspectDopamineReadyWindow(
      lessonLocalId: lessonLocalId,
      slots: slots,
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
    return _executor.runDopamineReadyWindowFromStudentState(
      lessonLocalId: lessonLocalId,
      source: source,
      maxSlots: maxSlots,
      returnMode: returnMode,
      itemIdx: itemIdx,
      layer: layer,
      marker: marker,
      topic: topic,
    );
  }
}

JsonMap readyWindowSlotJson(DopamineReadySlot slot) => {
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
