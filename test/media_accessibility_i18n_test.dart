import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/aula_widgets.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  tearDown(() => setSimActiveLanguage('pt-BR'));

  testWidgets('visual board semantics e titulos seguem idioma da interface', (
    tester,
  ) async {
    setSimActiveLanguage('en');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonVisualBoard(
            data:
                '<svg viewBox="0 0 600 800"><text>Comparison versus examples</text></svg>',
            caption: 'Pedagogical lesson image',
          ),
        ),
      ),
    );

    expect(find.text('Comparison board'), findsOneWidget);
    expect(find.byTooltip('Visual board description'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Show visual board description'),
      findsOneWidget,
    );
  });

  testWidgets('alt text generico de imagem acompanha locale ativo', (
    tester,
  ) async {
    setSimActiveLanguage('es');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonVisualBoard(
            data:
                '<svg viewBox="0 0 600 800"><text>Imagen pedagógica</text></svg>',
            caption: 'Imagen pedagógica de la clase',
          ),
        ),
      ),
    );

    expect(find.text('Imagen pedagógica de la clase'), findsWidgets);
  });
}
