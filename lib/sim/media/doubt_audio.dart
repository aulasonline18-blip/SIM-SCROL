import '../localization/sim_locale_contract.dart';
import 'audio_core.dart';
import 'audio_preference.dart';
import 'lesson_audio_api_contract.dart';

class DoubtAudio {
  DoubtAudio({required this.audioCore, required this.preference});

  final AudioCore audioCore;
  final AudioPreference preference;

  Future<bool> speakDoubt(
    String text, {
    String? lang,
    SimLocaleContract? localeContract,
    required String lessonKey,
  }) {
    return speakText(
      text,
      lang: lang,
      localeContract: localeContract,
      lessonKey: '$lessonKey:doubt',
    );
  }

  Future<bool> speakText(
    String text, {
    String? lang,
    SimLocaleContract? localeContract,
    required String lessonKey,
  }) {
    if (!preference.getAudioEnabled()) return Future.value(false);
    final cleanText = text.trim();
    if (cleanText.isEmpty) return Future.value(false);
    final audioLanguage = lang?.trim().isNotEmpty == true
        ? lang!.trim()
        : localeContract?.explanationLanguage;
    if (audioLanguage == null || audioLanguage.trim().isEmpty) {
      return Future.value(false);
    }
    final textHash = hashString(cleanText);
    final resolvedVoice = voiceByLang(audioLanguage);
    final localeIdentity = localeContract?.mediaIdentity(
      audioLanguage: audioLanguage,
      voice: resolvedVoice,
      speed: 1,
      textHash: textHash,
      sourceVersion: 'doubt-audio.v1',
    );
    return audioCore.speak(
      cleanText,
      SpeakOptions(
        lang: audioLanguage,
        audioLanguage: audioLanguage,
        localeContract: localeContract,
        explanationLanguage: localeContract?.explanationLanguage,
        targetLanguage: localeContract?.targetLanguage,
        lessonKey: [
          lessonKey,
          localeIdentity ?? 'media-locale:missing',
        ].join(':'),
        voice: resolvedVoice,
        textHash: textHash,
      ),
    );
  }

  void stopDoubtAudio() {
    audioCore.stop();
  }
}
