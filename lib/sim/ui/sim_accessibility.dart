import 'package:flutter/material.dart';

import 'sim_i18n.dart';
import 'sim_theme.dart';

enum SimVisualState { success, warning, danger, disabled, focus }

class SimContrast {
  const SimContrast._();

  static const double text = 4.5;
  static const double largeText = 3;
  static const double nonText = 3;

  static double ratio(Color foreground, Color background) {
    final lighter = foreground.computeLuminance() + 0.05;
    final darker = background.computeLuminance() + 0.05;
    return lighter > darker ? lighter / darker : darker / lighter;
  }

  static bool meets(
    Color foreground,
    Color background, {
    double minimum = text,
  }) {
    return ratio(foreground, background) >= minimum;
  }
}

class SimTextScale {
  const SimTextScale._();

  static const double certificationScale = 2;

  static bool supports(TextScaler scaler, {double baseFontSize = 16}) {
    return scaler.scale(baseFontSize) >= baseFontSize * certificationScale;
  }
}

class SimStateVisualToken {
  const SimStateVisualToken({
    required this.state,
    required this.foreground,
    required this.background,
    required this.border,
    required this.icon,
    required this.semanticLabel,
    this.borderWidth = 1.5,
  });

  final SimVisualState state;
  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;
  final String semanticLabel;
  final double borderWidth;

  bool get includesNonColorCue =>
      semanticLabel.isNotEmpty && icon.codePoint != 0 && borderWidth > 0;
}

class SimAccessibility {
  const SimAccessibility._();

  static SimStateVisualToken stateToken(
    SimVisualState state,
    SimPalette palette,
  ) {
    return switch (state) {
      SimVisualState.success => SimStateVisualToken(
        state: state,
        foreground: palette.success,
        background: palette.successSurface,
        border: palette.success,
        icon: Icons.check_circle_outline,
        semanticLabel: t('a11y_success'),
      ),
      SimVisualState.warning => SimStateVisualToken(
        state: state,
        foreground: palette.warning,
        background: palette.warningSurface,
        border: palette.warning,
        icon: Icons.warning_amber_rounded,
        semanticLabel: t('a11y_warning'),
      ),
      SimVisualState.danger => SimStateVisualToken(
        state: state,
        foreground: palette.danger,
        background: palette.dangerSurface,
        border: palette.danger,
        icon: Icons.error_outline,
        semanticLabel: t('a11y_error'),
      ),
      SimVisualState.disabled => SimStateVisualToken(
        state: state,
        foreground: palette.disabled,
        background: palette.surfaceSoft,
        border: palette.disabled,
        icon: Icons.block,
        semanticLabel: t('a11y_unavailable'),
      ),
      SimVisualState.focus => SimStateVisualToken(
        state: state,
        foreground: palette.focus,
        background: palette.selectedSurface,
        border: palette.focus,
        icon: Icons.radio_button_checked,
        semanticLabel: t('a11y_focus'),
        borderWidth: 2,
      ),
    };
  }

  static List<SimStateVisualToken> criticalStateTokens(SimPalette palette) {
    return SimVisualState.values
        .map((state) => stateToken(state, palette))
        .toList(growable: false);
  }
}
