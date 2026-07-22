import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/lesson/dopamine_ready_window_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/media/slot_media_contract.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _ptLocale = SimLocaleContract(
  interfaceLocale: 'pt-BR',
  learningLocale: 'en',
  explanationLanguage: 'Portuguese',
  mediaTextLanguage: 'Portuguese',
  targetLanguage: 'English',
  source: SimLocaleSource.userSelected,
);

const _enLocale = SimLocaleContract(
  interfaceLocale: 'en',
  learningLocale: 'en',
  explanationLanguage: 'English',
  mediaTextLanguage: 'English',
  targetLanguage: 'English',
  source: SimLocaleSource.userSelected,
);

void main() {
  test('ready window aceita midia somente no idioma correto', () {
    final slot = _slot(_ptLocale);
    final key = slotMediaKey('lesson-1', slot, SlotMediaType.image);
    final state = StudentLearningState.empty(lessonLocalId: 'lesson-1')
        .copyWith(
          events: [
            StudentLearningEvent(
              type: 'IMAGE_READY',
              ts: 1,
              payload: {
                'itemMarker': 'M1',
                'itemIdx': 0,
                'layer': LessonLayer.l1.value,
                'slotMedia': SlotMediaContract(
                  lessonLocalId: 'lesson-1',
                  marker: 'M1',
                  itemIdx: 0,
                  layer: LessonLayer.l1,
                  mediaType: SlotMediaType.image,
                  status: 'ready',
                  source: 'visual-generated',
                  createdAt: '2026-07-22T00:00:00Z',
                  cacheKey: key,
                  localeContract: _ptLocale,
                  mediaTextLanguage: 'Portuguese',
                ).toJson(),
              },
            ),
          ],
        );

    expect(slotMediaAlreadyRequested(state, slot, SlotMediaType.image), isTrue);
  });

  test('midia de idioma errado ou legado nao bloqueia novo idioma', () {
    final slot = _slot(_ptLocale);
    final wrongKey = slotMediaCacheKey(
      lessonLocalId: 'lesson-1',
      marker: 'M1',
      itemIdx: 0,
      layer: LessonLayer.l1,
      mediaType: SlotMediaType.image,
      localeContract: _enLocale,
      mediaTextLanguage: 'English',
    );
    final state = StudentLearningState.empty(lessonLocalId: 'lesson-1')
        .copyWith(
          events: [
            StudentLearningEvent(
              type: 'IMAGE_READY',
              ts: 1,
              payload: {
                'itemMarker': 'M1',
                'itemIdx': 0,
                'layer': LessonLayer.l1.value,
                'slotMedia': SlotMediaContract(
                  lessonLocalId: 'lesson-1',
                  marker: 'M1',
                  itemIdx: 0,
                  layer: LessonLayer.l1,
                  mediaType: SlotMediaType.image,
                  status: 'ready',
                  source: 'visual-generated',
                  createdAt: '2026-07-22T00:00:00Z',
                  cacheKey: wrongKey,
                  localeContract: _enLocale,
                  mediaTextLanguage: 'English',
                ).toJson(),
              },
            ),
            const StudentLearningEvent(
              type: 'IMAGE_READY',
              ts: 2,
              payload: {
                'itemMarker': 'M1',
                'itemIdx': 0,
                'layer': 1,
                'slotMedia': {
                  'lessonLocalId': 'lesson-1',
                  'marker': 'M1',
                  'itemIdx': 0,
                  'layer': 1,
                  'mediaType': 'image',
                  'status': 'ready',
                  'source': 'legacy',
                  'createdAt': '2026-07-22T00:00:00Z',
                  'cacheKey': 'legacy-key',
                  'legacyLocale': true,
                },
              },
            ),
          ],
        );

    expect(
      slotMediaAlreadyRequested(state, slot, SlotMediaType.image),
      isFalse,
    );
    expect(slotHasInvalidMediaLocale(state, slot), isTrue);
  });
}

DopamineReadySlot _slot(SimLocaleContract locale) {
  final params = CompleteLessonParams(
    lessonLocalId: 'lesson-1',
    item: 'Item 1',
    lang: locale.learningLocale,
    academic: 'base',
    layer: LessonLayer.l1,
    mode: LessonMode.session,
    marker: 'M1',
    itemIdx: 0,
    localeContract: locale,
  );
  return DopamineReadySlot(
    slot: 'A',
    itemIdx: 0,
    marker: 'M1',
    layer: LessonLayer.l1,
    params: params,
    expectedKey: lessonKeyFor(params),
  );
}
