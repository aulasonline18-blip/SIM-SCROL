part of 'student_state_store.dart';

StudentLearningState _importCyberBackup(
  StudentStateStore store,
  JsonMap backup,
) {
  final states = backup['studentLearningStates'] is Map
      ? JsonMap.from(backup['studentLearningStates'] as Map)
      : const <String, dynamic>{};
  final lessons = backup['lessons'] is List
      ? backup['lessons'] as List
      : const [];
  StudentLearningState? lastImported;
  final protectedIds = <String>{
    ...states.keys.map((key) => key.toString()).where((key) => key.isNotEmpty),
    for (final lesson in lessons.whereType<Map>())
      _lessonIdFromCyberLesson(JsonMap.from(lesson)),
  }..removeWhere((id) => id.trim().isEmpty);

  for (final id in protectedIds) {
    final before = store._memory[id] ?? store._readStateIfExists(id);
    final rawSnapshot = states[id];
    final snapshot = rawSnapshot is Map
        ? StudentLearningState.fromJson(
            JsonMap.from({...rawSnapshot, 'lessonLocalId': id}),
          )
        : null;
    final lesson = lessons
        .whereType<Map>()
        .map((entry) => JsonMap.from(entry))
        .where((entry) => _lessonIdFromCyberLesson(entry) == id)
        .cast<JsonMap?>()
        .firstWhere((entry) => entry != null, orElse: () => null);
    final lessonState = lesson == null
        ? null
        : _stateFromCyberLesson(store, lesson, id);
    final imported = _mergeBackupStates(lessonState, snapshot);
    if (imported == null) continue;
    final merged = before == null
        ? imported
        : mergeValidatedRemoteState(imported, before);
    lastImported = store.writeState(
      merged.copyWith(
        lessonLocalId: id,
        profile: merged.profile.copyWith(
          extra: {...merged.profile.extra, 'lessonLocalId': id},
        ),
      ),
    );
  }
  if (lastImported == null) {
    throw ArgumentError('Backup compativel sem aulas validas.');
  }
  return lastImported;
}

StudentLearningState? _mergeBackupStates(
  StudentLearningState? existing,
  StudentLearningState? incoming,
) {
  if (existing == null) return incoming;
  if (incoming == null) return existing;
  return mergeStudentLearningStateFromCloud(existing, incoming);
}

String _lessonIdFromCyberLesson(JsonMap lesson) {
  final direct = (lesson['id'] ?? '').toString().trim();
  if (direct.isNotEmpty) return direct;
  final onboarding = lesson['onboarding'];
  if (onboarding is Map) {
    final fromOnboarding = (onboarding['lessonLocalId'] ?? '')
        .toString()
        .trim();
    if (fromOnboarding.isNotEmpty) return fromOnboarding;
  }
  return '';
}

StudentLearningState _stateFromCyberLesson(
  StudentStateStore store,
  JsonMap lesson,
  String id,
) {
  final onboarding = lesson['onboarding'] is Map
      ? JsonMap.from(lesson['onboarding'] as Map)
      : const <String, dynamic>{};
  final rawItems =
      lesson['curriculo'] ?? lesson['curriculum'] ?? lesson['items'];
  final items = rawItems is List
      ? rawItems
            .whereType<Map>()
            .map((raw) {
              final item = JsonMap.from(raw);
              return CurriculumItem(
                marker: (item['marker'] ?? item['id'] ?? '').toString(),
                text:
                    (item['text'] ??
                            item['microitem_for_teacher'] ??
                            item['what_student_must_master'] ??
                            item['title'] ??
                            '')
                        .toString(),
                unit: item['unit']?.toString(),
                title: item['title']?.toString(),
                microitemForTeacher:
                    (item['microitem_for_teacher'] ??
                            item['what_student_must_master'])
                        ?.toString(),
                extra: item
                  ..removeWhere(
                    (key, _) => {
                      'marker',
                      'id',
                      'text',
                      'unit',
                      'title',
                      'microitem_for_teacher',
                      'what_student_must_master',
                    }.contains(key),
                  ),
              );
            })
            .where((item) => item.marker.isNotEmpty && item.text.isNotEmpty)
            .toList()
      : <CurriculumItem>[];
  final now =
      (lesson['updatedAt'] as num?)?.toInt() ??
      (lesson['createdAt'] as num?)?.toInt() ??
      store.now();
  final topic =
      (onboarding['objetivo'] ??
              onboarding['free_text'] ??
              lesson['title'] ??
              lesson['tema'] ??
              'Aula SIM')
          .toString();
  return StudentLearningState.empty(lessonLocalId: id, now: now).copyWith(
    profile: StudentProfile(
      preferredName: onboarding['preferred_name']?.toString(),
      language: onboarding['language']?.toString(),
      stableLang: (onboarding['stable_lang'] ?? onboarding['stableLang'])
          ?.toString(),
      objetivo: topic,
      nivel: onboarding['nivel']?.toString(),
      academicLevel:
          (onboarding['academic_level'] ?? onboarding['academicLevel'])
              ?.toString(),
      targetTopic: (onboarding['target_topic'] ?? topic).toString(),
      sessionGoal: topic,
      extra: onboarding,
    ),
    curriculum: items.isEmpty
        ? null
        : StudentCurriculum(
            topic: topic,
            totalItems: items.length,
            generatedAt: now,
            provisional: false,
            items: items,
          ),
    progress: items.isEmpty
        ? null
        : LessonProgress(
            itemIdx: 0,
            layer: LessonLayer.l1,
            erros: 0,
            amparoLvl: 0,
            historia: const [],
            mainAdvances: 0,
            concluidos: const [],
            pendentesMarkers: items.map((item) => item.marker).toList(),
            totalItems: items.length,
            pctAvanco: 0,
          ),
    current: items.isEmpty
        ? null
        : LessonCurrent(
            itemIdx: 0,
            marker: items.first.marker,
            layer: LessonLayer.l1,
            amparoLvl: 0,
          ),
  );
}
