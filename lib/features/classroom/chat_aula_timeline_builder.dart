import '../../sim/classroom/classroom_models.dart';
import '../../sim/classroom/lesson_runtime_engine.dart';
import '../../sim/lesson/lesson_models.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/ui/sim_i18n.dart';
import '../onboarding/preparation_and_placement.dart';
import 'chat_aula_messages.dart';

class ChatLessonTimelineInput {
  const ChatLessonTimelineInput({
    required this.snapshot,
    this.runtimeLoading = false,
    this.runtimeError,
    this.showImagePanel = false,
    this.imageStatus = 'idle',
    this.imageError,
    this.hasPaidImageOffer = false,
    this.doubtProcessing = false,
    this.doubtProgress = 0,
    this.doubtResponse,
    this.doubtError,
  });

  final LessonRuntimeSnapshot? snapshot;
  final bool runtimeLoading;
  final String? runtimeError;
  final bool showImagePanel;
  final String imageStatus;
  final String? imageError;
  final bool hasPaidImageOffer;
  final bool doubtProcessing;
  final int doubtProgress;
  final String? doubtResponse;
  final String? doubtError;
}

List<ChatLessonMessage> buildChatLessonMessages(ChatLessonTimelineInput input) {
  final messages = <ChatLessonMessage>[];
  final snapshot = input.snapshot;
  final content = snapshot?.conteudo;
  final phase = snapshot?.phase;

  for (var i = 0; i < (snapshot?.history.length ?? 0); i++) {
    final entry = snapshot!.history[i];
    final timestampLabel = _formatTimestampLabel(entry.answeredAt);
    messages
      ..add(
        ChatLessonMessage(
          id: 'history-question-${entry.id}-$i',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.historyQuestion,
          text: entry.text,
          options: entry.options
              .map(
                (option) => ChatLessonOption(
                  letter: option.id,
                  text: option.text,
                  selected: option.id == entry.chosenOptionId,
                  enabled: false,
                ),
              )
              .toList(growable: false),
          imageData: entry.imageUrl,
          selectedAnswer: entry.chosenOptionId,
          isCorrect: entry.correct,
          deliveryStatus: ChatLessonDeliveryStatus.read,
          timestampLabel: timestampLabel,
        ),
      )
      ..add(
        ChatLessonMessage(
          id: 'history-answer-${entry.id}-$i',
          role: ChatLessonMessageRole.student,
          kind: ChatLessonMessageKind.historyAnswer,
          text: entry.chosenOptionId.name,
          selectedAnswer: entry.chosenOptionId,
          isCorrect: entry.correct,
          deliveryStatus: ChatLessonDeliveryStatus.read,
          timestampLabel: timestampLabel,
        ),
      );
  }

  if (input.runtimeLoading && content == null) {
    messages.add(
      const ChatLessonMessage(
        id: 'runtime-loading',
        role: ChatLessonMessageRole.system,
        kind: ChatLessonMessageKind.loading,
        actionKey: 'retry',
        deliveryStatus: ChatLessonDeliveryStatus.processing,
      ),
    );
  }

  if (content != null) {
    final activeId = _activeMessageId(snapshot, content);
    messages.add(
      ChatLessonMessage(
        id: 'explanation-$activeId',
        role: ChatLessonMessageRole.sim,
        kind: ChatLessonMessageKind.explanation,
        text: content.explanation,
        deliveryStatus: ChatLessonDeliveryStatus.delivered,
      ),
    );

    if (input.doubtProcessing) {
      messages.add(
        ChatLessonMessage(
          id: 'doubt-processing',
          role: ChatLessonMessageRole.system,
          kind: ChatLessonMessageKind.loading,
          text: t('aula_doubt_processing'),
          progress: input.doubtProgress,
          deliveryStatus: ChatLessonDeliveryStatus.processing,
        ),
      );
    } else if ((input.doubtError ?? '').trim().isNotEmpty) {
      messages.add(
        ChatLessonMessage(
          id: 'doubt-error',
          role: ChatLessonMessageRole.system,
          kind: ChatLessonMessageKind.error,
          text: input.doubtError,
          deliveryStatus: ChatLessonDeliveryStatus.failed,
        ),
      );
    } else if ((input.doubtResponse ?? '').trim().isNotEmpty) {
      messages.add(
        ChatLessonMessage(
          id: 'doubt-response',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.feedback,
          text: input.doubtResponse,
          deliveryStatus: ChatLessonDeliveryStatus.delivered,
        ),
      );
    }

    final imageData = snapshot?.imagem;
    if ((imageData != null && imageData.trim().isNotEmpty) ||
        input.showImagePanel ||
        input.hasPaidImageOffer ||
        (input.imageError ?? '').trim().isNotEmpty ||
        input.imageStatus == 'loading') {
      messages.add(
        ChatLessonMessage(
          id: 'image-$activeId',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.image,
          imageData: imageData,
          text: input.imageError,
          imageStatus: input.imageStatus,
          hasPaidImageOffer: input.hasPaidImageOffer,
          actionKey: input.hasPaidImageOffer ? 'paid-image-offer' : null,
          deliveryStatus: input.imageStatus == 'loading'
              ? ChatLessonDeliveryStatus.processing
              : (input.imageError ?? '').trim().isNotEmpty
              ? ChatLessonDeliveryStatus.failed
              : ChatLessonDeliveryStatus.delivered,
        ),
      );
    }

    messages.add(
      ChatLessonMessage(
        id: 'question-$activeId',
        role: ChatLessonMessageRole.sim,
        kind: ChatLessonMessageKind.question,
        text: content.question,
        deliveryStatus: ChatLessonDeliveryStatus.delivered,
      ),
    );

    final selected = phase?.letter;
    messages.add(
      ChatLessonMessage(
        id: 'options-$activeId',
        role: ChatLessonMessageRole.sim,
        kind: ChatLessonMessageKind.options,
        selectedAnswer: selected,
        options: _options(content, selected: selected, enabled: true),
        signals: phase?.type == ClassroomPhaseType.expandida
            ? _signals(enabled: true)
            : const [],
        deliveryStatus: ChatLessonDeliveryStatus.delivered,
      ),
    );

    if (phase?.type == ClassroomPhaseType.processando) {
      messages.add(
        ChatLessonMessage(
          id: 'processing-signal',
          role: ChatLessonMessageRole.system,
          kind: ChatLessonMessageKind.processing,
          text: t('aula_registering'),
          deliveryStatus: ChatLessonDeliveryStatus.processing,
        ),
      );
    } else if (phase?.type == ClassroomPhaseType.concluido) {
      messages.add(
        ChatLessonMessage(
          id: 'feedback-$activeId',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.feedback,
          text: feedbackText(phase?.message ?? ''),
          isCorrect: phase?.wasCorrect,
          actionKey: snapshot?.viewModel?.nextLabel,
          deliveryStatus: ChatLessonDeliveryStatus.delivered,
        ),
      );
      if (input.runtimeLoading) {
        messages.add(
          ChatLessonMessage(
            id: 'runtime-advance-loading-$activeId',
            role: ChatLessonMessageRole.system,
            kind: ChatLessonMessageKind.loading,
            text: t('preparing_next_lesson'),
            deliveryStatus: ChatLessonDeliveryStatus.processing,
          ),
        );
      }
    }
  }

  if (phase?.type == ClassroomPhaseType.erroEngine ||
      (input.runtimeError ?? '').trim().isNotEmpty) {
    messages.add(
      ChatLessonMessage(
        id: 'engine-error',
        role: ChatLessonMessageRole.system,
        kind: ChatLessonMessageKind.error,
        text: _studentFacingRuntimeError(phase?.message ?? input.runtimeError),
        actionKey: 'retry',
        deliveryStatus: ChatLessonDeliveryStatus.failed,
      ),
    );
  }

  return _withSequenceIndexes(messages);
}

String? _studentFacingRuntimeError(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  final lower = text.toLowerCase();
  if (lower.contains('lessonlocalid ausente')) {
    return 'Escolha um objetivo para abrir a aula.';
  }
  if (lower.contains('http 401') ||
      lower.contains('http 403') ||
      lower.contains('invalid token') ||
      lower.contains('unauthorized') ||
      lower.contains('forbidden') ||
      lower.contains('missing bearer')) {
    return 'Sua sessão expirou. Entre novamente para continuar a aula.';
  }
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection') ||
      lower.contains('timeout')) {
    return 'Não consegui falar com o servidor agora. Tente novamente.';
  }
  return text;
}

String _activeMessageId(
  LessonRuntimeSnapshot? snapshot,
  LessonContent content,
) {
  final parts = [
    snapshot?.itemMarker ?? 'active',
    snapshot?.viewModel?.headerLabel ?? '',
    content.question,
    content.explanation,
  ].map(_safeIdPart).where((part) => part.isNotEmpty).toList(growable: false);
  return parts.isEmpty ? 'active' : parts.join('-');
}

String? _formatTimestampLabel(int? epochMs) {
  if (epochMs == null || epochMs <= 0) return null;
  final local = DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

List<ChatLessonMessage> _withSequenceIndexes(List<ChatLessonMessage> messages) {
  return [
    for (var i = 0; i < messages.length; i++)
      messages[i].copyWith(sequenceIndex: i),
  ];
}

String _safeIdPart(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (normalized.length <= 48) return normalized;
  return normalized.substring(0, 48).replaceAll(RegExp(r'-+$'), '');
}

List<ChatLessonOption> _options(
  LessonContent content, {
  required AnswerLetter? selected,
  required bool enabled,
}) {
  return AnswerLetter.values
      .map(
        (letter) => ChatLessonOption(
          letter: letter,
          text: content.options[letter] ?? '',
          selected: selected == letter,
          enabled: enabled,
        ),
      )
      .toList(growable: false);
}

List<ChatLessonSignal> _signals({required bool enabled}) {
  return const [
        (1, 'aula_sig_certeza'),
        (2, 'aula_sig_revisar'),
        (3, 'aula_sig_nao_sei'),
      ]
      .map(
        (item) => ChatLessonSignal(
          value: item.$1,
          labelKey: item.$2,
          enabled: enabled,
        ),
      )
      .toList(growable: false);
}
