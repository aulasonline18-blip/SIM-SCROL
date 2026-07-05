// MIRROR OF: src/sim/lesson/studentLessonMaterialService.ts (Web, source of truth)
import 'dart:async';

import '../state/live_entry_state.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
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
    this.waitBeforeOrderMs = 2000,
    this.waitAfterOrderMs = 12000,
  });

  final String lessonLocalId;
  final String? topic;
  final int itemIdx;
  final String? marker;
  final LessonLayer layer;
  final CompleteLessonParams params;
  final int waitBeforeOrderMs;
  final int waitAfterOrderMs;
}

class ResolveLessonMaterialResult {
  const ResolveLessonMaterialResult({
    required this.conteudo,
    required this.imagem,
    required this.source,
    required this.waitedMs,
  });

  final LessonContent conteudo;
  final String? imagem;
  final LessonMaterialSource source;
  final int waitedMs;
}

class StudentLessonMaterialService {
  StudentLessonMaterialService({
    required this.stateService,
    required this.orchestrator,
    required this.readyWindowEngine,
    this.mediaService,
  });

  final StudentLearningStateService stateService;
  final LessonOrchestrator orchestrator;
  final DopamineReadyWindowEngine readyWindowEngine;
  final StudentLessonMediaService? mediaService;

  ResolveLessonMaterialResult? resolveFastLessonMaterialFromStateOrCache(
    ResolveLessonMaterialInput input,
  ) {
    final fromState = _readReadyFromStudentState(input);
    if (fromState != null) {
      final visualReady = orchestrator.ensureVisualForReadyLesson(
        input.params,
        fromState.conteudo,
        priority: 'active',
        initialImage: null,
      );
      _prepareLessonAudio(input, visualReady.conteudo);
      _mirrorCurrentLessonMaterial(input, visualReady);
      return ResolveLessonMaterialResult(
        conteudo: visualReady.conteudo,
        imagem: visualReady.imagem,
        source: LessonMaterialSource.studentState,
        waitedMs: 0,
      );
    }
    final cached = orchestrator.peekCachedLesson(lessonKeyFor(input.params));
    if (cached == null) return null;
    final visualReady = orchestrator.ensureVisualForReadyLesson(
      input.params,
      cached.conteudo,
      priority: 'active',
    );
    _prepareLessonAudio(input, visualReady.conteudo);
    _mirrorCurrentLessonMaterial(input, visualReady);
    return ResolveLessonMaterialResult(
      conteudo: visualReady.conteudo,
      imagem: visualReady.imagem,
      source: LessonMaterialSource.memoryCacheFromMotor,
      waitedMs: 0,
    );
  }

  Future<ResolveLessonMaterialResult?> resolveLessonMaterialFromStateOrEngine(
    ResolveLessonMaterialInput input,
  ) async {
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    final fast = resolveFastLessonMaterialFromStateOrCache(input);
    if (fast != null) return fast;

    final lesson = await orchestrator.prefetchCompleteLesson(
      input.params,
      priority: 'active',
    );
    _mirrorPreparedAndCurrentLessonMaterial(input, lesson);
    final waitedMs = DateTime.now().millisecondsSinceEpoch - startedAt;
    _appendLessonTextReady(
      input,
      lesson.conteudo,
      LessonMaterialSource.studentStateAfterWait,
      waitedMs,
    );
    return ResolveLessonMaterialResult(
      conteudo: lesson.conteudo,
      imagem: lesson.imagem,
      source: LessonMaterialSource.studentStateAfterWait,
      waitedMs: waitedMs,
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
          'maxSlots': 3,
        },
      ),
    );
    unawaited(
      readyWindowEngine
          .runDopamineReadyWindowFromStudentState(
            lessonLocalId: lessonLocalId,
            source: source,
            maxSlots: 3,
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
          .catchError((Object error) {
            stateService.appendEvent(
              lessonLocalId,
              StudentLearningEvent(
                type: 'BACKGROUND_READY_WINDOW_FAILED',
                ts: DateTime.now().millisecondsSinceEpoch,
                payload: {'source': source, 'error': error.toString()},
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
      final idempotencyKey = '$source:$lessonLocalId:$itemIdx:L${layer.value}';
      final jobs = [...state.queuedActions];
      final hasActiveDuplicate = jobs.any(
        (job) =>
            job['type'] == 'PREPARE_READY_WINDOW' &&
            job['idempotency_key'] == idempotencyKey &&
            (job['status'] == 'queued' || job['status'] == 'running'),
      );
      if (!hasActiveDuplicate) {
        jobs.add({
          'job_id': 'PREPARE_READY_WINDOW:$idempotencyKey:$now',
          'type': 'PREPARE_READY_WINDOW',
          'status': 'queued',
          'idempotency_key': idempotencyKey,
          'priority': priority,
          'source': source,
          'payload': {
            'maxSlots': 3,
            'reason': reason ?? 'lesson_window_visible',
            'itemIdx': itemIdx,
            'layer': layer.value,
            'marker': items.length > itemIdx ? items[itemIdx].marker : null,
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
      return state.copyWith(
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
    });
  }

  List<({int offset, DopamineWindowItem item, LessonLayer layer})>
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
    final window = <({int offset, DopamineWindowItem item, LessonLayer layer})>[
      (offset: 0, item: first, layer: firstLayer),
    ];
    var cursor = (idx: fromIdx, layer: firstLayer);
    while (window.length < 3) {
      final next = _nextReadyWindowSlot(cursor.idx, cursor.layer, items);
      if (next == null || next.idx < 0 || next.idx >= items.length) break;
      final item = items[next.idx];
      window.add((offset: window.length, item: item, layer: next.layer));
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
        imagem: null,
        audioText: content.audioText,
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

  void _mirrorCurrentLessonMaterial(
    ResolveLessonMaterialInput input,
    CompleteLesson lesson,
  ) {
    stateService.mutate(input.lessonLocalId, (state) {
      return state.copyWith(
        currentLessonMaterial: preparedMaterialFromLesson(
          lesson: lesson,
          itemIdx: input.itemIdx,
          marker: input.marker,
          layer: input.layer,
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
    final material = preparedMaterialFromLesson(
      lesson: lesson,
      itemIdx: input.itemIdx,
      marker: input.marker,
      layer: input.layer,
    );
    stateService.mutate(input.lessonLocalId, (state) {
      return state.copyWith(
        currentLessonMaterial: material,
        readyLessonMaterials: {...state.readyLessonMaterials, key: material},
      );
    });
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
      priority: 'active',
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
