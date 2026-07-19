import '../state/student_learning_state.dart';

class PlacementGateItem {
  const PlacementGateItem({
    required this.marker,
    required this.itemIdx,
    required this.text,
    required this.reason,
  });

  final String marker;
  final int itemIdx;
  final String text;
  final String reason;
}

class PlacementPlan {
  const PlacementPlan({
    required this.gates,
    required this.strategy,
    required this.maxQuestions,
    required this.waitingForCurriculum,
  });

  final List<PlacementGateItem> gates;
  final String strategy;
  final int maxQuestions;
  final bool waitingForCurriculum;
}

class PlacementPlanEngine {
  const PlacementPlanEngine();

  PlacementPlan build(List<CurriculumItem> items) {
    if (items.isEmpty) {
      return const PlacementPlan(
        gates: [],
        strategy: 'waiting_curriculum',
        maxQuestions: 0,
        waitingForCurriculum: true,
      );
    }
    if (items.length <= 5) {
      return PlacementPlan(
        gates: _gatesFor(items, List.generate(items.length, (index) => index)),
        strategy: 'small_ordered',
        maxQuestions: items.length.clamp(3, 5).toInt(),
        waitingForCurriculum: false,
      );
    }
    if (items.length <= 20) {
      final mid = items.length ~/ 2;
      final advanced = ((items.length - 1) * 0.75).round();
      final probes = _uniqueSorted([0, mid, advanced]);
      return PlacementPlan(
        gates: _gatesFor(items, probes).take(6).toList(growable: false),
        strategy: 'medium_boundary',
        maxQuestions: 6,
        waitingForCurriculum: false,
      );
    }
    final probes = _uniqueSorted([
      0,
      ((items.length - 1) * 0.25).round(),
      ((items.length - 1) * 0.50).round(),
      ((items.length - 1) * 0.75).round(),
    ]);
    return PlacementPlan(
      gates: _gatesFor(items, probes).take(7).toList(growable: false),
      strategy: 'large_adaptive_boundary',
      maxQuestions: 7,
      waitingForCurriculum: false,
    );
  }

  List<int> _uniqueSorted(List<int> indexes) {
    final set = <int>{};
    for (final index in indexes) {
      if (index >= 0) set.add(index);
    }
    return set.toList()..sort();
  }

  List<PlacementGateItem> _gatesFor(
    List<CurriculumItem> items,
    List<int> indexes,
  ) {
    return [
      for (final index in indexes)
        if (index >= 0 && index < items.length)
          PlacementGateItem(
            marker: items[index].marker,
            itemIdx: index,
            text: items[index].teacherText,
            reason: index == 0
                ? 'basic_gate'
                : index < items.length / 2
                ? 'early_boundary'
                : 'advanced_boundary',
          ),
    ];
  }
}
