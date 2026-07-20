import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/portal/portal_flow.dart';
import 'package:sim_mobile/shared/widgets/shared_widgets.dart';
import 'package:sim_mobile/sim/classroom/classroom_text_scale.dart';
import 'package:sim_mobile/sim/ui/sim_accessibility.dart';
import 'package:sim_mobile/sim/ui/sim_components.dart';
import 'package:sim_mobile/sim/ui/sim_design_system.dart';
import 'package:sim_mobile/sim/ui/sim_theme.dart';
import 'package:sim_mobile/sim/ui/widgets/cyber_step_shell.dart';

void main() {
  test('SIM Ideal breakpoints keep phone focused and tablet wider', () {
    expect(SimBreakpoints.frameMaxWidth(390), double.infinity);
    expect(SimBreakpoints.learningMaxWidth(390), double.infinity);
    expect(SimBreakpoints.frameMaxWidth(800), 840);
    expect(SimBreakpoints.learningMaxWidth(800), 640);
    expect(SimBreakpoints.frameMaxWidth(1200), 1200);
    expect(SimBreakpoints.learningMaxWidth(1200), 840);
  });

  test('classroom text scale grows strongly on phone and tablet', () {
    expect(ClassroomTextScale.scaleForWidth(5, 390), 1.44);
    expect(ClassroomTextScale.scaleForWidth(3, 390), 1.12);
    expect(ClassroomTextScale.scaleForWidth(1, 800), 1.18);
    expect(ClassroomTextScale.scaleForWidth(5, 800), 1.86);
    expect(
      ClassroomTextScale.scaleForWidth(1, 800),
      greaterThan(ClassroomTextScale.scaleForWidth(5, 390) - 0.3),
    );
  });

  testWidgets('primary and secondary actions keep accessible touch height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            PrimaryWideButton(label: 'Continuar', onTap: () {}),
            SecondaryWideButton(label: 'Voltar', onTap: () {}),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.text('Continuar')).height, greaterThan(0));
    expect(
      tester.getSize(find.byType(FilledButton).first).height,
      greaterThanOrEqualTo(SimTouch.min),
    );
    expect(
      tester.getSize(find.byType(FilledButton).last).height,
      greaterThanOrEqualTo(SimTouch.min),
    );
  });

  test('constitutional palette keeps readable light and dark contrast', () {
    for (final palette in const [SimPalette.light, SimPalette.darkMode]) {
      expect(SimContrast.meets(palette.text, palette.background), isTrue);
      expect(SimContrast.meets(palette.text, palette.surface), isTrue);
      expect(SimContrast.meets(palette.onPrimary, palette.primary), isTrue);
      expect(palette.primary, isNot(palette.success));
      expect(palette.warning, isNot(palette.danger));
    }
  });

  testWidgets('global surfaces and status states fit a phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      SimThemeScope(
        darkMode: false,
        onToggleDarkMode: _noop,
        child: MaterialApp(
          home: Scaffold(
            body: SimResponsiveContainer(
              includeSafeArea: true,
              child: Column(
                children: const [
                  SimLearningSurface(
                    child: Text(
                      'Uma superfície pedagógica respira sem cortar texto.',
                    ),
                  ),
                  SizedBox(height: SimSpacing.sm),
                  SimStatusSurface(
                    tone: SimSurfaceTone.success,
                    icon: Icons.check_circle_outline,
                    child: Text('Acerto claro com ícone e texto.'),
                  ),
                  SizedBox(height: SimSpacing.sm),
                  SimStatusSurface(
                    tone: SimSurfaceTone.warning,
                    icon: Icons.warning_amber_rounded,
                    child: Text('Atenção clara sem depender só da cor.'),
                  ),
                  SizedBox(height: SimSpacing.sm),
                  SimStatusSurface(
                    tone: SimSurfaceTone.danger,
                    icon: Icons.error_outline,
                    child: Text('Erro humano com contraste e borda.'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SimLearningSurface), findsOneWidget);
    expect(find.byType(SimStatusSurface), findsNWidgets(3));
  });

  testWidgets('CyberStepShell widens learning column on tablet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(820, 1000));
    await tester.pumpWidget(
      const MaterialApp(
        home: CyberStepShell(
          step: 1,
          total: 5,
          child: SizedBox(key: Key('ideal-child'), width: double.infinity),
        ),
      ),
    );

    final childWidth = tester
        .getSize(find.byKey(const Key('ideal-child')))
        .width;
    expect(childWidth, greaterThan(560));
    expect(childWidth, lessThanOrEqualTo(640));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('SimFrame protects global content from physical safe areas', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(430, 900),
          padding: EdgeInsets.fromLTRB(0, 47, 0, 34),
          viewPadding: EdgeInsets.fromLTRB(0, 47, 0, 34),
        ),
        child: MaterialApp(
          home: SimThemeScope(
            darkMode: false,
            onToggleDarkMode: _noop,
            child: const SimFrame(
              child: ColoredBox(
                key: Key('safe-content'),
                color: Colors.white,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byKey(const Key('safe-content')));
    expect(rect.top, 47);
    expect(rect.bottom, 900 - 34);
    expect(rect.left, 0);
    expect(rect.right, 430);
  });

  testWidgets(
    'SimFrame respects landscape side cutouts and bottom gesture bar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 430));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(900, 430),
            padding: EdgeInsets.fromLTRB(44, 0, 44, 21),
            viewPadding: EdgeInsets.fromLTRB(44, 0, 44, 21),
          ),
          child: MaterialApp(
            home: SimThemeScope(
              darkMode: false,
              onToggleDarkMode: _noop,
              child: const SimFrame(
                child: ColoredBox(
                  key: Key('landscape-safe-content'),
                  color: Colors.white,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );

      final rect = tester.getRect(
        find.byKey(const Key('landscape-safe-content')),
      );
      expect(rect.left, 44);
      expect(rect.right, 900 - 44);
      expect(rect.top, 0);
      expect(rect.bottom, 430 - 21);
    },
  );
}

void _noop() {}
