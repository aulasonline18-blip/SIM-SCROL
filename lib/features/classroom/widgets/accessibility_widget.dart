part of '../chat_aula_widgets.dart';

class _ChatSignals extends StatelessWidget {
  const _ChatSignals({required this.message, required this.onSignal});

  final ChatLessonMessage message;
  final void Function(int value) onSignal;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final signal in message.signals)
        _SignalChoice(
          key: Key('signal-button-${signal.value}'),
          value: signal.value,
          label: t(signal.labelKey),
          enabled: signal.enabled,
          onTap: () => onSignal(signal.value),
        ),
    ],
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      SimActionButton(label: label, onPressed: onPressed);
}

class _SignalChoice extends StatelessWidget {
  const _SignalChoice({
    required this.value,
    required this.label,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final int value;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled ? palette.surface : palette.surfaceSoft,
        borderRadius: BorderRadius.circular(SimRadius.pill),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(SimRadius.pill),
          child: Container(
            constraints: const BoxConstraints(minHeight: SimTouch.min),
            padding: const EdgeInsets.symmetric(
              horizontal: SimSpacing.md,
              vertical: SimSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SimRadius.pill),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: palette.warningSurface,
                  child: Text(
                    '$value',
                    style: TextStyle(
                      color: palette.warning,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: SimSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SimTypography.label.copyWith(
                      color: enabled ? palette.text : palette.muted,
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
