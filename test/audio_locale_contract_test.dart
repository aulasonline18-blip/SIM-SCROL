import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/media/audio_core.dart';
import 'package:sim_mobile/sim/media/audio_preference.dart';

import 'support/memory_test_stores.dart';

const _locale = SimLocaleContract(
  interfaceLocale: 'es',
  learningLocale: 'en',
  explanationLanguage: 'Spanish',
  mediaTextLanguage: 'Spanish',
  targetLanguage: 'English',
  source: SimLocaleSource.userSelected,
);

class _RecordingAudioClient implements GeneratedAudioClient {
  String? lang;
  String? explanationLanguage;
  String? targetLanguage;
  SimLocaleContract? localeContract;
  double? speed;
  String? textHash;

  @override
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
  }) async {
    this.lang = lang;
    this.explanationLanguage = explanationLanguage;
    this.targetLanguage = targetLanguage;
    this.localeContract = localeContract;
    this.speed = speed;
    this.textHash = textHash;
    return 'data:audio/wav;base64,AAAA';
  }
}

void main() {
  test('audio payload carrega audioLanguage e localeContract', () async {
    final preference = AudioPreference(storage: MemoryAudioPreferenceStorage());
    final client = _RecordingAudioClient();
    final core = AudioCore(
      preference: preference,
      playback: NoopAudioPlaybackAdapter(),
      generatedAudioClient: client,
    );

    final ok = await core.speak(
      'Texto explicativo',
      const SpeakOptions(
        lang: 'Spanish',
        audioLanguage: 'Spanish',
        explanationLanguage: 'Spanish',
        targetLanguage: 'English',
        localeContract: _locale,
        lessonKey: 'lesson-1:M1',
        voice: 'Charon',
        rate: 1.15,
        textHash: 'txt-1',
      ),
    );

    expect(ok, isTrue);
    expect(client.lang, 'es-ES');
    expect(client.explanationLanguage, 'Spanish');
    expect(client.targetLanguage, 'English');
    expect(client.localeContract, _locale);
    expect(client.speed, 1.15);
    expect(client.textHash, 'txt-1');
  });

  test('audio cache key muda com idioma, voz, velocidade e hash', () {
    final preference = AudioPreference(storage: MemoryAudioPreferenceStorage());
    final core = AudioCore(
      preference: preference,
      playback: NoopAudioPlaybackAdapter(),
    );
    final base = core.audioCacheKey(
      'Texto',
      const SpeakOptions(
        audioLanguage: 'Spanish',
        localeContract: _locale,
        lessonKey: 'lesson-1:M1',
        voice: 'Charon',
        rate: 1,
        textHash: 'a',
      ),
    );

    expect(
      core.audioCacheKey(
        'Texto',
        const SpeakOptions(
          audioLanguage: 'English',
          localeContract: SimLocaleContract(
            interfaceLocale: 'en',
            learningLocale: 'en',
            explanationLanguage: 'English',
            mediaTextLanguage: 'English',
            targetLanguage: 'English',
            source: SimLocaleSource.userSelected,
          ),
          lessonKey: 'lesson-1:M1',
          voice: 'Charon',
          rate: 1,
          textHash: 'a',
        ),
      ),
      isNot(base),
    );
    expect(
      core.audioCacheKey(
        'Texto',
        const SpeakOptions(
          audioLanguage: 'Spanish',
          localeContract: _locale,
          lessonKey: 'lesson-1:M1',
          voice: 'Nova',
          rate: 1.25,
          textHash: 'b',
        ),
      ),
      isNot(base),
    );
  });

  test('sem idioma explicito audio nao gera silenciosamente', () async {
    final preference = AudioPreference(storage: MemoryAudioPreferenceStorage());
    final client = _RecordingAudioClient();
    final core = AudioCore(
      preference: preference,
      playback: NoopAudioPlaybackAdapter(),
      generatedAudioClient: client,
    );

    expect(await core.speak('Texto sem locale'), isFalse);
    expect(client.lang, isNull);
  });
}
