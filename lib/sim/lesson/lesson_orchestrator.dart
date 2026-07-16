import 'dart:async';

import '../media/lesson_image_api_contract.dart';
import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
import 'lesson_event_bus.dart';
import 'lesson_material_cache.dart';
import 'lesson_models.dart';
import 'lesson_pipeline_runtime.dart';

class LessonOrchestrator {
  LessonOrchestrator({
    required this.t02Client,
    required this.cache,
    required this.bus,
    this.onAudioTextReady,
    this.onImageReady,
    List<Duration>? imageRefreshDelays,
  }) : imageRefreshDelays =
           imageRefreshDelays ??
           const [
             Duration(seconds: 1),
             Duration(seconds: 2),
             Duration(seconds: 3),
             Duration(seconds: 5),
             Duration(seconds: 8),
             Duration(seconds: 13),
           ];

  final T02LessonClient t02Client;
  final LessonMaterialCache cache;
  final LessonEventBus bus;
  final List<Duration> imageRefreshDelays;
  void Function(CompleteLessonParams params, CompleteLesson lesson)?
  onAudioTextReady;
  void Function(CompleteLessonParams params, CompleteLesson lesson)?
  onImageReady;
  final Map<String, Future<CompleteLesson>> _textInflight = {};
  final Map<String, Future<void>> _imageRefreshInflight = {};
  final BackgroundTextSemaphore _bgText = BackgroundTextSemaphore();
  Future<void> _lastLessonFullyComplete = Future.value();

  bool get isLessonBusy => _textInflight.isNotEmpty;

  int get warmCacheEntryCount => cache.warmEntryCount;

  int get coldCacheEntryCount => cache.coldEntryCount;

  CompleteLesson? peekCachedLesson(String key) => cache.peek(key);

  void protectWarmCachedLessons(Iterable<String> keys) {
    cache.protectWarmKeys(keys);
  }

  CompleteLesson ensureVisualForReadyLesson(
    CompleteLessonParams params,
    LessonContent conteudo, {
    String priority = 'active',
    String? initialImage,
    bool deferMedia = false,
  }) {
    final key = lessonKeyFor(params);
    final cached = cache.peek(key);
    if (cached != null) {
      if (!deferMedia) {
        queueAudioForReadyLesson(params, cached);
        queueImageForReadyLesson(params, cached);
      }
      return cached;
    }

    final base = CompleteLesson(
      conteudo: conteudo,
      imagem: initialImage?.trim().isEmpty == true ? null : initialImage,
      audioText: conteudo.audioText,
    );
    cache.putForParams(params, base);
    bus.notify(key, base);
    if (!deferMedia) {
      queueAudioForReadyLesson(params, base);
      queueImageForReadyLesson(params, base);
    }
    return base;
  }

  void queueAudioForReadyLesson(
    CompleteLessonParams params,
    CompleteLesson lesson,
  ) {
    onAudioTextReady?.call(params, lesson);
  }

  void queueImageForReadyLesson(
    CompleteLessonParams params,
    CompleteLesson lesson,
  ) {
    _notifyReadyImage(params, lesson);
    _scheduleImageRefreshIfNeeded(params, lesson);
  }

  void setAudioTextPreparer(
    void Function(CompleteLessonParams params, CompleteLesson lesson)? preparer,
  ) {
    onAudioTextReady = preparer;
  }

  Future<CompleteLesson> prefetchCompleteLesson(
    CompleteLessonParams params, {
    String priority = 'background',
    bool forceRefresh = false,
    bool deferMedia = false,
  }) {
    final key = lessonKeyFor(params);
    final ready = cache.peek(key);
    if (ready != null && !forceRefresh) {
      if (!deferMedia) {
        queueAudioForReadyLesson(params, ready);
        queueImageForReadyLesson(params, ready);
      }
      return Future.value(ready);
    }
    final existing = _textInflight[key];
    if (existing != null && !forceRefresh) return existing;

    Future<CompleteLesson> fetchFn() => _fetchText(params);
    final queued = priority == 'active'
        ? fetchFn()
        : _bgText.run(() async {
            final gate = _lastLessonFullyComplete;
            await gate;
            return fetchFn();
          });

    final future = queued
        .then((lesson) {
          cache.putForParams(params, lesson);
          bus.notify(key, lesson);
          if (!deferMedia) {
            queueAudioForReadyLesson(params, lesson);
            queueImageForReadyLesson(params, lesson);
          }
          if (_textInflight[key] != null) _textInflight.remove(key);
          return lesson;
        })
        .catchError((Object error) {
          if (_textInflight[key] != null) _textInflight.remove(key);
          throw error;
        });
    _textInflight[key] = future;
    _lastLessonFullyComplete = future.then((_) {}).catchError((_) {});
    return future;
  }

  void resetLessonSequentialGate() {
    _lastLessonFullyComplete = Future.value();
  }

  void _notifyReadyImage(CompleteLessonParams params, CompleteLesson lesson) {
    if (lesson.imagem == null || lesson.imagem!.trim().isEmpty) return;
    onImageReady?.call(params, lesson);
  }

  Future<CompleteLesson> _fetchText(CompleteLessonParams params) async {
    final material = await _fetchMaterial(params);
    return _lessonFromMaterial(material);
  }

  Future<T02LessonMaterial> _fetchMaterial(CompleteLessonParams params) {
    return t02Client.completeLesson(_requestFor(params));
  }

  T02LessonRequest _requestFor(CompleteLessonParams params) {
    return T02LessonRequest(
      lessonLocalId: params.lessonLocalId,
      item: params.item,
      lang: params.lang,
      academic: params.academic,
      layer: params.layer,
      mode: params.mode.name,
      errCount: params.errCount,
      history: params.history,
      marker: params.marker,
      profile: params.pedagogicalEnvelope,
      amparoLvl: params.amparoLvl,
      curriculumItems: params.curriculumItems,
      topic: params.topic,
      itemIdx: params.itemIdx,
      interfaceLocale: params.interfaceLocale,
      learningLocale: params.learningLocale,
      explanationLanguage: params.explanationLanguage,
      targetLanguage: params.targetLanguage,
    );
  }

  CompleteLesson _lessonFromMaterial(T02LessonMaterial material) {
    final imageDataUrl = material.imageDataUrl?.trim().isEmpty == true
        ? null
        : material.imageDataUrl;
    final status = _cleanText(material.imageStatus);
    final error = _cleanText(material.imageError);
    final conteudo = LessonContent(
      explanation: material.explanation,
      question: material.question,
      options: material.options,
      correctAnswer: material.correctAnswer,
      whyCorrect: material.whyCorrect,
      whyWrong: material.whyWrong,
    );
    return CompleteLesson(
      conteudo: conteudo,
      imagem: imageDataUrl,
      audioText: conteudo.audioText,
      imageMetadata: imageDataUrl == null && status == null && error == null
          ? null
          : LessonImageGenerationMetadata(
              requestId: material.imageId,
              provider: 'server-classroom',
              model: material.source,
              mimeType: null,
              charged: false,
              cacheHit: imageDataUrl != null,
              retryable: status == null ? null : _isPendingImageStatus(status),
              mediaType: 'image',
              status: imageDataUrl != null ? 'ready' : status,
              source: material.source,
              n3Reason: error,
            ),
    );
  }

  void _scheduleImageRefreshIfNeeded(
    CompleteLessonParams params,
    CompleteLesson lesson,
  ) {
    if (lesson.imagem != null && lesson.imagem!.trim().isNotEmpty) return;
    if (imageRefreshDelays.isEmpty) return;
    final status = lesson.imageMetadata?.status;
    if (status != null && !_isPendingImageStatus(status)) return;
    final key = lessonKeyFor(params);
    if (_imageRefreshInflight.containsKey(key)) return;

    final future = _refreshImageUntilReady(params, key);
    _imageRefreshInflight[key] = future;
    unawaited(
      future.whenComplete(() {
        _imageRefreshInflight.remove(key);
      }),
    );
  }

  Future<void> _refreshImageUntilReady(
    CompleteLessonParams params,
    String key,
  ) async {
    for (final delay in imageRefreshDelays) {
      await Future<void>.delayed(delay);
      final current = cache.peek(key);
      if (current?.imagem != null && current!.imagem!.trim().isNotEmpty) {
        return;
      }

      final material = await _fetchMaterial(params);
      final refreshed = _lessonFromMaterial(material);
      final currentAfterFetch = cache.peek(key);
      final base = currentAfterFetch ?? refreshed;

      if (refreshed.imagem != null && refreshed.imagem!.trim().isNotEmpty) {
        final completed = base.copyWith(
          conteudo: base.conteudo,
          imagem: refreshed.imagem,
          imageMetadata: refreshed.imageMetadata,
        );
        cache.putForParams(params, completed);
        bus.notify(key, completed);
        _notifyReadyImage(params, completed);
        return;
      }

      final status = refreshed.imageMetadata?.status;
      if (status != null && !_isPendingImageStatus(status)) {
        final updated = base.copyWith(imageMetadata: refreshed.imageMetadata);
        cache.putForParams(params, updated);
        bus.notify(key, updated);
        return;
      }
    }
  }

  static String? _cleanText(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static bool _isPendingImageStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'idle' ||
        normalized == 'queued' ||
        normalized == 'pending' ||
        normalized == 'processing' ||
        normalized == 'running';
  }

  CompleteLesson seedCompleteLesson(
    CompleteLessonParams params,
    LessonContent conteudo,
  ) {
    final key = lessonKeyFor(params);
    final lesson = CompleteLesson(
      conteudo: conteudo,
      imagem: null,
      audioText: conteudo.audioText,
    );
    cache.putForParams(params, lesson);
    bus.notify(key, lesson);
    queueAudioForReadyLesson(params, lesson);
    return lesson;
  }
}

JsonMap preparedMaterialFromLesson({
  required CompleteLesson lesson,
  required int itemIdx,
  required String? marker,
  required LessonLayer layer,
}) {
  return {
    'text_status': 'ready',
    ...lesson.conteudo.toJson(),
    if (lesson.imagem != null && lesson.imagem!.trim().isNotEmpty)
      'imagem': lesson.imagem,
    if (lesson.imageMetadata != null && !lesson.imageMetadata!.isEmpty)
      'imageMetadata': lesson.imageMetadata!.toJson(),
    'generated_at': DateTime.now().toIso8601String(),
    'model': 'T02_content',
    'prompt_contract_version': 'T02_content.v3',
    'for_itemIdx': itemIdx,
    'for_marker': marker,
    'for_layer': layer.name,
  };
}
