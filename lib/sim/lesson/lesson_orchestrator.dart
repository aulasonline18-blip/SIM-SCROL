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
  });

  final T02LessonClient t02Client;
  final LessonMaterialCache cache;
  final LessonEventBus bus;
  void Function(CompleteLessonParams params, CompleteLesson lesson)?
  onAudioTextReady;
  void Function(CompleteLessonParams params, CompleteLesson lesson)?
  onImageReady;
  final Map<String, Future<CompleteLesson>> _textInflight = {};
  final BackgroundTextSemaphore _bgText = BackgroundTextSemaphore();
  Future<void> _lastLessonFullyComplete = Future.value();

  bool get isLessonBusy => _textInflight.isNotEmpty;

  CompleteLesson? peekCachedLesson(String key) => cache.peek(key);

  CompleteLesson ensureVisualForReadyLesson(
    CompleteLessonParams params,
    LessonContent conteudo, {
    String priority = 'active',
    String? initialImage,
  }) {
    final key = lessonKeyFor(params);
    final cached = cache.peek(key);
    if (cached != null) {
      onAudioTextReady?.call(params, cached);
      _notifyReadyImage(params, cached);
      return cached;
    }

    final base = CompleteLesson(
      conteudo: conteudo,
      imagem: initialImage?.trim().isEmpty == true ? null : initialImage,
      audioText: conteudo.audioText,
    );
    cache.put(key, base);
    bus.notify(key, base);
    onAudioTextReady?.call(params, base);
    _notifyReadyImage(params, base);
    return base;
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
  }) {
    final key = lessonKeyFor(params);
    final ready = cache.peek(key);
    if (ready != null && !forceRefresh) {
      onAudioTextReady?.call(params, ready);
      _notifyReadyImage(params, ready);
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
          cache.put(key, lesson);
          bus.notify(key, lesson);
          onAudioTextReady?.call(params, lesson);
          _notifyReadyImage(params, lesson);
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
    final material = await t02Client.completeLesson(
      T02LessonRequest(
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
      ),
    );
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
      imagem: material.imageDataUrl?.trim().isEmpty == true
          ? null
          : material.imageDataUrl,
      audioText: conteudo.audioText,
      imageMetadata: material.imageDataUrl == null
          ? null
          : LessonImageGenerationMetadata(
              requestId: material.imageId,
              provider: 'server-classroom',
              model: material.source,
              mimeType: null,
              charged: false,
              cacheHit: true,
            ),
    );
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
    cache.put(key, lesson);
    bus.notify(key, lesson);
    onAudioTextReady?.call(params, lesson);
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
