import '../state/student_learning_state.dart';
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
    List<String?> parts,
  ) {
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
    });
  }

  void markLessonAudioStarted(LessonMediaPosition position) {
    _appendMediaEvent(
      position,
      'AUDIO_STARTED',
      {'phase': 'started', 'source': 'tts-playback'},
      audioStatus: 'playing',
      audioPlaying: true,
    );
  }

  void markLessonAudioReady(
    LessonMediaPosition position, {
    String? lessonKey,
    String? language,
    String? voice,
  }) {
    final payload = <String, dynamic>{
      'phase': 'ready',
      'source': 'tts-generated',
    };
    if (lessonKey != null) payload['lessonKey'] = lessonKey;
    if (language != null) payload['language'] = language;
    if (voice != null) payload['voice'] = voice;
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
        ),
      ).toJson();
    }
    _appendMediaEvent(
      position,
      'AUDIO_READY',
      payload,
      audioStatus: 'ready',
      audioPlaying: false,
      lessonKey: lessonKey,
      language: language,
      voice: voice,
    );
  }

  void markLessonAudioFailed(LessonMediaPosition position, {String? error}) {
    final safeError = _safeMediaError(error);
    _appendMediaEvent(
      position,
      'AUDIO_FAILED',
      {'phase': 'failed', 'source': 'tts-generated', 'errorCode': safeError},
      audioStatus: 'failed',
      audioPlaying: false,
      error: safeError,
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
  }) async {
    final sequence = parts
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (sequence.isEmpty) return false;
    final lessonKey = [
      position.lessonLocalId,
      position.itemMarker ?? 'no-marker',
      position.layer?.value ?? 'L?',
    ].join(':');
    try {
      final ok = await audioCore.speakSequence(
        sequence,
        SpeakOptions(
          lessonKey: lessonKey,
          lang: language,
          voice: voice ?? voiceByLang(language ?? ''),
          onStart: () {
            markLessonAudioStarted(position);
            onStart?.call();
          },
          onEnd: onEnd,
        ),
      );
      if (ok) {
        markLessonAudioReady(
          position,
          lessonKey: lessonKey,
          language: language,
          voice: voice,
        );
      } else {
        markLessonAudioFailed(position, error: 'audio_playback_unavailable');
      }
      return ok;
    } catch (error) {
      markLessonAudioFailed(position, error: 'audio_playback_unavailable');
      return false;
    }
  }

  void markLessonImageReady(
    LessonMediaPosition position, {
    String? cacheKey,
    String? imageUrl,
  }) {
    _appendMediaEvent(position, 'IMAGE_READY', {
      'phase': 'ready',
      if (cacheKey != null) 'cacheKeyHash': hashString(cacheKey),
      'hasImageUrl': imageUrl != null && imageUrl.isNotEmpty,
    });
  }

  void markLessonNoImage(LessonMediaPosition position, {String? reason}) {
    _appendMediaEvent(position, 'NO_IMAGE', {
      'phase': 'no_image',
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
    });
  }

  void markLessonImageStarted(
    LessonMediaPosition position, {
    String? cacheKey,
  }) {
    _appendMediaEvent(position, 'IMAGE_STARTED', {
      'phase': 'started',
      if (cacheKey != null) 'cacheKeyHash': hashString(cacheKey),
    });
  }

  void markLessonImageFailed(LessonMediaPosition position, {String? error}) {
    _appendMediaEvent(position, 'IMAGE_FAILED', {
      'phase': 'failed',
      'errorCode': _safeMediaError(error),
    });
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
