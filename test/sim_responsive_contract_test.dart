import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/ui/responsive/sim_responsive.dart';

void main() {
  test('classifies Material and Android width breakpoints', () {
    expect(SimResponsive.widthClassFor(320), SimWindowClass.compact);
    expect(SimResponsive.widthClassFor(599), SimWindowClass.compact);
    expect(SimResponsive.widthClassFor(600), SimWindowClass.medium);
    expect(SimResponsive.widthClassFor(839), SimWindowClass.medium);
    expect(SimResponsive.widthClassFor(840), SimWindowClass.expanded);
    expect(SimResponsive.widthClassFor(1199), SimWindowClass.expanded);
    expect(SimResponsive.widthClassFor(1200), SimWindowClass.large);
    expect(SimResponsive.widthClassFor(1600), SimWindowClass.extraLarge);
  });

  test('classifies Material and Android height breakpoints', () {
    expect(SimResponsive.heightClassFor(320), SimWindowClass.compact);
    expect(SimResponsive.heightClassFor(479), SimWindowClass.compact);
    expect(SimResponsive.heightClassFor(480), SimWindowClass.medium);
    expect(SimResponsive.heightClassFor(899), SimWindowClass.medium);
    expect(SimResponsive.heightClassFor(900), SimWindowClass.expanded);
  });

  test('does not artificially narrow compact phone windows', () {
    expect(SimResponsive.frameMaxWidthFor(390), double.infinity);
    expect(SimResponsive.maxWidthConstraintsFor(390).maxWidth, double.infinity);
  });

  test('applies tablet and wide content limits', () {
    expect(SimResponsive.frameMaxWidthFor(700), 840);
    expect(SimResponsive.frameMaxWidthFor(1000), 1120);
    expect(SimResponsive.frameMaxWidthFor(1300), 1200);
    expect(SimResponsive.contentMaxWidthFor(700), 680);
    expect(SimResponsive.contentMaxWidthFor(1000), 720);
    expect(SimResponsive.contentMaxWidthFor(1300), 840);
  });

  test('returns safe reusable constraints for panels', () {
    const mediumPanel = 640.0;
    const expandedPanel = 720.0;
    const largePanel = 960.0;

    expect(
      SimResponsive.maxWidthConstraintsFor(
        700,
        medium: mediumPanel,
        expanded: expandedPanel,
        large: largePanel,
      ),
      const BoxConstraints(maxWidth: mediumPanel),
    );
    expect(
      SimResponsive.maxWidthConstraintsFor(
        1000,
        medium: mediumPanel,
        expanded: expandedPanel,
        large: largePanel,
      ),
      const BoxConstraints(maxWidth: expandedPanel),
    );
    expect(
      SimResponsive.maxWidthConstraintsFor(
        1400,
        medium: mediumPanel,
        expanded: expandedPanel,
        large: largePanel,
      ),
      const BoxConstraints(maxWidth: largePanel),
    );
  });
}
