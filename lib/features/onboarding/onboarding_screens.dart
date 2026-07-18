import 'package:flutter/material.dart';

import '../../features/session/lab_session.dart';
import '../../session/entry_form_state.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../sim/ui/sim_i18n.dart';

class ConversationalEntryScreen extends StatelessWidget {
  const ConversationalEntryScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final routePath = Uri.tryParse(session.route)?.path ?? session.route;
    if (routePath == '/cyber/idioma') {
      return _LanguageScreen(session: session);
    }
    return _EntryScreen(session: session);
  }
}

class ObjetoScreen extends StatelessWidget {
  const ObjetoScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) => _EntryScreen(session: session);
}

class _EntryScreen extends StatefulWidget {
  const _EntryScreen({required this.session});

  final LabSession session;

  @override
  State<_EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<_EntryScreen> {
  late final TextEditingController objectiveController;
  late final TextEditingController nameController;
  final guidedControllers = <String, TextEditingController>{};
  String? error;

  LabSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    objectiveController = TextEditingController(text: session.freeText);
    nameController = TextEditingController(text: session.preferredName);
    for (final group in GuidedOnboardingSection.groups) {
      guidedControllers[group.keyName] = TextEditingController(
        text: session.guidedAnswers[group.keyName] ?? '',
      );
    }
    session.addListener(_syncFromSession);
  }

  void _syncFromSession() {
    if (!mounted) return;
    _syncText(objectiveController, session.freeText);
    _syncText(nameController, session.preferredName);
    for (final group in GuidedOnboardingSection.groups) {
      _syncText(
        guidedControllers[group.keyName]!,
        session.guidedAnswers[group.keyName] ?? '',
      );
    }
    setState(() {});
  }

  void _syncText(TextEditingController controller, String value) {
    if (controller.text == value) return;
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

  void _submit() {
    final ok = session.saveObjectiveEntry();
    setState(() => error = ok ? null : 'objeto_required');
  }

  @override
  void dispose() {
    session.removeListener(_syncFromSession);
    objectiveController.dispose();
    nameController.dispose();
    for (final controller in guidedControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = entryFormMaxFreeText - session.freeText.length;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            StepHeader(
              title: t('objeto_title'),
              subtitle: t('objeto_subtitle'),
            ),
            const SizedBox(height: 16),
            SimChatBubble(
              text: t('objeto_card1_title'),
              supportingText: t('objeto_card1_body'),
            ),
            const SizedBox(height: 12),
            SimChatInputCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SimChatFieldLabel(t('objeto_input_label')),
                  const SizedBox(height: 8),
                  SimInput(
                    controller: objectiveController,
                    hint: t('objeto_placeholder'),
                    maxLines: 5,
                    onChanged: session.setFreeText,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$remaining',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (remaining < 0) SimChatError(text: t('objeto_too_long')),
                  if (session.attachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AttachmentPreviewList(
                      attachments: session.attachments,
                      onRemove: session.removeAttachment,
                    ),
                  ],
                  if (session.attachmentError != null)
                    SimChatError(text: session.attachmentError!),
                  const SizedBox(height: 12),
                  AttachmentMenu(onPick: _pickAttachment),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SimChatInputCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SimChatFieldLabel(t('objeto_preferred_name')),
                  const SizedBox(height: 8),
                  SimInput(
                    controller: nameController,
                    hint: t('objeto_name_placeholder'),
                    onChanged: session.setPreferredName,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GuidedOnboardingSection(session: session),
            if (error != null) ...[
              const SizedBox(height: 12),
              SimChatError(text: t(error!)),
            ],
            const SizedBox(height: 20),
            PrimaryWideButton(label: t('start_lesson'), onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

class _LanguageScreen extends StatefulWidget {
  const _LanguageScreen({required this.session});

  final LabSession session;

  @override
  State<_LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<_LanguageScreen> {
  late final TextEditingController otherController;

  LabSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    otherController = TextEditingController(text: session.otherLanguage);
    session.addListener(_syncFromSession);
  }

  void _syncFromSession() {
    if (!mounted) return;
    if (otherController.text != session.otherLanguage) {
      otherController.value = TextEditingValue(
        text: session.otherLanguage,
        selection: TextSelection.collapsed(
          offset: session.otherLanguage.length,
        ),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    session.removeListener(_syncFromSession);
    otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        key: const Key('language-screen'),
        padding: const EdgeInsets.all(20),
        children: [
          StepHeader(
            title: t('language_title'),
            subtitle: t('language_subtitle'),
          ),
          const SizedBox(height: 16),
          SimChatInputCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SimChatFieldLabel(t('language_choose_label')),
                const SizedBox(height: 10),
                SimChatChoiceWrap(
                  children: [
                    for (final language in supportedLangs)
                      LanguageButton(
                        language: language,
                        selected: session.selectedLanguageCode == language.code,
                        onTap: () => session.chooseLanguage(
                          language.code,
                          language.name,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                SimChatFieldLabel(t('language_other_label')),
                const SizedBox(height: 8),
                SimInput(
                  key: const Key('language-other-input'),
                  controller: otherController,
                  hint: t('language_other_placeholder'),
                  onChanged: session.setOtherLanguage,
                ),
                const SizedBox(height: 12),
                PrimaryWideButton(
                  label: t('continue'),
                  onPressed: session.otherLanguage.trim().isEmpty
                      ? null
                      : () => session.chooseLanguage(
                          'other',
                          session.otherLanguage,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
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
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: ListView(padding: const EdgeInsets.all(20), children: children),
  );
}

class SimChatReveal extends StatelessWidget {
  const SimChatReveal({
    required this.child,
    this.delay = Duration.zero,
    super.key,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => child;
}

class SimChatBubble extends StatelessWidget {
  const SimChatBubble({required this.text, this.supportingText, super.key});

  final String text;
  final String? supportingText;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFD8E2F0)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (supportingText != null) ...[
            const SizedBox(height: 6),
            Text(supportingText!),
          ],
        ],
      ),
    ),
  );
}

class SimChatInputCard extends StatelessWidget {
  const SimChatInputCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => SimCard(child: child);
}

class SimChatChoiceWrap extends StatelessWidget {
  const SimChatChoiceWrap({required this.children, super.key})
    : staggered = false;

  const SimChatChoiceWrap.staggered({required this.children, super.key})
    : staggered = true;

  final List<Widget> children;
  final bool staggered;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
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
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: IconButton.filled(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_forward),
    ),
  );
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
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
  );
}

class SimChatFieldLabel extends StatelessWidget {
  const SimChatFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w700));
}

class SimChatError extends StatelessWidget {
  const SimChatError({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(text, style: const TextStyle(color: Colors.red)),
  );
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

class GuidedOnboardingSection extends StatelessWidget {
  const GuidedOnboardingSection({required this.session, super.key});

  final LabSession session;

  static const groups = <GuidedGroup>[
    GuidedGroup(
      keyName: 'goal',
      titleKey: 'guided_goal_title',
      optionKeys: [
        'guided_goal_school',
        'guided_goal_work',
        'guided_goal_self',
      ],
    ),
    GuidedGroup(
      keyName: 'level',
      titleKey: 'guided_level_title',
      optionKeys: [
        'guided_level_beginner',
        'guided_level_mid',
        'guided_level_high',
      ],
    ),
    GuidedGroup(
      keyName: 'preference',
      titleKey: 'guided_preference_title',
      optionKeys: [
        'guided_pref_fast',
        'guided_pref_examples',
        'guided_pref_step',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final group in groups) ...[
        SimChatFieldLabel(t(group.titleKey)),
        const SizedBox(height: 8),
        SimChatChoiceWrap(
          children: [
            for (final key in group.optionKeys)
              SimChatChoiceChip(
                label: t(key),
                selected: session.guidedAnswers[group.keyName] == key,
                onTap: () => session.setGuidedAnswer(group.keyName, key),
              ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    ],
  );
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
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < attachments.length; i++)
        AttachmentChip(attachment: attachments[i], onRemove: () => onRemove(i)),
    ],
  );
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
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.attach_file),
    title: Text(attachment.name),
    subtitle: Text(attachment.status),
    trailing: IconButton(
      tooltip: t('remove'),
      onPressed: onRemove,
      icon: const Icon(Icons.close),
    ),
  );
}

class AttachmentMenu extends StatelessWidget {
  const AttachmentMenu({required this.onPick, super.key});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      MenuLine(label: t('attach_photo'), onTap: () => onPick('photo')),
      MenuLine(label: t('attach_file'), onTap: () => onPick('file')),
      MenuLine(label: t('attach_text'), onTap: () => onPick('text')),
    ],
  );
}

class MenuLine extends StatelessWidget {
  const MenuLine({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: onTap, child: Text(label));
}
