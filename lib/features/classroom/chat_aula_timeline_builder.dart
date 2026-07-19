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
    this.doubtProcessing = false,
    this.doubtProgress = 0,
    this.doubtResponse,
    this.doubtError,
    this.lessonLocalId,
  });

  final LessonRuntimeSnapshot? snapshot;
  final bool runtimeLoading;
  final String? runtimeError;
  final bool showImagePanel;
  final String imageStatus;
  final String? imageError;
  final bool doubtProcessing;
  final int doubtProgress;
  final String? doubtResponse;
  final String? doubtError;
  final String? lessonLocalId;
}

List<ChatLessonMessage> buildChatLessonMessages(ChatLessonTimelineInput input) {
  final messages = <ChatLessonMessage>[];
  final snapshot = input.snapshot;
  final content = snapshot?.conteudo;
  final phase = snapshot?.phase;
  final marker = snapshot?.itemMarker;
  final itemIdx = _itemIdxFromHeader(snapshot?.viewModel?.headerLabel);
  final layer = _layerFromHeader(snapshot?.viewModel?.headerLabel);

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
          lessonLocalId: input.lessonLocalId,
          marker: marker,
          itemIdx: itemIdx,
          layer: layer,
          createdAt: entry.answeredAt,
          isHistorical: true,
          isActionable: false,
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
          lessonLocalId: input.lessonLocalId,
          marker: marker,
          itemIdx: itemIdx,
          layer: layer,
          createdAt: entry.answeredAt,
          isHistorical: true,
          isActionable: false,
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
        isActionable: false,
        deliveryStatus: ChatLessonDeliveryStatus.processing,
      ),
    );
  }

  if (content == null && phase?.type == ClassroomPhaseType.avancoPendente) {
    messages.add(
      ChatLessonMessage(
        id: 'local-advance-preparing-${marker ?? 'active'}',
        role: ChatLessonMessageRole.system,
        kind: ChatLessonMessageKind.processing,
        text: t(phase?.message ?? 'aula_advance_pending'),
        lessonLocalId: input.lessonLocalId,
        marker: marker,
        itemIdx: itemIdx,
        layer: layer,
        isActionable: false,
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
        lessonLocalId: input.lessonLocalId,
        marker: marker,
        unit: snapshot?.viewModel?.itemUnit ?? snapshot?.itemUnit,
        title: snapshot?.viewModel?.itemTitle ?? snapshot?.itemTitle,
        itemIdx: itemIdx,
        layer: layer,
        isActionable: false,
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
          lessonLocalId: input.lessonLocalId,
          marker: marker,
          itemIdx: itemIdx,
          layer: layer,
          isActionable: false,
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
          lessonLocalId: input.lessonLocalId,
          marker: marker,
          itemIdx: itemIdx,
          layer: layer,
          isActionable: false,
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
          lessonLocalId: input.lessonLocalId,
          marker: marker,
          itemIdx: itemIdx,
          layer: layer,
          isActionable: false,
          deliveryStatus: ChatLessonDeliveryStatus.delivered,
        ),
      );
    }

    final imageData = snapshot?.imagem;
    if ((imageData != null && imageData.trim().isNotEmpty) ||
        input.showImagePanel ||
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
          lessonLocalId: input.lessonLocalId,
          marker: marker,
          itemIdx: itemIdx,
          layer: layer,
          isActionable: false,
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
        lessonLocalId: input.lessonLocalId,
        marker: marker,
        itemIdx: itemIdx,
        layer: layer,
        isActionable: false,
        deliveryStatus: ChatLessonDeliveryStatus.delivered,
      ),
    );

    final selected = phase?.letter;
    final answerBusy =
        input.runtimeLoading || phase?.type == ClassroomPhaseType.processando;
    messages.add(
      ChatLessonMessage(
        id: 'options-$activeId',
        role: ChatLessonMessageRole.sim,
        kind: ChatLessonMessageKind.options,
        selectedAnswer: selected,
        options: _options(content, selected: selected, enabled: !answerBusy),
        signals: phase?.type == ClassroomPhaseType.expandida
            ? _signals(enabled: !answerBusy)
            : const [],
        lessonLocalId: input.lessonLocalId,
        marker: marker,
        itemIdx: itemIdx,
        layer: layer,
        isActionable: true,
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
          lessonLocalId: input.lessonLocalId,
          marker: marker,
          itemIdx: itemIdx,
          layer: layer,
          isActionable: false,
          deliveryStatus: ChatLessonDeliveryStatus.processing,
        ),
      );
    } else if (phase?.type == ClassroomPhaseType.avancoPendente) {
      messages.add(
        ChatLessonMessage(
          id: 'local-advance-preparing-$activeId',
          role: ChatLessonMessageRole.system,
          kind: ChatLessonMessageKind.processing,
          text: t(phase?.message ?? 'aula_advance_pending'),
          lessonLocalId: input.lessonLocalId,
          marker: marker,
          itemIdx: itemIdx,
          layer: layer,
          isActionable: false,
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
          lessonLocalId: input.lessonLocalId,
          marker: marker,
          itemIdx: itemIdx,
          layer: layer,
          isActionable: false,
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
            lessonLocalId: input.lessonLocalId,
            marker: marker,
            itemIdx: itemIdx,
            layer: layer,
            isActionable: false,
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
        text: studentFacingRuntimeError(phase?.message ?? input.runtimeError),
        lessonLocalId: input.lessonLocalId,
        marker: marker,
        itemIdx: itemIdx,
        layer: layer,
        isActionable: false,
        deliveryStatus: ChatLessonDeliveryStatus.failed,
      ),
    );
  }

  return _withSequenceIndexes(messages);
}

int? _itemIdxFromHeader(String? headerLabel) {
  final match = RegExp(r'aula_item_of:(\d+)/').firstMatch(headerLabel ?? '');
  if (match == null) return null;
  final oneBased = int.tryParse(match.group(1) ?? '');
  if (oneBased == null || oneBased <= 0) return null;
  return oneBased - 1;
}

int? _layerFromHeader(String? headerLabel) {
  final match = RegExp(r'aula_layer_(\d+)').firstMatch(headerLabel ?? '');
  return int.tryParse(match?.group(1) ?? '');
}

String? studentFacingRuntimeError(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  if (text.startsWith('aula_fb_')) return feedbackText(text);
  final lower = text.toLowerCase();
  if (lower.contains('lessonlocalid ausente')) {
    return t('aula_choose_goal');
  }
  if (lower.contains('http 401') ||
      lower.contains('http 403') ||
      lower.contains('invalid token') ||
      lower.contains('unauthorized') ||
      lower.contains('forbidden') ||
      lower.contains('missing bearer')) {
    return t('aula_session_expired');
  }
  if (lower.contains('http') ||
      lower.contains('{') ||
      lower.contains('}') ||
      lower.contains('exception') ||
      lower.contains('stack') ||
      lower.contains('error')) {
    return t('aula_gen_fail');
  }
  final translated = t(text);
  if (translated != text) return translated;
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection') ||
      lower.contains('timeout')) {
    return t('aula_server_unavailable');
  }
  return t('aula_gen_fail');
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
