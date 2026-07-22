import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/lesson/lesson_readiness_resolver.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  group('L4 cache textual com identidade linguistica', () {
    test('cache com locale correto retorna material pronto', () {
      final locale = _locale();
      final params = _params(locale);
      final orchestrator = _orchestrator();
      orchestrator.cache.putForParams(params, _lesson(locale));

      final result = const LessonReadinessResolver().resolveFromMemoryCache(
        orchestrator: orchestrator,
        params: params,
      );

      expect(result.status, LessonReadinessStatus.readyFromMemoryCache);
      expect(result.lesson?.localeContract?.toJson(), locale.toJson());
    });

    test('cache com explanationLanguage diferente e recusado', () {
      final locale = _locale();
      final wrong = locale
          .copyWith(explanationLanguage: 'English')
          .normalized();
      final params = _params(locale);
      final orchestrator = _orchestrator();
      orchestrator.cache.put(lessonKeyFor(params), _lesson(wrong));

      final result = const LessonReadinessResolver().resolveFromMemoryCache(
        orchestrator: orchestrator,
        params: params,
      );

      expect(result.status, LessonReadinessStatus.staleLocale);
      expect(result.isReady, isFalse);
    });

    test('cache com targetLanguage diferente e recusado', () {
      final locale = _locale();
      final wrong = locale.copyWith(targetLanguage: 'Spanish').normalized();
      final params = _params(locale);
      final orchestrator = _orchestrator();
      orchestrator.cache.put(lessonKeyFor(params), _lesson(wrong));

      final result = const LessonReadinessResolver().resolveFromMemoryCache(
        orchestrator: orchestrator,
        params: params,
      );

      expect(result.status, LessonReadinessStatus.staleLocale);
      expect(result.safeReason, contains('locale incompatible'));
    });

    test('cache legado sem locale vira legacyLocale, nao aula pronta', () {
      final params = _params(_locale());
      final orchestrator = _orchestrator();
      orchestrator.cache.put(lessonKeyFor(params), _lesson(null));

      final result = const LessonReadinessResolver().resolveFromMemoryCache(
        orchestrator: orchestrator,
        params: params,
      );

      expect(result.status, LessonReadinessStatus.legacyLocale);
      expect(result.isReady, isFalse);
    });

    test('putForParams migra lesson sem locale para locale do contrato', () {
      final params = _params(_locale());
      final orchestrator = _orchestrator();

      expect(orchestrator.cache.putForParams(params, _lesson(null)), isTrue);

      final cached = orchestrator.peekCachedLesson(lessonKeyFor(params));
      expect(
        cached?.localeContract?.toJson(),
        params.effectiveLocaleContract.toJson(),
      );
    });
  });
}

LessonOrchestrator _orchestrator() => LessonOrchestrator(
  t02Client: _FakeT02Client(),
  cache: LessonMaterialCache(),
  bus: LessonEventBus(),
);

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

class _FakeT02Client implements T02LessonClient {
  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    throw StateError(
      'server must not be called by cache locale contract tests',
    );
  }

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) =>
      completeLesson(request);
}
