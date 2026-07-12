import 'dart:math' as math;

import 'blueprint_prompt.dart';

enum PedagogicalVisualRole {
  primaryConcept,
  supportingContext,
  attention,
  critical,
  definition,
  neutral,
}

class PedagogicalVisualPalette {
  const PedagogicalVisualPalette({
    required this.background,
    required this.surface,
    required this.text,
    required this.mutedText,
    required this.connector,
    required this.border,
    required this.primaryConcept,
    required this.primaryConceptFill,
    required this.supportingContext,
    required this.supportingContextFill,
    required this.attention,
    required this.attentionFill,
    required this.critical,
    required this.criticalFill,
    required this.definition,
    required this.definitionFill,
    required this.neutral,
    required this.neutralFill,
  });

  factory PedagogicalVisualPalette.fromColorLegend(
    List<BlueprintColorLegendItem> legend,
  ) {
    var palette = standard;
    for (final item in legend) {
      final role = pedagogicalRoleFromLegendLabel(item.label);
      if (role == null || !isSafePedagogicalSurfaceColor(item.color)) {
        continue;
      }
      palette = palette.copyWithRoleFill(role, item.color.toUpperCase());
    }
    return palette;
  }

  static const standard = PedagogicalVisualPalette(
    background: '#FFFFFF',
    surface: '#F8FAFC',
    text: '#0F172A',
    mutedText: '#475569',
    connector: '#334155',
    border: '#1E293B',
    primaryConcept: '#16A34A',
    primaryConceptFill: '#DCFCE7',
    supportingContext: '#0284C7',
    supportingContextFill: '#E0F2FE',
    attention: '#D97706',
    attentionFill: '#FEF3C7',
    critical: '#DC2626',
    criticalFill: '#FEE2E2',
    definition: '#7C3AED',
    definitionFill: '#F3E8FF',
    neutral: '#64748B',
    neutralFill: '#F1F5F9',
  );

  final String background;
  final String surface;
  final String text;
  final String mutedText;
  final String connector;
  final String border;
  final String primaryConcept;
  final String primaryConceptFill;
  final String supportingContext;
  final String supportingContextFill;
  final String attention;
  final String attentionFill;
  final String critical;
  final String criticalFill;
  final String definition;
  final String definitionFill;
  final String neutral;
  final String neutralFill;

  String fillFor(PedagogicalVisualRole role) {
    switch (role) {
      case PedagogicalVisualRole.primaryConcept:
        return primaryConceptFill;
      case PedagogicalVisualRole.supportingContext:
        return supportingContextFill;
      case PedagogicalVisualRole.attention:
        return attentionFill;
      case PedagogicalVisualRole.critical:
        return criticalFill;
      case PedagogicalVisualRole.definition:
        return definitionFill;
      case PedagogicalVisualRole.neutral:
        return neutralFill;
    }
  }

  String strokeFor(PedagogicalVisualRole role) {
    switch (role) {
      case PedagogicalVisualRole.primaryConcept:
        return primaryConcept;
      case PedagogicalVisualRole.supportingContext:
        return supportingContext;
      case PedagogicalVisualRole.attention:
        return attention;
      case PedagogicalVisualRole.critical:
        return critical;
      case PedagogicalVisualRole.definition:
        return definition;
      case PedagogicalVisualRole.neutral:
        return neutral;
    }
  }

  PedagogicalVisualPalette copyWithRoleFill(
    PedagogicalVisualRole role,
    String color,
  ) {
    switch (role) {
      case PedagogicalVisualRole.primaryConcept:
        return copyWith(primaryConceptFill: color);
      case PedagogicalVisualRole.supportingContext:
        return copyWith(supportingContextFill: color);
      case PedagogicalVisualRole.attention:
        return copyWith(attentionFill: color);
      case PedagogicalVisualRole.critical:
        return copyWith(criticalFill: color);
      case PedagogicalVisualRole.definition:
        return copyWith(definitionFill: color);
      case PedagogicalVisualRole.neutral:
        return copyWith(neutralFill: color);
    }
  }

  PedagogicalVisualPalette copyWith({
    String? background,
    String? surface,
    String? text,
    String? mutedText,
    String? connector,
    String? border,
    String? primaryConcept,
    String? primaryConceptFill,
    String? supportingContext,
    String? supportingContextFill,
    String? attention,
    String? attentionFill,
    String? critical,
    String? criticalFill,
    String? definition,
    String? definitionFill,
    String? neutral,
    String? neutralFill,
  }) {
    return PedagogicalVisualPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      mutedText: mutedText ?? this.mutedText,
      connector: connector ?? this.connector,
      border: border ?? this.border,
      primaryConcept: primaryConcept ?? this.primaryConcept,
      primaryConceptFill: primaryConceptFill ?? this.primaryConceptFill,
      supportingContext: supportingContext ?? this.supportingContext,
      supportingContextFill:
          supportingContextFill ?? this.supportingContextFill,
      attention: attention ?? this.attention,
      attentionFill: attentionFill ?? this.attentionFill,
      critical: critical ?? this.critical,
      criticalFill: criticalFill ?? this.criticalFill,
      definition: definition ?? this.definition,
      definitionFill: definitionFill ?? this.definitionFill,
      neutral: neutral ?? this.neutral,
      neutralFill: neutralFill ?? this.neutralFill,
    );
  }
}

PedagogicalVisualRole? pedagogicalRoleFromLegendLabel(String label) {
  final normalized = label.toLowerCase();
  if (_hasAny(normalized, const [
    'principal',
    'main',
    'primary',
    'conceito principal',
    'ideia central',
  ])) {
    return PedagogicalVisualRole.primaryConcept;
  }
  if (_hasAny(normalized, const [
    'apoio',
    'contexto',
    'complementar',
    'support',
    'context',
  ])) {
    return PedagogicalVisualRole.supportingContext;
  }
  if (_hasAny(normalized, const [
    'atenção',
    'atencao',
    'foco',
    'importante',
    'attention',
    'focus',
  ])) {
    return PedagogicalVisualRole.attention;
  }
  if (_hasAny(normalized, const [
    'erro',
    'exceção',
    'excecao',
    'risco',
    'crítico',
    'critico',
    'contraste',
    'error',
    'risk',
    'critical',
  ])) {
    return PedagogicalVisualRole.critical;
  }
  if (_hasAny(normalized, const [
    'definição',
    'definicao',
    'termo-chave',
    'termo chave',
    'conceitual',
    'definition',
    'keyword',
  ])) {
    return PedagogicalVisualRole.definition;
  }
  if (_hasAny(normalized, const [
    'neutro',
    'estrutura',
    'eixo',
    'base',
    'secundário',
    'secundario',
    'neutral',
    'axis',
    'structure',
  ])) {
    return PedagogicalVisualRole.neutral;
  }
  return null;
}

bool isSafePedagogicalSurfaceColor(String color) {
  if (!_isHexColor(color)) return false;
  final textContrast = contrastRatio(
    color,
    PedagogicalVisualPalette.standard.text,
  );
  final backgroundContrast = contrastRatio(
    color,
    PedagogicalVisualPalette.standard.background,
  );
  return textContrast >= 4.5 && backgroundContrast >= 1.2;
}

double contrastRatio(String first, String second) {
  final a = _relativeLuminance(first);
  final b = _relativeLuminance(second);
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}

bool _hasAny(String text, List<String> needles) {
  return needles.any(text.contains);
}

bool _isHexColor(String value) {
  return RegExp(r'^#[0-9A-F]{6}$', caseSensitive: false).hasMatch(value);
}

double _relativeLuminance(String color) {
  final r = _linearRgb(int.parse(color.substring(1, 3), radix: 16) / 255);
  final g = _linearRgb(int.parse(color.substring(3, 5), radix: 16) / 255);
  final b = _linearRgb(int.parse(color.substring(5, 7), radix: 16) / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _linearRgb(double channel) {
  if (channel <= 0.03928) return channel / 12.92;
  final normalized = (channel + 0.055) / 1.055;
  return math.pow(normalized, 2.4).toDouble();
}
