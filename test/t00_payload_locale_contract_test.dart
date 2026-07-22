import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/experience/bootstrap_payload.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';

void main() {
  test('T00 payload carrega localeContract completo e ficha estruturada', () {
    const locale = SimLocaleContract(
      interfaceLocale: 'pt-BR',
      learningLocale: 'en',
      explanationLanguage: 'Portuguese',
      targetLanguage: 'English',
      mediaTextLanguage: 'Portuguese',
      source: SimLocaleSource.userSelected,
    );
    final pedagogicalEntry = {
      'version': 1,
      'localeContract': locale.toJson(),
      'student_goal': {
        'objective': 'aprender ingles',
        'learning_goal': 'present perfect',
      },
    };

    final body = buildT00Phase1Body(
      data: {
        'objetivo': 'aprender ingles',
        'learningLocale': locale.learningLocale,
        'explanationLanguage': locale.explanationLanguage,
        'targetLanguage': locale.targetLanguage,
        'mediaTextLanguage': locale.mediaTextLanguage,
        'localeContract': locale.toJson(),
        'pedagogical_entry': pedagogicalEntry,
        'pedagogical_entry_ficha': pedagogicalEntry,
        'human_summary': 'Objective: aprender ingles',
        'human_summary_locale': 'Portuguese',
        'student_profile_notes_locale': 'Portuguese',
        'goal_type': 'exam',
        'goal_type_source': 'explicit_choice',
      },
      lang: 'Portuguese',
      academic: 'adult',
    );

    final ficha = body['ficha'] as Map;
    expect(ficha['localeContract'], locale.toJson());
    expect(ficha['pedagogical_entry'], pedagogicalEntry);
    expect(ficha['pedagogical_entry_ficha'], pedagogicalEntry);
    expect(ficha['language'], 'en');
    expect(ficha['language_semantics'], 'learningLocale');
    expect(ficha['stableLang'], isNull);
    expect(ficha['stableLang_semantics'], 'explanationLanguage');
    expect(ficha['targetLanguage'], 'English');
    expect(ficha['goal_type'], 'exam');
    expect(ficha['goal_type_source'], 'explicit_choice');
  });
}
