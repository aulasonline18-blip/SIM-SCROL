import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/session/lab_session.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/sim_theme.dart';

BoxDecoration glassDecoration({double radius = 12}) => BoxDecoration(
  color: Colors.white.withValues(alpha: 0.92),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: SimPalette.light.border),
  boxShadow: const [
    BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8)),
  ],
);

BoxDecoration glassDecorationFor(BuildContext context, {double radius = 12}) {
  final palette = SimThemeScope.paletteOf(context);
  return BoxDecoration(
    color: palette.elevatedSurface.withValues(
      alpha: palette.dark ? 0.96 : 0.94,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: palette.border),
    boxShadow: [
      BoxShadow(
        color: palette.shadow.withValues(alpha: palette.dark ? 0.28 : 0.08),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

BoxDecoration primaryButtonDecorationFor(
  BuildContext context, {
  double radius = 12,
}) => BoxDecoration(
  color: SimThemeScope.paletteOf(context).primary,
  borderRadius: BorderRadius.circular(radius),
);

BoxDecoration pillDecorationFor(BuildContext context) {
  final palette = SimThemeScope.paletteOf(context);
  return BoxDecoration(
    color: palette.surfaceSoft,
    borderRadius: BorderRadius.circular(SimRadius.pill),
    border: Border.all(color: palette.border),
  );
}

class PrimaryWideButton extends StatelessWidget {
  const PrimaryWideButton({
    required this.label,
    this.onTap,
    this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) =>
      SimActionButton(label: label, onPressed: onPressed ?? onTap);
}

class SecondaryWideButton extends StatelessWidget {
  const SecondaryWideButton({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SimActionButton(
    label: label,
    onPressed: onTap,
    tone: SimActionTone.secondary,
  );
}

class AnswerButton extends StatelessWidget {
  const AnswerButton({
    required this.letter,
    required this.text,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
    this.resultCorrect,
    super.key,
  });

  final String letter;
  final String text;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;
  final bool? resultCorrect;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final disabled = !enabled || onTap == null;
    final accent = disabled
        ? palette.muted
        : resultCorrect == true
        ? palette.success
        : resultCorrect == false
        ? palette.danger
        : selected
        ? palette.primary
        : palette.border;
    final background = disabled
        ? palette.surfaceSoft
        : resultCorrect == true
        ? palette.successSurface
        : resultCorrect == false
        ? palette.dangerSurface
        : selected
        ? palette.selectedSurface
        : palette.surface;
    final letterColor = disabled
        ? palette.muted
        : selected || resultCorrect != null
        ? palette.onPrimary
        : palette.text;
    final letterBg = disabled
        ? palette.border
        : selected || resultCorrect != null
        ? accent
        : palette.surfaceSoft;
    return Padding(
      padding: const EdgeInsets.only(bottom: SimSpacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: !disabled,
        label: '$letter. $text',
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(SimRadius.lg),
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(SimRadius.lg),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 58),
              padding: const EdgeInsets.symmetric(
                horizontal: SimSpacing.md,
                vertical: SimSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(SimRadius.lg),
                border: Border.all(color: accent, width: selected ? 1.5 : 1),
                boxShadow: [
                  if (!disabled)
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: letterBg,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: letterColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: SimSpacing.md),
                  Expanded(
                    child: Text(
                      text,
                      style: SimTypography.option.copyWith(
                        color: disabled ? palette.muted : palette.text,
                      ),
                    ),
                  ),
                  if (resultCorrect != null) ...[
                    const SizedBox(width: SimSpacing.sm),
                    Icon(
                      resultCorrect! ? Icons.check_circle : Icons.cancel,
                      color: accent,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SimAulaMenuButton extends StatelessWidget {
  const SimAulaMenuButton({required this.onTap, this.size = 44, super.key});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => SimIconAction(
    icon: Icons.menu_rounded,
    semanticLabel: t('menu'),
    onPressed: onTap,
    size: size,
    iconSize: 21,
  );
}

void showAulaMenu(
  BuildContext context,
  LabSession session, {
  double? textScale,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: FutureBuilder(
        future: session.listDrawerCloudLessons(),
        builder: (context, snapshot) {
          final lessons = snapshot.data ?? const [];
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              Text(t('menu'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.add_circle_outline,
                label: t('new_lesson'),
                onTap: () {
                  Navigator.pop(context);
                  session.startNewLessonFromDrawer();
                },
              ),
              _MenuTile(
                icon: Icons.credit_card,
                label: t('credits'),
                onTap: () {
                  Navigator.pop(context);
                  session.openCreditsFromDrawer();
                },
              ),
              _MenuTile(
                icon: Icons.privacy_tip_outlined,
                label: t('privacy'),
                onTap: () {
                  Navigator.pop(context);
                  session.openSupport('/privacidade');
                },
              ),
              _MenuTile(
                icon: Icons.article_outlined,
                label: t('terms'),
                onTap: () {
                  Navigator.pop(context);
                  session.openSupport('/termos');
                },
              ),
              _MenuTile(
                icon: Icons.person_remove_outlined,
                label: t('delete_account_request'),
                onTap: () {
                  Navigator.pop(context);
                  session.openSupport('/conta/deletar');
                },
              ),
              _MenuTile(
                icon: Icons.upload_file,
                label: t('backup_export'),
                onTap: () async {
                  final text = session.buildDrawerBackupText();
                  await session.writeDrawerBackupFile(text);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              _MenuTile(
                icon: Icons.download,
                label: t('backup_import'),
                onTap: () async {
                  final text = await session.pickDrawerBackupFileText();
                  if (text != null) await session.importDrawerBackup(text);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              if (lessons.isNotEmpty) const Divider(height: 24),
              for (final lesson in lessons.take(12))
                _DrawerLessonTile(
                  lesson: lesson,
                  onOpen: () {
                    Navigator.pop(context);
                    session.openDrawerLocalLesson(lesson.lessonLocalId);
                  },
                  onRename: () async {
                    final name = await _askLessonName(context, lesson);
                    if (name == null) return;
                    await session.renameDrawerCloudLesson(
                      lesson.lessonLocalId,
                      name,
                    );
                  },
                  onDelete: () async {
                    final confirmed = await _confirmDeleteLesson(
                      context,
                      lesson,
                    );
                    if (confirmed != true) return;
                    await session.deleteDrawerCloudLesson(lesson.lessonLocalId);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              const Divider(height: 24),
              _MenuTile(
                icon: Icons.logout,
                label: t('logout'),
                onTap: () async {
                  Navigator.pop(context);
                  await session.signOutReal();
                },
              ),
            ],
          );
        },
      ),
    ),
  );
}

Future<String?> _askLessonName(BuildContext context, dynamic lesson) {
  final controller = TextEditingController(
    text: lesson.tema.isEmpty ? t('lesson') : lesson.tema,
  );
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t('rename_lesson')),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: t('lesson_name')),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(t('save')),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

Future<bool?> _confirmDeleteLesson(BuildContext context, dynamic lesson) {
  final title = lesson.tema.isEmpty ? t('lesson') : lesson.tema;
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t('delete_lesson')),
      content: Text(t('delete_lesson_confirm', {'title': title})),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(t('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(t('delete')),
        ),
      ],
    ),
  );
}

class _DrawerLessonTile extends StatelessWidget {
  const _DrawerLessonTile({
    required this.lesson,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final dynamic lesson;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = lesson.tema.isEmpty ? t('lesson') : lesson.tema;
    return ListTile(
      dense: true,
      leading: const Icon(Icons.school_outlined),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${lesson.nivel} - ${lesson.concluidos}/${lesson.totalItens}',
      ),
      onTap: onOpen,
      trailing: Wrap(
        spacing: 4,
        children: [
          SimIconAction(
            icon: Icons.edit_outlined,
            semanticLabel: t('rename_lesson'),
            onPressed: onRename,
            size: 40,
          ),
          SimIconAction(
            icon: Icons.delete_outline,
            semanticLabel: t('delete_lesson'),
            onPressed: onDelete,
            size: 40,
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      ListTile(leading: Icon(icon), title: Text(label), onTap: onTap);
}

class SupportedLang {
  const SupportedLang({
    required this.code,
    required this.name,
    required this.native,
    required this.flag,
  });
  final String code;
  final String name;
  final String native;
  final String flag;
}

const supportedLangs = <SupportedLang>[
  SupportedLang(
    code: 'pt',
    name: 'Portuguese',
    native: 'Português',
    flag: 'BR',
  ),
  SupportedLang(code: 'en', name: 'English', native: 'English', flag: 'US'),
  SupportedLang(code: 'es', name: 'Spanish', native: 'Español', flag: 'ES'),
  SupportedLang(code: 'fr', name: 'French', native: 'Français', flag: 'FR'),
  SupportedLang(code: 'de', name: 'German', native: 'Deutsch', flag: 'DE'),
  SupportedLang(code: 'it', name: 'Italian', native: 'Italiano', flag: 'IT'),
];

class LanguageButton extends StatelessWidget {
  const LanguageButton({
    required this.language,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final SupportedLang language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: language.native,
      child: Material(
        color: selected ? palette.selectedSurface : palette.surface,
        borderRadius: BorderRadius.circular(SimRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SimRadius.lg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 56, minWidth: 132),
            padding: const EdgeInsets.symmetric(
              horizontal: SimSpacing.md,
              vertical: SimSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SimRadius.lg),
              border: Border.all(
                color: selected ? palette.primary : palette.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  language.flag,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: SimSpacing.sm),
                Text(
                  language.native,
                  style: SimTypography.label.copyWith(color: palette.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StepHeader extends StatelessWidget {
  const StepHeader({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SimTypography.title.copyWith(color: palette.text)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: SimTypography.subtitle.copyWith(color: palette.muted),
          ),
        ],
      ],
    );
  }
}

class SimInput extends StatelessWidget {
  const SimInput({
    this.controller,
    this.hint,
    this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
    this.validator,
    this.errorText,
    this.helperText,
    this.maxLength,
    this.inputFormatters,
    this.autofocus = false,
    this.obscureText = false,
    this.onChanged,
    super.key,
  });

  final TextEditingController? controller;
  final String? hint;
  final String? label;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final String? helperText;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      maxLines: obscureText ? 1 : maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      maxLength: maxLength,
      maxLengthEnforcement: maxLength == null
          ? null
          : MaxLengthEnforcement.none,
      inputFormatters: inputFormatters,
      autofocus: autofocus,
      obscureText: obscureText,
      onChanged: onChanged,
      style: SimTypography.body.copyWith(color: palette.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        errorText: errorText,
        filled: true,
        fillColor: palette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SimRadius.lg),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SimRadius.lg),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SimRadius.lg),
          borderSide: BorderSide(color: palette.primary, width: 1.4),
        ),
      ),
    );
  }
}

class SimCard extends StatelessWidget {
  const SimCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SimLearningSurface(padding: const EdgeInsets.all(16), child: child);
}

class CardTitle extends StatelessWidget {
  const CardTitle({required this.icon, required this.title, super.key});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleIcon(icon: icon),
      const SizedBox(width: 10),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    ],
  );
}

class CircleIcon extends StatelessWidget {
  const CircleIcon({required this.icon, this.top = 0, super.key});

  final IconData icon;
  final double top;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: palette.selectedSurface,
        child: Icon(icon, color: palette.primary, size: 20),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => SimIconAction(
    icon: icon,
    semanticLabel: tooltip ?? t('menu'),
    onPressed: onTap,
  );
}

class CreditsPill extends StatelessWidget {
  const CreditsPill({
    this.credits,
    this.value,
    this.unlimited = false,
    this.isUnlimited = false,
    this.onTap,
    super.key,
  });

  final int? credits;
  final int? value;
  final bool unlimited;
  final bool isUnlimited;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: const Icon(Icons.bolt, size: 16),
    label: Text(
      unlimited || isUnlimited
          ? t('credits_unlimited')
          : '${credits ?? value ?? 0}',
    ),
    onPressed: onTap,
  );
}

class BackgroundDecor extends StatelessWidget {
  const BackgroundDecor({super.key});

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFFF8FAFC), child: SizedBox.expand());
}
