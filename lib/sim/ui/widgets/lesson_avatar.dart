import 'package:flutter/material.dart';

import '../sim_i18n.dart';
import '../sim_theme.dart';

class LessonAvatar extends StatefulWidget {
  const LessonAvatar({this.speaking = false, super.key});

  final bool speaking;

  @override
  State<LessonAvatar> createState() => _LessonAvatarState();
}

class _LessonAvatarState extends State<LessonAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.speaking) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(LessonAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.speaking && !oldWidget.speaking) {
      _controller.repeat(reverse: true);
    } else if (!widget.speaking && oldWidget.speaking) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      image: true,
      label: widget.speaking ? t('a11y_sim_speaking') : 'SIM',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.surface,
              border: Border.all(color: palette.primary, width: 1.5),
            ),
            child: Icon(Icons.smart_toy, color: palette.primary, size: 22),
          ),
          const SizedBox(width: 8),
          _WaveformBar(animation: _controller, speaking: widget.speaking),
        ],
      ),
    );
  }
}

class _WaveformBar extends StatelessWidget {
  const _WaveformBar({required this.animation, required this.speaking});

  final AnimationController animation;
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return SizedBox(
      width: 24,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (i) {
          final delay = i / 4;
          return AnimatedBuilder(
            animation: animation,
            builder: (_, _) {
              final t = speaking ? ((animation.value + delay) % 1.0) : 0.28;
              final h = speaking
                  ? (0.28 + 0.72 * (0.5 - (t - 0.5).abs()) * 2)
                  : 0.28;
              return Container(
                width: 4,
                height: 20 * h,
                decoration: BoxDecoration(
                  color: palette.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
