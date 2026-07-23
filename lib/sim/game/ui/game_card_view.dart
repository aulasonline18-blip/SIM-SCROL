import 'package:flutter/material.dart';

import '../../state/student_learning_state.dart';
import '../game_runtime_controller.dart';
import '../pedagogical_card.dart';

final class GameCardView extends StatelessWidget {
  const GameCardView({
    super.key,
    required this.controller,
    required this.nowMs,
    this.mediaEnabled = true,
    this.audioEnabled = true,
    this.onChanged,
    this.onNeedMicrodeck,
    this.onOpenDoubt,
    this.onToggleAudio,
    this.onError,
  });

  final GameRuntimeController controller;
  final int Function() nowMs;
  final bool mediaEnabled;
  final bool audioEnabled;
  final VoidCallback? onChanged;
  final VoidCallback? onNeedMicrodeck;
  final VoidCallback? onOpenDoubt;
  final VoidCallback? onToggleAudio;
  final void Function(Object error)? onError;

  @override
  Widget build(BuildContext context) {
    final card = controller.currentCard;

    if (card == null || controller.needsMicrodeck) {
      return _buildEmpty(context);
    }

    return _buildCard(context, card);
  }

  Widget _buildEmpty(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      key: const Key('sim_game_card_empty'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: null,
              color: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 16),
            const Text(
              'Preparando carta',
              key: Key('sim_game_needs_microdeck'),
              softWrap: true,
            ),
            if (onNeedMicrodeck != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('sim_game_need_microdeck_action'),
                onPressed: onNeedMicrodeck,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Preparar'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, PedagogicalCard card) {
    return Card(
      key: const Key('sim_game_card_ready'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (controller.currentIndex == null)
                  ? null
                  : (controller.currentIndex! + 1) /
                        (controller.currentIndex! + 1),
            ),
            const SizedBox(height: 16),
            Text(
              card.explanation,
              key: const Key('sim_game_explanation'),
              softWrap: true,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            _MediaBlock(
              card: card,
              mediaEnabled: mediaEnabled,
              audioEnabled: audioEnabled,
              onToggleAudio: onToggleAudio,
            ),
            const SizedBox(height: 16),
            Text(
              card.question,
              key: const Key('sim_game_question'),
              softWrap: true,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _AnswerButton(
              letter: AnswerLetter.A,
              text: card.options[AnswerLetter.A] ?? '',
              selected: controller.selectedAnswer == AnswerLetter.A,
              enabled: controller.canSelectAnswer,
              onPressed: () => _selectAnswer(AnswerLetter.A),
            ),
            const SizedBox(height: 8),
            _AnswerButton(
              letter: AnswerLetter.B,
              text: card.options[AnswerLetter.B] ?? '',
              selected: controller.selectedAnswer == AnswerLetter.B,
              enabled: controller.canSelectAnswer,
              onPressed: () => _selectAnswer(AnswerLetter.B),
            ),
            const SizedBox(height: 8),
            _AnswerButton(
              letter: AnswerLetter.C,
              text: card.options[AnswerLetter.C] ?? '',
              selected: controller.selectedAnswer == AnswerLetter.C,
              enabled: controller.canSelectAnswer,
              onPressed: () => _selectAnswer(AnswerLetter.C),
            ),
            if (controller.selectedAnswer != null) ...[
              const SizedBox(height: 16),
              _QualifierButton(
                decision: DecisionSignal.one,
                text: card.qualifiers[DecisionSignal.one] ?? '',
                selected: controller.selectedQualifier == DecisionSignal.one,
                enabled: controller.canSelectQualifier,
                onPressed: () => _selectQualifier(DecisionSignal.one),
              ),
              const SizedBox(height: 8),
              _QualifierButton(
                decision: DecisionSignal.two,
                text: card.qualifiers[DecisionSignal.two] ?? '',
                selected: controller.selectedQualifier == DecisionSignal.two,
                enabled: controller.canSelectQualifier,
                onPressed: () => _selectQualifier(DecisionSignal.two),
              ),
              const SizedBox(height: 8),
              _QualifierButton(
                decision: DecisionSignal.three,
                text: card.qualifiers[DecisionSignal.three] ?? '',
                selected: controller.selectedQualifier == DecisionSignal.three,
                enabled: controller.canSelectQualifier,
                onPressed: () => _selectQualifier(DecisionSignal.three),
              ),
            ],
            if (controller.canShowFeedback &&
                controller.feedbackText != null) ...[
              const SizedBox(height: 16),
              DecoratedBox(
                key: const Key('sim_game_feedback'),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    controller.feedbackText!,
                    softWrap: true,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('sim_game_continue_button'),
                onPressed: _advance,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Continuar'),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const Key('sim_game_doubt_button'),
                tooltip: 'Abrir dúvida',
                onPressed: onOpenDoubt,
                icon: const Icon(Icons.help_outline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectAnswer(AnswerLetter letter) {
    try {
      controller.selectAnswer(letter, clientTimestampMs: nowMs());
      onChanged?.call();
    } catch (error) {
      _report(error);
    }
  }

  void _selectQualifier(DecisionSignal decision) {
    try {
      controller.selectQualifier(decision, clientTimestampMs: nowMs());
      onChanged?.call();
    } catch (error) {
      _report(error);
    }
  }

  void _advance() {
    try {
      controller.advanceToNextCard(clientTimestampMs: nowMs());
      if (controller.needsMicrodeck) {
        onNeedMicrodeck?.call();
      }
      onChanged?.call();
    } catch (error) {
      _report(error);
    }
  }

  void _report(Object error) {
    final handler = onError;
    if (handler == null) {
      throw error;
    }
    handler(error);
  }
}

final class _MediaBlock extends StatelessWidget {
  const _MediaBlock({
    required this.card,
    required this.mediaEnabled,
    required this.audioEnabled,
    required this.onToggleAudio,
  });

  final PedagogicalCard card;
  final bool mediaEnabled;
  final bool audioEnabled;
  final VoidCallback? onToggleAudio;

  @override
  Widget build(BuildContext context) {
    final media = card.media;
    final hasImage =
        mediaEnabled && media?.imageKey != null && media!.imageKey!.isNotEmpty;
    final hasAudio =
        audioEnabled && media?.audioKey != null && media!.audioKey!.isNotEmpty;

    if (!hasImage && !hasAudio) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          if (hasImage)
            Expanded(
              child: DecoratedBox(
                key: const Key('sim_game_image_placeholder'),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Midia visual: ${media.imageKey}',
                    softWrap: true,
                  ),
                ),
              ),
            ),
          if (hasImage && hasAudio) const SizedBox(width: 8),
          if (hasAudio)
            IconButton(
              key: const Key('sim_game_audio_button'),
              tooltip: 'Áudio',
              onPressed: onToggleAudio,
              icon: const Icon(Icons.volume_up),
            ),
        ],
      ),
    );
  }
}

final class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.letter,
    required this.text,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final AnswerLetter letter;
  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = switch (letter) {
      AnswerLetter.A => 'A',
      AnswerLetter.B => 'B',
      AnswerLetter.C => 'C',
    };
    final keyName = switch (letter) {
      AnswerLetter.A => 'sim_game_answer_A',
      AnswerLetter.B => 'sim_game_answer_B',
      AnswerLetter.C => 'sim_game_answer_C',
    };

    return Semantics(
      label: 'Alternativa $label',
      selected: selected,
      button: true,
      child: OutlinedButton(
        key: Key(keyName),
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(48),
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          foregroundColor: selected
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : null,
        ),
        child: Row(
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 18),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text('$label. $text', softWrap: true)),
          ],
        ),
      ),
    );
  }
}

final class _QualifierButton extends StatelessWidget {
  const _QualifierButton({
    required this.decision,
    required this.text,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final DecisionSignal decision;
  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = switch (decision) {
      DecisionSignal.one => '1',
      DecisionSignal.two => '2',
      DecisionSignal.three => '3',
    };
    final keyName = switch (decision) {
      DecisionSignal.one => 'sim_game_qualifier_1',
      DecisionSignal.two => 'sim_game_qualifier_2',
      DecisionSignal.three => 'sim_game_qualifier_3',
    };

    return Semantics(
      label: 'Sinal $label',
      selected: selected,
      button: true,
      child: OutlinedButton(
        key: Key(keyName),
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(48),
          backgroundColor: selected
              ? Theme.of(context).colorScheme.tertiaryContainer
              : null,
          foregroundColor: selected
              ? Theme.of(context).colorScheme.onTertiaryContainer
              : null,
        ),
        child: Row(
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 18),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text('$label. $text', softWrap: true)),
          ],
        ),
      ),
    );
  }
}
