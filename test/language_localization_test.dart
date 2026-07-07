import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/onboarding/onboarding_screens.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/shared/widgets/shared_widgets.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  tearDown(() {
    setSimActiveLanguage('pt-BR');
  });

  test('interface localization covers Portuguese English and Spanish', () {
    expect(debugSimLocalizedValue('pt-BR', 'aula_next'), 'Próximo');
    expect(
      debugSimLocalizedValue('pt-BR', 'aula_try_again_2'),
      'Tentar novamente',
    );

    expect(debugSimLocalizedValue('en', 'aula_next'), 'Next');
    expect(debugSimLocalizedValue('en', 'aula_try_again_2'), 'Try again');

    expect(debugSimLocalizedValue('es', 'aula_next'), 'Siguiente');
    expect(
      debugSimLocalizedValue('es', 'aula_try_again_2'),
      'Intentar de nuevo',
    );

    expect(debugSimLocalizedValue('es', 'aula_next'), isNot('aula_next'));
  });

  test('supported interface locales expose complete localization key sets', () {
    final counts = debugSimLocalizationKeyCounts();
    expect(counts['pt'], counts['en']);
    expect(counts['es'], counts['en']);
    expect(debugSimMissingLocalizationKeys()['pt'], isEmpty);
    expect(debugSimMissingLocalizationKeys()['en'], isEmpty);
    expect(debugSimMissingLocalizationKeys()['es'], isEmpty);
  });

  test('device locale fallback only returns supported interface locales', () {
    expect(
      const SimLocaleSettings().resolveInterfaceLocale(const Locale('fr')),
      'pt-BR',
    );
    expect(
      const SimLocaleSettings().resolveInterfaceLocale(
        const Locale('en', 'US'),
      ),
      'en',
    );
    expect(
      const SimLocaleSettings().resolveInterfaceLocale(
        const Locale('es', 'MX'),
      ),
      'es',
    );
  });

  test(
    'manual interface and learning languages are persisted separately',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = LabSession(prefs: prefs);

      await session.setInterfaceLanguage(
        followDevice: false,
        localeTag: 'pt-BR',
      );
      await session.setLearningLanguage(localeTag: 'es');

      final reloaded = SimLocaleSettings.load(prefs);
      expect(reloaded.followDeviceInterface, isFalse);
      expect(reloaded.manualInterfaceLocale, 'pt-BR');
      expect(reloaded.learningLocale, 'es');
      expect(reloaded.contract().interfaceLocale, 'pt-BR');
      expect(reloaded.contract().learningLocale, 'es');
      expect(reloaded.contract().explanationLanguage, 'Spanish');

      session.dispose();
    },
  );

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
      final id = session.lessonLocalId!;
      final state = session.canonicalStore?.readState(id);

      expect(session.interfaceLocaleTag, 'pt-BR');
      expect(state?.profile.language, 'pt-BR');
      expect(state?.profile.stableLang, 'Portuguese');
      expect(state?.profile.extra['interfaceLocale'], 'pt-BR');
      expect(state?.profile.extra['learningLocale'], 'pt-BR');
      expect(state?.profile.extra['explanationLanguage'], 'Portuguese');

      session.dispose();
    },
  );

  testWidgets(
    'language screen shows separate app and lesson language controls',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = LabSession(prefs: prefs);
      setSimActiveLanguage('pt-BR');

      await tester.pumpWidget(
        MaterialApp(home: IdiomaScreen(session: session)),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      expect(find.text('Idioma do app'), findsOneWidget);
      expect(find.text('Idioma das aulas'), findsOneWidget);
      expect(find.text('Seguir dispositivo'), findsOneWidget);

      session.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'lesson drawer exposes separate app and lesson language settings',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = LabSession(prefs: prefs)
        ..authed = false
        ..authReady = true;
      setSimActiveLanguage('pt-BR');
      await session.setInterfaceLanguage(
        followDevice: false,
        localeTag: 'pt-BR',
      );
      await session.setLearningLanguage(localeTag: 'es');

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAulaMenu(context, session),
              child: const Text('open drawer'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open drawer'));
      await tester.pumpAndSettle();

      expect(find.text('Idioma do app'), findsOneWidget);
      expect(find.text('Idioma das aulas'), findsOneWidget);
      expect(find.text('Seguir dispositivo'), findsOneWidget);
      expect(session.localeSettings.learningLocale, 'es');

      session.dispose();
    },
  );
}
