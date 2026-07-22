import 'package:flutter/foundation.dart';

import '../../session/entry_form_state.dart';
import '../ui/sim_i18n.dart';

enum PedagogicalReceptionPath { guided, material }

class PedagogicalReceptionStep {
  const PedagogicalReceptionStep({
    required this.id,
    required this.title,
    required this.help,
    required this.required,
  });

  final String id;
  final String title;
  final String help;
  final bool required;
}

class PedagogicalReceptionController extends ChangeNotifier {
  PedagogicalReceptionController({required this.form});

  final EntryFormState form;
  int activeIndex = 0;
  String? error;
  final Map<String, String> fieldErrors = {};

  PedagogicalReceptionPath get path {
    return form.entryPath == 'material_help'
        ? PedagogicalReceptionPath.material
        : PedagogicalReceptionPath.guided;
  }

  bool get hasProcessingAttachment =>
      form.attachments.any((attachment) => attachment.status == 'processing');

  bool get hasAttachmentIssue => form.attachments.any(
    (attachment) =>
        attachment.status == 'error' || attachment.status == 'insufficient',
  );

  int get activeStepNumber => activeIndex + 1;

  int get totalStepCount => steps.length;

  String errorFor(String fieldId) => fieldErrors[fieldId] ?? '';

  bool stepCanAdvance(String id) => validateStep(id, mutate: false) == null;

  List<PedagogicalReceptionStep> get steps {
    final selected = path;
    return [
      PedagogicalReceptionStep(
        id: 'objective',
        title: t('objective_step_title'),
        help: t('objective_step_help'),
        required: true,
      ),
      if (selected == PedagogicalReceptionPath.material) ...[
        PedagogicalReceptionStep(
          id: 'material_type',
          title: t('objective_material_type_title'),
          help: t('objective_material_type_help'),
          required: true,
        ),
        PedagogicalReceptionStep(
          id: 'attachments',
          title: t('objective_attachments_title'),
          help: t('objective_attachments_help'),
          required: true,
        ),
        PedagogicalReceptionStep(
          id: 'material_purpose',
          title: t('objective_material_purpose_title'),
          help: t('objective_material_purpose_help'),
          required: true,
        ),
      ] else ...[
        PedagogicalReceptionStep(
          id: 'level',
          title: t('objective_level_title'),
          help: t('objective_level_help'),
          required: true,
        ),
        PedagogicalReceptionStep(
          id: 'purpose',
          title: t('objective_purpose_title'),
          help: t('objective_purpose_help'),
          required: true,
        ),
        PedagogicalReceptionStep(
          id: 'deadline',
          title: t('objective_deadline_title'),
          help: t('objective_deadline_help'),
          required: false,
        ),
        PedagogicalReceptionStep(
          id: 'result',
          title: t('objective_result_title'),
          help: t('objective_result_help'),
          required: false,
        ),
        PedagogicalReceptionStep(
          id: 'blocker',
          title: t('objective_blocker_title'),
          help: t('objective_blocker_help'),
          required: false,
        ),
        PedagogicalReceptionStep(
          id: 'style',
          title: t('objective_style_title'),
          help: t('objective_style_help'),
          required: false,
        ),
      ],
      PedagogicalReceptionStep(
        id: 'profile',
        title: t('objective_profile_title'),
        help: t('objective_profile_help'),
        required: false,
      ),
      PedagogicalReceptionStep(
        id: 'finish',
        title: t('objective_finish_title'),
        help: t('objective_finish_help'),
        required: true,
      ),
    ];
  }

  void choosePath(PedagogicalReceptionPath value) {
    form.updatePedagogicalField(
      'entry_path',
      value == PedagogicalReceptionPath.material
          ? 'material_help'
          : 'guided_path',
    );
    error = null;
    fieldErrors.clear();
    if (activeIndex >= steps.length) activeIndex = steps.length - 1;
    notifyListeners();
  }

  bool advance() {
    final current = steps[activeIndex];
    final validation = validateStep(current.id);
    if (validation != null) {
      error = validation;
      notifyListeners();
      return false;
    }
    error = null;
    if (activeIndex < steps.length - 1) {
      activeIndex += 1;
      notifyListeners();
    }
    return true;
  }

  void edit(String id) {
    final index = steps.indexWhere((step) => step.id == id);
    if (index < 0) return;
    activeIndex = index;
    error = null;
    fieldErrors.clear();
    notifyListeners();
  }

  String? validateStep(String id, {bool mutate = true}) {
    String? set(String fieldId, String? value) {
      if (mutate) {
        if (value == null) {
          fieldErrors.remove(fieldId);
        } else {
          fieldErrors[fieldId] = value;
        }
      }
      return value;
    }

    switch (id) {
      case 'objective':
        final text = form.freeText.trim();
        if (text.length < 10) return set('objective', t('objective_error_min'));
        if (form.freeText.length > entryFormMaxFreeText) {
          return set('objective', t('objective_error_max'));
        }
        set('objective', null);
        return null;
      case 'level':
        return form.academicLevel.trim().isEmpty
            ? t('objective_error_level')
            : null;
      case 'purpose':
        return form.traversalGoal.trim().isEmpty
            ? t('objective_error_purpose')
            : null;
      case 'material_type':
        return form.materialType.trim().isEmpty
            ? t('objective_error_material_type')
            : null;
      case 'attachments':
        if (hasProcessingAttachment) {
          return t('objective_error_attachment_wait');
        }
        if (!form.describeMaterialWithoutAttachment &&
            !form.attachments.any(
              (attachment) => attachment.status == 'ready',
            )) {
          return t('objective_error_attachment_required');
        }
        return null;
      case 'material_purpose':
        return form.traversalGoal.trim().isEmpty
            ? t('objective_error_material_purpose')
            : null;
      case 'profile':
        final age = form.studentAge.trim();
        if (age.isEmpty || form.ageNotDeclared) {
          set('age', null);
          return null;
        }
        final parsed = int.tryParse(age);
        if (parsed == null || parsed < 3 || parsed > 120) {
          return set('age', t('objective_error_age_invalid'));
        }
        set('age', null);
        return null;
      case 'finish':
        return validateAll();
      default:
        return null;
    }
  }

  String? validateAll() {
    for (final step in steps) {
      if (step.id == 'finish') continue;
      final validation = validateStep(step.id);
      if (validation != null) return validation;
    }
    return null;
  }

  String summaryFor(String id) {
    switch (id) {
      case 'objective':
        return form.freeText.trim();
      case 'level':
        return form.academicLevel.trim();
      case 'purpose':
      case 'material_purpose':
        return form.traversalGoal.trim();
      case 'deadline':
        return form.deadlineCustom.trim().isNotEmpty
            ? form.deadlineCustom.trim()
            : form.deadline.trim();
      case 'result':
        return form.expectedResult.trim();
      case 'blocker':
        return form.difficulties.trim();
      case 'style':
        return form.learningPreference.trim();
      case 'material_type':
        return form.materialType.trim();
      case 'attachments':
        final ready = form.attachments.where((a) => a.status == 'ready').length;
        if (form.attachments.isEmpty) {
          return form.describeMaterialWithoutAttachment
              ? t('objective_attachment_description_summary')
              : '';
        }
        final names = form.attachments
            .map((attachment) => attachment.name.trim())
            .where((name) => name.isNotEmpty)
            .join(', ');
        final status = t('objective_attachment_summary', {
          'ready': ready,
          'total': form.attachments.length,
        });
        return names.isEmpty ? status : '$status\n$names';
      case 'profile':
        return [
          form.preferredName.trim(),
          form.ageNotDeclared
              ? t('objective_age_not_declared')
              : form.studentAge.trim(),
          form.profileObservation.trim(),
        ].where((value) => value.isNotEmpty).join(' · ');
      case 'finish':
        return finalSummaryLines().join('\n');
      default:
        return '';
    }
  }

  List<String> finalSummaryLines() {
    final subject = form.subject.trim().isEmpty
        ? t('objective_not_informed')
        : form.subject.trim();
    final topic = form.topic.trim().isEmpty
        ? t('objective_not_informed')
        : form.topic.trim();
    final lines = <String>[
      path == PedagogicalReceptionPath.material
          ? t('objective_summary_material_path')
          : t('objective_summary_guided_path'),
      if (form.freeText.trim().isNotEmpty)
        '${t('objective_summary_objective')}: ${form.freeText.trim()}',
      '${t('objective_summary_subject')}: $subject',
      '${t('objective_summary_topic')}: $topic',
      if (form.materialType.trim().isNotEmpty)
        '${t('objective_summary_material')}: ${form.materialType.trim()}',
      if (form.attachments.isNotEmpty) summaryFor('attachments'),
      if (form.academicLevel.trim().isNotEmpty)
        '${t('objective_summary_context')}: ${form.academicLevel.trim()}',
      if (form.traversalGoal.trim().isNotEmpty)
        '${t('objective_summary_use')}: ${form.traversalGoal.trim()}',
      if (_effectiveDeadline().isNotEmpty)
        '${t('objective_summary_deadline')}: ${_effectiveDeadline()}',
      if (form.expectedResult.trim().isNotEmpty)
        '${t('objective_summary_result')}: ${form.expectedResult.trim()}',
      if (form.difficulties.trim().isNotEmpty)
        '${t('objective_summary_attention')}: ${form.difficulties.trim()}',
      if (form.learningPreference.trim().isNotEmpty)
        '${t('objective_summary_style')}: ${form.learningPreference.trim()}',
      if (summaryFor('profile').trim().isNotEmpty)
        '${t('objective_summary_care')}: ${summaryFor('profile').trim()}',
    ];
    return lines
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
  }

  String _effectiveDeadline() {
    final custom = form.deadlineCustom.trim();
    return custom.isNotEmpty ? custom : form.deadline.trim();
  }
}
