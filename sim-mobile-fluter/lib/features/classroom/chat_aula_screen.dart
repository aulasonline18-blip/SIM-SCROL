import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../sim/auxiliary/aux_room_models.dart';
import '../../sim/classroom/classroom_text_scale.dart';
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
  final TextEditingController _doubtController = TextEditingController();
  final List<ChatLessonMessage> _conversationMessages = <ChatLessonMessage>[];
  String? _conversationLessonKey;
  int _conversationArchiveSeq = 0;
  int _fontScaleLevel = ClassroomTextScale.defaultLevel;
  bool _doubtSheetOpen = false;

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

  void _openDoubtSheetFromChat() {
    if (widget.session.doubt.status == DoubtStatus.processing) return;
    if (!widget.session.doubtOpen) widget.session.toggleDoubt();
    if (_doubtSheetOpen) return;
    _doubtSheetOpen = true;
    _showDoubtSheet();
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

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final snapshot = session.aulaSnapshot;

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
                onChooseAnswer: (letter) =>
                    session.chooseAulaAnswer(letter.name),
                onSignal: session.submitAulaSignal,
                onRetry: () => unawaited(session.openAulaRuntime()),
                onNext: () => unawaited(session.advanceAula()),
                onOpenDoubt: _openDoubtSheetFromChat,
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

    for (final message in incoming) {
      final index = _conversationMessages.indexWhere(
        (current) => current.id == message.id,
      );
      if (index >= 0) {
        final current = _conversationMessages[index];
        if (_shouldArchiveAsNewTurn(current, message)) {
          _conversationMessages[index] = current.copyWith(
            id: _archivedMessageId(current.id),
          );
          _conversationMessages.add(message);
          continue;
        }
        _conversationMessages[index] = message;
        continue;
      }
      if (_isDuplicateHistoryMessage(message)) continue;
      _conversationMessages.add(message);
    }

    return List.unmodifiable(_conversationMessages);
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
