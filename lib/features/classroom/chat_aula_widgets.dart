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
  static const double _feedbackElementAnchor = 0.50;
  static const int _scrollMillisecondsPerScreen = 420;
  static const Duration _minimumScrollDuration = Duration(milliseconds: 220);
  static const Duration _maximumScrollDuration = Duration(milliseconds: 680);
  static const Duration _settledElementScrollDuration = Duration(
    milliseconds: 420,
  );
  static const Duration _roundRevealStepDelay = Duration(milliseconds: 120);
  static const Duration _optionsRevealDelay = Duration(milliseconds: 180);

  late final ScrollController _ownedScrollController;
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  final Map<String, int> _roundRevealStage = <String, int>{};
  final Set<String> _practiceUnlockedRounds = <String>{};
  final Set<String> _optionsReadyRounds = <String>{};
  String? _lastScrollSignature;
  bool _scrollScheduled = false;
  Timer? _revealTimer;
  Timer? _optionsTimer;

  ScrollController get _effectiveScrollController =>
      widget.scrollController ?? _ownedScrollController;

  @override
  void initState() {
    super.initState();
    _ownedScrollController = ScrollController();
    _syncPedagogicalRoundClock(widget.messages);
    _schedulePedagogicalScroll();
  }

  @override
  void didUpdateWidget(covariant ChatAulaTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_timelineSignature(oldWidget.messages) !=
            _timelineSignature(widget.messages) ||
        oldWidget.initialScrollKey != widget.initialScrollKey ||
        oldWidget.initialScrollToCurrent != widget.initialScrollToCurrent) {
      _syncPedagogicalRoundClock(widget.messages);
      _schedulePedagogicalScroll();
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _optionsTimer?.cancel();
    _ownedScrollController.dispose();
    super.dispose();
  }

  void _syncPedagogicalRoundClock(List<ChatLessonMessage> messages) {
    for (final message in messages) {
      final roundId = _roundIdFor(message);
      if (roundId == null || message.isHistorical) continue;
      _roundRevealStage.putIfAbsent(roundId, () => 0);
      if (_roundHasStudentAction(messages, roundId)) {
        _practiceUnlockedRounds.add(roundId);
        _optionsReadyRounds.add(roundId);
      }
    }
    _scheduleRevealTick();
  }

  void _scheduleRevealTick() {
    _revealTimer?.cancel();
    final roundId = _nextRoundToReveal(widget.messages);
    if (roundId == null) return;
    _revealTimer = Timer(_roundRevealStepDelay, () {
      if (!mounted) return;
      setState(() {
        final current = _roundRevealStage[roundId] ?? 0;
        _roundRevealStage[roundId] = (current + 1).clamp(0, 3);
      });
      _schedulePedagogicalScroll();
      _scheduleRevealTick();
    });
  }

  String? _nextRoundToReveal(List<ChatLessonMessage> messages) {
    for (final message in messages) {
      final roundId = _roundIdFor(message);
      if (roundId == null || message.isHistorical) continue;
      if (!_roundUsesGuidedPractice(messages, roundId)) continue;
      if ((_roundRevealStage[roundId] ?? 0) < 3) return roundId;
    }
    return null;
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
        onPractice: _unlockPracticeRound,
        onOpenDoubt: widget.onOpenDoubt,
        session: widget.session,
        pendingActionKeys: widget.pendingActionKeys,
        onImageSettled: widget.onImageSettled,
      ),
    );
  }

  List<ChatLessonMessage> _visibleMessages(List<ChatLessonMessage> messages) {
    return [
      for (final message in messages)
        if (_isMessageVisible(message, messages)) message,
    ];
  }

  bool _isMessageVisible(
    ChatLessonMessage message,
    List<ChatLessonMessage> messages,
  ) {
    if (message.isHistorical) return true;
    final roundId = _roundIdFor(message);
    if (roundId == null) return true;
    if (!_roundUsesGuidedPractice(messages, roundId)) return true;
    final stage = _roundRevealStage[roundId] ?? 0;
    if (!_stageAllowsMessage(message, stage)) return false;
    if (message.kind == ChatLessonMessageKind.question) {
      return _roundQuestionUnlocked(messages, roundId);
    }
    if (message.kind == ChatLessonMessageKind.options) {
      if (!_roundQuestionUnlocked(messages, roundId)) return false;
      if (_roundHasStudentAction(messages, roundId)) return true;
      return _optionsReadyRounds.contains(roundId);
    }
    return true;
  }

  bool _stageAllowsMessage(ChatLessonMessage message, int stage) {
    return switch (message.kind) {
      ChatLessonMessageKind.itemIntro => true,
      ChatLessonMessageKind.explanation => stage >= 1,
      ChatLessonMessageKind.image => stage >= 2,
      ChatLessonMessageKind.practiceAction => stage >= 3,
      _ => true,
    };
  }

  bool _roundQuestionUnlocked(List<ChatLessonMessage> messages, String roundId) {
    return _practiceUnlockedRounds.contains(roundId) ||
        _roundHasStudentAction(messages, roundId);
  }

  bool _roundUsesGuidedPractice(
    List<ChatLessonMessage> messages,
    String roundId,
  ) {
    return messages.any(
      (message) =>
          _roundIdFor(message) == roundId &&
          message.kind == ChatLessonMessageKind.practiceAction,
    );
  }

  bool _roundHasStudentAction(List<ChatLessonMessage> messages, String roundId) {
    return messages.any((message) {
      if (_roundIdFor(message) != roundId) return false;
      return message.kind == ChatLessonMessageKind.feedback ||
          message.selectedAnswer != null ||
          message.signals.isNotEmpty;
    });
  }

  void _unlockPracticeRound(ChatLessonMessage message) {
    final roundId = _roundIdFor(message);
    if (roundId == null) return;
    setState(() {
      _practiceUnlockedRounds.add(roundId);
    });
    _schedulePedagogicalScroll();
    _optionsTimer?.cancel();
    _optionsTimer = Timer(_optionsRevealDelay, () {
      if (!mounted) return;
      setState(() => _optionsReadyRounds.add(roundId));
      _schedulePedagogicalScroll();
    });
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

String? _roundIdFor(ChatLessonMessage message) {
  if (message.isHistorical) return null;
  final base = [
    message.lessonLocalId ?? '',
    message.marker ?? '',
    message.itemIdx?.toString() ?? '',
    message.layer?.toString() ?? '',
    _activeRoundSuffix(message.id),
  ].where((part) => part.isNotEmpty).join('|');
  if (base.trim().isEmpty) return null;
  return base;
}

String _activeRoundSuffix(String id) {
  const prefixes = [
    'item-intro-',
    'explanation-',
    'image-',
    'practice-action-',
    'question-',
    'options-',
    'feedback-',
  ];
  for (final prefix in prefixes) {
    if (id.startsWith(prefix)) return id.substring(prefix.length);
  }
  return id;
}

double _pedagogicalGapAfter(ChatLessonMessage message) {
  return switch (message.kind) {
    ChatLessonMessageKind.itemIntro => SimSpacing.xl,
    ChatLessonMessageKind.explanation => SimSpacing.xxl,
    ChatLessonMessageKind.image => SimSpacing.xxl,
    ChatLessonMessageKind.practiceAction => SimSpacing.xxl,
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
    required this.onPractice,
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
  final void Function(ChatLessonMessage message) onPractice;
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
                    onPractice: () => onPractice(message),
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
    this.onPractice,
    super.key,
  });

  final AulaConversationBlock block;
  final AulaConversationActions actions;
  final Set<String> pendingActionKeys;
  final VoidCallback? onImageSettled;
  final VoidCallback? onPractice;

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
      AulaConversationBlockType.practiceAction => _ActionButton(
        label: message.text ?? t('aula_practice_foundation'),
        onPressed: onPractice ?? actions.advance,
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
          const SizedBox(height: SimSpacing.sm),
          _ActionButton(label: t('retry'), onPressed: actions.retry),
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
      return _StatusText(
        icon: Icons.image_not_supported_outlined,
        text: widget.message.text ?? t('aula_image_unavailable_short'),
        tone: SimSurfaceTone.warning,
      );
    }
    if (data == null || data.isEmpty) {
      return _StatusText(
        icon: Icons.image_outlined,
        text: t('aula_image_loading'),
        tone: SimSurfaceTone.soft,
        loading: true,
      );
    }
    final caption = widget.message.text ?? t('aula_image_alt');
    return LessonVisualBoard(
      data: data,
      caption: caption,
      onImageSettled: widget.onImageSettled,
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.message});

  final ChatLessonMessage message;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final style = switch (message.kind) {
      ChatLessonMessageKind.itemIntro => SimTypography.label.copyWith(
        color: palette.muted,
      ),
      ChatLessonMessageKind.explanation => SimTypography.lessonBody.copyWith(
        color: palette.text,
      ),
      ChatLessonMessageKind.question => SimTypography.lessonQuestion.copyWith(
        color: palette.text,
        fontSize: 18,
      ),
      ChatLessonMessageKind.feedback => SimTypography.feedback.copyWith(
        color: message.isCorrect == false ? palette.warning : palette.success,
      ),
      _ => DefaultTextStyle.of(context).style.copyWith(color: palette.text),
    };
    final chunks = <Widget>[
      if ((message.title ?? '').isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: SimSpacing.xs),
          child: Text(
            message.title!,
            style: SimTypography.meta.copyWith(color: palette.muted),
          ),
        ),
      if ((message.text ?? '').isNotEmpty) Text(message.text!, style: style),
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
    crossAxisAlignment: CrossAxisAlignment.stretch,
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
        _SignalChoice(
          key: Key('signal-button-${signal.value}'),
          value: signal.value,
          label: t(signal.labelKey),
          enabled: signal.enabled,
          onTap: () => onSignal(signal.value),
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
      SimActionButton(label: label, onPressed: onPressed);
}

class _SignalChoice extends StatelessWidget {
  const _SignalChoice({
    required this.value,
    required this.label,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final int value;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled ? palette.surface : palette.surfaceSoft,
        borderRadius: BorderRadius.circular(SimRadius.pill),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(SimRadius.pill),
          child: Container(
            constraints: const BoxConstraints(minHeight: SimTouch.min),
            padding: const EdgeInsets.symmetric(
              horizontal: SimSpacing.md,
              vertical: SimSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SimRadius.pill),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: palette.warningSurface,
                  child: Text(
                    '$value',
                    style: TextStyle(
                      color: palette.warning,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: SimSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SimTypography.label.copyWith(
                      color: enabled ? palette.text : palette.muted,
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

class _LiveLoadingBlock extends StatelessWidget {
  const _LiveLoadingBlock({required this.message, required this.onRetry});

  final ChatLessonMessage message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (message.id == 'doubt-processing' && (message.progress ?? 0) > 0) {
      return DoubtProgressBar(
        progress: message.progress!,
        label: message.text ?? t('aula_doubt_processing'),
      );
    }
    if (message.actionKey == 'retry-menu-lesson') {
      return _MenuLessonArrivalBlock(message: message, onRetry: onRetry);
    }
    return _StatusText(
      icon: Icons.auto_awesome,
      text: message.text ?? t('loading'),
      tone: SimSurfaceTone.soft,
      loading: true,
    );
  }
}

class _MenuLessonArrivalBlock extends StatefulWidget {
  const _MenuLessonArrivalBlock({required this.message, required this.onRetry});

  final ChatLessonMessage message;
  final VoidCallback onRetry;

  @override
  State<_MenuLessonArrivalBlock> createState() =>
      _MenuLessonArrivalBlockState();
}

class _MenuLessonArrivalBlockState extends State<_MenuLessonArrivalBlock> {
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  void _scheduleTick() {
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _tick = (_tick + 1).clamp(0, 6));
      if (_tick < 6) _scheduleTick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final progress = ((_tick + 1) / 6).clamp(0.18, 0.92);
    final detail = _tick < 2
        ? 'Localizando este ponto.'
        : _tick < 4
        ? 'Chamando o professor.'
        : 'Quase lá. A aula entra aqui.';
    return SimStatusSurface(
      tone: SimSurfaceTone.soft,
      icon: Icons.auto_awesome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message.text ?? t('aula_menu_lesson_arriving'),
            style: SimTypography.label.copyWith(color: palette.text),
          ),
          const SizedBox(height: SimSpacing.xs),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              detail,
              key: ValueKey(detail),
              style: SimTypography.caption.copyWith(color: palette.muted),
            ),
          ),
          const SizedBox(height: SimSpacing.sm),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.12, end: progress.toDouble()),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              minHeight: 4,
              value: value,
              backgroundColor: palette.border,
            ),
          ),
          if (_tick >= 5) ...[
            const SizedBox(height: SimSpacing.sm),
            SimActionButton(
              label: t('aula_try_again_2'),
              icon: Icons.refresh,
              onPressed: widget.onRetry,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({
    required this.icon,
    required this.text,
    required this.tone,
    this.loading = false,
  });

  final IconData icon;
  final String text;
  final SimSurfaceTone tone;
  final bool loading;

  @override
  Widget build(BuildContext context) => SimStatusSurface(
    tone: tone,
    icon: icon,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: SimTypography.caption),
        if (loading) ...[
          const SizedBox(height: SimSpacing.xs),
          const LinearProgressIndicator(minHeight: 3),
        ],
      ],
    ),
  );
}
