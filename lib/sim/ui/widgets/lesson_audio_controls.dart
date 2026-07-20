import 'package:flutter/material.dart';

import '../sim_design_system.dart';
import '../sim_i18n.dart';

class LessonAudioControlButton extends StatelessWidget {
  const LessonAudioControlButton({
    required this.enabled,
    required this.playing,
    required this.loading,
    required this.onPressed,
    super.key,
  });

  final bool enabled;
  final bool playing;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = playing
        ? Icons.stop_circle_outlined
        : enabled
        ? Icons.volume_up_outlined
        : Icons.volume_off_outlined;
    return SimIconAction(
      icon: icon,
      semanticLabel: playing ? t('aula_audio_stop') : t('aula_audio_play'),
      onPressed: loading ? null : onPressed,
      size: SimTouch.icon,
      iconSize: 20,
      child: loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}
