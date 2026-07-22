part of '../onboarding_screens.dart';

class OnboardingChatFlow extends StatelessWidget {
  const OnboardingChatFlow({
    required this.children,
    required this.semanticLabel,
    this.scrollable = true,
    super.key,
  });

  final List<Widget> children;
  final String semanticLabel;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final content = Padding(
      padding: SimBreakpoints.pagePadding(
        width,
      ).copyWith(top: SimSpacing.lg, bottom: SimSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    return Semantics(
      label: semanticLabel,
      child: scrollable
          ? ListView(padding: EdgeInsets.zero, children: [content])
          : content,
    );
  }
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
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return SimLearningSurface(
      tone: SimSurfaceTone.selected,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: SimTypography.lessonQuestion.copyWith(color: palette.text),
          ),
          if (supportingText != null) ...[
            const SizedBox(height: 6),
            Text(
              supportingText!,
              style: SimTypography.muted.copyWith(color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) => Wrap(
    spacing: SimSpacing.sm,
    runSpacing: SimSpacing.sm,
    children: children,
  );
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
  Widget build(BuildContext context) => SimIconAction(
    icon: Icons.arrow_forward,
    semanticLabel: semanticLabel,
    onPressed: onPressed,
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
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? palette.selectedSurface : palette.surface,
        borderRadius: BorderRadius.circular(SimRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SimRadius.lg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: SimTouch.min),
            padding: const EdgeInsets.symmetric(
              horizontal: SimSpacing.md,
              vertical: SimSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SimRadius.lg),
              border: Border.all(
                color: selected ? palette.primary : palette.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: SimTypography.label.copyWith(
                color: palette.text,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
    final palette = SimThemeScope.paletteOf(context);
    return Text(text, style: SimTypography.label.copyWith(color: palette.text));
  }
}

class SimChatError extends StatelessWidget {
  const SimChatError({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: text,
    child: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SimStatusSurface(
        tone: SimSurfaceTone.danger,
        icon: Icons.error_outline,
        child: Text(text),
      ),
    ),
  );
}
