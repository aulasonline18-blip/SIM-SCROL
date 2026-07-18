import 'package:flutter/material.dart';

import 'responsive/sim_responsive.dart';
import 'sim_design_system.dart';
import 'sim_theme.dart';

class SimResponsiveContainer extends StatelessWidget {
  const SimResponsiveContainer({
    required this.child,
    this.maxWidth,
    this.padding,
    this.includeSafeArea = false,
    super.key,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;
  final bool includeSafeArea;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final content = Center(
      child: ConstrainedBox(
        constraints: SimResponsive.maxWidthConstraintsFor(
          width,
          compact: double.infinity,
          medium: maxWidth ?? SimResponsiveMaxWidth.text,
          expanded: maxWidth ?? SimResponsiveMaxWidth.conversation,
          large: maxWidth ?? SimResponsiveMaxWidth.page,
        ),
        child: Padding(
          padding: padding ?? SimResponsive.pagePaddingFor(width),
          child: child,
        ),
      ),
    );

    if (!includeSafeArea) return content;
    return SafeArea(child: content);
  }
}

class SimConstrainedContent extends StatelessWidget {
  const SimConstrainedContent({required this.child, this.maxWidth, super.key});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? SimResponsive.contentMaxWidthFor(width),
        ),
        child: child,
      ),
    );
  }
}

class SimResponsiveSurface extends StatelessWidget {
  const SimResponsiveSurface({
    required this.child,
    this.maxWidth,
    this.padding,
    super.key,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final palette = SimThemeScope.paletteOf(context);
    return SimConstrainedContent(
      maxWidth: maxWidth ?? SimResponsive.cardMaxWidthFor(width),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(SimRadius.lg),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: padding ?? SimResponsive.cardPaddingFor(width),
          child: child,
        ),
      ),
    );
  }
}

class SimResponsiveButtonStyle {
  const SimResponsiveButtonStyle._();

  static ButtonStyle filled(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return FilledButton.styleFrom(
      minimumSize: SimResponsive.buttonMinimumSizeFor(width),
      padding: SimResponsive.buttonPaddingFor(width),
      textStyle: SimTypography.action,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SimRadius.lg),
      ),
    );
  }

  static ButtonStyle outlined(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return OutlinedButton.styleFrom(
      minimumSize: SimResponsive.buttonMinimumSizeFor(width),
      padding: SimResponsive.buttonPaddingFor(width),
      textStyle: SimTypography.action,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SimRadius.lg),
      ),
    );
  }
}
