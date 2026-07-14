// ignore_for_file: unused_import, unnecessary_import
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../sim/billing/sim_server_billing_clients.dart';
import '../../sim/cloud/sim_server_cloud_functions.dart';
import '../../sim/cloud/supabase_flutter_session_provider.dart';
import '../../sim/cloud/supabase_student_state_cloud_storage.dart';
import '../../sim/config/sim_environment.dart';
import '../../sim/external_ai/sim_ai_server_config.dart';
import '../../sim/external_ai/sim_server_ai_clients.dart';
import '../../sim/external_ai/sim_server_attachment_client.dart';
import '../../sim/classroom/classroom_models.dart';
import '../../sim/classroom/classroom_text_scale.dart';
import '../../sim/classroom/lesson_runtime_engine.dart';
import '../../sim/classroom/lesson_main_view_model.dart';
import '../../sim/experience/student_experience_types.dart';
import '../../sim/organism/sim_organism.dart';
import '../../sim/organism/sim_organism_provider.dart';
import '../../session/auth_session.dart';
import '../../session/entry_form_state.dart';
import '../../session/lesson_ui_state.dart';
import '../../session/navigation_state.dart';
import '../../sim/lesson/lesson_models.dart';
import '../../sim/media/audio_core.dart';
import '../../sim/media/audio_preference.dart';
import '../../sim/media/lesson_audio_controller.dart';
import '../../sim/media/student_lesson_media_service.dart';
import '../../sim/state/shared_prefs_state_storage.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/state/student_state_store.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/sim_theme.dart';
import '../../sim/ui/widgets/cyber_step_shell.dart';
import '../../sim/ui/widgets/sim_preparation_experience.dart';
import '../../sim/ui/widgets/sim_typewriter.dart';
import '../../sim/auxiliary/aux_room_models.dart';
import '../../sim/auxiliary/doubt_input_sheet.dart';
import '../../sim/ui/widgets/doubt_progress_bar.dart';

import '../../core/utils/sim_constants.dart';
import '../session/lab_session.dart';
import '../portal/portal_flow.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screens.dart';
import '../onboarding/preparation_and_placement.dart';
import '../classroom/aula_screen.dart';
import '../classroom/aux_room_screens.dart';
import '../classroom/aula_widgets.dart';
import '../billing/billing_and_simple_pages.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'chat_aula_timeline_builder.dart';
import 'doubt_input_sheet_widget.dart';

class AulaLabScreen extends StatefulWidget {
  const AulaLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<AulaLabScreen> createState() => _AulaLabScreenState();
}

enum _AulaScrollTarget { image, question, signal, feedback, error }

class _AulaLabScreenState extends State<AulaLabScreen>
    with WidgetsBindingObserver {
  static const _scrollDuration = Duration(milliseconds: 420);

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _doubtController = TextEditingController();
  int _lastHistoryLen = 0;
  bool _lastHasContent = false;
  bool _doubtSheetOpen = false;
  String? _theoryDoneKey;
  String? _questionDoneKey;
  AnswerLetter? _localAnswerSel;
  final bool _localExpanded = false;
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _imageKey = GlobalKey();
  final GlobalKey _questionKey = GlobalKey();
  final GlobalKey _answersKey = GlobalKey();
  final GlobalKey _signalKey = GlobalKey();
  final GlobalKey _feedbackKey = GlobalKey();
  final GlobalKey _errorKey = GlobalKey();
  String? _lastScrollSignature;
  String? _lastMediaPositionSignature;
  int _fontScaleLevel = ClassroomTextScale.defaultLevel;
  bool _userScrollOverride = false;
  bool _forceNextSnapshotScroll = false;
  _AulaScrollTarget? _pendingScrollTarget;
  int _scrollRequestGeneration = 0;
  int _programmaticScrollDepth = 0;
  DateTime? _lastBottomScrollAt;

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
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _scrollForSnapshot(widget.session.aulaSnapshot, force: true);
  }

  void _onSessionChange() {
    final snap = widget.session.aulaSnapshot;
    final history = snap?.history ?? const <QuestionHistoryEntry>[];
    final hasContent = snap?.conteudo != null;
    final imageReady = snap?.imagem != null && snap!.imagem!.trim().isNotEmpty;
    final phase = snap?.phase;
    final mediaPositionSignature = [
      snap?.itemMarker,
      snap?.viewModel?.headerLabel,
    ].join('|');
    if (_lastMediaPositionSignature == null) {
      _lastMediaPositionSignature = mediaPositionSignature;
    } else if (mediaPositionSignature != _lastMediaPositionSignature) {
      _lastMediaPositionSignature = mediaPositionSignature;
      widget.session.stopActiveAudio(notify: false);
    }
    final scrollSignature = [
      history.length,
      hasContent,
      phase?.type.name,
      phase?.letter?.name,
      phase?.message,
      imageReady,
    ].join('|');
    if (history.length != _lastHistoryLen ||
        hasContent != _lastHasContent ||
        scrollSignature != _lastScrollSignature) {
      _lastHistoryLen = history.length;
      _lastHasContent = hasContent;
      _lastScrollSignature = scrollSignature;
      final forceScroll = _forceNextSnapshotScroll || !_userScrollOverride;
      _forceNextSnapshotScroll = false;
      _scrollForSnapshot(snap, force: forceScroll);
    }
    if (mounted) setState(() {});
    final open = widget.session.doubtOpen;
    if (open && !_doubtSheetOpen) {
      _doubtSheetOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showDoubtSheet());
    }
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
    _scrollRequestGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    widget.session.removeListener(_onSessionChange);
    widget.session.stopActiveAudio(notify: false);
    _scrollController.dispose();
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

  void _scrollToBottom() {
    if (_userScrollOverride) return;
    final now = DateTime.now();
    final last = _lastBottomScrollAt;
    if (last != null && now.difference(last).inMilliseconds < 110) return;
    _lastBottomScrollAt = now;
    final requestGeneration = ++_scrollRequestGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (requestGeneration != _scrollRequestGeneration) return;
      if (_userScrollOverride) return;
      if (_scrollController.hasClients) {
        unawaited(
          _runProgrammaticScroll(
            requestGeneration,
            () => _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
            ),
          ),
        );
      }
    });
  }

  void _scrollToTarget(
    GlobalKey targetKey, {
    double alignment = 0.1,
    bool fallbackToBottom = true,
    bool force = false,
    _AulaScrollTarget? target,
  }) {
    if (!force && _userScrollOverride) {
      _markPendingScroll(target);
      return;
    }
    if (force) {
      _userScrollOverride = false;
      _clearPendingScroll();
    }
    final requestGeneration = ++_scrollRequestGeneration;

    Future<void> ensure({int attemptsLeft = 4}) async {
      if (requestGeneration != _scrollRequestGeneration) return;
      if (!force && _userScrollOverride) {
        _markPendingScroll(target);
        return;
      }
      if (!mounted) return;
      final ctx = targetKey.currentContext;
      if (ctx == null) {
        if (attemptsLeft > 0) {
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return;
          await ensure(attemptsLeft: attemptsLeft - 1);
          return;
        }
        if (!fallbackToBottom || !_scrollController.hasClients) return;
        await _runProgrammaticScroll(
          requestGeneration,
          () => _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: _scrollDuration,
            curve: Curves.easeOutCubic,
          ),
        );
        return;
      }
      await _runProgrammaticScroll(
        requestGeneration,
        () => Scrollable.ensureVisible(
          ctx,
          alignment: alignment,
          duration: _scrollDuration,
          curve: Curves.easeOutCubic,
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ensure());
    });
  }

  Future<void> _runProgrammaticScroll(
    int requestGeneration,
    Future<void> Function() action,
  ) async {
    if (!mounted || requestGeneration != _scrollRequestGeneration) return;
    _programmaticScrollDepth += 1;
    try {
      await action();
    } catch (_) {
      // A disposed ScrollPosition can cancel an in-flight animation.
    } finally {
      _programmaticScrollDepth -= 1;
      if (mounted && requestGeneration == _scrollRequestGeneration) {
        if (_isNearBottom()) _clearPendingScroll();
      }
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_programmaticScrollDepth > 0) return false;
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      final scrollingAwayFromBottom = notification.dragDetails!.delta.dy > 0;
      if (scrollingAwayFromBottom) {
        _userScrollOverride = !_isNearBottom();
      } else if (_isNearBottom()) {
        _userScrollOverride = false;
        _clearPendingScroll();
      }
    } else if (notification is ScrollEndNotification && _isNearBottom()) {
      _userScrollOverride = false;
      _clearPendingScroll();
    }
    return false;
  }

  void _scrollForSnapshot(
    LessonRuntimeSnapshot? snapshot, {
    bool force = false,
  }) {
    final phase = snapshot?.phase;
    if (phase?.type == ClassroomPhaseType.concluido) {
      _scrollToTarget(
        _feedbackKey,
        alignment: 0.18,
        force: force,
        target: _AulaScrollTarget.feedback,
      );
      return;
    }
    if (phase?.type == ClassroomPhaseType.erroEngine) {
      _scrollToTarget(
        _errorKey,
        alignment: 0.72,
        force: force,
        target: _AulaScrollTarget.error,
      );
      return;
    }
    if (phase?.type == ClassroomPhaseType.expandida ||
        phase?.type == ClassroomPhaseType.processando) {
      _scrollToTarget(
        _signalKey,
        alignment: 0.72,
        force: force,
        target: _AulaScrollTarget.signal,
      );
      return;
    }
    final imageData = snapshot?.imagem;
    final hasReadyImage = imageData != null && imageData.trim().isNotEmpty;
    if (hasReadyImage && phase?.type == ClassroomPhaseType.lendo) {
      _scrollToTarget(
        _imageKey,
        alignment: 0.18,
        force: force,
        target: _AulaScrollTarget.image,
      );
      return;
    }
    if (snapshot?.conteudo != null) {
      final answersReady =
          widget.session.prefs == null ||
          _questionDoneKey == snapshot!.conteudo!.question;
      _scrollToTarget(
        answersReady ? _answersKey : _questionKey,
        alignment: answersReady ? 0.5 : 0.12,
        force: force,
        target: _AulaScrollTarget.question,
      );
    }
  }

  void _onLessonImageSettled() {
    _scrollToTarget(
      _imageKey,
      alignment: 0.18,
      force: !_userScrollOverride,
      target: _AulaScrollTarget.image,
    );
  }

  void _prepareUserDrivenScroll() {
    _forceNextSnapshotScroll = true;
    _userScrollOverride = false;
    _clearPendingScroll();
  }

  String? _activeLayerLabel(String? headerLabel) {
    if (headerLabel == null) return null;
    final match = RegExp(
      r'aula_(?:layer|review_lbl)_(\d+)',
    ).firstMatch(headerLabel);
    final n = match?.group(1);
    if (n == null || n.isEmpty) return null;
    return t('aula_layer_label').replaceAll('{n}', n);
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    final threshold = (position.viewportDimension * 0.18).clamp(96.0, 220.0);
    return position.extentAfter <= threshold;
  }

  void _markPendingScroll(_AulaScrollTarget? target) {
    if (target == null || _pendingScrollTarget == target) return;
    if (!mounted) {
      _pendingScrollTarget = target;
      return;
    }
    setState(() => _pendingScrollTarget = target);
  }

  void _clearPendingScroll() {
    if (_pendingScrollTarget == null) return;
    if (!mounted) {
      _pendingScrollTarget = null;
      return;
    }
    setState(() => _pendingScrollTarget = null);
  }

  String _pendingScrollLabel(_AulaScrollTarget target) {
    return switch (target) {
      _AulaScrollTarget.image => 'Ver imagem',
      _AulaScrollTarget.question => 'Ir para a pergunta',
      _AulaScrollTarget.signal => 'Ir para os sinais',
      _AulaScrollTarget.feedback => 'Ver feedback',
      _AulaScrollTarget.error => 'Ver erro',
    };
  }

  void _jumpToPendingScroll() {
    final target = _pendingScrollTarget;
    if (target == null) return;
    _scrollForSnapshot(widget.session.aulaSnapshot, force: true);
  }

  bool _hasLessonImagePanel() {
    final imageData = widget.session.aulaSnapshot?.imagem;
    final hasImage = imageData != null && imageData.trim().isNotEmpty;
    return hasImage ||
        widget.session.imageError != null ||
        (widget.session.aulaRuntimeLoading && imageData == null);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final snapshot = session.aulaSnapshot;
    final phase = snapshot?.phase;
    final content = snapshot?.conteudo;
    final history = snapshot?.history ?? const <QuestionHistoryEntry>[];
    final viewModel = snapshot?.viewModel;
    final selected = phase?.letter;
    final isExpanded = phase?.type == ClassroomPhaseType.expandida;
    final isProcessing = phase?.type == ClassroomPhaseType.processando;
    final isCompleted = phase?.type == ClassroomPhaseType.concluido;
    final isEngineError = phase?.type == ClassroomPhaseType.erroEngine;
    final isDone = snapshot?.isDone ?? false;
    final wasCorrect = phase?.wasCorrect;
    final feedbackKey = phase?.message;
    final layerLabel = _activeLayerLabel(viewModel?.headerLabel);
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final palette = SimThemeScope.paletteOf(context);
    final frameWidth = SimBreakpoints.frameMaxWidth(
      screenWidth,
    ).clamp(0.0, screenWidth);
    final learningWidth = SimBreakpoints.learningMaxWidth(screenWidth);
    final horizontalInset = ((frameWidth - learningWidth) / 2).clamp(
      SimBreakpoints.isTablet(screenWidth) ? 28.0 : 16.0,
      160.0,
    );
    final showStudyRail = SimBreakpoints.isWide(screenWidth);
    // Effective answer selection â€” uses local state when runtime has no position
    final effectiveSelected = content != null ? selected : _localAnswerSel;
    final effectiveExpanded = content != null ? isExpanded : _localExpanded;
    // Gate question display until typewriter finishes (visualTheoryReady).
    // _theoryDoneKey is set by SimTypewriter.onDone and cleared to null when a
    // new explanation arrives (SimTypewriter restarts itself via didUpdateWidget,
    // so _theoryDoneKey becomes stale automatically).
    final explanationKey = content?.explanation;
    final theoryReady = session.prefs == null
        ? content != null
        : explanationKey != null && _theoryDoneKey == explanationKey;
    final questionKey = content?.question;
    final questionReady = session.prefs == null
        ? theoryReady
        : theoryReady && questionKey != null && _questionDoneKey == questionKey;
    final textScale = ClassroomTextScale.scaleForWidth(
      _fontScaleLevel,
      screenWidth,
    );
    final bottomScrollPadding =
        media.padding.bottom +
        96 +
        (showStudyRail ? 0 : 56) +
        (session.audioEnabled && session.audioPlaying ? 74 : 0) +
        (_pendingScrollTarget != null ? 72 : 0);
    final pendingTarget = _pendingScrollTarget;
    final aulaBusy = session.aulaRuntimeLoading || isProcessing;
    Widget answerWithSignals(AnswerLetter letter, String label) {
      final isActive = effectiveSelected == letter;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnswerButton(
            label: label,
            text: content?.options[letter] ?? '',
            active: isActive,
            enabled: !aulaBusy,
            onTap: () {
              _prepareUserDrivenScroll();
              session.chooseAulaAnswer(label);
            },
          ),
          if (effectiveExpanded && isActive) ...[
            const SizedBox(height: 4),
            KeyedSubtree(
              key: _signalKey,
              child: _SinalRow(
                busy: aulaBusy,
                onSignal: (value) {
                  _prepareUserDrivenScroll();
                  unawaited(session.submitAulaSignal(value));
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    if (isDone) {
      return LessonDoneScreen(session: session);
    }

    if (session.aulaRuntimeError?.contains('sem curriculo') == true ||
        session.aulaRuntimeError?.contains('sem currículo') == true) {
      return LessonNoCurriculumScreen(session: session);
    }

    // Full-screen review/recovery room overlays
    if (session.reviewRoom != null) {
      return ReviewRoomScreen(session: session);
    }
    if (session.recoveryRoom != null) {
      return RecoveryRoomScreen(session: session);
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Stack(
          children: [
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: ListView(
                  key: const Key('aula-scroll-view'),
                  controller: _scrollController,
                  scrollCacheExtent: const ScrollCacheExtent.pixels(1600),
                  padding: EdgeInsets.fromLTRB(
                    horizontalInset,
                    112,
                    horizontalInset,
                    bottomScrollPadding,
                  ),
                  children: [
                    // Past answered questions â€” dimmed, non-interactive
                    // Sliding window: last 4 entries keep image, older entries show text only
                    Builder(
                      builder: (context) {
                        final imageCutoff = (history.length - 4).clamp(
                          0,
                          history.length,
                        );
                        return Column(
                          children: [
                            for (var i = 0; i < history.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: RepaintBoundary(
                                  child: Opacity(
                                    opacity: 0.6,
                                    child: IgnorePointer(
                                      child: _QuestionHistoryBlock(
                                        entry: history[i],
                                        showImage: i >= imageCutoff,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),

                    // Active content card
                    if (session.aulaRuntimeLoading && content == null) ...[
                      const SizedBox(height: 8),
                      // AUL-3: Loading phase â€” glass-soft card matching LessonMainScreen.tsx
                      Container(
                        constraints: const BoxConstraints(minHeight: 280),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: palette.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F111827),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x1A21B2E9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    t('aula_theory').toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: kMono,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: palette.text,
                                      letterSpacing: 2.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (_) {
                                final copy = loadingCopy(session.entryStatus);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      copy.$1,
                                      style: TextStyle(
                                        color: palette.text,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      copy.$2,
                                      style: TextStyle(
                                        color: palette.muted,
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                height: 8,
                                color: const Color(0x14000000),
                                child: const _PulseBar(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Semantics(
                              button: true,
                              label: t('aula_retry_prepare'),
                              child: Material(
                                color: const Color(0x0F000000),
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  onTap: () =>
                                      unawaited(session.openAulaRuntime()),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: palette.border),
                                    ),
                                    child: Text(
                                      t('aula_try_again_2'),
                                      style: TextStyle(
                                        color: palette.text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Theory card â€” only when content is loaded
                    if (content != null) ...[
                      _RevealOnMount(
                        key: ValueKey(
                          'theory:${snapshot?.itemMarker}:${content.explanation.hashCode}',
                        ),
                        child: SimCard(
                          key: _contentKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (layerLabel != null) ...[
                                _LayerBadge(label: layerLabel),
                                const SizedBox(height: 10),
                              ],
                              _LessonTheoryHeader(
                                unit: viewModel?.itemUnit,
                                marker:
                                    viewModel?.itemMarker ??
                                    snapshot?.itemMarker,
                                title: viewModel?.itemTitle,
                              ),
                              const SizedBox(height: 8),
                              if (session.prefs == null)
                                Text(
                                  content.explanation,
                                  style: TextStyle(
                                    color: palette.text,
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                )
                              else
                                SimTypewriter(
                                  text: content.explanation,
                                  charactersPerTick: 3,
                                  tickDuration: const Duration(
                                    milliseconds: 18,
                                  ),
                                  style: SimTypography.lessonBody.copyWith(
                                    color: palette.text,
                                  ),
                                  cursorColor: palette.text,
                                  onTick: _scrollToBottom,
                                  onDone: () {
                                    setState(
                                      () =>
                                          _theoryDoneKey = content.explanation,
                                    );
                                    _scrollToBottom();
                                  },
                                ),
                              // Doubt: processing â†’ progress bar
                              if (session.doubt.status ==
                                  DoubtStatus.processing) ...[
                                const SizedBox(height: 12),
                                DoubtProgressBar(
                                  progress: session.doubt.progress.toDouble(),
                                  label: t('aula_doubt_processing'),
                                ),
                              ],
                              // Doubt: explaining / error â†’ explanation card
                              if (session.doubt.status ==
                                      DoubtStatus.explaining ||
                                  session.doubt.status ==
                                      DoubtStatus.error) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: palette.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: palette.border),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x59111827),
                                        blurRadius: 30,
                                        spreadRadius: -24,
                                        offset: Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Explicação da sua dúvida',
                                        style: TextStyle(
                                          color: palette.text,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (session.doubt.error != null)
                                        Text(
                                          session.doubt.error!,
                                          style: TextStyle(
                                            color: palette.muted,
                                            fontSize: 14,
                                            height: 1.4,
                                          ),
                                        )
                                      else if (session.doubt.response != null)
                                        Text(
                                          session.doubt.response!.explanation,
                                          style: TextStyle(
                                            color: palette.text,
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (content != null &&
                        theoryReady &&
                        _hasLessonImagePanel()) ...[
                      _RevealOnMount(
                        key: _imageKey,
                        child: SimCard(
                          child: LessonImagePanel(
                            session: session,
                            onImageSettled: _onLessonImageSettled,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (content == null) ...[
                      _RevealOnMount(
                        key: _questionKey,
                        child: SimCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_hasLessonImagePanel()) ...[
                                KeyedSubtree(
                                  key: _imageKey,
                                  child: LessonImagePanel(
                                    session: session,
                                    onImageSettled: _onLessonImageSettled,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Challenge/question block â€” hidden while doubt sheet is open to avoid duplicate B. finders
                    if (!session.doubtOpen &&
                        theoryReady &&
                        content != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: palette.border)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                t('aula_challenge'),
                                style: TextStyle(
                                  fontFamily: kMono,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: palette.muted,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: palette.border)),
                          ],
                        ),
                      ),
                      _RevealOnMount(
                        key: ValueKey(
                          'question:${snapshot?.itemMarker}:${content.question.hashCode}',
                        ),
                        child: SimCard(
                          key: _questionKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (session.prefs == null)
                                Text(
                                  content.question,
                                  style: SimTypography.lessonQuestion.copyWith(
                                    color: palette.text,
                                  ),
                                )
                              else
                                SimTypewriter(
                                  key: ValueKey('question:${content.question}'),
                                  text: content.question,
                                  charactersPerTick: 4,
                                  tickDuration: const Duration(
                                    milliseconds: 16,
                                  ),
                                  style: SimTypography.lessonQuestion.copyWith(
                                    color: palette.text,
                                  ),
                                  cursorColor: palette.text,
                                  onTick: _scrollToBottom,
                                  onDone: () {
                                    setState(
                                      () => _questionDoneKey = content.question,
                                    );
                                    _scrollToTarget(
                                      _answersKey,
                                      alignment: 0.5,
                                      force: !_userScrollOverride,
                                      target: _AulaScrollTarget.question,
                                    );
                                  },
                                ),
                              if (questionReady) ...[
                                const SizedBox(height: 10),
                                _StaggeredAnswerList(
                                  key: _answersKey,
                                  children: [
                                    answerWithSignals(AnswerLetter.A, 'A'),
                                    answerWithSignals(AnswerLetter.B, 'B'),
                                    answerWithSignals(AnswerLetter.C, 'C'),
                                  ],
                                ),
                              ],

                              if (isProcessing) ...[
                                const SizedBox(height: 14),
                                const StatusLine(
                                  icon: Icons.auto_awesome_outlined,
                                  text: 'Registrando...',
                                  loading: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ], // end challenge block
                    if (isCompleted && feedbackKey != null) ...[
                      const SizedBox(height: 10),
                      KeyedSubtree(
                        key: _feedbackKey,
                        child: _FeedbackBox(
                          isCorrect: wasCorrect ?? false,
                          message: feedbackText(feedbackKey),
                          doubtLabel:
                              session.doubt.status == DoubtStatus.processing
                              ? t('aula_doubt_processing')
                              : t('aula_doubt_about_question'),
                          nextLabel: nextBtnText(
                            viewModel?.nextLabel ?? 'aula_next',
                          ),
                          busy: session.doubt.status == DoubtStatus.processing,
                          nextBusy: session.aulaRuntimeLoading,
                          onAskDoubt: () {
                            _prepareUserDrivenScroll();
                            if (!session.aulaRuntimeLoading) {
                              session.toggleDoubt();
                            }
                          },
                          onNext: () {
                            _prepareUserDrivenScroll();
                            unawaited(session.advanceAula());
                          },
                        ),
                      ),
                    ],
                    if (isEngineError) ...[
                      const SizedBox(height: 12),
                      Container(
                        key: _errorKey,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: simWarn),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('aula_gen_fail'),
                              style: const TextStyle(
                                color: simWarn,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (phase?.message != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                studentFacingRuntimeError(phase!.message) ??
                                    t('aula_gen_fail'),
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Semantics(
                              button: true,
                              label: t('aula_retry_prepare'),
                              child: Material(
                                color: palette.text,
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  onTap: () =>
                                      unawaited(session.openAulaRuntime()),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      t('aula_try_again_2'),
                                      style: TextStyle(
                                        color: palette.surface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
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
            if (showStudyRail)
              Positioned(
                top: 132,
                right: (horizontalInset - 84).clamp(16.0, 96.0),
                child: SafeArea(
                  bottom: false,
                  child: _AulaStudyRail(
                    progress: viewModel?.progress.toDouble(),
                    itemLabel: viewModel != null
                        ? headerLabelText(viewModel.headerLabel)
                        : null,
                    fontScaleLevel: _fontScaleLevel,
                    onFontTap: () => unawaited(_cycleFontScaleLevel()),
                  ),
                ),
              )
            else
              Positioned(
                right: 16,
                bottom: 24,
                child: SafeArea(
                  top: false,
                  child: _FontScaleButton(
                    level: _fontScaleLevel,
                    onTap: () => unawaited(_cycleFontScaleLevel()),
                  ),
                ),
              ),
            // FixedBubble â€” fixed bottom-center overlay while audio plays
            if (session.audioEnabled && session.audioPlaying)
              Positioned(
                bottom: 82,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: const IgnorePointer(child: _FixedBubble()),
                  ),
                ),
              ),
            if (pendingTarget != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: media.padding.bottom + (showStudyRail ? 18 : 88),
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: _pendingScrollLabel(pendingTarget),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const Key('aula-scroll-current-button'),
                          onTap: _jumpToPendingScroll,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: SimTouch.min,
                              maxWidth: 260,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: palette.border),
                              boxShadow: [
                                BoxShadow(
                                  color: palette.shadow,
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: palette.text,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _pendingScrollLabel(pendingTarget),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.text,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LessonNoCurriculumScreen extends StatelessWidget {
  const LessonNoCurriculumScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(32),
              decoration: glassDecoration(radius: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t('aula_no_curr_h1'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t('aula_no_curr_body'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  PrimaryWideButton(
                    label: t('aula_back_curr'),
                    onTap: () => session.openSupport('/cyber/objeto'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FontScaleButton extends StatelessWidget {
  const _FontScaleButton({required this.level, required this.onTap});

  final int level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: t('aula_font_scale_label', {'level': level}),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const Key('aula-font-scale-button'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.noScaling),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.text_fields, color: palette.text, size: 18),
                  const SizedBox(height: 1),
                  Text(
                    '$level/5',
                    key: const Key('aula-font-scale-level'),
                    style: TextStyle(
                      color: palette.text,
                      fontFamily: kMono,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AulaStudyRail extends StatelessWidget {
  const _AulaStudyRail({
    required this.fontScaleLevel,
    required this.onFontTap,
    this.progress,
    this.itemLabel,
  });

  final int fontScaleLevel;
  final VoidCallback onFontTap;
  final double? progress;
  final String? itemLabel;

  @override
  Widget build(BuildContext context) {
    final fill = ((progress ?? 0) / 100).clamp(0.0, 1.0);
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      container: true,
      label: t('aula_tools'),
      child: Container(
        key: const Key('aula-study-rail'),
        width: 72,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t('aula_header_short'),
              style: SimTypography.meta.copyWith(fontSize: 9),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 8,
                height: 84,
                color: const Color(0x0F111827),
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: fill,
                  alignment: Alignment.bottomCenter,
                  child: Container(color: palette.text),
                ),
              ),
            ),
            if (itemLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                itemLabel!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.muted,
                  fontFamily: kMono,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _FontScaleButton(level: fontScaleLevel, onTap: onFontTap),
          ],
        ),
      ),
    );
  }
}

class _QuestionHistoryBlock extends StatelessWidget {
  const _QuestionHistoryBlock({required this.entry, required this.showImage});

  final QuestionHistoryEntry entry;
  final bool showImage;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showImage && entry.imageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 120, maxHeight: 80),
              color: palette.surface,
              padding: const EdgeInsets.all(4),
              child: LessonMediaImageView(data: entry.imageUrl!, compact: true),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          entry.text,
          style: TextStyle(
            color: palette.text,
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        for (final opt in entry.options) ...[
          Builder(
            builder: (context) {
              final chosen = opt.id == entry.chosenOptionId;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: palette.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: chosen ? palette.text : palette.border,
                    width: chosen ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: chosen ? palette.text : palette.surfaceSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        opt.id.name.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: chosen ? palette.surface : palette.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        opt.text,
                        style: TextStyle(color: palette.text, fontSize: 15),
                      ),
                    ),
                    if (chosen) ...[
                      const SizedBox(width: 8),
                      Text(
                        entry.correct ? 'ok' : 'x',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                          letterSpacing: 0.18 * 11,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _RevealOnMount extends StatefulWidget {
  const _RevealOnMount({required this.child, super.key});

  final Widget child;

  @override
  State<_RevealOnMount> createState() => _RevealOnMountState();
}

class _RevealOnMountState extends State<_RevealOnMount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final value = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.96 + (0.04 * value),
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - value)),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _LayerBadge extends StatelessWidget {
  const _LayerBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.text,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F111827),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.background,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _LessonTheoryHeader extends StatelessWidget {
  const _LessonTheoryHeader({this.unit, this.marker, this.title});

  final String? unit;
  final String? marker;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final cleanUnit = unit?.trim();
    final cleanMarker = marker?.trim();
    final cleanTitle = title?.trim();
    final identity = [
      if (cleanMarker != null && cleanMarker.isNotEmpty) cleanMarker,
      if (cleanTitle != null && cleanTitle.isNotEmpty) cleanTitle,
    ].join(' · ');
    final hasUnit = cleanUnit != null && cleanUnit.isNotEmpty;
    final top = hasUnit
        ? '${t('aula_theory')} · $cleanUnit'
        : [t('aula_theory'), if (identity.isNotEmpty) identity].join(' · ');
    final bottom = hasUnit ? identity : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          top,
          style: TextStyle(
            fontFamily: kMono,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: palette.muted,
            letterSpacing: 1.2,
          ),
        ),
        if (bottom.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            bottom,
            style: TextStyle(
              color: palette.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}

// AUL-5: FeedbackBox with fade+slide-up animation on appear
class _FeedbackBox extends StatefulWidget {
  const _FeedbackBox({
    required this.isCorrect,
    required this.message,
    required this.doubtLabel,
    required this.nextLabel,
    required this.busy,
    required this.nextBusy,
    required this.onAskDoubt,
    required this.onNext,
  });

  final bool isCorrect;
  final String message;
  final String doubtLabel;
  final String nextLabel;
  final bool busy;
  final bool nextBusy;
  final VoidCallback onAskDoubt;
  final VoidCallback onNext;

  @override
  State<_FeedbackBox> createState() => _FeedbackBoxState();
}

class _FeedbackBoxState extends State<_FeedbackBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final color = widget.isCorrect ? simSuccess : simWarn;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
            boxShadow: [
              BoxShadow(color: color, blurRadius: 0, spreadRadius: 1),
              BoxShadow(
                color: color.withAlpha(100),
                blurRadius: 40,
                spreadRadius: -10,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 300;
              final message = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    widget.isCorrect
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
              final actions = [
                Expanded(
                  child: _FeedbackActionButton(
                    label: widget.doubtLabel,
                    enabled: !widget.busy && !widget.nextBusy,
                    primary: false,
                    onTap: widget.onAskDoubt,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FeedbackActionButton(
                    label: widget.nextLabel,
                    enabled: !widget.nextBusy,
                    primary: true,
                    onTap: widget.onNext,
                  ),
                ),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  message,
                  const SizedBox(height: 14),
                  if (compact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FeedbackActionButton(
                          label: widget.doubtLabel,
                          enabled: !widget.busy && !widget.nextBusy,
                          primary: false,
                          onTap: widget.onAskDoubt,
                        ),
                        const SizedBox(height: 10),
                        _FeedbackActionButton(
                          label: widget.nextLabel,
                          enabled: !widget.nextBusy,
                          primary: true,
                          onTap: widget.onNext,
                        ),
                      ],
                    )
                  else
                    Row(children: actions),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FeedbackActionButton extends StatelessWidget {
  const _FeedbackActionButton({
    required this.label,
    required this.enabled,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final background = primary ? palette.text : palette.surface;
    final foreground = primary ? palette.background : palette.text;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled ? background : palette.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primary ? palette.text : palette.border,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: enabled ? foreground : palette.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaggeredAnswerList extends StatefulWidget {
  const _StaggeredAnswerList({required this.children, super.key});

  final List<Widget> children;

  @override
  State<_StaggeredAnswerList> createState() => _StaggeredAnswerListState();
}

class _StaggeredAnswerListState extends State<_StaggeredAnswerList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(_StaggeredAnswerList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      _controller
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.children,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          AnimatedBuilder(
            animation: _controller,
            child: widget.children[i],
            builder: (context, child) {
              final start = (i * 0.18).clamp(0.0, 0.7);
              final end = (start + 0.42).clamp(start + 0.01, 1.0);
              final value = ((_controller.value - start) / (end - start)).clamp(
                0.0,
                1.0,
              );
              final curved = Curves.easeOutCubic.transform(value);
              return Opacity(
                opacity: curved,
                child: Transform.scale(
                  scale: 0.97 + (0.03 * curved),
                  alignment: Alignment.topLeft,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - curved)),
                    child: child,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// AUL-8: Row of 3 equal signal buttons, mono-18 number, label-11 uppercase
class _SinalRow extends StatelessWidget {
  const _SinalRow({required this.busy, required this.onSignal});
  final bool busy;
  final void Function(int) onSignal;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final labels = [
      (1, t('aula_sig_certeza')),
      (2, t('aula_sig_revisar')),
      (3, t('aula_sig_nao_sei')),
    ];
    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.text, width: 1)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                button: true,
                excludeSemantics: true,
                label: t('signal_option_named', {
                  'value': labels[i].$1,
                  'label': labels[i].$2,
                }),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: busy ? null : () => onSignal(labels[i].$1),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: SimTouch.min,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surfaceSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${labels[i].$1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: kMono,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              labels[i].$2.toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: palette.text,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Loading pulse bar â€” animates w-1/2 pulse, matches loading card bar in LessonMainScreen.tsx
class _PulseBar extends StatefulWidget {
  const _PulseBar();
  @override
  State<_PulseBar> createState() => _PulseBarState();
}

class _PulseBarState extends State<_PulseBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Opacity(
        opacity: _opacity.value,
        child: FractionallySizedBox(
          widthFactor: 0.5,
          alignment: Alignment.centerLeft,
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: palette.text,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class _FixedBubble extends StatefulWidget {
  const _FixedBubble();

  @override
  State<_FixedBubble> createState() => _FixedBubbleState();
}

class _FixedBubbleState extends State<_FixedBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(curved);
    _opacity = Tween<double>(begin: 1.0, end: 0.85).animate(curved);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    Widget bubble({double scale = 1, double opacity = 1, double spread = 0}) {
      return Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
              border: Border.all(color: palette.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow.withAlpha(
                    (0.18 * (1 - spread / 12) * 255).round(),
                  ),
                  blurRadius: 12,
                  spreadRadius: spread,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final child = reducedMotion
        ? bubble()
        : AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => bubble(
              scale: _scale.value,
              opacity: _opacity.value,
              spread: (_controller.value * 12).round().toDouble(),
            ),
          );
    return Semantics(
      label: t('aula_audio_playing'),
      liveRegion: true,
      child: child,
    );
  }
}
