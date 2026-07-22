import '../state/student_learning_state.dart';
import '../localization/sim_locale_contract.dart';

class PlacementContext {
  const PlacementContext({
    required this.language,
    required this.lessonLocalId,
    required this.objetivo,
    required this.profile,
    required this.curriculumItems,
    required this.markers,
    this.academicLevel,
    this.studentProfileInternal,
  });

  final String language;
  final String lessonLocalId;
  final String objetivo;
  final JsonMap profile;
  final String? academicLevel;
  final Object? studentProfileInternal;
  final List<CurriculumItem> curriculumItems;
  final List<String> markers;
}

PlacementContext? buildPlacementContext(StudentLearningState? state) {
  final curriculum = state?.curriculum;
  if (state == null || curriculum == null || curriculum.items.isEmpty) {
    return null;
  }
  final profile = state.profile.toJson();
  final locale = SimLocaleContract.fromLegacyState({
    'localeContract': state.localeContract.toJson(),
    'profile': profile,
  }).normalized();
  final lang = locale.explanationLanguage;
  final enrichedProfile = <String, dynamic>{
    ...profile,
    ...locale.toJson(),
    'localeContract': locale.toJson(),
    'language': locale.learningLocale,
    'language_semantics': 'learningLocale',
    'stableLang': locale.explanationLanguage,
    'stableLang_semantics': 'explanationLanguage',
  };
  return PlacementContext(
    lessonLocalId: state.lessonLocalId,
    language: lang,
    objetivo: (enrichedProfile['objetivo'] ?? curriculum.topic).toString(),
    profile: JsonMap.from(enrichedProfile),
    academicLevel: (profile['academic_level'] ?? profile['ACADEMIC_LEVEL'])
        ?.toString(),
    studentProfileInternal: profile['student_profile_internal'],
    curriculumItems: curriculum.items,
    markers: curriculum.items.map((item) => item.marker).toList(),
  );
}
