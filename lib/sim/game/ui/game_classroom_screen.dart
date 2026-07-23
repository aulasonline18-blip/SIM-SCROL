import 'package:flutter/material.dart';

import '../game_runtime_controller.dart';
import 'game_card_view.dart';

final class GameClassroomScreen extends StatefulWidget {
  const GameClassroomScreen({
    super.key,
    required this.controller,
    required this.nowMs,
    this.mediaEnabled = true,
    this.audioEnabled = true,
    this.onNeedMicrodeck,
    this.onOpenDoubt,
    this.onToggleAudio,
    this.onError,
  });

  final GameRuntimeController controller;
  final int Function() nowMs;
  final bool mediaEnabled;
  final bool audioEnabled;
  final VoidCallback? onNeedMicrodeck;
  final VoidCallback? onOpenDoubt;
  final VoidCallback? onToggleAudio;
  final void Function(Object error)? onError;

  @override
  State<GameClassroomScreen> createState() => _GameClassroomScreenState();
}

final class _GameClassroomScreenState extends State<GameClassroomScreen> {
  Object? _localError;

  @override
  Widget build(BuildContext context) {
    final status = _statusText();
    final cardId = widget.controller.currentCardId;
    final index = widget.controller.currentIndex;

    return Scaffold(
      key: const Key('sim_game_classroom_screen'),
      appBar: AppBar(
        key: const Key('sim_game_classroom_header'),
        title: const Text('SIM Game'),
        actions: [
          IconButton(
            tooltip: 'Áudio',
            onPressed: widget.onToggleAudio,
            icon: Icon(
              widget.audioEnabled ? Icons.volume_up : Icons.volume_off,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                status,
                key: const Key('sim_game_classroom_status'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _identityText(cardId: cardId, index: index),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_localError != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Erro local. Tente novamente.',
                  key: const Key('sim_game_classroom_error'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: KeyedSubtree(
                  key: const Key('sim_game_classroom_card_host'),
                  child: GameCardView(
                    controller: widget.controller,
                    nowMs: widget.nowMs,
                    mediaEnabled: widget.mediaEnabled,
                    audioEnabled: widget.audioEnabled,
                    onChanged: _handleCardChanged,
                    onNeedMicrodeck: _handleNeedMicrodeck,
                    onOpenDoubt: widget.onOpenDoubt,
                    onToggleAudio: widget.onToggleAudio,
                    onError: _handleError,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText() {
    if (_localError != null) return 'Erro';
    if (widget.controller.needsMicrodeck ||
        widget.controller.currentCard == null) {
      return 'Preparando carta';
    }
    if (widget.controller.canShowFeedback) return 'Feedback';
    if (widget.controller.selectedAnswer != null) return 'Escolha seu sinal';
    return 'Carta pronta';
  }

  String _identityText({required String? cardId, required int? index}) {
    final card = cardId == null ? 'sem carta' : 'carta $cardId';
    final position = index == null ? 'sem indice' : 'indice ${index + 1}';
    return '$card · $position';
  }

  void _handleCardChanged() {
    setState(() {
      _localError = null;
    });
  }

  void _handleError(Object error) {
    setState(() {
      _localError = error;
    });
    widget.onError?.call(error);
  }

  void _handleNeedMicrodeck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onNeedMicrodeck?.call();
    });
  }
}
