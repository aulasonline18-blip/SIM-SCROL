import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'audio_core.dart';

/// Real audio adapter — plays WAV data URLs from the TTS endpoint.
/// Mirrors Web behaviour: single currentAudio instance, overwritten on each new speak().
class PlatformAudioAdapter implements AudioPlaybackAdapter {
  AudioPlayer? _player;
  FlutterTts? _tts;
  StreamSubscription<void>? _completeSubscription;
  void Function()? _onEnd;

  AudioPlayer get _activePlayer {
    final existing = _player;
    if (existing != null) return existing;
    final created = AudioPlayer();
    _completeSubscription = created.onPlayerComplete.listen((_) {
      _onEnd?.call();
      _onEnd = null;
    });
    _player = created;
    return created;
  }

  @override
  Future<bool> playDataUrl(String dataUrl, SpeakOptions opts) async {
    final audio = _extractAudioData(dataUrl);
    if (audio == null) return false;
    _stop();
    _onEnd = opts.onEnd;
    try {
      await _activePlayer.play(
        BytesSource(audio.bytes, mimeType: audio.mimeType),
      );
      opts.onStart?.call();
      return true;
    } catch (_) {
      _onEnd = null;
      opts.onEnd?.call();
      return false;
    }
  }

  @override
  Future<bool> speakWithPlatformTts(String text, SpeakOptions opts) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      opts.onEnd?.call();
      return false;
    }
    _stop();
    _onEnd = opts.onEnd;
    try {
      final tts = _activeTts;
      await tts.setLanguage(simTtsLanguageForStableLang(opts.lang));
      await tts.setSpeechRate(0.48);
      await tts.setPitch(1.0);
      await tts.awaitSpeakCompletion(true);
      opts.onStart?.call();
      final result = await tts.speak(trimmed);
      final ok = result == 1 || result == true;
      if (!ok) {
        _onEnd = null;
        opts.onEnd?.call();
      }
      return ok;
    } catch (_) {
      _onEnd = null;
      opts.onEnd?.call();
      return false;
    }
  }

  FlutterTts get _activeTts {
    final existing = _tts;
    if (existing != null) return existing;
    final created = FlutterTts();
    created.setCompletionHandler(() {
      _onEnd?.call();
      _onEnd = null;
    });
    created.setCancelHandler(() {
      _onEnd?.call();
      _onEnd = null;
    });
    created.setErrorHandler((_) {
      _onEnd?.call();
      _onEnd = null;
    });
    _tts = created;
    return created;
  }

  @override
  void stop() => _stop();

  void _stop() {
    _onEnd = null;
    final player = _player;
    if (player != null) {
      unawaited(player.stop());
    }
    final tts = _tts;
    if (tts != null) {
      unawaited(tts.stop());
    }
  }

  /// Decodes `data:audio/*;base64,<payload>` into typed bytes for audioplayers.
  _AudioData? _extractAudioData(String dataUrl) {
    try {
      final comma = dataUrl.indexOf(',');
      if (comma < 0) return null;
      final header = dataUrl.substring(0, comma).toLowerCase();
      if (!header.startsWith('data:audio/') || !header.contains(';base64')) {
        return null;
      }
      final mimeType = header
          .substring('data:'.length)
          .split(';')
          .first
          .trim();
      if (mimeType.isEmpty || !mimeType.startsWith('audio/')) return null;
      final payload = dataUrl.substring(comma + 1);
      final bytes = base64Decode(payload);
      if (bytes.isEmpty) return null;
      return _AudioData(bytes: bytes, mimeType: mimeType);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    unawaited(_completeSubscription?.cancel());
    _player?.dispose();
    unawaited(_tts?.stop());
  }
}

class _AudioData {
  const _AudioData({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

String simTtsLanguageForStableLang(String? lang) {
  final stable = (lang ?? '').trim().toLowerCase();
  if (stable.isEmpty) return 'en-US';
  if (stable.startsWith('pt') ||
      stable.contains('portugu') ||
      stable.contains('brasil')) {
    return 'pt-BR';
  }
  if (stable.startsWith('es') ||
      stable.contains('spanish') ||
      stable.contains('español')) {
    return 'es-ES';
  }
  if (stable.startsWith('fr') ||
      stable.contains('french') ||
      stable.contains('français')) {
    return 'fr-FR';
  }
  if (stable.startsWith('ja') ||
      stable.contains('japanese') ||
      stable.contains('日本')) {
    return 'ja-JP';
  }
  if (stable.startsWith('de') || stable.contains('german')) return 'de-DE';
  if (stable.startsWith('it') || stable.contains('italian')) return 'it-IT';
  if (stable.startsWith('ar') || stable.contains('arabic')) return 'ar';
  if (stable.startsWith('hi') || stable.contains('hindi')) return 'hi-IN';
  if (stable.startsWith('zh') ||
      stable.contains('chinese') ||
      stable.contains('中文')) {
    return 'zh-CN';
  }
  if (stable.startsWith('ko') || stable.contains('korean')) return 'ko-KR';
  if (stable.startsWith('ru') || stable.contains('russian')) return 'ru-RU';
  if (stable.startsWith('en') || stable.contains('english')) return 'en-US';
  return 'en-US';
}
