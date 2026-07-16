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
      'fr',
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
    expect(contract.toJson(), {
      'interfaceLocale': 'en',
      'learningLocale': 'pt-BR',
      'explanationLanguage': 'Portuguese',
      'targetLanguage': 'English',
    });
  });

  test('invalid or missing locale data falls back safely', () {
    final settings = const SimLocaleSettings(
      followDeviceInterface: false,
      manualInterfaceLocale: 'klingon',
      learningLocale: 'unknown',
    );

    expect(settings.contract().interfaceLocale, 'pt-BR');
    expect(settings.contract().learningLocale, 'pt-BR');
    expect(settings.contract().explanationLanguage, 'Portuguese');
    expect(normalizeSimTargetLanguage('Italian'), 'Italian');
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

  test(
    'historical lesson preserves original pedagogical language after changes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = LabSession(prefs: prefs);

      await session.setInterfaceLanguage(
        followDevice: false,
        localeTag: 'pt-BR',
      );
      await session.setLearningLanguage(localeTag: 'pt-BR');
      session.freeText = 'Quero estudar proporções com exemplos simples';

      expect(session.saveObjectiveEntry(), isTrue);
      final id = session.lessonLocalId!;
      final before = session.canonicalStore?.readState(id);

      await session.setInterfaceLanguage(followDevice: false, localeTag: 'en');
      await session.setLearningLanguage(
        localeTag: 'es',
        targetLanguage: 'English',
      );
      final after = session.canonicalStore?.readState(id);

      expect(session.interfaceLocaleTag, 'en');
      expect(session.learningLocaleTag, 'es');
      expect(before?.profile.extra['learningLocale'], 'pt-BR');
      expect(after?.profile.language, 'pt-BR');
      expect(after?.profile.stableLang, 'Portuguese');
      expect(after?.profile.extra['interfaceLocale'], 'pt-BR');
      expect(after?.profile.extra['learningLocale'], 'pt-BR');
      expect(after?.profile.extra['explanationLanguage'], 'Portuguese');
      expect(after?.profile.extra['targetLanguage'], isNull);

      session.dispose();
    },
  );

  test('fixed technical states are localized and do not expose raw keys', () {
    expect(
      debugSimLocalizedValue('en', 'aula_gen_fail'),
      isNot('aula_gen_fail'),
    );
    expect(
      debugSimLocalizedValue('es', 'aula_audio_unavailable'),
      isNot('aula_audio_unavailable'),
    );
    expect(
      debugSimLocalizedValue('pt-BR', 'aula_image_unavailable'),
      contains('Imagem'),
    );
    expect(
      debugSimLocalizedValue('en', 'aula_image_unavailable'),
      contains('Image'),
    );
    expect(
      debugSimLocalizedValue('es', 'aula_image_unavailable'),
      contains('Imagen'),
    );
  });

  test('accessibility labels follow the interface language', () {
    expect(
      debugSimLocalizedValue('pt-BR', 'aula_audio_play'),
      'Tocar áudio da aula',
    );
    expect(
      debugSimLocalizedValue('en', 'aula_audio_play'),
      'Play lesson audio',
    );
    expect(
      debugSimLocalizedValue('es', 'aula_audio_play'),
      'Reproducir audio de la clase',
    );
    expect(
      debugSimLocalizedValue('en', 'aula_image_expand_lesson'),
      'Expand lesson image',
    );
    expect(
      debugSimLocalizedValue('es', 'aula_image_expand_lesson'),
      'Ampliar imagen de la clase',
    );
  });

  testWidgets(
    'conversational entry shows separate app and lesson language controls',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = LabSession(prefs: prefs);
      setSimActiveLanguage('pt-BR');

      await tester.pumpWidget(
        MaterialApp(home: ConversationalEntryScreen(session: session)),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      expect(
        find.text('SIM: Em que idioma você quer usar o SIM?'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('sim-entry-interface-language-button')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('sim-entry-interface-language-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Seguir dispositivo'), findsOneWidget);
      await tester.tap(find.text('Português').last);
      await tester.pumpAndSettle();

      expect(
        find.text('SIM: Em que idioma você quer que eu ensine as aulas?'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('sim-entry-learning-language-button')),
        findsOneWidget,
      );

      session.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('language picker fixed labels follow selected app language', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = LabSession(prefs: prefs);
    setSimActiveLanguage('pt-BR');

    await tester.pumpWidget(
      MaterialApp(home: ConversationalEntryScreen(session: session)),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(find.textContaining('Português'), findsNothing);
    expect(
      find.text(
        'Uma timeline. Duas entradas fortes. Uma ficha pedagógica estruturada.',
      ),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const Key('sim-entry-interface-language-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('sim-entry-interface-language-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('sim-entry-interface-language-search')),
      findsOneWidget,
    );
    expect(find.text('Buscar idioma'), findsOneWidget);
    expect(find.byTooltip('Fechar'), findsOneWidget);

    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(find.text('App language'), findsOneWidget);
    expect(find.text('Lesson language'), findsOneWidget);
    expect(find.text('Choose'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('sim-entry-learning-language-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('sim-entry-learning-language-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('sim-entry-learning-language-search')),
      findsOneWidget,
    );
    expect(find.text('Search language'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    session.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

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
