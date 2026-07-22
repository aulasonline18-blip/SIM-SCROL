import 'dart:async';
import '../experience/curriculum_utils.dart';
import '../localization/sim_locale_contract.dart';
import '../state/live_entry_state.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import '../media/lesson_image_api_contract.dart';
import '../media/student_lesson_media_service.dart';
import 'dopamine_ready_window_engine.dart';
import 'lesson_models.dart';
import 'lesson_orchestrator.dart';
import 'lesson_readiness_resolver.dart';
import 'ready_window_worker.dart';

part 'student_lesson_material_failures.dart';

enum LessonMaterialSource {
  studentState,
  studentStateAfterWait,
  memoryCacheFromMotor,
}

class ResolveLessonMaterialInput {
  const ResolveLessonMaterialInput({
    required this.lessonLocalId,
    required this.topic,
    required this.itemIdx,
    required this.marker,
    required this.layer,
    required this.params,
    this.forceRefresh = false,
    this.waitBeforeOrderMs = 2000,
    this.waitAfterOrderMs = 12000,
    this.allowRemoteOrder = false,
    this.remoteOrderPriority = 'background',
    this.onBackgroundResolved,
  });

  final String lessonLocalId;
  final String? topic;
  final int itemIdx;
  final String? marker;
  final LessonLayer layer;
  final CompleteLessonParams params;
  final bool forceRefresh;
  final int waitBeforeOrderMs;
  final int waitAfterOrderMs;
  final bool allowRemoteOrder;
  final String remoteOrderPriority;
  final void Function(ResolveLessonMaterialResult result)? onBackgroundResolved;
}

class ResolveLessonMaterialResult {
  const ResolveLessonMaterialResult({
    required this.conteudo,
    required this.imagem,
    required this.source,
    required this.waitedMs,
    this.imageMetadata,
    this.localeContract,
  });

  final LessonContent conteudo;
  final String? imagem;
  final LessonMaterialSource source;
  final int waitedMs;
  final LessonImageGenerationMetadata? imageMetadata;
  final SimLocaleContract? localeContract;
}

class StudentLessonMaterialService {
  StudentLessonMaterialService({
    required this.stateService,
    required this.orchestrator,
    required this.readyWindowEngine,
    this.mediaService,
  }) {
    final previousOnImageReady = orchestrator.onImageReady;
    orchestrator.onImageReady = (params, lesson) {
      previousOnImageReady?.call(params, lesson);
      _mirrorImageReady(params, lesson);
      _markImageReady(params, lesson);
    };
    final previousOnImageStarted = orchestrator.onImageStarted;
    orchestrator.onImageStarted = (params, lesson) {
      previousOnImageStarted?.call(params, lesson);
      _markImageStarted(params, lesson);
    };
    final previousOnImageFailed = orchestrator.onImageFailed;
    orchestrator.onImageFailed = (params, lesson) {
      previousOnImageFailed?.call(params, lesson);
      _markImageFailed(params, lesson);
    };
    final previousOnNoImage = orchestrator.onNoImage;
    orchestrator.onNoImage = (params, lesson) {
      previousOnNoImage?.call(params, lesson);
      _markNoImage(params, lesson);
    };
  }

  final StudentLearningStateService stateService;
  final LessonOrchestrator orchestrator;
  final DopamineReadyWindowEngine readyWindowEngine;
  final StudentLessonMediaService? mediaService;
  final Map<String, ResolveLessonMaterialInput> _inputsByLessonKey = {};
  final Map<String, void Function()> _imageUnsubscribersByLessonKey = {};
  final LessonReadinessResolver _readinessResolver =
      const LessonReadinessResolver();
  ResolveLessonMaterialResult? resolveFastLessonMaterialFromStateOrCache(
    ResolveLessonMaterialInput input,
  ) {
    _rememberInput(input);
    final stateReadiness = _readinessResolver.resolveFromState(
      state: stateService.read(input.lessonLocalId),
      identity: _identityFor(input),
      params: input.params,
    );
    if (_shouldDiscardReadiness(stateReadiness)) {
      _discardUnreadableReadyMaterial(input, stateReadiness);
    }
    final readyFromState = stateReadiness.lesson;
    if (stateReadiness.status == LessonReadinessStatus.readyFromState &&
        readyFromState != null) {
      final visualReady = orchestrator.ensureVisualForReadyLesson(
        input.params,
        readyFromState.conteudo,
        priority: 'hot-local',
        initialImage: readyFromState.imagem,
      );
      _prepareLessonAudio(input, visualReady.conteudo);
      _mirrorCurrentLessonMaterial(input, visualReady);
      _appendLessonTextReady(
        input,
        visualReady.conteudo,
        LessonMaterialSource.studentState,
        0,
      );
      _appendInstantExperienceMetric(
        input,
        source: LessonMaterialSource.studentState,
        textReadyMs: 0,
      );
      return ResolveLessonMaterialResult(
        conteudo: visualReady.conteudo,
        imagem: visualReady.imagem,
        source: LessonMaterialSource.studentState,
        waitedMs: 0,
        imageMetadata: visualReady.imageMetadata,
        localeContract: visualReady.localeContract,
      );
    }
    final cacheReadiness = _readinessResolver.resolveFromMemoryCache(
      orchestrator: orchestrator,
      params: input.params,
    );
    final lesson = cacheReadiness.lesson;
    if (lesson == null) return null;
    final visualReady = orchestrator.ensureVisualForReadyLesson(
      input.params,
      lesson.conteudo,
      priority: 'hot-local',
    );
    _prepareLessonAudio(input, visualReady.conteudo);
    _mirrorCurrentLessonMaterial(input, visualReady);
    _appendLessonTextReady(
      input,
      visualReady.conteudo,
      LessonMaterialSource.memoryCacheFromMotor,
      0,
    );
    _appendInstantExperienceMetric(
      input,
      source: LessonMaterialSource.memoryCacheFromMotor,
      textReadyMs: 0,
    );
    return ResolveLessonMaterialResult(
      conteudo: visualReady.conteudo,
      imagem: visualReady.imagem,
      source: LessonMaterialSource.memoryCacheFromMotor,
      waitedMs: 0,
      imageMetadata: visualReady.imageMetadata,
      localeContract: visualReady.localeContract,
    );
  }

  Future<ResolveLessonMaterialResult?> resolveLessonMaterialFromStateOrEngine(
    ResolveLessonMaterialInput input,
  ) async {
    _rememberInput(input);
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    final fast = input.forceRefresh
        ? null
        : resolveFastLessonMaterialFromStateOrCache(input);
    if (fast != null) return fast;
    if (!input.forceRefresh &&
        input.waitBeforeOrderMs > 0 &&
        orchestrator.isLessonBusy) {
      await Future<void>.delayed(
        Duration(milliseconds: input.waitBeforeOrderMs),
      );
      final afterWait = resolveFastLessonMaterialFromStateOrCache(input);
      if (afterWait != null) {
        final waitedMs = DateTime.now().millisecondsSinceEpoch - startedAt;
        _appendLessonWaitApplied(
          input,
          stage: 'before_order',
          waitedMs: waitedMs,
          resolved: true,
        );
        return afterWait;
      }
      _appendLessonWaitApplied(
        input,
        stage: 'before_order',
        waitedMs: DateTime.now().millisecondsSinceEpoch - startedAt,
        resolved: false,
      );
    }
    if (!input.allowRemoteOrder) return null;
    final lessonFuture = orchestrator.prefetchCompleteLesson(
      input.params,
      priority: input.remoteOrderPriority,
    );
    if (input.waitAfterOrderMs <= 0) {
      unawaited(
        lessonFuture
            .then((lesson) {
              _mirrorPreparedAndCurrentLessonMaterial(input, lesson);
              final result = ResolveLessonMaterialResult(
                conteudo: lesson.conteudo,
                imagem: lesson.imagem,
                source: LessonMaterialSource.studentStateAfterWait,
                waitedMs: DateTime.now().millisecondsSinceEpoch - startedAt,
                imageMetadata: lesson.imageMetadata,
                localeContract: lesson.localeContract,
              );
              _appendLessonTextReady(
                input,
                lesson.conteudo,
                LessonMaterialSource.studentStateAfterWait,
                result.waitedMs,
              );
              input.onBackgroundResolved?.call(result);
            })
            .catchError((Object error) {
              appendBackgroundMaterialFailed(input, error);
              return null;
            }),
      );
      _appendLessonWaitApplied(
        input,
        stage: 'after_order_background',
        waitedMs: DateTime.now().millisecondsSinceEpoch - startedAt,
        resolved: false,
      );
      return null;
    }
    final CompleteLesson lesson;
    try {
      lesson = await lessonFuture.timeout(
        Duration(milliseconds: input.waitAfterOrderMs),
      );
    } on TimeoutException {
      final afterTimeout = input.forceRefresh
          ? null
          : resolveFastLessonMaterialFromStateOrCache(input);
      _appendLessonWaitApplied(
        input,
        stage: 'after_order_timeout',
        waitedMs: DateTime.now().millisecondsSinceEpoch - startedAt,
        resolved: afterTimeout != null,
      );
      return afterTimeout;
    }
    _mirrorPreparedAndCurrentLessonMaterial(input, lesson);
    final waitedMs = DateTime.now().millisecondsSinceEpoch - startedAt;
    _appendLessonTextReady(
      input,
      lesson.conteudo,
      LessonMaterialSource.studentStateAfterWait,
      waitedMs,
    );
    _appendInstantExperienceMetric(
      input,
      source: LessonMaterialSource.studentStateAfterWait,
      textReadyMs: waitedMs,
    );
    return ResolveLessonMaterialResult(
      conteudo: lesson.conteudo,
      imagem: lesson.imagem,
      source: LessonMaterialSource.studentStateAfterWait,
      waitedMs: waitedMs,
      imageMetadata: lesson.imageMetadata,
      localeContract: lesson.localeContract,
    );
  }

  void _rememberInput(ResolveLessonMaterialInput input) {
    final key = lessonKeyFor(input.params);
    _inputsByLessonKey[key] = input;
    _imageUnsubscribersByLessonKey.putIfAbsent(
      key,
      () => orchestrator.bus.subscribe(key, (lesson) {
        if (lesson.imagem == null || lesson.imagem!.trim().isEmpty) return;
        _mirrorImageReady(input.params, lesson);
      }),
    );
  }

  void _appendLessonTextReady(
    ResolveLessonMaterialInput input,
    LessonContent content,
    LessonMaterialSource source,
    int waitedMs,
  ) {
    stateService.appendEvent(
      input.lessonLocalId,
      StudentLearningEvent(
        type: 'LESSON_TEXT_READY',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'lessonLocalId': input.lessonLocalId,
          'itemIdx': input.itemIdx,
          'marker': input.marker,
          'layer': input.layer.value,
          'mode': input.params.mode.name,
          'source': source.name,
          'waitedMs': waitedMs,
          'question': content.question,
        },
      ),
    );
  }

  void _appendInstantExperienceMetric(
    ResolveLessonMaterialInput input, {
    required LessonMaterialSource source,
    required int textReadyMs,
  }) {
    stateService.appendEvent(
      input.lessonLocalId,
      StudentLearningEvent(
        type: 'INSTANT_EXPERIENCE_MEASURED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'lessonLocalId': input.lessonLocalId,
          'itemIdx': input.itemIdx,
          'marker': input.marker,
          'layer': input.layer.value,
          'source': source.name,
          'textReadyMs': textReadyMs,
          'mediaMeasuredSeparately': true,
          'warmCacheCount': orchestrator.warmCacheEntryCount,
          'coldCacheCount': orchestrator.coldCacheEntryCount,
        },
      ),
    );
  }

  void _appendLessonWaitApplied(
    ResolveLessonMaterialInput input, {
    required String stage,
    required int waitedMs,
    required bool resolved,
  }) {
    stateService.appendEvent(
      input.lessonLocalId,
      StudentLearningEvent(
        type: 'LESSON_MATERIAL_WAIT_APPLIED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'lessonLocalId': input.lessonLocalId,
          'itemIdx': input.itemIdx,
          'marker': input.marker,
          'layer': input.layer.value,
          'stage': stage,
          'waitedMs': waitedMs,
          'resolved': resolved,
          'waitBeforeOrderMs': input.waitBeforeOrderMs,
          'waitAfterOrderMs': input.waitAfterOrderMs,
        },
      ),
    );
  }

  void prepareReadyWindowInBackground({
    required String lessonLocalId,
    required String? topic,
    required int itemIdx,
    required LessonLayer layer,
    required String? marker,
    required String source,
  }) {
    stateService.appendEvent(
      lessonLocalId,
      StudentLearningEvent(
        type: 'BACKGROUND_READY_WINDOW_STARTED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'source': source,
          'itemIdx': itemIdx,
          'marker': marker,
          'layer': layer.value,
          'maxSlots': offlineWarmCacheSize,
        },
      ),
    );
    unawaited(
      readyWindowEngine
          .runDopamineReadyWindowFromStudentState(
            lessonLocalId: lessonLocalId,
            source: source,
            maxSlots: offlineWarmCacheSize,
            itemIdx: itemIdx,
            layer: layer,
            marker: marker,
            topic: topic,
          )
          .then((result) {
            stateService.appendEvent(
              lessonLocalId,
              StudentLearningEvent(
                type: 'BACKGROUND_READY_WINDOW_READY',
                ts: DateTime.now().millisecondsSinceEpoch,
                payload: {
                  'source': source,
                  'ready': result.where((ready) => ready).length,
                  'requested': result.length,
                },
              ),
            );
          })
          .catchError((Object _) {
            _queueReadyWindowRetryFromState(
              lessonLocalId: lessonLocalId,
              topic: topic,
              itemIdx: itemIdx,
              layer: layer,
              marker: marker,
              source: '$source.retry',
            );
            stateService.appendEvent(
              lessonLocalId,
              StudentLearningEvent(
                type: 'BACKGROUND_READY_WINDOW_FAILED',
                ts: DateTime.now().millisecondsSinceEpoch,
                payload: {
                  'source': source,
                  'error_code': 'LESSON_READY_WINDOW_FAILED',
                },
              ),
            );
          }),
    );
  }

  void maintainLessonReadyWindow({
    required String lessonLocalId,
    required String? topic,
    required int itemIdx,
    required LessonLayer layer,
    required List<DopamineWindowItem> items,
    required String source,
    String priority = 'background',
    String? reason,
  }) {
    final window = readyWindowEngine.buildDopamineWindowPlan(
      fromIdx: itemIdx,
      layer: layer,
      items: items,
    );
    stateService.mutate(lessonLocalId, (state) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final marker = items.length > itemIdx ? items[itemIdx].marker : null;
      final localeIdentity = state.localeContract.cacheIdentity();
      final idempotencyKey = [
        'ready-window',
        lessonLocalId,
        localeIdentity,
        itemIdx,
        marker ?? '',
        'L${layer.value}',
      ].join(':');
      final jobs = [...state.queuedActions];
      final hotSlots = window
          .take(hotTextWindowSize)
          .map((slot) {
            return {
              'itemIdx': slot.idx,
              'marker': slot.item.marker,
              'layer': slot.layer.value,
              'localeCacheIdentity': localeIdentity,
              'preparedKey': preparedLessonMaterialKey(
                slot.idx,
                slot.item.marker,
                slot.layer,
              ),
            };
          })
          .toList(growable: false);
      final duplicateIndex = jobs.indexWhere(
        (job) =>
            job['type'] == 'PREPARE_READY_WINDOW' &&
            job['idempotency_key'] == idempotencyKey &&
            (job['status'] == 'queued' ||
                job['status'] == 'running' ||
                job['status'] == 'failed'),
      );
      var promotedHot = false;
      var windowQueued = false;
      if (duplicateIndex < 0) {
        windowQueued = true;
        jobs.add({
          'job_id': 'PREPARE_READY_WINDOW:$idempotencyKey:$now',
          'type': 'PREPARE_READY_WINDOW',
          'status': 'queued',
          'idempotency_key': idempotencyKey,
          'priority': priority,
          'source': source,
          'payload': {
            'maxSlots': localLessonTraySize,
            'reason': reason ?? 'lesson_window_visible',
            'itemIdx': itemIdx,
            'layer': layer.value,
            'marker': marker,
            'topic': topic,
            'hotSlots': hotSlots,
          },
          'created_at': now,
          'started_at': null,
          'finished_at': null,
          'error': null,
          'attempts': 0,
          'max_attempts': readyWindowWorkerMaxAttempts,
          'next_retry_at': null,
        });
      } else if (priority == 'hot-local' &&
          jobs[duplicateIndex]['priority'] != 'hot-local' &&
          jobs[duplicateIndex]['status'] == 'queued') {
        promotedHot = true;
        windowQueued = true;
        jobs[duplicateIndex] = {
          ...jobs[duplicateIndex],
          'priority': 'hot-local',
          'source': source,
          'payload': {
            ...JsonMap.from(
              jobs[duplicateIndex]['payload'] as Map? ?? const {},
            ),
            'reason': reason ?? 'lesson_window_visible',
            'hotSlots': hotSlots,
          },
          'next_retry_at': null,
        };
      } else {
        final duplicateStatus = jobs[duplicateIndex]['status'];
        windowQueued =
            duplicateStatus == 'queued' || duplicateStatus == 'running';
      }
      final hotKeys = {
        for (final slot in window)
          preparedLessonMaterialKey(slot.idx, slot.item.marker, slot.layer),
      };
      final hotReadyMaterials = {
        for (final entry in state.readyLessonMaterials.entries)
          if (hotKeys.contains(entry.key)) entry.key: entry.value,
      };
      return state.copyWith(
        readyLessonMaterials: hotReadyMaterials,
        queuedActions: jobs,
        events: [
          ...state.events,
          ...dopamineWindowServiceEvents(
            ts: now,
            lessonLocalId: lessonLocalId,
            source: source,
            reason: reason ?? 'lesson_window_visible',
            currentItemIdx: itemIdx,
            currentLayer: layer,
            window: window,
            readyMaterials: hotReadyMaterials,
            promotedHot: promotedHot,
            windowQueued: windowQueued,
            idempotencyKey: idempotencyKey,
            marker: marker,
          ),
        ],
      );
    }, allowLocalHousekeeping: true);
  }

  void _queueReadyWindowRetryFromState({
    required String lessonLocalId,
    required String? topic,
    required int itemIdx,
    required LessonLayer layer,
    required String? marker,
    required String source,
  }) {
    final state = stateService.read(lessonLocalId);
    final curriculumItems =
        state?.curriculum?.items ?? const <CurriculumItem>[];
    final items = curriculumItems
        .map(
          (item) =>
              DopamineWindowItem(text: itemText(item), marker: item.marker),
        )
        .where((item) => item.text.trim().isNotEmpty)
        .toList(growable: false);
    if (items.isEmpty) return;
    final markerIdx = marker == null
        ? -1
        : items.indexWhere((item) => item.marker == marker);
    final effectiveIdx = markerIdx >= 0
        ? markerIdx
        : itemIdx.clamp(0, items.length - 1);
    maintainLessonReadyWindow(
      lessonLocalId: lessonLocalId,
      topic: topic,
      itemIdx: effectiveIdx,
      layer: layer,
      source: source,
      reason: 'background_ready_window_retry',
      items: items,
    );
  }

  CompleteLesson? _readReadyFromStudentState(ResolveLessonMaterialInput input) {
    final result = _readinessResolver.resolveFromState(
      state: stateService.read(input.lessonLocalId),
      identity: _identityFor(input),
      params: input.params,
    );
    if (_shouldDiscardReadiness(result)) {
      _discardUnreadableReadyMaterial(input, result);
    }
    return result.status == LessonReadinessStatus.readyFromState
        ? result.lesson
        : null;
  }

  String? _stringOrNull(Object? value) {
    final text = value?.toString();
    return text == null || text.trim().isEmpty ? null : text;
  }

  void _mirrorImageReady(CompleteLessonParams params, CompleteLesson lesson) {
    if (lesson.imagem == null || lesson.imagem!.trim().isEmpty) return;
    final input = _inputsByLessonKey[lessonKeyFor(params)];
    if (input == null) return;
    final key = preparedLessonMaterialKey(
      input.itemIdx,
      input.marker,
      input.layer,
    );
    final material = preparedMaterialFromLesson(
      lesson: lesson,
      itemIdx: input.itemIdx,
      marker: input.marker,
      layer: input.layer,
    );
    stateService.mutate(input.lessonLocalId, (state) {
      return state.copyWith(
        lessonLocalId: input.lessonLocalId,
        currentLessonMaterial: material,
        readyLessonMaterials: {...state.readyLessonMaterials, key: material},
      );
    });
  }

  void _mirrorCurrentLessonMaterial(
    ResolveLessonMaterialInput input,
    CompleteLesson lesson,
  ) {
    stateService.mutate(input.lessonLocalId, (state) {
      return state.copyWith(
        lessonLocalId: input.lessonLocalId,
        currentLessonMaterial: _preparedMaterialPreservingImage(
          input,
          lesson,
          state,
        ),
      );
    });
  }

  void _mirrorPreparedAndCurrentLessonMaterial(
    ResolveLessonMaterialInput input,
    CompleteLesson lesson,
  ) {
    final key = preparedLessonMaterialKey(
      input.itemIdx,
      input.marker,
      input.layer,
    );
    stateService.mutate(input.lessonLocalId, (state) {
      final material = _preparedMaterialPreservingImage(input, lesson, state);
      return state.copyWith(
        lessonLocalId: input.lessonLocalId,
        currentLessonMaterial: material,
        readyLessonMaterials: {...state.readyLessonMaterials, key: material},
      );
    });
  }

  JsonMap _preparedMaterialPreservingImage(
    ResolveLessonMaterialInput input,
    CompleteLesson lesson,
    StudentLearningState state,
  ) {
    final material = preparedMaterialFromLesson(
      lesson: lesson,
      itemIdx: input.itemIdx,
      marker: input.marker,
      layer: input.layer,
    );
    if ((material['imagem'] as String?)?.trim().isNotEmpty == true) {
      return material;
    }
    final key = preparedLessonMaterialKey(
      input.itemIdx,
      input.marker,
      input.layer,
    );
    final existing =
        state.readyLessonMaterials[key] ?? state.currentLessonMaterial;
    final cached = orchestrator.peekCachedLesson(lessonKeyFor(input.params));
    final image = _stringOrNull(existing?['imagem']) ?? cached?.imagem;
    if (image == null) return material;
    return {
      ...material,
      'imagem': image,
      if (cached?.imageMetadata != null && !cached!.imageMetadata!.isEmpty)
        'imageMetadata': cached.imageMetadata!.toJson()
      else if (existing?['imageMetadata'] != null)
        'imageMetadata': existing?['imageMetadata'],
    };
  }

  CompleteLesson? readReadyLessonMaterialFromStudentState(
    ResolveLessonMaterialInput input,
  ) {
    final lesson = _readReadyFromStudentState(input);
    if (lesson == null) return null;
    stateService.appendEvent(
      input.lessonLocalId,
      StudentLearningEvent(
        type: 'LESSON_TEXT_READY',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'lessonLocalId': input.lessonLocalId,
          'itemIdx': input.itemIdx,
          'marker': input.marker,
          'layer': input.layer.value,
          'source': 'state',
          'resume_instantaneo': true,
        },
      ),
    );
    return orchestrator.ensureVisualForReadyLesson(
      input.params,
      lesson.conteudo,
      priority: 'hot-local',
      initialImage: null,
    );
  }

  bool isLessonMaterialReadyInStateOrCache(ResolveLessonMaterialInput input) {
    final stateResult = _readinessResolver.resolveFromState(
      state: stateService.read(input.lessonLocalId),
      identity: _identityFor(input),
      params: input.params,
    );
    if (_shouldDiscardReadiness(stateResult)) {
      _discardUnreadableReadyMaterial(input, stateResult);
    }
    if (stateResult.isReady) return true;
    return _readinessResolver
        .resolveFromMemoryCache(
          orchestrator: orchestrator,
          params: input.params,
        )
        .isReady;
  }

  LessonReadinessIdentity _identityFor(ResolveLessonMaterialInput input) {
    return LessonReadinessIdentity(
      lessonLocalId: input.lessonLocalId,
      itemIdx: input.itemIdx,
      marker: input.marker,
      layer: input.layer,
    );
  }

  void _discardUnreadableReadyMaterial(
    ResolveLessonMaterialInput input,
    LessonReadinessResult result,
  ) {
    final key = result.discardedKey;
    if (key == null) return;
    stateService.mutate(input.lessonLocalId, (state) {
      final next = {...state.readyLessonMaterials}..remove(key);
      return state.copyWith(
        readyLessonMaterials: next,
        events: [
          ...state.events,
          StudentLearningEvent(
            type: 'LESSON_MATERIAL_INVALID_DISCARDED',
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: {
              'key': key,
              'itemIdx': input.itemIdx,
              'marker': input.marker,
              'layer': input.layer.value,
              'error': result.safeReason ?? result.status.name,
              'status': result.status.name,
            },
          ),
        ],
      );
    });
  }

  bool _shouldDiscardReadiness(LessonReadinessResult result) {
    return result.status == LessonReadinessStatus.invalid ||
        result.status == LessonReadinessStatus.stale ||
        result.status == LessonReadinessStatus.staleLocale ||
        result.status == LessonReadinessStatus.legacyLocale;
  }

  void _prepareLessonAudio(
    ResolveLessonMaterialInput input,
    LessonContent content,
  ) {
    mediaService?.prepareLessonAudioText(
      LessonMediaPosition(
        lessonLocalId: input.lessonLocalId,
        itemMarker: input.marker,
        layer: input.layer,
      ),
      [
        content.explanation,
        content.question,
        content.options[AnswerLetter.A],
        content.options[AnswerLetter.B],
        content.options[AnswerLetter.C],
      ],
      input.params.effectiveLocaleContract,
    );
  }

  LessonMediaPosition _mediaPositionFor(
    CompleteLessonParams params, {
    ResolveLessonMaterialInput? input,
  }) => LessonMediaPosition(
    lessonLocalId: params.lessonLocalId,
    itemMarker: input?.marker ?? params.marker,
    itemIdx: input?.itemIdx ?? params.itemIdx,
    layer: input?.layer ?? params.layer,
  );

  ResolveLessonMaterialInput? _inputFor(CompleteLessonParams params) =>
      _inputsByLessonKey[lessonKeyFor(params)];

  void _markImageReady(CompleteLessonParams params, CompleteLesson lesson) =>
      mediaService?.markLessonImageReady(
        _mediaPositionFor(params, input: _inputFor(params)),
        cacheKey: lessonKeyFor(params),
        imageUrl: lesson.imagem,
        localeContract: params.effectiveLocaleContract,
        visualTextPolicy:
            lesson.imageMetadata?.visualTextPolicy ?? 'explanation',
      );

  void _markImageStarted(CompleteLessonParams params, CompleteLesson lesson) =>
      mediaService?.markLessonImageStarted(
        _mediaPositionFor(params, input: _inputFor(params)),
        cacheKey: lessonKeyFor(params),
        localeContract: params.effectiveLocaleContract,
        visualTextPolicy:
            lesson.imageMetadata?.visualTextPolicy ?? 'explanation',
      );

  void _markImageFailed(CompleteLessonParams params, CompleteLesson lesson) =>
      mediaService?.markLessonImageFailed(
        _mediaPositionFor(params, input: _inputFor(params)),
        error: lesson.imageMetadata?.n3Reason ?? 'VISUAL_ROUTE_FAILED',
        localeContract: params.effectiveLocaleContract,
      );

  void _markNoImage(CompleteLessonParams params, CompleteLesson lesson) =>
      mediaService?.markLessonNoImage(
        _mediaPositionFor(params, input: _inputFor(params)),
        reason: lesson.imageMetadata?.n2Reason,
        localeContract: params.effectiveLocaleContract,
      );
}
