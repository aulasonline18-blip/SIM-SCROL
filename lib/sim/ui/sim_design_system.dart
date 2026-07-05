import 'package:flutter/material.dart';

import '../../core/utils/sim_constants.dart';
import 'responsive/sim_responsive.dart';
import 'sim_theme.dart';

class SimBreakpoints {
  const SimBreakpoints._();

  static const double compactMax = SimResponsiveBreakpoints.medium - 1;
  static const double tabletMin = SimResponsiveBreakpoints.medium;
  static const double wideMin = SimResponsiveBreakpoints.expanded;

  static bool isTablet(double width) => width >= tabletMin;
  static bool isWide(double width) => width >= wideMin;

  static double frameMaxWidth(double width) =>
      SimResponsive.frameMaxWidthFor(width);

  static double learningMaxWidth(double width) =>
      SimResponsive.contentMaxWidthFor(
        width,
        medium: 640,
        expanded: SimResponsiveMaxWidth.conversation,
      );

  static EdgeInsets pagePadding(double width) =>
      SimResponsive.pagePaddingFor(width);

  static EdgeInsets classroomScrollPadding(double width) {
    final horizontal = isTablet(width) ? 28.0 : 16.0;
    return EdgeInsets.fromLTRB(horizontal, 112, horizontal, 128);
  }
}

class SimSpacing {
  const SimSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

class SimRadius {
  const SimRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 18;
}

class SimTouch {
  const SimTouch._();

  static const double min = 48;
  static const double icon = 44;
}

class SimTypography {
  const SimTypography._();

  static const TextStyle lessonBody = TextStyle(
    color: simDark,
    fontSize: 16,
    height: 1.5,
  );

  static const TextStyle lessonQuestion = TextStyle(
    color: simDark,
    fontSize: 16,
    height: 1.42,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle action = TextStyle(
    color: simDark,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle meta = TextStyle(
    color: simMuted,
    fontFamily: kMono,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );
}

class SimResponsiveCenter extends StatelessWidget {
  const SimResponsiveCenter({
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
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? SimBreakpoints.learningMaxWidth(width),
        ),
        child: Padding(
          padding: padding ?? SimBreakpoints.pagePadding(width),
          child: child,
        ),
      ),
    );
  }
}

enum SimActionTone { primary, secondary, danger }

class SimActionButton extends StatelessWidget {
  const SimActionButton({
    required this.label,
    required this.onPressed,
    this.tone = SimActionTone.primary,
    this.icon,
    this.height = 54,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final SimActionTone tone;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final enabled = onPressed != null;
    final foreground = tone == SimActionTone.danger
        ? palette.onPrimary
        : palette.text;
    final background = switch (tone) {
      SimActionTone.primary => palette.surface,
      SimActionTone.secondary => palette.surface,
      SimActionTone.danger => palette.primary,
    };
    final side = tone == SimActionTone.primary
        ? BorderSide(color: palette.primary, width: 1.1)
        : BorderSide(color: palette.border);

    final child = icon == null
        ? Text(label, textAlign: TextAlign.center)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: SimSpacing.xs),
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          );

    return SizedBox(
      width: double.infinity,
      height: height.clamp(SimTouch.min, 72),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: enabled ? background : palette.surfaceSoft,
          foregroundColor: enabled ? foreground : simMuted,
          disabledBackgroundColor: palette.surfaceSoft,
          disabledForegroundColor: palette.muted,
          side: side,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SimRadius.lg),
          ),
          textStyle: SimTypography.action,
        ),
        child: child,
      ),
    );
  }
}

class SimIconAction extends StatelessWidget {
  const SimIconAction({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.size = SimTouch.icon,
    this.iconSize = 18,
    this.child,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      excludeSemantics: true,
      label: semanticLabel,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(SimRadius.md),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(SimRadius.md),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SimRadius.md),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: child ?? Icon(icon, color: palette.text, size: iconSize),
          ),
        ),
      ),
    );
  }
}

class SimTextAction extends StatelessWidget {
  const SimTextAction({
    required this.label,
    required this.onPressed,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel ?? label,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: palette.muted,
          minimumSize: const Size(SimTouch.min, SimTouch.min),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
