part of '../chat_aula_widgets.dart';

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
    final palette = SimThemeScope.paletteOf(context);
    final tone = _surfaceToneFor(message, isStudent);
    return Align(
      alignment: isStudent ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: EdgeInsets.only(bottom: _pedagogicalGapAfter(message)),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: SimLearningSurface(
                key: ValueKey('surface-${message.id}-${message.kind.name}'),
                tone: tone,
                borderWidth: message.kind == ChatLessonMessageKind.question
                    ? 1.5
                    : 1,
                padding: EdgeInsets.all(
                  message.kind == ChatLessonMessageKind.options
                      ? SimSpacing.sm
                      : SimSpacing.md,
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: palette.text),
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
          _StatusText(
            icon: Icons.info_outline,
            text: message.text ?? t('aula_gen_fail'),
            tone: SimSurfaceTone.danger,
          ),
          if (message.actionKey == 'retry-menu-lesson') ...[
            const SizedBox(height: SimSpacing.sm),
            _ActionButton(
              label: t('aula_try_again_2'),
              onPressed: actions.retry,
            ),
          ],
        ],
      ),
      AulaConversationBlockType.loading => _LiveLoadingBlock(
        message: message,
        onRetry: actions.retry,
      ),
      _ => _TextBlock(message: message),
    };
  }
}

SimSurfaceTone _surfaceToneFor(ChatLessonMessage message, bool isStudent) {
  if (isStudent) return SimSurfaceTone.selected;
  return switch (message.kind) {
    ChatLessonMessageKind.itemIntro => SimSurfaceTone.soft,
    ChatLessonMessageKind.question => SimSurfaceTone.elevated,
    ChatLessonMessageKind.feedback =>
      message.isCorrect == false
          ? SimSurfaceTone.warning
          : SimSurfaceTone.success,
    ChatLessonMessageKind.error => SimSurfaceTone.danger,
    ChatLessonMessageKind.loading ||
    ChatLessonMessageKind.processing => SimSurfaceTone.soft,
    ChatLessonMessageKind.options => SimSurfaceTone.soft,
    _ => SimSurfaceTone.normal,
  };
}
