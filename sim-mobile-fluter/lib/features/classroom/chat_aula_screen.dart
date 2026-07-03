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
    final messages = buildChatLessonMessages(
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
}
