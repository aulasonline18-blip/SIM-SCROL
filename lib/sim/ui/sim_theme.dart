import 'package:flutter/material.dart';

class SimPalette {
  const SimPalette({
    required this.dark,
    required this.background,
    required this.frame,
    required this.surface,
    required this.surfaceSoft,
    required this.text,
    required this.muted,
    required this.border,
    required this.primary,
    required this.onPrimary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.disabled,
    required this.focus,
    required this.shadow,
  });

  final bool dark;
  final Color background;
  final Color frame;
  final Color surface;
  final Color surfaceSoft;
  final Color text;
  final Color muted;
  final Color border;
  final Color primary;
  final Color onPrimary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color disabled;
  final Color focus;
  final Color shadow;

  static const light = SimPalette(
    dark: false,
    background: Colors.white,
    frame: Color(0xFF111827),
    surface: Colors.white,
    surfaceSoft: Color(0xFFF9FAFB),
    text: Color(0xFF111827),
    muted: Color(0xFF6B7280),
    border: Color(0xFFD1D5DB),
    primary: Color(0xFF111827),
    onPrimary: Colors.white,
    success: Color(0xFF166534),
    warning: Color(0xFF854D0E),
    danger: Color(0xFFB91C1C),
    disabled: Color(0xFF6B7280),
    focus: Color(0xFF2563EB),
    shadow: Color(0x2E111827),
  );

  static const darkMode = SimPalette(
    dark: true,
    background: Color(0xFF05070D),
    frame: Color(0xFF000000),
    surface: Color(0xFF0F172A),
    surfaceSoft: Color(0xFF111827),
    text: Color(0xFFF8FAFC),
    muted: Color(0xFFCBD5E1),
    border: Color(0xFF334155),
    primary: Color(0xFFE5E7EB),
    onPrimary: Color(0xFF020617),
    success: Color(0xFF86EFAC),
    warning: Color(0xFFFDE68A),
    danger: Color(0xFFFCA5A5),
    disabled: Color(0xFF94A3B8),
    focus: Color(0xFF93C5FD),
    shadow: Color(0x99000000),
  );
}

class SimThemeScope extends InheritedWidget {
  const SimThemeScope({
    required this.darkMode,
    required this.onToggleDarkMode,
    required super.child,
    super.key,
  });

  final bool darkMode;
  final VoidCallback onToggleDarkMode;

  static SimThemeScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SimThemeScope>();
  }

  static SimThemeScope of(BuildContext context) {
    return maybeOf(context) ??
        const SimThemeScope(
          darkMode: false,
          onToggleDarkMode: _noop,
          child: SizedBox.shrink(),
        );
  }

  static SimPalette paletteOf(BuildContext context) {
    return of(context).darkMode ? SimPalette.darkMode : SimPalette.light;
  }

  @override
  bool updateShouldNotify(SimThemeScope oldWidget) {
    return darkMode != oldWidget.darkMode ||
        onToggleDarkMode != oldWidget.onToggleDarkMode;
  }
}

void _noop() {}
