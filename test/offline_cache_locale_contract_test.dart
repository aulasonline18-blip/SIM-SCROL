import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/cache/secure_lesson_cache_store.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/lesson/lesson_readiness_resolver.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  group('L4 offline-first com locale textual', () {
    test('offline preparado no mesmo idioma abre pelo cache local', () {
      final locale = _locale();
      final params = _params(locale);
      final orchestrator = _orchestrator();
      orchestrator.cache.putForParams(params, _lesson(locale));

      final result = const LessonReadinessResolver().resolveFromMemoryCache(
        orchestrator: orchestrator,
        params: params,
      );

      expect(result.status, LessonReadinessStatus.readyFromMemoryCache);
      expect(result.lesson?.conteudo.question, 'Pergunta M1?');
    });

    test('offline preparado em outro idioma nao renderiza aula errada', () {
      final locale = _locale();
      final params = _params(locale);
      final wrong = locale.copyWith(learningLocale: 'es').normalized();
      final orchestrator = _orchestrator();
      orchestrator.cache.put(lessonKeyFor(params), _lesson(wrong));

      final result = const LessonReadinessResolver().resolveFromMemoryCache(
        orchestrator: orchestrator,
        params: params,
      );

      expect(result.status, LessonReadinessStatus.staleLocale);
      expect(result.lesson, isNull);
    });

    test('cache novo substitui legado e passa a ser validavel offline', () {
      final params = _params(_locale());
      final orchestrator = _orchestrator();
      orchestrator.cache.put(lessonKeyFor(params), _lesson(null));

      final legacy = const LessonReadinessResolver().resolveFromMemoryCache(
        orchestrator: orchestrator,
        params: params,
      );
      expect(legacy.status, LessonReadinessStatus.legacyLocale);

      orchestrator.cache.putForParams(
        params,
        _lesson(params.effectiveLocaleContract),
      );
      final repaired = const LessonReadinessResolver().resolveFromMemoryCache(
        orchestrator: orchestrator,
        params: params,
      );

      expect(repaired.status, LessonReadinessStatus.readyFromMemoryCache);
      expect(
        repaired.lesson?.localeContract?.toJson(),
        params.effectiveLocaleContract.toJson(),
      );
    });

    test('reabrir app preserva locale e recusa cache stale', () async {
      final locale = _locale();
      final wrong = locale.copyWith(targetLanguage: 'Spanish').normalized();
      final params = _params(locale);
      final store = MemoryLessonCacheStore();
      final firstCache = LessonMaterialCache(store: store);
      firstCache.put(lessonKeyFor(params), _lesson(wrong));
      await firstCache.persistNow();

      final reopened = LessonMaterialCache(store: store);
      await reopened.hydrate();
      final orchestrator = LessonOrchestrator(
        t02Client: _FakeT02Client(),
        cache: reopened,
        bus: LessonEventBus(),
      );

      final result = const LessonReadinessResolver().resolveFromMemoryCache(
        orchestrator: orchestrator,
        params: params,
      );

      expect(result.status, LessonReadinessStatus.staleLocale);
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
    explanation: 'Explicacao M1 em portugues.',
    question: 'Pergunta M1?',
    options: {
      AnswerLetter.A: 'I am',
      AnswerLetter.B: 'I was',
      AnswerLetter.C: 'I will',
    },
    correctAnswer: AnswerLetter.A,
    whyCorrect: 'Correto.',
  ),
  imagem: null,
  audioText: 'Explicacao M1 em portugues.',
  localeContract: localeContract,
);

class _FakeT02Client implements T02LessonClient {
  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    throw StateError('server must not be called by offline locale tests');
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
