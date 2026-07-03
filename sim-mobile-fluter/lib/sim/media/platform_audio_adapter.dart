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
    final bytes = _extractWavBytes(dataUrl);
    if (bytes == null) return false;
    _stop();
    _onEnd = opts.onEnd;
    try {
      await _activePlayer.play(BytesSource(bytes));
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
      await tts.setLanguage(_ttsLanguage(opts.lang));
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

  String _ttsLanguage(String? lang) {
    final stable = (lang ?? '').toLowerCase();
    if (stable.startsWith('pt')) return 'pt-BR';
    if (stable.startsWith('es')) return 'es-ES';
    if (stable.startsWith('fr')) return 'fr-FR';
    if (stable.startsWith('ja')) return 'ja-JP';
    return 'en-US';
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

  /// Decodes `data:audio/wav;base64,<payload>` → raw bytes.
  Uint8List? _extractWavBytes(String dataUrl) {
    try {
      final comma = dataUrl.indexOf(',');
      if (comma < 0) return null;
      final header = dataUrl.substring(0, comma).toLowerCase();
      if (!header.startsWith('data:audio/') || !header.contains(';base64')) {
        return null;
      }
      final payload = dataUrl.substring(comma + 1);
      return base64Decode(payload);
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
