import '../localization/sim_locale_contract.dart';

class GenerateLessonAudioRequest {
  const GenerateLessonAudioRequest({
    required this.text,
    required this.lessonKey,
    this.lang = '',
    this.voice = '',
    this.speed = 1,
    this.explanationLanguage,
    this.targetLanguage,
    this.localeContract,
    this.textHash,
  });

  final String text;
  final String lang;
  final String lessonKey;
  final String voice;
  final double speed;
  final String? explanationLanguage;
  final String? targetLanguage;
  final SimLocaleContract? localeContract;
  final String? textHash;

  GenerateLessonAudioRequest normalized() {
    final cleanText = text.trim();
    if (cleanText.length > maxAudioInputChars) {
      throw const FormatException('AUDIO_TEXT_TOO_LARGE');
    }
    final cleanLessonKey = lessonKey.trim();
    if (cleanLessonKey.length > 180) {
      throw const FormatException('AUDIO_LESSON_KEY_TOO_LARGE');
    }
    return GenerateLessonAudioRequest(
      text: cleanText,
      lang: lang.trim().length > 80
          ? lang.trim().substring(0, 80)
          : lang.trim(),
      lessonKey: cleanLessonKey,
      voice: voice.trim().isEmpty ? voiceByLang(lang) : voice.trim(),
      speed: speed <= 0 ? 1 : speed,
      explanationLanguage: explanationLanguage?.trim(),
      targetLanguage: targetLanguage?.trim(),
      localeContract: localeContract?.normalized(),
      textHash: textHash?.trim(),
    );
  }
}

class GenerateLessonAudioResponse {
  const GenerateLessonAudioResponse({
    required this.dataUrl,
    required this.voice,
    required this.model,
  });

  final String dataUrl;
  final String voice;
  final String model;
}

const String geminiTtsModel = 'gemini-2.5-flash-preview-tts';
const int audioRequestTimeoutMs = 95000;
const int maxAudioInputChars = 4000;

String voiceByLang(String lang) {
  final normalized = lang.trim();
  final base = normalized.split('-').first;
  const voices = {
    'pt': 'Charon',
    'pt-BR': 'Charon',
    'en': 'Charon',
    'en-US': 'Charon',
    'es': 'Fenrir',
    'fr': 'Fenrir',
  };
  return voices[normalized] ?? voices[base] ?? 'Charon';
}
