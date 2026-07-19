import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/classroom/chat_aula_screen.dart';
import 'package:sim_mobile/features/onboarding/onboarding_screens.dart';
import 'package:sim_mobile/main.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';
import 'package:sim_mobile/sim/ui/sim_theme.dart';

void main() {
  setUp(() => setSimActiveLanguage('pt-BR'));

  testWidgets('rota de aula usa chat quando existe lessonLocalId', (
    tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/aula'
      ..lessonLocalId = 'lesson-chat-route';

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    await tester.pumpAndSettle();

    expect(find.byType(ChatAulaScreen), findsOneWidget);
  });

  testWidgets('rota de aula sem lessonLocalId volta para recepcao', (
    tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/aula';

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    await tester.pumpAndSettle();

    expect(find.byType(ChatAulaScreen), findsNothing);
    expect(find.byType(ConversationalEntryScreen), findsOneWidget);
    expect(find.text('Recepção pedagógica'), findsOneWidget);
  });

  testWidgets('portal renderiza entrada principal do SIM', (tester) async {
    await tester.pumpWidget(const SimMobileApp());
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('SIM'), findsOneWidget);
    expect(find.text(t('portal_tagline')), findsOneWidget);
  });

  testWidgets('portal alterna e persiste modo escuro', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(SimMobileApp(prefs: prefs));
    await tester.pump();

    expect(find.bySemanticsLabel(t('theme_dark')), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(t('theme_dark')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(t('theme_light')), findsOneWidget);
    expect(prefs.getBool('sim.ui.dark_mode'), isTrue);
  });

  testWidgets('modo escuro aplica fundo escuro no portal', (tester) async {
    SharedPreferences.setMockInitialValues({'sim.ui.dark_mode': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(SimMobileApp(prefs: prefs));
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, SimPalette.darkMode.background);
    expect(find.bySemanticsLabel(t('theme_light')), findsOneWidget);
  });

  testWidgets('modo escuro aplica fundo escuro no onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({'sim.ui.dark_mode': true});
    final prefs = await SharedPreferences.getInstance();
    final session = LabSession()
      ..route = '/cyber/idioma'
      ..authed = true
      ..authReady = true;

    await tester.pumpWidget(
      SimMobileApp(initialSession: session, prefs: prefs),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ConversationalEntryScreen));
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      SimPalette.darkMode.background,
    );
    expect(find.byType(ConversationalEntryScreen), findsOneWidget);
  });

  testWidgets('aula alterna e persiste modo escuro', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = LabSession(prefs: prefs)
      ..authed = true
      ..authReady = true
      ..route = '/cyber/aula'
      ..lessonLocalId = 'lesson-dark-classroom';

    await tester.pumpWidget(
      SimMobileApp(initialSession: session, prefs: prefs),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChatAulaScreen), findsOneWidget);
    expect(find.bySemanticsLabel(t('theme_dark')), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(t('theme_dark')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(t('theme_light')), findsOneWidget);
    expect(prefs.getBool('sim.ui.dark_mode'), isTrue);
  });

  testWidgets('recepcao salva objetivo e cria lessonLocalId', (tester) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true;

    await tester.pumpWidget(
      MaterialApp(home: ConversationalEntryScreen(session: session)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('reception-guided-path')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Quero estudar porcentagem com exemplos simples',
    );
    expect(session.freeText, contains('porcentagem'));
    expect(session.saveObjectiveEntry(), isTrue);
    expect(session.lessonLocalId, isNotNull);
  });
}
