import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/widgets/shared_widgets.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/widgets/doubt_progress_bar.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/sim_theme.dart';
import '../session/lab_session.dart';
import 'aula_widgets.dart';
import 'chat_aula_messages.dart';

part 'widgets/message_widget.dart';
part 'widgets/media_widget.dart';
part 'widgets/action_widget.dart';
part 'widgets/feedback_widget.dart';
part 'widgets/accessibility_widget.dart';

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
  static const double _renderedElementAnchor = 0.75;
  static const double _feedbackElementAnchor = 0.75;
  static const int _scrollMillisecondsPerScreen = 420;
  static const Duration _minimumScrollDuration = Duration(milliseconds: 220);
  static const Duration _maximumScrollDuration = Duration(milliseconds: 680);
  static const Duration _settledElementScrollDuration = Duration(
    milliseconds: 420,
  );

  late final ScrollController _ownedScrollController;
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  String? _lastScrollSignature;
  bool _scrollScheduled = false;

  ScrollController get _effectiveScrollController =>
      widget.scrollController ?? _ownedScrollController;

  @override
  void initState() {
    super.initState();
    _ownedScrollController = ScrollController();
    _schedulePedagogicalScroll();
  }

  @override
  void didUpdateWidget(covariant ChatAulaTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_timelineSignature(oldWidget.messages) !=
            _timelineSignature(widget.messages) ||
        oldWidget.initialScrollKey != widget.initialScrollKey ||
        oldWidget.initialScrollToCurrent != widget.initialScrollToCurrent) {
      _schedulePedagogicalScroll();
    }
  }

  @override
  void dispose() {
    _ownedScrollController.dispose();
    super.dispose();
  }

  void _schedulePedagogicalScroll() {
    if (!widget.initialScrollToCurrent || widget.messages.isEmpty) return;
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted) return;
      _scrollToPedagogicalTarget();
    });
  }

  void _scrollToPedagogicalTarget() {
    if (!_effectiveScrollController.hasClients) return;
    final visibleMessages = _visibleMessages(widget.messages);
    final target = _selectPedagogicalScrollTarget(visibleMessages);
    if (target == null) return;
    final signature =
        '${widget.initialScrollKey ?? ''}|${target.signaturePart}';
    if (_lastScrollSignature == signature) return;
    _lastScrollSignature = signature;

    final key = _messageKeys[target.message.id];
    final context = key?.currentContext;
    if (context != null) {
      _ensureTargetVisible(context, target);
      return;
    }

    final position = _effectiveScrollController.position;
    final max = position.maxScrollExtent;
    if (max <= 0) return;
    final estimated = target.index <= 0 || visibleMessages.length <= 1
        ? 0.0
        : max * (target.index / (visibleMessages.length - 1));
    _effectiveScrollController
        .animateTo(
          estimated.clamp(position.minScrollExtent, position.maxScrollExtent),
          duration: _scrollDurationForDistance(
            (position.pixels - estimated).abs(),
          ),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final retryKey = _messageKeys[target.message.id];
            final retryContext = retryKey?.currentContext;
            if (retryContext != null) {
              _ensureTargetVisible(retryContext, target);
            }
          });
        });
  }

  void _ensureTargetVisible(
    BuildContext targetContext,
    _PedagogicalScrollTarget target,
  ) {
    Scrollable.ensureVisible(
      targetContext,
      alignment: target.alignment,
      duration: _settledElementScrollDuration,
      curve: Curves.easeOutCubic,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  Duration _scrollDurationForDistance(double distance) {
    final viewport = _effectiveScrollController.hasClients
        ? _effectiveScrollController.position.viewportDimension
        : 600.0;
    final screens = viewport <= 0 ? 1.0 : distance / viewport;
    final milliseconds = (_scrollMillisecondsPerScreen * screens)
        .clamp(
          _minimumScrollDuration.inMilliseconds,
          _maximumScrollDuration.inMilliseconds,
        )
        .round();
    return Duration(milliseconds: milliseconds);
  }

  GlobalKey _keyForMessage(ChatLessonMessage message) {
    return _messageKeys.putIfAbsent(
      message.id,
      () => GlobalKey(debugLabel: 'chat-aula-message-${message.id}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleMessages = _visibleMessages(widget.messages);
    if (visibleMessages.isEmpty) {
      return Center(
        key: const Key('chat-empty-state'),
        child: Padding(
          padding: const EdgeInsets.all(SimSpacing.lg),
          child: SimStatusSurface(
            tone: SimSurfaceTone.soft,
            icon: Icons.auto_awesome,
            child: Text(t('aula_choose_goal')),
          ),
        ),
      );
    }
    return ListView.builder(
      key: const Key('chat-aula-timeline'),
      controller: _effectiveScrollController,
      padding: widget.padding,
      itemCount: visibleMessages.length,
      itemBuilder: (context, index) => ChatAulaMessageBubble(
        key: _keyForMessage(visibleMessages[index]),
        message: visibleMessages[index],
        semanticIndex: index,
        onChooseAnswer: widget.onChooseAnswer,
        onSignal: widget.onSignal,
        onRetry: widget.onRetry,
        onNext: widget.onNext,
        onOpenDoubt: widget.onOpenDoubt,
        session: widget.session,
        pendingActionKeys: widget.pendingActionKeys,
        onImageSettled: widget.onImageSettled,
      ),
    );
  }

  List<ChatLessonMessage> _visibleMessages(List<ChatLessonMessage> messages) {
    return messages;
  }
}

class _PedagogicalScrollTarget {
  const _PedagogicalScrollTarget({
    required this.message,
    required this.index,
    required this.alignment,
  });

  final ChatLessonMessage message;
  final int index;
  final double alignment;

  String get signaturePart {
    final selected = message.selectedAnswer?.name ?? '';
    final signalCount = message.signals.length;
    final status = message.deliveryStatus.name;
    return '${message.id}|$selected|$signalCount|$status';
  }
}

_PedagogicalScrollTarget? _selectPedagogicalScrollTarget(
  List<ChatLessonMessage> messages,
) {
  final stateIndex = _lastIndexWhere(
    messages,
    (message) =>
        message.kind == ChatLessonMessageKind.error ||
        message.kind == ChatLessonMessageKind.loading ||
        message.kind == ChatLessonMessageKind.processing,
  );
  if (stateIndex != null) {
    return _target(messages, stateIndex);
  }

  final feedbackIndex = _lastIndexWhere(
    messages,
    (message) => message.kind == ChatLessonMessageKind.feedback,
  );
  if (feedbackIndex != null) {
    final nextItemIntroAfterFeedbackIndex = _firstIndexWhereAfter(
      messages,
      feedbackIndex,
      (message) =>
          !message.isHistorical &&
          message.kind == ChatLessonMessageKind.itemIntro,
    );
    if (nextItemIntroAfterFeedbackIndex != null) {
      return _target(messages, nextItemIntroAfterFeedbackIndex);
    }
    final nextExplanationAfterFeedbackIndex = _firstIndexWhereAfter(
      messages,
      feedbackIndex,
      (message) =>
          !message.isHistorical &&
          message.kind == ChatLessonMessageKind.explanation,
    );
    if (nextExplanationAfterFeedbackIndex != null) {
      return _target(messages, nextExplanationAfterFeedbackIndex);
    }
  }
  if (feedbackIndex != null) {
    return _target(
      messages,
      feedbackIndex,
      alignment: _ChatAulaTimelineState._feedbackElementAnchor,
    );
  }

  final signalIndex = _lastIndexWhere(
    messages,
    (message) =>
        message.kind == ChatLessonMessageKind.signals && !message.isHistorical,
  );
  if (signalIndex != null) {
    return _target(messages, signalIndex);
  }

  final expandedOptionsIndex = _lastIndexWhere(
    messages,
    (message) =>
        message.kind == ChatLessonMessageKind.options &&
        message.signals.isNotEmpty &&
        !message.isHistorical,
  );
  if (expandedOptionsIndex != null) {
    return _target(messages, expandedOptionsIndex);
  }

  final selectedOptionsIndex = _lastIndexWhere(
    messages,
    (message) =>
        message.kind == ChatLessonMessageKind.options &&
        message.selectedAnswer != null &&
        !message.isHistorical,
  );
  if (selectedOptionsIndex != null) {
    return _target(messages, selectedOptionsIndex);
  }

  final questionIndex = _lastIndexWhere(
    messages,
    (message) =>
        message.kind == ChatLessonMessageKind.question && !message.isHistorical,
  );
  if (questionIndex != null) {
    return _target(messages, questionIndex);
  }

  final actionIndex = _lastIndexWhere(
    messages,
    (message) => message.isActionable && !message.isHistorical,
  );
  if (actionIndex != null) {
    return _target(messages, actionIndex);
  }

  final imageIndex = _lastIndexWhere(
    messages,
    (message) =>
        message.kind == ChatLessonMessageKind.image && !message.isHistorical,
  );
  if (imageIndex != null) {
    return _target(messages, imageIndex);
  }

  final explanationIndex = _lastIndexWhere(
    messages,
    (message) =>
        message.kind == ChatLessonMessageKind.explanation &&
        !message.isHistorical,
  );
  if (explanationIndex != null) {
    return _target(messages, explanationIndex);
  }

  return _target(messages, messages.length - 1);
}

_PedagogicalScrollTarget _target(
  List<ChatLessonMessage> messages,
  int index, {
  double alignment = _ChatAulaTimelineState._renderedElementAnchor,
}) {
  return _PedagogicalScrollTarget(
    message: messages[index],
    index: index,
    alignment: alignment,
  );
}

double _pedagogicalGapAfter(ChatLessonMessage message) {
  return switch (message.kind) {
    ChatLessonMessageKind.itemIntro => SimSpacing.xl,
    ChatLessonMessageKind.explanation => SimSpacing.xxl,
    ChatLessonMessageKind.image => SimSpacing.xxl,
    ChatLessonMessageKind.question => SimSpacing.xl,
    ChatLessonMessageKind.options => SimSpacing.xl,
    ChatLessonMessageKind.feedback => SimSpacing.xxl,
    _ => SimSpacing.md,
  };
}

int? _lastIndexWhere(
  List<ChatLessonMessage> messages,
  bool Function(ChatLessonMessage message) test,
) {
  for (var i = messages.length - 1; i >= 0; i--) {
    if (test(messages[i])) return i;
  }
  return null;
}

int? _firstIndexWhereAfter(
  List<ChatLessonMessage> messages,
  int startExclusive,
  bool Function(ChatLessonMessage message) test,
) {
  for (var i = startExclusive + 1; i < messages.length; i++) {
    if (test(messages[i])) return i;
  }
  return null;
}

String _timelineSignature(List<ChatLessonMessage> messages) {
  return messages.map(_messageSignaturePart).join('|');
}

String _messageSignaturePart(ChatLessonMessage message) {
  final selected = message.selectedAnswer?.name ?? '';
  final signal = message.selectedSignal?.name ?? '';
  final signalCount = message.signals.length;
  final status = message.deliveryStatus.name;
  final action = message.isActionable ? '1' : '0';
  final historical = message.isHistorical ? '1' : '0';
  final textHash = message.text?.hashCode.toString() ?? '';
  return [
    message.id,
    message.kind.name,
    selected,
    signal,
    signalCount,
    status,
    action,
    historical,
    message.imageStatus,
    textHash,
  ].join(':');
}
