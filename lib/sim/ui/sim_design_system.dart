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
  static const double xxxl = 40;
  static const double touchGap = SimResponsiveDensity.touchGap;
}

class SimRadius {
  const SimRadius._();

  static const double sm = 8;
  static const double md = 10;
  static const double lg = 12;
  static const double xl = 16;
  static const double pill = 999;
}

class SimTouch {
  const SimTouch._();

  static const double wcagMinimum = 24;
  static const double recommended = SimResponsiveDensity.touchMin;
  static const double min = SimResponsiveDensity.touchMin;
  static const double icon = 44;
  static const double spacing = SimSpacing.touchGap;
}

class SimTypography {
  const SimTypography._();

  static const TextStyle lessonBody = TextStyle(
    color: simDark,
    fontSize: 16,
    height: 1.5,
  );

  static const TextStyle title = TextStyle(
    color: simDark,
    fontSize: 22,
    height: 1.22,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle subtitle = TextStyle(
    color: simMuted,
    fontSize: 15,
    height: 1.38,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = lessonBody;

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

  static const TextStyle option = TextStyle(
    color: simDark,
    fontSize: 16,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle feedback = TextStyle(
    color: simDark,
    fontSize: 16,
    height: 1.38,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle label = TextStyle(
    color: simDark,
    fontSize: 14,
    height: 1.35,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle meta = TextStyle(
    color: simMuted,
    fontFamily: kMono,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static const TextStyle caption = TextStyle(
    color: simMuted,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle muted = TextStyle(
    color: simMuted,
    fontSize: 14,
    height: 1.4,
  );

  static const TextStyle emphasis = TextStyle(
    color: simDark,
    fontSize: 16,
    height: 1.45,
    fontWeight: FontWeight.w700,
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
    final foreground = switch (tone) {
      SimActionTone.primary => palette.onPrimary,
      SimActionTone.secondary => palette.text,
      SimActionTone.danger => palette.onPrimary,
    };
    final background = switch (tone) {
      SimActionTone.primary => palette.primary,
      SimActionTone.secondary => palette.surface,
      SimActionTone.danger => palette.danger,
    };
    final side = tone == SimActionTone.primary
        ? BorderSide(color: palette.primary)
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
          elevation: enabled && tone == SimActionTone.primary ? 1 : 0,
          backgroundColor: enabled ? background : palette.surfaceSoft,
          foregroundColor: enabled ? foreground : simMuted,
          disabledBackgroundColor: palette.surfaceSoft,
          disabledForegroundColor: palette.muted,
          side: side,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SimRadius.lg),
          ),
          textStyle: SimTypography.action,
          shadowColor: palette.shadow,
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

enum SimSurfaceTone {
  normal,
  soft,
  elevated,
  selected,
  success,
  warning,
  danger,
}

class SimLearningSurface extends StatelessWidget {
  const SimLearningSurface({
    required this.child,
    this.tone = SimSurfaceTone.normal,
    this.padding,
    this.margin,
    this.width,
    this.borderWidth = 1,
    super.key,
  });

  final Widget child;
  final SimSurfaceTone tone;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final colors = _surfaceColors(palette, tone);
    return Container(
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(SimRadius.xl),
        border: Border.all(color: colors.border, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: palette.dark ? 0.28 : 0.08),
            blurRadius: tone == SimSurfaceTone.elevated ? 18 : 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(SimSpacing.lg),
        child: child,
      ),
    );
  }
}

class SimElevatedSurface extends SimLearningSurface {
  const SimElevatedSurface({
    required super.child,
    super.padding,
    super.margin,
    super.width,
    super.key,
  }) : super(tone: SimSurfaceTone.elevated);
}

class SimStatusSurface extends StatelessWidget {
  const SimStatusSurface({
    required this.child,
    required this.tone,
    this.icon,
    this.padding,
    super.key,
  });

  final Widget child;
  final SimSurfaceTone tone;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final colors = _surfaceColors(palette, tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(SimRadius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding:
            padding ??
            const EdgeInsets.symmetric(
              horizontal: SimSpacing.md,
              vertical: SimSpacing.sm,
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: colors.foreground),
              const SizedBox(width: SimSpacing.xs),
            ],
            Flexible(
              child: DefaultTextStyle.merge(
                style: TextStyle(color: colors.foreground, height: 1.35),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SimProgressRail extends StatelessWidget {
  const SimProgressRail({
    required this.value,
    this.height = 7,
    this.semanticLabel,
    super.key,
  });

  final double value;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final clamped = value.clamp(0.0, 1.0);
    final rail = ClipRRect(
      borderRadius: BorderRadius.circular(SimRadius.pill),
      child: ColoredBox(
        color: palette.surfaceSoft,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: clamped,
            child: SizedBox(
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.primary,
                  borderRadius: BorderRadius.circular(SimRadius.pill),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()}%',
      child: SizedBox(height: height, width: double.infinity, child: rail),
    );
  }
}

class SimSectionHeader extends StatelessWidget {
  const SimSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SimTypography.title.copyWith(color: palette.text),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: SimSpacing.xs),
                Text(
                  subtitle!,
                  style: SimTypography.subtitle.copyWith(color: palette.muted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: SimSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

class _SimSurfaceColors {
  const _SimSurfaceColors({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

_SimSurfaceColors _surfaceColors(SimPalette palette, SimSurfaceTone tone) {
  return switch (tone) {
    SimSurfaceTone.normal => _SimSurfaceColors(
      background: palette.surface,
      border: palette.border,
      foreground: palette.text,
    ),
    SimSurfaceTone.soft => _SimSurfaceColors(
      background: palette.surfaceSoft,
      border: palette.border,
      foreground: palette.text,
    ),
    SimSurfaceTone.elevated => _SimSurfaceColors(
      background: palette.elevatedSurface,
      border: palette.border,
      foreground: palette.text,
    ),
    SimSurfaceTone.selected => _SimSurfaceColors(
      background: palette.selectedSurface,
      border: palette.primary,
      foreground: palette.text,
    ),
    SimSurfaceTone.success => _SimSurfaceColors(
      background: palette.successSurface,
      border: palette.success,
      foreground: palette.success,
    ),
    SimSurfaceTone.warning => _SimSurfaceColors(
      background: palette.warningSurface,
      border: palette.warning,
      foreground: palette.warning,
    ),
    SimSurfaceTone.danger => _SimSurfaceColors(
      background: palette.dangerSurface,
      border: palette.danger,
      foreground: palette.danger,
    ),
  };
}
