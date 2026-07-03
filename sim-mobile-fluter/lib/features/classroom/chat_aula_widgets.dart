import 'package:flutter/material.dart';

import '../../core/utils/sim_constants.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/sim_theme.dart';
import '../../sim/ui/widgets/doubt_progress_bar.dart';
import '../onboarding/preparation_and_placement.dart';
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
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('chat-aula-timeline'),
      padding: padding,
      children: [
        for (var index = 0; index < messages.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          ChatAulaMessageBubble(
            message: messages[index],
            session: session,
            onChooseAnswer: onChooseAnswer,
            onSignal: onSignal,
            onRetry: onRetry,
            onNext: onNext,
            onOpenDoubt: onOpenDoubt,
            onImageSettled: onImageSettled,
          ),
        ],
      ],
    );
  }
}

class ChatAulaMessageBubble extends StatelessWidget {
  const ChatAulaMessageBubble({
    required this.message,
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
      label: _semanticLabel(message),
      child: Align(
        alignment: isStudent ? Alignment.centerRight : Alignment.centerLeft,
        child: bubble,
      ),
    );
  }

  String _semanticLabel(ChatLessonMessage message) {
    return switch (message.role) {
      ChatLessonMessageRole.student => 'Mensagem do aluno',
      ChatLessonMessageRole.system => 'Mensagem do sistema',
      ChatLessonMessageRole.sim => 'Mensagem do SIM',
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
                text: message.text ?? 'Analisando sua dúvida...',
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
            ),
          ],
        ],
      ),
      ChatLessonMessageKind.doubtAction => _ChatActionButton(
        key: const Key('chat-doubt-action'),
        label: message.text ?? 'Dúvida',
        onPressed: onOpenDoubt,
      ),
      ChatLessonMessageKind.studentAnswer ||
      ChatLessonMessageKind.historyAnswer ||
      ChatLessonMessageKind.studentSignal => _StudentShortMessage(
        text: message.text ?? '',
      ),
      _ => _TextMessage(message.text ?? ''),
    };
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
      label: 'Sinal ${signal.value}',
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
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      child: Material(
        color: palette.text,
        borderRadius: BorderRadius.circular(SimRadius.md),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(SimRadius.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: SimTouch.min),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                color: palette.surface,
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
