import '../lesson/dopamine_ready_window_engine.dart';
import '../lesson/lesson_models.dart';
import '../lesson/student_lesson_material_service.dart';
import '../state/live_entry_state.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'classroom_models.dart';
import 'lesson_position_engine.dart';

class LessonMaterialController {
  LessonMaterialController({
    required this.stateService,
    required this.materialService,
    SimConstitutionalContract? constitutionalContract,
  }) : constitutionalContract =
           constitutionalContract ?? const SimConstitutionalContract();

  final StudentLearningStateService stateService;
  final StudentLessonMaterialService materialService;
  final SimConstitutionalContract constitutionalContract;
  LessonMaterialSource? lastAppliedMaterialSource;
  int lastAppliedMaterialWaitedMs = 0;
  static const int _hotAdvanceWaitAfterOrderMs = 0;
  static const int _hotAdvanceCachePolls = 40;
  static const Duration _hotAdvanceCachePollInterval = Duration(
    milliseconds: 5,
  );

  bool carregarRapidoSePronto({
    required String lessonLocalId,
    required String? topic,
    required LessonPositionState position,
    required String idioma,
    required String academic,
    required LessonMode mode,
    required List<PlannedItem> baseItems,
  }) {
    final item = position.itemAtivo;
    if (item == null) return false;
    final currentState = stateService.read(lessonLocalId);
    final params = _paramsForPosition(
      lessonLocalId: lessonLocalId,
      topic: topic,
      position: position,
      item: item,
      idioma: idioma,
      academic: academic,
      mode: mode,
      baseItems: baseItems,
      currentState: currentState,
    );
    final fast = materialService.resolveFastLessonMaterialFromStateOrCache(
      ResolveLessonMaterialInput(
        lessonLocalId: lessonLocalId,
        topic: topic,
        itemIdx: position.itemIdx,
        marker: item.marker,
        layer: position.layer,
        params: params,
      ),
    );
    if (fast == null) return false;
    _applyMaterial(position, fast);
    _mirrorDisplayedPreparedLesson(
      lessonLocalId: lessonLocalId,
      position: position,
      item: item,
      material: fast,
    );
    _markShowingFirstLessonIfNeeded(lessonLocalId, position, item);
    materialService.maintainLessonReadyWindow(
      lessonLocalId: lessonLocalId,
      topic: topic,
      itemIdx: position.itemIdx,
      layer: position.layer,
      items: baseItems
          .map(
            (item) => DopamineWindowItem(text: item.text, marker: item.marker),
          )
          .toList(),
      source: 'cyber.aula.fast-window',
      priority: 'hot-local',
      reason: 'fast_prepared_lesson_visible',
    );
    return true;
  }

  Future<void> carregar({
    required String lessonLocalId,
    required String? topic,
    required LessonPositionState position,
    required String idioma,
    required String academic,
    required LessonMode mode,
    required List<PlannedItem> baseItems,
    bool forceRefresh = false,
    bool allowRemoteOrder = false,
    int waitAfterOrderMs = 0,
    String missingSource = 'cyber.aula.local-preparation',
    String missingPriority = 'background',
    String missingReason = 'material_missing_prepare_without_fallback',
  }) async {
    final item = position.itemAtivo;
    if (item == null) {
      position.phase = const ClassroomPhase.doneEnd();
      return;
    }

    final currentState = stateService.read(lessonLocalId);
    final params = _paramsForPosition(
      lessonLocalId: lessonLocalId,
      topic: topic,
      position: position,
      item: item,
      idioma: idioma,
      academic: academic,
      mode: mode,
      baseItems: baseItems,
      currentState: currentState,
    );

    final fast = forceRefresh
        ? null
        : materialService.resolveFastLessonMaterialFromStateOrCache(
            ResolveLessonMaterialInput(
              lessonLocalId: lessonLocalId,
              topic: topic,
              itemIdx: position.itemIdx,
              marker: item.marker,
              layer: position.layer,
              params: params,
            ),
          );
    if (fast != null) {
      _applyMaterial(position, fast);
      _mirrorDisplayedPreparedLesson(
        lessonLocalId: lessonLocalId,
        position: position,
        item: item,
        material: fast,
      );
      _markShowingFirstLessonIfNeeded(lessonLocalId, position, item);
      materialService.maintainLessonReadyWindow(
        lessonLocalId: lessonLocalId,
        topic: topic,
        itemIdx: position.itemIdx,
        layer: position.layer,
        items: baseItems
            .map(
              (item) =>
                  DopamineWindowItem(text: item.text, marker: item.marker),
            )
            .toList(),
        source: 'cyber.aula.cache-window',
        priority: 'hot-local',
        reason: 'lesson_window_visible',
      );
      return;
    }

    position.phase = const ClassroomPhase.loading();
    position.imagem = null;
    position.imageMetadata = null;
    position.teoriaPronta = false;
    ResolveLessonMaterialResult? resolved;
    try {
      resolved = await materialService.resolveLessonMaterialFromStateOrEngine(
        ResolveLessonMaterialInput(
          lessonLocalId: lessonLocalId,
          topic: topic,
          itemIdx: position.itemIdx,
          marker: item.marker,
          layer: position.layer,
          params: params,
          forceRefresh: forceRefresh,
          waitBeforeOrderMs: 0,
          waitAfterOrderMs: waitAfterOrderMs,
          allowRemoteOrder: allowRemoteOrder,
        ),
      );
    } catch (_) {
      resolved = null;
    }
    if (resolved == null) {
      if (missingPriority == 'hot-local') {
        final hotRecovered = await _waitForHotPreparedMaterial(
          lessonLocalId: lessonLocalId,
          topic: topic,
          position: position,
          idioma: idioma,
          academic: academic,
          mode: mode,
          baseItems: baseItems,
        );
        if (hotRecovered) return;
      }
      position.phase = const ClassroomPhase.advancePending(
        message: 'aula_advance_preparing',
      );
      materialService.maintainLessonReadyWindow(
        lessonLocalId: lessonLocalId,
        topic: topic,
        itemIdx: position.itemIdx,
        layer: position.layer,
        items: baseItems
            .map(
              (item) =>
                  DopamineWindowItem(text: item.text, marker: item.marker),
            )
            .toList(),
        source: missingSource,
        priority: missingPriority,
        reason: missingReason,
      );
      return;
    }
    _applyMaterial(position, resolved);
    _mirrorDisplayedPreparedLesson(
      lessonLocalId: lessonLocalId,
      position: position,
      item: item,
      material: resolved,
    );
    _markShowingFirstLessonIfNeeded(lessonLocalId, position, item);
    materialService.maintainLessonReadyWindow(
      lessonLocalId: lessonLocalId,
      topic: topic,
      itemIdx: position.itemIdx,
      layer: position.layer,
      items: baseItems
          .map(
            (item) => DopamineWindowItem(text: item.text, marker: item.marker),
          )
          .toList(),
      source: 'cyber.aula.loaded-window',
      priority: 'hot-local',
      reason: 'lesson_loaded_keeps_ready_window_alive',
    );
  }

  Future<void> carregarTextoDeAvanco({
    required String lessonLocalId,
    required String? topic,
    required LessonPositionState position,
    required String idioma,
    required String academic,
    required LessonMode mode,
    required List<PlannedItem> baseItems,
  }) {
    return carregar(
      lessonLocalId: lessonLocalId,
      topic: topic,
      position: position,
      idioma: idioma,
      academic: academic,
      mode: mode,
      baseItems: baseItems,
      allowRemoteOrder: true,
      waitAfterOrderMs: _hotAdvanceWaitAfterOrderMs,
      missingSource: 'cyber.aula.advance-hot-miss',
      missingPriority: 'hot-local',
      missingReason: 'advance_hot_path_fetch_failed',
    );
  }

  Future<bool> _waitForHotPreparedMaterial({
    required String lessonLocalId,
    required String? topic,
    required LessonPositionState position,
    required String idioma,
    required String academic,
    required LessonMode mode,
    required List<PlannedItem> baseItems,
  }) async {
    for (var attempt = 0; attempt < _hotAdvanceCachePolls; attempt++) {
      await Future<void>.delayed(_hotAdvanceCachePollInterval);
      final loaded = carregarRapidoSePronto(
        lessonLocalId: lessonLocalId,
        topic: topic,
        position: position,
        idioma: idioma,
        academic: academic,
        mode: mode,
        baseItems: baseItems,
      );
      if (loaded) {
        stateService.appendEvent(
          lessonLocalId,
          StudentLearningEvent(
            type: 'ADVANCE_HOT_CACHE_RECOVERED',
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: {
              'itemIdx': position.itemIdx,
              'marker': position.itemAtivo?.marker,
              'layer': position.layer.value,
              'attempt': attempt + 1,
            },
          ),
        );
        return true;
      }
    }
    stateService.appendEvent(
      lessonLocalId,
      StudentLearningEvent(
        type: 'ADVANCE_HOT_CACHE_RECOVERY_EXHAUSTED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'itemIdx': position.itemIdx,
          'marker': position.itemAtivo?.marker,
          'layer': position.layer.value,
          'attempts': _hotAdvanceCachePolls,
        },
      ),
    );
    return false;
  }

  CompleteLessonParams _paramsForPosition({
    required String lessonLocalId,
    required String? topic,
    required LessonPositionState position,
    required PlannedItem item,
    required String idioma,
    required String academic,
    required LessonMode mode,
    required List<PlannedItem> baseItems,
    required StudentLearningState? currentState,
  }) {
    return CompleteLessonParams(
      lessonLocalId: lessonLocalId,
      item: item.text,
      lang: idioma,
      academic: academic,
      layer: position.layer,
      mode: mode,
      errCount: position.erros,
      history: position.historia,
      marker: item.marker,
      amparoLvl: currentState?.progress?.amparoLvl,
      curriculumItems: _curriculumSnapshot(baseItems),
      topic: topic,
      itemIdx: position.itemIdx,
      pedagogicalEnvelope: _pedagogicalEnvelope(
        currentState?.profile.toJson() ?? const {},
        item,
      ),
    );
  }

  void _applyMaterial(
    LessonPositionState position,
    ResolveLessonMaterialResult material,
  ) {
    constitutionalContract.assertLessonMaterial(material.conteudo);
    lastAppliedMaterialSource = material.source;
    lastAppliedMaterialWaitedMs = material.waitedMs;
    position.conteudo = material.conteudo;
    position.imagem = material.imagem;
    position.imageMetadata = material.imageMetadata;
    position.teoriaPronta = true;
    position.phase = const ClassroomPhase.reading();
  }

  void _mirrorDisplayedPreparedLesson({
    required String lessonLocalId,
    required LessonPositionState position,
    required PlannedItem item,
    required ResolveLessonMaterialResult material,
  }) {
    stateService.mutate(lessonLocalId, (state) {
      return state.copyWith(
        currentLessonMaterial: {
          'text_status': 'ready',
          ...material.conteudo.toJson(),
          'generated_at': DateTime.now().toIso8601String(),
          'model': 'T02-display',
          'prompt_contract_version': 'T02_content.v3',
          'for_itemIdx': position.itemIdx,
          'for_marker': item.marker,
          'for_layer': position.layer.name,
        },
      );
    });
  }

  void _markShowingFirstLessonIfNeeded(
    String lessonLocalId,
    LessonPositionState position,
    PlannedItem item,
  ) {
    if (position.itemIdx != 0 || position.layer != LessonLayer.l1) return;
    updateLiveEntryState(
      stateService,
      lessonLocalId,
      status: LiveEntryStatus.showingFirstLesson,
      firstItemMarker: item.marker,
      firstLessonMaterialKey: firstLessonMaterialKey(item.marker),
      firstLessonReadyAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  JsonMap _pedagogicalEnvelope(JsonMap profile, PlannedItem item) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = profile[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return '';
    }

    return {
      if (item.marker.isNotEmpty) 'marker': item.marker,
      if ((item.unit ?? '').trim().isNotEmpty) 'unit': item.unit!.trim(),
      if ((item.title ?? '').trim().isNotEmpty) 'title': item.title!.trim(),
      if (pick(['stableLang', 'STABLE_LANG', 'idioma']).isNotEmpty)
        'stable_lang': pick(['stableLang', 'STABLE_LANG', 'idioma']),
      if (pick(['academic_level', 'ACADEMIC_LEVEL']).isNotEmpty)
        'academic_level': pick(['academic_level', 'ACADEMIC_LEVEL']),
      if (profile['student_profile_internal'] != null)
        'student_profile_internal': profile['student_profile_internal'],
      if (profile['guidance_for_T02'] != null)
        'guidance_for_T02': profile['guidance_for_T02'],
      if (pick(['preferred_name']).isNotEmpty)
        'preferred_name': pick(['preferred_name']),
      if (pick(['student_profile_notes']).isNotEmpty)
        'student_profile_notes': pick(['student_profile_notes']),
      if (profile['interpreted_fields'] != null)
        'interpreted_fields': profile['interpreted_fields'],
      if (profile['curriculum_global_plan'] != null)
        'curriculum_global_plan': profile['curriculum_global_plan'],
      if (pick(['target_topic', 'TARGET_TOPIC']).isNotEmpty)
        'target_topic': pick(['target_topic', 'TARGET_TOPIC']),
      if (pick(['subject']).isNotEmpty) 'subject': pick(['subject']),
      if (pick(['exam_goal']).isNotEmpty) 'exam_goal': pick(['exam_goal']),
      if (pick(['session_goal', 'SESSION_GOAL']).isNotEmpty)
        'session_goal': pick(['session_goal', 'SESSION_GOAL']),
      if (pick(['geographic_zone', 'GEOGRAPHIC_ZONE']).isNotEmpty)
        'geographic_zone': pick(['geographic_zone', 'GEOGRAPHIC_ZONE']),
      if (pick(['country_or_curriculum']).isNotEmpty)
        'country_or_curriculum': pick(['country_or_curriculum']),
      if (pick(['original_text_preserved']).isNotEmpty)
        'original_text_preserved': pick(['original_text_preserved']),
    };
  }

  List<JsonMap> _curriculumSnapshot(List<PlannedItem> items) {
    return [
      for (var index = 0; index < items.length; index += 1)
        {
          ...items[index].extra,
          'order': index + 1,
          'marker': items[index].marker,
          if ((items[index].unit ?? '').trim().isNotEmpty)
            'unit': items[index].unit!.trim(),
          'title': items[index].text,
          'text': items[index].text,
          'purpose': items[index].text,
          'microitem_for_teacher': items[index].text,
        },
    ];
  }
}
