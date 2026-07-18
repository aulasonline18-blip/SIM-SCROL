import 'package:flutter/material.dart';

import '../../features/session/lab_session.dart';
import '../../sim/ui/sim_i18n.dart';

const _primary = Color(0xFF2563EB);
const _border = Color(0xFFE5E7EB);
const _surface = Color(0xFFFFFFFF);
const _ink = Color(0xFF111827);

BoxDecoration glassDecoration({double radius = 12}) => BoxDecoration(
  color: Colors.white.withValues(alpha: 0.92),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: _border),
  boxShadow: const [
    BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8)),
  ],
);

BoxDecoration glassDecorationFor(BuildContext context, {double radius = 12}) =>
    glassDecoration(radius: radius);

BoxDecoration primaryButtonDecorationFor(
  BuildContext context, {
  double radius = 12,
}) =>
    BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(radius));

BoxDecoration pillDecorationFor(BuildContext context) => BoxDecoration(
  color: const Color(0xFFF8FAFC),
  borderRadius: BorderRadius.circular(999),
  border: Border.all(color: _border),
);

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
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(onPressed: onPressed ?? onTap, child: Text(label)),
  );
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
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(onPressed: onTap, child: Text(label)),
  );
}

class AnswerButton extends StatelessWidget {
  const AnswerButton({
    required this.letter,
    required this.text,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
    super.key,
  });

  final String letter;
  final String text;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        backgroundColor: selected ? const Color(0xFFEFF6FF) : _surface,
        side: BorderSide(color: selected ? _primary : _border),
        padding: const EdgeInsets.all(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: selected ? _primary : const Color(0xFFF3F4F6),
            child: Text(
              letter,
              style: TextStyle(color: selected ? Colors.white : _ink),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

class SimAulaMenuButton extends StatelessWidget {
  const SimAulaMenuButton({required this.onTap, this.size = 44, super.key});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: IconButton(
      tooltip: t('menu'),
      icon: const Icon(Icons.menu_rounded),
      onPressed: onTap,
    ),
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

Future<String?> _askLessonName(
  BuildContext context,
  dynamic lesson,
) {
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

Future<bool?> _confirmDeleteLesson(
  BuildContext context,
  dynamic lesson,
) {
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
      subtitle: Text('${lesson.nivel} - ${lesson.concluidos}/${lesson.totalItens}'),
      onTap: onOpen,
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: t('rename_lesson'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: onRename,
          ),
          IconButton(
            tooltip: t('delete_lesson'),
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
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
  SupportedLang(code: 'ja', name: 'Japanese', native: '日本語', flag: 'JP'),
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
  Widget build(BuildContext context) => ChoiceChip(
    selected: selected,
    label: Text('${language.flag} ${language.native}'),
    onSelected: (_) => onTap(),
  );
}

class StepHeader extends StatelessWidget {
  const StepHeader({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ],
  );
}

class SimInput extends StatelessWidget {
  const SimInput({
    this.controller,
    this.hint,
    this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    super.key,
  });

  final TextEditingController? controller;
  final String? hint;
  final String? label;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    maxLines: obscureText ? 1 : maxLines,
    keyboardType: keyboardType,
    obscureText: obscureText,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
  );
}

class SimCard extends StatelessWidget {
  const SimCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: _border),
    ),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top),
    child: CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFEFF6FF),
      child: Icon(icon, color: _primary, size: 20),
    ),
  );
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
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: tooltip,
    icon: Icon(icon),
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
