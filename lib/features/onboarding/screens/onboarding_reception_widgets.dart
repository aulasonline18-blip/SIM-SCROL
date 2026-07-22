part of '../onboarding_screens.dart';

class _FinishSummary extends StatelessWidget {
  const _FinishSummary({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Column(
      key: const Key('reception-final-summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('objective_finish_summary_intro'),
          style: TextStyle(
            color: palette.text,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        for (final line in lines) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 18,
                color: palette.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  line,
                  style: TextStyle(color: palette.text, height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ReceptionBlock extends StatelessWidget {
  const _ReceptionBlock({
    required this.step,
    required this.active,
    required this.complete,
    required this.summary,
    required this.error,
    required this.onEdit,
    required this.child,
    super.key,
  });

  final PedagogicalReceptionStep step;
  final bool active;
  final bool complete;
  final String summary;
  final String? error;
  final VoidCallback onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('reception-turn-${step.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SimQuestionBubble(
          key: Key('reception-question-${step.id}'),
          active: active,
          title: step.title,
          help: step.help,
        ),
        if (complete && summary.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _StudentSummaryBubble(
            key: Key('reception-answer-${step.id}'),
            text: summary,
            onEdit: onEdit,
          ),
        ],
        if (active) ...[
          const SizedBox(height: 10),
          _ActiveReplyBubble(
            key: Key('reception-active-${step.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                child,
                if (error != null) SimChatError(text: error!),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SimIntroBubble extends StatelessWidget {
  const _SimIntroBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SimLearningSurface(
          tone: SimSurfaceTone.selected,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, color: palette.primary, size: 18),
              const SizedBox(width: SimSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: palette.text, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimQuestionBubble extends StatelessWidget {
  const _SimQuestionBubble({
    required this.active,
    required this.title,
    required this.help,
    super.key,
  });

  final bool active;
  final String title;
  final String help;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SimLearningSurface(
          tone: active ? SimSurfaceTone.selected : SimSurfaceTone.soft,
          borderWidth: active ? 1.4 : 1,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SimTypography.lessonQuestion.copyWith(
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                help,
                style: SimTypography.muted.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentSummaryBubble extends StatelessWidget {
  const _StudentSummaryBubble({
    required this.text,
    required this.onEdit,
    super.key,
  });

  final String text;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SimLearningSurface(
          tone: SimSurfaceTone.success,
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SimTextAction(
                key: const Key('reception-edit-answer'),
                label: t('objective_edit'),
                onPressed: onEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveReplyBubble extends StatelessWidget {
  const _ActiveReplyBubble({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SimLearningSurface(
          tone: SimSurfaceTone.elevated,
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );
  }
}

class _TextStep extends StatelessWidget {
  const _TextStep({
    required this.controller,
    required this.label,
    required this.help,
    required this.onChanged,
    required this.onNext,
    this.textInputAction,
    this.optional = false,
  });

  final TextEditingController controller;
  final String label;
  final String help;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final TextInputAction? textInputAction;
  final bool optional;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SmallTextField(
        controller: controller,
        label: label,
        help: help,
        onChanged: onChanged,
        maxLines: 2,
        textInputAction: textInputAction,
      ),
      const SizedBox(height: 12),
      PrimaryWideButton(
        label: optional ? t('objective_skip') : t('objective_continue'),
        onPressed: onNext,
      ),
    ],
  );
}

class _ChoiceTextStep extends StatelessWidget {
  const _ChoiceTextStep({
    required this.controller,
    required this.label,
    required this.options,
    required this.onChanged,
    required this.onNext,
    this.focusNode,
    this.canAdvance = true,
    this.optional = false,
  });

  final TextEditingController controller;
  final String label;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final FocusNode? focusNode;
  final bool canAdvance;
  final bool optional;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SimChatFieldLabel(label),
      const SizedBox(height: 8),
      SimChatChoiceWrap(
        children: [
          for (final option in options)
            SimChatChoiceChip(
              label: option,
              selected: controller.text == option,
              onTap: () {
                controller.text = option;
                onChanged(option);
              },
            ),
        ],
      ),
      const SizedBox(height: 10),
      SimInput(
        controller: controller,
        hint: optional
            ? t('objective_optional_hint')
            : t('objective_custom_hint'),
        focusNode: focusNode,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          if (optional || canAdvance) onNext();
        },
        onChanged: onChanged,
      ),
      const SizedBox(height: 12),
      PrimaryWideButton(
        label: optional ? t('objective_skip') : t('objective_continue'),
        onPressed: optional || canAdvance ? onNext : null,
      ),
    ],
  );
}

class _SmallTextField extends StatelessWidget {
  const _SmallTextField({
    required this.controller,
    required this.label,
    required this.help,
    required this.onChanged,
    this.focusNode,
    this.errorText = '',
    this.textInputAction,
    this.onSubmitted,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String help;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final String errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SimChatFieldLabel(label),
        const SizedBox(height: 4),
        Text(help, style: SimTypography.caption.copyWith(color: palette.muted)),
        const SizedBox(height: 8),
        SimInput(
          controller: controller,
          hint: '',
          focusNode: focusNode,
          errorText: errorText.isEmpty ? null : errorText,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLines: maxLines,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ObjectiveStep extends StatelessWidget {
  const _ObjectiveStep({
    required this.objectiveController,
    required this.subjectController,
    required this.topicController,
    required this.objectiveFocus,
    required this.subjectFocus,
    required this.topicFocus,
    required this.path,
    required this.objectiveError,
    required this.onObjectiveChanged,
    required this.onSubjectChanged,
    required this.onTopicChanged,
    required this.onPathChanged,
    required this.onNext,
    required this.canAdvance,
  });

  final TextEditingController objectiveController;
  final TextEditingController subjectController;
  final TextEditingController topicController;
  final FocusNode objectiveFocus;
  final FocusNode subjectFocus;
  final FocusNode topicFocus;
  final PedagogicalReceptionPath path;
  final String objectiveError;
  final ValueChanged<String> onObjectiveChanged;
  final ValueChanged<String> onSubjectChanged;
  final ValueChanged<String> onTopicChanged;
  final ValueChanged<PedagogicalReceptionPath> onPathChanged;
  final VoidCallback onNext;
  final bool canAdvance;

  @override
  Widget build(BuildContext context) {
    final count = objectiveController.text.length;
    final overLimit = count > entryFormMaxFreeText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SimInput(
          key: const Key('reception-objective-input'),
          controller: objectiveController,
          focusNode: objectiveFocus,
          label: t('objective_field_label'),
          hint: t('objective_field_hint'),
          maxLines: 3,
          maxLength: entryFormMaxFreeText,
          textInputAction: TextInputAction.newline,
          errorText: objectiveError.isEmpty ? null : objectiveError,
          helperText: t('objective_chars', {
            'count': count,
            'max': entryFormMaxFreeText,
          }),
          onChanged: onObjectiveChanged,
        ),
        Text(
          t('objective_chars', {'count': count, 'max': entryFormMaxFreeText}),
          key: const Key('objective-character-counter'),
          style: SimTypography.caption.copyWith(
            color: SimThemeScope.paletteOf(context).muted,
          ),
        ),
        if (overLimit) SimChatError(text: t('objective_error_max')),
        const SizedBox(height: 12),
        _SmallTextField(
          key: const Key('reception-subject-input'),
          controller: subjectController,
          focusNode: subjectFocus,
          label: t('objective_subject_label'),
          help: t('objective_subject_hint'),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => topicFocus.requestFocus(),
          onChanged: onSubjectChanged,
        ),
        const SizedBox(height: 12),
        _SmallTextField(
          key: const Key('reception-topic-input'),
          controller: topicController,
          focusNode: topicFocus,
          label: t('objective_topic_label'),
          help: t('objective_topic_hint'),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (canAdvance) onNext();
          },
          onChanged: onTopicChanged,
        ),
        const SizedBox(height: 12),
        SimChatChoiceWrap(
          children: [
            SimChatChoiceChip(
              key: const Key('reception-guided-path'),
              label: t('objective_guided_aux'),
              selected: path == PedagogicalReceptionPath.guided,
              onTap: () => onPathChanged(PedagogicalReceptionPath.guided),
            ),
            SimChatChoiceChip(
              key: const Key('reception-material-path'),
              label: t('objective_material_aux'),
              selected: path == PedagogicalReceptionPath.material,
              onTap: () => onPathChanged(PedagogicalReceptionPath.material),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PrimaryWideButton(
          key: const Key('objective-primary-continue'),
          label: t('objective_continue'),
          onPressed: canAdvance ? onNext : null,
        ),
      ],
    );
  }
}

class _AttachmentsStep extends StatelessWidget {
  const _AttachmentsStep({
    required this.session,
    required this.errorText,
    required this.onPick,
    required this.onDescribeOnly,
    required this.onNext,
    required this.canAdvance,
  });

  final LabSession session;
  final String? errorText;
  final ValueChanged<String> onPick;
  final ValueChanged<bool> onDescribeOnly;
  final VoidCallback onNext;
  final bool canAdvance;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t('objective_attachment_limits'),
        style: SimTypography.caption.copyWith(
          color: SimThemeScope.paletteOf(context).muted,
        ),
      ),
      const SizedBox(height: 10),
      if (session.attachments.isEmpty)
        Text(t('objective_attachment_empty'))
      else
        AttachmentPreviewList(
          attachments: session.attachments,
          onRemove: session.removeAttachment,
        ),
      const SizedBox(height: 10),
      Material(
        color: Colors.transparent,
        child: CheckboxListTile(
          key: const Key('objective-describe-material-only'),
          contentPadding: EdgeInsets.zero,
          value: session.entryForm.describeMaterialWithoutAttachment,
          onChanged: (value) => onDescribeOnly(value ?? false),
          title: Text(t('objective_describe_instead')),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ),
      if (errorText != null && errorText!.trim().isNotEmpty)
        SimChatError(text: errorText!),
      const SizedBox(height: 10),
      AttachmentMenu(onPick: onPick),
      const SizedBox(height: 12),
      PrimaryWideButton(
        label: t('objective_continue'),
        onPressed: canAdvance ? onNext : null,
      ),
    ],
  );
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    required this.nameController,
    required this.ageController,
    required this.observationController,
    required this.ageFocus,
    required this.ageError,
    required this.ageNotDeclared,
    required this.onNameChanged,
    required this.onAgeChanged,
    required this.onAgeNotDeclared,
    required this.onObservationChanged,
    required this.onNext,
  });

  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController observationController;
  final FocusNode ageFocus;
  final String ageError;
  final bool ageNotDeclared;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onAgeChanged;
  final ValueChanged<bool> onAgeNotDeclared;
  final ValueChanged<String> onObservationChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SmallTextField(
        key: const Key('objective-name-input'),
        controller: nameController,
        label: t('objective_name_label'),
        help: t('objective_optional'),
        textInputAction: TextInputAction.next,
        onChanged: onNameChanged,
      ),
      const SizedBox(height: 12),
      _SmallTextField(
        key: const Key('objective-age-input'),
        controller: ageController,
        focusNode: ageFocus,
        label: t('objective_age_label'),
        help: t('objective_age_help'),
        errorText: ageError,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 3,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onNext(),
        onChanged: onAgeChanged,
      ),
      Material(
        color: Colors.transparent,
        child: CheckboxListTile(
          key: const Key('objective-age-not-declared'),
          contentPadding: EdgeInsets.zero,
          value: ageNotDeclared,
          onChanged: (value) => onAgeNotDeclared(value ?? false),
          title: Text(t('objective_age_not_declared')),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ),
      const SizedBox(height: 12),
      _SmallTextField(
        key: const Key('objective-observation-input'),
        controller: observationController,
        label: t('objective_observation_label'),
        help: t('objective_observation_help'),
        maxLines: 2,
        textInputAction: TextInputAction.newline,
        onChanged: onObservationChanged,
      ),
      const SizedBox(height: 12),
      PrimaryWideButton(label: t('objective_skip'), onPressed: onNext),
    ],
  );
}
