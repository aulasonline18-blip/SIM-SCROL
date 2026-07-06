// MIRROR OF: src/cyber/lesson-orchestrator.ts (Web, source of truth)
import 'dart:convert';

import '../media/lesson_image_api_contract.dart';
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
    this.onImageReady,
  });

  final T02LessonClient t02Client;
  final LessonMaterialCache cache;
  final LessonEventBus bus;
  final LessonVisualPipeline visualPipeline;
  void Function(CompleteLessonParams params, CompleteLesson lesson)?
  onAudioTextReady;
  void Function(CompleteLessonParams params, CompleteLesson lesson)?
  onImageReady;
  final Map<String, Future<CompleteLesson>> _textInflight = {};
  final Map<String, _PaidPending> _paidPending = {};
  final Map<String, Future<LessonImageGenerationMetadata?>> _paidInflight = {};
  final Map<String, _ImageInflight> _imageInflight = {};
  final Map<String, int> _imageEpochByKey = {};
  final Map<String, String> _declinedImageSignaturesByKey = {};
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
    final signature = _lessonContentSignature(lesson);
    final existing = _imageInflight[key];
    if (existing != null && existing.signature == signature) return;

    final pending = _paidPending[key];
    final pendingChanged = pending != null && pending.signature != signature;
    if (pendingChanged) {
      _paidPending.remove(key);
    }
    final declinedSignature = _declinedImageSignaturesByKey[key];
    if (declinedSignature != null && declinedSignature != signature) {
      _declinedImageSignaturesByKey.remove(key);
    }
    if (pending == null || pendingChanged) {
      bus.clearPaidImageOffer(key);
    }

    final epoch = (_imageEpochByKey[key] ?? 0) + 1;
    _imageEpochByKey[key] = epoch;
    final future = _imageQueue
        .run(() => _fetchImage(params, lesson, signature, epoch))
        .catchError((_) {});
    _imageInflight[key] = _ImageInflight(signature: signature, epoch: epoch);
    future.whenComplete(() {
      final current = _imageInflight[key];
      if (current != null && current.epoch == epoch) {
        _imageInflight.remove(key);
      }
    });
  }

  // D2.1: image pipeline — central funnel: software first, paid offer only.
  Future<void> _fetchImage(
    CompleteLessonParams params,
    CompleteLesson lesson,
    String signature,
    int epoch,
  ) async {
    final key = lessonKeyFor(params);
    if (!_isCurrentImageDecision(key, signature, epoch)) return;
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
    if (!_isCurrentImageDecision(key, signature, epoch)) return;
    if (result.hasImage) {
      _publishImage(
        params,
        lesson,
        result.displayUrl!,
        imageMetadata: result.imageMetadata,
      );
      return;
    }
  }

  bool _isCurrentImageDecision(String key, String signature, int epoch) {
    final current = _imageInflight[key];
    if (current == null ||
        current.epoch != epoch ||
        current.signature != signature) {
      return false;
    }
    final cached = cache.peek(key);
    if (cached == null) return true;
    return _lessonContentSignature(cached) == signature;
  }

  String? _currentContentSignature(String key) {
    final cached = cache.peek(key);
    return cached == null ? null : _lessonContentSignature(cached);
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
      lessonText,
      trigger.imagePrompt,
    ], maxChars: 1800);
    final inferredVisualType = _resolveVisualTypeFromLessonText(
      current: trigger.visualType,
      lessonText: lessonText,
    );

    return trigger.copyWith(
      topic: enrichedTopic.isEmpty ? null : enrichedTopic,
      visualType: inferredVisualType,
      imagePrompt: enrichedPrompt.isEmpty ? null : enrichedPrompt,
    );
  }

  void _publishImage(
    CompleteLessonParams params,
    CompleteLesson lesson,
    String imageData, {
    LessonImageGenerationMetadata? imageMetadata,
  }) {
    final key = lessonKeyFor(params);
    final updated = CompleteLesson(
      conteudo: lesson.conteudo,
      imagem: imageData,
      audioText: lesson.audioText,
      imageMetadata: imageMetadata,
    );
    cache.put(key, updated);
    onImageReady?.call(params, updated);
    bus.clearPaidImageOffer(key);
    bus.notify(key, updated);
  }

  @override
  Future<LessonImageGenerationMetadata?> acceptPaidImageOffer(
    String lessonKey,
  ) async {
    final existing = _paidInflight[lessonKey];
    if (existing != null) {
      return existing;
    }
    final pending = _paidPending.remove(lessonKey);
    if (pending == null) {
      final cached = cache.peek(lessonKey);
      if (cached?.imagem != null && cached!.imagem!.trim().isNotEmpty) {
        bus.clearPaidImageOffer(lessonKey);
        bus.notify(lessonKey, cached);
        return cached.imageMetadata;
      }
      return null;
    }
    _declinedImageSignaturesByKey.remove(lessonKey);
    final future = _imageQueue.run(() async {
      final image = await visualPipeline.fetchPaidLessonImageResponse(
        pending.approvedPrompt,
        lessonKey,
        aspectRatio: normalizedLessonImageAspectRatio(
          pending.trigger.aspectRatio,
        ),
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
      if (image != null && image.dataUrl.trim().isNotEmpty) {
        final metadata = image.toMetadata();
        _publishImage(
          pending.params,
          pending.base,
          image.dataUrl,
          imageMetadata: metadata,
        );
        return metadata;
      }
      return null;
    });
    _paidInflight[lessonKey] = future;
    try {
      return await future;
    } finally {
      _paidInflight.remove(lessonKey);
    }
  }

  @override
  void declinePaidImageOffer(String lessonKey) {
    _declinedImageSignaturesByKey[lessonKey] =
        _currentContentSignature(lessonKey) ?? '';
    bus.clearPaidImageOffer(lessonKey);
  }

  void resetDeclinedPaidImageOffer(String lessonKey) {
    _declinedImageSignaturesByKey.remove(lessonKey);
    _publishPendingPaidImageOffer(lessonKey);
  }

  void _publishPendingPaidImageOffer(String lessonKey) {
    final pending = _paidPending[lessonKey];
    if (pending == null ||
        (pending.signature != null &&
            _declinedImageSignaturesByKey[lessonKey] == pending.signature)) {
      return;
    }
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

String? _resolveVisualTypeFromLessonText({
  required String? current,
  required String lessonText,
}) {
  final inferred = _inferVisualTypeFromLessonText(lessonText);
  if (inferred == null) return current;
  final currentType = current?.trim().toLowerCase();
  if (currentType == null || currentType.isEmpty) return inferred;
  if (inferred == 'graph' &&
      _isGenericOrAiVisualType(currentType) &&
      _lessonTextHasGraphEvidence(lessonText)) {
    return inferred;
  }
  return current;
}

bool _isGenericOrAiVisualType(String value) {
  return const {
    'ai',
    'image',
    'photo',
    'realistic',
    'illustration',
    'diagram',
    'generic',
    'anatomy',
  }.contains(value);
}

bool _lessonTextHasGraphEvidence(String text) {
  final normalized = text
      .toLowerCase()
      .replaceAll('²', '^2')
      .replaceAll('−', '-');
  return RegExp(
        r'\b[a-z](?:\s*\(\s*[a-z]\s*\))?\s*=\s*[^|.;?]*\^2',
      ).hasMatch(normalized) ||
      [
        'função',
        'funcao',
        'parábola',
        'parabola',
        'gráfico',
        'grafico',
        'eixo',
      ].any(normalized.contains);
}

String _lessonContentSignature(CompleteLesson lesson) {
  return jsonEncode(lesson.conteudo.toJson());
}

class _PaidPending {
  const _PaidPending({
    required this.approvedPrompt,
    required this.base,
    required this.offerId,
    required this.params,
    required this.trigger,
    required this.stableLang,
    required this.source,
    required this.signature,
  });

  final String approvedPrompt;
  final CompleteLesson base;
  final String offerId;
  final CompleteLessonParams params;
  final LessonVisualTrigger trigger;
  final String stableLang;
  final String source;
  final String? signature;
}

class _ImageInflight {
  const _ImageInflight({required this.signature, required this.epoch});

  final String signature;
  final int epoch;
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
