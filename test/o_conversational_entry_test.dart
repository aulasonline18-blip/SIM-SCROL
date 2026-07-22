import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/onboarding/onboarding_screens.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setSimActiveLanguage('pt-BR');
  });

  testWidgets('entrada conversacional renderiza recepcao pedagogica viva', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final session = LabSession(prefs: prefs)
      ..authed = true
      ..authReady = true;

    await tester.pumpWidget(
      MaterialApp(home: ConversationalEntryScreen(session: session)),
    );
    await tester.pump();

    expect(find.text('O que você quer estudar?'), findsOneWidget);
    expect(find.byKey(const Key('reception-objective-input')), findsOneWidget);
    expect(find.byKey(const Key('reception-guided-path')), findsOneWidget);

    session.dispose();
  });

  test('ficha da entrada preserva objetivo, idioma e perfil mínimo', () async {
    final prefs = await SharedPreferences.getInstance();
    final session = LabSession(prefs: prefs)
      ..authed = true
      ..authReady = true;

    await session.setInterfaceLanguage(followDevice: false, localeTag: 'pt-BR');
    await session.setLearningLanguage(localeTag: 'pt-BR');
    session
      ..freeText = 'Quero estudar frações equivalentes com exemplos'
      ..preferredName = 'Lucas';

    expect(session.saveObjectiveEntry(), isTrue);
    final state = session.canonicalStore?.readState(session.lessonLocalId!);

    expect(state?.profile.objetivo, contains('frações'));
    expect(state?.profile.extra['interfaceLocale'], 'pt-BR');
    expect(state?.profile.extra['learningLocale'], 'pt-BR');

    session.dispose();
  });
}
