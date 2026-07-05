import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/utils/sim_constants.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/sim_theme.dart';
import '../../sim/ui/widgets/doubt_progress_bar.dart';
import '../session/lab_session.dart';
import 'aula_widgets.dart';
import 'chat_aula_messages.dart';

class ChatAulaTimeline extends StatefulWidget {
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
  final EdgeInsets padding;

  @override
  State<ChatAulaTimeline> createState() => _ChatAulaTimelineState();
}

class _ChatAulaTimelineState extends State<ChatAulaTimeline> {
  static const _scrollDuration = Duration(milliseconds: 420);

  late final ScrollController _scrollController =
      widget.scrollController ?? ScrollController();
  late final bool _ownsScrollController = widget.scrollController == null;
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  final FocusNode _timelineFocusNode = FocusNode(
    debugLabel: 'chat-aula-timeline-focus',
  );
  bool _autoFollow = true;
  bool _showCurrentButton = false;
  int _unreadWhileAway = 0;
  String _messageSignature = '';

  @override
  void initState() {
    super.initState();
    _messageSignature = _signatureOf(widget.messages);
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToCurrent(immediate: true),
    );
  }

  @override
  void didUpdateWidget(ChatAulaTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = _signatureOf(widget.messages);
    if (nextSignature == _messageSignature) return;
    _messageSignature = nextSignature;
    _retainMessageKeys(widget.messages);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_autoFollow) {
        _scrollToCurrent();
      } else {
        setState(() {
          _showCurrentButton = true;
          _unreadWhileAway++;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    if (_ownsScrollController) _scrollController.dispose();
    _timelineFocusNode.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final nearEnd = position.maxScrollExtent - position.pixels <= 96;
    if (nearEnd != _autoFollow || _showCurrentButton == nearEnd) {
      setState(() {
        _autoFollow = nearEnd;
        _showCurrentButton = !nearEnd;
        if (nearEnd) _unreadWhileAway = 0;
      });
    }
  }

  Future<void> _scrollToCurrent({bool immediate = false}) async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
      return;
    }
    final target = _targetMessage();
    final targetKey = target == null ? null : _messageKeys[target.message.id];
    final targetContext = targetKey?.currentContext;
    if (targetContext != null && target != null) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: immediate ? Duration.zero : _scrollDuration,
        curve: Curves.easeOutCubic,
        alignment: target.alignment,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    } else {
      final fallbackOffset = _fallbackOffsetFor(position, target?.message);
      if (immediate) {
        _scrollController.jumpTo(fallbackOffset);
      } else {
        await _scrollController.animateTo(
          fallbackOffset,
          duration: _scrollDuration,
          curve: Curves.easeOutCubic,
        );
      }
      if (target != null && mounted) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        final retryContext = _messageKeys[target.message.id]?.currentContext;
        if (retryContext != null && retryContext.mounted) {
          await Scrollable.ensureVisible(
            retryContext,
            duration: immediate ? Duration.zero : _scrollDuration,
            curve: Curves.easeOutCubic,
            alignment: target.alignment,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
          );
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _autoFollow = true;
      _showCurrentButton = false;
      _unreadWhileAway = 0;
    });
  }

  Future<void> _scrollByViewport(double factor) async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (position.pixels + (position.viewportDimension * factor))
        .clamp(0.0, position.maxScrollExtent);
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _scrollToTranscriptStart() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  double _fallbackOffsetFor(
    ScrollPosition position,
    ChatLessonMessage? targetMessage,
  ) {
    if (targetMessage?.kind == ChatLessonMessageKind.explanation) {
      final lead = position.viewportDimension * 0.72;
      return (position.maxScrollExtent - lead).clamp(
        0.0,
        position.maxScrollExtent,
      );
    }
    return position.maxScrollExtent;
  }

  String _signatureOf(List<ChatLessonMessage> messages) {
    return messages
        .map(
          (message) => [
            message.id,
            message.kind.name,
            message.text ?? '',
            message.imageData ?? '',
            message.imageStatus,
            message.hasPaidImageOffer.toString(),
            message.actionKey ?? '',
            message.deliveryStatus.name,
            message.timestampLabel ?? '',
            message.sequenceIndex?.toString() ?? '',
            message.isCorrect?.toString() ?? '',
            message.progress?.toString() ?? '',
            message.options
                .map(
                  (option) =>
                      '${option.letter.name}:${option.selected}:${option.enabled}',
                )
                .join(','),
            message.signals
                .map((signal) => '${signal.value}:${signal.enabled}')
                .join(','),
          ].join('|'),
        )
        .join('||');
  }

  void _retainMessageKeys(List<ChatLessonMessage> messages) {
    final ids = messages.map((message) => message.id).toSet();
    _messageKeys.removeWhere((id, _) => !ids.contains(id));
  }

  GlobalKey _keyForMessage(ChatLessonMessage message) {
    return _messageKeys.putIfAbsent(
      message.id,
      () => GlobalKey(debugLabel: 'chat-message-${message.id}'),
    );
  }

  _ChatScrollTarget? _targetMessage() {
    if (widget.messages.isEmpty) return null;
    var latestExplanationIndex = -1;
    var latestLiveIndex = -1;
    ChatLessonMessage? latestLiveMessage;
    for (var i = 0; i < widget.messages.length; i++) {
      final message = widget.messages[i];
      if (message.kind == ChatLessonMessageKind.explanation) {
        latestExplanationIndex = i;
      }
      final isLiveTarget = switch (message.kind) {
        ChatLessonMessageKind.feedback ||
        ChatLessonMessageKind.processing ||
        ChatLessonMessageKind.error => true,
        ChatLessonMessageKind.options =>
          message.selectedAnswer != null || message.signals.isNotEmpty,
        _ => false,
      };
      if (isLiveTarget) {
        latestLiveIndex = i;
        latestLiveMessage = message;
      }
    }
    if (latestExplanationIndex > latestLiveIndex) {
      final hasPriorFeedback = widget.messages
          .take(latestExplanationIndex)
          .any((message) => message.kind == ChatLessonMessageKind.feedback);
      if (hasPriorFeedback) {
        return _ChatScrollTarget.forMessage(
          widget.messages[latestExplanationIndex],
        );
      }
    }
    if (latestLiveMessage != null) {
      return _ChatScrollTarget.forMessage(latestLiveMessage);
    }

    for (final message in widget.messages.reversed) {
      if (message.kind == ChatLessonMessageKind.image &&
          message.imageData != null &&
          message.imageData!.trim().isNotEmpty) {
        return _ChatScrollTarget.forMessage(message);
      }
    }

    for (final message in widget.messages.reversed) {
      if (message.kind == ChatLessonMessageKind.options ||
          message.kind == ChatLessonMessageKind.question ||
          message.kind == ChatLessonMessageKind.image) {
        return _ChatScrollTarget.forMessage(message);
      }
    }

    final latestTurnStart = widget.messages.lastWhere(
      (message) => message.kind == ChatLessonMessageKind.explanation,
      orElse: () => widget.messages.last,
    );
    return _ChatScrollTarget.forMessage(latestTurnStart);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.end): () {
          _scrollToCurrent();
        },
        const SingleActivator(LogicalKeyboardKey.home): () {
          _scrollToTranscriptStart();
        },
        const SingleActivator(LogicalKeyboardKey.pageDown): () {
          _scrollByViewport(0.82);
        },
        const SingleActivator(LogicalKeyboardKey.pageUp): () {
          _scrollByViewport(-0.82);
        },
      },
      child: Focus(
        autofocus: true,
        focusNode: _timelineFocusNode,
        child: Semantics(
          container: true,
          label: t('aula_conversation_region'),
          hint: t('aula_conversation_keyboard_hint'),
          child: Stack(
            children: [
              NotificationListener<SizeChangedLayoutNotification>(
                onNotification: (_) {
                  if (_autoFollow) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scrollToCurrent(),
                    );
                  }
                  return false;
                },
                child: NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    if (notification.direction != ScrollDirection.idle) {
                      final metrics = notification.metrics;
                      final nearEnd =
                          metrics.maxScrollExtent - metrics.pixels <= 96;
                      if (!nearEnd && (_autoFollow || !_showCurrentButton)) {
                        setState(() {
                          _autoFollow = false;
                          _showCurrentButton = true;
                        });
                      }
                      return false;
                    }
                    _handleScroll();
                    return false;
                  },
                  child: ListView(
                    key: const Key('chat-aula-timeline'),
                    controller: _scrollController,
                    restorationId: 'chat-aula-timeline-scroll',
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: widget.padding.copyWith(
                      bottom: widget.padding.bottom + bottomInset,
                    ),
                    children: [
                      for (
                        var index = 0;
                        index < widget.messages.length;
                        index++
                      ) ...[
                        if (index > 0) const SizedBox(height: 10),
                        SizeChangedLayoutNotifier(
                          child: ChatAulaMessageBubble(
                            key: _keyForMessage(widget.messages[index]),
                            message: widget.messages[index],
                            semanticIndex: index,
                            session: widget.session,
                            onChooseAnswer: widget.onChooseAnswer,
                            onSignal: widget.onSignal,
                            onRetry: widget.onRetry,
                            onNext: widget.onNext,
                            onOpenDoubt: widget.onOpenDoubt,
                            pendingActionKeys: widget.pendingActionKeys,
                            onImageSettled: () {
                              widget.onImageSettled?.call();
                              if (_autoFollow) {
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => _scrollToCurrent(),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_showCurrentButton)
                Positioned(
                  right: 16,
                  bottom: 16 + bottomInset,
                  child: SafeArea(
                    top: false,
                    child: _ChatReturnToCurrentButton(
                      label:
                          _targetMessage()?.buttonLabel ??
                          t('aula_return_current'),
                      unreadCount: _unreadWhileAway,
                      onPressed: _scrollToCurrent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatScrollTarget {
  const _ChatScrollTarget({
    required this.message,
    required this.alignment,
    required this.buttonLabel,
  });

  final ChatLessonMessage message;
  final double alignment;
  final String buttonLabel;

  factory _ChatScrollTarget.forMessage(ChatLessonMessage message) {
    return _ChatScrollTarget(
      message: message,
      alignment: switch (message.kind) {
        ChatLessonMessageKind.feedback => 0.18,
        ChatLessonMessageKind.error => 0.18,
        ChatLessonMessageKind.processing => 0.32,
        ChatLessonMessageKind.image => 0.18,
        ChatLessonMessageKind.question => 0.16,
        ChatLessonMessageKind.options => 0.42,
        ChatLessonMessageKind.explanation => 0.12,
        _ => 0.78,
      },
      buttonLabel: switch (message.kind) {
        ChatLessonMessageKind.feedback => t('aula_return_feedback'),
        ChatLessonMessageKind.error => t('aula_return_error'),
        ChatLessonMessageKind.processing => t('aula_return_processing'),
        ChatLessonMessageKind.image => t('aula_return_image'),
        ChatLessonMessageKind.question => t('aula_return_question'),
        ChatLessonMessageKind.options => t('aula_return_options'),
        ChatLessonMessageKind.explanation => t('aula_return_new_item'),
        _ => t('aula_return_current'),
      },
    );
  }
}

class _ChatReturnToCurrentButton extends StatelessWidget {
  const _ChatReturnToCurrentButton({
    required this.label,
    required this.unreadCount,
    required this.onPressed,
  });

  final String label;
  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final displayLabel = unreadCount > 0
        ? t('aula_return_with_new_messages', {
            'target': label,
            'count': unreadCount,
          })
        : label;
    return Semantics(
      button: true,
      label: displayLabel,
      child: Tooltip(
        message: displayLabel,
        child: Material(
          color: palette.text,
          borderRadius: BorderRadius.circular(999),
          elevation: 8,
          child: InkWell(
            key: const Key('chat-return-current-button'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              constraints: const BoxConstraints(
                minWidth: SimTouch.min,
                minHeight: SimTouch.min,
                maxWidth: 320,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_downward_rounded,
                    color: palette.surface,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.surface,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
    final palette = SimThemeScope.paletteOf(context);
    final isStudent = message.role == ChatLessonMessageRole.student;
    final isSystem = message.role == ChatLessonMessageRole.system;
    final maxWidth = MediaQuery.sizeOf(context).width < 520
        ? double.infinity
        : 520.0;
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isStudent
              ? palette.primary.withValues(alpha: 0.14)
              : isSystem
              ? palette.surfaceSoft
              : palette.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isStudent ? 18 : 6),
            bottomRight: Radius.circular(isStudent ? 6 : 18),
          ),
          border: Border.all(
            color: isSystem
                ? palette.border.withValues(alpha: 0.7)
                : palette.border,
          ),
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: 18,
              spreadRadius: -12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _ChatAulaMessageBody(
            message: message,
            session: session,
            onChooseAnswer: onChooseAnswer,
            onSignal: onSignal,
            onRetry: onRetry,
            onNext: onNext,
            onOpenDoubt: onOpenDoubt,
            pendingActionKeys: pendingActionKeys,
            onImageSettled: onImageSettled,
          ),
        ),
      ),
    );

    final messageContent = Align(
      alignment: isStudent ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble,
    );
    final animatedMessage = _isInteractive(message.kind)
        ? messageContent
        : _ChatMessageReveal(messageId: message.id, child: messageContent);

    return Semantics(
      container: true,
      liveRegion: _isLiveRegion(message),
      label: _semanticLabel(message),
      sortKey: OrdinalSortKey(semanticIndex.toDouble()),
      child: animatedMessage,
    );
  }

  bool _isInteractive(ChatLessonMessageKind kind) {
    return switch (kind) {
      ChatLessonMessageKind.options ||
      ChatLessonMessageKind.signals ||
      ChatLessonMessageKind.feedback ||
      ChatLessonMessageKind.error ||
      ChatLessonMessageKind.doubtAction => true,
      _ => false,
    };
  }

  bool _isLiveRegion(ChatLessonMessage message) {
    return switch (message.deliveryStatus) {
      ChatLessonDeliveryStatus.processing ||
      ChatLessonDeliveryStatus.failed => true,
      _ => message.kind == ChatLessonMessageKind.feedback,
    };
  }

  String _semanticLabel(ChatLessonMessage message) {
    final owner = switch (message.role) {
      ChatLessonMessageRole.student => 'Mensagem do aluno',
      ChatLessonMessageRole.system => 'Mensagem do sistema',
      ChatLessonMessageRole.sim => 'Mensagem do SIM',
    };
    final status = _deliveryStatusLabel(message.deliveryStatus);
    final timestamp = message.timestampLabel?.trim();
    final text = (message.text ?? '').trim();
    final parts = [
      owner,
      if (timestamp != null && timestamp.isNotEmpty) timestamp,
      'Status: $status',
      if (text.isNotEmpty) text,
    ];
    return parts.join('. ');
  }

  String _deliveryStatusLabel(ChatLessonDeliveryStatus status) {
    return switch (status) {
      ChatLessonDeliveryStatus.sending => 'enviando',
      ChatLessonDeliveryStatus.sent => 'enviada',
      ChatLessonDeliveryStatus.delivered => 'entregue',
      ChatLessonDeliveryStatus.read => 'lida',
      ChatLessonDeliveryStatus.processing => 'processando',
      ChatLessonDeliveryStatus.failed => 'falha',
    };
  }
}

class _ChatMessageReveal extends StatelessWidget {
  const _ChatMessageReveal({required this.messageId, required this.child});

  final String messageId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey('chat-message-reveal-$messageId'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.985 + (0.015 * value),
            alignment: Alignment.topLeft,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _ChatAulaMessageBody extends StatelessWidget {
  const _ChatAulaMessageBody({
    required this.message,
    required this.onChooseAnswer,
    required this.onSignal,
    required this.onRetry,
    required this.onNext,
    required this.onOpenDoubt,
    this.pendingActionKeys = const {},
    this.session,
    this.onImageSettled,
  });

  final ChatLessonMessage message;
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
    final palette = SimThemeScope.paletteOf(context);
    return switch (message.kind) {
      ChatLessonMessageKind.options => _ChatOptions(
        message: message,
        onChooseAnswer: onChooseAnswer,
        onSignal: onSignal,
        pendingActionKeys: pendingActionKeys,
      ),
      ChatLessonMessageKind.signals => _ChatSignals(
        message: message,
        onSignal: onSignal,
        pendingActionKeys: pendingActionKeys,
      ),
      ChatLessonMessageKind.image =>
        session == null
            ? ChatImageBubble(message: message)
            : LessonImagePanel(
                session: session!,
                onImageSettled: onImageSettled,
              ),
      ChatLessonMessageKind.loading || ChatLessonMessageKind.processing =>
        message.id == 'doubt-processing'
            ? _DoubtProgressMessage(
                text: message.text ?? t('aula_doubt_processing'),
                progress: message.progress ?? 0,
              )
            : _StatusMessage(
                text: message.text ?? t('preparing_lesson'),
                loading: true,
                retryPending: pendingActionKeys.contains('retry'),
                onRetry: message.actionKey == 'retry' ? onRetry : null,
              ),
      ChatLessonMessageKind.error => _StatusMessage(
        text: message.text ?? t('aula_gen_fail'),
        loading: false,
        warn: true,
        retryPending: pendingActionKeys.contains('retry'),
        onRetry: message.actionKey == 'retry' ? onRetry : null,
      ),
      ChatLessonMessageKind.feedback => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                message.isCorrect == false
                    ? Icons.info_outline
                    : Icons.check_circle_outline,
                size: 20,
                color: message.isCorrect == false ? simWarn : palette.primary,
              ),
              const SizedBox(width: 8),
              Expanded(child: _TextMessage(message.text ?? '')),
            ],
          ),
          if ((message.actionKey ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                final enabled =
                    message.deliveryStatus != ChatLessonDeliveryStatus.read;
                final doubtButton = _ChatActionButton(
                  key: const Key('chat-feedback-doubt-button'),
                  label: t('aula_doubt_about_question'),
                  enabled: enabled && !pendingActionKeys.contains('doubt'),
                  busy: pendingActionKeys.contains('doubt'),
                  primary: false,
                  onPressed: onOpenDoubt,
                );
                final nextButton = _ChatActionButton(
                  key: const Key('chat-feedback-next-button'),
                  label: t(message.actionKey ?? 'aula_next'),
                  enabled: enabled && !pendingActionKeys.contains('next'),
                  busy: pendingActionKeys.contains('next'),
                  onPressed: onNext,
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      doubtButton,
                      const SizedBox(height: 10),
                      nextButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: doubtButton),
                    const SizedBox(width: 10),
                    Expanded(child: nextButton),
                  ],
                );
              },
            ),
          ],
        ],
      ),
      ChatLessonMessageKind.doubtAction => _ChatActionButton(
        key: const Key('chat-doubt-action'),
        label: message.text ?? t('aula_doubt'),
        enabled: !pendingActionKeys.contains('doubt'),
        busy: pendingActionKeys.contains('doubt'),
        onPressed: onOpenDoubt,
      ),
      ChatLessonMessageKind.studentAnswer ||
      ChatLessonMessageKind.historyAnswer ||
      ChatLessonMessageKind.studentSignal => _StudentShortMessage(
        text: message.text ?? '',
      ),
      ChatLessonMessageKind.historyQuestion => _HistoryQuestionMessage(
        message: message,
      ),
      _ => _TextMessage(message.text ?? ''),
    };
  }
}

class _HistoryQuestionMessage extends StatelessWidget {
  const _HistoryQuestionMessage({required this.message});

  final ChatLessonMessage message;

  @override
  Widget build(BuildContext context) {
    final imageData = message.imageData?.trim();
    final hasImage = imageData != null && imageData.isNotEmpty;
    final palette = SimThemeScope.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasImage) ...[
          Semantics(
            label: 'Imagem da questão respondida',
            image: true,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 220, maxHeight: 160),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(SimRadius.md),
                border: Border.all(color: palette.border),
              ),
              child: LessonMediaImageView(data: imageData, compact: true),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _TextMessage(message.text ?? ''),
        if (message.options.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final option in message.options)
            _HistoryOptionRow(option: option, selected: option.selected),
        ],
      ],
    );
  }
}

class _HistoryOptionRow extends StatelessWidget {
  const _HistoryOptionRow({required this.option, required this.selected});

  final ChatLessonOption option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      enabled: false,
      selected: selected,
      label: t('answer_option_named', {'label': option.letter.name}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? palette.primary.withValues(alpha: 0.12)
              : palette.surfaceSoft,
          borderRadius: BorderRadius.circular(SimRadius.lg),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: selected ? simGradientPrimary : null,
                color: selected ? null : palette.surface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: selected
                      ? palette.primary
                      : palette.border.withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                option.letter.name,
                style: TextStyle(
                  fontFamily: kMono,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? simDark : palette.text,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.text,
                style: SimTypography.lessonBody.copyWith(
                  color: palette.text,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatImageBubble extends StatelessWidget {
  const ChatImageBubble({required this.message, super.key});

  final ChatLessonMessage message;

  @override
  Widget build(BuildContext context) {
    final imageReady =
        message.imageData != null && message.imageData!.trim().isNotEmpty;
    final loading = message.imageStatus == 'loading';
    final hasError = (message.text ?? '').trim().isNotEmpty;
    final offer = message.hasPaidImageOffer && !loading && !imageReady;
    final palette = SimThemeScope.paletteOf(context);
    final icon = imageReady
        ? Icons.image_outlined
        : loading
        ? Icons.hourglass_empty
        : offer
        ? Icons.add_photo_alternate_outlined
        : Icons.broken_image_outlined;
    final label = imageReady
        ? 'Imagem da aula pronta'
        : loading
        ? 'Gerando imagem da aula...'
        : offer
        ? t('aula_img_desc')
        : hasError
        ? message.text!
        : 'Imagem indisponível. A aula continua.';
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(SimRadius.lg),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          if (loading)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.primary,
              ),
            )
          else
            Icon(icon, color: hasError ? simWarn : palette.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: SimTypography.lessonBody.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoubtProgressMessage extends StatelessWidget {
  const _DoubtProgressMessage({required this.text, required this.progress});

  final String text;
  final int progress;

  @override
  Widget build(BuildContext context) {
    return DoubtProgressBar(progress: progress.toDouble(), label: text);
  }
}

class _TextMessage extends StatelessWidget {
  const _TextMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Text(
      text,
      style: SimTypography.lessonBody.copyWith(
        color: palette.text,
        height: 1.42,
      ),
    );
  }
}

class _StudentShortMessage extends StatelessWidget {
  const _StudentShortMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontFamily: kMono,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: palette.text,
      ),
    );
  }
}

class _ChatOptions extends StatelessWidget {
  const _ChatOptions({
    required this.message,
    required this.onChooseAnswer,
    required this.onSignal,
    required this.pendingActionKeys,
  });

  final ChatLessonMessage message;
  final void Function(AnswerLetter letter) onChooseAnswer;
  final void Function(int value) onSignal;
  final Set<String> pendingActionKeys;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in message.options)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnswerButton(
                label: option.letter.name,
                text: option.text,
                active: option.selected,
                enabled:
                    option.enabled && !pendingActionKeys.contains('answer'),
                onTap: () => onChooseAnswer(option.letter),
              ),
              if (option.selected && message.signals.isNotEmpty)
                _InlineSignalChoices(
                  signals: message.signals,
                  onSignal: onSignal,
                  pendingActionKeys: pendingActionKeys,
                ),
            ],
          ),
      ],
    );
  }
}

class _InlineSignalChoices extends StatelessWidget {
  const _InlineSignalChoices({
    required this.signals,
    required this.onSignal,
    required this.pendingActionKeys,
  });

  final List<ChatLessonSignal> signals;
  final void Function(int value) onSignal;
  final Set<String> pendingActionKeys;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Container(
      key: const Key('inline-signal-choices'),
      margin: const EdgeInsets.only(top: 8, left: 12, bottom: 10),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.primary, width: 1)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < signals.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _SignalButton(
                signal: signals[i],
                busy: pendingActionKeys.contains('signal'),
                onPressed: () => onSignal(signals[i].value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatSignals extends StatelessWidget {
  const _ChatSignals({
    required this.message,
    required this.onSignal,
    required this.pendingActionKeys,
  });

  final ChatLessonMessage message;
  final void Function(int value) onSignal;
  final Set<String> pendingActionKeys;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < message.signals.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _SignalButton(
                  signal: message.signals[i],
                  busy: pendingActionKeys.contains('signal'),
                  onPressed: () => onSignal(message.signals[i].value),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SignalButton extends StatelessWidget {
  const _SignalButton({
    required this.signal,
    required this.busy,
    required this.onPressed,
  });

  final ChatLessonSignal signal;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      enabled: signal.enabled && !busy,
      label: t('signal_option_named', {
        'value': signal.value,
        'label': t(signal.labelKey),
      }),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(SimRadius.lg),
        child: InkWell(
          onTap: signal.enabled && !busy ? onPressed : null,
          borderRadius: BorderRadius.circular(SimRadius.lg),
          child: Container(
            constraints: const BoxConstraints(minHeight: SimTouch.min),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: palette.surfaceSoft,
              borderRadius: BorderRadius.circular(SimRadius.lg),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.primary,
                    ),
                  )
                else
                  Text(
                    '${signal.value}',
                    style: TextStyle(
                      fontFamily: kMono,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: palette.text,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  t(signal.labelKey),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.text,
    required this.loading,
    this.warn = false,
    this.retryPending = false,
    this.onRetry,
  });

  final String text;
  final bool loading;
  final bool warn;
  final bool retryPending;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.primary,
                ),
              )
            else
              Icon(
                warn ? Icons.warning_amber_rounded : Icons.info_outline,
                color: warn ? simWarn : palette.primary,
                size: 20,
              ),
            const SizedBox(width: 10),
            Expanded(child: _TextMessage(text)),
          ],
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          _ChatActionButton(
            label: retryPending ? t('aula_retrying') : t('aula_try_again_2'),
            enabled: !retryPending,
            busy: retryPending,
            onPressed: onRetry!,
          ),
        ],
      ],
    );
  }
}

class _ChatActionButton extends StatelessWidget {
  const _ChatActionButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.busy = false,
    this.primary = true,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final bool busy;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final background = primary ? palette.text : palette.surface;
    final foreground = primary ? palette.surface : palette.text;
    return Semantics(
      button: true,
      enabled: enabled && !busy,
      label: label,
      child: Material(
        color: enabled && !busy ? background : palette.surfaceSoft,
        borderRadius: BorderRadius.circular(SimRadius.md),
        child: InkWell(
          onTap: enabled && !busy ? onPressed : null,
          borderRadius: BorderRadius.circular(SimRadius.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: SimTouch.min),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SimRadius.md),
              border: Border.all(
                color: primary ? palette.text : palette.border,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled && !busy ? foreground : palette.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
