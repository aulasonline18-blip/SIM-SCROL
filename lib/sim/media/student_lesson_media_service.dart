import '../state/student_learning_state.dart';
import '../localization/sim_locale_contract.dart';
import 'audio_core.dart';
import 'lesson_audio_api_contract.dart';
import 'slot_media_contract.dart';

class LessonMediaPosition {
  const LessonMediaPosition({
    required this.lessonLocalId,
    this.itemMarker,
    this.itemIdx,
    this.layer,
  });

  final String lessonLocalId;
  final String? itemMarker;
  final int? itemIdx;
  final LessonLayer? layer;
}

class StudentLessonMediaService {
  StudentLessonMediaService({
    required this.audioCore,
    required this.readState,
    required this.writeState,
  });

  final AudioCore audioCore;
  final StudentLearningState Function(String lessonLocalId) readState;
  final StudentLearningState Function(StudentLearningState state) writeState;

  void prepareLessonAudioText(
    LessonMediaPosition position,
    List<String?> parts, [
    SimLocaleContract? localeContract,
  ]) {
    final text = parts
        .whereType<String>()
        .where((p) => p.isNotEmpty)
        .join('. ');
    if (text.isEmpty) return;
    audioCore.prepareText(text);
    _appendMediaEvent(position, 'AUDIO_READY', {
      'phase': 'ready',
      'source': 'tts-prepare',
      'hasAudioText': true,
    }, localeContract: localeContract);
  }

  void markLessonAudioStarted(
    LessonMediaPosition position, {
    SimLocaleContract? localeContract,
    String? audioLanguage,
    String? voice,
    double speed = 1,
    String? textHash,
  }) {
    _appendMediaEvent(
      position,
      'AUDIO_STARTED',
      {
        'phase': 'started',
        'source': 'tts-playback',
        'audioLanguage': ?audioLanguage,
        'voice': ?voice,
        'speed': speed,
        'textHash': ?textHash,
      },
      audioStatus: 'playing',
      audioPlaying: true,
      localeContract: localeContract,
      language: audioLanguage,
      voice: voice,
    );
  }

  void markLessonAudioReady(
    LessonMediaPosition position, {
    String? lessonKey,
    String? language,
    String? voice,
    double speed = 1,
    String? textHash,
    SimLocaleContract? localeContract,
  }) {
    final audioLanguage = language?.trim().isNotEmpty == true
        ? language!.trim()
        : localeContract?.explanationLanguage;
    final payload = <String, dynamic>{
      'phase': 'ready',
      'source': 'tts-generated',
    };
    if (lessonKey != null) payload['lessonKey'] = lessonKey;
    if (audioLanguage != null) {
      payload['language'] = audioLanguage;
      payload['audioLanguage'] = audioLanguage;
    }
    if (voice != null) payload['voice'] = voice;
    payload['speed'] = speed;
    if (textHash != null) payload['textHash'] = textHash;
    if (localeContract != null) {
      payload['localeContract'] = localeContract.toJson();
    }
    final marker = position.itemMarker;
    final layer = position.layer;
    if (marker != null && layer != null) {
      payload['slotMedia'] = SlotMediaContract(
        lessonLocalId: position.lessonLocalId,
        marker: marker,
        itemIdx: position.itemIdx ?? 0,
        layer: layer,
        mediaType: SlotMediaType.audio,
        status: 'ready',
        source: 'tts-generated',
        createdAt: DateTime.now().toIso8601String(),
        cacheKey: slotMediaCacheKey(
          lessonLocalId: position.lessonLocalId,
          marker: marker,
          itemIdx: position.itemIdx ?? 0,
          layer: layer,
          mediaType: SlotMediaType.audio,
          localeContract: localeContract,
          audioLanguage: audioLanguage,
          voice: voice,
          speed: speed,
          textHash: textHash,
        ),
        localeContract: localeContract,
        audioLanguage: audioLanguage,
        targetLanguage: localeContract?.targetLanguage,
        explanationLanguage: localeContract?.explanationLanguage,
        voice: voice,
        speed: speed,
      ).toJson();
    }
    _appendMediaEvent(
      position,
      'AUDIO_READY',
      payload,
      audioStatus: 'ready',
      audioPlaying: false,
      lessonKey: lessonKey,
      language: audioLanguage,
      voice: voice,
      localeContract: localeContract,
    );
  }

  void markLessonAudioFailed(
    LessonMediaPosition position, {
    String? error,
    SimLocaleContract? localeContract,
  }) {
    final safeError = _safeMediaError(error);
    _appendMediaEvent(
      position,
      'AUDIO_FAILED',
      {'phase': 'failed', 'source': 'tts-generated', 'errorCode': safeError},
      audioStatus: 'failed',
      audioPlaying: false,
      error: safeError,
      localeContract: localeContract,
    );
  }

  void stopLessonAudio() {
    audioCore.stop();
  }

  Future<bool> playLessonAudioSequence(
    LessonMediaPosition position,
    List<String?> parts, {
    void Function()? onEnd,
    void Function()? onStart,
    String? language,
    String? voice,
    double speed = 1,
    SimLocaleContract? localeContract,
  }) async {
    final sequence = parts
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (sequence.isEmpty) return false;
    final audioLanguage = language?.trim().isNotEmpty == true
        ? language!.trim()
        : localeContract?.explanationLanguage;
    if (audioLanguage == null || audioLanguage.trim().isEmpty) return false;
    final textHash = hashString(sequence.join('. '));
    final resolvedVoice = voice ?? voiceByLang(audioLanguage);
    final lessonKey = [
      position.lessonLocalId,
      position.itemMarker ?? 'no-marker',
      position.layer?.value ?? 'L?',
      localeContract?.mediaIdentity(
            audioLanguage: audioLanguage,
            voice: resolvedVoice,
            speed: speed,
            textHash: textHash,
          ) ??
          'media-locale:missing',
    ].join(':');
    try {
      final ok = await audioCore.speakSequence(
        sequence,
        SpeakOptions(
          lessonKey: lessonKey,
          lang: audioLanguage,
          audioLanguage: audioLanguage,
          localeContract: localeContract,
          targetLanguage: localeContract?.targetLanguage,
          explanationLanguage: localeContract?.explanationLanguage,
          textHash: textHash,
          rate: speed,
          voice: resolvedVoice,
          onStart: () {
            markLessonAudioStarted(
              position,
              localeContract: localeContract,
              audioLanguage: audioLanguage,
              voice: resolvedVoice,
              speed: speed,
              textHash: textHash,
            );
            onStart?.call();
          },
          onEnd: () {
            markLessonAudioReady(
              position,
              lessonKey: lessonKey,
              language: audioLanguage,
              voice: resolvedVoice,
              speed: speed,
              textHash: textHash,
              localeContract: localeContract,
            );
            onEnd?.call();
          },
        ),
      );
      if (!ok) {
        markLessonAudioFailed(
          position,
          error: 'audio_playback_unavailable',
          localeContract: localeContract,
        );
      }
      return ok;
    } catch (error) {
      markLessonAudioFailed(
        position,
        error: 'audio_playback_unavailable',
        localeContract: localeContract,
      );
      return false;
    }
  }

  void markLessonImageReady(
    LessonMediaPosition position, {
    String? cacheKey,
    String? imageUrl,
    SimLocaleContract? localeContract,
    String visualTextPolicy = 'explanation',
  }) {
    _appendMediaEvent(position, 'IMAGE_READY', {
      'phase': 'ready',
      if (cacheKey != null) 'cacheKeyHash': hashString(cacheKey),
      'hasImageUrl': imageUrl != null && imageUrl.isNotEmpty,
      if (localeContract != null) 'localeContract': localeContract.toJson(),
      if (localeContract != null)
        'mediaTextLanguage': localeContract.mediaTextLanguage,
      'visualTextPolicy': visualTextPolicy,
      if (position.itemMarker != null && position.layer != null)
        'slotMedia': SlotMediaContract(
          lessonLocalId: position.lessonLocalId,
          marker: position.itemMarker!,
          itemIdx: position.itemIdx ?? 0,
          layer: position.layer!,
          mediaType: SlotMediaType.image,
          status: 'ready',
          source: 'visual-generated',
          createdAt: DateTime.now().toIso8601String(),
          cacheKey: slotMediaCacheKey(
            lessonLocalId: position.lessonLocalId,
            marker: position.itemMarker!,
            itemIdx: position.itemIdx ?? 0,
            layer: position.layer!,
            mediaType: SlotMediaType.image,
            localeContract: localeContract,
            mediaTextLanguage: localeContract?.mediaTextLanguage,
            visualTextPolicy: visualTextPolicy,
          ),
          localeContract: localeContract,
          mediaTextLanguage: localeContract?.mediaTextLanguage,
          targetLanguage: localeContract?.targetLanguage,
          explanationLanguage: localeContract?.explanationLanguage,
        ).toJson(),
    }, localeContract: localeContract);
  }

  void markLessonNoImage(
    LessonMediaPosition position, {
    String? reason,
    SimLocaleContract? localeContract,
  }) {
    _appendMediaEvent(position, 'NO_IMAGE', {
      'phase': 'no_image',
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
      if (localeContract != null) 'localeContract': localeContract.toJson(),
    }, localeContract: localeContract);
  }

  void markLessonImageStarted(
    LessonMediaPosition position, {
    String? cacheKey,
    SimLocaleContract? localeContract,
    String visualTextPolicy = 'explanation',
  }) {
    _appendMediaEvent(position, 'IMAGE_STARTED', {
      'phase': 'started',
      if (cacheKey != null) 'cacheKeyHash': hashString(cacheKey),
      if (localeContract != null) 'localeContract': localeContract.toJson(),
      if (localeContract != null)
        'mediaTextLanguage': localeContract.mediaTextLanguage,
      'visualTextPolicy': visualTextPolicy,
    }, localeContract: localeContract);
  }

  void markLessonImageFailed(
    LessonMediaPosition position, {
    String? error,
    SimLocaleContract? localeContract,
  }) {
    _appendMediaEvent(position, 'IMAGE_FAILED', {
      'phase': 'failed',
      'errorCode': _safeMediaError(error),
      if (localeContract != null) 'localeContract': localeContract.toJson(),
    }, localeContract: localeContract);
  }

  void _appendMediaEvent(
    LessonMediaPosition position,
    String type,
    JsonMap payload, {
    String? audioStatus,
    bool? audioPlaying,
    String? lessonKey,
    String? language,
    String? voice,
    String? error,
    SimLocaleContract? localeContract,
  }) {
    final state = readState(position.lessonLocalId);
    final now = DateTime.now().millisecondsSinceEpoch;
    writeState(
      state.copyWith(
        audio: audioStatus == null
            ? state.audio
            : state.audio.copyWith(
                status: audioStatus,
                playing: audioPlaying,
                updatedAt: now,
                lessonKey: lessonKey,
                language: language,
                voice: voice,
                error: error,
              ),
        events: [
          ...state.events,
          StudentLearningEvent(
            type: type,
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: {
              ...payload,
              'itemMarker': position.itemMarker,
              'itemIdx': position.itemIdx,
              'layer': position.layer?.value,
              if (localeContract != null)
                'localeContract': localeContract.toJson(),
            },
          ),
        ],
      ),
    );
  }
}

String? _safeMediaError(String? error) {
  final raw = error?.trim();
  if (raw == null || raw.isEmpty) return null;
  if (RegExp(r'^[A-Z0-9_:-]{3,80}$').hasMatch(raw)) return raw;
  return 'SIM_MEDIA_ERROR_${hashString(raw)}';
}
