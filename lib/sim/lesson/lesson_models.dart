import '../state/student_learning_state.dart';
import '../media/lesson_image_api_contract.dart';

enum LessonMode { session, simulado, reforco, amparo }

class LessonContent {
  const LessonContent({
    required this.explanation,
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.whyCorrect,
    this.whyWrong,
  });

  final String explanation;
  final String question;
  final Map<AnswerLetter, String> options;
  final AnswerLetter correctAnswer;
  final String? whyCorrect;
  final Object? whyWrong;

  String get audioText => [
    explanation,
    question,
  ].where((text) => text.trim().isNotEmpty).join('. ');

  JsonMap toJson() => {
    'explanation': explanation,
    'question': question,
    'options': {
      'A': options[AnswerLetter.A] ?? '',
      'B': options[AnswerLetter.B] ?? '',
      'C': options[AnswerLetter.C] ?? '',
    },
    'correct_answer': correctAnswer.name,
    if (whyCorrect != null) 'why_correct': whyCorrect,
    if (whyWrong != null) 'why_wrong': whyWrong,
  };
}

class CompleteLessonParams {
  const CompleteLessonParams({
    required this.lessonLocalId,
    required this.item,
    required this.lang,
    required this.academic,
    required this.layer,
    required this.mode,
    this.errCount = 0,
    this.history = const [],
    this.amparoLvl,
    this.marker,
    this.pedagogicalEnvelope = const {},
    this.curriculumItems = const [],
    this.topic,
    this.itemIdx,
    this.interfaceLocale,
    this.learningLocale,
    this.explanationLanguage,
    this.targetLanguage,
  });

  final String lessonLocalId;
  final String item;
  final String lang;
  final String academic;
  final LessonLayer layer;
  final LessonMode mode;
  final int errCount;
  final List<String> history;
  final int? amparoLvl;
  final String? marker;
  final JsonMap pedagogicalEnvelope;
  final List<JsonMap> curriculumItems;
  final String? topic;
  final int? itemIdx;
  final String? interfaceLocale;
  final String? learningLocale;
  final String? explanationLanguage;
  final String? targetLanguage;
}

class CompleteLesson {
  const CompleteLesson({
    required this.conteudo,
    required this.imagem,
    required this.audioText,
    this.imageMetadata,
  });

  final LessonContent conteudo;
  final String? imagem;
  final String audioText;
  final LessonImageGenerationMetadata? imageMetadata;

  static const Object _unchanged = Object();

  CompleteLesson copyWith({
    LessonContent? conteudo,
    Object? imagem = _unchanged,
    Object? imageMetadata = _unchanged,
  }) {
    final nextConteudo = conteudo ?? this.conteudo;
    final imageChanged = !identical(imagem, _unchanged);
    return CompleteLesson(
      conteudo: nextConteudo,
      imagem: imageChanged ? imagem as String? : this.imagem,
      audioText: nextConteudo.audioText,
      imageMetadata: identical(imageMetadata, _unchanged)
          ? (imageChanged ? null : this.imageMetadata)
          : imageMetadata as LessonImageGenerationMetadata?,
    );
  }
}

String lessonKeyFor(CompleteLessonParams params) {
  final amparo = params.mode == LessonMode.amparo ? params.amparoLvl ?? 0 : 0;
  return [
    'lesson:v1:m2:v2',
    params.lessonLocalId,
    params.lang,
    params.learningLocale ?? '',
    params.explanationLanguage ?? '',
    params.academic,
    params.layer.value,
    params.mode.name,
    amparo,
    params.item,
  ].join(':');
}

LessonContent lessonContentFromT02Material(dynamic material) {
  final options = material.options as Map<AnswerLetter, String>;
  return LessonContent(
    explanation: material.explanation as String,
    question: material.question as String,
    options: options,
    correctAnswer: material.correctAnswer as AnswerLetter,
    whyCorrect: material.whyCorrect as String?,
    whyWrong: material.whyWrong,
  );
}
