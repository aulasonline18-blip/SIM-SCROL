import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/media/slot_media_contract.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _ptUiEnLesson = SimLocaleContract(
  interfaceLocale: 'pt-BR',
  learningLocale: 'en',
  explanationLanguage: 'Portuguese',
  mediaTextLanguage: 'Portuguese',
  targetLanguage: 'English',
  source: SimLocaleSource.userSelected,
);

const _enUiEnLesson = SimLocaleContract(
  interfaceLocale: 'en',
  learningLocale: 'en',
  explanationLanguage: 'English',
  mediaTextLanguage: 'English',
  targetLanguage: 'English',
  source: SimLocaleSource.userSelected,
);

void main() {
  test('SlotMediaContract serializa identidade explicita de idioma', () {
    final contract = SlotMediaContract(
      lessonLocalId: 'lesson-1',
      marker: 'M1',
      itemIdx: 0,
      layer: LessonLayer.l1,
      mediaType: SlotMediaType.image,
      status: 'ready',
      source: 'visual-generated',
      createdAt: '2026-07-22T00:00:00Z',
      cacheKey: 'image-key',
      localeContract: _ptUiEnLesson,
      mediaTextLanguage: 'Portuguese',
      targetLanguage: 'English',
      explanationLanguage: 'Portuguese',
      sourceVersion: 'slot-media.v2',
    );

    final json = contract.toJson();
    final restored = SlotMediaContract.fromJson(json);

    expect(json['localeContract'], isA<Map>());
    expect(restored.localeContract?.interfaceLocale, 'pt-BR');
    expect(restored.mediaTextLanguage, 'Portuguese');
    expect(restored.targetLanguage, 'English');
    expect(restored.explanationLanguage, 'Portuguese');
    expect(restored.legacyLocale, isFalse);
  });

  test(
    'cache key de midia muda por idioma, voz, velocidade e hash de texto',
    () {
      final base = slotMediaCacheKey(
        lessonLocalId: 'lesson-1',
        marker: 'M1',
        itemIdx: 0,
        layer: LessonLayer.l1,
        mediaType: SlotMediaType.audio,
        localeContract: _ptUiEnLesson,
        audioLanguage: 'Portuguese',
        voice: 'Charon',
        speed: 1,
        textHash: 'abc',
      );
      expect(
        slotMediaCacheKey(
          lessonLocalId: 'lesson-1',
          marker: 'M1',
          itemIdx: 0,
          layer: LessonLayer.l1,
          mediaType: SlotMediaType.audio,
          localeContract: _enUiEnLesson,
          audioLanguage: 'English',
          voice: 'Charon',
          speed: 1,
          textHash: 'abc',
        ),
        isNot(base),
      );
      expect(
        slotMediaCacheKey(
          lessonLocalId: 'lesson-1',
          marker: 'M1',
          itemIdx: 0,
          layer: LessonLayer.l1,
          mediaType: SlotMediaType.audio,
          localeContract: _ptUiEnLesson,
          audioLanguage: 'Portuguese',
          voice: 'Nova',
          speed: 1.25,
          textHash: 'abc',
        ),
        isNot(base),
      );
      expect(
        slotMediaCacheKey(
          lessonLocalId: 'lesson-1',
          marker: 'M1',
          itemIdx: 0,
          layer: LessonLayer.l1,
          mediaType: SlotMediaType.audio,
          localeContract: _ptUiEnLesson,
          audioLanguage: 'Portuguese',
          voice: 'Charon',
          speed: 1,
          textHash: 'def',
        ),
        isNot(base),
      );
    },
  );

  test('contrato legado sem locale e identificado', () {
    final legacy = SlotMediaContract.fromJson({
      'lessonLocalId': 'lesson-1',
      'marker': 'M1',
      'itemIdx': 0,
      'layer': 1,
      'mediaType': 'image',
      'status': 'ready',
      'source': 'legacy',
      'createdAt': '2026-07-22T00:00:00Z',
      'cacheKey': 'legacy-key',
    });

    expect(legacy.legacyLocale, isTrue);
    expect(legacy.localeContract, isNull);
    expect(legacy.sourceVersion, 'slot-media.v1');
  });
}
