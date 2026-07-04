class ClassroomTextScale {
  const ClassroomTextScale._();

  static const prefsKey = 'sim.classroom.text_scale.level';
  static const defaultLevel = 2;
  static const minLevel = 1;
  static const maxLevel = 5;
  static const levels = <int, double>{
    1: 0.92,
    2: 1.0,
    3: 1.12,
    4: 1.28,
    5: 1.44,
  };

  static const tabletLevels = <int, double>{
    1: 1.18,
    2: 1.32,
    3: 1.48,
    4: 1.66,
    5: 1.86,
  };

  static int normalize(int value) => value.clamp(minLevel, maxLevel);

  static double scaleFor(int level) => levels[normalize(level)]!;

  static double scaleForWidth(int level, double width) {
    final normalized = normalize(level);
    if (width >= 600) return tabletLevels[normalized]!;
    return levels[normalized]!;
  }

  static int next(int current) {
    final normalized = normalize(current);
    return normalized >= maxLevel ? minLevel : normalized + 1;
  }
}
