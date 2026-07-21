part of '../onboarding_screens.dart';

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
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < attachments.length; i++) ...[
        AttachmentChip(attachment: attachments[i], onRemove: () => onRemove(i)),
        const SizedBox(height: SimSpacing.sm),
      ],
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
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final statusTone = switch (attachment.status) {
      'ready' => SimSurfaceTone.success,
      'error' => SimSurfaceTone.danger,
      'processing' => SimSurfaceTone.warning,
      _ => SimSurfaceTone.soft,
    };
    final statusIcon = switch (attachment.status) {
      'ready' => Icons.check_circle_outline,
      'error' => Icons.error_outline,
      'processing' => Icons.hourglass_top,
      _ => Icons.description_outlined,
    };
    return SimLearningSurface(
      tone: statusTone,
      padding: const EdgeInsets.all(SimSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: palette.surface,
            child: Icon(statusIcon, color: palette.text, size: 20),
          ),
          const SizedBox(width: SimSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SimTypography.label.copyWith(color: palette.text),
                ),
                const SizedBox(height: 3),
                Text(
                  _attachmentStatusText(attachment),
                  style: SimTypography.caption.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: SimSpacing.xs),
          SimIconAction(
            icon: Icons.close,
            semanticLabel: t('remove'),
            onPressed: onRemove,
            size: 40,
            iconSize: 18,
          ),
        ],
      ),
    );
  }

  String _attachmentStatusText(AttachmentDraft attachment) {
    return switch (attachment.status) {
      'processing' => 'Estou lendo seu material...',
      'ready' => 'Consegui extrair o conteúdo.',
      'error' =>
        attachment.error?.trim().isNotEmpty == true
            ? attachment.error!.trim()
            : 'Não consegui ler bem. Você pode descrever com texto.',
      _ => 'Material recebido.',
    };
  }
}

class AttachmentMenu extends StatelessWidget {
  const AttachmentMenu({required this.onPick, super.key});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MenuLine(
        icon: Icons.description_outlined,
        label: t('attach_file'),
        onTap: () => onPick('document'),
      ),
      const SizedBox(height: SimSpacing.sm),
      MenuLine(
        icon: Icons.photo_camera_outlined,
        label: t('attach_camera'),
        onTap: () => onPick('camera'),
      ),
      const SizedBox(height: SimSpacing.sm),
      MenuLine(
        icon: Icons.image_outlined,
        label: t('attach_image'),
        onTap: () => onPick('gallery'),
      ),
    ],
  );
}

class MenuLine extends StatelessWidget {
  const MenuLine({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SimActionButton(
    label: label,
    icon: icon,
    onPressed: onTap,
    tone: SimActionTone.secondary,
  );
}
