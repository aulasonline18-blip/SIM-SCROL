import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/onboarding/onboarding_screens.dart';
import 'package:sim_mobile/sim/ui/sim_accessibility.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';
import 'package:sim_mobile/sim/ui/sim_theme.dart';
import 'package:sim_mobile/sim/ui/widgets/lesson_avatar.dart';

void main() {
  tearDown(() => setSimActiveLanguage('pt-BR'));

  testWidgets('erro inline e liveRegion usam idioma ativo', (tester) async {
    setSimActiveLanguage('en');
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SimChatError(text: t('objective_error_min'))),
      ),
    );

    final node = tester.getSemantics(find.byType(SimChatError));
    expect(
      node.label,
      contains('Write a little more about what you want to learn.'),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  testWidgets('avatar de aula anuncia fala em espanhol', (tester) async {
    setSimActiveLanguage('es');
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LessonAvatar(speaking: true))),
    );

    final node = tester.getSemantics(find.byType(LessonAvatar));
    expect(node.label, 'SIM hablando');
    semantics.dispose();
  });

  test('tokens visuais de estado usam labels traduzidos', () {
    setSimActiveLanguage('en');
    final danger = SimAccessibility.stateToken(
      SimVisualState.danger,
      SimPalette.light,
    );
    expect(danger.semanticLabel, 'error');

    setSimActiveLanguage('es');
    final disabled = SimAccessibility.stateToken(
      SimVisualState.disabled,
      SimPalette.light,
    );
    expect(disabled.semanticLabel, 'no disponible');
  });
}
