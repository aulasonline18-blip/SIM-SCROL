import '../../session/entry_form_state.dart';
import '../state/student_learning_state.dart';

class PedagogicalReceptionBuilder {
  const PedagogicalReceptionBuilder();

  JsonMap build({
    required EntryFormState form,
    required String appLocale,
    required String lessonLocale,
    required String explanationLanguage,
    String? targetLanguage,
    String? objectiveOverride,
  }) {
    final objective = (objectiveOverride ?? form.freeText).trim();
    final attachmentsText = form.buildAttachmentsText();
    final base = form.buildPedagogicalFicha(
      appLocale: appLocale,
      lessonLocale: lessonLocale,
      explanationLanguage: explanationLanguage,
      targetLanguage: targetLanguage,
    );
    final materialBased = form.entryPath == 'material_help';
    final knownWeaknesses = _joinClean([
      form.difficulties,
      form.profileDifficulties.join(', '),
      form.profileObservation,
    ]);
    final notes = _studentProfileNotes(
      objective: objective,
      attachmentsText: attachmentsText,
      summary: base['human_summary']?.toString() ?? '',
    );
    final ficha =
        <String, dynamic>{
          ...base,
          'objective': objective,
          'objetivo': objective,
          'real_objective': objective,
          'entry_path': materialBased ? 'material_help' : 'guided_path',
          'material_based': materialBased,
          'material_type': form.materialType.trim(),
          'material_received': {
            ...((base['material_received'] as Map?) ?? const {}),
            'present': materialBased || form.attachments.isNotEmpty,
          },
          'attachments_text': attachmentsText,
          'deadline': _effectiveDeadline(form),
          'expected_result': form.expectedResult.trim(),
          'known_weaknesses': knownWeaknesses,
          'learning_care_notes': _joinClean([
            knownWeaknesses,
            form.learningPreference,
          ]),
          'student_profile_notes': notes,
          'human_summary': _humanSummary(
            objective: objective,
            form: form,
            attachmentsText: attachmentsText,
          ),
          'pedagogical_entry_ficha': true,
        }..removeWhere((_, value) {
          if (value == null) return true;
          if (value is String) return value.trim().isEmpty;
          if (value is List) return value.isEmpty;
          if (value is Map) return value.isEmpty;
          return false;
        });
    return JsonMap.from(ficha);
  }

  String _effectiveDeadline(EntryFormState form) {
    final custom = form.deadlineCustom.trim();
    if (custom.isNotEmpty) return custom;
    return form.deadline.trim();
  }

  String _studentProfileNotes({
    required String objective,
    required String attachmentsText,
    required String summary,
  }) {
    return _joinClean([
      objective,
      summary.isEmpty ? '' : '--- Resumo pedagogico ---\n$summary',
      attachmentsText,
    ], separator: '\n\n');
  }

  String _humanSummary({
    required String objective,
    required EntryFormState form,
    required String attachmentsText,
  }) {
    return _joinClean([
      if (form.preferredName.trim().isNotEmpty)
        'Aluno: ${form.preferredName.trim()}',
      'Caminho: ${form.entryPath == 'material_help' ? 'material trazido pelo aluno' : 'SIM monta o caminho'}',
      if (objective.isNotEmpty) 'Objetivo: $objective',
      if (form.academicLevel.trim().isNotEmpty)
        'Nivel/contexto: ${form.academicLevel.trim()}',
      if (_effectiveDeadline(form).isNotEmpty)
        'Prazo: ${_effectiveDeadline(form)}',
      if (form.expectedResult.trim().isNotEmpty)
        'Resultado esperado: ${form.expectedResult.trim()}',
      if (form.difficulties.trim().isNotEmpty)
        'Onde trava: ${form.difficulties.trim()}',
      if (form.learningPreference.trim().isNotEmpty)
        'Conducao preferida: ${form.learningPreference.trim()}',
      if (attachmentsText.trim().isNotEmpty)
        'Material lido: ${form.attachments.where((a) => a.status == 'ready').length} anexo(s).',
    ]);
  }

  String _joinClean(List<String> values, {String separator = '\n'}) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(separator);
  }
}
