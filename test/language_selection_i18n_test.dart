import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/onboarding/onboarding_screens.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  tearDown(() => setSimActiveLanguage('pt-BR'));

  testWidgets('tela de idioma renderiza instrucoes em ingles', (tester) async {
    setSimActiveLanguage('en');
    final session = LabSession()
      ..route = '/cyber/idioma'
      ..authReady = true
      ..authed = true;
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ConversationalEntryScreen(session: session)),
    );

    expect(find.text('Experience language'), findsOneWidget);
    expect(find.text('Main languages'), findsWidgets);
    expect(find.text('Idioma da experiência'), findsNothing);
  });

  testWidgets('tela de idioma renderiza instrucoes em espanhol', (
    tester,
  ) async {
    setSimActiveLanguage('es');
    final session = LabSession()
      ..route = '/cyber/idioma'
      ..authReady = true
      ..authed = true;
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ConversationalEntryScreen(session: session)),
    );

    expect(find.text('Idioma de la experiencia'), findsOneWidget);
    expect(find.text('Idiomas principales'), findsWidgets);
    expect(
      find.text('Choose the interface and lesson language before the goal.'),
      findsNothing,
    );
  });

  testWidgets('escolha de UI preserva targetLanguage do contrato L1', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = LabSession(prefs: prefs)
      ..route = '/cyber/idioma'
      ..authReady = true
      ..authed = true;
    addTearDown(session.dispose);

    await session.setLearningLanguage(
      localeTag: 'pt-BR',
      targetLanguage: 'English',
    );
    setSimActiveLanguage('en');

    await tester.pumpWidget(
      MaterialApp(home: ConversationalEntryScreen(session: session)),
    );
    await tester.tap(find.text('English').first);
    await tester.pumpAndSettle();

    expect(session.localeContract.interfaceLocale, 'en');
    expect(session.localeContract.targetLanguage, 'English');
  });
}
