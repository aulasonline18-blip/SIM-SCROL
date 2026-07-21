part of '../dopamine_ready_window_engine.dart';

class DopamineWindowItem {
  const DopamineWindowItem({
    required this.text,
    this.marker,
    this.isReview = false,
    this.reviewLayer,
  });

  final String text;
  final String? marker;
  final bool isReview;
  final LessonLayer? reviewLayer;
}

class DopamineReadySlot {
  const DopamineReadySlot({
    required this.slot,
    required this.itemIdx,
    required this.marker,
    required this.layer,
    required this.params,
    this.expectedKey,
  });

  final String slot;
  final int itemIdx;
  final String? marker;
  final LessonLayer layer;
  final CompleteLessonParams params;
  final String? expectedKey;
}

class WindowPosition {
  const WindowPosition({
    required this.itemId,
    required this.layer,
    this.globalItemNumber,
    this.marker,
  });

  final String itemId;
  final String layer;
  final int? globalItemNumber;
  final String? marker;
}

class ReadyWindowPlanner {
  const ReadyWindowPlanner();

  List<({int offset, int idx, DopamineWindowItem item, LessonLayer layer})>
  buildDopamineWindowPlan({
    required int fromIdx,
    required LessonLayer layer,
    required List<DopamineWindowItem> items,
    int maxSlots = localLessonTraySize,
  }) {
    if (fromIdx < 0 || fromIdx >= items.length) return const [];
    final first = items[fromIdx];
    final firstLayer = first.isReview
        ? first.reviewLayer ?? LessonLayer.l1
        : layer;
    final window =
        <({int offset, int idx, DopamineWindowItem item, LessonLayer layer})>[
          (offset: 0, idx: fromIdx, item: first, layer: firstLayer),
        ];
    var cursor = (idx: fromIdx, layer: firstLayer);
    while (window.length < maxSlots) {
      final next = nextSlot(cursor.idx, cursor.layer, items);
      if (next == null || next.itemIdx < 0 || next.itemIdx >= items.length) {
        break;
      }
      final item = items[next.itemIdx];
      window.add((
        offset: window.length,
        idx: next.itemIdx,
        item: item,
        layer: next.layer,
      ));
      cursor = (idx: next.itemIdx, layer: next.layer);
    }
    return window;
  }

  List<DopamineReadySlot> buildDopamineReadySlots({
    required String lessonLocalId,
    required String source,
    required List<DopamineWindowItem> items,
    required int currentItemIdx,
    required LessonLayer currentLayer,
    required CompleteLessonParams Function(
      DopamineWindowItem item,
      LessonLayer layer,
    )
    buildParams,
    int maxSlots = localLessonTraySize,
  }) {
    final slots = <DopamineReadySlot>[];
    final planned = buildDopamineWindowPlan(
      fromIdx: currentItemIdx < 0 ? 0 : currentItemIdx,
      layer: currentLayer,
      items: items,
      maxSlots: maxSlots,
    );
    for (final plan in planned) {
      final params = buildParams(plan.item, plan.layer);
      slots.add(
        DopamineReadySlot(
          slot: slotName(plan.offset),
          itemIdx: plan.idx,
          marker: plan.item.marker,
          layer: plan.layer,
          params: params,
          expectedKey: lessonKeyFor(params),
        ),
      );
    }
    return slots;
  }

  List<WindowPosition> calculateNextPositions({
    required String currentItemId,
    required String currentLayer,
    required int windowSize,
    required int globalTotalItems,
  }) {
    final itemNumber = int.tryParse(
      currentItemId.replaceAll(RegExp(r'\D'), ''),
    );
    if (itemNumber == null || itemNumber < 1 || itemNumber > globalTotalItems) {
      return const [];
    }
    var cursor = WindowPosition(
      itemId: currentItemId,
      layer: currentLayer,
      globalItemNumber: itemNumber,
      marker: currentItemId,
    );
    final positions = <WindowPosition>[cursor];
    while (positions.length < windowSize) {
      final next = nextPosition(cursor);
      if (!isPositionValid(next, globalTotalItems)) break;
      positions.add(next);
      cursor = next;
    }
    return positions;
  }

  WindowPosition nextPosition(WindowPosition current) {
    final number = current.globalItemNumber ?? 1;
    final layer = current.layer.toUpperCase();
    if (layer == 'L1') {
      return WindowPosition(
        itemId: current.itemId,
        layer: 'L2',
        globalItemNumber: number,
        marker: current.marker,
      );
    }
    if (layer == 'L2') {
      return WindowPosition(
        itemId: current.itemId,
        layer: 'L3',
        globalItemNumber: number,
        marker: current.marker,
      );
    }
    final nextNumber = number + 1;
    return WindowPosition(
      itemId: 'M$nextNumber',
      layer: 'L1',
      globalItemNumber: nextNumber,
      marker: 'M$nextNumber',
    );
  }

  bool isPositionValid(WindowPosition position, int globalTotalItems) {
    final number = position.globalItemNumber;
    return number != null && number >= 1 && number <= globalTotalItems;
  }

  String slotName(int index) {
    const hot = ['A', 'B', 'C', 'D'];
    if (index >= 0 && index < hot.length) return hot[index];
    return 'W${index + 1}';
  }

  ({int itemIdx, LessonLayer layer})? nextSlot(
    int itemIdx,
    LessonLayer layer,
    List<DopamineWindowItem> items,
  ) {
    final item = items[itemIdx];
    if (!item.isReview && layer != LessonLayer.l3) {
      return (
        itemIdx: itemIdx,
        layer: layer == LessonLayer.l1 ? LessonLayer.l2 : LessonLayer.l3,
      );
    }
    final nextIdx = itemIdx + 1;
    if (nextIdx >= items.length) return null;
    final next = items[nextIdx];
    return (itemIdx: nextIdx, layer: next.reviewLayer ?? LessonLayer.l1);
  }
}
