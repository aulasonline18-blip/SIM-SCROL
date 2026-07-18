import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/chat_aula_screen.dart';
import 'package:sim_mobile/features/onboarding/onboarding_screens.dart';
import 'package:sim_mobile/main.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

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

  testWidgets('rota de aula sem lessonLocalId volta para entrada fina', (
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
    expect(find.text(t('objeto_title')), findsOneWidget);
  });

  testWidgets('portal renderiza entrada principal do SIM', (tester) async {
    await tester.pumpWidget(const SimMobileApp());
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('SIM'), findsOneWidget);
    expect(find.text(t('portal_tagline')), findsOneWidget);
  });

  testWidgets('entrada fina salva objetivo e cria lessonLocalId', (
    tester,
  ) async {
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
