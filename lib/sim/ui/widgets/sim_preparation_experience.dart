import 'package:flutter/material.dart';

import '../sim_i18n.dart';

class SimPreparationExperience extends StatelessWidget {
  const SimPreparationExperience({
    required this.stage,
    required this.ready,
    required this.onContinue,
    super.key,
  });

  final String stage;
  final bool ready;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final title = _titleFor(stage);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(ready ? Icons.check_circle : Icons.sync, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!ready) const LinearProgressIndicator(),
              if (ready) ...[
                Text(t('preparation_ready')),
                const SizedBox(height: 16),
                FilledButton(onPressed: onContinue, child: Text(t('continue'))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _titleFor(String stage) => switch (stage) {
    'review' => t('aux_review_intro_msg'),
    'reviewDone' => t('aux_review_done_msg'),
    'recovery' => t('aux_recovery_intro_msg'),
    'recoveryDone' => t('aux_recovery_done_msg'),
    'done' => t('lesson_done_title'),
    _ => t('preparation_chat_intro'),
  };
}
