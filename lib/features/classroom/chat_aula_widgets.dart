import 'package:flutter/material.dart';

import '../../shared/widgets/shared_widgets.dart';
import '../../sim/ui/widgets/doubt_progress_bar.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/ui/sim_i18n.dart';
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
    final target = _selectPedagogicalScrollTarget(widget.messages);
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
    final estimated = target.index <= 0 || widget.messages.length <= 1
        ? 0.0
        : max * (target.index / (widget.messages.length - 1));
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
    if (widget.messages.isEmpty) {
      return Center(
        key: const Key('chat-empty-state'),
        child: Text(t('aula_choose_goal')),
      );
    }
    return ListView.builder(
      key: const Key('chat-aula-timeline'),
      controller: _effectiveScrollController,
      padding: widget.padding,
      itemCount: widget.messages.length,
      itemBuilder: (context, index) => ChatAulaMessageBubble(
        key: _keyForMessage(widget.messages[index]),
        message: widget.messages[index],
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
    return _target(messages, feedbackIndex);
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

_PedagogicalScrollTarget _target(List<ChatLessonMessage> messages, int index) {
  return _PedagogicalScrollTarget(
    message: messages[index],
    index: index,
    alignment: _ChatAulaTimelineState._renderedElementAnchor,
  );
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child:
                message.id == 'doubt-processing' && (message.progress ?? 0) > 0
                ? DoubtProgressBar(
                    progress: message.progress!,
                    label: message.text ?? t('aula_doubt_processing'),
                  )
                : Text(message.text ?? t('loading')),
          ),
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
    final style = DefaultTextStyle.of(context).style;
    final chunks = <Widget>[
      if ((message.title ?? '').isNotEmpty)
        Text(message.title!, style: Theme.of(context).textTheme.titleSmall),
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
