part of '../student_learning_state.dart';

class StudentSnapshot {
  const StudentSnapshot({
    required this.stateVersion,
    required this.lessonLocalId,
    required this.lessonCloudId,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.profile,
    required this.curriculum,
    required this.curriculumStatus,
    required this.current,
    required this.progress,
  });

  final int stateVersion;
  final String lessonLocalId;
  final String? lessonCloudId;
  final String? userId;
  final int createdAt;
  final int updatedAt;
  final StudentProfile profile;
  final StudentCurriculum? curriculum;
  final StudentCurriculumStatus? curriculumStatus;
  final LessonCurrent? current;
  final LessonProgress? progress;

  JsonMap toJson() => {
    'stateVersion': stateVersion,
    'lessonLocalId': lessonLocalId,
    'lessonCloudId': lessonCloudId,
    'userId': userId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'profile': profile.toJson(),
    'curriculum': curriculum?.toJson(),
    'curriculumStatus': curriculumStatus?.toJson(),
    'current': current?.toJson(),
    'progress': progress?.toJson(),
  };
}
