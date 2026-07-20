// ignore_for_file: unused_import, unnecessary_import
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/sim_constants.dart';
import '../../sim/classroom/classroom_models.dart';
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
import '../../sim/state/student_learning_state.dart';
import '../../sim/state/student_state_store.dart';
import '../../sim/placement/placement_route_controller.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/sim_theme.dart';
import '../../sim/ui/widgets/cyber_step_shell.dart';
import '../../sim/ui/widgets/sim_preparation_experience.dart';
import '../../sim/auxiliary/aux_room_models.dart';

import '../session/lab_session.dart';
import '../portal/portal_flow.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screens.dart';
import '../onboarding/preparation_and_placement.dart';
import '../classroom/aux_room_screens.dart';
import '../classroom/aula_widgets.dart';
import '../billing/billing_and_simple_pages.dart';
import '../../shared/widgets/shared_widgets.dart';

class PhaseBoundaryScreen extends StatefulWidget {
  const PhaseBoundaryScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<PhaseBoundaryScreen> createState() => _PhaseBoundaryScreenState();
}

class _PhaseBoundaryScreenState extends State<PhaseBoundaryScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_handleSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _launchWhenReady());
  }

  @override
  void dispose() {
    widget.session.removeListener(_handleSessionChanged);
    super.dispose();
  }

  void _handleSessionChanged() {
    if (!mounted) return;
    setState(() {});
    _launchWhenReady();
  }

  void _launchWhenReady() {
    if (!mounted || _started) return;
    if (!widget.session.authReady) return;
    if (!widget.session.authed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.session.authed) return;
        widget.session.goLogin(target: '/cyber/curriculo');
      });
      return;
    }
    _launch();
  }

  void _launch() {
    if (_started) return;
    _started = true;
    unawaited(widget.session.launchExperience());
  }

  String _toSimStage(String status) => switch (status) {
    'pedido_recebido' => 'profile',
    't00_running' => 'curriculum',
    't02_running' => 'lesson',
    'placement' => 'placement',
    'primeira_aula_pronta' => 'done',
    'erro' => 'error',
    _ => 'generic',
  };

  @override
  Widget build(BuildContext context) {
    final status = widget.session.entryStatus;
    final error = widget.session.entryError;
    final publicError = error == null
        ? null
        : humanErrorMessage(error, fallback: t('aula_gen_fail'));
    final authReady = widget.session.authReady;
    final authed = widget.session.authed;
    final isError = status == 'erro';
    final isCredits =
        error?.toLowerCase().contains('crédito') == true ||
        error?.toLowerCase().contains('credit') == true;
    final simStage = _toSimStage(status);
    final isReady = widget.session.canContinueFromPreparationGate;

    return Scaffold(
      backgroundColor: SimThemeScope.paletteOf(context).background,
      body: SafeArea(
        child: isError && authReady && authed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    constraints: const BoxConstraints(maxWidth: 448),
                    decoration: glassDecoration(radius: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t('preparing_failed_title'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: simDark,
                          ),
                        ),
                        if (publicError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            publicError,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: simMuted,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (isCredits)
                          PrimaryWideButton(
                            label: t('aula_buy_credits'),
                            onTap: () => widget.session.openCredits(),
                          )
                        else
                          PrimaryWideButton(
                            label: t('aula_try_again_2'),
                            onTap: () {
                              _started = false;
                              _launch();
                            },
                          ),
                        const SizedBox(height: 12),
                        SimTextAction(
                          label: t('preparing_change_goal'),
                          onPressed: () =>
                              widget.session.openSupport('/cyber/objeto'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    // invisible debug labels
                    Text(
                      widget.session.route,
                      style: const TextStyle(
                        color: Colors.transparent,
                        fontSize: 1,
                      ),
                    ),
                    Text(
                      'entry.status: $status',
                      style: const TextStyle(
                        color: Colors.transparent,
                        fontSize: 1,
                      ),
                    ),
                    Expanded(
                      child: OnboardingChatFlow(
                        semanticLabel: t('onboarding_chat_region'),
                        children: [
                          SimChatReveal(
                            child: SimPreparationExperience(
                              stage: simStage,
                              ready: isReady,
                              onContinue: () => unawaited(
                                widget.session
                                    .continueFromPreparationToWarmup(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class WarmupBridgeScreen extends StatelessWidget {
  const WarmupBridgeScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: SingleChildScrollView(
              child: _WarmupRoomCard(
                lesson: session.warmupLesson,
                selectedAnswer: session.warmupSelectedAnswer,
                waitingForOfficial: session.warmupWaitingForOfficialLesson,
                loading: session.warmupLoading,
                error: session.warmupError,
                onAnswer: session.chooseWarmupAnswer,
                onContinue: session.continueFromWarmupToAula,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WarmupRoomCard extends StatelessWidget {
  const _WarmupRoomCard({
    required this.lesson,
    required this.selectedAnswer,
    required this.waitingForOfficial,
    required this.loading,
    required this.error,
    required this.onAnswer,
    required this.onContinue,
  });

  final SimWarmupLesson? lesson;
  final String? selectedAnswer;
  final bool waitingForOfficial;
  final bool loading;
  final String? error;
  final ValueChanged<String> onAnswer;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final item = lesson;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      constraints: const BoxConstraints(maxWidth: 560),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: item == null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading) ...[
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Preparando uma ponte de boas-vindas...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: simDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'A aula oficial continua sendo preparada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'A ponte de boas-vindas ainda não chegou.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: simDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (error?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(
                    'A aula principal continua sendo preparada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Boas-vindas enquanto preparo sua aula',
                  style: TextStyle(
                    color: simDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.explanation,
                  style: const TextStyle(
                    color: simDark,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  item.question,
                  style: const TextStyle(
                    color: simDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                for (final entry in item.options.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _WarmupOptionButton(
                      letter: entry.key,
                      text: entry.value,
                      selected: selectedAnswer == entry.key,
                      correct: item.correctAnswer == entry.key,
                      answered: selectedAnswer != null,
                      onTap: () => onAnswer(entry.key),
                    ),
                  ),
                if (selectedAnswer != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    selectedAnswer == item.correctAnswer
                        ? (item.whyCorrect?.trim().isNotEmpty == true
                              ? item.whyCorrect!.trim()
                              : 'Certo. A aula principal continua sendo preparada.')
                        : (item.whyWrong[selectedAnswer]?.trim().isNotEmpty ==
                                  true
                              ? item.whyWrong[selectedAnswer]!.trim()
                              : 'Boa tentativa. A aula principal vai explicar melhor.'),
                    style: TextStyle(
                      color: selectedAnswer == item.correctAnswer
                          ? const Color(0xFF047857)
                          : const Color(0xFFB45309),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: waitingForOfficial ? null : onContinue,
                    icon: waitingForOfficial
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(
                      waitingForOfficial
                          ? 'Preparando a aula oficial...'
                          : 'Continuar para a aula',
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _WarmupOptionButton extends StatelessWidget {
  const _WarmupOptionButton({
    required this.letter,
    required this.text,
    required this.selected,
    required this.correct,
    required this.answered,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final bool correct;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = answered && correct
        ? const Color(0xFF10B981)
        : selected
        ? const Color(0xFF111827)
        : const Color(0xFFD1D5DB);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: answered ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF3F4F6) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                letter,
                style: const TextStyle(
                  color: simDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: simDark,
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlacementLabScreen extends StatefulWidget {
  const PlacementLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<PlacementLabScreen> createState() => _PlacementLabScreenState();
}

// NV-1..NV-4: Nivelamento 4-step sub-flow inside CyberStepShell
// step 1/4 = Choice, 2/4 = Intro, 3/4 = Question, 4/4 = Result
class _PlacementLabScreenState extends State<PlacementLabScreen> {
  bool _preparing = false;
  bool _redirectingToAula = false;

  PlacementRouteController? get _controller =>
      widget.session.activePlacementController;

  void _goToIntro() {
    widget.session.choosePlacementFindMyPointThenPreparation();
  }

  void _goToQuestion() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _preparing = true);
    await controller.startTest();
    if (mounted) {
      setState(() => _preparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final step = switch (controller?.stage) {
      PlacementLocalStage.intro => 2,
      PlacementLocalStage.running => 3,
      PlacementLocalStage.result => 4,
      PlacementLocalStage.redirectToAula => 4,
      _ => 1,
    };
    return CyberStepShell(step: step, total: 4, child: _buildSubStep());
  }

  Widget _buildSubStep() {
    final controller = _controller;
    if (controller == null) {
      return const Text(
        'Nivelamento não disponível.',
        style: TextStyle(color: simMuted, fontSize: 16),
      );
    }
    switch (controller.stage) {
      case PlacementLocalStage.choice:
        return _PlacementChoice(
          onBeginning: widget.session.skipPlacement,
          onQuick: _goToIntro,
        );
      case PlacementLocalStage.intro:
        return _PlacementIntro(
          onStart: _preparing ? null : _goToQuestion,
          preparing: _preparing,
        );
      case PlacementLocalStage.running:
        return _PlacementQuestion(
          controller: controller,
          onAnswered: (choiceId) {
            widget.session.answerPlacement(choiceId);
            setState(() {});
          },
        );
      case PlacementLocalStage.result:
        return _PlacementResult(
          controller: controller,
          onContinue: widget.session.finishPlacement,
        );
      case PlacementLocalStage.redirectToAula:
        _redirectToAulaAfterFrame();
        return const Center(child: CircularProgressIndicator());
    }
  }

  void _redirectToAulaAfterFrame() {
    if (_redirectingToAula) return;
    _redirectingToAula = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(widget.session.openAulaAfterPlacementIfReady());
    });
  }
}

// NV-1: Choice screen
class _PlacementChoice extends StatelessWidget {
  const _PlacementChoice({required this.onBeginning, required this.onQuick});
  final VoidCallback onBeginning;
  final VoidCallback onQuick;

  @override
  Widget build(BuildContext context) {
    return OnboardingChatFlow(
      semanticLabel: t('onboarding_chat_region'),
      scrollable: false,
      children: [
        SimChatBubble(
          text: t('placement_choice_h1'),
          supportingText: t('placement_choice_body'),
        ),
        SimChatChoiceWrap(
          children: [
            SimChatChoiceChip(
              label: t('placement_start_beginning'),
              selected: false,
              onTap: onBeginning,
            ),
            SimChatChoiceChip(
              label: t('placement_take_quick'),
              selected: false,
              onTap: onQuick,
            ),
          ],
        ),
      ],
    );
  }
}

// NV-2: Intro screen
class _PlacementIntro extends StatelessWidget {
  const _PlacementIntro({required this.onStart, required this.preparing});
  final VoidCallback? onStart;
  final bool preparing;

  @override
  Widget build(BuildContext context) {
    return OnboardingChatFlow(
      semanticLabel: t('onboarding_chat_region'),
      scrollable: false,
      children: [
        SimChatBubble(
          text: t('placement_intro_h1'),
          supportingText: t('placement_intro_body'),
        ),
        FilledButton.icon(
          onPressed: onStart,
          icon: preparing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(
            preparing ? t('placement_preparing') : t('placement_start'),
          ),
        ),
      ],
    );
  }
}

// NV-3: Question screen
class _PlacementQuestion extends StatelessWidget {
  const _PlacementQuestion({
    required this.controller,
    required this.onAnswered,
  });

  final PlacementRouteController controller;
  final ValueChanged<String> onAnswered;

  @override
  Widget build(BuildContext context) {
    final screen = controller.questionScreen();
    if (screen == null) {
      return OnboardingChatFlow(
        semanticLabel: t('onboarding_chat_region'),
        scrollable: false,
        children: [
          SimChatBubble(
            text: t('placement_waiting_h1'),
            supportingText: t('placement_waiting_body'),
          ),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    return OnboardingChatFlow(
      semanticLabel: t('onboarding_chat_region'),
      scrollable: false,
      children: [
        SimChatBubble(
          text: screen.prompt,
          supportingText: t('placement_question_of', {
            'n': '${controller.index + 1}',
            'total': '${controller.blocks.length}',
          }),
        ),
        SimChatChoiceWrap(
          children: [
            for (final entry
                in controller.blocks[controller.index].choices.asMap().entries)
              SimChatChoiceChip(
                label:
                    '${String.fromCharCode(65 + entry.key)}. ${t(entry.value.label)}',
                selected: false,
                onTap: () => onAnswered(entry.value.id),
              ),
          ],
        ),
      ],
    );
  }
}

// NV-4: Result screen
class _PlacementResult extends StatelessWidget {
  const _PlacementResult({required this.controller, required this.onContinue});

  final PlacementRouteController controller;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return OnboardingChatFlow(
      semanticLabel: t('onboarding_chat_region'),
      scrollable: false,
      children: [
        SimChatBubble(
          text: t('placement_result_h1'),
          supportingText: t('placement_result_body'),
        ),
        FilledButton.icon(
          onPressed: onContinue,
          icon: const Icon(Icons.arrow_forward),
          label: Text(t('continue')),
        ),
      ],
    );
  }
}

// Loading card copy â€” mirrors entryLoadingCopy() in LessonMainScreen.tsx
(String, String) loadingCopy(String status) => switch (status) {
  'pedido_recebido' => (
    'Recebi seu pedido.',
    'A sala já abriu. Estou começando a entender seu objetivo.',
  ),
  't00_running' => (
    'Entendendo seu objetivo...',
    'Estou montando seu perfil e procurando o primeiro tema.',
  ),
  'first_item_ready' => (
    'Primeiro tema encontrado.',
    'Já tenho o ponto inicial. Agora vou preparar a primeira explicação.',
  ),
  't02_running' || 't02_first_lesson_running' => (
    'Preparando sua primeira aula...',
    'O professor já recebeu o primeiro tema e está escrevendo a explicação.',
  ),
  'primeira_aula_pronta' || 'first_lesson_ready' => (
    'A primeira aula chegou.',
    'Estou abrindo o material.',
  ),
  'failed_t00' => (
    'Não consegui entender o objetivo.',
    'Tente novamente com uma descrição um pouco mais direta do que deseja estudar.',
  ),
  'failed_t02' => (
    'Não consegui preparar a aula.',
    'Tente novamente. Se persistir, o servidor pode estar temporariamente indisponível.',
  ),
  'blocked_credits' => (
    'Créditos insuficientes.',
    'Adicione créditos para gerar a próxima aula real.',
  ),
  _ => (
    t('preparing_lesson'),
    'A sala já abriu. Estou buscando a explicação do primeiro tema.',
  ),
};

String feedbackText(String key) => switch (key) {
  'aula_fb_correct' ||
  'aula_fb_correct_rev' ||
  'aula_fb_correct_dont_know' ||
  'aula_fb_wrong_confident' ||
  'aula_fb_wrong_uncertain' ||
  'aula_fb_wrong_dont_know' ||
  'aula_fb_dont_know' ||
  'aula_fb_redo' ||
  'aula_fb_review_none' ||
  'aula_fb_review_light' ||
  'aula_fb_review_heavy' => t(key),
  _ => key,
};

String nextBtnText(String key) => switch (key) {
  'aula_next' => t('aula_next'),
  'aula_next_item' => t('aula_next_item'),
  'aula_consolidate' => t('aula_consolidate'),
  'aula_layer_label_2' => t('aula_next_layer'),
  'aula_layer_label_3' => t('aula_final_layer'),
  _ => t('aula_advance'),
};

String headerLabelText(String key) {
  if (key.startsWith('aula_item_of:')) {
    final rest = key.substring('aula_item_of:'.length);
    final parts = rest.split(':');
    final fraction = parts.isNotEmpty ? parts[0] : '';
    final layerKey = parts.length > 1 ? parts[1] : '';
    final layer = switch (layerKey) {
      'aula_layer_1' => 'Camada 1/3',
      'aula_layer_2' => 'Camada 2/3',
      'aula_layer_3' => 'Camada 3/3',
      _ => layerKey,
    };
    final normalizedFraction = fraction.replaceFirst('/', ' / ');
    return 'Item $normalizedFraction · $layer';
  }
  if (key.startsWith('aula_review_review:')) return 'Revisão';
  return key;
}
