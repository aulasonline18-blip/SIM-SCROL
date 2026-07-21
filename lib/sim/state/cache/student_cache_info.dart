part of '../student_learning_state.dart';

class StudentCacheInfo {
  const StudentCacheInfo({
    required this.currentLessonMaterial,
    required this.readyLessonMaterials,
    required this.queuedActions,
    required this.inflightJobs,
  });

  final JsonMap? currentLessonMaterial;
  final Map<String, JsonMap> readyLessonMaterials;
  final List<JsonMap> queuedActions;
  final List<JsonMap> inflightJobs;

  List<String> get readyLessonIds => readyLessonMaterials.keys.toList();

  int get readyCount => readyLessonMaterials.length;

  bool get hasCurrentLessonMaterial => currentLessonMaterial != null;

  JsonMap toJson() => {
    'currentLessonMaterial': currentLessonMaterial,
    'readyLessonMaterials': readyLessonMaterials,
    'queuedActions': queuedActions,
    'inflightJobs': inflightJobs,
  };
}
