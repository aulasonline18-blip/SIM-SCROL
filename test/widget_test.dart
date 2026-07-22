import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/classroom/chat_aula_screen.dart';
import 'package:sim_mobile/features/onboarding/onboarding_screens.dart';
import 'package:sim_mobile/features/onboarding/preparation_and_placement.dart';
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
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'pt-BR'
      ..freeText = 'Estudar matematica'
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
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'pt-BR'
      ..route = '/cyber/aula';

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    await tester.pumpAndSettle();

    expect(find.byType(ChatAulaScreen), findsNothing);
    expect(find.byType(ConversationalEntryScreen), findsOneWidget);
    expect(session.route, '/cyber/objeto');
  });

  testWidgets('lessonLocalId alone does not bypass language and objective', (
    tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/aula'
      ..lessonLocalId = 'legacy-incomplete-route';

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    await tester.pumpAndSettle();

    expect(find.byType(ChatAulaScreen), findsNothing);
    expect(find.byType(ConversationalEntryScreen), findsOneWidget);
    expect(session.route, '/cyber/idioma');
  });

  testWidgets('portao de nivelamento renderiza conteudo e nao tela branca', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = LabSession(prefs: prefs)
      ..authed = true
      ..authReady = true
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'pt-BR'
      ..lessonLocalId = 'placement-rendered'
      ..route = '/cyber/placement';
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(home: PlacementLabScreen(session: session)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Passo 1 de 4'), findsOneWidget);
    expect(
      find.text('Antes de começar, escolha seu ponto de partida.'),
      findsOneWidget,
    );
    expect(find.text('Começar do início'), findsOneWidget);
    expect(find.text('Encontrar meu ponto'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
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
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'pt-BR'
      ..freeText = 'Estudar historia'
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

    await tester.enterText(
      find.byType(TextField).first,
      'Quero estudar porcentagem com exemplos simples',
    );
    expect(session.freeText, contains('porcentagem'));
    expect(session.saveObjectiveEntry(), isTrue);
    expect(session.lessonLocalId, isNotNull);
  });
}
