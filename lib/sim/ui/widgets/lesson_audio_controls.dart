import 'package:flutter/material.dart';

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
    return IconButton(
      tooltip: playing ? t('aula_audio_stop') : t('aula_audio_play'),
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              playing
                  ? Icons.stop_circle_outlined
                  : enabled
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
            ),
    );
  }
}
