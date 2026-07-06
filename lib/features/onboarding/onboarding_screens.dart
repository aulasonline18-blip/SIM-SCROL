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
          SimChatBubble(
            text: t('language_chat_intro'),
            supportingText: t('language_body'),
          ),
          SimChatChoiceWrap(
            children: [
              for (final language in supportedLangs)
                SimChatChoiceChip(
                  label: language.native.isEmpty
                      ? language.name
                      : '${language.native} · ${language.name}',
                  selected: session.selectedLanguageCode == language.code,
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
            OtherLanguageBox(session: session),
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
  late final TextEditingController objectiveController = TextEditingController(
    text: widget.session.freeText,
  );
  late final TextEditingController nameController = TextEditingController(
    text: widget.session.preferredName,
  );

  bool get waitingAttachment => widget.session.attachments.any(
    (a) => a.status == 'uploading' || a.status == 'processing',
  );
  bool get objectiveTooShort => widget.session.freeText.trim().length < 10;
  bool get canContinue => !sending && !waitingAttachment && !objectiveTooShort;

  @override
  void dispose() {
    objectiveController.dispose();
    nameController.dispose();
    super.dispose();
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
          SimChatBubble(
            text: t('objective_chat_intro'),
            supportingText: t('objective_chat_body'),
          ),
          SimChatInputCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: SimChatFieldLabel(t('objeto_card1_title'))),
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
          if (!objectiveTooShort) ...[
            SimChatBubble(text: t('name_chat_prompt')),
            SimChatInputCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SimChatFieldLabel(t('objeto_preferred_name')),
                  const SizedBox(height: 6),
                  SimInput(
                    hint: t('objeto_name_placeholder'),
                    controller: nameController,
                    onChanged: widget.session.setPreferredName,
                  ),
                ],
              ),
            ),
            SimChatBubble(
              text: t('guided_title'),
              supportingText: t('guided_body'),
            ),
            for (final group in GuidedOnboardingSection.groups)
              _GuidedChatQuestion(session: widget.session, group: group),
          ],
          if (error != null) SimChatError(text: t(error!)),
          Semantics(
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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
  const SimChatChoiceWrap({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: children);
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

class _GuidedChatQuestion extends StatefulWidget {
  const _GuidedChatQuestion({required this.session, required this.group});

  final LabSession session;
  final GuidedGroup group;

  @override
  State<_GuidedChatQuestion> createState() => _GuidedChatQuestionState();
}

class _GuidedChatQuestionState extends State<_GuidedChatQuestion> {
  late final TextEditingController controller = TextEditingController(
    text: _customInitialValue(),
  );

  String _customInitialValue() {
    final current = widget.session.guidedAnswers[widget.group.keyName] ?? '';
    final optionLabels = widget.group.optionKeys.map(t).toSet();
    return optionLabels.contains(current) ? '' : current;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.session.guidedAnswers[widget.group.keyName] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SimChatBubble(text: t(widget.group.titleKey)),
        SimChatChoiceWrap(
          children: [
            for (final optionKey in widget.group.optionKeys)
              SimChatChoiceChip(
                label: t(optionKey),
                selected: selected == t(optionKey),
                onTap: () {
                  controller.clear();
                  widget.session.setGuidedAnswer(
                    widget.group.keyName,
                    selected == t(optionKey) ? '' : t(optionKey),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        SimChatInputCard(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: t('guided_custom_hint'),
            ),
            onChanged: (value) =>
                widget.session.setGuidedAnswer(widget.group.keyName, value),
          ),
        ),
      ],
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
