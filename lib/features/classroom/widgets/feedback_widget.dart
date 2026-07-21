part of '../chat_aula_widgets.dart';

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.message});

  final ChatLessonMessage message;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final style = switch (message.kind) {
      ChatLessonMessageKind.itemIntro => SimTypography.label.copyWith(
        color: palette.muted,
      ),
      ChatLessonMessageKind.explanation => SimTypography.lessonBody.copyWith(
        color: palette.text,
      ),
      ChatLessonMessageKind.question => SimTypography.lessonQuestion.copyWith(
        color: palette.text,
        fontSize: 18,
      ),
      ChatLessonMessageKind.feedback => SimTypography.feedback.copyWith(
        color: message.isCorrect == false ? palette.warning : palette.success,
      ),
      _ => DefaultTextStyle.of(context).style.copyWith(color: palette.text),
    };
    final chunks = <Widget>[
      if ((message.title ?? '').isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: SimSpacing.xs),
          child: Text(
            message.title!,
            style: SimTypography.meta.copyWith(color: palette.muted),
          ),
        ),
      if ((message.text ?? '').isNotEmpty) Text(message.text!, style: style),
      if (message.selectedAnswer != null)
        Text(message.selectedAnswer!.name, textAlign: TextAlign.right),
      if (message.selectedSignal != null)
        Text('${message.selectedSignal!.value}', textAlign: TextAlign.right),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: chunks.isEmpty ? [Text(t('loading'))] : chunks,
    );
  }
}

class _LiveLoadingBlock extends StatelessWidget {
  const _LiveLoadingBlock({required this.message, required this.onRetry});

  final ChatLessonMessage message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (message.id == 'doubt-processing' && (message.progress ?? 0) > 0) {
      return DoubtProgressBar(
        progress: message.progress!,
        label: message.text ?? t('aula_doubt_processing'),
      );
    }
    if (message.actionKey == 'retry-menu-lesson') {
      return _MenuLessonArrivalBlock(message: message, onRetry: onRetry);
    }
    return _StatusText(
      icon: Icons.auto_awesome,
      text: message.text ?? t('loading'),
      tone: SimSurfaceTone.soft,
      loading: true,
    );
  }
}

class _MenuLessonArrivalBlock extends StatefulWidget {
  const _MenuLessonArrivalBlock({required this.message, required this.onRetry});

  final ChatLessonMessage message;
  final VoidCallback onRetry;

  @override
  State<_MenuLessonArrivalBlock> createState() =>
      _MenuLessonArrivalBlockState();
}

class _MenuLessonArrivalBlockState extends State<_MenuLessonArrivalBlock> {
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  void _scheduleTick() {
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _tick = (_tick + 1).clamp(0, 6));
      if (_tick < 6) _scheduleTick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final progress = ((_tick + 1) / 6).clamp(0.18, 0.92);
    final detail = _tick < 2
        ? 'Localizando este ponto.'
        : _tick < 4
        ? 'Chamando o professor.'
        : 'Quase lá. A aula entra aqui.';
    return SimStatusSurface(
      tone: SimSurfaceTone.soft,
      icon: Icons.auto_awesome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message.text ?? t('aula_menu_lesson_arriving'),
            style: SimTypography.label.copyWith(color: palette.text),
          ),
          const SizedBox(height: SimSpacing.xs),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              detail,
              key: ValueKey(detail),
              style: SimTypography.caption.copyWith(color: palette.muted),
            ),
          ),
          const SizedBox(height: SimSpacing.sm),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.12, end: progress.toDouble()),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              minHeight: 4,
              value: value,
              backgroundColor: palette.border,
            ),
          ),
          if (_tick >= 5) ...[
            const SizedBox(height: SimSpacing.sm),
            SimActionButton(
              label: t('aula_try_again_2'),
              icon: Icons.refresh,
              onPressed: widget.onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({
    required this.icon,
    required this.text,
    required this.tone,
    this.loading = false,
  });

  final IconData icon;
  final String text;
  final SimSurfaceTone tone;
  final bool loading;

  @override
  Widget build(BuildContext context) => SimStatusSurface(
    tone: tone,
    icon: icon,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: SimTypography.caption),
        if (loading) ...[
          const SizedBox(height: SimSpacing.xs),
          const LinearProgressIndicator(minHeight: 3),
        ],
      ],
    ),
  );
}
