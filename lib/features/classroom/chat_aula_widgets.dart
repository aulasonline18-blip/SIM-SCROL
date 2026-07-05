import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/utils/sim_constants.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../sim/auxiliary/aux_room_models.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/sim_theme.dart';
import '../../sim/ui/widgets/doubt_progress_bar.dart';
import '../onboarding/preparation_and_placement.dart';
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
  final ScrollController? scrollController;
  final EdgeInsets padding;

  @override
  State<ChatAulaTimeline> createState() => _ChatAulaTimelineState();
}

class _ChatAulaTimelineState extends State<ChatAulaTimeline> {
  late final ScrollController _scrollController =
      widget.scrollController ?? ScrollController();
  late final bool _ownsScrollController = widget.scrollController == null;
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  bool _autoFollow = true;
  bool _showCurrentButton = false;
  String _messageSignature = '';

  @override
  void initState() {
    super.initState();
    _messageSignature = _signatureOf(widget.messages);
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
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
        setState(() => _showCurrentButton = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    if (_ownsScrollController) _scrollController.dispose();
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
      });
    }
  }

  Future<void> _scrollToCurrent() async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
      return;
    }
    final targetKey = _targetMessageKey();
    final targetContext = targetKey?.currentContext;
    if (targetContext != null) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 1,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    } else {
      await _scrollController.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) return;
    setState(() {
      _autoFollow = true;
      _showCurrentButton = false;
    });
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

  GlobalKey? _targetMessageKey() {
    if (widget.messages.isEmpty) return null;
    final preferred = widget.messages.lastWhere(
      (message) =>
          message.kind == ChatLessonMessageKind.signals ||
          message.kind == ChatLessonMessageKind.feedback ||
          message.kind == ChatLessonMessageKind.error ||
          message.kind == ChatLessonMessageKind.image,
      orElse: () => widget.messages.last,
    );
    return _messageKeys[preferred.id];
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Stack(
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
                final nearEnd = metrics.maxScrollExtent - metrics.pixels <= 96;
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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
              child: _ChatReturnToCurrentButton(onPressed: _scrollToCurrent),
            ),
          ),
      ],
    );
  }
}

class _ChatReturnToCurrentButton extends StatelessWidget {
  const _ChatReturnToCurrentButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      label: t('aula_return_current'),
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
                Text(
                  t('aula_return_current'),
                  style: TextStyle(
                    color: palette.surface,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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

class ChatAulaMessageBubble extends StatelessWidget {
  const ChatAulaMessageBubble({
    required this.message,
    required this.semanticIndex,
    required this.onChooseAnswer,
    required this.onSignal,
    required this.onRetry,
    required this.onNext,
    required this.onOpenDoubt,
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
            onImageSettled: onImageSettled,
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      liveRegion: _isLiveRegion(message),
      label: _semanticLabel(message),
      sortKey: OrdinalSortKey(semanticIndex.toDouble()),
      child: Align(
        alignment: isStudent ? Alignment.centerRight : Alignment.centerLeft,
        child: bubble,
      ),
    );
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

class _ChatAulaMessageBody extends StatelessWidget {
  const _ChatAulaMessageBody({
    required this.message,
    required this.onChooseAnswer,
    required this.onSignal,
    required this.onRetry,
    required this.onNext,
    required this.onOpenDoubt,
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
  final VoidCallback? onImageSettled;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return switch (message.kind) {
      ChatLessonMessageKind.options => _ChatOptions(
        message: message,
        onChooseAnswer: onChooseAnswer,
      ),
      ChatLessonMessageKind.signals => _ChatSignals(
        message: message,
        onSignal: onSignal,
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
                onRetry: message.actionKey == 'retry' ? onRetry : null,
              ),
      ChatLessonMessageKind.error => _StatusMessage(
        text: message.text ?? t('aula_gen_fail'),
        loading: false,
        warn: true,
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
            const SizedBox(height: 12),
            _ChatActionButton(
              label: nextBtnText(message.actionKey ?? ''),
              onPressed: onNext,
              enabled: session?.doubt.status != DoubtStatus.processing,
            ),
          ],
        ],
      ),
      ChatLessonMessageKind.doubtAction => _ChatActionButton(
        key: const Key('chat-doubt-action'),
        label: message.text ?? t('aula_doubt'),
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
  const _ChatOptions({required this.message, required this.onChooseAnswer});

  final ChatLessonMessage message;
  final void Function(AnswerLetter letter) onChooseAnswer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in message.options)
          AnswerButton(
            label: option.letter.name,
            text: option.text,
            active: option.selected,
            enabled: option.enabled,
            onTap: () => onChooseAnswer(option.letter),
          ),
      ],
    );
  }
}

class _ChatSignals extends StatelessWidget {
  const _ChatSignals({required this.message, required this.onSignal});

  final ChatLessonMessage message;
  final void Function(int value) onSignal;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Como voce se sente?',
          style: SimTypography.lessonBody.copyWith(
            color: palette.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < message.signals.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _SignalButton(
                  signal: message.signals[i],
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
  const _SignalButton({required this.signal, required this.onPressed});

  final ChatLessonSignal signal;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      enabled: signal.enabled,
      label: t('signal_option_named', {
        'value': signal.value,
        'label': t(signal.labelKey),
      }),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(SimRadius.lg),
        child: InkWell(
          onTap: signal.enabled ? onPressed : null,
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
    this.onRetry,
  });

  final String text;
  final bool loading;
  final bool warn;
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
          _ChatActionButton(label: t('aula_try_again_2'), onPressed: onRetry!),
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
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled ? palette.text : palette.muted,
        borderRadius: BorderRadius.circular(SimRadius.md),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(SimRadius.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: SimTouch.min),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                color: enabled
                    ? palette.surface
                    : palette.surface.withValues(alpha: 0.56),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
