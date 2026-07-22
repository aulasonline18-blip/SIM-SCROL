import '../state/student_learning_state.dart';
import '../localization/sim_locale_contract.dart';
import '../lesson/lesson_content_validator.dart';

enum StudentExperienceRouteStage {
  profile,
  curriculum,
  placement,
  lesson,
  ready,
}

enum StudentExperienceState {
  idle,
  fichaRecebida,
  t00Streaming,
  primeiroItemRecebido,
  providerFailedAfterPartial,
  nivelamentoNecessario,
  nivelamentoEmAndamento,
  t02PrimeiraAulaStreaming,
  primeiraAulaMinimaPronta,
  salaAberta,
  continuidadePreparando,
  erroRecuperavel,
  erroBloqueante,
}

enum StudentExperienceEventType {
  studentFormSubmitted,
  t00Started,
  objectiveSubmittedAt,
  t00StreamStartedAt,
  t00FirstRawChunkAt,
  t00ProfilePartialReceived,
  t00FirstItemReceived,
  t00FirstItemReceivedAt,
  t00PartialReady,
  t00QualityCheckReceived,
  t00FinalCurriculumReceived,
  t00ProviderFailedAfterPartial,
  t00FallbackGatewayStarted,
  t00FallbackGatewaySucceeded,
  t00FallbackGatewayFailed,
  firstItemFastPathStarted,
  firstLessonShellOpened,
  timeToClassroom,
  placementRequired,
  placementScreenReleasedAfterSlotA,
  placementDeferredUntilAfterFirstLesson,
  t02FirstLessonStarted,
  t02FirstMinimumLessonReady,
  timeToFirstQuestion,
  firstSlotARequested,
  firstSlotAReady,
  placementStartFromZeroClicked,
  placementContinueToAula,
  recoverableError,
  blockingError,
}

enum StudentExperienceErrorKind { auth, credits, timeout, generic }

class StudentExperienceErrorInfo {
  const StudentExperienceErrorInfo({required this.kind, required this.message});

  final StudentExperienceErrorKind kind;
  final String message;
}

class StudentExperienceEngineException implements Exception {
  const StudentExperienceEngineException(this.error);

  final StudentExperienceErrorInfo error;

  @override
  String toString() => error.message;
}

class SimWarmupLesson {
  const SimWarmupLesson({
    required this.explanation,
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.whyCorrect,
    this.whyWrong = const {},
    this.welcomeBridge = true,
  });

  final String explanation;
  final String question;
  final Map<String, String> options;
  final String correctAnswer;
  final String? whyCorrect;
  final Map<String, String> whyWrong;
  final bool welcomeBridge;

  Map<String, Object?> toJson() => {
    'explanation': explanation,
    'question': question,
    'options': options,
    'correctAnswer': correctAnswer,
    'whyCorrect': whyCorrect,
    'whyWrong': whyWrong,
    'type': 'warmup',
    'mode': 'WARMUP_WELCOME_BRIDGE',
    'welcomeBridge': welcomeBridge,
    'officialCurriculum': false,
    'countsForMastery': false,
  };

  static SimWarmupLesson? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final source = raw['warmup'] is Map ? raw['warmup'] as Map : raw;
    final optionsRaw = source['options'];
    if (optionsRaw is! Map) return null;
    final options = <String, String>{
      for (final letter in const ['A', 'B', 'C'])
        letter: normalizeDidacticMathNotation(
          (optionsRaw[letter] ?? optionsRaw[letter.toLowerCase()] ?? '')
              .toString(),
        ),
    };
    final explanation = normalizeDidacticMathNotation(
      (source['explanation'] ?? source['explicacao'] ?? '').toString(),
    );
    final question = normalizeDidacticMathNotation(
      (source['question'] ?? source['pergunta'] ?? '').toString(),
    );
    final correct = (source['correct_answer'] ?? source['correctAnswer'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    if (explanation.isEmpty ||
        question.isEmpty ||
        options.values.any((value) => value.isEmpty) ||
        !options.containsKey(correct)) {
      return null;
    }
    final whyWrongRaw = source['why_wrong'] ?? source['whyWrong'];
    final whyWrong = <String, String>{
      if (whyWrongRaw is Map)
        for (final letter in const ['A', 'B', 'C'])
          if ((whyWrongRaw[letter] ?? whyWrongRaw[letter.toLowerCase()]) !=
              null)
            letter: normalizeDidacticMathNotation(
              (whyWrongRaw[letter] ?? whyWrongRaw[letter.toLowerCase()])
                  .toString(),
            ),
    };
    return SimWarmupLesson(
      explanation: explanation,
      question: question,
      options: options,
      correctAnswer: correct,
      whyCorrect: normalizeDidacticMathObject(
        source['why_correct'] ?? source['whyCorrect'],
      )?.toString(),
      whyWrong: whyWrong,
      welcomeBridge: source['welcomeBridge'] != false,
    );
  }
}

class StudentExperienceSnapshot {
  const StudentExperienceSnapshot({
    required this.state,
    required this.stage,
    required this.lessonLocalId,
    required this.destination,
    required this.startMarker,
    required this.startItemIndex,
    required this.error,
    required this.updatedAt,
  });

  final StudentExperienceState state;
  final StudentExperienceRouteStage stage;
  final String lessonLocalId;
  final String? destination;
  final String? startMarker;
  final int startItemIndex;
  final StudentExperienceErrorInfo? error;
  final int updatedAt;
}

class StudentExperienceArgs {
  const StudentExperienceArgs({
    required this.academic,
    required this.idioma,
    required this.lessonLocalId,
    required this.onboarding,
    this.localeContract = const SimLocaleContract(
      interfaceLocale: 'pt-BR',
      learningLocale: 'pt-BR',
      explanationLanguage: 'Portuguese',
      mediaTextLanguage: 'Portuguese',
      source: SimLocaleSource.fallback,
    ),
    this.onStage,
  });

  final String academic;
  final String idioma;
  final String lessonLocalId;
  final JsonMap onboarding;
  final SimLocaleContract localeContract;
  final void Function(StudentExperienceRouteStage stage)? onStage;
}

class StudentExperienceResult {
  const StudentExperienceResult({
    required this.destination,
    required this.curriculum,
    required this.startMarker,
    required this.startItemIndex,
  });

  final String destination;
  final StudentCurriculum curriculum;
  final String? startMarker;
  final int startItemIndex;
}

class FirstCurriculumItem {
  const FirstCurriculumItem({
    required this.curriculum,
    required this.item,
    required this.itemIndex,
    required this.marker,
  });

  final StudentCurriculum curriculum;
  final CurriculumItem item;
  final int itemIndex;
  final String? marker;
}
