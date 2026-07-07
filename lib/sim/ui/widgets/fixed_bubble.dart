import 'package:flutter/material.dart';

import '../sim_i18n.dart';

/// Pulsing audio indicator bubble — shown when audio is enabled AND speaking.
/// Port of FixedBubble.tsx: fixed bottom-center, 40×40, animate-pulse-bubble (1.2s).
class FixedBubble extends StatefulWidget {
  const FixedBubble({
    super.key,
    required this.audioEnabled,
    required this.speaking,
    this.onTap,
  });

  final bool audioEnabled;
  final bool speaking;
  final VoidCallback? onTap;

  @override
  State<FixedBubble> createState() => _FixedBubbleState();
}

class _FixedBubbleState extends State<FixedBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _syncPulse();
  }

  @override
  void didUpdateWidget(FixedBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioEnabled != widget.audioEnabled ||
        oldWidget.speaking != widget.speaking) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    if (widget.audioEnabled && widget.speaking) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
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
    if (!widget.audioEnabled || !widget.speaking) {
      return const SizedBox.shrink();
    }
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Semantics(
          button: true,
          enabled: widget.onTap != null,
          label: t('audio_playing'),
          child: ScaleTransition(
            scale: _scale,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: widget.onTap,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF111827),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2E111827),
                        blurRadius: 18,
                        spreadRadius: -4,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.volume_up,
                    color: Color(0xFF111827),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
