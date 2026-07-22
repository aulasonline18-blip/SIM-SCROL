import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/media/lesson_visual_pipeline.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _ptExplanation = SimLocaleContract(
  interfaceLocale: 'en',
  learningLocale: 'en',
  explanationLanguage: 'Portuguese',
  mediaTextLanguage: 'Portuguese',
  targetLanguage: 'English',
  source: SimLocaleSource.userSelected,
);

const _enExplanation = SimLocaleContract(
  interfaceLocale: 'en',
  learningLocale: 'en',
  explanationLanguage: 'English',
  mediaTextLanguage: 'English',
  targetLanguage: 'English',
  source: SimLocaleSource.userSelected,
);

void main() {
  test('visual payload inclui contrato de idioma completo', () {
    final request = VisualRouterN3Request(
      visualTrigger: const {'needs_image': true, 'visual_type': 'comparison'},
      lessonLocalId: 'lesson-1',
      itemMarker: 'M1',
      itemIdx: 0,
      layer: LessonLayer.l1,
      requestId: 'r1',
      idioma: _ptExplanation.mediaTextLanguage,
      localeContract: _ptExplanation,
      mediaTextLanguage: _ptExplanation.mediaTextLanguage,
      explanationLanguage: _ptExplanation.explanationLanguage,
      targetLanguage: _ptExplanation.targetLanguage,
      visualTextPolicy: 'explanation',
    );

    final json = request.toJson();

    expect(json['localeContract'], isA<Map>());
    expect(json['interfaceLocale'], 'en');
    expect(json['learningLocale'], 'en');
    expect(json['explanationLanguage'], 'Portuguese');
    expect(json['targetLanguage'], 'English');
    expect(json['mediaTextLanguage'], 'Portuguese');
    expect(json['visualTextPolicy'], 'explanation');
    expect(json['idioma'], 'Portuguese');
  });

  test('idempotency do visual muda quando mediaTextLanguage muda', () {
    final base = VisualRouterN3Request(
      visualTrigger: const {'needs_image': true, 'visual_type': 'comparison'},
      lessonLocalId: 'lesson-1',
      itemMarker: 'M1',
      itemIdx: 0,
      layer: LessonLayer.l1,
      requestId: 'r1',
      idioma: _ptExplanation.mediaTextLanguage,
      localeContract: _ptExplanation,
      mediaTextLanguage: _ptExplanation.mediaTextLanguage,
      explanationLanguage: _ptExplanation.explanationLanguage,
      targetLanguage: _ptExplanation.targetLanguage,
      visualTextPolicy: 'explanation',
    ).toJson()['idempotencyKey'];
    final changed = VisualRouterN3Request(
      visualTrigger: const {'needs_image': true, 'visual_type': 'comparison'},
      lessonLocalId: 'lesson-1',
      itemMarker: 'M1',
      itemIdx: 0,
      layer: LessonLayer.l1,
      requestId: 'r1',
      idioma: _enExplanation.mediaTextLanguage,
      localeContract: _enExplanation,
      mediaTextLanguage: _enExplanation.mediaTextLanguage,
      explanationLanguage: _enExplanation.explanationLanguage,
      targetLanguage: _enExplanation.targetLanguage,
      visualTextPolicy: 'explanation',
    ).toJson()['idempotencyKey'];

    expect(changed, isNot(base));
  });

  test('S12 visual request resolve idioma explicativo por contrato', () {
    final request = S12VisualRequest(
      trigger: const LessonVisualTrigger(
        needsImage: true,
        kind: 'comparison',
        raw: {'needs_image': true, 'visual_type': 'comparison'},
      ),
      lessonLocalId: 'lesson-1',
      marker: 'M1',
      itemIdx: 0,
      layer: LessonLayer.l1,
      idioma: 'legacy',
      localeContract: _ptExplanation,
      mediaTextLanguage: _ptExplanation.mediaTextLanguage,
      explanationLanguage: _ptExplanation.explanationLanguage,
      targetLanguage: _ptExplanation.targetLanguage,
      visualTextPolicy: 'explanation',
    );

    expect(request.resolvedMediaTextLanguage, 'Portuguese');
    expect(request.resolvedExplanationLanguage, 'Portuguese');
    expect(request.resolvedTargetLanguage, 'English');
    expect(request.localeIdentity, contains('Portuguese'));
  });
}
