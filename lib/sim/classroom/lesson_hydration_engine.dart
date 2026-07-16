import '../lesson/lesson_models.dart';
import '../lesson/student_lesson_material_service.dart';
import '../state/student_learning_state.dart';
import 'classroom_models.dart';

class LessonHydrationResult {
  const LessonHydrationResult({
    required this.hydratedFromState,
    required this.initialProgress,
    required this.initialFastLesson,
  });

  final LessonCurrent? hydratedFromState;
  final LessonProgress? initialProgress;
  final ResolveLessonMaterialResult? initialFastLesson;
}

class LessonHydrationEngine {
  LessonHydrationEngine({required this.materialService});

  final StudentLessonMaterialService materialService;

  LessonHydrationResult hydrate({
    required StudentLearningState? state,
    required List<PlannedItem> baseItems,
    required String lessonLocalId,
    required String? topic,
    required String idioma,
    required String academic,
  }) {
    final hydrated = _validCurrent(state, baseItems);
    final progress = state?.progress;
    ResolveLessonMaterialResult? fast;
    final itemIdx = progress?.itemIdx ?? hydrated?.itemIdx ?? 0;
    final layer = progress?.layer ?? hydrated?.layer ?? LessonLayer.l1;
    if (itemIdx >= 0 && itemIdx < baseItems.length) {
      final item = baseItems[itemIdx];
      fast = materialService.resolveFastLessonMaterialFromStateOrCache(
        ResolveLessonMaterialInput(
          lessonLocalId: lessonLocalId,
          topic: topic,
          itemIdx: itemIdx,
          marker: item.marker,
          layer: layer,
          params: CompleteLessonParams(
            lessonLocalId: lessonLocalId,
            item: item.text,
            lang: idioma,
            academic: academic,
            layer: layer,
            mode: LessonMode.session,
            errCount: progress?.erros ?? 0,
            history: progress?.historia ?? const [],
            marker: item.marker,
            curriculumItems: _curriculumSnapshot(baseItems),
            topic: topic,
            itemIdx: itemIdx,
            pedagogicalEnvelope: _pedagogicalEnvelope(
              state?.profile.toJson() ?? const {},
              item,
            ),
          ),
        ),
      );
    }
    return LessonHydrationResult(
      hydratedFromState: hydrated,
      initialProgress: progress,
      initialFastLesson: fast,
    );
  }

  LessonCurrent? _validCurrent(
    StudentLearningState? state,
    List<PlannedItem> baseItems,
  ) {
    final current = state?.current;
    if (current == null) return null;
    if (current.itemIdx < 0 || current.itemIdx >= baseItems.length) return null;
    final expectedMarker = baseItems[current.itemIdx].marker;
    if (current.marker != null && current.marker != expectedMarker) return null;
    return current;
  }
}

JsonMap _pedagogicalEnvelope(JsonMap profile, PlannedItem item) {
  String pick(List<String> keys) {
    for (final key in keys) {
      final value = profile[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  return {
    if (item.marker.isNotEmpty) 'marker': item.marker,
    if ((item.unit ?? '').trim().isNotEmpty) 'unit': item.unit!.trim(),
    if ((item.title ?? '').trim().isNotEmpty) 'title': item.title!.trim(),
    if (pick(['stableLang', 'STABLE_LANG', 'idioma']).isNotEmpty)
      'stable_lang': pick(['stableLang', 'STABLE_LANG', 'idioma']),
    if (pick(['academic_level', 'ACADEMIC_LEVEL']).isNotEmpty)
      'academic_level': pick(['academic_level', 'ACADEMIC_LEVEL']),
    if (profile['student_profile_internal'] != null)
      'student_profile_internal': profile['student_profile_internal'],
    if (profile['guidance_for_T02'] != null)
      'guidance_for_T02': profile['guidance_for_T02'],
    if (profile['curriculum_global_plan'] != null)
      'curriculum_global_plan': profile['curriculum_global_plan'],
    if (pick(['original_text_preserved']).isNotEmpty)
      'original_text_preserved': pick(['original_text_preserved']),
  };
}

List<JsonMap> _curriculumSnapshot(List<PlannedItem> items) {
  return [
    for (var index = 0; index < items.length; index += 1)
      {
        ...items[index].extra,
        'order': index + 1,
        'marker': items[index].marker,
        if ((items[index].unit ?? '').trim().isNotEmpty)
          'unit': items[index].unit!.trim(),
        'title': items[index].text,
        'text': items[index].text,
        'purpose': items[index].text,
        'microitem_for_teacher': items[index].text,
      },
  ];
}
