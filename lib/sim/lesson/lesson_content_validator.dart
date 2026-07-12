import '../state/student_learning_state.dart';
import 'lesson_models.dart';

class LessonContentValidationException implements Exception {
  const LessonContentValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _requiredText(Object? value, String field) {
  final text = (value ?? '').toString().trim();
  if (text.isEmpty) {
    throw LessonContentValidationException('$field ausente/vazio');
  }
  return text;
}

AnswerLetter parseRequiredCorrectAnswer(Object? value) {
  final raw = value?.toString().trim().toUpperCase();
  if (raw == null || raw.isEmpty) {
    throw const LessonContentValidationException('correct_answer ausente');
  }
  return AnswerLetter.values.firstWhere(
    (letter) => letter.name == raw,
    orElse: () =>
        throw const LessonContentValidationException('correct_answer invalido'),
  );
}

LessonContent validatedLessonContentFromJson(JsonMap source) {
  final options = source['options'];
  if (options is! Map) {
    throw const LessonContentValidationException('options ausente');
  }
  final normalizedOptions = {
    AnswerLetter.A: _requiredText(options['A'] ?? options['a'], 'options.A'),
    AnswerLetter.B: _requiredText(options['B'] ?? options['b'], 'options.B'),
    AnswerLetter.C: _requiredText(options['C'] ?? options['c'], 'options.C'),
  };
  return LessonContent(
    explanation: _requiredText(
      source['explanation'] ?? source['explicacao'],
      'explanation',
    ),
    question: _requiredText(
      source['question'] ?? source['pergunta'],
      'question',
    ),
    options: normalizedOptions,
    correctAnswer: parseRequiredCorrectAnswer(
      source['correct_answer'] ?? source['correctAnswer'],
    ),
    whyCorrect: (source['why_correct'] ?? source['whyCorrect'])?.toString(),
    whyWrong: source['why_wrong'] ?? source['whyWrong'],
  );
}
