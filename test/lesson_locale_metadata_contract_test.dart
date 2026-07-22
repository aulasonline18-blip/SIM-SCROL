import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  group('L4 locale metadata do material textual', () {
    test('CompleteLesson preserva localeContract em copyWith', () {
      final contract = _locale();
      final lesson = _lesson(contract);

      expect(lesson.copyWith().localeContract?.toJson(), contract.toJson());
      expect(lesson.copyWith(localeContract: null).localeContract, isNull);
    });

    test('PreparedLessonMaterial serializa localeContract e cacheIdentity', () {
      final contract = _locale();
      final material = preparedMaterialFromLesson(
        lesson: _lesson(contract),
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l1,
      );

      expect(material['localeContract'], contract.toJson());
      expect(material['localeCacheIdentity'], contract.cacheIdentity());
      expect(
        lessonLocaleContractFromMaterial(material)?.toJson(),
        contract.toJson(),
      );
    });

    test('lessonKey muda por identidade textual, nao por interfaceLocale', () {
      final base = _locale();
      final changedInterface = base
          .copyWith(interfaceLocale: 'en')
          .normalized();
      final changedLearning = base.copyWith(learningLocale: 'es').normalized();
      final changedExplanation = base
          .copyWith(explanationLanguage: 'English')
          .normalized();
      final changedTarget = base
          .copyWith(targetLanguage: 'Spanish')
          .normalized();

      expect(
        lessonKeyFor(_params(base)),
        lessonKeyFor(_params(changedInterface)),
      );
      expect(
        lessonKeyFor(_params(base)),
        isNot(lessonKeyFor(_params(changedLearning))),
      );
      expect(
        lessonKeyFor(_params(base)),
        isNot(lessonKeyFor(_params(changedExplanation))),
      );
      expect(
        lessonKeyFor(_params(base)),
        isNot(lessonKeyFor(_params(changedTarget))),
      );
    });

    test('material legado sem locale e identificado como legacyLocale', () {
      final material = preparedMaterialFromLesson(
        lesson: _lesson(null),
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l1,
      )..remove('localeContract');

      expect(lessonLocaleContractFromMaterial(material), isNull);
      expect(
        validateLessonLocaleContract(actual: null, params: _params(_locale())),
        LessonLocaleValidationStatus.legacyLocale,
      );
    });
  });
}

SimLocaleContract _locale() => SimLocaleContract.fromUserSelection(
  interfaceLocale: 'pt-BR',
  learningLocale: 'en',
  explanationLanguage: 'Portuguese',
  targetLanguage: 'English',
);

CompleteLessonParams _params(SimLocaleContract locale) => CompleteLessonParams(
  lessonLocalId: 'lesson-l4',
  item: 'Verb to be',
  lang: 'Portuguese',
  academic: 'base',
  layer: LessonLayer.l1,
  mode: LessonMode.session,
  marker: 'M1',
  itemIdx: 0,
  localeContract: locale,
);

CompleteLesson _lesson(SimLocaleContract? localeContract) => CompleteLesson(
  conteudo: const LessonContent(
    explanation: 'Explicacao em portugues.',
    question: 'Qual alternativa traduz corretamente?',
    options: {
      AnswerLetter.A: 'I am',
      AnswerLetter.B: 'I was',
      AnswerLetter.C: 'I will',
    },
    correctAnswer: AnswerLetter.A,
    whyCorrect: 'Correto.',
  ),
  imagem: null,
  audioText: 'Explicacao em portugues.',
  localeContract: localeContract,
);
