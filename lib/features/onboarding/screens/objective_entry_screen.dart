part of '../onboarding_screens.dart';

class _EntryScreen extends StatefulWidget {
  const _EntryScreen({required this.session});

  final LabSession session;

  @override
  State<_EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<_EntryScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController objectiveController;
  late final TextEditingController subjectController;
  late final TextEditingController topicController;
  late final TextEditingController nameController;
  late final TextEditingController levelController;
  late final TextEditingController purposeController;
  late final TextEditingController deadlineController;
  late final TextEditingController resultController;
  late final TextEditingController blockerController;
  late final TextEditingController preferenceController;
  late final TextEditingController materialTypeController;
  late final TextEditingController ageController;
  late final TextEditingController observationController;
  late final FocusNode objectiveFocus;
  late final FocusNode subjectFocus;
  late final FocusNode topicFocus;
  late final FocusNode levelFocus;
  late final FocusNode purposeFocus;
  late final FocusNode ageFocus;
  late final PedagogicalReceptionController reception;
  late final ObjectiveEntryViewModel viewModel;
  final scrollController = ScrollController();
  final blockKeys = <String, GlobalKey>{};
  String? error;

  LabSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    objectiveController = TextEditingController(text: session.freeText);
    subjectController = TextEditingController(text: session.entryForm.subject);
    topicController = TextEditingController(text: session.entryForm.topic);
    nameController = TextEditingController(text: session.preferredName);
    levelController = TextEditingController(text: session.academicLevel);
    purposeController = TextEditingController(text: session.traversalGoal);
    deadlineController = TextEditingController(text: session.deadline);
    resultController = TextEditingController(text: session.expectedResult);
    blockerController = TextEditingController(text: session.difficulties);
    preferenceController = TextEditingController(
      text: session.learningPreference,
    );
    materialTypeController = TextEditingController(text: session.materialType);
    ageController = TextEditingController(text: session.studentAge);
    observationController = TextEditingController(
      text: session.profileObservation,
    );
    objectiveFocus = FocusNode();
    subjectFocus = FocusNode();
    topicFocus = FocusNode();
    levelFocus = FocusNode();
    purposeFocus = FocusNode();
    ageFocus = FocusNode();
    if (session.entryForm.entryPath.trim().isEmpty) {
      session.entryForm.entryPath = 'guided_path';
    }
    reception = PedagogicalReceptionController(form: session.entryForm)
      ..addListener(_handleReceptionChanged);
    viewModel = ObjectiveEntryViewModel(session: session, reception: reception);
    session.addListener(_syncFromSession);
  }

  void _handleReceptionChanged() {
    if (!mounted) return;
    setState(() => error = reception.error);
    if (reception.error == null) _scrollToActive();
    if (reception.error != null) _focusCurrentError();
  }

  void _syncFromSession() {
    if (!mounted) return;
    _syncText(objectiveController, session.freeText, objectiveFocus);
    _syncText(subjectController, session.entryForm.subject, subjectFocus);
    _syncText(topicController, session.entryForm.topic, topicFocus);
    _syncText(nameController, session.preferredName);
    _syncText(levelController, session.academicLevel, levelFocus);
    _syncText(purposeController, session.traversalGoal, purposeFocus);
    _syncText(deadlineController, session.deadline);
    _syncText(resultController, session.expectedResult);
    _syncText(blockerController, session.difficulties);
    _syncText(preferenceController, session.learningPreference);
    _syncText(materialTypeController, session.materialType);
    _syncText(ageController, session.studentAge, ageFocus);
    _syncText(observationController, session.profileObservation);
    setState(() {});
  }

  void _syncText(
    TextEditingController controller,
    String value, [
    FocusNode? focusNode,
  ]) {
    if (controller.text == value || focusNode?.hasFocus == true) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _pickAttachment(String source) async {
    final message = await session.pickLabAttachment(source);
    if (!mounted) return;
    setState(() => error = message);
  }

  bool _next() {
    final advanced = viewModel.advance();
    if (!advanced) _focusCurrentError();
    return advanced;
  }

  void _focusCurrentError() {
    final current = reception.steps[reception.activeIndex].id;
    if (current == 'objective') objectiveFocus.requestFocus();
    if (current == 'level') levelFocus.requestFocus();
    if (current == 'purpose' || current == 'material_purpose') {
      purposeFocus.requestFocus();
    }
    if (current == 'profile' && reception.errorFor('age').isNotEmpty) {
      ageFocus.requestFocus();
    }
  }

  void _scrollToActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final step = reception.steps[reception.activeIndex];
      final context = blockKeys[step.id]?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  void _submit() {
    final validation = viewModel.validateActiveStep();
    if (validation != null) {
      setState(() => error = validation);
      _focusCurrentError();
      return;
    }
    final ok = viewModel.submitObjectiveEntry();
    setState(() => error = ok ? null : t('objective_error_min'));
  }

  @override
  void dispose() {
    session.removeListener(_syncFromSession);
    reception.removeListener(_handleReceptionChanged);
    reception.dispose();
    scrollController.dispose();
    for (final controller in [
      objectiveController,
      subjectController,
      topicController,
      nameController,
      levelController,
      purposeController,
      deadlineController,
      resultController,
      blockerController,
      preferenceController,
      materialTypeController,
      ageController,
      observationController,
    ]) {
      controller.dispose();
    }
    for (final node in [
      objectiveFocus,
      subjectFocus,
      topicFocus,
      levelFocus,
      purposeFocus,
      ageFocus,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final palette = SimThemeScope.paletteOf(context);
    final visibleSteps = viewModel.visibleSteps;
    final progressLabel = t('objective_step_of', {
      'n': reception.activeStepNumber,
      'total': reception.totalStepCount,
    });
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: SimBreakpoints.learningMaxWidth(width),
            ),
            child: Form(
              key: formKey,
              child: Semantics(
                label: t('objective_screen_title'),
                value: t('objective_progress_semantics', {
                  'n': reception.activeStepNumber,
                  'total': reception.totalStepCount,
                  'title': reception.steps[reception.activeIndex].title,
                }),
                explicitChildNodes: true,
                child: ListView(
                  key: const Key('pedagogical-reception-scroll'),
                  controller: scrollController,
                  padding: SimBreakpoints.pagePadding(
                    width,
                  ).copyWith(top: 20, bottom: 28),
                  children: [
                    StepHeader(
                      title: t('objective_screen_title'),
                      subtitle: t('objective_screen_subtitle'),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      label: progressLabel,
                      liveRegion: true,
                      child: Text(
                        progressLabel,
                        key: const Key('objective-progress-label'),
                        style: SimTypography.caption.copyWith(
                          color: palette.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SimIntroBubble(text: t('objective_intro')),
                    const SizedBox(height: 12),
                    for (var i = 0; i < visibleSteps.length; i++) ...[
                      _ReceptionBlock(
                        key: blockKeys.putIfAbsent(
                          visibleSteps[i].id,
                          () => GlobalKey(),
                        ),
                        step: visibleSteps[i],
                        active: i == reception.activeIndex,
                        complete: i < reception.activeIndex,
                        summary: viewModel.summaryFor(visibleSteps[i].id),
                        error:
                            i == reception.activeIndex &&
                                visibleSteps[i].id != 'objective' &&
                                visibleSteps[i].id != 'profile'
                            ? error
                            : null,
                        onEdit: () => viewModel.edit(visibleSteps[i].id),
                        child: _stepBody(visibleSteps[i].id),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody(String id) {
    switch (id) {
      case 'objective':
        return _ObjectiveStep(
          objectiveController: objectiveController,
          subjectController: subjectController,
          topicController: topicController,
          objectiveFocus: objectiveFocus,
          subjectFocus: subjectFocus,
          topicFocus: topicFocus,
          path: reception.path,
          objectiveError: reception.errorFor('objective'),
          onObjectiveChanged: (value) {
            session.setFreeText(value);
            if (value.length <= entryFormMaxFreeText) {
              reception.fieldErrors.remove('objective');
            }
          },
          onSubjectChanged: (value) =>
              session.setPedagogicalEntryField('subject', value),
          onTopicChanged: (value) =>
              session.setPedagogicalEntryField('topic', value),
          onPathChanged: reception.choosePath,
          onNext: _next,
          canAdvance: reception.stepCanAdvance('objective'),
        );
      case 'level':
        return _ChoiceTextStep(
          controller: levelController,
          focusNode: levelFocus,
          label: t('objective_level_title'),
          options: [
            t('objective_level_zero'),
            t('objective_level_fundamental'),
            t('objective_level_medio'),
            t('objective_level_college'),
            t('objective_level_work'),
          ],
          onChanged: (value) =>
              session.setPedagogicalEntryField('academic_level', value),
          onNext: _next,
          canAdvance: reception.stepCanAdvance('level'),
        );
      case 'purpose':
        return _ChoiceTextStep(
          controller: purposeController,
          focusNode: purposeFocus,
          label: t('objective_purpose_title'),
          options: [
            t('objective_purpose_exam'),
            t('objective_purpose_homework'),
            t('objective_purpose_work'),
            t('objective_purpose_self'),
            t('objective_purpose_contest'),
            t('objective_purpose_unknown'),
          ],
          onChanged: (value) =>
              session.setPedagogicalEntryField('traversal_goal', value),
          onNext: _next,
          canAdvance: reception.stepCanAdvance('purpose'),
        );
      case 'deadline':
        return _ChoiceTextStep(
          controller: deadlineController,
          label: t('objective_deadline_title'),
          options: [
            t('objective_deadline_none'),
            t('objective_deadline_today'),
            t('objective_deadline_week'),
            t('objective_deadline_month'),
          ],
          onChanged: (value) =>
              session.setPedagogicalEntryField('deadline', value),
          onNext: _next,
          optional: true,
          canAdvance: true,
        );
      case 'result':
        return _TextStep(
          controller: resultController,
          label: t('objective_result_title'),
          help: t('objective_result_help'),
          onChanged: (value) =>
              session.setPedagogicalEntryField('expected_result', value),
          onNext: _next,
          optional: true,
          textInputAction: TextInputAction.done,
        );
      case 'blocker':
        return _TextStep(
          controller: blockerController,
          label: t('objective_blocker_title'),
          help: t('objective_blocker_help'),
          onChanged: (value) =>
              session.setPedagogicalEntryField('difficulties', value),
          onNext: _next,
          optional: true,
          textInputAction: TextInputAction.done,
        );
      case 'style':
        return _ChoiceTextStep(
          controller: preferenceController,
          label: t('objective_style_title'),
          options: [
            t('objective_style_step'),
            t('objective_style_examples'),
            t('objective_style_exercises'),
            t('objective_style_review'),
            t('objective_style_direct'),
          ],
          onChanged: (value) =>
              session.setPedagogicalEntryField('learning_preference', value),
          onNext: _next,
          optional: true,
          canAdvance: true,
        );
      case 'material_type':
        return _ChoiceTextStep(
          controller: materialTypeController,
          label: t('objective_material_type_title'),
          options: [
            t('objective_material_photo'),
            t('objective_material_pdf'),
            t('objective_material_list'),
            t('objective_material_exam'),
            t('objective_material_question'),
            t('objective_material_attempt'),
          ],
          onChanged: (value) =>
              session.setPedagogicalEntryField('material_type', value),
          onNext: _next,
          canAdvance: reception.stepCanAdvance('material_type'),
        );
      case 'attachments':
        return _AttachmentsStep(
          session: session,
          errorText: error,
          onPick: _pickAttachment,
          onDescribeOnly: (value) {
            session.setPedagogicalEntryField(
              'material_description_only',
              value.toString(),
            );
          },
          onNext: _next,
          canAdvance: reception.stepCanAdvance('attachments'),
        );
      case 'material_purpose':
        return _ChoiceTextStep(
          controller: purposeController,
          focusNode: purposeFocus,
          label: t('objective_material_purpose_title'),
          options: [
            t('objective_purpose_exam'),
            t('objective_purpose_homework'),
            t('objective_material_list'),
            t('objective_style_review'),
            t('objective_material_question'),
          ],
          onChanged: (value) =>
              session.setPedagogicalEntryField('traversal_goal', value),
          onNext: _next,
          canAdvance: reception.stepCanAdvance('material_purpose'),
        );
      case 'profile':
        return _ProfileStep(
          nameController: nameController,
          ageController: ageController,
          observationController: observationController,
          ageFocus: ageFocus,
          ageError: reception.errorFor('age'),
          ageNotDeclared: session.entryForm.ageNotDeclared,
          onNameChanged: session.setPreferredName,
          onAgeChanged: (value) {
            session.setStudentAge(value);
            reception.fieldErrors.remove('age');
          },
          onAgeNotDeclared: (value) {
            session.submitStudentAge(notDeclared: value);
            if (value) ageController.clear();
            reception.fieldErrors.remove('age');
          },
          onObservationChanged: session.setProfileObservation,
          onNext: _next,
        );
      case 'finish':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FinishSummary(lines: viewModel.finalSummaryLines()),
            const SizedBox(height: 14),
            PrimaryWideButton(
              key: const Key('reception-submit'),
              label: t('objective_submit'),
              onPressed: _submit,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
