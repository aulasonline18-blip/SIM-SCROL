part of 'lab_session.dart';

extension LabSessionProfileBackupHelpers on LabSession {
  JsonMap _guidedProfileFields(String objective, {JsonMap ficha = const {}}) {
    final answers = guidedAnswers;
    String? value(String key) {
      final raw = answers[key]?.trim();
      return raw == null || raw.isEmpty ? null : raw;
    }

    final purpose = value('purpose');
    final level = value('level') ?? _cleanOrNull(academicLevel);
    final blocker = value('blocker') ?? _cleanOrNull(difficulties);
    final deadline = value('deadline') ?? _cleanOrNull(this.deadline);
    final style = value('style') ?? _cleanOrNull(learningPreference);
    final start = value('start');

    final summaryLines = [
      if (purpose != null) 'Objetivo real: $purpose',
      if (level != null) 'Nivel percebido: $level',
      if (blocker != null) 'Onde trava: $blocker',
      if (deadline != null) 'Prazo/prova: $deadline',
      if (style != null) 'Como prefere ser conduzido: $style',
      if (start != null) 'Ponto de partida desejado: $start',
    ];
    final guidedSummary = summaryLines.join('\n');

    final fields = <String, dynamic>{};
    if (guidedSummary.isNotEmpty) fields['guided_summary'] = guidedSummary;
    if (purpose != null) {
      fields['real_use_goal'] = purpose;
      fields['exam_goal'] = purpose;
    }
    if (objective.trim().isNotEmpty) {
      fields['learning_goal'] = objective.trim();
    }
    if (level != null) {
      fields['academic_level'] = level;
      fields['nivel'] = level;
    }
    if (blocker != null) {
      fields['known_weaknesses'] = blocker;
      fields['learning_care_notes'] = blocker;
    }
    if (deadline != null) {
      fields['session_goal'] = deadline;
      fields['SESSION_GOAL'] = deadline;
    }
    if (style != null) {
      fields['attention_profile'] = style;
      fields['motivation_profile'] = style;
    }
    if (start != null) fields['prior_knowledge'] = start;
    if (answers.isNotEmpty) fields['guided_answers'] = JsonMap.from(answers);
    if (ficha.isNotEmpty) {
      fields['pedagogical_entry_ficha'] = ficha;
      for (final key in const [
        'entry_path',
        'age_range',
        'material_type',
        'material_based',
        'attachments_text',
        'student_profile_notes',
        'subject',
        'topic',
        'country_curriculum',
        'human_summary',
      ]) {
        final value = ficha[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          fields[key == 'human_summary' ? 'human_entry_summary' : key] = value;
        }
      }
    }
    return fields;
  }

  Map<String, dynamic> _cyberLessonFromState(StudentLearningState state) {
    final curriculum = state.curriculum;
    final progress = state.progress;
    final layerNumber = switch (progress?.layer ??
        state.current?.layer ??
        LessonLayer.l1) {
      LessonLayer.l1 => 1,
      LessonLayer.l2 => 2,
      LessonLayer.l3 => 3,
    };
    return {
      'id': state.lessonLocalId,
      'name':
          state.profile.objetivo ?? curriculum?.topic ?? state.lessonLocalId,
      'createdAt': state.createdAt,
      'updatedAt': state.updatedAt,
      'onboarding': {
        ...state.profile.toJson(),
        'lessonLocalId': state.lessonLocalId,
        'objetivo': state.profile.objetivo ?? curriculum?.topic ?? '',
        'stableLang': state.profile.stableLang ?? state.profile.language ?? '',
      },
      'curriculo': {
        'topic': curriculum?.topic ?? state.profile.objetivo ?? '',
        'geradoEm': curriculum?.generatedAt ?? state.updatedAt,
        'provisional': curriculum?.provisional ?? false,
        'items': [
          for (final item in curriculum?.items ?? const <CurriculumItem>[])
            {
              ...item.toJson(),
              'id': item.marker,
              'title': item.title ?? item.text,
              'titulo': item.title ?? item.text,
              'item_name': item.text,
              'microitem_for_teacher': item.microitemForTeacher ?? item.text,
            },
        ],
      },
      'progress': {
        'itemIdx': progress?.itemIdx ?? state.current?.itemIdx ?? 0,
        'layer': layerNumber,
        'erros': progress?.erros ?? 0,
        'amparoLvl': progress?.amparoLvl ?? 0,
        'historia': progress?.historia ?? const <String>[],
        'mainAdvances': progress?.mainAdvances ?? 0,
        'concluidos': progress?.concluidos ?? const <String>[],
        'pendentes':
            progress?.pendentesMarkers
                .map((marker) => {'marker': marker})
                .toList() ??
            const <Map<String, dynamic>>[],
        'tentativas': [
          for (final attempt in state.attempts)
            {
              'marker': attempt.marker,
              'layer': switch (attempt.layer) {
                LessonLayer.l1 => 1,
                LessonLayer.l2 => 2,
                LessonLayer.l3 => 3,
              },
              'letra': attempt.letra.name,
              'sinal': attempt.sinal.value,
              'correct': attempt.correct,
              'ts': attempt.ts,
            },
        ],
      },
    };
  }

  Set<String> _lessonIdsFromBackup(Map<String, dynamic> backup) {
    final ids = <String>{};
    final states = backup['studentLearningStates'];
    if (states is Map) {
      ids.addAll(
        states.keys.map((key) => key.toString()).where((key) => key.isNotEmpty),
      );
    }
    final lessons = backup['lessons'];
    if (lessons is List) {
      for (final lesson in lessons.whereType<Map>()) {
        final id = lesson['id']?.toString().trim();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
    }
    final state = backup['state'];
    if (state is Map) {
      final id = state['lessonLocalId']?.toString().trim();
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    return ids;
  }
}
