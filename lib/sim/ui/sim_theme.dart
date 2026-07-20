import 'package:flutter/material.dart';

class SimPalette {
  const SimPalette({
    required this.dark,
    required this.background,
    required this.frame,
    required this.surface,
    required this.surfaceSoft,
    required this.elevatedSurface,
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
    required this.selectedSurface,
    required this.successSurface,
    required this.warningSurface,
    required this.dangerSurface,
  });

  final bool dark;
  final Color background;
  final Color frame;
  final Color surface;
  final Color surfaceSoft;
  final Color elevatedSurface;
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
  final Color selectedSurface;
  final Color successSurface;
  final Color warningSurface;
  final Color dangerSurface;

  static const light = SimPalette(
    dark: false,
    background: Color(0xFFFCFBF7),
    frame: Color(0xFFF4F7FB),
    surface: Colors.white,
    surfaceSoft: Color(0xFFF6F8FB),
    elevatedSurface: Color(0xFFFFFFFF),
    text: Color(0xFF111820),
    muted: Color(0xFF647084),
    border: Color(0xFFDCE3EC),
    primary: Color(0xFF2563EB),
    onPrimary: Colors.white,
    success: Color(0xFF15803D),
    warning: Color(0xFFA16207),
    danger: Color(0xFFDC4A3D),
    disabled: Color(0xFF94A3B8),
    focus: Color(0xFF1D4ED8),
    shadow: Color(0x1A0F172A),
    selectedSurface: Color(0xFFEFF6FF),
    successSurface: Color(0xFFEAFBF0),
    warningSurface: Color(0xFFFFF7DF),
    dangerSurface: Color(0xFFFFF0ED),
  );

  static const darkMode = SimPalette(
    dark: true,
    background: Color(0xFF0D1117),
    frame: Color(0xFF111827),
    surface: Color(0xFF151C27),
    surfaceSoft: Color(0xFF1B2431),
    elevatedSurface: Color(0xFF202B3A),
    text: Color(0xFFF8FAFC),
    muted: Color(0xFFB7C4D6),
    border: Color(0xFF334155),
    primary: Color(0xFF60A5FA),
    onPrimary: Color(0xFF07111F),
    success: Color(0xFF86EFAC),
    warning: Color(0xFFFCD34D),
    danger: Color(0xFFFCA5A5),
    disabled: Color(0xFF78869A),
    focus: Color(0xFF93C5FD),
    shadow: Color(0x73000000),
    selectedSurface: Color(0xFF172A46),
    successSurface: Color(0xFF123224),
    warningSurface: Color(0xFF342A13),
    dangerSurface: Color(0xFF3A1C1C),
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
