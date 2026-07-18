import 'package:flutter/material.dart';

import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/sim_theme.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../session/lab_session.dart';

class LessonNoCurriculumScreen extends StatelessWidget {
  const LessonNoCurriculumScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(32),
              decoration: glassDecoration(radius: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t('aula_no_curr_h1'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t('aula_no_curr_body'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  PrimaryWideButton(
                    label: t('aula_back_curr'),
                    onTap: () => session.openSupport('/cyber/objeto'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
