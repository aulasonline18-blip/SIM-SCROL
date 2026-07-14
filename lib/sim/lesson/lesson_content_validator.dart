import '../state/student_learning_state.dart';
import 'lesson_models.dart';

class LessonContentValidationException implements Exception {
  const LessonContentValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

String normalizeDidacticMathNotation(String value) {
  var text = value.trim();
  if (text.isEmpty) return text;

  final looksPortuguese = RegExp(
    r'\b(você|voce|força|forca|ângulo|angulo|chão|chao|calcula|mala|eixo|opção|opcao|correta)\b',
    caseSensitive: false,
  ).hasMatch(text) ||
      RegExp(r'[áàâãéêíóôõúçÁÀÂÃÉÊÍÓÔÕÚÇ]').hasMatch(text);
  final sine = looksPortuguese ? 'sen' : 'sin';

  text = text.replaceAllMapped(
    RegExp(r'\\text\{([^{}]*)\}'),
    (match) => match.group(1)!.trim(),
  );
  text = text.replaceAll(RegExp(r'\^\s*\{\\circ\}'), '°');
  text = text.replaceAll(RegExp(r'\^\s*\\circ'), '°');
  text = text.replaceAll(r'\cdot', '×');
  text = text.replaceAll(r'\times', '×');
  text = text.replaceAll(r'\sin', sine);
  text = text.replaceAll(r'\cos', 'cos');
  text = text.replaceAll(r'\tan', 'tan');
  text = text.replaceAllMapped(
    RegExp(r'\\frac\{([^{}]+)\}\{([^{}]+)\}'),
    (match) => '(${match.group(1)})/(${match.group(2)})',
  );
  text = text.replaceAllMapped(
    RegExp(r'\\sqrt\{([^{}]+)\}'),
    (match) => '√(${match.group(1)})',
  );
  text = text.replaceAllMapped(
    RegExp(r'\b([A-Za-z])_([A-Za-z0-9])\b'),
    (match) => '${match.group(1)}${match.group(2)}',
  );
  text = text.replaceAll(r'$', '');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

Object? normalizeDidacticMathObject(Object? value) {
  if (value is String) return normalizeDidacticMathNotation(value);
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key, normalizeDidacticMathObject(item)),
    );
  }
  if (value is List) {
    return value.map(normalizeDidacticMathObject).toList();
  }
  return value;
}

String _requiredText(Object? value, String field) {
  final text = normalizeDidacticMathNotation((value ?? '').toString());
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
    whyCorrect: normalizeDidacticMathObject(
      source['why_correct'] ?? source['whyCorrect'],
    )?.toString(),
    whyWrong: normalizeDidacticMathObject(
      source['why_wrong'] ?? source['whyWrong'],
    ),
  );
}
