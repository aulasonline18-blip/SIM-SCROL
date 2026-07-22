import '../../session/entry_form_state.dart';
import '../localization/sim_locale_contract.dart';
import '../state/student_learning_state.dart';

class PedagogicalReceptionBuilder {
  const PedagogicalReceptionBuilder();

  JsonMap build({
    required EntryFormState form,
    required String appLocale,
    required String lessonLocale,
    required String explanationLanguage,
    String? targetLanguage,
    SimLocaleContract? localeContract,
    String? objectiveOverride,
  }) {
    final objective = (objectiveOverride ?? form.freeText).trim();
    final attachmentsText = form.buildAttachmentsText();
    final base = form.buildPedagogicalFicha(
      appLocale: appLocale,
      lessonLocale: lessonLocale,
      explanationLanguage: explanationLanguage,
      targetLanguage: targetLanguage,
      localeContract: localeContract,
    );
    final locale = SimLocaleContract.fromLegacyState(base).normalized();
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
      locale: locale.explanationLanguage,
    );
    final pedagogicalEntry = base['pedagogical_entry'] is Map
        ? JsonMap.from(base['pedagogical_entry'] as Map)
        : JsonMap.from({
            'version': 1,
            'localeContract': locale.toJson(),
            'student_goal': {'objective': objective},
          });
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
          'student_profile_notes_locale': locale.explanationLanguage,
          'human_summary': _humanSummary(
            objective: objective,
            form: form,
            attachmentsText: attachmentsText,
            locale: locale.explanationLanguage,
          ),
          'human_summary_locale': locale.explanationLanguage,
          'pedagogical_entry': pedagogicalEntry,
          'pedagogical_entry_ficha': pedagogicalEntry,
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
    required String locale,
  }) {
    return _joinClean([
      objective,
      summary.isEmpty
          ? ''
          : '--- ${_summaryLabel(locale, 'pedagogicalSummary')} ---\n$summary',
      attachmentsText,
    ], separator: '\n\n');
  }

  String _humanSummary({
    required String objective,
    required EntryFormState form,
    required String attachmentsText,
    required String locale,
  }) {
    return _joinClean([
      if (form.preferredName.trim().isNotEmpty)
        '${_summaryLabel(locale, 'student')}: ${form.preferredName.trim()}',
      '${_summaryLabel(locale, 'path')}: ${form.entryPath == 'material_help' ? _summaryLabel(locale, 'materialPath') : _summaryLabel(locale, 'guidedPath')}',
      if (objective.isNotEmpty)
        '${_summaryLabel(locale, 'objective')}: $objective',
      if (form.academicLevel.trim().isNotEmpty)
        '${_summaryLabel(locale, 'level')}: ${form.academicLevel.trim()}',
      if (_effectiveDeadline(form).isNotEmpty)
        '${_summaryLabel(locale, 'deadline')}: ${_effectiveDeadline(form)}',
      if (form.expectedResult.trim().isNotEmpty)
        '${_summaryLabel(locale, 'expectedResult')}: ${form.expectedResult.trim()}',
      if (form.difficulties.trim().isNotEmpty)
        '${_summaryLabel(locale, 'blocker')}: ${form.difficulties.trim()}',
      if (form.learningPreference.trim().isNotEmpty)
        '${_summaryLabel(locale, 'preference')}: ${form.learningPreference.trim()}',
      if (attachmentsText.trim().isNotEmpty)
        '${_summaryLabel(locale, 'materialRead')}: ${form.attachments.where((a) => a.status == 'ready').length}.',
    ]);
  }

  String _summaryLabel(String locale, String key) {
    final language = locale.toLowerCase();
    final en = language.startsWith('english') || language == 'en';
    final es = language.startsWith('spanish') || language == 'es';
    final labels = en
        ? const {
            'pedagogicalSummary': 'Pedagogical summary',
            'student': 'Student',
            'path': 'Path',
            'materialPath': 'student material',
            'guidedPath': 'SIM builds the path',
            'objective': 'Objective',
            'level': 'Level/context',
            'deadline': 'Deadline',
            'expectedResult': 'Expected result',
            'blocker': 'Where it gets stuck',
            'preference': 'Preferred guidance',
            'materialRead': 'Readable material attachments',
          }
        : es
        ? const {
            'pedagogicalSummary': 'Resumen pedagógico',
            'student': 'Estudiante',
            'path': 'Ruta',
            'materialPath': 'material del estudiante',
            'guidedPath': 'SIM construye la ruta',
            'objective': 'Objetivo',
            'level': 'Nivel/contexto',
            'deadline': 'Plazo',
            'expectedResult': 'Resultado esperado',
            'blocker': 'Dónde se bloquea',
            'preference': 'Conducción preferida',
            'materialRead': 'Anexos con material legible',
          }
        : const {
            'pedagogicalSummary': 'Resumo pedagogico',
            'student': 'Aluno',
            'path': 'Caminho',
            'materialPath': 'material trazido pelo aluno',
            'guidedPath': 'SIM monta o caminho',
            'objective': 'Objetivo',
            'level': 'Nivel/contexto',
            'deadline': 'Prazo',
            'expectedResult': 'Resultado esperado',
            'blocker': 'Onde trava',
            'preference': 'Conducao preferida',
            'materialRead': 'Anexos com material lido',
          };
    return labels[key] ?? key;
  }

  String _joinClean(List<String> values, {String separator = '\n'}) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(separator);
  }
}
