// ignore_for_file: prefer_initializing_formals

part of '../student_learning_state.dart';

class CurriculumItem {
  const CurriculumItem({
    required this.marker,
    required this.text,
    this.unit,
    this.title,
    this.microitemForTeacher,
    this.extra = const {},
  });

  final String marker;
  final String text;
  final String? unit;
  final String? title;
  final String? microitemForTeacher;
  final JsonMap extra;

  String get teacherText => microitemForTeacher ?? text;

  JsonMap toJson() => {
    ...extra,
    'marker': marker,
    'text': text,
    if (unit != null) 'unit': unit,
    if (title != null) 'title': title,
    if (microitemForTeacher != null)
      'microitem_for_teacher': microitemForTeacher,
  };

  factory CurriculumItem.fromJson(JsonMap json) => CurriculumItem(
    marker: (json['marker'] ?? '').toString(),
    text: (json['text'] ?? json['title'] ?? '').toString(),
    unit: _stringValue(json['unit'] ?? json['unidade']),
    title: json['title'] as String?,
    microitemForTeacher: json['microitem_for_teacher'] as String?,
    extra: JsonMap.of(json)
      ..removeWhere(
        (key, _) => {
          'marker',
          'text',
          'unit',
          'unidade',
          'title',
          'microitem_for_teacher',
        }.contains(key),
      ),
  );
}

class CurriculumGlobalPlan {
  const CurriculumGlobalPlan({
    required this.globalTotalItems,
    required this.batchStartItem,
    required this.batchEndItem,
    this.operationalBatchLimit,
    this.partNumber,
    this.partTitle,
    this.unitsCovered,
    this.unitsPending,
    int? nextGlobalItemToRequest,
    bool continuationNeeded = false,
    String? continuationInstruction,
  }) : _nextGlobalItemToRequest = nextGlobalItemToRequest,
       _continuationNeeded = continuationNeeded,
       _continuationInstruction = continuationInstruction;

  final int globalTotalItems;
  final int batchStartItem;
  final int batchEndItem;
  final int? operationalBatchLimit;
  final int? partNumber;
  final String? partTitle;
  final String? unitsCovered;
  final String? unitsPending;
  final int? _nextGlobalItemToRequest;
  final bool _continuationNeeded;
  final String? _continuationInstruction;

  bool get hasRemainingGlobalItems => globalTotalItems > batchEndItem;

  int? get nextGlobalItemToRequest {
    final next = _nextGlobalItemToRequest;
    if (next != null && next > batchEndItem) return next;
    if (hasRemainingGlobalItems) return batchEndItem + 1;
    return null;
  }

  bool get continuationNeeded => _continuationNeeded || hasRemainingGlobalItems;

  String? get continuationInstruction {
    final clean = _continuationInstruction?.trim();
    if (clean != null &&
        clean.isNotEmpty &&
        clean.toLowerCase() != 'n/a' &&
        clean != '-') {
      return clean;
    }
    final next = nextGlobalItemToRequest;
    if (!continuationNeeded || next == null) return null;
    return 'Continue a partir do item $next.';
  }

  int globalItemNumberForLocalIndex(int localIndex) {
    return batchStartItem + localIndex.clamp(0, batchSize).toInt();
  }

  int get batchSize {
    final size = batchEndItem - batchStartItem + 1;
    return size > 0 ? size : 0;
  }

  bool get isMultiPart {
    return hasRemainingGlobalItems ||
        continuationNeeded ||
        (partNumber ?? 1) > 1;
  }

  String get displayPartTitle {
    final clean = partTitle?.trim();
    if (clean != null && clean.isNotEmpty) return clean;
    final number = partNumber ?? 1;
    return 'Parte $number';
  }

  JsonMap toJson() => {
    'globalTotalItems': globalTotalItems,
    'batchStartItem': batchStartItem,
    'batchEndItem': batchEndItem,
    if (operationalBatchLimit != null)
      'operationalBatchLimit': operationalBatchLimit,
    if (partNumber != null) 'partNumber': partNumber,
    if (partTitle != null) 'partTitle': partTitle,
    if (unitsCovered != null) 'unitsCovered': unitsCovered,
    if (unitsPending != null) 'unitsPending': unitsPending,
    if (nextGlobalItemToRequest != null)
      'nextGlobalItemToRequest': nextGlobalItemToRequest,
    'continuationNeeded': continuationNeeded,
    if (continuationInstruction != null)
      'continuationInstruction': continuationInstruction,
  };

  factory CurriculumGlobalPlan.fromJson(JsonMap json, int localItemCount) {
    final globalTotal =
        _intValue(
          json['globalTotalItems'] ??
              json['global_total_items'] ??
              json['estimatedGlobalTotalItems'] ??
              json['estimated_global_total_items'],
        ) ??
        localItemCount;
    final start =
        _intValue(json['batchStartItem'] ?? json['batch_start_item']) ?? 1;
    final end =
        _intValue(json['batchEndItem'] ?? json['batch_end_item']) ??
        (start + localItemCount - 1);
    return CurriculumGlobalPlan(
      globalTotalItems: globalTotal,
      operationalBatchLimit: _intValue(
        json['operationalBatchLimit'] ?? json['operational_batch_limit'],
      ),
      batchStartItem: start,
      batchEndItem: end,
      partNumber: _intValue(json['partNumber'] ?? json['part_number']),
      partTitle: _stringValue(json['partTitle'] ?? json['part_title']),
      unitsCovered: _stringValue(json['unitsCovered'] ?? json['units_covered']),
      unitsPending: _stringValue(json['unitsPending'] ?? json['units_pending']),
      nextGlobalItemToRequest: _intValue(
        json['nextGlobalItemToRequest'] ?? json['next_global_item_to_request'],
      ),
      continuationNeeded:
          json['continuationNeeded'] == true ||
          json['continuation_needed'] == true,
      continuationInstruction: _stringValue(
        json['continuationInstruction'] ?? json['continuation_instruction'],
      ),
    );
  }
}

class StudentCurriculum {
  const StudentCurriculum({
    required this.topic,
    required this.totalItems,
    required this.generatedAt,
    required this.provisional,
    required this.items,
    this.globalPlan,
  });

  final String topic;
  final int totalItems;
  final int? generatedAt;
  final bool provisional;
  final List<CurriculumItem> items;
  final CurriculumGlobalPlan? globalPlan;

  int get displayTotalItems => globalPlan?.globalTotalItems ?? totalItems;

  int displayItemNumberForLocalIndex(int localIndex) {
    return globalPlan?.globalItemNumberForLocalIndex(localIndex) ??
        (localIndex + 1);
  }

  bool get isPartOfGlobalPlan => globalPlan?.isMultiPart == true;

  String get displayPartTitle => globalPlan?.displayPartTitle ?? '';

  JsonMap toJson() => {
    'topic': topic,
    'totalItems': totalItems,
    'generatedAt': generatedAt,
    'provisional': provisional,
    'items': items.map((item) => item.toJson()).toList(),
    if (globalPlan != null) 'globalPlan': globalPlan!.toJson(),
  };

  factory StudentCurriculum.fromJson(JsonMap json) {
    final items = (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CurriculumItem.fromJson(JsonMap.from(item)))
        .toList();
    final rawGlobalPlan =
        json['globalPlan'] ?? json['global_plan'] ?? json['curriculum_plan'];
    return StudentCurriculum(
      topic: (json['topic'] ?? '').toString(),
      totalItems: (json['totalItems'] as num?)?.toInt() ?? items.length,
      generatedAt: (json['generatedAt'] as num?)?.toInt(),
      provisional: json['provisional'] == true,
      items: items,
      globalPlan: rawGlobalPlan is Map
          ? CurriculumGlobalPlan.fromJson(
              JsonMap.from(rawGlobalPlan),
              items.length,
            )
          : null,
    );
  }
}

class StudentCurriculumStatus {
  const StudentCurriculumStatus({
    required this.status,
    required this.expansionStatus,
    required this.updatedAt,
    required this.objectiveKey,
    required this.initialCount,
    required this.totalCount,
    this.error,
  });

  final CurriculumStatusValue status;
  final CurriculumStatusValue expansionStatus;
  final String updatedAt;
  final String objectiveKey;
  final int initialCount;
  final int totalCount;
  final String? error;

  JsonMap toJson() => {
    'status': status.name,
    'expansionStatus': expansionStatus.name,
    'updatedAt': updatedAt,
    'objectiveKey': objectiveKey,
    'initialCount': initialCount,
    'totalCount': totalCount,
    if (error != null) 'error': error,
  };

  factory StudentCurriculumStatus.fromJson(JsonMap json) {
    return StudentCurriculumStatus(
      status: _curriculumStatusFromJson(json['status']),
      expansionStatus: _curriculumStatusFromJson(json['expansionStatus']),
      updatedAt: (json['updatedAt'] ?? '').toString(),
      objectiveKey: (json['objectiveKey'] ?? '').toString(),
      initialCount: (json['initialCount'] as num?)?.toInt() ?? 0,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
    );
  }
}

CurriculumStatusValue _curriculumStatusFromJson(Object? value) {
  final raw = value?.toString() ?? '';
  return CurriculumStatusValue.values.firstWhere(
    (status) => status.name == raw,
    orElse: () => switch (raw) {
      'initial_loading' => CurriculumStatusValue.initialLoading,
      'initial_ready' => CurriculumStatusValue.initialReady,
      'partial_ready' => CurriculumStatusValue.partialReady,
      _ => CurriculumStatusValue.empty,
    },
  );
}
