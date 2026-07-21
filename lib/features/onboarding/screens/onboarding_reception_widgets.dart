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
          'Com isso, consigo preparar uma aula mais certeira para você.',
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
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
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
                label: 'Editar',
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

class _BigChoiceButton extends StatelessWidget {
  const _BigChoiceButton({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.selectedSurface : palette.surface,
        borderRadius: BorderRadius.circular(SimRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SimRadius.lg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.all(SimSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SimRadius.lg),
              border: Border.all(
                color: selected ? palette.primary : palette.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: selected
                      ? palette.primary
                      : palette.surfaceSoft,
                  child: Icon(
                    icon,
                    color: selected ? palette.onPrimary : palette.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: SimSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: SimTypography.action),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: SimTypography.caption.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
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

class _TextStep extends StatelessWidget {
  const _TextStep({
    required this.controller,
    required this.label,
    required this.help,
    required this.onChanged,
    required this.onNext,
    this.minLines = 2,
    this.optional = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String help;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final int minLines;
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
        maxLines: minLines,
      ),
      const SizedBox(height: 12),
      PrimaryWideButton(
        label: optional ? 'Continuar' : 'Salvar e continuar',
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
    this.optional = false,
  });

  final TextEditingController controller;
  final String label;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final bool optional;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SimChatFieldLabel(label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            ChoiceChip(
              label: Text(option),
              selected: controller.text == option,
              onSelected: (_) {
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
            ? 'Escreva outro ou deixe em branco.'
            : 'Escreva se preferir.',
        onChanged: onChanged,
      ),
      const SizedBox(height: 12),
      PrimaryWideButton(
        label: optional ? 'Continuar' : 'Salvar e continuar',
        onPressed: onNext,
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
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String help;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SimChatFieldLabel(label),
      const SizedBox(height: 4),
      Text(
        help,
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      ),
      const SizedBox(height: 8),
      SimInput(
        controller: controller,
        hint: '',
        maxLines: maxLines,
        onChanged: onChanged,
      ),
    ],
  );
}
