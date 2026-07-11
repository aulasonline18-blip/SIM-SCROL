import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../sim/auxiliary/aux_room_models.dart';
import '../../sim/auxiliary/doubt_input_sheet.dart';
import '../../sim/classroom/classroom_text_scale.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/ui/sim_theme.dart';
import '../../sim/ui/widgets/fixed_bubble.dart';
import '../onboarding/preparation_and_placement.dart';
import '../session/lab_session.dart';
import 'aula_screen.dart';
import 'aula_widgets.dart';
import 'chat_aula_messages.dart';
import 'aux_room_screens.dart';
import 'chat_aula_timeline_builder.dart';
import 'chat_aula_widgets.dart';
import 'doubt_input_sheet_widget.dart';

class ChatAulaScreen extends StatefulWidget {
  const ChatAulaScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<ChatAulaScreen> createState() => _ChatAulaScreenState();
}

class _ChatAulaScreenState extends State<ChatAulaScreen>
    with WidgetsBindingObserver {
  static const _conversationSnapshotPrefix = 'sim.chat_aula.conversation.v1.';

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
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fontScaleLevel = ClassroomTextScale.normalize(
        prefs.getInt(ClassroomTextScale.prefsKey) ??
            ClassroomTextScale.defaultLevel,
      );
    });
  }

  Future<void> _cycleFontScaleLevel() async {
    final next = ClassroomTextScale.next(_fontScaleLevel);
    setState(() => _fontScaleLevel = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(ClassroomTextScale.prefsKey, next);
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
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_conversationSnapshotKey(lessonKey));
      if (!mounted) return;
      final restored = _decodeConversationSnapshot(raw);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _conversationSnapshotKey(lessonKey),
      jsonEncode({
        'version': 1,
        'lessonKey': lessonKey,
        'archiveSeq': _conversationArchiveSeq,
        'messages': _messagesWithDeadPastFeedbackActions()
            .map((message) => message.toJson(includeInlineImageData: false))
            .toList(),
      }),
    );
  }

  String _conversationSnapshotKey(String lessonKey) {
    final encoded = base64Url.encode(utf8.encode(lessonKey));
    return '$_conversationSnapshotPrefix$encoded';
  }

  _RestoredConversation? _decodeConversationSnapshot(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final messagesRaw = decoded['messages'];
    if (messagesRaw is! List) return null;
    final messages = messagesRaw
        .map(ChatLessonMessage.fromJson)
        .nonNulls
        .toList(growable: false);
    if (messages.isEmpty) return null;
    final archiveSeq = decoded['archiveSeq'];
    return _RestoredConversation(
      messages: messages,
      archiveSeq: archiveSeq is int ? archiveSeq : messages.length,
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
      widget.session.submitAulaSignal(value);
    });
  }

  void _retryLessonRuntime() {
    _runConversationAction('retry', widget.session.openAulaRuntime);
  }

  void _advanceLesson() {
    _runConversationAction('next', widget.session.advanceAula);
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
    return hasImage ||
        widget.session.imageError != null ||
        widget.session.hasLessonPaidImageOffer ||
        (widget.session.aulaRuntimeLoading && imageData == null);
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

    if (session.reviewRoom != null) {
      return ReviewRoomScreen(session: session);
    }
    if (session.recoveryRoom != null) {
      return RecoveryRoomScreen(session: session);
    }

    final viewModel = snapshot?.viewModel;
    final palette = SimThemeScope.paletteOf(context);
    final textScale = ClassroomTextScale.scaleForWidth(
      _fontScaleLevel,
      MediaQuery.sizeOf(context).width,
    );
    final messages = _mergeConversationMessages(
      session,
      buildChatLessonMessages(
        ChatLessonTimelineInput(
          snapshot: snapshot,
          runtimeLoading: session.aulaRuntimeLoading,
          runtimeError: session.aulaRuntimeError,
          showImagePanel: _hasLessonImagePanel(),
          imageStatus: session.imageStatus,
          imageError: session.imageError,
          hasPaidImageOffer: session.hasLessonPaidImageOffer,
          doubtProcessing: session.doubt.status == DoubtStatus.processing,
          doubtProgress: session.doubt.progress,
          doubtResponse: session.doubt.response?.explanation,
          doubtError: session.doubt.error,
          lessonLocalId: session.lessonLocalId,
        ),
      ),
    );

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
              top: MediaQuery.paddingOf(context).top + 82,
              child: ChatAulaTimeline(
                messages: messages,
                session: session,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
                pendingActionKeys: _pendingConversationActions,
                initialScrollToCurrent: true,
                onChooseAnswer: _chooseAnswer,
                onSignal: _submitSignal,
                onRetry: _retryLessonRuntime,
                onNext: _advanceLesson,
                onOpenDoubt: _openDoubtFromAction,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: MediaQuery.paddingOf(context).top + 82,
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
      message.hasPaidImageOffer,
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

class _RestoredConversation {
  const _RestoredConversation({
    required this.messages,
    required this.archiveSeq,
  });

  final List<ChatLessonMessage> messages;
  final int archiveSeq;
}
