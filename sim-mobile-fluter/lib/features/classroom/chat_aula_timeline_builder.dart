import '../../sim/classroom/classroom_models.dart';
import '../../sim/classroom/lesson_runtime_engine.dart';
import '../../sim/lesson/lesson_models.dart';
import '../../sim/state/student_learning_state.dart';
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
    messages
      ..add(
        ChatLessonMessage(
          id: 'history-question-${entry.id}-$i',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.historyQuestion,
          text: entry.text,
          imageData: entry.imageUrl,
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
      ),
    );

    if (input.doubtProcessing) {
      messages.add(
        ChatLessonMessage(
          id: 'doubt-processing',
          role: ChatLessonMessageRole.system,
          kind: ChatLessonMessageKind.loading,
          text: 'Analisando sua duvida...',
          progress: input.doubtProgress,
        ),
      );
    } else if ((input.doubtError ?? '').trim().isNotEmpty) {
      messages.add(
        ChatLessonMessage(
          id: 'doubt-error',
          role: ChatLessonMessageRole.system,
          kind: ChatLessonMessageKind.error,
          text: input.doubtError,
        ),
      );
    } else if ((input.doubtResponse ?? '').trim().isNotEmpty) {
      messages.add(
        ChatLessonMessage(
          id: 'doubt-response',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.feedback,
          text: input.doubtResponse,
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
        ),
      );
    }

    messages.add(
      ChatLessonMessage(
        id: 'question-$activeId',
        role: ChatLessonMessageRole.sim,
        kind: ChatLessonMessageKind.question,
        text: content.question,
      ),
    );

    final selected = phase?.letter;
    final locked = snapshot?.viewModel?.locked ?? false;
    messages.add(
      ChatLessonMessage(
        id: 'options-$activeId',
        role: ChatLessonMessageRole.sim,
        kind: ChatLessonMessageKind.options,
        selectedAnswer: selected,
        options: _options(content, selected: selected, enabled: !locked),
      ),
    );

    if (selected != null) {
      messages.add(
        ChatLessonMessage(
          id: 'student-answer-$activeId',
          role: ChatLessonMessageRole.student,
          kind: ChatLessonMessageKind.studentAnswer,
          text: selected.name,
          selectedAnswer: selected,
        ),
      );
    }

    if (phase?.type == ClassroomPhaseType.expandida) {
      messages.add(
        ChatLessonMessage(
          id: 'signals-$activeId',
          role: ChatLessonMessageRole.sim,
          kind: ChatLessonMessageKind.signals,
          signals: _signals(enabled: true),
        ),
      );
    } else if (phase?.type == ClassroomPhaseType.processando) {
      messages
        ..add(
          ChatLessonMessage(
            id: 'student-signal-$activeId',
            role: ChatLessonMessageRole.student,
            kind: ChatLessonMessageKind.studentSignal,
            text: _signalText(phase?.signal),
            selectedSignal: phase?.signal,
          ),
        )
        ..add(
          const ChatLessonMessage(
            id: 'processing-signal',
            role: ChatLessonMessageRole.system,
            kind: ChatLessonMessageKind.processing,
            text: 'Registrando...',
          ),
        );
    } else if (phase?.type == ClassroomPhaseType.concluido) {
      messages
        ..add(
          ChatLessonMessage(
            id: 'student-signal-$activeId',
            role: ChatLessonMessageRole.student,
            kind: ChatLessonMessageKind.studentSignal,
            text: _signalText(phase?.signal),
            selectedSignal: phase?.signal,
          ),
        )
        ..add(
          const ChatLessonMessage(
            id: 'doubt-action',
            role: ChatLessonMessageRole.sim,
            kind: ChatLessonMessageKind.doubtAction,
            text: 'Dúvida',
            actionKey: 'open-doubt',
          ),
        )
        ..add(
          ChatLessonMessage(
            id: 'feedback-$activeId',
            role: ChatLessonMessageRole.sim,
            kind: ChatLessonMessageKind.feedback,
            text: feedbackText(phase?.message ?? ''),
            isCorrect: phase?.wasCorrect,
            actionKey: snapshot?.viewModel?.nextLabel,
          ),
        );
    }
  }

  if (phase?.type == ClassroomPhaseType.erroEngine ||
      (input.runtimeError ?? '').trim().isNotEmpty) {
    messages.add(
      ChatLessonMessage(
        id: 'engine-error',
        role: ChatLessonMessageRole.system,
        kind: ChatLessonMessageKind.error,
        text: phase?.message ?? input.runtimeError,
        actionKey: 'retry',
      ),
    );
  }

  return messages;
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

String _signalText(DecisionSignal? signal) {
  return switch (signal) {
    DecisionSignal.one => '1',
    DecisionSignal.two => '2',
    DecisionSignal.three => '3',
    null => '',
  };
}
