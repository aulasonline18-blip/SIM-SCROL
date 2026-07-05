// MIRROR OF: src/cyber/lesson-orchestrator.ts (Web, source of truth)
import '../media/lesson_visual_pipeline.dart';
import '../media/lesson_paid_image_offer.dart';
import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
import 'lesson_event_bus.dart';
import 'lesson_material_cache.dart';
import 'lesson_models.dart';
import 'lesson_pipeline_runtime.dart';

class LessonOrchestrator implements LessonPaidImageOrchestrator {
  LessonOrchestrator({
    required this.t02Client,
    required this.cache,
    required this.bus,
    required this.visualPipeline,
    this.onAudioTextReady,
  });

  final T02LessonClient t02Client;
  final LessonMaterialCache cache;
  final LessonEventBus bus;
  final LessonVisualPipeline visualPipeline;
  void Function(CompleteLessonParams params, CompleteLesson lesson)?
  onAudioTextReady;
  final Map<String, Future<CompleteLesson>> _textInflight = {};
  final Map<String, _PaidPending> _paidPending = {};
  final Map<String, Future<String?>> _paidInflight = {};
  final Map<String, Future<void>> _imageInflight = {};
  final Set<String> _declinedKeys = {};
  final ImageSequentialQueue _imageQueue = ImageSequentialQueue();
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
      if ((cached.imagem == null || cached.imagem!.trim().isEmpty) &&
          _lessonNeedsImage(cached)) {
        _scheduleImage(params, cached);
      }
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
    if (_lessonNeedsImage(base)) {
      _scheduleImage(params, base);
    }
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
      if ((ready.imagem == null || ready.imagem!.trim().isEmpty) &&
          _lessonNeedsImage(ready)) {
        _scheduleImage(params, ready);
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
          cache.put(key, lesson);
          bus.notify(key, lesson);
          onAudioTextReady?.call(params, lesson);
          if (_textInflight[key] != null) _textInflight.remove(key);
          // Part III.6: dispatch image sequentially in background
          _scheduleImage(params, lesson);
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

  bool _lessonNeedsImage(CompleteLesson lesson) {
    final trigger = LessonVisualTrigger.fromJson(lesson.conteudo.visualTrigger);
    return trigger.needsImage && trigger.pedagogicalNeed != 'none';
  }

  void _scheduleImage(CompleteLessonParams params, CompleteLesson lesson) {
    final key = lessonKeyFor(params);
    if (_imageInflight.containsKey(key)) return;
    final future = _imageQueue
        .run(() => _fetchImage(params, lesson))
        .catchError((_) {});
    _imageInflight[key] = future;
    future.whenComplete(() => _imageInflight.remove(key));
  }

  // D2.1: image pipeline — central funnel: software first, paid offer only.
  Future<void> _fetchImage(
    CompleteLessonParams params,
    CompleteLesson lesson,
  ) async {
    final key = lessonKeyFor(params);
    final vt = lesson.conteudo.visualTrigger;
    final trigger = _enrichVisualTrigger(
      LessonVisualTrigger.fromJson(vt),
      params,
      lesson,
    );
    if (!trigger.needsImage || trigger.pedagogicalNeed == 'none') {
      return;
    }

    final result = await visualPipeline.resolveVisual(
      trigger: trigger,
      lessonKey: key,
      stableLang: params.lang,
      academicLevel: params.academic,
      allowPaidImages: true,
      acceptedOfferId: null,
    );
    if (result.hasImage) {
      _publishImage(key, lesson, result.displayUrl!);
      return;
    }
    if (result.source == 'skip_no_paid' || result.source == 'skip_no_offer') {
      _publishPaidImageOffer(
        key: key,
        params: params,
        trigger: trigger,
        source: result.source,
      );
    }
  }

  LessonVisualTrigger _enrichVisualTrigger(
    LessonVisualTrigger trigger,
    CompleteLessonParams params,
    CompleteLesson lesson,
  ) {
    final lessonText = _compactVisualContext([
      params.item,
      lesson.conteudo.explanation,
      lesson.conteudo.question,
      lesson.conteudo.options[AnswerLetter.A],
      lesson.conteudo.options[AnswerLetter.B],
      lesson.conteudo.options[AnswerLetter.C],
    ]);
    if (lessonText.isEmpty) return trigger;

    final enrichedTopic = _joinVisualContext([trigger.topic, params.item]);
    final enrichedPrompt = _joinVisualContext([
      trigger.imagePrompt,
      lessonText,
    ], maxChars: 1400);
    final inferredVisualType =
        trigger.visualType ?? _inferVisualTypeFromLessonText(lessonText);

    return trigger.copyWith(
      topic: enrichedTopic.isEmpty ? null : enrichedTopic,
      visualType: inferredVisualType,
      imagePrompt: enrichedPrompt.isEmpty ? null : enrichedPrompt,
    );
  }

  void _publishImage(String key, CompleteLesson lesson, String imageData) {
    final updated = CompleteLesson(
      conteudo: lesson.conteudo,
      imagem: imageData,
      audioText: lesson.audioText,
    );
    cache.put(key, updated);
    bus.clearPaidImageOffer(key);
    bus.notify(key, updated);
  }

  void _publishPaidImageOffer({
    required String key,
    required CompleteLessonParams params,
    required LessonVisualTrigger trigger,
    required String source,
  }) {
    if (_declinedKeys.contains(key) || _paidPending.containsKey(key)) return;
    final prompt = visualPipeline.buildPromptForTrigger(
      topic: trigger.topic ?? params.item,
      trigger: trigger,
      lang: params.lang,
    );
    if (prompt.trim().isEmpty) return;
    final offerId = _stableOfferId(key, prompt);
    _paidPending[key] = _PaidPending(
      approvedPrompt: prompt,
      base:
          cache.peek(key) ??
          CompleteLesson(
            conteudo: LessonContent(
              explanation: '',
              question: '',
              options: const {
                AnswerLetter.A: '',
                AnswerLetter.B: '',
                AnswerLetter.C: '',
              },
              correctAnswer: AnswerLetter.A,
              visualTrigger: trigger.toVisualTriggerMap(),
            ),
            imagem: null,
            audioText: '',
          ),
      offerId: offerId,
      trigger: trigger,
      stableLang: params.lang,
      source: source,
    );
    _publishPendingPaidImageOffer(key);
  }

  @override
  Future<void> acceptPaidImageOffer(String lessonKey) async {
    final pending = _paidPending.remove(lessonKey);
    if (pending == null) return;
    _declinedKeys.remove(lessonKey);
    final existing = _paidInflight[lessonKey];
    if (existing != null) {
      await existing;
      return;
    }
    final future = _imageQueue.run(() async {
      final image = await visualPipeline.fetchPaidLessonImage(
        pending.approvedPrompt,
        lessonKey,
        acceptedOfferId: pending.offerId,
        idempotencyKey: pending.offerId,
        visualTrigger: pending.trigger.toVisualTriggerMap(),
        lessonContext: {
          'stableLang': pending.stableLang,
          'topic': pending.trigger.topic,
          'visualType': pending.trigger.visualType,
          'pedagogicalNeed': pending.trigger.pedagogicalNeed,
          'source': 'sim_app_flutter',
        },
      );
      if (image != null && image.trim().isNotEmpty) {
        _publishImage(lessonKey, pending.base, image);
      }
      return image;
    });
    _paidInflight[lessonKey] = future;
    try {
      await future;
    } finally {
      _paidInflight.remove(lessonKey);
    }
  }

  @override
  void declinePaidImageOffer(String lessonKey) {
    _declinedKeys.add(lessonKey);
    bus.clearPaidImageOffer(lessonKey);
  }

  void resetDeclinedPaidImageOffer(String lessonKey) {
    _declinedKeys.remove(lessonKey);
    _publishPendingPaidImageOffer(lessonKey);
  }

  void _publishPendingPaidImageOffer(String lessonKey) {
    final pending = _paidPending[lessonKey];
    if (pending == null || _declinedKeys.contains(lessonKey)) return;
    bus.notifyPaidImageOffer(
      lessonKey,
      LessonPaidImageOffer(
        offerId: pending.offerId,
        lessonKey: lessonKey,
        prompt: pending.approvedPrompt,
        creditCost: 10,
        source: pending.source,
      ),
    );
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
      ),
    );
    final conteudo = LessonContent(
      explanation: material.explanation,
      question: material.question,
      options: material.options,
      correctAnswer: material.correctAnswer,
      whyCorrect: material.whyCorrect,
      whyWrong: material.whyWrong,
      visualTrigger: material.visualTrigger,
    );
    return CompleteLesson(
      conteudo: conteudo,
      imagem: null,
      audioText: conteudo.audioText,
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

String _compactVisualContext(List<String?> parts, {int maxChars = 1200}) {
  return _joinVisualContext(parts, maxChars: maxChars);
}

String _joinVisualContext(List<String?> parts, {int maxChars = 1200}) {
  final seen = <String>{};
  final buffer = StringBuffer();
  for (final raw in parts) {
    final text = (raw ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) continue;
    final key = text.toLowerCase();
    if (!seen.add(key)) continue;
    if (buffer.isNotEmpty) buffer.write(' | ');
    buffer.write(text);
    if (buffer.length >= maxChars) break;
  }
  final result = buffer.toString();
  if (result.length <= maxChars) return result;
  return result.substring(0, maxChars);
}

String? _inferVisualTypeFromLessonText(String text) {
  final t = text.toLowerCase();
  if ([
    'função',
    'funcao',
    'parábola',
    'parabola',
    'gráfico',
    'grafico',
    'coeficiente',
    'eixo',
  ].any(t.contains)) {
    return 'graph';
  }
  if (['tabela', 'coluna', 'linha'].any(t.contains)) return 'table';
  if (['fluxograma', 'processo', 'etapa', 'passo'].any(t.contains)) {
    return 'flowchart';
  }
  if (['ciclo'].any(t.contains)) return 'cycle';
  if (['comparação', 'comparacao', 'diferença', 'diferenca'].any(t.contains)) {
    return 'comparison';
  }
  return null;
}

String _stableOfferId(String lessonKey, String prompt) {
  return 'img_offer_${_stableHash('$lessonKey|${prompt.trim()}')}';
}

String _stableHash(String input) {
  var hash = 5381;
  for (final unit in input.codeUnits) {
    hash = ((hash << 5) + hash) ^ unit;
  }
  return (hash & 0xffffffff).toRadixString(36);
}

class _PaidPending {
  const _PaidPending({
    required this.approvedPrompt,
    required this.base,
    required this.offerId,
    required this.trigger,
    required this.stableLang,
    required this.source,
  });

  final String approvedPrompt;
  final CompleteLesson base;
  final String offerId;
  final LessonVisualTrigger trigger;
  final String stableLang;
  final String source;
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
    'generated_at': DateTime.now().toIso8601String(),
    'model': 'T02_content',
    'prompt_contract_version': 'T02_content.v3',
    'for_itemIdx': itemIdx,
    'for_marker': marker,
    'for_layer': layer.name,
  };
}
