import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/session/entry_form_state.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';

void main() {
  test(
    'objetivo do aluno alimenta learning_goal sem traduzir texto digitado',
    () {
      const locale = SimLocaleContract(
        interfaceLocale: 'es',
        learningLocale: 'en',
        explanationLanguage: 'Spanish',
        targetLanguage: 'English',
        mediaTextLanguage: 'Spanish',
        source: SimLocaleSource.userSelected,
      );
      final form = EntryFormState()
        ..updateFreeText('quiero aprender present perfect para hablar mejor')
        ..updatePedagogicalField('subject', 'English')
        ..updatePedagogicalField('topic', 'present perfect')
        ..updatePedagogicalField('traversal_goal', 'Trabajo/práctica');

      final ficha = form.buildPedagogicalFicha(
        appLocale: 'es',
        lessonLocale: 'en',
        explanationLanguage: 'Spanish',
        targetLanguage: 'English',
        localeContract: locale,
      );

      expect(
        ficha['objective'],
        'quiero aprender present perfect para hablar mejor',
      );
      expect(ficha['learning_goal'], 'present perfect');
      expect(ficha['targetLanguage'], 'English');
      expect(ficha['goal_type'], 'real_use');
      expect(ficha['goal_type_source'], 'explicit_choice');
      expect(ficha['real_use_goal'], 'Trabajo/práctica');
      expect(
        (ficha['pedagogical_entry'] as Map)['localeContract'],
        locale.toJson(),
      );
    },
  );

  test(
    'sem materia e topico explicita status not_informed sem inventar dados',
    () {
      final form = EntryFormState()
        ..updateFreeText('Quero entender juros compostos');

      final ficha = form.buildPedagogicalFicha(
        appLocale: 'pt-BR',
        lessonLocale: 'pt-BR',
        explanationLanguage: 'Portuguese',
        localeContract: SimLocaleContract.fallbackForDevelopment(),
      );

      final entry = ficha['pedagogical_entry'] as Map;
      final goal = entry['student_goal'] as Map;

      expect(goal['subject_status'], 'not_informed');
      expect(goal['topic_status'], 'not_informed');
      expect(goal.containsKey('subject'), isFalse);
      expect(goal.containsKey('topic'), isFalse);
      expect(ficha['learning_goal'], 'Quero entender juros compostos');
    },
  );
}
