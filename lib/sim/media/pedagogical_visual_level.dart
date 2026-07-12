enum PedagogicalVisualLevel {
  child,
  fundamental,
  highSchool,
  examPrep,
  advanced,
}

class PedagogicalVisualLevelProfile {
  const PedagogicalVisualLevelProfile({
    required this.level,
    required this.label,
    required this.maxPrimaryElements,
    required this.detailSlots,
    required this.maxTextLines,
    required this.labelMaxChars,
    required this.connectorDensity,
    required this.showDetailStrip,
  });

  final PedagogicalVisualLevel level;
  final String label;
  final int maxPrimaryElements;
  final int detailSlots;
  final int maxTextLines;
  final int labelMaxChars;
  final int connectorDensity;
  final bool showDetailStrip;

  static const child = PedagogicalVisualLevelProfile(
    level: PedagogicalVisualLevel.child,
    label: 'Infantil',
    maxPrimaryElements: 2,
    detailSlots: 0,
    maxTextLines: 1,
    labelMaxChars: 11,
    connectorDensity: 1,
    showDetailStrip: false,
  );

  static const fundamental = PedagogicalVisualLevelProfile(
    level: PedagogicalVisualLevel.fundamental,
    label: 'Fundamental',
    maxPrimaryElements: 3,
    detailSlots: 1,
    maxTextLines: 2,
    labelMaxChars: 13,
    connectorDensity: 2,
    showDetailStrip: true,
  );

  static const highSchool = PedagogicalVisualLevelProfile(
    level: PedagogicalVisualLevel.highSchool,
    label: 'Ensino Médio',
    maxPrimaryElements: 4,
    detailSlots: 2,
    maxTextLines: 2,
    labelMaxChars: 16,
    connectorDensity: 3,
    showDetailStrip: true,
  );

  static const examPrep = PedagogicalVisualLevelProfile(
    level: PedagogicalVisualLevel.examPrep,
    label: 'Vestibular',
    maxPrimaryElements: 5,
    detailSlots: 3,
    maxTextLines: 2,
    labelMaxChars: 18,
    connectorDensity: 4,
    showDetailStrip: true,
  );

  static const advanced = PedagogicalVisualLevelProfile(
    level: PedagogicalVisualLevel.advanced,
    label: 'Avançado',
    maxPrimaryElements: 6,
    detailSlots: 4,
    maxTextLines: 3,
    labelMaxChars: 20,
    connectorDensity: 5,
    showDetailStrip: true,
  );

  static const fallback = highSchool;

  static PedagogicalVisualLevelProfile fromAcademicLevel(String? rawLevel) {
    final text = _normalize(rawLevel);
    if (text.isEmpty) return fallback;
    if (_containsAny(text, const [
      'infantil',
      'pre escola',
      'pre-escola',
      'pré escola',
      'pré-escola',
      'crianca',
      'criança',
      'kids',
      'child',
    ])) {
      return child;
    }
    if (_containsAny(text, const [
      'fundamental',
      'basico',
      'básico',
      'elementary',
      'middle school',
    ])) {
      return fundamental;
    }
    if (_containsAny(text, const [
      'vestibular',
      'enem',
      'pre vestibular',
      'pré vestibular',
      'pre-vestibular',
      'pré-vestibular',
      'exam',
      'sat',
    ])) {
      return examPrep;
    }
    if (_containsAny(text, const [
      'universitario',
      'universitário',
      'superior',
      'graduacao',
      'graduação',
      'pos graduacao',
      'pós graduação',
      'advanced',
      'college',
      'university',
    ])) {
      return advanced;
    }
    if (_containsAny(text, const [
      'medio',
      'médio',
      'ensino medio',
      'ensino médio',
      'high school',
    ])) {
      return highSchool;
    }
    return fallback;
  }

  int primaryCountFor(int requested) {
    if (requested <= 0) return 0;
    final capped = requested < maxPrimaryElements
        ? requested
        : maxPrimaryElements;
    return capped < 1 ? 1 : capped;
  }
}

bool _containsAny(String text, List<String> values) {
  return values.any(text.contains);
}

String _normalize(String? value) {
  return (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}
