part of '../student_learning_state.dart';

class StudentProfile {
  const StudentProfile({
    this.preferredName,
    this.language,
    this.stableLang,
    this.objetivo,
    this.nivel,
    this.academicLevel,
    this.targetTopic,
    this.sessionGoal,
    this.extra = const {},
  });

  final String? preferredName;
  final String? language;
  final String? stableLang;
  final String? objetivo;
  final String? nivel;
  final String? academicLevel;
  final String? targetTopic;
  final String? sessionGoal;
  final JsonMap extra;

  JsonMap toJson() => {
    ...extra,
    if (preferredName != null) 'preferredName': preferredName,
    if (language != null) 'language': language,
    if (stableLang != null) 'stableLang': stableLang,
    if (objetivo != null) 'objetivo': objetivo,
    if (nivel != null) 'nivel': nivel,
    if (academicLevel != null) 'academicLevel': academicLevel,
    if (targetTopic != null) 'targetTopic': targetTopic,
    if (sessionGoal != null) 'sessionGoal': sessionGoal,
  };

  factory StudentProfile.fromJson(JsonMap json) {
    final extra = JsonMap.of(json)
      ..removeWhere(
        (key, _) => {
          'preferredName',
          'language',
          'stableLang',
          'objetivo',
          'nivel',
          'academicLevel',
          'targetTopic',
          'sessionGoal',
        }.contains(key),
      );
    return StudentProfile(
      preferredName: json['preferredName'] as String?,
      language: json['language'] as String?,
      stableLang: json['stableLang'] as String?,
      objetivo: json['objetivo'] as String?,
      nivel: json['nivel'] as String?,
      academicLevel: json['academicLevel'] as String?,
      targetTopic: json['targetTopic'] as String?,
      sessionGoal: json['sessionGoal'] as String?,
      extra: extra,
    );
  }

  StudentProfile copyWith({
    String? preferredName,
    String? language,
    String? stableLang,
    String? objetivo,
    String? nivel,
    String? academicLevel,
    String? targetTopic,
    String? sessionGoal,
    JsonMap? extra,
  }) {
    return StudentProfile(
      preferredName: preferredName ?? this.preferredName,
      language: language ?? this.language,
      stableLang: stableLang ?? this.stableLang,
      objetivo: objetivo ?? this.objetivo,
      nivel: nivel ?? this.nivel,
      academicLevel: academicLevel ?? this.academicLevel,
      targetTopic: targetTopic ?? this.targetTopic,
      sessionGoal: sessionGoal ?? this.sessionGoal,
      extra: extra ?? this.extra,
    );
  }
}
