import 'dart:async';

import 'package:flutter/material.dart';

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

class ChatAulaScreen extends StatefulWidget {
  const ChatAulaScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<ChatAulaScreen> createState() => _ChatAulaScreenState();
}

class _ChatAulaScreenState extends State<ChatAulaScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(_onSessionChange);
  }

  void _onSessionChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.session.removeListener(_onSessionChange);
    widget.session.stopActiveAudio(notify: false);
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
      ClassroomTextScale.defaultLevel,
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
        doubtResponse: session.doubt.response?.explanation,
        doubtError: session.doubt.error,
      ),
    );

    return Scaffold(
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
