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
  final Map<String, _ImageInflight> _imageInflight = {};
  final Map<String, int> _imageEpochByKey = {};
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
          if ((lesson.imagem == null || lesson.imagem!.trim().isEmpty) &&
              _lessonNeedsImage(lesson)) {
            _scheduleImage(params, lesson);
          }
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

    bus.clearPaidImageOffer(key);

    final epoch = (_imageEpochByKey[key] ?? 0) + 1;
    _imageEpochByKey[key] = epoch;
    _imageInflight[key] = _ImageInflight(signature: signature, epoch: epoch);
    final future = _fetchImage(
      params,
      lesson,
      signature,
      epoch,
    ).catchError((_) {});
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
      stableLang: params.explanationLanguage ?? params.lang,
      academicLevel: params.academic,
      allowPaidImages: true,
      acceptedOfferId: null,
    );
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
      lessonLocalId: params.lessonLocalId,
      marker: params.marker,
      itemIdx: params.itemIdx,
      layer: params.layer.value,
    );
  }

  void _publishImage(
    CompleteLessonParams params,
    CompleteLesson lesson,
    String imageData, {
    LessonImageGenerationMetadata? imageMetadata,
  }) {
    final key = lessonKeyFor(params);
    final cached = cache.peek(key);
    if (cached?.imagem != null && cached!.imagem!.trim().isNotEmpty) {
      return;
    }
    final base = cached ?? lesson;
    final updated = CompleteLesson(
      conteudo: base.conteudo,
      imagem: imageData,
      audioText: base.audioText,
      imageMetadata: _slotImageMetadata(params, key, imageMetadata),
    );
    cache.put(key, updated);
    onImageReady?.call(params, updated);
    bus.clearPaidImageOffer(key);
    bus.notify(key, updated);
  }

  LessonImageGenerationMetadata? _slotImageMetadata(
    CompleteLessonParams params,
    String key,
    LessonImageGenerationMetadata? metadata,
  ) {
    final marker = params.marker;
    final itemIdx = params.itemIdx;
    if (marker == null || marker.trim().isEmpty || itemIdx == null) {
      return metadata;
    }
    return (metadata ?? const LessonImageGenerationMetadata()).withSlot(
      lessonLocalId: params.lessonLocalId,
      marker: marker,
      itemIdx: itemIdx,
      layer: params.layer.value,
      cacheKey: key,
      status: 'ready',
      mediaType: 'image',
      source: metadata?.source ?? 'server_visual',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<LessonImageGenerationMetadata?> acceptPaidImageOffer(
    String lessonKey,
  ) async => cache.peek(lessonKey)?.imageMetadata;

  @override
  void declinePaidImageOffer(String lessonKey) {
    bus.clearPaidImageOffer(lessonKey);
  }

  void resetDeclinedPaidImageOffer(String lessonKey) {
    bus.clearPaidImageOffer(lessonKey);
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
    final serverManagedVisual =
        material.source == 'server-classroom' &&
        (material.imageStatus ?? '').trim().isNotEmpty;
    final conteudo = LessonContent(
      explanation: material.explanation,
      question: material.question,
      options: material.options,
      correctAnswer: material.correctAnswer,
      whyCorrect: material.whyCorrect,
      whyWrong: material.whyWrong,
      visualTrigger: serverManagedVisual && material.imageDataUrl == null
          ? null
          : material.visualTrigger,
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
