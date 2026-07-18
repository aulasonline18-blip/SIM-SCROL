import 'package:flutter/material.dart';

import '../../auxiliary/doubt_progress_bar.dart';
import '../sim_theme.dart';

class DoubtProgressBar extends StatelessWidget {
  const DoubtProgressBar({required this.progress, this.label, super.key});

  final int progress;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final pct = progress.clamp(0, 100);
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      label: label ?? doubtProgressLabel(pct),
      value: '$pct%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label ?? doubtProgressLabel(pct),
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$pct%',
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: pct / 100),
          ),
        ],
      ),
    );
  }
}
