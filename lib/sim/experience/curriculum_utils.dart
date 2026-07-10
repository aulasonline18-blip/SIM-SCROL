import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';

String itemText(CurriculumItem item) {
  return (item.microitemForTeacher ?? item.title ?? item.text).trim();
}

String normalizeStudyKey(Object? value) {
  return value.toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

List<CurriculumItem> normalizeCurriculumItems(Object? raw) {
  final List<Object?> items;
  if (raw is List) {
    items = raw;
  } else if (raw is Map) {
    final rawItems = raw['items'];
    if (rawItems is List) {
      items = rawItems;
    } else {
      return normalizeCurriculumItems(raw['curriculo'] ?? raw['curriculum']);
    }
  } else {
    return const [];
  }

  final out = <CurriculumItem>[];
  for (var i = 0; i < items.length; i++) {
    final entry = items[i];
    if (entry is! Map) continue;
    final item = Map<String, dynamic>.from(entry);
    final rawMarker = item['marker_id'] ?? item['marker'] ?? item['id'];
    final marker = rawMarker is num && rawMarker > 0
        ? 'M${rawMarker.toInt()}'
        : rawMarker is String && rawMarker.trim().isNotEmpty
        ? rawMarker.trim()
        : 'M${i + 1}';
    final text = _firstText(
      item['microitem_for_teacher'],
      item['what_student_must_master'],
      item['title'],
      item['titulo'],
      item['item_name'],
      item['text'],
    );
    if (text.isEmpty) continue;
    out.add(
      CurriculumItem(
        marker: marker,
        text: text,
        title: item['title'] is String ? item['title'] as String : text,
        microitemForTeacher: item['microitem_for_teacher'] is String
            ? item['microitem_for_teacher'] as String
            : text,
        extra: item,
      ),
    );
  }
  return out;
}

List<CurriculumItem> dedupeCurriculumBatchItems(List<CurriculumItem> items) {
  final seenMarkers = <String>{};
  final seenGlobalIndexes = <int>{};
  final out = <CurriculumItem>[];
  for (final item in items) {
    final markerKey = item.marker.trim().toLowerCase();
    final globalIndex = _intFrom(item.extra['global_item_index']);
    if (markerKey.isNotEmpty && seenMarkers.contains(markerKey)) {
      continue;
    }
    if (globalIndex != null && seenGlobalIndexes.contains(globalIndex)) {
      continue;
    }
    if (markerKey.isNotEmpty) seenMarkers.add(markerKey);
    if (globalIndex != null) seenGlobalIndexes.add(globalIndex);
    out.add(item);
  }
  return out;
}

CurriculumGlobalPlan? normalizeCurriculumGlobalPlan({
  required Object? rawCurriculum,
  required Object? rawQualityCheck,
  required int localItemCount,
}) {
  final fromCurriculum = _planMapFrom(rawCurriculum);
  if (fromCurriculum != null) {
    return CurriculumGlobalPlan.fromJson(fromCurriculum, localItemCount);
  }
  final fromQuality = _planMapFrom(rawQualityCheck);
  if (fromQuality != null) {
    return CurriculumGlobalPlan.fromJson(fromQuality, localItemCount);
  }
  return null;
}

JsonMap? buildCurriculumContinuationRequest(StudentLearningState state) {
  final curriculum = state.curriculum;
  final plan = curriculum?.globalPlan;
  if (curriculum == null || plan == null || !plan.continuationNeeded) {
    return null;
  }
  final next = plan.nextGlobalItemToRequest;
  if (next == null || next <= plan.batchEndItem) return null;
  return {
    'lessonLocalId': state.lessonLocalId,
    'topic': curriculum.topic,
    'partNumber': (plan.partNumber ?? 1) + 1,
    'previousBatch': {
      'start': plan.batchStartItem,
      'end': plan.batchEndItem,
      'items': curriculum.items.length,
    },
    'nextGlobalItemToRequest': next,
    'globalTotalItems': plan.globalTotalItems,
    'unitsPending': plan.unitsPending,
    'continuationInstruction': plan.continuationInstruction,
    'profile': state.profile.toJson(),
  };
}

String curriculumPlanRootLessonId(StudentLearningState state) {
  final raw = state.extra['curriculumPlanRootLessonId'];
  final text = raw?.toString().trim();
  return text == null || text.isEmpty ? state.lessonLocalId : text;
}

String curriculumPartLessonId(String rootLessonLocalId, int partNumber) {
  final cleanRoot = rootLessonLocalId.trim();
  if (partNumber <= 1) return cleanRoot;
  return '$cleanRoot::part-$partNumber';
}

String? nextCurriculumPartLessonId(StudentLearningState state) {
  final raw = state.extra['nextCurriculumPartLessonId'];
  final fromExtra = raw?.toString().trim();
  if (fromExtra != null && fromExtra.isNotEmpty) return fromExtra;

  final request = buildCurriculumContinuationRequest(state);
  final nextPart = request == null ? null : _intFrom(request['partNumber']);
  if (nextPart == null || nextPart <= 1) return null;
  return curriculumPartLessonId(curriculumPlanRootLessonId(state), nextPart);
}

StudentLearningState markCurriculumPartStatus({
  required StudentLearningState state,
  required String status,
  String? nextLessonLocalId,
  String? error,
}) {
  final extra = {
    ...state.extra,
    'curriculumPlanRootLessonId': curriculumPlanRootLessonId(state),
    'curriculumPartNumber': state.curriculum?.globalPlan?.partNumber ?? 1,
    'nextCurriculumPartStatus': status,
  };
  if (nextLessonLocalId != null) {
    extra['nextCurriculumPartLessonId'] = nextLessonLocalId;
  }
  if (error != null) {
    extra['nextCurriculumPartError'] = error;
  }
  return state.copyWith(extra: extra);
}

StudentLearningState? readyNextCurriculumPart({
  required StudentLearningStateService service,
  required StudentLearningState state,
}) {
  final nextId = nextCurriculumPartLessonId(state);
  if (nextId == null) return null;
  final next = service.read(nextId);
  return next?.curriculum?.items.isNotEmpty == true ? next : null;
}

JsonMap? _planMapFrom(Object? value) {
  if (value is! Map) return null;
  final map = JsonMap.from(value);
  final direct =
      map['curriculum_plan'] ?? map['globalPlan'] ?? map['global_plan'];
  if (direct is Map) return JsonMap.from(direct);
  final values = map['values'];
  if (values is Map) return _planMapFromQualityValues(JsonMap.from(values));
  return _planMapFromQualityValues(map);
}

JsonMap? _planMapFromQualityValues(JsonMap values) {
  String pick(String key) {
    final direct = values[key];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }
    for (final entry in values.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase() &&
          entry.value.toString().trim().isNotEmpty) {
        return entry.value.toString().trim();
      }
    }
    return '';
  }

  final estimated = pick('Estimated global total items');
  final limit = pick('Operational batch limit used');
  final range = pick('Current batch global range');
  final part = pick('Current part title/number');
  final covered = pick('Units covered in this batch');
  final pending = pick('Units pending after this batch');
  final next = pick('Next global item to request');
  final continuation = pick('Continuation needed');
  final instruction = pick('Continuation instruction for software');
  if ([
    estimated,
    limit,
    range,
    part,
    covered,
    pending,
    next,
    continuation,
    instruction,
  ].every((value) => value.isEmpty)) {
    return null;
  }
  final parsedRange = _rangeFrom(range);
  return {
    'globalTotalItems': _intFrom(estimated),
    'operationalBatchLimit': _intFrom(limit),
    'batchStartItem': parsedRange.$1,
    'batchEndItem': parsedRange.$2,
    'partNumber': _intFrom(part),
    'partTitle': part,
    'unitsCovered': covered,
    'unitsPending': pending,
    'nextGlobalItemToRequest': _intFrom(next),
    'continuationNeeded': _boolFrom(continuation),
    'continuationInstruction': instruction,
  }..removeWhere((_, value) => value == null || value == '');
}

int? _intFrom(Object? value) {
  if (value is num) return value.toInt();
  final match = RegExp(r'\d+').firstMatch(value?.toString() ?? '');
  return match == null ? null : int.tryParse(match.group(0)!);
}

(int?, int?) _rangeFrom(String value) {
  final match = RegExp(
    r'(\d+)\s*(?:-|–|—|to|até|a)\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) return (null, null);
  return (int.tryParse(match.group(1)!), int.tryParse(match.group(2)!));
}

bool? _boolFrom(String value) {
  final clean = value.trim().toLowerCase();
  if ([
    'yes',
    'sim',
    'true',
    'required',
    'necessaria',
    'necessária',
    'needed',
  ].any(clean.contains)) {
    return true;
  }
  if (['no', 'não', 'nao', 'false', 'none', 'not needed'].any(clean.contains)) {
    return false;
  }
  return null;
}

String _firstText(
  Object? a,
  Object? b,
  Object? c,
  Object? d,
  Object? e,
  Object? f,
) {
  for (final value in [a, b, c, d, e, f]) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}
