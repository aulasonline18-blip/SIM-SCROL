part of '../dopamine_ready_window_engine.dart';

class ReadyWindowMedia {
  ReadyWindowMedia({required this.service, required this.orchestrator});

  final StudentLearningStateService service;
  final LessonOrchestrator orchestrator;
  final Set<String> _queuedSecondaryMediaKeys = {};
  final Set<String> _mediaRefreshKeys = {};

  CompleteLesson prepareMediaFromCachedLesson({
    required String lessonLocalId,
    required String source,
    required DopamineReadySlot slot,
    required CompleteLesson lesson,
    required void Function(String lessonLocalId, String type, JsonMap payload)
    emit,
  }) {
    final state = service.read(lessonLocalId);
    final mediaKey = slotMediaKey(lessonLocalId, slot, SlotMediaType.image);
    if (_mediaRefreshKeys.contains(mediaKey) ||
        slotMediaAlreadyRequested(state, slot, SlotMediaType.image)) {
      return lesson;
    }
    _mediaRefreshKeys.add(mediaKey);
    emit(lessonLocalId, 'DOPAMINE_SLOT_MEDIA_REFRESH_REQUESTED', {
      'source': source,
      'slot': slot.slot,
      'itemIdx': slot.itemIdx,
      'marker': slot.marker,
      'layer': slot.layer.value,
      'mediaKey': mediaKey,
      'storage': 'cache',
    });
    return orchestrator.ensureVisualForReadyLesson(
      slot.params,
      lesson.conteudo,
      priority: 'background',
      initialImage: lesson.imagem,
      deferMedia: true,
    );
  }

  void queueSecondaryMedia({
    required String lessonLocalId,
    required String source,
    required List<ReadyWindowMediaSlot> mediaSlots,
    required void Function(String lessonLocalId, String type, JsonMap payload)
    emit,
  }) {
    if (mediaSlots.isEmpty) return;
    final current = mediaSlots
        .where((entry) => entry.slot.slot == 'A')
        .toList(growable: false);
    final next = mediaSlots
        .where((entry) => entry.slot.slot != 'A')
        .toList(growable: false);

    for (final entry in current) {
      _queueSecondaryMediaType(
        lessonLocalId: lessonLocalId,
        source: source,
        entry: entry,
        mediaType: SlotMediaType.audio,
        priority: 'current',
        emit: emit,
      );
    }
    for (final entry in current) {
      _queueSecondaryMediaType(
        lessonLocalId: lessonLocalId,
        source: source,
        entry: entry,
        mediaType: SlotMediaType.image,
        priority: 'current',
        emit: emit,
      );
    }
    for (final entry in next) {
      _queueSecondaryMediaType(
        lessonLocalId: lessonLocalId,
        source: source,
        entry: entry,
        mediaType: SlotMediaType.audio,
        priority: 'next',
        emit: emit,
      );
    }
    for (final entry in next) {
      _queueSecondaryMediaType(
        lessonLocalId: lessonLocalId,
        source: source,
        entry: entry,
        mediaType: SlotMediaType.image,
        priority: 'next',
        emit: emit,
      );
    }
  }

  void clearMediaCache() {
    _queuedSecondaryMediaKeys.clear();
    _mediaRefreshKeys.clear();
  }

  bool hasMediaReady(DopamineReadySlot position) {
    final state = service.read(position.params.lessonLocalId);
    return slotMediaAlreadyRequested(state, position, SlotMediaType.audio) ||
        slotMediaAlreadyRequested(state, position, SlotMediaType.image);
  }

  Future<void> prefetchMedia(DopamineReadySlot position) async {
    final state = service.read(position.params.lessonLocalId);
    final result = LessonReadinessResolver().resolve(
      state: state,
      orchestrator: orchestrator,
      identity: LessonReadinessIdentity(
        lessonLocalId: position.params.lessonLocalId,
        itemIdx: position.itemIdx,
        marker: position.marker,
        layer: position.layer,
      ),
      params: position.params,
    );
    final lesson = result.lesson;
    if (lesson == null) return;
    queueSecondaryMedia(
      lessonLocalId: position.params.lessonLocalId,
      source: 'prefetch_media',
      mediaSlots: [ReadyWindowMediaSlot(slot: position, lesson: lesson)],
      emit: (_, _, _) {},
    );
  }

  Future<void> prefetchWindowMedia(List<DopamineReadySlot> positions) async {
    for (final position in positions) {
      await prefetchMedia(position);
    }
  }

  void _queueSecondaryMediaType({
    required String lessonLocalId,
    required String source,
    required ReadyWindowMediaSlot entry,
    required SlotMediaType mediaType,
    required String priority,
    required void Function(String lessonLocalId, String type, JsonMap payload)
    emit,
  }) {
    final mediaKey = slotMediaKey(lessonLocalId, entry.slot, mediaType);
    final state = service.read(lessonLocalId);
    if (_queuedSecondaryMediaKeys.contains(mediaKey) ||
        slotMediaAlreadyRequested(state, entry.slot, mediaType)) {
      return;
    }
    _queuedSecondaryMediaKeys.add(mediaKey);
    if (mediaType == SlotMediaType.audio) {
      orchestrator.queueAudioForReadyLesson(entry.slot.params, entry.lesson);
    } else {
      orchestrator.queueImageForReadyLesson(entry.slot.params, entry.lesson);
    }
    emit(
      lessonLocalId,
      mediaType == SlotMediaType.audio
          ? 'DOPAMINE_SLOT_AUDIO_QUEUED'
          : 'DOPAMINE_SLOT_IMAGE_QUEUED',
      {
        'source': source,
        'slot': entry.slot.slot,
        'priority': priority,
        'itemIdx': entry.slot.itemIdx,
        'marker': entry.slot.marker,
        'layer': entry.slot.layer.value,
        'mediaKey': mediaKey,
      },
    );
  }
}

class ReadyWindowMediaSlot {
  const ReadyWindowMediaSlot({required this.slot, required this.lesson});

  final DopamineReadySlot slot;
  final CompleteLesson lesson;
}

bool slotMediaAlreadyRequested(
  StudentLearningState? state,
  DopamineReadySlot slot,
  SlotMediaType mediaType,
) {
  final expectedKey = slotMediaKey(slot.params.lessonLocalId, slot, mediaType);
  final expectedLocale = slot.params.effectiveLocaleContract;
  final acceptedTypes = mediaType == SlotMediaType.audio
      ? const {'AUDIO_STARTED', 'AUDIO_READY'}
      : const {'IMAGE_STARTED', 'IMAGE_READY', 'NO_IMAGE'};
  return (state?.events ?? const <StudentLearningEvent>[]).any((event) {
    if (!acceptedTypes.contains(event.type)) return false;
    final payload = event.payload;
    final slotMedia = payload['slotMedia'];
    if (slotMedia is Map && slotMedia['cacheKey'] == expectedKey) {
      return true;
    }
    if (payload['mediaKey'] == expectedKey) return true;
    if (!_eventLocaleCompatible(payload, slotMedia, expectedLocale)) {
      return false;
    }
    final marker = payload['marker'] ?? payload['itemMarker'];
    final rawLayer = payload['layer'];
    final layer = rawLayer is num
        ? rawLayer.toInt()
        : int.tryParse(rawLayer?.toString() ?? '');
    final rawItemIdx = payload['itemIdx'];
    final itemIdx = rawItemIdx is num
        ? rawItemIdx.toInt()
        : int.tryParse(rawItemIdx?.toString() ?? '');
    final sameMarker = marker == null || marker == slot.marker;
    final sameLayer = layer == null || layer == slot.layer.value;
    final sameItem = itemIdx == null || itemIdx == slot.itemIdx;
    return sameMarker && sameLayer && sameItem;
  });
}

String slotMediaKey(
  String lessonLocalId,
  DopamineReadySlot slot,
  SlotMediaType mediaType,
) {
  return slotMediaCacheKey(
    lessonLocalId: lessonLocalId,
    marker: slot.marker ?? 'no-marker',
    itemIdx: slot.itemIdx,
    layer: slot.layer,
    mediaType: mediaType,
    localeContract: slot.params.effectiveLocaleContract,
    mediaTextLanguage: mediaType == SlotMediaType.image
        ? slot.params.effectiveLocaleContract.mediaTextLanguage
        : null,
    audioLanguage: mediaType == SlotMediaType.audio
        ? slot.params.effectiveLocaleContract.explanationLanguage
        : null,
    targetLanguage: slot.params.effectiveLocaleContract.targetLanguage,
    explanationLanguage:
        slot.params.effectiveLocaleContract.explanationLanguage,
  );
}

bool slotHasInvalidMediaLocale(
  StudentLearningState? state,
  DopamineReadySlot slot,
) {
  return (state?.events ?? const <StudentLearningEvent>[]).any((event) {
    if (event.type != 'AUDIO_READY' &&
        event.type != 'IMAGE_READY' &&
        event.type != 'NO_IMAGE') {
      return false;
    }
    final payload = event.payload;
    final marker = payload['marker'] ?? payload['itemMarker'];
    final rawLayer = payload['layer'];
    final layer = rawLayer is num
        ? rawLayer.toInt()
        : int.tryParse(rawLayer?.toString() ?? '');
    final rawItemIdx = payload['itemIdx'];
    final itemIdx = rawItemIdx is num
        ? rawItemIdx.toInt()
        : int.tryParse(rawItemIdx?.toString() ?? '');
    final sameMarker = marker == null || marker == slot.marker;
    final sameLayer = layer == null || layer == slot.layer.value;
    final sameItem = itemIdx == null || itemIdx == slot.itemIdx;
    if (!sameMarker || !sameLayer || !sameItem) return false;
    return !_eventLocaleCompatible(
      payload,
      payload['slotMedia'],
      slot.params.effectiveLocaleContract,
    );
  });
}

bool _eventLocaleCompatible(
  JsonMap payload,
  Object? slotMedia,
  SimLocaleContract expected,
) {
  final payloadLocale = _payloadLocaleContract(payload['localeContract']);
  if (payloadLocale != null) return payloadLocale.isCompatibleWith(expected);
  if (slotMedia is Map) {
    final slotLocale = _payloadLocaleContract(slotMedia['localeContract']);
    if (slotLocale != null) return slotLocale.isCompatibleWith(expected);
    if (slotMedia['legacyLocale'] == true) return false;
  }
  return false;
}

SimLocaleContract? _payloadLocaleContract(Object? raw) {
  if (raw is! Map) return null;
  return SimLocaleContract.fromJson(Map<String, dynamic>.from(raw));
}
