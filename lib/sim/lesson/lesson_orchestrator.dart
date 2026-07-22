import 'dart:async';

import '../config/sim_environment.dart';
import '../localization/sim_locale_contract.dart';
import '../media/lesson_image_api_contract.dart';
import '../media/lesson_visual_pipeline.dart';
import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
import 'lesson_event_bus.dart';
import 'lesson_material_cache.dart';
import 'lesson_models.dart';

class BackgroundTextSemaphore {
  static const int _maxConcurrent = 2;

  int _active = 0;
  final List<Completer<void>> _waiters = [];

  Future<T> run<T>(Future<T> Function() fn) async {
    if (_active >= _maxConcurrent) {
      final c = Completer<void>();
      _waiters.add(c);
      await c.future;
    }
    _active++;
    try {
      return await fn();
    } finally {
      _active--;
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete();
      }
    }
  }
}

class LessonOrchestrator {
  LessonOrchestrator({
    required this.t02Client,
    required this.cache,
    required this.bus,
    this.onAudioTextReady,
    this.onImageReady,
    this.onImageStarted,
    this.onImageFailed,
    this.onNoImage,
    List<Duration>? imageRefreshDelays,
    this.visualPipeline,
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
  void Function(CompleteLessonParams params, CompleteLesson lesson)?
  onImageStarted;
  void Function(CompleteLessonParams params, CompleteLesson lesson)?
  onImageFailed;
  void Function(CompleteLessonParams params, CompleteLesson lesson)? onNoImage;
  final S12VisualPipeline? visualPipeline;
  final Map<String, Future<CompleteLesson>> _textInflight = {};
  final Map<String, Future<void>> _imageRefreshInflight = {};
  final Map<String, Future<void>> _visualRouteInflight = {};
  final BackgroundTextSemaphore _bgText = BackgroundTextSemaphore();
  Future<void> _lastLessonFullyComplete = Future.value();

  bool get isLessonBusy => _textInflight.isNotEmpty;

  int get warmCacheEntryCount => cache.warmEntryCount;

  int get coldCacheEntryCount => cache.coldEntryCount;

  CompleteLesson? peekCachedLesson(String key) {
    final lesson = cache.peek(key);
    if (lesson != null) cache.touch(key);
    return lesson;
  }

  void protectWarmCachedLessons(Iterable<String> keys) {
    cache.protectWarmKeys(keys);
  }

  CompleteLesson ensureVisualForReadyLesson(
    CompleteLessonParams params,
    LessonContent conteudo, {
    String priority = 'hot-local',
    String? initialImage,
    bool deferMedia = false,
  }) {
    final key = lessonKeyFor(params);
    final cached = cache.peek(key);
    if (cached != null) {
      cache.touch(key);
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
    _notifyLocalVisualState(params, lesson);
    _scheduleVisualRouteIfNeeded(params, lesson);
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
    final queued = _bgText.run(() async {
      if (priority != 'hot-local') {
        final gate = _lastLessonFullyComplete;
        await gate;
      }
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
    if (priority != 'hot-local') {
      _lastLessonFullyComplete = future.then((_) {}).catchError((_) {});
    }
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
    return _lessonFromMaterial(material, params);
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
      localeContract: params.effectiveLocaleContract,
    );
  }

  CompleteLesson _lessonFromMaterial(
    T02LessonMaterial material,
    CompleteLessonParams params,
  ) {
    final imageDataUrl = material.imageDataUrl?.trim().isEmpty == true
        ? null
        : material.imageDataUrl;
    final status = _cleanText(material.imageStatus);
    final error = _cleanText(material.imageError);
    final trigger = LessonVisualTrigger.fromJson(material.visualTrigger);
    final locale = params.effectiveLocaleContract;
    final visualTextPolicy = _visualTextPolicyFor(trigger);
    final s12 = imageDataUrl == null
        ? visualPipeline?.resolveLocal(
            S12VisualRequest(
              trigger: trigger,
              lessonLocalId: params.lessonLocalId,
              marker: params.marker,
              itemIdx: params.itemIdx,
              layer: params.layer,
              idioma: locale.mediaTextLanguage,
              localeContract: locale,
              mediaTextLanguage: locale.mediaTextLanguage,
              explanationLanguage: locale.explanationLanguage,
              targetLanguage: locale.targetLanguage,
              visualTextPolicy: visualTextPolicy,
              subject: params.topic,
              explanation: material.explanation,
              question: material.question,
              options: material.options.values,
            ),
          )
        : null;
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
      imagem: imageDataUrl ?? s12?.imageData,
      audioText: conteudo.audioText,
      localeContract: params.effectiveLocaleContract,
      visualTrigger: trigger?.raw,
      imageMetadata:
          imageDataUrl == null && s12 == null && status == null && error == null
          ? null
          : LessonImageGenerationMetadata(
              requestId: material.imageId ?? s12?.requestId,
              provider: s12 == null ? 'complete-lesson' : 's12',
              model: material.source,
              mimeType: material.mimeType ?? s12?.mimeType,
              charged: false,
              cacheHit: imageDataUrl != null || s12?.isReady == true,
              retryable: s12?.shouldCallN3 == true
                  ? true
                  : status == null
                  ? null
                  : _isPendingImageStatus(status),
              mediaType: 'image',
              status: imageDataUrl != null ? 'ready' : s12?.status ?? status,
              source: s12 == null ? material.source : 's12',
              n2Reason: material.n2Reason ?? s12?.n2Reason,
              n3Reason: material.n3Reason ?? s12?.n3Reason ?? error,
              lessonLocalId: params.lessonLocalId,
              marker: params.marker,
              itemIdx: params.itemIdx,
              layer: params.layer.value,
              localeContract: locale,
              mediaTextLanguage: locale.mediaTextLanguage,
              explanationLanguage: locale.explanationLanguage,
              targetLanguage: locale.targetLanguage,
              visualTextPolicy: visualTextPolicy,
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
    if (lesson.imageMetadata?.source == 's12') return;
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

      final T02LessonMaterial material;
      try {
        material = await _fetchMaterial(params);
      } catch (_) {
        return;
      }
      final refreshed = _lessonFromMaterial(material, params);
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

  void _notifyLocalVisualState(
    CompleteLessonParams params,
    CompleteLesson lesson,
  ) {
    final status = lesson.imageMetadata?.status?.trim().toLowerCase();
    if (status == 'processing') {
      onImageStarted?.call(params, lesson);
    } else if (status == 'failed' || status == 'error') {
      onImageFailed?.call(params, lesson);
    } else if (status == 'no_image') {
      onNoImage?.call(params, lesson);
    }
  }

  void _scheduleVisualRouteIfNeeded(
    CompleteLessonParams params,
    CompleteLesson lesson,
  ) {
    final pipeline = visualPipeline;
    if (pipeline == null || lesson.imageMetadata?.source != 's12') return;
    if (lesson.imageMetadata?.status != 'processing') return;
    final key = lessonKeyFor(params);
    if (_visualRouteInflight.containsKey(key)) return;
    final trigger = LessonVisualTrigger.fromJson(lesson.visualTrigger);
    if (trigger == null) return;
    final future = _resolveVisualRoute(params, key, trigger);
    _visualRouteInflight[key] = future;
    unawaited(future.whenComplete(() => _visualRouteInflight.remove(key)));
  }

  Future<void> _resolveVisualRoute(
    CompleteLessonParams params,
    String key,
    LessonVisualTrigger trigger,
  ) async {
    final current = cache.peek(key);
    if (current == null) return;
    final locale = params.effectiveLocaleContract;
    final visualTextPolicy = _visualTextPolicyFor(trigger);
    final result = await visualPipeline!.resolveN3(
      S12VisualRequest(
        trigger: trigger,
        lessonLocalId: params.lessonLocalId,
        marker: params.marker,
        itemIdx: params.itemIdx,
        layer: params.layer,
        idioma: locale.mediaTextLanguage,
        localeContract: locale,
        mediaTextLanguage: locale.mediaTextLanguage,
        explanationLanguage: locale.explanationLanguage,
        targetLanguage: locale.targetLanguage,
        visualTextPolicy: visualTextPolicy,
        subject: params.topic,
        explanation: current.conteudo.explanation,
        question: current.conteudo.question,
        options: current.conteudo.options.values,
      ),
    );
    final metadata = LessonImageGenerationMetadata(
      requestId: result.requestId ?? current.imageMetadata?.requestId,
      mimeType: result.mimeType ?? current.imageMetadata?.mimeType,
      charged: false,
      cacheHit: result.isReady,
      retryable: result.status == 'processing',
      lessonLocalId: params.lessonLocalId,
      marker: params.marker,
      itemIdx: params.itemIdx,
      layer: params.layer.value,
      mediaType: 'image',
      status: result.isReady
          ? 'ready'
          : result.status == 'processing'
          ? 'processing'
          : 'failed',
      source: 's12-n3',
      n2Reason: result.n2Reason,
      n3Reason: result.n3Reason,
      localeContract: locale,
      mediaTextLanguage: locale.mediaTextLanguage,
      explanationLanguage: locale.explanationLanguage,
      targetLanguage: locale.targetLanguage,
      visualTextPolicy: visualTextPolicy,
    );
    final next = current.copyWith(
      imagem: result.isReady ? result.imageData : null,
      imageMetadata: metadata,
    );
    cache.putForParams(params, next);
    bus.notify(key, next);
    if (result.isReady) {
      _notifyReadyImage(params, next);
    } else if (result.status == 'processing') {
      onImageStarted?.call(params, next);
    } else {
      onImageFailed?.call(params, next);
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
      localeContract: params.effectiveLocaleContract,
    );
    cache.putForParams(params, lesson);
    bus.notify(key, lesson);
    queueAudioForReadyLesson(params, lesson);
    return lesson;
  }

  static String _visualTextPolicyFor(LessonVisualTrigger? trigger) {
    final raw =
        trigger?.raw['visualTextPolicy'] ??
        trigger?.raw['visual_text_policy'] ??
        trigger?.raw['textPolicy'] ??
        trigger?.raw['text_policy'];
    final text = raw?.toString().trim().toLowerCase();
    if (text == 'target' ||
        text == 'mixed' ||
        text == 'no_text' ||
        text == 'explanation') {
      return text!;
    }
    return 'explanation';
  }
}

JsonMap preparedMaterialFromLesson({
  required CompleteLesson lesson,
  required int itemIdx,
  required String? marker,
  required LessonLayer layer,
}) {
  final localeContract =
      lesson.localeContract ??
      (SimEnvironment.isProduction
          ? null
          : SimLocaleContract.fallbackForDevelopment());
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
    if (localeContract != null) ...{
      'localeContract': localeContract.toJson(),
      'localeCacheIdentity': localeContract.cacheIdentity(),
    },
    'for_itemIdx': itemIdx,
    'for_marker': marker,
    'for_layer': layer.name,
  };
}
