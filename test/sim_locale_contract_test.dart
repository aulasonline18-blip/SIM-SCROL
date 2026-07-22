import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/media/slot_media_contract.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  test('pt-BR en e es normalizam em todas as camadas', () {
    final pt = SimLocaleContract.fromUserSelection(
      interfaceLocale: 'pt',
      learningLocale: 'Portuguese',
    );
    final en = SimLocaleContract.fromUserSelection(
      interfaceLocale: 'en-US',
      learningLocale: 'English',
    );
    final es = SimLocaleContract.fromUserSelection(
      interfaceLocale: 'es-ES',
      learningLocale: 'Español',
    );

    expect(pt.interfaceLocale, 'pt-BR');
    expect(pt.learningLocale, 'pt-BR');
    expect(pt.explanationLanguage, 'Portuguese');
    expect(en.interfaceLocale, 'en');
    expect(en.learningLocale, 'en');
    expect(en.explanationLanguage, 'English');
    expect(es.interfaceLocale, 'es');
    expect(es.learningLocale, 'es');
    expect(es.explanationLanguage, 'Spanish');
  });

  test('idioma desconhecido fica auditavel e preserva alvo raw', () {
    final contract = SimLocaleContract.fromUserSelection(
      interfaceLocale: 'pt-BR',
      learningLocale: 'Klingon',
    );

    expect(contract.interfaceLocale, 'pt-BR');
    expect(contract.learningLocale, 'pt-BR');
    expect(contract.explanationLanguage, 'Klingon');
    expect(contract.targetLanguage, 'Klingon');
  });

  test('interface e target podem divergir', () {
    final contract = SimLocaleContract.fromUserSelection(
      interfaceLocale: 'pt-BR',
      learningLocale: 'en',
      explanationLanguage: 'Portuguese',
      targetLanguage: 'English',
    );

    expect(contract.interfaceLocale, 'pt-BR');
    expect(contract.learningLocale, 'en');
    expect(contract.explanationLanguage, 'Portuguese');
    expect(contract.targetLanguage, 'English');
  });

  test(
    'cacheIdentity muda por explanation e target; mediaIdentity muda por midia',
    () {
      final base = SimLocaleContract.fromUserSelection(
        interfaceLocale: 'pt-BR',
        learningLocale: 'en',
        explanationLanguage: 'Portuguese',
        targetLanguage: 'English',
      );
      final changedExplanation = base
          .copyWith(
            explanationLanguage: 'English',
            mediaTextLanguage: 'English',
          )
          .normalized();
      final changedTarget = base
          .copyWith(targetLanguage: 'Spanish')
          .normalized();
      final changedMedia = base
          .copyWith(mediaTextLanguage: 'Spanish')
          .normalized();

      expect(base.cacheIdentity(), isNot(changedExplanation.cacheIdentity()));
      expect(base.cacheIdentity(), isNot(changedTarget.cacheIdentity()));
      expect(base.mediaIdentity(), isNot(changedMedia.mediaIdentity()));
    },
  );

  test('fallback tem source explicito e JSON nao perde campos', () {
    final fallback = SimLocaleContract.fallbackForDevelopment();
    final restored = SimLocaleContract.fromJson(fallback.toJson());

    expect(fallback.source, SimLocaleSource.fallback);
    expect(restored.toJson(), fallback.toJson());
    expect(restored.debugSummary(), contains('source=fallback'));
  });

  test('estado legado migra localeContract com source migrated', () {
    final state = StudentLearningState.fromJson({
      'lessonLocalId': 'l1',
      'createdAt': 1,
      'updatedAt': 1,
      'profile': {
        'language': 'en',
        'stableLang': 'Portuguese',
        'targetLanguage': 'English',
      },
    });

    expect(state.localeContract.source, SimLocaleSource.migrated);
    expect(state.localeContract.learningLocale, 'en');
    expect(state.localeContract.explanationLanguage, 'Portuguese');
    expect(state.localeContract.targetLanguage, 'English');
    expect(state.toJson()['localeContract'], isA<Map>());
  });

  test('CompleteLesson e SlotMediaContract serializam localeContract', () {
    final contract = SimLocaleContract.fromUserSelection(
      interfaceLocale: 'pt-BR',
      learningLocale: 'en',
      explanationLanguage: 'Portuguese',
      targetLanguage: 'English',
    );
    final paramsA = CompleteLessonParams(
      lessonLocalId: 'l1',
      item: 'verb to be',
      lang: 'Portuguese',
      academic: 'base',
      layer: LessonLayer.l1,
      mode: LessonMode.session,
      localeContract: contract,
    );
    final paramsB = CompleteLessonParams(
      lessonLocalId: 'l1',
      item: 'verb to be',
      lang: 'Portuguese',
      academic: 'base',
      layer: LessonLayer.l1,
      mode: LessonMode.session,
      localeContract: contract.copyWith(targetLanguage: 'Spanish').normalized(),
    );
    final media = SlotMediaContract(
      lessonLocalId: 'l1',
      marker: 'M1',
      itemIdx: 0,
      layer: LessonLayer.l1,
      mediaType: SlotMediaType.image,
      status: 'ready',
      source: 'test',
      createdAt: 'now',
      cacheKey: slotMediaCacheKey(
        lessonLocalId: 'l1',
        marker: 'M1',
        itemIdx: 0,
        layer: LessonLayer.l1,
        mediaType: SlotMediaType.image,
        localeContract: contract,
      ),
      localeContract: contract,
    );

    expect(lessonKeyFor(paramsA), isNot(lessonKeyFor(paramsB)));
    expect(media.toJson()['localeContract'], contract.toJson());
    expect(
      SlotMediaContract.fromJson(media.toJson()).localeContract?.toJson(),
      contract.toJson(),
    );
  });
}
