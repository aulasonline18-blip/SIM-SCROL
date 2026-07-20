import 'dart:async';

import 'package:flutter/material.dart';

import '../../sim/auxiliary/aux_room_models.dart';
import '../../sim/auxiliary/doubt_input_sheet.dart';
import '../../sim/classroom/classroom_text_scale.dart';
import '../../sim/classroom/pedagogical_slot_visibility.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/sim_theme.dart';
import '../../sim/ui/widgets/fixed_bubble.dart';
import '../../session/chat_conversation_store.dart';
import '../onboarding/preparation_and_placement.dart';
import '../session/lab_session.dart';
import 'aula_widgets.dart';
import 'chat_aula_messages.dart';
import 'aux_room_screens.dart';
import 'chat_aula_timeline_builder.dart';
import 'chat_aula_widgets.dart';
import 'doubt_input_sheet_widget.dart';
import 'lesson_empty_screen.dart';

class ChatAulaScreen extends StatefulWidget {
  const ChatAulaScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<ChatAulaScreen> createState() => _ChatAulaScreenState();
}

class _ChatAulaScreenState extends State<ChatAulaScreen>
    with WidgetsBindingObserver {
  final ChatConversationStore _conversationStore =
      const ChatConversationStore();
  final TextEditingController _doubtController = TextEditingController();
  final List<ChatLessonMessage> _conversationMessages = <ChatLessonMessage>[];
  final Set<String> _restoredConversationKeys = <String>{};
  final Set<String> _restoringConversationKeys = <String>{};
  String? _conversationLessonKey;
  int _conversationArchiveSeq = 0;
  int _fontScaleLevel = ClassroomTextScale.defaultLevel;
  bool _doubtSheetOpen = false;
  final Set<String> _pendingConversationActions = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(_onSessionChange);
    unawaited(_loadFontScaleLevel());
  }

  Future<void> _loadFontScaleLevel() async {
    final level = await _conversationStore.loadFontScaleLevel();
    if (!mounted) return;
    setState(() => _fontScaleLevel = level);
  }

  Future<void> _cycleFontScaleLevel() async {
    final next = ClassroomTextScale.next(_fontScaleLevel);
    setState(() => _fontScaleLevel = next);
    await _conversationStore.saveFontScaleLevel(next);
  }

  void _onSessionChange() {
    final open = widget.session.doubtOpen;
    if (open && !_doubtSheetOpen) {
      _doubtSheetOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showDoubtSheet());
    }
    if (mounted) setState(() {});
  }

  void _ensureConversationRestored(LabSession session) {
    final key = _conversationKeyFor(session);
    if (_restoredConversationKeys.contains(key) ||
        _restoringConversationKeys.contains(key)) {
      return;
    }
    _restoringConversationKeys.add(key);
    unawaited(_restoreConversationSnapshot(key));
  }

  Future<void> _restoreConversationSnapshot(String lessonKey) async {
    try {
      final restored = await _conversationStore.restore(lessonKey);
      if (!mounted) return;
      _restoringConversationKeys.remove(lessonKey);
      _restoredConversationKeys.add(lessonKey);
      if (restored == null) {
        unawaited(_persistConversationSnapshot(lessonKey));
        return;
      }
      setState(() {
        _conversationLessonKey = lessonKey;
        _conversationMessages
          ..clear()
          ..addAll(restored.messages);
        _conversationArchiveSeq = restored.archiveSeq;
      });
    } catch (_) {
      if (!mounted) return;
      _restoringConversationKeys.remove(lessonKey);
      _restoredConversationKeys.add(lessonKey);
    }
  }

  Future<void> _persistConversationSnapshot(String lessonKey) async {
    if (!_restoredConversationKeys.contains(lessonKey)) return;
    await _conversationStore.persist(
      lessonKey: lessonKey,
      archiveSeq: _conversationArchiveSeq,
      messages: _messagesWithDeadPastFeedbackActions()
          .where((message) => !_isEphemeralRuntimeMessage(message))
          .toList(growable: false),
    );
  }

  void _openDoubtSheetFromChat() {
    if (widget.session.doubt.status == DoubtStatus.processing) return;
    if (!widget.session.doubtOpen) widget.session.toggleDoubt();
    if (_doubtSheetOpen) return;
    _doubtSheetOpen = true;
    _showDoubtSheet();
  }

  void _runConversationAction(String key, FutureOr<void> Function() action) {
    setState(() => _pendingConversationActions.add(key));
    Future<void>.sync(action).whenComplete(() {
      if (!mounted) return;
      setState(() => _pendingConversationActions.remove(key));
    });
  }

  void _chooseAnswer(AnswerLetter letter) {
    _runConversationAction('answer', () {
      widget.session.chooseAulaAnswer(letter.name);
    });
  }

  void _submitSignal(int value) {
    _runConversationAction('signal', () {
      return widget.session.submitAulaSignal(value);
    });
  }

  void _openDoubtFromAction() {
    _runConversationAction('doubt', _openDoubtSheetFromChat);
  }

  void _showDoubtSheet() {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DoubtInputSheet(
        controller: _doubtController,
        busy: widget.session.doubt.status == DoubtStatus.processing,
        onSubmit: (draft) {
          if (widget.session.doubtOpen) widget.session.toggleDoubt();
          Navigator.of(context).pop();
          _appendStudentDoubtMessage(draft);
          unawaited(widget.session.submitDoubt(draft));
          _doubtController.clear();
        },
        onClose: () {
          if (widget.session.doubtOpen) widget.session.toggleDoubt();
          _doubtController.clear();
        },
      ),
    ).whenComplete(() {
      _doubtSheetOpen = false;
      if (widget.session.doubtOpen) widget.session.toggleDoubt();
    });
  }

  @override
  void dispose() {
    final key = _conversationLessonKey;
    if (key != null) unawaited(_persistConversationSnapshot(key));
    WidgetsBinding.instance.removeObserver(this);
    widget.session.removeListener(_onSessionChange);
    widget.session.stopActiveAudio(notify: false);
    _doubtController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      final key = _conversationLessonKey;
      if (key != null) unawaited(_persistConversationSnapshot(key));
      widget.session.stopActiveAudio();
    }
  }

  bool _hasLessonImagePanel() {
    final imageData = widget.session.aulaSnapshot?.imagem;
    final hasImage = imageData != null && imageData.trim().isNotEmpty;
    final hasPedagogicalContent = hasValidPedagogicalContent(
      widget.session.aulaSnapshot?.conteudo,
    );
    return hasImage ||
        widget.session.imageError != null ||
        (!hasPedagogicalContent && widget.session.imageStatus == 'loading');
  }

  void _appendStudentDoubtMessage(DoubtInputDraft draft) {
    final image = draft.image;
    final text = draft.cleanText;
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _conversationLessonKey ??= _conversationKeyFor(widget.session);
      _conversationMessages.add(
        ChatLessonMessage(
          id:
              'student-doubt-${now.microsecondsSinceEpoch}-'
              '${_conversationArchiveSeq++}',
          role: ChatLessonMessageRole.student,
          kind: ChatLessonMessageKind.studentDoubt,
          text: text.isEmpty ? null : text,
          imageData: image?.dataUrl,
          mediaName: image?.name,
          mediaType: image?.type,
          mediaSize: image?.size,
          deliveryStatus: ChatLessonDeliveryStatus.sent,
          timestampLabel: timestamp,
        ),
      );
    });
    final key = _conversationLessonKey;
    if (key != null) unawaited(_persistConversationSnapshot(key));
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final snapshot = session.aulaSnapshot;
    _ensureConversationRestored(session);

    if (snapshot?.isDone ?? false) {
      return LessonDoneScreen(session: session);
    }

    if (session.aulaRuntimeError?.contains('sem curriculo') == true ||
        session.aulaRuntimeError?.contains('sem currículo') == true) {
      return LessonNoCurriculumScreen(session: session);
    }

    if (session.recoveryRoom != null) {
      return RecoveryRoomScreen(session: session);
    }
    if (session.amparoRoom != null) {
      return AmparoRoomScreen(session: session);
    }
    if (session.reviewRoom != null) {
      return ReviewRoomScreen(session: session);
    }

    final viewModel = snapshot?.viewModel;
    final palette = SimThemeScope.paletteOf(context);
    final textScale = ClassroomTextScale.scaleForWidth(
      _fontScaleLevel,
      MediaQuery.sizeOf(context).width,
    );
    final snapshotImage = snapshot?.imagem;
    final hasPedagogicalContent = hasValidPedagogicalContent(
      snapshot?.conteudo,
    );
    final chatImageStatus =
        hasPedagogicalContent &&
            (snapshotImage == null || snapshotImage.trim().isEmpty) &&
            session.imageStatus == 'loading'
        ? 'idle'
        : session.imageStatus;
    final messages = _mergeConversationMessages(
      session,
      buildChatLessonMessages(
        ChatLessonTimelineInput(
          snapshot: snapshot,
          runtimeLoading: session.aulaRuntimeLoading,
          runtimeError: session.aulaRuntimeError,
          showImagePanel: _hasLessonImagePanel(),
          imageStatus: chatImageStatus,
          imageError: session.imageError,
          doubtProcessing: session.doubt.status == DoubtStatus.processing,
          doubtProgress: session.doubt.progress,
          doubtResponse: session.doubt.response?.explanation,
          doubtError: session.doubt.error,
          lessonLocalId: session.lessonLocalId,
        ),
      ),
    );
    final width = MediaQuery.sizeOf(context).width;
    final topBarHeight = MediaQuery.paddingOf(context).top + 94;
    final timelinePadding = SimBreakpoints.classroomScrollPadding(
      width,
    ).copyWith(top: SimSpacing.md, bottom: 132);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: palette.background,
      body: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              top: topBarHeight,
              child: ChatAulaTimeline(
                messages: messages,
                session: session,
                padding: timelinePadding,
                pendingActionKeys: _pendingConversationActions,
                initialScrollToCurrent: true,
                initialScrollKey: _conversationKeyFor(session),
                onChooseAnswer: _chooseAnswer,
                onSignal: _submitSignal,
                onRetry: () {},
                onNext: () {},
                onOpenDoubt: _openDoubtFromAction,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: topBarHeight,
                child: AulaTopBar(
                  session: session,
                  showReviewButton: true,
                  progress: viewModel?.progress.toDouble(),
                  headerLabel: viewModel != null
                      ? headerLabelText(viewModel.headerLabel)
                      : null,
                  textScale: textScale,
                  fontScaleLevel: _fontScaleLevel,
                  onFontScaleTap: () => unawaited(_cycleFontScaleLevel()),
                ),
              ),
            ),
            FixedBubble(
              audioEnabled: session.audioEnabled,
              speaking: session.audioPlaying,
              onTap: session.stopActiveAudio,
            ),
          ],
        ),
      ),
    );
  }

  List<ChatLessonMessage> _mergeConversationMessages(
    LabSession session,
    List<ChatLessonMessage> incoming,
  ) {
    final lessonKey = _conversationKeyFor(session);
    if (_conversationLessonKey != lessonKey) {
      _conversationLessonKey = lessonKey;
      _conversationMessages.clear();
      _conversationArchiveSeq = 0;
    }

    for (
      var incomingIndex = 0;
      incomingIndex < incoming.length;
      incomingIndex++
    ) {
      final message = incoming[incomingIndex];
      final index = _conversationMessages.indexWhere(
        (current) => current.id == message.id,
      );
      if (index >= 0) {
        final current = _conversationMessages[index];
        if (_shouldArchiveAsNewTurn(current, message)) {
          _conversationMessages[index] = current.copyWith(
            id: _archivedMessageId(current.id),
            deliveryStatus: ChatLessonDeliveryStatus.read,
            isHistorical: true,
            isActionable: false,
          );
          _conversationMessages.add(message);
          continue;
        }
        _conversationMessages[index] = message;
        continue;
      }
      if (_isDuplicateHistoryMessage(message)) continue;
      _insertConversationMessage(message, incoming, incomingIndex);
    }
    _removeStaleEphemeralMessages(incoming);

    final messages = List<ChatLessonMessage>.unmodifiable(
      _messagesWithDeadPastFeedbackActions(),
    );
    if (_restoredConversationKeys.contains(lessonKey)) {
      unawaited(_persistConversationSnapshot(lessonKey));
    }
    return messages;
  }

  List<ChatLessonMessage> _messagesWithDeadPastFeedbackActions() {
    var activeFeedbackIndex = -1;
    String? latestTurnId;
    for (var i = 0; i < _conversationMessages.length; i++) {
      final message = _conversationMessages[i];
      if (message.kind == ChatLessonMessageKind.explanation) {
        latestTurnId = _turnIdFor(message);
      }
      if (message.kind == ChatLessonMessageKind.feedback &&
          (message.actionKey ?? '').isNotEmpty) {
        activeFeedbackIndex = i;
      }
    }
    if (activeFeedbackIndex < 0 && latestTurnId == null) {
      return _conversationMessages;
    }
    return [
      for (var i = 0; i < _conversationMessages.length; i++)
        if (_conversationMessages[i].kind == ChatLessonMessageKind.feedback &&
            (_conversationMessages[i].actionKey ?? '').isNotEmpty &&
            (i != activeFeedbackIndex ||
                _turnIdFor(_conversationMessages[i]) != latestTurnId))
          _conversationMessages[i].copyWith(
            deliveryStatus: ChatLessonDeliveryStatus.read,
            isHistorical: true,
            isActionable: false,
          )
        else
          _conversationMessages[i],
    ];
  }

  String? _turnIdFor(ChatLessonMessage message) {
    final prefix = switch (message.kind) {
      ChatLessonMessageKind.explanation => 'explanation-',
      ChatLessonMessageKind.feedback => 'feedback-',
      _ => null,
    };
    if (prefix == null || !message.id.startsWith(prefix)) return null;
    return message.id.substring(prefix.length);
  }

  void _insertConversationMessage(
    ChatLessonMessage message,
    List<ChatLessonMessage> incoming,
    int incomingIndex,
  ) {
    for (var i = incomingIndex + 1; i < incoming.length; i++) {
      final nextIncomingId = incoming[i].id;
      final nextCurrentIndex = _conversationMessages.indexWhere(
        (current) => current.id == nextIncomingId,
      );
      if (nextCurrentIndex >= 0) {
        _conversationMessages.insert(nextCurrentIndex, message);
        return;
      }
    }
    _conversationMessages.add(message);
  }

  String _conversationKeyFor(LabSession session) {
    final snapshot = session.aulaSnapshot;
    final localId = session.lessonLocalId;
    if (localId != null && localId.trim().isNotEmpty) return localId.trim();
    final marker = snapshot?.itemMarker;
    if (marker != null && marker.trim().isNotEmpty) return 'marker:$marker';
    return 'route:${session.route}';
  }

  bool _isDuplicateHistoryMessage(ChatLessonMessage message) {
    if (_conversationMessages.isEmpty) return false;
    final text = message.text?.trim();
    return switch (message.kind) {
      ChatLessonMessageKind.historyQuestion =>
        text != null &&
            text.isNotEmpty &&
            _conversationMessages.any(
              (current) =>
                  current.role == ChatLessonMessageRole.sim &&
                  (current.kind == ChatLessonMessageKind.question ||
                      current.kind == ChatLessonMessageKind.historyQuestion) &&
                  current.text?.trim() == text,
            ),
      ChatLessonMessageKind.historyAnswer => _conversationMessages.any(
        (current) =>
            current.role == ChatLessonMessageRole.student &&
            (current.kind == ChatLessonMessageKind.studentAnswer ||
                current.kind == ChatLessonMessageKind.historyAnswer) &&
            current.selectedAnswer == message.selectedAnswer &&
            current.text?.trim() == text,
      ),
      _ => false,
    };
  }

  void _removeStaleEphemeralMessages(List<ChatLessonMessage> incoming) {
    final liveIncomingIds = incoming.map((message) => message.id).toSet();
    _conversationMessages.removeWhere(
      (message) =>
          _isEphemeralRuntimeMessage(message) &&
          !liveIncomingIds.contains(message.id),
    );
  }

  bool _isEphemeralRuntimeMessage(ChatLessonMessage message) {
    if (message.isHistorical) return false;
    return message.kind == ChatLessonMessageKind.loading ||
        message.kind == ChatLessonMessageKind.processing ||
        message.kind == ChatLessonMessageKind.error;
  }

  bool _shouldArchiveAsNewTurn(
    ChatLessonMessage current,
    ChatLessonMessage incoming,
  ) {
    if (current.kind != incoming.kind) return false;
    if (_messageFingerprint(current) == _messageFingerprint(incoming)) {
      return false;
    }
    return switch (incoming.kind) {
      ChatLessonMessageKind.loading ||
      ChatLessonMessageKind.processing ||
      ChatLessonMessageKind.error => true,
      ChatLessonMessageKind.feedback => incoming.id.startsWith('doubt-'),
      _ => false,
    };
  }

  String _archivedMessageId(String id) =>
      '$id#archived-${_conversationArchiveSeq++}';

  String _messageFingerprint(ChatLessonMessage message) {
    return [
      message.kind.name,
      message.text ?? '',
      message.imageData ?? '',
      message.mediaName ?? '',
      message.mediaType ?? '',
      message.mediaSize?.toString() ?? '',
      message.imageStatus,
      message.selectedAnswer?.name ?? '',
      message.selectedSignal?.name ?? '',
      message.isCorrect?.toString() ?? '',
      message.actionKey ?? '',
      message.progress?.toString() ?? '',
      for (final option in message.options)
        '${option.letter.name}:${option.text}:${option.selected}:${option.enabled}',
      for (final signal in message.signals)
        '${signal.value}:${signal.labelKey}:${signal.enabled}',
    ].join('|');
  }
}
