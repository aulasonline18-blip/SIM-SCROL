import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/ui/responsive/sim_responsive.dart';
import 'package:sim_mobile/sim/ui/sim_components.dart';
import 'package:sim_mobile/sim/ui/sim_design_system.dart';
import 'package:sim_mobile/sim/ui/sim_theme.dart';

void main() {
  test('responsive constraints apply max width by window class', () {
    expect(SimResponsive.maxWidthConstraintsFor(320).maxWidth, double.infinity);
    expect(SimResponsive.maxWidthConstraintsFor(700).maxWidth, 680);
    expect(SimResponsive.maxWidthConstraintsFor(1000).maxWidth, 720);
    expect(SimResponsive.maxWidthConstraintsFor(1300).maxWidth, 840);
  });

  test('compact phones are not artificially narrowed', () {
    expect(SimResponsive.contentMaxWidthFor(320), double.infinity);
    expect(SimResponsive.cardMaxWidthFor(360), double.infinity);
    expect(SimResponsive.frameMaxWidthFor(390), double.infinity);
  });

  test('responsive padding and gaps increase by window class', () {
    expect(SimResponsive.paddingFor(320).horizontal, 32);
    expect(SimResponsive.paddingFor(700).horizontal, 48);
    expect(SimResponsive.paddingFor(1000).horizontal, 64);
    expect(SimResponsive.paddingFor(1300).horizontal, 80);

    expect(SimResponsive.cardPaddingFor(320).left, 16);
    expect(SimResponsive.cardPaddingFor(700).left, 20);
    expect(SimResponsive.cardPaddingFor(1000).left, 24);
    expect(SimResponsive.cardPaddingFor(1300).left, 28);

    expect(SimResponsive.gapFor(320), lessThan(SimResponsive.gapFor(700)));
    expect(SimResponsive.gapFor(700), lessThan(SimResponsive.gapFor(1000)));
    expect(SimResponsive.gapFor(1000), lessThan(SimResponsive.gapFor(1300)));
  });

  test('visible area helper accounts for keyboard viewInsets', () {
    const media = MediaQueryData(
      size: Size(390, 844),
      padding: EdgeInsets.fromLTRB(0, 47, 0, 34),
      viewInsets: EdgeInsets.only(bottom: 320),
    );

    expect(SimResponsive.keyboardInsetsFor(media).bottom, 320);
    expect(SimResponsive.safeKeyboardPaddingFor(media).bottom, 320);
    expect(SimResponsive.visibleSizeFor(media), const Size(390, 477));
  });

  test('safe area helper preserves physical padding without keyboard', () {
    const media = MediaQueryData(
      size: Size(430, 900),
      padding: EdgeInsets.fromLTRB(12, 44, 12, 34),
    );

    expect(SimResponsive.safePaddingFor(media), media.padding);
    expect(SimResponsive.safeKeyboardPaddingFor(media), media.padding);
    expect(SimResponsive.visibleSizeFor(media), const Size(406, 822));
  });

  test(
    'card and button tokens meet shared responsive accessibility minimums',
    () {
      expect(SimResponsive.cardMaxWidthFor(320), double.infinity);
      expect(SimResponsive.cardMaxWidthFor(700), 680);
      expect(SimResponsive.cardMaxWidthFor(1000), 840);
      expect(SimResponsive.buttonMinimumSizeFor(320).height, SimTouch.min);
      expect(
        SimResponsive.buttonMinimumSizeFor(700).width,
        greaterThan(SimTouch.min),
      );
      expect(SimTouch.min, SimResponsiveDensity.touchMin);
      expect(SimTouch.spacing, SimResponsiveDensity.touchGap);
    },
  );

  testWidgets('shared responsive components render without feature screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: SimThemeScope(
          darkMode: false,
          onToggleDarkMode: () {},
          child: const SimResponsiveContainer(
            child: SimResponsiveSurface(
              child: SizedBox(key: Key('shared-component'), height: 40),
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byKey(const Key('shared-component')));
    expect(rect.width, lessThanOrEqualTo(680));
    expect(rect.height, 40);
  });

  testWidgets('responsive button style keeps minimum target size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Builder(
            builder: (context) {
              return FilledButton(
                style: SimResponsiveButtonStyle.filled(context),
                onPressed: () {},
                child: const Text('Continuar'),
              );
            },
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(SimTouch.min),
    );
    expect(
      tester.getSize(find.byType(FilledButton)).width,
      greaterThanOrEqualTo(SimTouch.min),
    );
  });
}
