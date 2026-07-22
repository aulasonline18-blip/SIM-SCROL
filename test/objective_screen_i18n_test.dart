import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/onboarding/onboarding_screens.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  tearDown(() => setSimActiveLanguage('pt-BR'));

  testWidgets('objetivo renderiza titulo placeholder e erro em ingles', (
    tester,
  ) async {
    setSimActiveLanguage('en');
    final session = LabSession()
      ..authReady = true
      ..authed = true;
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp(home: ObjetoScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.text('What do you want to study?'), findsOneWidget);
    expect(find.text('Goal, school subject, or topic'), findsOneWidget);
    expect(find.text('I have material'), findsOneWidget);

    expect(
      find.text('Write a little more about what you want to learn.'),
      findsNothing,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SimChatError(text: t('objective_error_min'))),
      ),
    );

    expect(
      find.text('Write a little more about what you want to learn.'),
      findsOneWidget,
    );
  });

  testWidgets('objetivo renderiza em espanhol e preserva texto do aluno', (
    tester,
  ) async {
    setSimActiveLanguage('es');
    final session = LabSession()
      ..authReady = true
      ..authed = true;
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp(home: ObjetoScreen(session: session)));
    await tester.pumpAndSettle();

    expect(find.text('¿Qué quieres estudiar?'), findsOneWidget);
    expect(find.text('Objetivo, materia o tema'), findsOneWidget);

    const typed = 'Quiero estudiar fracciones con dibujos';
    await tester.enterText(
      find.byKey(const Key('reception-objective-input')),
      typed,
    );
    await tester.pump();

    expect(find.text(typed), findsOneWidget);
    expect(session.freeText, typed);
    expect(find.text('O que você quer estudar?'), findsNothing);
  });
}
