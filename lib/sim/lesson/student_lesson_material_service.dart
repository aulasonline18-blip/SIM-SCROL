import 'dart:async';

import '../state/live_entry_state.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import '../media/lesson_image_api_contract.dart';
import '../media/student_lesson_media_service.dart';
import 'dopamine_ready_window_engine.dart';
import 'lesson_content_validator.dart';
import 'lesson_models.dart';
import 'lesson_orchestrator.dart';

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
}

class ResolveLessonMaterialResult {
  const ResolveLessonMaterialResult({
    required this.conteudo,
    required this.imagem,
    required this.source,
    required this.waitedMs,
    this.imageMetadata,
  });

  final LessonContent conteudo;
  final String? imagem;
  final LessonMaterialSource source;
  final int waitedMs;
  final LessonImageGenerationMetadata? imageMetadata;
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
    };
  }

  final StudentLearningStateService stateService;
  final LessonOrchestrator orchestrator;
  final DopamineReadyWindowEngine readyWindowEngine;
  final StudentLessonMediaService? mediaService;
  final Map<String, ResolveLessonMaterialInput> _inputsByLessonKey = {};
  final Map<String, void Function()> _imageUnsubscribersByLessonKey = {};

  ResolveLessonMaterialResult? resolveFastLessonMaterialFromStateOrCache(
    ResolveLessonMaterialInput input,
  ) {
    _rememberInput(input);
    final fromState = _readReadyFromStudentState(input);
    if (fromState != null) {
      final visualReady = orchestrator.ensureVisualForReadyLesson(
        input.params,
        fromState.conteudo,
        priority: 'hot-local',
        initialImage: fromState.imagem,
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
      );
    }
    final cached = orchestrator.peekCachedLesson(lessonKeyFor(input.params));
    if (cached == null) return null;
    final visualReady = orchestrator.ensureVisualForReadyLesson(
      input.params,
      cached.conteudo,
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
      priority: 'background',
    );
    if (input.waitAfterOrderMs <= 0) {
      unawaited(
        lessonFuture
            .then((lesson) {
              _mirrorPreparedAndCurrentLessonMaterial(input, lesson);
              _appendLessonTextReady(
                input,
                lesson.conteudo,
                LessonMaterialSource.studentStateAfterWait,
                DateTime.now().millisecondsSinceEpoch - startedAt,
              );
            })
            .catchError((_) => null),
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
    final window = _buildReadyWindow(itemIdx, layer, items);
    stateService.mutate(lessonLocalId, (state) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final marker = items.length > itemIdx ? items[itemIdx].marker : null;
      final idempotencyKey = [
        'ready-window',
        lessonLocalId,
        itemIdx,
        marker ?? '',
        'L${layer.value}',
      ].join(':');
      final jobs = [...state.queuedActions];
      final duplicateIndex = jobs.indexWhere(
        (job) =>
            job['type'] == 'PREPARE_READY_WINDOW' &&
            job['idempotency_key'] == idempotencyKey &&
            (job['status'] == 'queued' || job['status'] == 'running'),
      );
      if (duplicateIndex < 0) {
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
          },
          'created_at': now,
          'started_at': null,
          'finished_at': null,
          'error': null,
          'attempts': 0,
          'max_attempts': 3,
          'next_retry_at': null,
        });
      } else if (priority == 'hot-local' &&
          jobs[duplicateIndex]['priority'] != 'hot-local' &&
          jobs[duplicateIndex]['status'] == 'queued') {
        jobs[duplicateIndex] = {
          ...jobs[duplicateIndex],
          'priority': 'hot-local',
          'source': source,
          'payload': {
            ...JsonMap.from(
              jobs[duplicateIndex]['payload'] as Map? ?? const {},
            ),
            'reason': reason ?? 'lesson_window_visible',
          },
          'next_retry_at': null,
        };
      }
      final warmIdempotencyKey = [
        'warm-ready-window',
        lessonLocalId,
        itemIdx,
        marker ?? '',
        'L${layer.value}',
        'slots-$offlineWarmCacheSize',
      ].join(':');
      final hasWarmDuplicate = jobs.any(
        (job) =>
            job['type'] == 'PREPARE_READY_WINDOW' &&
            job['idempotency_key'] == warmIdempotencyKey &&
            (job['status'] == 'queued' || job['status'] == 'running'),
      );
      if (!hasWarmDuplicate) {
        jobs.add({
          'job_id': 'PREPARE_READY_WINDOW:$warmIdempotencyKey:$now',
          'type': 'PREPARE_READY_WINDOW',
          'status': 'queued',
          'idempotency_key': warmIdempotencyKey,
          'priority': 'background',
          'source': '$source.warm-offline-cache',
          'payload': {
            'maxSlots': offlineWarmCacheSize,
            'reason': 'warm_offline_cache_fill',
            'itemIdx': itemIdx,
            'layer': layer.value,
            'marker': marker,
            'topic': topic,
          },
          'created_at': now,
          'started_at': null,
          'finished_at': null,
          'error': null,
          'attempts': 0,
          'max_attempts': 3,
          'next_retry_at': null,
        });
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
          StudentLearningEvent(
            type: 'CACHE_WINDOW_UPDATED',
            ts: now,
            payload: {
              'lessonLocalId': lessonLocalId,
              'currentItemIdx': itemIdx,
              'currentLayer': layer.value,
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
        ],
      );
    }, allowLocalHousekeeping: true);
  }

  List<({int offset, int idx, DopamineWindowItem item, LessonLayer layer})>
  _buildReadyWindow(
    int fromIdx,
    LessonLayer layer,
    List<DopamineWindowItem> items,
  ) {
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
    while (window.length < localLessonTraySize) {
      final next = _nextReadyWindowSlot(cursor.idx, cursor.layer, items);
      if (next == null || next.idx < 0 || next.idx >= items.length) break;
      final item = items[next.idx];
      window.add((
        offset: window.length,
        idx: next.idx,
        item: item,
        layer: next.layer,
      ));
      cursor = next;
    }
    return window;
  }

  ({int idx, LessonLayer layer})? _nextReadyWindowSlot(
    int idx,
    LessonLayer layer,
    List<DopamineWindowItem> items,
  ) {
    final item = idx >= 0 && idx < items.length ? items[idx] : null;
    if (item == null) return null;
    if (!item.isReview && layer != LessonLayer.l3) {
      return (
        idx: idx,
        layer: layer == LessonLayer.l1 ? LessonLayer.l2 : LessonLayer.l3,
      );
    }
    final nextIdx = idx + 1;
    if (nextIdx >= items.length) return null;
    final next = items[nextIdx];
    return (
      idx: nextIdx,
      layer: next.isReview
          ? next.reviewLayer ?? LessonLayer.l1
          : LessonLayer.l1,
    );
  }

  CompleteLesson? _readReadyFromStudentState(ResolveLessonMaterialInput input) {
    final state = stateService.read(input.lessonLocalId);
    final key = preparedLessonMaterialKey(
      input.itemIdx,
      input.marker,
      input.layer,
    );
    final material = state?.readyLessonMaterials[key];
    if (material == null || material['text_status'] != 'ready') return null;
    if (material['for_itemIdx'] != input.itemIdx) return null;
    if (material['for_layer'] != input.layer.name) return null;
    if ((material['for_marker'] as String?) != input.marker) return null;
    try {
      final content = validatedLessonContentFromJson(JsonMap.from(material));
      return CompleteLesson(
        conteudo: content,
        imagem: _stringOrNull(material['imagem']),
        audioText: content.audioText,
        imageMetadata: LessonImageGenerationMetadata.fromJson(
          material['imageMetadata'],
        ),
      );
    } on LessonContentValidationException catch (error) {
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
                'error': error.message,
              },
            ),
          ],
        );
      });
      return null;
    }
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

  // D4: Resume Instantâneo — lê da fonte única (StudentLearningState) diretamente.
  // Planta-Mãe §10: student_state > cache > T02.
  CompleteLesson? readReadyLessonMaterialFromStudentState(
    ResolveLessonMaterialInput input,
  ) {
    final lesson = _readReadyFromStudentState(input);
    if (lesson == null) return null;
    // Log Resume Instantâneo
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

  // D4: Pergunta "tem material pronto?" sem buscar T02 (síncrono, sem custo).
  bool isLessonMaterialReadyInStateOrCache(ResolveLessonMaterialInput input) {
    if (_readReadyFromStudentState(input) != null) return true;
    return orchestrator.peekCachedLesson(lessonKeyFor(input.params)) != null;
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
    );
  }
}
