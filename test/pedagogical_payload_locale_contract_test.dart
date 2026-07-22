import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/session/entry_form_state.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/reception/pedagogical_reception_builder.dart';

void main() {
  const englishLearning = SimLocaleContract(
    interfaceLocale: 'en',
    learningLocale: 'en',
    explanationLanguage: 'English',
    targetLanguage: 'English',
    mediaTextLanguage: 'English',
    source: SimLocaleSource.userSelected,
  );

  test(
    'ficha estruturada contem localeContract e dados pedagogicos neutros',
    () {
      final form = EntryFormState()
        ..updateFreeText('I want to learn English grammar for interviews')
        ..updatePedagogicalField('subject', 'English')
        ..updatePedagogicalField('topic', 'present perfect')
        ..updatePedagogicalField('academic_level', 'adult learner')
        ..updatePedagogicalField('traversal_goal', 'Exam')
        ..updatePedagogicalField('deadline', 'next week')
        ..updatePedagogicalField('expected_result', 'answer confidently');

      final ficha = form.buildPedagogicalFicha(
        appLocale: 'en',
        lessonLocale: 'en',
        explanationLanguage: 'English',
        targetLanguage: 'English',
        localeContract: englishLearning,
      );

      final entry = ficha['pedagogical_entry'] as Map;
      final mirror = ficha['pedagogical_entry_ficha'] as Map;
      final goal = entry['student_goal'] as Map;
      final goalType = goal['goal_type'] as Map;

      expect(entry['localeContract'], englishLearning.toJson());
      expect(mirror, entry);
      expect(
        goal['objective'],
        'I want to learn English grammar for interviews',
      );
      expect(goal['learning_goal'], 'present perfect');
      expect(goal['subject'], 'English');
      expect(goal['topic'], 'present perfect');
      expect(goalType['code'], 'exam');
      expect(goalType['source'], 'explicit_choice');
      expect(ficha['learning_goal'], 'present perfect');
      expect(ficha['targetLanguage'], 'English');
    },
  );

  test('resumos humanos em ingles nao carregam rotulos portugueses fixos', () {
    final form = EntryFormState()
      ..updateFreeText('I want to understand fractions')
      ..updatePreferredName('Ana')
      ..updateStudentAge('12')
      ..toggleProfileDifficulty('division')
      ..updateProfileObservation('needs calm pacing')
      ..updatePedagogicalField('traversal_goal', 'Self-study')
      ..updatePedagogicalField('expected_result', 'solve exercises alone');

    final ficha = const PedagogicalReceptionBuilder().build(
      form: form,
      appLocale: 'en',
      lessonLocale: 'en',
      explanationLanguage: 'English',
      targetLanguage: 'English',
      localeContract: englishLearning,
    );

    final payloadText = [
      ficha['human_summary'],
      ficha['profile_summary'],
      ficha['goal_summary'],
      ficha['student_profile_notes'],
      ficha['initial_adaptation_guidance'],
    ].join('\n');

    expect(ficha['human_summary_locale'], 'English');
    expect(ficha['student_profile_notes_locale'], 'English');
    expect(payloadText, isNot(contains('Objetivo:')));
    expect(payloadText, isNot(contains('Prazo:')));
    expect(payloadText, isNot(contains('Dificuldade:')));
    expect(payloadText, isNot(contains('Nome:')));
    expect(payloadText, isNot(contains('Idade:')));
    expect(payloadText, contains('Objective:'));
    expect(payloadText, contains('Student:'));
  });

  test('texto livre sem escolha nao inventa tipo de objetivo', () {
    final form = EntryFormState()
      ..updateFreeText('Quero estudar biologia celular');

    final ficha = form.buildPedagogicalFicha(
      appLocale: 'pt-BR',
      lessonLocale: 'pt-BR',
      explanationLanguage: 'Portuguese',
      localeContract: SimLocaleContract.fallbackForDevelopment(),
    );

    final entry = ficha['pedagogical_entry'] as Map;
    final goal = entry['student_goal'] as Map;
    final goalType = goal['goal_type'] as Map;

    expect(goalType['code'], 'unspecified');
    expect(goalType['source'], 'not_inferred');
    expect(ficha.containsKey('exam_goal'), isFalse);
    expect(ficha.containsKey('real_use_goal'), isFalse);
  });
}
