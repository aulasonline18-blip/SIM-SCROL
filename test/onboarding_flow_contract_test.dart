import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/onboarding/onboarding_screens.dart';
import 'package:sim_mobile/features/session/lab_session.dart';

void main() {
  testWidgets('Fluxo de onboarding deve preservar comportamento atual', (
    tester,
  ) async {
    final languageSession = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/idioma';
    addTearDown(languageSession.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ConversationalEntryScreen(session: languageSession)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('language-screen')), findsOneWidget);
    await tester.tap(find.text('Português'));
    await tester.pumpAndSettle();
    expect(languageSession.selectedLanguageCode, 'pt');
    expect(languageSession.stableLang, 'Portuguese');

    final entrySession = LabSession()
      ..authed = true
      ..authReady = true;
    addTearDown(entrySession.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ObjetoScreen(session: entrySession)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('pedagogical-reception-scroll')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reception-guided-path')), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('reception-guided-path')));
    await tester.enterText(
      find.byType(TextField).first,
      'Quero aprender porcentagem para prova',
    );
    await _tapVisible(tester, find.text('Salvar e continuar').first);

    expect(entrySession.freeText, 'Quero aprender porcentagem para prova');
    expect(
      find.byKey(const Key('reception-answer-objective'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Qual nível ou contexto devo considerar?'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
