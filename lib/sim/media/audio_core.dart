import 'audio_preference.dart';
import '../localization/sim_locale_contract.dart';

class SpeakOptions {
  const SpeakOptions({
    this.lang,
    this.rate = 1,
    this.lessonKey,
    this.voice = 'Charon',
    this.localeContract,
    this.audioLanguage,
    this.targetLanguage,
    this.explanationLanguage,
    this.textHash,
    this.onStart,
    this.onEnd,
  });

  final String? lang;
  final double rate;
  final String? lessonKey;
  final String voice;
  final SimLocaleContract? localeContract;
  final String? audioLanguage;
  final String? targetLanguage;
  final String? explanationLanguage;
  final String? textHash;
  final void Function()? onStart;
  final void Function()? onEnd;
}

abstract interface class GeneratedAudioClient {
  Future<String?> generateAudio({
    required String text,
    required String lang,
    required String voice,
    required String lessonKey,
    double speed = 1,
    String? explanationLanguage,
    String? targetLanguage,
    SimLocaleContract? localeContract,
    String? textHash,
  });
}

abstract interface class AudioPlaybackAdapter {
  Future<bool> playDataUrl(String dataUrl, SpeakOptions opts);
  Future<bool> speakWithPlatformTts(String text, SpeakOptions opts);
  void stop();
}

typedef AudioErrorListener = void Function(Object error);

class NoopAudioPlaybackAdapter implements AudioPlaybackAdapter {
  String? lastSpokenText;
  String? lastDataUrl;

  @override
  Future<bool> playDataUrl(String dataUrl, SpeakOptions opts) async {
    lastDataUrl = dataUrl;
    opts.onStart?.call();
    opts.onEnd?.call();
    return true;
  }

  @override
  Future<bool> speakWithPlatformTts(String text, SpeakOptions opts) async {
    lastSpokenText = text;
    opts.onStart?.call();
    opts.onEnd?.call();
    return text.trim().isNotEmpty;
  }

  @override
  void stop() {}
}

class AudioCore {
  AudioCore({
    required this.preference,
    required this.playback,
    this.generatedAudioClient,
    this.stableLangProvider,
    this.onGeneratedAudioError,
    this.availabilityProbe,
    this.maxAudioCache = 12,
  }) {
    preference.subscribe((enabled) {
      if (!enabled) stop();
    });
  }

  final AudioPreference preference;
  final AudioPlaybackAdapter playback;
  final GeneratedAudioClient? generatedAudioClient;
  final String Function()? stableLangProvider;
  final AudioErrorListener? onGeneratedAudioError;
  final bool Function()? availabilityProbe;
  final int maxAudioCache;
  final Map<String, String> _generatedAudioCache = {};

  bool available() {
    if (!preference.getAudioEnabled()) return false;
    if (generatedAudioClient != null) return true;
    final probe = availabilityProbe;
    if (probe != null) return probe();
    return playback is! NoopAudioPlaybackAdapter;
  }

  void prepareText(String text) {
    text.trim();
  }

  void stop() {
    playback.stop();
  }

  Future<bool> speak(
    String text, [
    SpeakOptions opts = const SpeakOptions(),
  ]) async {
    if (!preference.getAudioEnabled()) {
      opts.onEnd?.call();
      return false;
    }
    final clean = text.trim();
    if (clean.isEmpty) {
      opts.onEnd?.call();
      return false;
    }
    final audioLanguage = _explicitAudioLanguage(opts);
    if (audioLanguage == null) {
      opts.onEnd?.call();
      return false;
    }
    final key = audioCacheKey(clean, opts);
    final cached = _generatedAudioCache[key];
    if (cached != null && await playback.playDataUrl(cached, opts)) return true;
    final client = generatedAudioClient;
    if (client != null) {
      String? generated;
      try {
        generated = await client.generateAudio(
          text: clean,
          lang: audioLanguage,
          voice: opts.voice,
          lessonKey: opts.lessonKey ?? key,
          speed: opts.rate,
          explanationLanguage:
              opts.explanationLanguage ??
              opts.localeContract?.explanationLanguage,
          targetLanguage:
              opts.targetLanguage ?? opts.localeContract?.targetLanguage,
          localeContract: opts.localeContract,
          textHash: opts.textHash ?? hashString(clean),
        );
      } catch (error) {
        onGeneratedAudioError?.call(error);
      }
      if (generated != null && generated.isNotEmpty) {
        if (await playback.playDataUrl(generated, opts)) {
          rememberAudio(key, generated);
          return true;
        }
      }
    }
    return await playback.speakWithPlatformTts(
      clean,
      SpeakOptions(
        lang: audioLanguage,
        rate: opts.rate,
        lessonKey: opts.lessonKey,
        voice: opts.voice,
        localeContract: opts.localeContract,
        audioLanguage: audioLanguage,
        targetLanguage: opts.targetLanguage,
        explanationLanguage: opts.explanationLanguage,
        textHash: opts.textHash ?? hashString(clean),
        onStart: opts.onStart,
        onEnd: opts.onEnd,
      ),
    );
  }

  Future<bool> speakSequence(
    List<String?> parts, [
    SpeakOptions opts = const SpeakOptions(),
  ]) {
    final joined = parts
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join('. ')
        .replaceAll('..', '.');
    return speak(joined, opts);
  }

  void rememberAudio(String key, String dataUrl) {
    _generatedAudioCache.remove(key);
    _generatedAudioCache[key] = dataUrl;
    while (_generatedAudioCache.length > maxAudioCache) {
      _generatedAudioCache.remove(_generatedAudioCache.keys.first);
    }
  }

  String audioCacheKey(String text, SpeakOptions opts) {
    return [
      opts.lessonKey ?? 'lesson',
      _explicitAudioLanguage(opts) ?? 'audio-language-missing',
      opts.voice,
      opts.rate.toStringAsFixed(2),
      opts.localeContract?.mediaIdentity(
            audioLanguage: _explicitAudioLanguage(opts),
            voice: opts.voice,
            speed: opts.rate,
            textHash: opts.textHash ?? hashString(text),
          ) ??
          'media-locale:missing',
      opts.textHash ?? hashString(text),
    ].join('|');
  }

  String? _explicitAudioLanguage(SpeakOptions opts) {
    final explicit =
        opts.audioLanguage ??
        opts.lang ??
        opts.localeContract?.explanationLanguage ??
        stableLangProvider?.call();
    final clean = explicit?.trim();
    if (clean == null || clean.isEmpty) return null;
    return stableLangToBCP47(clean);
  }
}

String hashString(String input) {
  var hash = 5381;
  for (final unit in input.codeUnits) {
    hash = ((hash << 5) + hash) ^ unit;
  }
  return (hash & 0xffffffff).toRadixString(36);
}

String stableLangToBCP47([String? stableLang]) {
  final raw = (stableLang ?? '').toLowerCase().trim();
  final map = <RegExp, String>{
    RegExp(r'^(en|engl)'): 'en-US',
    RegExp(r'^(pt|portu|brasil)'): 'pt-BR',
    RegExp(r'^(es|span|espa|castel)'): 'es-ES',
    RegExp(r'^(fr|franc|french)'): 'fr-FR',
    RegExp(r'^(de|alem|german|deutsch)'): 'de-DE',
    RegExp(r'^(it|ital)'): 'it-IT',
    RegExp(r'^(ja|japo|japan|日本)'): 'ja-JP',
    RegExp(r'^(zh|chin|中文|mandarin)'): 'zh-CN',
    RegExp(r'^(ko|kore|한국)'): 'ko-KR',
    RegExp(r'^(ar|arab|عرب)'): 'ar-SA',
    RegExp(r'^(ru|russ|русск)'): 'ru-RU',
    RegExp(r'^(hi|hind)'): 'hi-IN',
    RegExp(r'^(nl|dutch|holand)'): 'nl-NL',
    RegExp(r'^(sv|swed|sueco)'): 'sv-SE',
    RegExp(r'^(no|norw|noruego)'): 'nb-NO',
    RegExp(r'^(da|dan)'): 'da-DK',
    RegExp(r'^(fi|finn|fin)'): 'fi-FI',
    RegExp(r'^(pl|pol)'): 'pl-PL',
    RegExp(r'^(tr|turk|türk)'): 'tr-TR',
    RegExp(r'^(he|hebr|עבר)'): 'he-IL',
    RegExp(r'^(uk|ukrain|україн)'): 'uk-UA',
    RegExp(r'^(cs|czech|česk)'): 'cs-CZ',
    RegExp(r'^(el|greek|ελλ)'): 'el-GR',
    RegExp(r'^(ro|roman)'): 'ro-RO',
    RegExp(r'^(hu|hungar)'): 'hu-HU',
    RegExp(r'^(id|indones)'): 'id-ID',
    RegExp(r'^(th|thai)'): 'th-TH',
    RegExp(r'^(vi|vietnam)'): 'vi-VN',
  };
  for (final entry in map.entries) {
    if (entry.key.hasMatch(raw)) return entry.value;
  }
  return 'en-US';
}
