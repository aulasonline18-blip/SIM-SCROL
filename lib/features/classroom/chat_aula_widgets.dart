import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/utils/sim_constants.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/responsive/sim_responsive.dart';
import '../../sim/ui/sim_theme.dart';
import '../../sim/ui/widgets/doubt_progress_bar.dart';
import '../session/lab_session.dart';
import '../onboarding/preparation_and_placement.dart';
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
  State<ChatAulaTimeline> createState() => _ChatAulaTimelineState();
}

class _ChatAulaTimelineState extends State<ChatAulaTimeline> {
  static const _scrollDuration = Duration(milliseconds: 840);

  late final ScrollController _scrollController =
      widget.scrollController ?? ScrollController();
  late final bool _ownsScrollController = widget.scrollController == null;
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  final FocusNode _timelineFocusNode = FocusNode(
    debugLabel: 'chat-aula-timeline-focus',
  );
  String _messageSignature = '';
  late bool _initialScrollToCurrentPending = widget.initialScrollToCurrent;
  _ExplicitScrollIntent? _pendingScrollIntent;

  @override
  void initState() {
    super.initState();
    _messageSignature = _signatureOf(widget.messages);
    _scheduleInitialScrollToCurrent();
  }

  @override
  void didUpdateWidget(ChatAulaTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.initialScrollToCurrent && widget.initialScrollToCurrent) ||
        oldWidget.initialScrollKey != widget.initialScrollKey) {
      _initialScrollToCurrentPending = widget.initialScrollToCurrent;
    }
    final nextSignature = _signatureOf(widget.messages);
    if (nextSignature == _messageSignature) {
      _scheduleInitialScrollToCurrent();
      return;
    }
    _messageSignature = nextSignature;
    _retainMessageKeys(widget.messages);
    final fallbackOffset = _scrollController.hasClients
        ? _scrollController.position.pixels
        : null;
    final intent = _pendingScrollIntent;
    _pendingScrollIntent = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (intent != null) {
        _scrollForIntent(intent, initialFallbackOffset: fallbackOffset);
      }
    });
    _scheduleInitialScrollToCurrent();
  }

  @override
  void dispose() {
    if (_ownsScrollController) _scrollController.dispose();
    _timelineFocusNode.dispose();
    super.dispose();
  }

  Future<void> _scrollForIntent(
    _ExplicitScrollIntent intent, {
    bool immediate = false,
    bool preferNewTurnStart = false,
    double? initialFallbackOffset,
  }) {
    return _scrollToCurrent(
      immediate: immediate,
      preferNewTurnStart:
          preferNewTurnStart || intent == _ExplicitScrollIntent.nextExplanation,
      initialFallbackOffset: initialFallbackOffset,
    );
  }

  void _scheduleInitialScrollToCurrent() {
    if (!_initialScrollToCurrentPending ||
        !widget.initialScrollToCurrent ||
        !_hasInitialScrollTarget(widget.messages)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_initialScrollToCurrentPending ||
          !widget.initialScrollToCurrent ||
          !_hasInitialScrollTarget(widget.messages)) {
        return;
      }
      _initialScrollToCurrentPending = false;
      unawaited(_scrollToCurrent(immediate: true));
    });
  }

  bool _hasInitialScrollTarget(List<ChatLessonMessage> messages) {
    return messages.any((message) {
      return switch (message.kind) {
        ChatLessonMessageKind.loading => false,
        _ => true,
      };
    });
  }

  Future<void> _scrollToCurrent({
    bool immediate = false,
    bool preferNewTurnStart = false,
    double? initialFallbackOffset,
  }) async {
    if (!_scrollController.hasClients) return;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = immediate || disableAnimations
        ? Duration.zero
        : _scrollDuration;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToCurrent(
          immediate: immediate,
          preferNewTurnStart: preferNewTurnStart,
          initialFallbackOffset: initialFallbackOffset,
        );
      });
      return;
    }
    final target = preferNewTurnStart
        ? _autoScrollTargetMessage()
        : _targetMessage();
    final targetKey = target == null ? null : _messageKeys[target.message.id];
    final targetContext = targetKey?.currentContext;
    if (targetContext != null && target != null) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: duration,
        curve: Curves.easeOutCubic,
        alignment: target.alignment,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    } else {
      final seededFallbackOffset = initialFallbackOffset == null
          ? null
          : (initialFallbackOffset +
                    (preferNewTurnStart
                        ? position.viewportDimension * 0.45
                        : 0))
                .clamp(0.0, position.maxScrollExtent);
      final fallbackOffset =
          seededFallbackOffset ?? _fallbackOffsetFor(position, target?.message);
      if (immediate) {
        _scrollController.jumpTo(fallbackOffset);
      } else if (disableAnimations) {
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
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: target.alignment,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
          );
        }
      }
    }
  }

  void _handleSignal(int value) {
    _pendingScrollIntent = _ExplicitScrollIntent.currentFeedback;
    widget.onSignal(value);
    _consumePendingIntentIfWidgetDoesNotUpdate();
  }

  void _handleNext() {
    _pendingScrollIntent = _ExplicitScrollIntent.nextExplanation;
    widget.onNext();
    _consumePendingIntentIfWidgetDoesNotUpdate();
  }

  void _consumePendingIntentIfWidgetDoesNotUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final intent = _pendingScrollIntent;
      if (!mounted || intent == null) return;
      _pendingScrollIntent = null;
      _scrollForIntent(intent);
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
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
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
            message.unit ?? '',
            message.title ?? '',
            message.imageData ?? '',
            message.imageStatus,
            message.mediaName ?? '',
            message.mediaType ?? '',
            message.mediaSize?.toString() ?? '',
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
    if (latestLiveIndex >= 0 && latestExplanationIndex > latestLiveIndex) {
      for (
        var i = widget.messages.length - 1;
        i >= latestExplanationIndex;
        i--
      ) {
        final message = widget.messages[i];
        if (message.kind == ChatLessonMessageKind.options ||
            message.kind == ChatLessonMessageKind.question ||
            message.kind == ChatLessonMessageKind.image) {
          return _ChatScrollTarget.forMessage(message);
        }
      }
      return _ChatScrollTarget.forMessage(
        widget.messages[latestExplanationIndex],
      );
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

  _ChatScrollTarget? _autoScrollTargetMessage() {
    final turnStart = _latestNewTurnStartAfterLiveTarget();
    if (turnStart != null) {
      return _ChatScrollTarget.forMessage(turnStart);
    }
    return _targetMessage();
  }

  ChatLessonMessage? _latestNewTurnStartAfterLiveTarget() {
    var latestExplanationIndex = -1;
    var latestLiveIndex = -1;
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
      if (isLiveTarget) latestLiveIndex = i;
    }
    if (latestLiveIndex >= 0 && latestExplanationIndex > latestLiveIndex) {
      return widget.messages[latestExplanationIndex];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final pagePadding = SimResponsive.pagePaddingFor(width);
        final horizontalPadding = pagePadding.horizontal / 2;
        final contentMaxWidth = SimResponsive.contentMaxWidthFor(
          width,
          medium: 620,
          expanded: 620,
          large: 680,
        );
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
                  NotificationListener<ScrollMetricsNotification>(
                    onNotification: (_) {
                      return false;
                    },
                    child: NotificationListener<SizeChangedLayoutNotification>(
                      onNotification: (_) {
                        return false;
                      },
                      child: NotificationListener<UserScrollNotification>(
                        onNotification: (_) => false,
                        child: ListView(
                          key: const Key('chat-aula-timeline'),
                          controller: _scrollController,
                          restorationId: 'chat-aula-timeline-scroll',
                          scrollCacheExtent: ScrollCacheExtent.pixels(
                            (MediaQuery.sizeOf(context).height * 2).clamp(
                              600.0,
                              1400.0,
                            ),
                          ),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            widget.padding.top,
                            horizontalPadding,
                            widget.padding.bottom + bottomInset,
                          ),
                          children: [
                            if (widget.messages.isEmpty)
                              Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: contentMaxWidth,
                                  ),
                                  child: const _ChatEmptyState(),
                                ),
                              )
                            else
                              for (
                                var index = 0;
                                index < widget.messages.length;
                                index++
                              ) ...[
                                if (index > 0) const SizedBox(height: 10),
                                Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: contentMaxWidth,
                                    ),
                                    child: SizeChangedLayoutNotifier(
                                      child: ChatAulaMessageBubble(
                                        key: _keyForMessage(
                                          widget.messages[index],
                                        ),
                                        message: widget.messages[index],
                                        semanticIndex: index,
                                        session: widget.session,
                                        onChooseAnswer: widget.onChooseAnswer,
                                        onSignal: _handleSignal,
                                        onRetry: widget.onRetry,
                                        onNext: _handleNext,
                                        onOpenDoubt: widget.onOpenDoubt,
                                        pendingActionKeys:
                                            widget.pendingActionKeys,
                                        onImageSettled: () {
                                          widget.onImageSettled?.call();
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _ExplicitScrollIntent { currentFeedback, nextExplanation }

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      container: true,
      label: t('aula_empty_conversation'),
      child: Container(
        key: const Key('chat-empty-state'),
        constraints: const BoxConstraints(minHeight: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.surfaceSoft,
          borderRadius: BorderRadius.circular(SimRadius.lg),
          border: Border.all(color: palette.border),
        ),
        child: Text(
          t('aula_empty_conversation'),
          textAlign: TextAlign.center,
          style: SimTypography.lessonBody.copyWith(
            color: palette.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ChatScrollTarget {
  const _ChatScrollTarget({required this.message, required this.alignment});

  final ChatLessonMessage message;
  final double alignment;

  factory _ChatScrollTarget.forMessage(ChatLessonMessage message) {
    return _ChatScrollTarget(
      message: message,
      alignment: switch (message.kind) {
        ChatLessonMessageKind.feedback => 0.08,
        ChatLessonMessageKind.error => 0.18,
        ChatLessonMessageKind.processing => 0.32,
        ChatLessonMessageKind.image => 0.18,
        ChatLessonMessageKind.question => 0.16,
        ChatLessonMessageKind.options => 0.42,
        ChatLessonMessageKind.explanation => 0.12,
        _ => 0.78,
      },
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
    final mediaName = (message.mediaName ?? '').trim();
    final media = mediaName.isEmpty ? _mediaStatusText(message) : mediaName;
    final parts = [
      owner,
      if (message.isHistorical) 'Histórico preservado',
      if (!message.isActionable) 'Sem ação ativa',
      if (timestamp != null && timestamp.isNotEmpty) timestamp,
      'Status: $status',
      if (text.isNotEmpty) text,
      if (media.isNotEmpty) media,
    ];
    return parts.join('. ');
  }

  String _mediaStatusText(ChatLessonMessage message) {
    return switch (message.kind) {
      ChatLessonMessageKind.image =>
        message.imageStatus == 'loading'
            ? t('aula_image_loading')
            : (message.imageData ?? '').trim().isNotEmpty
            ? t('aula_image_ready')
            : t('aula_image_unavailable'),
      ChatLessonMessageKind.studentDoubt =>
        (message.imageData ?? '').trim().isNotEmpty
            ? t('aula_attachment_image')
            : '',
      ChatLessonMessageKind.loading ||
      ChatLessonMessageKind.processing => message.text ?? t('preparing_lesson'),
      ChatLessonMessageKind.error => message.text ?? t('aula_gen_fail'),
      _ => '',
    };
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

class _ChatFeedbackActionReveal extends StatelessWidget {
  const _ChatFeedbackActionReveal({
    required this.messageId,
    required this.enabled,
    required this.child,
  });

  final String messageId;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!enabled || disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey('chat-feedback-action-reveal-$messageId'),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: 0.82 + (0.18 * value),
          child: Transform.scale(
            scale: 0.94 + (0.06 * value),
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
                onRetry: message.isActionable && message.actionKey == 'retry'
                    ? onRetry
                    : null,
              ),
      ChatLessonMessageKind.error => _StatusMessage(
        text: message.text ?? t('aula_gen_fail'),
        loading: false,
        warn: true,
        retryPending: pendingActionKeys.contains('retry'),
        onRetry: message.isActionable && message.actionKey == 'retry'
            ? onRetry
            : null,
      ),
      ChatLessonMessageKind.feedback => _ChatFeedbackActionReveal(
        messageId: message.id,
        enabled:
            (message.actionKey ?? '').isNotEmpty &&
            message.isActionable &&
            message.deliveryStatus != ChatLessonDeliveryStatus.read,
        child: _FeedbackMessageActions(
          message: message,
          pendingActionKeys: pendingActionKeys,
          onOpenDoubt: onOpenDoubt,
          onNext: onNext,
        ),
      ),
      ChatLessonMessageKind.doubtAction => _ChatActionButton(
        key: const Key('chat-doubt-action'),
        label: message.text ?? t('aula_doubt'),
        enabled: message.isActionable,
        busy: false,
        onPressed: onOpenDoubt,
      ),
      ChatLessonMessageKind.studentAnswer ||
      ChatLessonMessageKind.historyAnswer ||
      ChatLessonMessageKind.studentSignal => _StudentShortMessage(
        text: message.text ?? '',
      ),
      ChatLessonMessageKind.studentDoubt => _StudentDoubtMessage(
        message: message,
      ),
      ChatLessonMessageKind.explanation => _ExplanationMessage(
        message: message,
      ),
      ChatLessonMessageKind.historyQuestion => _HistoryQuestionMessage(
        message: message,
      ),
      _ => _TextMessage(message.text ?? ''),
    };
  }
}

class _FeedbackMessageActions extends StatelessWidget {
  const _FeedbackMessageActions({
    required this.message,
    required this.pendingActionKeys,
    required this.onOpenDoubt,
    required this.onNext,
  });

  final ChatLessonMessage message;
  final Set<String> pendingActionKeys;
  final VoidCallback onOpenDoubt;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final effectiveActionable =
        message.isActionable &&
        message.deliveryStatus != ChatLessonDeliveryStatus.read;
    final feedbackIcon = message.isCorrect == false
        ? Icons.info_outline
        : Icons.check_circle_outline;
    final feedbackColor = message.isCorrect == false
        ? simWarn
        : palette.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: palette.surfaceSoft,
            borderRadius: BorderRadius.circular(SimRadius.md),
            border: Border.all(color: palette.border.withValues(alpha: 0.75)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(feedbackIcon, size: 18, color: feedbackColor),
              const SizedBox(width: 8),
              Expanded(child: _TextMessage(message.text ?? '')),
            ],
          ),
        ),
        if ((message.actionKey ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final doubtBusy = pendingActionKeys.contains('doubt');
              final nextBusy = pendingActionKeys.contains('next');
              final doubtButton = _ChatActionButton(
                key: const Key('chat-feedback-doubt-button'),
                label: doubtBusy ? t('aula_doubt_processing') : t('aula_doubt'),
                enabled: effectiveActionable && !doubtBusy,
                busy: doubtBusy,
                primary: false,
                compact: true,
                onPressed: onOpenDoubt,
              );
              final nextButton = _ChatActionButton(
                key: const Key('chat-feedback-next-button'),
                label: nextBusy
                    ? t('preparing_next_lesson')
                    : nextBtnText(message.actionKey ?? 'aula_next'),
                enabled: effectiveActionable && !nextBusy,
                busy: nextBusy,
                icon: Icons.arrow_forward_rounded,
                onPressed: onNext,
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    nextButton,
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: doubtButton,
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: nextButton),
                  const SizedBox(width: 10),
                  SizedBox(width: 148, child: doubtButton),
                ],
              );
            },
          ),
        ],
      ],
    );
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
            label: t('aula_answered_question_image'),
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

class _StudentDoubtMessage extends StatelessWidget {
  const _StudentDoubtMessage({required this.message});

  final ChatLessonMessage message;

  @override
  Widget build(BuildContext context) {
    final text = message.text?.trim();
    final hasText = text != null && text.isNotEmpty;
    final imageData = message.imageData?.trim();
    final hasImage = imageData != null && imageData.isNotEmpty;
    final hasAttachmentMetadata =
        (message.mediaName ?? '').trim().isNotEmpty ||
        (message.mediaType ?? '').trim().isNotEmpty ||
        message.mediaSize != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasText) _StudentShortMessage(text: text),
        if (hasText && (hasImage || hasAttachmentMetadata))
          const SizedBox(height: 10),
        if (hasImage || hasAttachmentMetadata)
          _ChatMediaAttachment(
            imageData: imageData,
            name: message.mediaName,
            type: message.mediaType,
            size: message.mediaSize,
          ),
      ],
    );
  }
}

class _ChatMediaAttachment extends StatelessWidget {
  const _ChatMediaAttachment({this.imageData, this.name, this.type, this.size});

  final String? imageData;
  final String? name;
  final String? type;
  final int? size;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final displayName = (name ?? '').trim().isEmpty
        ? t('aula_attachment_image')
        : name!.trim();
    final sizeLabel = _formatBytes(size);
    final typeLabel = (type ?? '').trim();
    final semanticName = typeLabel.isEmpty
        ? displayName
        : '$displayName, $typeLabel';
    final previewData = imageData?.trim();
    final hasPreview = previewData != null && previewData.isNotEmpty;
    return Semantics(
      container: true,
      image: true,
      label: t('aula_attachment_semantics', {'name': semanticName}),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(SimRadius.lg),
          border: Border.all(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasPreview)
              AspectRatio(
                aspectRatio: 16 / 10,
                child: LessonMediaImageView(data: previewData, compact: true),
              )
            else
              Container(
                height: 84,
                width: double.infinity,
                alignment: Alignment.center,
                color: palette.surfaceSoft,
                child: Icon(
                  Icons.image_outlined,
                  size: 30,
                  color: palette.primary,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Icon(Icons.image_outlined, size: 18, color: palette.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (sizeLabel != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      sizeLabel,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                        fontFamily: kMono,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return null;
    if (bytes < 1024) return '${bytes}B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)}KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)}MB';
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
    final palette = SimThemeScope.paletteOf(context);
    final icon = imageReady
        ? Icons.image_outlined
        : loading
        ? Icons.hourglass_empty
        : Icons.broken_image_outlined;
    final label = imageReady
        ? t('aula_image_ready')
        : loading
        ? t('aula_image_loading')
        : hasError
        ? message.text!
        : t('aula_image_unavailable');
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

class _ExplanationMessage extends StatelessWidget {
  const _ExplanationMessage({required this.message});

  final ChatLessonMessage message;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final cleanUnit = message.unit?.trim();
    final cleanMarker = message.marker?.trim();
    final cleanTitle = message.title?.trim();
    final hasAnyHeading =
        (cleanUnit != null && cleanUnit.isNotEmpty) ||
        (cleanTitle != null && cleanTitle.isNotEmpty);
    if (!hasAnyHeading) return _TextMessage(message.text ?? '');
    final identity = [
      if (cleanMarker != null && cleanMarker.isNotEmpty) cleanMarker,
      if (cleanTitle != null && cleanTitle.isNotEmpty) cleanTitle,
    ].join(' · ');
    final hasUnit = cleanUnit != null && cleanUnit.isNotEmpty;
    final top = hasUnit
        ? '${t('aula_theory')} · $cleanUnit'
        : [t('aula_theory'), if (identity.isNotEmpty) identity].join(' · ');
    final bottom = hasUnit ? identity : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          top,
          style: TextStyle(
            fontFamily: kMono,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: palette.muted,
            letterSpacing: 1.2,
          ),
        ),
        if (bottom.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            bottom,
            style: TextStyle(
              color: palette.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
        const SizedBox(height: 8),
        _TextMessage(message.text ?? ''),
      ],
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
    final answerEnabled =
        message.isActionable && !pendingActionKeys.contains('answer');
    final signalEnabled =
        message.isActionable && !pendingActionKeys.contains('signal');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in message.options)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChatAnswerCard(
                option: option,
                enabled: answerEnabled && option.enabled,
                onTap: () => onChooseAnswer(option.letter),
              ),
              if (option.selected && message.signals.isNotEmpty)
                _InlineSignalChoices(
                  signals: signalEnabled
                      ? message.signals
                      : [
                          for (final signal in message.signals)
                            ChatLessonSignal(
                              value: signal.value,
                              labelKey: signal.labelKey,
                              enabled: false,
                            ),
                        ],
                  onSignal: onSignal,
                  pendingActionKeys: pendingActionKeys,
                ),
            ],
          ),
      ],
    );
  }
}

class _ChatAnswerCard extends StatelessWidget {
  const _ChatAnswerCard({
    required this.option,
    required this.enabled,
    required this.onTap,
  });

  final ChatLessonOption option;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final selected = option.selected;
    final borderColor = selected ? palette.primary : palette.border;
    final background = selected
        ? palette.primary.withValues(alpha: 0.09)
        : palette.surface;
    final letterBackground = selected
        ? palette.primary.withValues(alpha: 0.16)
        : palette.surfaceSoft;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: t('answer_option_named', {'label': option.letter.name}),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(SimRadius.lg),
          border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(alpha: selected ? 0.16 : 0.08),
              blurRadius: selected ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(SimRadius.lg),
          child: InkWell(
            key: Key('chat-answer-card-${option.letter.name}'),
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(SimRadius.lg),
            child: Container(
              constraints: const BoxConstraints(minHeight: 62),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    key: Key('chat-answer-letter-${option.letter.name}'),
                    duration: const Duration(milliseconds: 140),
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: letterBackground,
                      borderRadius: BorderRadius.circular(SimRadius.md),
                      border: Border.all(
                        color: selected ? palette.primary : palette.border,
                      ),
                    ),
                    child: Text(
                      option.letter.name,
                      style: TextStyle(
                        fontFamily: kMono,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: selected ? palette.primary : palette.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.text,
                      style: SimTypography.lessonBody.copyWith(
                        color: enabled ? palette.text : palette.muted,
                        fontWeight: FontWeight.w700,
                        height: 1.28,
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
      child: _SignalButtonGroup(
        signals: signals,
        busy: false,
        onSignal: onSignal,
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
        _SignalButtonGroup(
          signals: message.isActionable && !pendingActionKeys.contains('signal')
              ? message.signals
              : [
                  for (final signal in message.signals)
                    ChatLessonSignal(
                      value: signal.value,
                      labelKey: signal.labelKey,
                      enabled: false,
                    ),
                ],
          busy: false,
          onSignal: onSignal,
        ),
      ],
    );
  }
}

class _SignalButtonGroup extends StatelessWidget {
  const _SignalButtonGroup({
    required this.signals,
    required this.busy,
    required this.onSignal,
  });

  final List<ChatLessonSignal> signals;
  final bool busy;
  final void Function(int value) onSignal;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final compact = SimResponsive.isCompact(
          MediaQuery.sizeOf(context).width,
        );
        final minButtonWidth = compact ? 96.0 : 112.0;
        final canUseRow =
            !compact && available >= (signals.length * minButtonWidth) + 16;
        final buttons = [
          for (final signal in signals)
            _SignalButton(
              key: Key('signal-button-${signal.value}'),
              signal: signal,
              busy: busy,
              onPressed: () => onSignal(signal.value),
            ),
        ];
        if (canUseRow) {
          return Row(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: buttons[i]),
              ],
            ],
          );
        }
        final columns = available >= (minButtonWidth * 2) + 8 ? 2 : 1;
        final buttonWidth = ((available - (8 * (columns - 1))) / columns).clamp(
          minButtonWidth,
          available,
        );
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final button in buttons)
              SizedBox(width: buttonWidth, child: button),
          ],
        );
      },
    );
  }
}

class _SignalButton extends StatelessWidget {
  const _SignalButton({
    required this.signal,
    required this.busy,
    required this.onPressed,
    super.key,
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
                  textAlign: TextAlign.center,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.primary,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  warn ? Icons.warning_amber_rounded : Icons.info_outline,
                  color: warn ? simWarn : palette.primary,
                  size: 20,
                ),
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
    this.compact = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final bool busy;
  final bool primary;
  final bool compact;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final active = enabled && !busy;
    final background = primary ? palette.surface : palette.surface;
    final foreground = primary ? palette.primary : palette.text;
    final borderColor = primary ? palette.primary : palette.border;
    return Semantics(
      button: true,
      enabled: active,
      label: label,
      child: Material(
        color: active ? background : palette.surfaceSoft,
        borderRadius: BorderRadius.circular(SimRadius.md),
        elevation: active && primary ? 1 : 0,
        shadowColor: palette.shadow.withValues(alpha: 0.18),
        child: InkWell(
          onTap: active ? onPressed : null,
          borderRadius: BorderRadius.circular(SimRadius.md),
          child: Container(
            constraints: BoxConstraints(
              minHeight: compact ? 50 : 52,
              minWidth: compact ? 92 : SimTouch.min,
            ),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 8 : 11,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SimRadius.md),
              border: Border.all(
                color: active && primary
                    ? borderColor.withValues(alpha: 0.85)
                    : borderColor,
                width: primary ? 1.4 : 1,
              ),
              boxShadow: active && primary
                  ? [
                      BoxShadow(
                        color: palette.shadow.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
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
                      color: primary ? palette.primary : palette.muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (!busy && icon != null) ...[
                  Icon(
                    icon,
                    size: compact ? 15 : 17,
                    color: active ? foreground : palette.muted,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? foreground : palette.muted,
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w800,
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
