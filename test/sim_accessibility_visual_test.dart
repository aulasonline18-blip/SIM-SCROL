import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/ui/sim_accessibility.dart';
import 'package:sim_mobile/sim/ui/sim_design_system.dart';
import 'package:sim_mobile/sim/ui/sim_theme.dart';

void main() {
  const palettes = [SimPalette.light, SimPalette.darkMode];

  test('light and dark palettes keep WCAG AA text contrast', () {
    for (final palette in palettes) {
      expect(
        SimContrast.meets(palette.text, palette.background),
        isTrue,
        reason: 'primary text on app background, dark=${palette.dark}',
      );
      expect(
        SimContrast.meets(palette.text, palette.surface),
        isTrue,
        reason: 'primary text on surface, dark=${palette.dark}',
      );
      expect(
        SimContrast.meets(palette.muted, palette.surface),
        isTrue,
        reason: 'secondary text on surface, dark=${palette.dark}',
      );
      expect(
        SimContrast.meets(palette.primary, palette.surface),
        isTrue,
        reason: 'primary action on surface, dark=${palette.dark}',
      );
      expect(
        SimContrast.meets(palette.onPrimary, palette.primary),
        isTrue,
        reason: 'text on primary action, dark=${palette.dark}',
      );
    }
  });

  test('critical state tokens have contrast and non-color cues', () {
    for (final palette in palettes) {
      for (final token in SimAccessibility.criticalStateTokens(palette)) {
        expect(
          SimContrast.meets(token.foreground, token.background),
          isTrue,
          reason: '${token.state} foreground contrast, dark=${palette.dark}',
        );
        expect(
          SimContrast.meets(
            token.border,
            token.background,
            minimum: SimContrast.nonText,
          ),
          isTrue,
          reason: '${token.state} border contrast, dark=${palette.dark}',
        );
        expect(token.includesNonColorCue, isTrue);
      }
    }
  });

  test('touch targets and spacing meet mobile accessibility minimums', () {
    expect(SimTouch.wcagMinimum, greaterThanOrEqualTo(24));
    expect(SimTouch.min, greaterThanOrEqualTo(SimTouch.recommended));
    expect(SimTouch.icon, greaterThanOrEqualTo(44));
    expect(SimTouch.spacing, greaterThanOrEqualTo(8));
    expect(SimSpacing.touchGap, greaterThanOrEqualTo(8));
  });

  test('spacing tokens keep coherent visual density', () {
    expect(SimSpacing.xs, greaterThanOrEqualTo(8));
    expect(SimSpacing.sm, greaterThan(SimSpacing.xs));
    expect(SimSpacing.md, greaterThan(SimSpacing.sm));
    expect(SimSpacing.lg, greaterThan(SimSpacing.md));
    expect(SimSpacing.xl, greaterThan(SimSpacing.lg));
    expect(SimSpacing.xxl, greaterThan(SimSpacing.xl));
  });

  test(
    'typography tokens define clear hierarchy without fixed scaling caps',
    () {
      final styles = <TextStyle>[
        SimTypography.title,
        SimTypography.body,
        SimTypography.caption,
        SimTypography.label,
        SimTypography.muted,
        SimTypography.emphasis,
      ];

      for (final style in styles) {
        expect(style.fontSize, isNotNull);
        expect(style.height, isNotNull);
        expect(style.fontSize, greaterThanOrEqualTo(12));
        expect(style.height, greaterThanOrEqualTo(1.3));
      }

      expect(
        SimTypography.title.fontSize,
        greaterThan(SimTypography.body.fontSize!),
      );
      expect(
        SimTypography.caption.fontSize,
        lessThan(SimTypography.body.fontSize!),
      );
      expect(SimTypography.emphasis.fontWeight, FontWeight.w700);
    },
  );

  test('theme palettes expose valid light and dark visual surfaces', () {
    expect(SimPalette.light.dark, isFalse);
    expect(SimPalette.darkMode.dark, isTrue);

    for (final palette in palettes) {
      expect(palette.background, isNot(equals(palette.text)));
      expect(palette.surface, isNot(equals(palette.text)));
      expect(palette.surfaceSoft, isNot(equals(palette.text)));
      expect(palette.focus, isNot(equals(palette.surface)));
    }
  });

  testWidgets('global text scale remains available to design-system text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Texto escalavel', style: SimTypography.body),
        ),
      ),
    );

    final context = tester.element(find.text('Texto escalavel'));
    final scaler = MediaQuery.textScalerOf(context);
    expect(SimTextScale.supports(scaler), isTrue);
    expect(scaler.scale(SimTypography.body.fontSize!), 32);
  });
}
