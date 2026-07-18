import 'package:flutter/material.dart';

import '../../shared/widgets/shared_widgets.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/ui/sim_i18n.dart';
import '../session/lab_session.dart';
import 'aula_widgets.dart';
import 'chat_aula_messages.dart';

class ChatAulaTimeline extends StatelessWidget {
  const ChatAulaTimeline({
    required this.messages,
    required this.onChooseAnswer,
    required this.onSignal,
    required this.onRetry,
    required this.onNext,
    required this.onOpenDoubt,
    this.session,
    this.onImageSettled,
    this.pendingActionKeys = const {},
    this.scrollController,
    this.initialScrollToCurrent = false,
    this.initialScrollKey,
    this.padding = const EdgeInsets.fromLTRB(16, 112, 16, 128),
    super.key,
  });

  final List<ChatLessonMessage> messages;
  final void Function(AnswerLetter letter) onChooseAnswer;
  final void Function(int value) onSignal;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  final VoidCallback onOpenDoubt;
  final LabSession? session;
  final VoidCallback? onImageSettled;
  final Set<String> pendingActionKeys;
  final ScrollController? scrollController;
  final bool initialScrollToCurrent;
  final String? initialScrollKey;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return Center(
        key: const Key('chat-empty-state'),
        child: Text(t('aula_choose_goal')),
      );
    }
    return ListView.builder(
      key: const Key('chat-aula-timeline'),
      controller: scrollController,
      padding: padding,
      itemCount: messages.length,
      itemBuilder: (context, index) => ChatAulaMessageBubble(
        message: messages[index],
        semanticIndex: index,
        onChooseAnswer: onChooseAnswer,
        onSignal: onSignal,
        onRetry: onRetry,
        onNext: onNext,
        onOpenDoubt: onOpenDoubt,
        session: session,
        pendingActionKeys: pendingActionKeys,
        onImageSettled: onImageSettled,
      ),
    );
  }
}

class AulaConversationActions {
  const AulaConversationActions({
    required this.chooseAnswer,
    required this.submitSignal,
    required this.advance,
    required this.retry,
    required this.openDoubt,
  });

  final void Function(AnswerLetter letter) chooseAnswer;
  final void Function(int value) submitSignal;
  final VoidCallback advance;
  final VoidCallback retry;
  final VoidCallback openDoubt;
}

class ChatAulaMessageBubble extends StatelessWidget {
  const ChatAulaMessageBubble({
    required this.message,
    required this.semanticIndex,
    required this.onChooseAnswer,
    required this.onSignal,
    required this.onRetry,
    required this.onNext,
    required this.onOpenDoubt,
    this.pendingActionKeys = const {},
    this.session,
    this.onImageSettled,
    super.key,
  });

  final ChatLessonMessage message;
  final int semanticIndex;
  final LabSession? session;
  final void Function(AnswerLetter letter) onChooseAnswer;
  final void Function(int value) onSignal;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  final VoidCallback onOpenDoubt;
  final Set<String> pendingActionKeys;
  final VoidCallback? onImageSettled;

  @override
  Widget build(BuildContext context) {
    final isStudent = message.role == ChatLessonMessageRole.student;
    return Align(
      alignment: isStudent ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          color: isStudent ? const Color(0xFFEFF6FF) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: AulaConversationBlockRenderer(
              block: AulaConversationBlock.fromMessage(message),
              pendingActionKeys: pendingActionKeys,
              onImageSettled: onImageSettled,
              actions: AulaConversationActions(
                chooseAnswer: onChooseAnswer,
                submitSignal: onSignal,
                advance: onNext,
                retry: onRetry,
                openDoubt: onOpenDoubt,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AulaConversationBlockRenderer extends StatelessWidget {
  const AulaConversationBlockRenderer({
    required this.block,
    required this.actions,
    this.pendingActionKeys = const {},
    this.onImageSettled,
    super.key,
  });

  final AulaConversationBlock block;
  final AulaConversationActions actions;
  final Set<String> pendingActionKeys;
  final VoidCallback? onImageSettled;

  @override
  Widget build(BuildContext context) {
    final message = block.message;
    return switch (block.type) {
      AulaConversationBlockType.answerOptions => _ChatOptions(
        message: message,
        onChooseAnswer: actions.chooseAnswer,
        onSignal: actions.submitSignal,
      ),
      AulaConversationBlockType.signalOptions => _ChatSignals(
        message: message,
        onSignal: actions.submitSignal,
      ),
      AulaConversationBlockType.visual => ChatImageBubble(
        message: message,
        onImageSettled: onImageSettled,
      ),
      AulaConversationBlockType.advanceAction => _ActionButton(
        label: message.text ?? t('continue'),
        onPressed: actions.openDoubt,
      ),
      AulaConversationBlockType.recoverableError => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.text ?? t('aula_gen_fail')),
          const SizedBox(height: 8),
          _ActionButton(label: t('retry'), onPressed: actions.retry),
        ],
      ),
      AulaConversationBlockType.loading => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(message.text ?? t('loading'))),
        ],
      ),
      _ => _TextBlock(message: message),
    };
  }
}

class ChatImageBubble extends StatefulWidget {
  const ChatImageBubble({
    required this.message,
    this.onImageSettled,
    super.key,
  });

  final ChatLessonMessage message;
  final VoidCallback? onImageSettled;

  @override
  State<ChatImageBubble> createState() => _ChatImageBubbleState();
}

class _ChatImageBubbleState extends State<ChatImageBubble> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onImageSettled?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.message.imageData?.trim();
    if (widget.message.imageStatus.toLowerCase() == 'failed') {
      return Text(widget.message.text ?? t('aula_image_unavailable_short'));
    }
    if (data == null || data.isEmpty) return Text(t('aula_image_loading'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LessonMediaImageView(data: data, compact: true),
        ),
        const SizedBox(height: 6),
        Text(
          widget.message.text ?? t('aula_image_alt'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.message});

  final ChatLessonMessage message;

  @override
  Widget build(BuildContext context) {
    final chunks = <Widget>[
      if ((message.title ?? '').isNotEmpty)
        Text(message.title!, style: Theme.of(context).textTheme.titleSmall),
      if ((message.text ?? '').isNotEmpty) Text(message.text!),
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

class _ChatOptions extends StatelessWidget {
  const _ChatOptions({
    required this.message,
    required this.onChooseAnswer,
    required this.onSignal,
  });

  final ChatLessonMessage message;
  final void Function(AnswerLetter letter) onChooseAnswer;
  final void Function(int value) onSignal;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final option in message.options)
        AnswerButton(
          key: Key('chat-answer-card-${option.letter.name}'),
          letter: option.letter.name,
          text: option.text,
          selected: option.selected,
          enabled: option.enabled,
          onTap: option.enabled ? () => onChooseAnswer(option.letter) : null,
        ),
      if (message.signals.isNotEmpty) const SizedBox(height: 8),
      if (message.signals.isNotEmpty)
        _ChatSignals(message: message, onSignal: onSignal),
    ],
  );
}

class _ChatSignals extends StatelessWidget {
  const _ChatSignals({required this.message, required this.onSignal});

  final ChatLessonMessage message;
  final void Function(int value) onSignal;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final signal in message.signals)
        FilterChip(
          key: Key('signal-button-${signal.value}'),
          label: Text(t(signal.labelKey)),
          selected: false,
          onSelected: signal.enabled ? (_) => onSignal(signal.value) : null,
        ),
    ],
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      FilledButton(onPressed: onPressed, child: Text(label));
}
