import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/onboarding/onboarding_screens.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  tearDown(() => setSimActiveLanguage('pt-BR'));

  test('compact localization contract keeps public keys human-readable', () {
    expect(debugSimLocalizedValue('pt-BR', 'aula_next'), 'Próximo');
    expect(
      debugSimLocalizedValue('pt-BR', 'aula_audio_play'),
      'Tocar áudio da aula',
    );
    expect(
      debugSimLocalizedValue('pt-BR', 'aula_image_unavailable'),
      contains('Imagem'),
    );
    expect(debugSimMissingLocalizationKeys()['pt'], isEmpty);
    expect(debugSimMissingLocalizationKeys()['en'], isEmpty);
  });

  test('language contract separates interface lesson and target languages', () {
    final settings = const SimLocaleSettings(
      followDeviceInterface: false,
      manualInterfaceLocale: 'en',
      learningLocale: 'pt-BR',
      targetLanguage: 'en',
    );

    final contract = settings.contract();
    expect(contract.interfaceLocale, 'en');
    expect(contract.learningLocale, 'pt-BR');
    expect(contract.explanationLanguage, 'Portuguese');
    expect(contract.targetLanguage, 'English');
  });

  test(
    'new lesson stores pedagogical locale without rewriting interface locale',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = LabSession(prefs: prefs);

      await session.setInterfaceLanguage(
        followDevice: false,
        localeTag: 'pt-BR',
      );
      await session.setLearningLanguage(localeTag: 'pt-BR');
      session.freeText = 'Quero estudar estatística com exemplos simples';

      expect(session.saveObjectiveEntry(), isTrue);
      final state = session.canonicalStore?.readState(session.lessonLocalId!);

      expect(session.interfaceLocaleTag, 'pt-BR');
      expect(state?.profile.language, 'pt-BR');
      expect(state?.profile.extra['interfaceLocale'], 'pt-BR');
      expect(state?.profile.extra['learningLocale'], 'pt-BR');

      session.dispose();
    },
  );

  testWidgets('conversational entry renders pedagogical reception', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = LabSession(prefs: prefs);

    await tester.pumpWidget(
      MaterialApp(home: ConversationalEntryScreen(session: session)),
    );
    await tester.pump();

    expect(find.text('Recepção pedagógica'), findsOneWidget);
    expect(find.byKey(const Key('reception-guided-path')), findsOneWidget);

    session.dispose();
  });
}
