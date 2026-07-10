// ignore_for_file: unused_import, unnecessary_import
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../sim/billing/sim_server_billing_clients.dart';
import '../../sim/cloud/sim_server_cloud_functions.dart';
import '../../sim/cloud/supabase_flutter_session_provider.dart';
import '../../sim/cloud/supabase_student_state_cloud_storage.dart';
import '../../sim/config/sim_environment.dart';
import '../../sim/external_ai/sim_ai_server_config.dart';
import '../../sim/external_ai/sim_server_ai_clients.dart';
import '../../sim/external_ai/sim_server_attachment_client.dart';
import '../../sim/classroom/classroom_models.dart';
import '../../sim/classroom/lesson_runtime_engine.dart';
import '../../sim/classroom/lesson_main_view_model.dart';
import '../../sim/experience/student_experience_types.dart';
import '../../sim/organism/sim_organism.dart';
import '../../sim/organism/sim_organism_provider.dart';
import '../../session/auth_session.dart';
import '../../session/entry_form_state.dart';
import '../../session/lesson_ui_state.dart';
import '../../session/navigation_state.dart';
import '../../sim/lesson/lesson_models.dart';
import '../../sim/media/audio_core.dart';
import '../../sim/media/audio_preference.dart';
import '../../sim/media/lesson_audio_controller.dart';
import '../../sim/media/student_lesson_media_service.dart';
import '../../sim/state/shared_prefs_state_storage.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/state/student_state_store.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/sim_theme.dart';
import '../../sim/ui/widgets/cyber_step_shell.dart';
import '../../sim/ui/widgets/sim_preparation_experience.dart';
import '../../sim/ui/widgets/sim_typewriter.dart';
import '../../sim/auxiliary/aux_room_models.dart';
import '../../sim/ui/widgets/doubt_progress_bar.dart';

import '../../core/utils/sim_constants.dart';
import '../session/lab_session.dart';
import '../portal/portal_flow.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screens.dart';
import '../onboarding/preparation_and_placement.dart';
import '../classroom/aula_screen.dart';
import '../classroom/aux_room_screens.dart';
import '../classroom/aula_widgets.dart';
import '../billing/billing_and_simple_pages.dart';
import '../../shared/widgets/shared_widgets.dart';

class IdiomaScreen extends StatefulWidget {
  const IdiomaScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<IdiomaScreen> createState() => _IdiomaScreenState();
}

class _IdiomaScreenState extends State<IdiomaScreen> {
  void _pick(String code, String name) {
    if (code == 'other') {
      widget.session.chooseLanguage(code, widget.session.otherLanguage.trim());
    } else {
      widget.session.chooseLanguage(code, name);
      Future.delayed(const Duration(milliseconds: 160), () {
        if (mounted) {
          // navigation is handled by session state change â€” just trigger it
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return CyberStepShell(
      step: 1,
      total: 5,
      child: OnboardingChatFlow(
        semanticLabel: t('onboarding_chat_region'),
        children: [
          SimChatReveal(
            child: SimChatBubble(
              text: t('language_chat_intro'),
              supportingText: t('language_body'),
            ),
          ),
          SimChatReveal(
            delay: const Duration(milliseconds: 80),
            child: SimChatBubble(
              text: t('language_app_title'),
              supportingText: t('language_app_body'),
            ),
          ),
          SimChatChoiceWrap.staggered(
            children: [
              SimChatChoiceChip(
                label: t('language_follow_device'),
                selected: session.localeSettings.followDeviceInterface,
                onTap: () =>
                    unawaited(session.setInterfaceLanguage(followDevice: true)),
              ),
              for (final language in supportedLangs.where(
                (lang) => const {'pt', 'en', 'es'}.contains(lang.code),
              ))
                SimChatChoiceChip(
                  label: language.native.isEmpty
                      ? language.name
                      : '${language.native} · ${language.name}',
                  selected:
                      !session.localeSettings.followDeviceInterface &&
                      session.interfaceLocaleTag ==
                          switch (language.code) {
                            'pt' => 'pt-BR',
                            'es' => 'es',
                            _ => 'en',
                          },
                  onTap: () => unawaited(
                    session.setInterfaceLanguage(
                      followDevice: false,
                      localeTag: language.code,
                    ),
                  ),
                ),
            ],
          ),
          SimChatReveal(
            delay: const Duration(milliseconds: 120),
            child: SimChatBubble(
              text: t('language_lessons_title'),
              supportingText: t('language_lessons_body'),
            ),
          ),
          SimChatChoiceWrap.staggered(
            children: [
              for (final language in supportedLangs.where(
                (lang) => const {'pt', 'en', 'es'}.contains(lang.code),
              ))
                SimChatChoiceChip(
                  label: language.native.isEmpty
                      ? language.name
                      : '${language.native} · ${language.name}',
                  selected:
                      session.learningLocaleTag ==
                      switch (language.code) {
                        'pt' => 'pt-BR',
                        'es' => 'es',
                        _ => 'en',
                      },
                  onTap: () => _pick(language.code, language.name),
                ),
              SimChatChoiceChip(
                label: t('language_other'),
                selected: session.selectedLanguageCode == 'other',
                onTap: () => _pick('other', session.otherLanguage.trim()),
              ),
            ],
          ),
          if (session.selectedLanguageCode == 'other') ...[
            const SizedBox(height: 8),
            SimChatReveal(
              delay: const Duration(milliseconds: 120),
              child: OtherLanguageBox(session: session),
            ),
          ],
        ],
      ),
    );
  }
}

class OtherLanguageBox extends StatefulWidget {
  const OtherLanguageBox({required this.session, super.key});

  final LabSession session;

  @override
  State<OtherLanguageBox> createState() => _OtherLanguageBoxState();
}

class _OtherLanguageBoxState extends State<OtherLanguageBox> {
  late final TextEditingController controller = TextEditingController(
    text: widget.session.otherLanguage,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.text.trim();
    return SimChatInputCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SimChatFieldLabel(t('language_type')),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: t('language_hint'),
              border: InputBorder.none,
            ),
            style: const TextStyle(fontSize: 18),
            onChanged: (v) {
              widget.session.setOtherLanguage(v);
              setState(() {});
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: value.isEmpty
                    ? null
                    : () => widget.session.chooseLanguage('other', value),
                child: Text(t('continue')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConversationalEntryScreen extends StatefulWidget {
  const ConversationalEntryScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<ConversationalEntryScreen> createState() =>
      _ConversationalEntryScreenState();
}

class _ConversationalEntryScreenState extends State<ConversationalEntryScreen> {
  bool languageMenuOpen = false;
  bool attachmentMenuOpen = false;
  bool sending = false;
  String? error;
  late final TextEditingController nameController = TextEditingController(
    text: widget.session.preferredName,
  );
  late final TextEditingController ageController = TextEditingController(
    text: widget.session.studentAge,
  );
  late final TextEditingController observationController =
      TextEditingController(text: widget.session.profileObservation);
  late final TextEditingController objectiveController = TextEditingController(
    text: widget.session.freeText,
  );
  late final TextEditingController materialNotesController =
      TextEditingController(text: widget.session.freeText);
  late final TextEditingController topicController = TextEditingController(
    text: widget.session.topic,
  );
  late final TextEditingController levelController = TextEditingController(
    text: widget.session.academicLevel,
  );

  bool get waitingAttachment => widget.session.attachments.any(
    (a) => a.status == 'uploading' || a.status == 'processing',
  );
  bool get objectiveReady => widget.session.freeText.trim().length >= 10;
  bool get canPrepare => !sending && !waitingAttachment && objectiveReady;

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    observationController.dispose();
    objectiveController.dispose();
    materialNotesController.dispose();
    topicController.dispose();
    levelController.dispose();
    super.dispose();
  }

  Future<void> _selectLanguage(_EntryLanguageOption option) async {
    if (option.followDevice) {
      await widget.session.setInterfaceLanguage(followDevice: true);
      await widget.session.setLearningLanguage(
        localeTag: widget.session.interfaceLocaleTag,
      );
    } else {
      await widget.session.setInterfaceLanguage(
        followDevice: false,
        localeTag: option.localeTag,
      );
      await widget.session.setLearningLanguage(localeTag: option.localeTag);
    }
    if (mounted) setState(() => languageMenuOpen = false);
  }

  void _setEntryField(String key, String value) {
    widget.session.setPedagogicalEntryField(key, value);
    setState(() => error = null);
  }

  void _setObjective(String value) {
    widget.session.setFreeText(value);
    setState(() => error = null);
  }

  int _group1Step(LabSession session) {
    if (!session.profileNameSubmitted) return 0;
    if (!session.profileAgeSubmitted) return 1;
    if (!session.profileDifficultiesSubmitted) return 2;
    if (!session.profileObservationSubmitted) return 3;
    return 4;
  }

  void _submitName() {
    if (widget.session.preferredName.trim().isEmpty) return;
    widget.session.submitProfileName();
    setState(() => error = null);
  }

  void _submitAge({bool notDeclared = false}) {
    widget.session.submitStudentAge(notDeclared: notDeclared);
    setState(() => error = null);
  }

  void _submitDifficulties() {
    widget.session.submitProfileDifficulties();
    setState(() => error = null);
  }

  void _submitObservation({bool skipped = false}) {
    widget.session.submitProfileObservation(skipped: skipped);
    if (skipped) observationController.clear();
    setState(() => error = null);
  }

  void _ensureObjectiveSeed(String materialLabel) {
    if (widget.session.freeText.trim().length >= 10) return;
    final seed =
        'Tenho material: $materialLabel. Quero que o SIM interprete e prepare minha aula.';
    widget.session.setFreeText(seed);
    objectiveController.text = seed;
    materialNotesController.text = seed;
  }

  void _submitSimLearningGoal() {
    if (widget.session.topic.trim().isEmpty) return;
    final goal = widget.session.topic.trim();
    if (widget.session.freeText.trim().length < 10) {
      widget.session.setFreeText('Quero aprender: $goal.');
      objectiveController.text = widget.session.freeText;
    }
    widget.session.submitSimLearningGoal();
    setState(() => error = null);
  }

  void _submitSimLearningLevel() {
    if (widget.session.academicLevel.trim().isEmpty) return;
    widget.session.submitSimLearningLevel();
    setState(() => error = null);
  }

  Future<void> _addAttachment(String source, String materialLabel) async {
    if (widget.session.attachments.length >= maxAttachments) {
      setState(() => error = 'attachment_limit');
      return;
    }
    _setEntryField('entry_path', 'tenho_material');
    _setEntryField('material_type', materialLabel);
    _ensureObjectiveSeed(materialLabel);
    setState(() {
      attachmentMenuOpen = false;
      error = null;
    });
    final pickError = await widget.session.pickLabAttachment(source);
    if (!mounted || pickError == null) return;
    setState(() => error = pickError);
  }

  Future<void> _prepareLesson() async {
    if (waitingAttachment) return;
    if (!objectiveReady) {
      setState(() => error = 'objective_required');
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 120));
    widget.session.saveObjectiveEntry();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final palette = SimThemeScope.paletteOf(context);
    final ficha = session.buildPedagogicalFicha();
    final path = session.entryPath;
    final isMaterialPath = path == 'tenho_material';
    final isSimPath = path == 'sim_monta';
    final group1Step = _group1Step(session);
    final group1Complete = group1Step >= 4;
    final simPathReady =
        isSimPath &&
        session.simLearningGoalSubmitted &&
        session.simLearningLevelSubmitted;
    final materialPathReady =
        isMaterialPath &&
        (session.materialType.trim().isNotEmpty ||
            session.attachments.isNotEmpty ||
            session.freeText.trim().length >= 10);
    final showSummary = simPathReady || materialPathReady;
    return CyberStepShell(
      step: 1,
      total: 5,
      child: OnboardingChatFlow(
        semanticLabel: t('onboarding_chat_region'),
        children: [
          _TimelineTurn(
            number: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SimChatBubble(
                  text: 'SIM: Em que idioma você quer usar o SIM?',
                ),
                const SizedBox(height: 10),
                _LanguageSelector(
                  session: session,
                  expanded: languageMenuOpen,
                  onToggle: () =>
                      setState(() => languageMenuOpen = !languageMenuOpen),
                  onSelect: (option) => unawaited(_selectLanguage(option)),
                ),
              ],
            ),
          ),
          _TimelineTurn(
            number: 2,
            child: _ProfileNameCard(
              controller: nameController,
              active: group1Step == 0,
              completed: session.profileNameSubmitted,
              onChanged: (value) {
                session.setPreferredName(value);
                setState(() {});
              },
              onSubmit: _submitName,
            ),
          ),
          if (group1Step >= 1)
            _TimelineTurn(
              number: 3,
              child: _ProfileAgeCard(
                controller: ageController,
                active: group1Step == 1,
                completed: session.profileAgeSubmitted,
                ageNotDeclared: session.ageNotDeclared,
                onChanged: (value) {
                  session.setStudentAge(value);
                  setState(() {});
                },
                onSubmit: () => _submitAge(),
                onSkip: () => _submitAge(notDeclared: true),
              ),
            ),
          if (group1Step >= 2)
            _TimelineTurn(
              number: 4,
              child: _ProfileDifficultiesCard(
                selected: session.profileDifficulties,
                active: group1Step == 2,
                completed: session.profileDifficultiesSubmitted,
                onToggle: (value) {
                  session.toggleProfileDifficulty(value);
                  setState(() {});
                },
                onSubmit: _submitDifficulties,
              ),
            ),
          if (group1Step >= 3)
            _TimelineTurn(
              number: 5,
              child: _ProfileObservationCard(
                controller: observationController,
                active: group1Step == 3,
                completed: session.profileObservationSubmitted,
                onChanged: (value) {
                  session.setProfileObservation(value);
                  setState(() {});
                },
                onSubmit: () => _submitObservation(),
                onSkip: () => _submitObservation(skipped: true),
              ),
            ),
          if (group1Complete)
            _TimelineTurn(
              number: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SimChatBubble(
                    text:
                        'SIM: Você já tem algo para me mostrar ou quer que eu monte o caminho?',
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 520;
                      final simButton = _EntryPathButton(
                        icon: Icons.account_tree_outlined,
                        title: 'Quero que o SIM monte minhas aulas',
                        description:
                            'Conte o que você precisa aprender. O SIM organiza o plano, cria microaulas e exercícios para te conduzir do ponto certo até o objetivo.',
                        shortPhrase:
                            'Você diz o objetivo. O SIM monta o caminho.',
                        selected: isSimPath,
                        onTap: () => _setEntryField('entry_path', 'sim_monta'),
                      );
                      final materialButton = _EntryPathButton(
                        icon: Icons.photo_camera_outlined,
                        title: 'Quero mostrar meu material ao SIM',
                        description:
                            'Envie foto, lista, livro, caderno, prova, PDF, questão ou resposta que tentou fazer. O SIM olha seu material e te ensina a resolver aquilo.',
                        shortPhrase:
                            'Você mostra o material. O SIM te ajuda com ele.',
                        selected: isMaterialPath,
                        onTap: () =>
                            _setEntryField('entry_path', 'tenho_material'),
                      );
                      if (narrow) {
                        return Column(
                          children: [
                            SizedBox(width: double.infinity, child: simButton),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: materialButton,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: simButton),
                          const SizedBox(width: 10),
                          Expanded(child: materialButton),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          if (group1Complete && isMaterialPath)
            _TimelineTurn(
              number: 7,
              child: _MaterialPathCard(
                session: session,
                attachmentMenuOpen: attachmentMenuOpen,
                notesController: materialNotesController,
                onToggleAttachmentMenu: () =>
                    setState(() => attachmentMenuOpen = !attachmentMenuOpen),
                onPickAttachment: _addAttachment,
                onMaterialType: (value) {
                  _setEntryField('material_type', value);
                  _ensureObjectiveSeed(value);
                },
                onNotesChanged: _setObjective,
                onRemoveAttachment: (index) =>
                    setState(() => session.removeAttachment(index)),
              ),
            ),
          if (group1Complete && isSimPath)
            _TimelineTurn(
              number: 7,
              child: _SimBuildPathCard(
                session: session,
                topicController: topicController,
                levelController: levelController,
                onField: _setEntryField,
                onGoalChanged: (value) {
                  _setEntryField('topic', value);
                  if (value.trim().isNotEmpty) {
                    _setObjective('Quero aprender: ${value.trim()}.');
                  }
                },
                onSubmitGoal: _submitSimLearningGoal,
                onSubmitLevel: _submitSimLearningLevel,
              ),
            ),
          if (group1Complete && showSummary)
            _TimelineTurn(
              number: 8,
              child: _FichaSummaryCard(
                ficha: ficha,
                canPrepare: canPrepare,
                sending: sending,
                error: error == null ? null : t(error!),
                onPrepare: _prepareLesson,
              ),
            ),
          if (group1Complete)
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Text(
                'Uma timeline. Duas entradas fortes. Uma ficha pedagógica estruturada.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryLanguageOption {
  const _EntryLanguageOption({
    required this.label,
    required this.localeTag,
    this.followDevice = false,
  });

  final String label;
  final String localeTag;
  final bool followDevice;
}

const List<_EntryLanguageOption> _entryLanguageOptions = [
  _EntryLanguageOption(
    label: 'Seguir dispositivo',
    localeTag: 'pt-BR',
    followDevice: true,
  ),
  _EntryLanguageOption(label: 'Português', localeTag: 'pt-BR'),
  _EntryLanguageOption(label: 'English', localeTag: 'en'),
  _EntryLanguageOption(label: 'Español', localeTag: 'es'),
  _EntryLanguageOption(label: 'Français', localeTag: 'fr'),
  _EntryLanguageOption(label: 'Deutsch', localeTag: 'de'),
  _EntryLanguageOption(label: 'Italiano', localeTag: 'it'),
];

String _entryLanguageLabel(String localeTag) {
  return switch (localeTag) {
    'en' => 'English',
    'es' => 'Español',
    'fr' => 'Français',
    'de' => 'Deutsch',
    'it' => 'Italiano',
    _ => 'Português',
  };
}

class _TimelineTurn extends StatelessWidget {
  const _TimelineTurn({required this.number, required this.child});

  final int number;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.surface,
                  border: Border.all(color: palette.primary, width: 1.4),
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: palette.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(width: 1, height: 72, color: palette.border),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.session,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  final LabSession session;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<_EntryLanguageOption> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final current = _entryLanguageLabel(session.learningLocaleTag);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              key: const Key('sim-entry-language-button'),
              onPressed: onToggle,
              icon: const Icon(Icons.language),
              label: Text('$current  ▾'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(180, 52),
                foregroundColor: palette.text,
                side: BorderSide(color: palette.border),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              Material(
                elevation: 8,
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 292),
                  child: ListView(
                    key: const Key('sim-entry-language-list'),
                    shrinkWrap: true,
                    children: [
                      for (final option in _entryLanguageOptions)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            option.followDevice
                                ? Icons.phone_android
                                : Icons.language,
                          ),
                          title: Text(option.label),
                          trailing:
                              !option.followDevice &&
                                  option.localeTag == session.learningLocaleTag
                              ? Icon(Icons.check, color: palette.primary)
                              : null,
                          onTap: () => onSelect(option),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileNameCard extends StatelessWidget {
  const _ProfileNameCard({
    required this.controller,
    required this.active,
    required this.completed,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool active;
  final bool completed;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _SequentialProfileCard(
      question: 'Como posso chamar você?',
      active: active,
      completed: completed,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('sim-entry-name-input'),
              controller: controller,
              enabled: active && !completed,
              decoration: const InputDecoration(
                hintText: 'Digite nome ou apelido...',
                border: OutlineInputBorder(),
              ),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
          _InlineSendButton(
            key: const Key('sim-entry-name-submit'),
            enabled: active && !completed && controller.text.trim().isNotEmpty,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _ProfileAgeCard extends StatelessWidget {
  const _ProfileAgeCard({
    required this.controller,
    required this.active,
    required this.completed,
    required this.ageNotDeclared,
    required this.onChanged,
    required this.onSubmit,
    required this.onSkip,
  });

  final TextEditingController controller;
  final bool active;
  final bool completed;
  final bool ageNotDeclared;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return _SequentialProfileCard(
      question: 'Quer me dizer sua idade? Pode pular.',
      active: active,
      completed: completed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('sim-entry-age-input'),
                  controller: controller,
                  enabled: active && !completed && !ageNotDeclared,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: ageNotDeclared
                        ? 'Prefiro não declarar'
                        : 'Digite sua idade...',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 8),
              _InlineSendButton(
                key: const Key('sim-entry-age-submit'),
                enabled:
                    active &&
                    !completed &&
                    (controller.text.trim().isNotEmpty || ageNotDeclared),
                onPressed: onSubmit,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('sim-entry-age-skip'),
            onPressed: active && !completed ? onSkip : null,
            child: const Text('Prefiro não declarar'),
          ),
        ],
      ),
    );
  }
}

class _ProfileDifficultiesCard extends StatelessWidget {
  const _ProfileDifficultiesCard({
    required this.selected,
    required this.active,
    required this.completed,
    required this.onToggle,
    required this.onSubmit,
  });

  static const options = [
    'Falta de base',
    'Concentração',
    'Esqueço rápido',
    'Travo em exercícios',
    'Leio e não entendo',
    'Fico nervoso em prova',
    'Erro conta',
    'Não sei por onde começar',
    'Não sei dizer',
  ];

  final List<String> selected;
  final bool active;
  final bool completed;
  final ValueChanged<String> onToggle;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _SequentialProfileCard(
      question: 'Quando você estuda, o que mais atrapalha?',
      active: active,
      completed: completed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in options)
                _CompactCheckOption(
                  label: option,
                  selected: selected.contains(option),
                  enabled: active && !completed,
                  onTap: () => onToggle(option),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: _InlineSendButton(
              key: const Key('sim-entry-difficulty-submit'),
              enabled: active && !completed && selected.isNotEmpty,
              onPressed: onSubmit,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileObservationCard extends StatelessWidget {
  const _ProfileObservationCard({
    required this.controller,
    required this.active,
    required this.completed,
    required this.onChanged,
    required this.onSubmit,
    required this.onSkip,
  });

  final TextEditingController controller;
  final bool active;
  final bool completed;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return _SequentialProfileCard(
      question: 'Quer me contar algo que ajude o SIM a te orientar melhor?',
      active: active,
      completed: completed,
      child: Column(
        children: [
          TextField(
            key: const Key('sim-entry-observation-input'),
            controller: controller,
            enabled: active && !completed,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Escreva do seu jeito...',
              border: OutlineInputBorder(),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                key: const Key('sim-entry-observation-skip'),
                onPressed: active && !completed ? onSkip : null,
                child: const Text('Pular'),
              ),
              const Spacer(),
              _InlineSendButton(
                key: const Key('sim-entry-observation-submit'),
                enabled: active && !completed,
                onPressed: onSubmit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SequentialProfileCard extends StatelessWidget {
  const _SequentialProfileCard({
    required this.question,
    required this.active,
    required this.completed,
    required this.child,
  });

  final String question;
  final bool active;
  final bool completed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final content = SimChatInputCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SIM: $question',
            style: TextStyle(
              color: palette.text,
              fontSize: 16,
              height: 1.28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
    return Opacity(
      opacity: completed ? 0.55 : 1,
      child: IgnorePointer(ignoring: completed, child: content),
    );
  }
}

class _InlineSendButton extends StatelessWidget {
  const _InlineSendButton({
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return IconButton.filled(
      tooltip: 'Enviar resposta',
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.arrow_forward),
      color: palette.onPrimary,
      style: IconButton.styleFrom(
        backgroundColor: palette.primary,
        disabledBackgroundColor: palette.surfaceSoft,
        minimumSize: const Size(SimTouch.min, SimTouch.min),
      ),
    );
  }
}

class _CompactCheckOption extends StatelessWidget {
  const _CompactCheckOption({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Material(
      color: selected
          ? palette.primary.withValues(alpha: 0.08)
          : palette.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? palette.primary : palette.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? palette.primary : palette.muted,
                    width: 1.4,
                  ),
                  color: selected ? palette.primary : Colors.transparent,
                ),
                child: selected
                    ? Icon(Icons.check, size: 9, color: palette.onPrimary)
                    : null,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  softWrap: true,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryPathButton extends StatelessWidget {
  const _EntryPathButton({
    required this.icon,
    required this.title,
    required this.description,
    required this.shortPhrase,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String shortPhrase;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: selected
            ? palette.primary.withValues(alpha: 0.08)
            : palette.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 154),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? palette.primary : palette.border,
                width: selected ? 1.8 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: palette.primary),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  shortPhrase,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialPathCard extends StatelessWidget {
  const _MaterialPathCard({
    required this.session,
    required this.attachmentMenuOpen,
    required this.notesController,
    required this.onToggleAttachmentMenu,
    required this.onPickAttachment,
    required this.onMaterialType,
    required this.onNotesChanged,
    required this.onRemoveAttachment,
  });

  final LabSession session;
  final bool attachmentMenuOpen;
  final TextEditingController notesController;
  final VoidCallback onToggleAttachmentMenu;
  final void Function(String source, String materialLabel) onPickAttachment;
  final ValueChanged<String> onMaterialType;
  final ValueChanged<String> onNotesChanged;
  final ValueChanged<int> onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    return SimChatInputCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SimChatBubble(
            text: 'SIM: Envie ou descreva o material que você quer estudar.',
          ),
          const SizedBox(height: 12),
          AttachmentPreviewList(
            attachments: session.attachments,
            onRemove: onRemoveAttachment,
          ),
          _MaterialAction(
            icon: Icons.photo_camera_outlined,
            label: 'Foto do caderno',
            selected: session.materialType == 'Foto do caderno',
            onTap: () => onPickAttachment('camera', 'Foto do caderno'),
          ),
          _MaterialAction(
            icon: Icons.format_list_bulleted,
            label: 'Lista',
            selected: session.materialType == 'Lista',
            onTap: () => onMaterialType('Lista'),
          ),
          _MaterialAction(
            icon: Icons.menu_book_outlined,
            label: 'Livro',
            selected: session.materialType == 'Livro',
            onTap: () => onMaterialType('Livro'),
          ),
          _MaterialAction(
            icon: Icons.edit_note_outlined,
            label: 'Caderno',
            selected: session.materialType == 'Caderno',
            onTap: () => onMaterialType('Caderno'),
          ),
          _MaterialAction(
            icon: Icons.description_outlined,
            label: 'Prova',
            selected: session.materialType == 'Prova',
            onTap: () => onMaterialType('Prova'),
          ),
          _MaterialAction(
            icon: Icons.picture_as_pdf_outlined,
            label: 'PDF',
            selected: session.materialType == 'PDF',
            onTap: () => onPickAttachment('document', 'PDF'),
          ),
          _MaterialAction(
            icon: Icons.quiz_outlined,
            label: 'Questão',
            selected: session.materialType == 'Questão',
            onTap: () => onMaterialType('Questão'),
          ),
          _MaterialAction(
            icon: Icons.edit_outlined,
            label: 'Resposta que tentei fazer',
            selected: session.materialType == 'Resposta que tentei fazer',
            onTap: () => onMaterialType('Resposta que tentei fazer'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('sim-entry-material-notes'),
            controller: notesController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Texto livre complementar',
              hintText: 'Conte o que o SIM precisa observar no material.',
              border: OutlineInputBorder(),
            ),
            onChanged: onNotesChanged,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onToggleAttachmentMenu,
            icon: const Icon(Icons.attach_file),
            label: const Text('Anexar material'),
          ),
          if (attachmentMenuOpen)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AttachmentMenu(
                onPick: (source) =>
                    onPickAttachment(source, 'Material anexado'),
              ),
            ),
          const SizedBox(height: 10),
          const _InfoStrip(
            text: 'SIM interpreta o material e pergunta só o que faltar.',
          ),
        ],
      ),
    );
  }
}

class _SimBuildPathCard extends StatelessWidget {
  const _SimBuildPathCard({
    required this.session,
    required this.topicController,
    required this.levelController,
    required this.onField,
    required this.onGoalChanged,
    required this.onSubmitGoal,
    required this.onSubmitLevel,
  });

  final LabSession session;
  final TextEditingController topicController;
  final TextEditingController levelController;
  final void Function(String key, String value) onField;
  final ValueChanged<String> onGoalChanged;
  final VoidCallback onSubmitGoal;
  final VoidCallback onSubmitLevel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SequentialProfileCard(
          question: 'O que você quer aprender?',
          active: !session.simLearningGoalSubmitted,
          completed: session.simLearningGoalSubmitted,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('sim-entry-topic-input'),
                  controller: topicController,
                  enabled: !session.simLearningGoalSubmitted,
                  decoration: const InputDecoration(
                    hintText:
                        'Ex: sistema digestivo, equação do segundo grau, inglês para viagem...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: onGoalChanged,
                ),
              ),
              const SizedBox(width: 8),
              _InlineSendButton(
                key: const Key('sim-entry-topic-submit'),
                enabled:
                    !session.simLearningGoalSubmitted &&
                    topicController.text.trim().isNotEmpty,
                onPressed: onSubmitGoal,
              ),
            ],
          ),
        ),
        if (session.simLearningGoalSubmitted) ...[
          const SizedBox(height: 10),
          _SequentialProfileCard(
            question: 'Qual nível devo considerar?',
            active: !session.simLearningLevelSubmitted,
            completed: session.simLearningLevelSubmitted,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('sim-entry-level-input'),
                    controller: levelController,
                    enabled: !session.simLearningLevelSubmitted,
                    decoration: const InputDecoration(
                      hintText:
                          'Ex: 5º ano, ensino médio, concurso, iniciante, Brasil...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => onField('academic_level', value),
                  ),
                ),
                const SizedBox(width: 8),
                _InlineSendButton(
                  key: const Key('sim-entry-level-submit'),
                  enabled:
                      !session.simLearningLevelSubmitted &&
                      levelController.text.trim().isNotEmpty,
                  onPressed: onSubmitLevel,
                ),
              ],
            ),
          ),
        ],
        if (session.simLearningLevelSubmitted) ...[
          const SizedBox(height: 10),
          SimChatInputCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _InfoStrip(
                  text:
                      'SIM continua a coleta pelo caminho guiado e monta o plano ideal.',
                ),
                const SizedBox(height: 12),
                _ChoiceLine(
                  icon: Icons.event_outlined,
                  label: 'Prazo',
                  selected: session.deadline,
                  options: const [
                    'Hoje',
                    'Esta semana',
                    'Este mês',
                    'Sem prazo',
                  ],
                  onSelected: (value) => onField('deadline', value),
                ),
                _ChoiceLine(
                  icon: Icons.groups_outlined,
                  label: 'Como prefere aprender',
                  selected: session.learningPreference,
                  options: const [
                    'Passo a passo',
                    'Com imagem',
                    'Com áudio',
                    'Direto ao ponto',
                  ],
                  onSelected: (value) => onField('learning_preference', value),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceLine extends StatelessWidget {
  const _ChoiceLine({
    required this.icon,
    required this.label,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final String selected;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          SimChatChoiceWrap(
            children: [
              for (final option in options)
                SimChatChoiceChip(
                  label: option,
                  selected: selected == option,
                  onTap: () => onSelected(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaterialAction extends StatelessWidget {
  const _MaterialAction({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minLeadingWidth: 30,
        leading: Icon(icon, color: selected ? palette.primary : palette.text),
        title: Text(
          label,
          style: TextStyle(
            color: palette.text,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        trailing: selected ? Icon(Icons.check, color: palette.primary) : null,
        onTap: onTap,
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.primary.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: palette.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: palette.text, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FichaSummaryCard extends StatelessWidget {
  const _FichaSummaryCard({
    required this.ficha,
    required this.canPrepare,
    required this.sending,
    required this.onPrepare,
    this.error,
  });

  final Map<String, dynamic> ficha;
  final bool canPrepare;
  final bool sending;
  final VoidCallback onPrepare;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final summary = (ficha['human_summary'] ?? '').toString();
    return SimChatInputCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo da ficha',
            style: TextStyle(
              color: palette.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (final line
              in summary.split('\n').where((line) => line.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: palette.primary,
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
            ),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.tune_outlined),
            label: const Text('Ajustar ficha'),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              style: TextStyle(
                color: palette.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton.icon(
              key: const Key('sim-entry-prepare-button'),
              onPressed: canPrepare ? onPrepare : null,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.school_outlined),
              label: const Text('Preparar minha aula'),
            ),
          ),
        ],
      ),
    );
  }
}

class ObjetoScreen extends StatefulWidget {
  const ObjetoScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<ObjetoScreen> createState() => _ObjetoScreenState();
}

class _ObjetoScreenState extends State<ObjetoScreen> {
  bool attachmentMenuOpen = false;
  bool sending = false;
  String? error;
  int visibleProfileStep = 0;
  late final TextEditingController objectiveController = TextEditingController(
    text: widget.session.freeText,
  );
  late final TextEditingController nameController = TextEditingController(
    text: widget.session.preferredName,
  );
  late final Map<String, TextEditingController> guidedControllers = {
    for (final group in GuidedOnboardingSection.groups)
      group.keyName: TextEditingController(
        text: widget.session.guidedAnswers[group.keyName] ?? '',
      ),
  };

  bool get waitingAttachment => widget.session.attachments.any(
    (a) => a.status == 'uploading' || a.status == 'processing',
  );
  bool get objectiveTooShort => widget.session.freeText.trim().length < 10;
  bool get canContinue => !sending && !waitingAttachment && !objectiveTooShort;

  @override
  void dispose() {
    objectiveController.dispose();
    nameController.dispose();
    for (final controller in guidedControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _guidedCount => GuidedOnboardingSection.groups.length;
  bool get _nameVisible => visibleProfileStep >= 1;
  bool get _guidedIntroVisible => visibleProfileStep >= 2;
  int get _visibleGuidedCount =>
      (visibleProfileStep - 1).clamp(0, _guidedCount).toInt();
  bool get _saveVisible => visibleProfileStep >= _guidedCount + 2;

  void _revealNextProfileStep() {
    setState(() {
      error = null;
      visibleProfileStep = (visibleProfileStep + 1)
          .clamp(0, _guidedCount + 2)
          .toInt();
    });
  }

  void _advanceFromObjective() {
    if (objectiveTooShort) {
      showObjectiveRequired();
      return;
    }
    _revealNextProfileStep();
  }

  void showObjectiveRequired() {
    setState(() {
      error = widget.session.attachments.isNotEmpty
          ? 'objective_required_attachment'
          : 'objective_required';
    });
  }

  Future<void> saveAndContinue() async {
    if (waitingAttachment) return;
    if (objectiveTooShort) {
      showObjectiveRequired();
      return;
    }
    if (!canContinue) return;
    setState(() {
      error = null;
      sending = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 160));
    widget.session.saveObjectiveEntry();
  }

  Future<void> addAttachment(String source) async {
    if (widget.session.attachments.length >= maxAttachments) {
      setState(() => error = 'attachment_limit');
      return;
    }
    setState(() {
      error = null;
      attachmentMenuOpen = false;
    });
    final pickError = await widget.session.pickLabAttachment(source);
    if (!mounted || pickError == null) return;
    setState(() => error = pickError);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = maxFreeText - widget.session.freeText.length;
    return CyberStepShell(
      step: 3,
      total: 5,
      child: OnboardingChatFlow(
        semanticLabel: t('onboarding_chat_region'),
        children: [
          SimChatReveal(
            child: SimChatBubble(
              text: t('objective_chat_intro'),
              supportingText: t('objective_chat_body'),
            ),
          ),
          SimChatReveal(
            delay: const Duration(milliseconds: 100),
            child: SimChatInputCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SimChatFieldLabel(t('objeto_card1_title')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AttachmentPreviewList(
                    attachments: widget.session.attachments,
                    onRemove: (index) =>
                        setState(() => widget.session.removeAttachment(index)),
                  ),
                  Text(
                    t('objeto_required_help'),
                    style: TextStyle(
                      color: SimThemeScope.paletteOf(context).muted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: objectiveController,
                    minLines: 4,
                    maxLines: 7,
                    maxLength: maxFreeText,
                    decoration: InputDecoration(
                      hintText: t('objeto_hint'),
                      border: const OutlineInputBorder(),
                      counterText: '',
                    ),
                    style: const TextStyle(fontSize: 16, height: 1.4),
                    onChanged: (value) {
                      widget.session.setFreeText(value);
                      if (error == 'objective_required' ||
                          error == 'objective_required_attachment') {
                        setState(() => error = null);
                      } else {
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        tooltip: t('attachment_open_menu'),
                        onPressed: () => setState(
                          () => attachmentMenuOpen = !attachmentMenuOpen,
                        ),
                        icon: const Icon(Icons.attach_file),
                      ),
                      Expanded(
                        child: Text(
                          '${widget.session.freeText.length}/$maxFreeText',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: SimThemeScope.paletteOf(context).muted,
                            fontSize: 12,
                            fontFamily: kMono,
                          ),
                        ),
                      ),
                      SimChatSendButton(
                        semanticLabel: t('continue'),
                        onPressed: _advanceFromObjective,
                      ),
                    ],
                  ),
                  if (attachmentMenuOpen) AttachmentMenu(onPick: addAttachment),
                  if (widget.session.attachments.isNotEmpty &&
                      objectiveTooShort) ...[
                    const SizedBox(height: 8),
                    Text(
                      t('objective_required_attachment'),
                      style: const TextStyle(color: Colors.black, fontSize: 13),
                    ),
                  ],
                  if (remaining < 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      t('objeto_too_long'),
                      style: const TextStyle(color: Colors.black, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_nameVisible) ...[
            SimChatReveal(child: SimChatBubble(text: t('name_chat_prompt'))),
            SimChatReveal(
              child: SimChatInputCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SimChatFieldLabel(t('objeto_preferred_name')),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SimInput(
                            hint: t('objeto_name_placeholder'),
                            controller: nameController,
                            onChanged: widget.session.setPreferredName,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SimChatSendButton(
                          semanticLabel: t('continue'),
                          onPressed: _revealNextProfileStep,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_guidedIntroVisible)
            SimChatReveal(
              child: SimChatBubble(
                text: t('guided_title'),
                supportingText: t('guided_body'),
              ),
            ),
          for (var i = 0; i < _visibleGuidedCount; i++)
            _GuidedChatQuestion(
              session: widget.session,
              group: GuidedOnboardingSection.groups[i],
              controller:
                  guidedControllers[GuidedOnboardingSection.groups[i].keyName]!,
              onSubmit: _revealNextProfileStep,
            ),
          if (error != null) SimChatError(text: t(error!)),
          if (_saveVisible)
            SimChatReveal(
              child: Semantics(
                button: true,
                enabled: canContinue,
                label: t('objeto_save_continue'),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: canContinue
                            ? saveAndContinue
                            : waitingAttachment
                            ? null
                            : showObjectiveRequired,
                        icon: sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward),
                        label: Text(
                          sending
                              ? t('objetivo_reading')
                              : waitingAttachment
                              ? t('attachment_waiting')
                              : objectiveTooShort
                              ? t('objeto_helper')
                              : t('objeto_save_continue'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class OnboardingChatFlow extends StatelessWidget {
  const OnboardingChatFlow({
    required this.children,
    required this.semanticLabel,
    super.key,
  });

  final List<Widget> children;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SimChatReveal extends StatefulWidget {
  const SimChatReveal({
    required this.child,
    this.delay = Duration.zero,
    super.key,
  });

  final Widget child;
  final Duration delay;

  @override
  State<SimChatReveal> createState() => _SimChatRevealState();
}

class _SimChatRevealState extends State<SimChatReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _delayTimer = Timer(widget.delay, () {
      if (!mounted) return;
      final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduced) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          context,
          duration: reduced ? Duration.zero : const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          alignment: 0.78,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      });
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: value,
          child: Transform.scale(
            alignment: Alignment.topLeft,
            scale: lerpDouble(0.82, 1, value)!,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class SimChatBubble extends StatelessWidget {
  const SimChatBubble({required this.text, this.supportingText, super.key});

  final String text;
  final String? supportingText;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: palette.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (supportingText != null && supportingText!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      supportingText!,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SimChatInputCard extends StatelessWidget {
  const SimChatInputCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class SimChatChoiceWrap extends StatelessWidget {
  const SimChatChoiceWrap({required this.children, super.key})
    : staggered = false;

  const SimChatChoiceWrap.staggered({required this.children, super.key})
    : staggered = true;

  final List<Widget> children;
  final bool staggered;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < children.length; i++)
          staggered
              ? SimChatReveal(
                  delay: Duration(milliseconds: 150 + (i * 70)),
                  child: children[i],
                )
              : children[i],
      ],
    );
  }
}

class SimChatSendButton extends StatelessWidget {
  const SimChatSendButton({
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: IconButton.filled(
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_forward),
        color: palette.onPrimary,
        style: IconButton.styleFrom(
          backgroundColor: palette.primary,
          minimumSize: const Size(SimTouch.min, SimTouch.min),
        ),
      ),
    );
  }
}

class SimChatChoiceChip extends StatelessWidget {
  const SimChatChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? palette.primary : palette.surface,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            constraints: const BoxConstraints(minHeight: SimTouch.min),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? palette.primary : palette.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? palette.onPrimary : palette.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SimChatFieldLabel extends StatelessWidget {
  const SimChatFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: SimThemeScope.paletteOf(context).text,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class SimChatError extends StatelessWidget {
  const SimChatError({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.danger),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            text,
            style: TextStyle(color: palette.danger, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class GuidedOnboardingSection extends StatelessWidget {
  const GuidedOnboardingSection({required this.session, super.key});

  final LabSession session;

  static const groups = [
    GuidedGroup(
      keyName: 'purpose',
      titleKey: 'guided_purpose',
      optionKeys: [
        'guided_school_test',
        'guided_exam',
        'guided_enem',
        'guided_exercises',
        'guided_understand',
      ],
    ),
    GuidedGroup(
      keyName: 'level',
      titleKey: 'guided_level',
      optionKeys: [
        'guided_zero',
        'guided_some',
        'guided_errors',
        'guided_advanced',
      ],
    ),
    GuidedGroup(
      keyName: 'blocker',
      titleKey: 'guided_blocker',
      optionKeys: [
        'guided_base',
        'guided_explanation',
        'guided_memory',
        'guided_focus',
        'guided_exercise_block',
      ],
    ),
    GuidedGroup(
      keyName: 'deadline',
      titleKey: 'guided_deadline',
      optionKeys: [
        'guided_today',
        'guided_week',
        'guided_month',
        'guided_no_deadline',
      ],
    ),
    GuidedGroup(
      keyName: 'style',
      titleKey: 'guided_style',
      optionKeys: [
        'guided_simple',
        'guided_step',
        'guided_images',
        'guided_audio',
        'guided_direct',
      ],
    ),
    GuidedGroup(
      keyName: 'start',
      titleKey: 'guided_start',
      optionKeys: [
        'guided_from_zero',
        'guided_find_point',
        'guided_direct_exam',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final answers = session.guidedAnswers;
    return SimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(icon: Icons.route_outlined, title: t('guided_title')),
          Text(
            t('guided_body'),
            style: const TextStyle(color: simMuted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),
          for (final group in groups) ...[
            Text(
              t(group.titleKey),
              style: const TextStyle(
                color: simDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final optionKey in group.optionKeys)
                  _GuidedChip(
                    label: t(optionKey),
                    selected: answers[group.keyName] == optionKey,
                    onTap: () => session.setGuidedAnswer(
                      group.keyName,
                      answers[group.keyName] == optionKey ? '' : optionKey,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _GuidedChatQuestion extends StatelessWidget {
  const _GuidedChatQuestion({
    required this.session,
    required this.group,
    required this.controller,
    required this.onSubmit,
  });

  final LabSession session;
  final GuidedGroup group;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return SimChatReveal(
      child: SimChatInputCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SimChatFieldLabel(t(group.titleKey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final optionKey in group.optionKeys)
                  Text(
                    t(optionKey),
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: t('guided_custom_hint'),
                    ),
                    onChanged: (value) =>
                        session.setGuidedAnswer(group.keyName, value),
                  ),
                ),
                const SizedBox(width: 8),
                SimChatSendButton(
                  semanticLabel: t('continue'),
                  onPressed: onSubmit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GuidedGroup {
  const GuidedGroup({
    required this.keyName,
    required this.titleKey,
    required this.optionKeys,
  });

  final String keyName;
  final String titleKey;
  final List<String> optionKeys;
}

class _GuidedChip extends StatelessWidget {
  const _GuidedChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? simDark : Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? simDark : simBorder),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : simDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AttachmentPreviewList extends StatelessWidget {
  const AttachmentPreviewList({
    required this.attachments,
    required this.onRemove,
    super.key,
  });

  final List<AttachmentDraft> attachments;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (int i = 0; i < attachments.length; i++)
            AttachmentChip(
              attachment: attachments[i],
              onRemove: () => onRemove(i),
            ),
        ],
      ),
    );
  }
}

class AttachmentChip extends StatelessWidget {
  const AttachmentChip({
    required this.attachment,
    required this.onRemove,
    super.key,
  });

  final AttachmentDraft attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final icon = attachment.type.startsWith('image/')
        ? '📷'
        : attachment.type == 'application/pdf'
        ? '📄'
        : '📝';
    final suffix =
        attachment.status == 'uploading' || attachment.status == 'processing'
        ? ' lendo...'
        : attachment.status == 'error'
        ? ' erro'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: simBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$icon ${attachment.name}$suffix',
            style: const TextStyle(color: simDark, fontSize: 12),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Text(
              '✕',
              style: TextStyle(color: simMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class AttachmentMenu extends StatelessWidget {
  const AttachmentMenu({required this.onPick, super.key});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: simBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33111827),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MenuLine(
              label: t('attach_document'),
              onTap: () => onPick('document'),
            ),
            MenuLine(label: t('attach_camera'), onTap: () => onPick('camera')),
            MenuLine(label: t('attach_image'), onTap: () => onPick('image')),
          ],
        ),
      ),
    );
  }
}

class MenuLine extends StatelessWidget {
  const MenuLine({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(color: simDark, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
