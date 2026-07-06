// ignore_for_file: unused_import, unnecessary_import
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../sim/billing/sim_pricing.dart';
import '../../sim/billing/sim_server_billing_clients.dart';
import '../../sim/cloud/sim_server_cloud_functions.dart';
import '../../sim/cloud/supabase_flutter_session_provider.dart';
import '../../sim/cloud/supabase_student_state_cloud_storage.dart';
import '../../sim/config/sim_environment.dart';
import '../../sim/external_ai/sim_ai_server_config.dart';
import '../../sim/external_ai/sim_server_ai_clients.dart';
import '../../sim/external_ai/sim_server_attachment_client.dart';
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
import '../../sim/media/lesson_visual_models.dart';
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

class AulaTopBar extends StatelessWidget {
  const AulaTopBar({
    required this.session,
    this.showReviewButton = false,
    this.progress,
    this.headerLabel,
    this.textScale = 1,
    this.fontScaleLevel,
    this.onFontScaleTap,
    super.key,
  });

  final LabSession session;
  final bool showReviewButton;
  final double? progress;
  final String? headerLabel;
  final double textScale;
  final int? fontScaleLevel;
  final VoidCallback? onFontScaleTap;

  @override
  Widget build(BuildContext context) {
    final fill = ((progress ?? 0) / 100).clamp(0.0, 1.0);
    final palette = SimThemeScope.paletteOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final compactTopBar = !SimBreakpoints.isTablet(width);
        final veryCompactTopBar = width < 360;
        final iconTouchSize = SimTouch.min;
        final edgeGap = veryCompactTopBar
            ? 2.0
            : compactTopBar
            ? 4.0
            : 10.0;
        final actionGap = veryCompactTopBar
            ? 2.0
            : compactTopBar
            ? 4.0
            : 6.0;
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                veryCompactTopBar
                    ? 4
                    : compactTopBar
                    ? 6
                    : 12,
                0,
                veryCompactTopBar
                    ? 4
                    : compactTopBar
                    ? 6
                    : 12,
                12,
              ),
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.96),
                border: Border(
                  bottom: BorderSide(color: palette.border, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 12,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      _HamburgerBtn(
                        onTap: () => showAulaMenu(
                          context,
                          session,
                          textScale: textScale,
                        ),
                        size: iconTouchSize,
                      ),
                      SizedBox(width: edgeGap),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final badgeMaxWidth = constraints.maxWidth.clamp(
                              0.0,
                              compactTopBar ? 92.0 : 220.0,
                            );
                            final showBadge =
                                !veryCompactTopBar && badgeMaxWidth >= 64;
                            return Stack(
                              fit: StackFit.expand,
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        height: 3,
                                        color: palette.border.withValues(
                                          alpha: 0.35,
                                        ),
                                        alignment: Alignment.centerLeft,
                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween<double>(
                                            begin: 0,
                                            end: fill,
                                          ),
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeOut,
                                          builder: (context, value, child) {
                                            return FractionallySizedBox(
                                              widthFactor: value,
                                              alignment: Alignment.centerLeft,
                                              child: child,
                                            );
                                          },
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              gradient: simGradientPrimary,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Color(0x2E111827),
                                                  blurRadius: 10,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (showBadge)
                                  Positioned.fill(
                                    child: Center(
                                      child: SizedBox(
                                        width: badgeMaxWidth,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: palette.surface,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: palette.border,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: palette.shadow,
                                                blurRadius: 8,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              (headerLabel ??
                                                      (session.stableLang ??
                                                          'SIM'))
                                                  .toUpperCase(),
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontFamily: kMono,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: palette.text,
                                                letterSpacing: 0.14 * 10,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(width: compactTopBar ? 5 : 8),
                      _HeaderIconCard(
                        icon: session.audioLoading
                            ? Icons.hourglass_empty
                            : session.audioPlaying
                            ? Icons.stop
                            : Icons.volume_up,
                        color: session.audioEnabled
                            ? palette.text
                            : palette.muted,
                        semanticLabel: session.audioLoading
                            ? 'Preparando áudio da aula'
                            : session.audioPlaying
                            ? 'Parar áudio da aula'
                            : 'Tocar áudio da aula',
                        onTap: session.toggleAudio,
                        size: iconTouchSize,
                      ),
                      SizedBox(width: actionGap),
                      _DarkModeToggleBtn(size: iconTouchSize),
                      if (!veryCompactTopBar &&
                          fontScaleLevel != null &&
                          onFontScaleTap != null) ...[
                        SizedBox(width: actionGap),
                        _HeaderFontScaleBtn(
                          level: fontScaleLevel!,
                          onTap: onFontScaleTap!,
                          size: iconTouchSize,
                        ),
                      ],
                      if (showReviewButton) ...[
                        SizedBox(width: actionGap),
                        Semantics(
                          button: true,
                          excludeSemantics: true,
                          label: 'Abrir revisão',
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(SimRadius.md),
                            child: InkWell(
                              onTap: session.openReviewRoom,
                              borderRadius: BorderRadius.circular(SimRadius.md),
                              child: Container(
                                width: compactTopBar ? iconTouchSize : null,
                                height: iconTouchSize,
                                padding: EdgeInsets.symmetric(
                                  horizontal: compactTopBar ? 0 : 8,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: simGradientPrimary,
                                  borderRadius: BorderRadius.circular(
                                    SimRadius.md,
                                  ),
                                  border: Border.all(color: palette.border),
                                  boxShadow: simShadowGlow,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.menu_book_outlined,
                                      color: palette.text,
                                      size: 14,
                                    ),
                                    if (!compactTopBar) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        t('aux_review_button').toUpperCase(),
                                        style: TextStyle(
                                          fontFamily: kMono,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: palette.text,
                                          letterSpacing: 0.16 * 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderFontScaleBtn extends StatelessWidget {
  const _HeaderFontScaleBtn({
    required this.level,
    required this.onTap,
    required this.size,
  });

  final int level;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Tamanho da letra: nível $level de 5',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(SimRadius.md),
        child: InkWell(
          key: const Key('chat-font-scale-button'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(SimRadius.md),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(SimRadius.md),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.noScaling),
              child: Text(
                '$level/5',
                key: const Key('chat-font-scale-level'),
                style: TextStyle(
                  color: palette.text,
                  fontFamily: kMono,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconCard extends StatelessWidget {
  const _HeaderIconCard({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.semanticLabel,
    this.size = SimTouch.icon,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SimIconAction(
      icon: icon,
      semanticLabel: semanticLabel,
      onPressed: onTap,
      size: size,
      iconSize: 16,
      child: Icon(icon, color: color, size: 16),
    );
  }
}

class _HamburgerBtn extends StatelessWidget {
  const _HamburgerBtn({required this.onTap, required this.size});
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SimAulaMenuButton(onTap: onTap, size: size);
  }
}

class LessonImagePanel extends StatelessWidget {
  const LessonImagePanel({
    required this.session,
    this.onImageSettled,
    super.key,
  });

  final LabSession session;
  final VoidCallback? onImageSettled;

  @override
  Widget build(BuildContext context) {
    final imageData = session.aulaSnapshot?.imagem;
    final loading = session.aulaRuntimeLoading && imageData == null;
    final ready = imageData != null && imageData.trim().isNotEmpty;
    final error = session.imageError;
    final offer = session.hasLessonPaidImageOffer && !loading && !ready;
    final imageCost = simPricing.imageCostCredits;
    final hasImageCredits = session.isUnlimited || session.credits >= imageCost;
    if (!loading && !ready && !offer && error == null) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        final maxReadyHeight = SimBreakpoints.isTablet(size.width)
            ? 320.0
            : 220.0;
        final readyHeight = (size.height * 0.28).clamp(136.0, maxReadyHeight);
        final palette = SimThemeScope.paletteOf(context);
        return Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: loading ? 88 : 0,
            maxHeight: ready ? readyHeight + 104 : double.infinity,
          ),
          padding: EdgeInsets.all(ready ? 10 : 14),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (ready)
                LessonImageStudySurface(
                  data: imageData,
                  height: readyHeight,
                  caption: lessonImageCaption(session),
                  onImageSettled: onImageSettled,
                )
              else if (!loading && !offer)
                const LessonImageErrorView(),
              if (!ready)
                Text(
                  loading
                      ? 'Gerando imagem da aula...'
                      : offer
                      ? t('aula_img_desc')
                      : error ?? 'Imagem indisponível. A aula continua.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (offer) ...[
                const SizedBox(height: 8),
                Text(
                  '${t('aula_img_cost', {'n': imageCost})}'
                  '${session.isUnlimited ? '' : t('aula_img_balance', {'n': session.credits})}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (!hasImageCredits) ...[
                      Expanded(
                        child: FilledButton(
                          onPressed: session.lessonImageOfferLoading
                              ? null
                              : session.buyImageCredits,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            backgroundColor: palette.surfaceSoft,
                            foregroundColor: palette.text,
                            disabledBackgroundColor: palette.surfaceSoft,
                            disabledForegroundColor: palette.muted,
                            side: BorderSide(color: palette.border),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: _ButtonText(t('aula_buy_credits')),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: OutlinedButton(
                        onPressed: session.lessonImageOfferLoading
                            ? null
                            : session.declineLessonPaidImage,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          foregroundColor: palette.text,
                          disabledForegroundColor: palette.muted,
                          side: BorderSide(color: palette.border),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: _ButtonText(
                          hasImageCredits
                              ? t('aula_skip')
                              : t('aula_continue_no_img'),
                        ),
                      ),
                    ),
                    if (hasImageCredits) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: session.lessonImageOfferLoading
                              ? null
                              : session.acceptLessonPaidImage,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            backgroundColor: palette.primary,
                            foregroundColor: palette.onPrimary,
                            disabledBackgroundColor: palette.surfaceSoft,
                            disabledForegroundColor: palette.muted,
                            side: BorderSide(color: palette.border),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: session.lessonImageOfferLoading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: palette.onPrimary,
                                  ),
                                )
                              : _ButtonText(
                                  t('aula_view_img', {'n': imageCost}),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ButtonText extends StatelessWidget {
  const _ButtonText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

String lessonImageCaption(LabSession session) {
  final trigger = session.currentVisualTrigger;
  final topic = trigger?['topic']?.toString().trim();
  final focus = trigger?['highlight_focus']?.toString().trim();
  final elements = trigger?['key_elements'];
  String? firstElement;
  if (elements is List && elements.isNotEmpty) {
    firstElement = elements.first.toString().trim();
  }
  String? base;
  if (focus != null && focus.isNotEmpty) {
    base = focus;
  } else if (topic != null && topic.isNotEmpty) {
    base = topic;
  } else if (firstElement != null && firstElement.isNotEmpty) {
    base = firstElement;
  }
  if (base == null || base.isEmpty) return 'Apoio visual da aula';
  final clean = base.replaceAll(RegExp(r'\s+'), ' ');
  if (clean.length <= 92) return clean;
  return '${clean.substring(0, 89).trimRight()}...';
}

class LessonImageStudySurface extends StatelessWidget {
  const LessonImageStudySurface({
    required this.data,
    required this.height,
    required this.caption,
    this.onImageSettled,
    super.key,
  });

  final String data;
  final double height;
  final String caption;
  final VoidCallback? onImageSettled;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      container: true,
      label: t('aula_image_alt'),
      image: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(SimRadius.md),
            child: ColoredBox(
              color: palette.surfaceSoft,
              child: SizedBox(
                height: height,
                width: double.infinity,
                child: LessonMediaImageView(
                  data: data,
                  onImageSettled: onImageSettled,
                ),
              ),
            ),
          ),
          const SizedBox(height: SimSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: SimSpacing.xs),
              Semantics(
                container: true,
                button: true,
                label: 'Ampliar imagem da aula',
                child: IconButton(
                  tooltip: 'Ampliar imagem',
                  onPressed: () => showLessonImageInspector(
                    context,
                    data: data,
                    caption: caption,
                  ),
                  icon: const Icon(Icons.open_in_full_rounded),
                  color: palette.text,
                  style: IconButton.styleFrom(
                    backgroundColor: palette.surfaceSoft,
                    side: BorderSide(color: palette.border),
                    minimumSize: const Size(SimTouch.icon, SimTouch.icon),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showLessonImageInspector(
  BuildContext context, {
  required String data,
  required String caption,
}) {
  final palette = SimThemeScope.paletteOf(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog.fullscreen(
        backgroundColor: palette.background,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Apoio visual',
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar imagem',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: palette.text,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(SimRadius.lg),
                      border: Border.all(color: palette.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(SimRadius.lg),
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 5,
                        child: Center(child: LessonMediaImageView(data: data)),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class LessonMediaImageView extends StatefulWidget {
  const LessonMediaImageView({
    required this.data,
    this.compact = false,
    this.onImageSettled,
    super.key,
  });

  final String data;
  final bool compact;
  final VoidCallback? onImageSettled;

  @override
  State<LessonMediaImageView> createState() => _LessonMediaImageViewState();
}

class _LessonMediaImageViewState extends State<LessonMediaImageView> {
  bool _settled = false;

  @override
  void didUpdateWidget(covariant LessonMediaImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _settled = false;
    }
  }

  void _notifySettled() {
    if (_settled) return;
    _settled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onImageSettled?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = widget.data.trim();
    if (trimmed.startsWith('data:image/svg+xml')) {
      final svg = _decodeSvgDataUrl(trimmed);
      final translatedSvg = svg == null
          ? null
          : translateLessonSvgForFlutter(svg);
      if (translatedSvg != null) {
        _notifySettled();
        return SvgPicture.string(
          translatedSvg,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            _notifySettled();
            return LessonImageErrorView(compact: widget.compact);
          },
        );
      }
      _notifySettled();
      return LessonImageErrorView(compact: widget.compact);
    }
    if (isUsableRasterImageDataUrl(trimmed)) {
      final comma = trimmed.indexOf(',');
      if (comma > 0 && trimmed.substring(0, comma).contains(';base64')) {
        try {
          return Image.memory(
            base64Decode(trimmed.substring(comma + 1)),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) _notifySettled();
              return child;
            },
            errorBuilder: (context, error, stackTrace) {
              _notifySettled();
              return LessonImageErrorView(compact: widget.compact);
            },
          );
        } catch (_) {
          _notifySettled();
          return LessonImageErrorView(compact: widget.compact);
        }
      }
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) _notifySettled();
          return child;
        },
        errorBuilder: (context, error, stackTrace) {
          _notifySettled();
          return LessonImageErrorView(compact: widget.compact);
        },
      );
    }
    _notifySettled();
    return LessonImageErrorView(compact: widget.compact);
  }

  String? _decodeSvgDataUrl(String raw) {
    final comma = raw.indexOf(',');
    if (comma <= 0) return null;
    final header = raw.substring(0, comma);
    final payload = raw.substring(comma + 1);
    try {
      if (header.contains(';base64')) {
        return utf8.decode(base64Decode(payload));
      }
      return Uri.decodeComponent(payload);
    } catch (_) {
      return null;
    }
  }
}

String? translateLessonSvgForFlutter(String raw) {
  var svg = raw.trim();
  if (svg.isEmpty) return null;
  final start = svg.toLowerCase().indexOf('<svg');
  final end = svg.toLowerCase().lastIndexOf('</svg>');
  if (start < 0 || end <= start) return null;
  svg = svg.substring(start, end + '</svg>'.length);
  svg = svg
      .replaceAll(RegExp(r'<\?xml[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<!doctype[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
      .replaceAll(
        RegExp(r'<script\b.*?</script>', caseSensitive: false, dotAll: true),
        '',
      )
      .replaceAll(
        RegExp(
          r'<foreignObject\b.*?</foreignObject>',
          caseSensitive: false,
          dotAll: true,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'<animate(?:Transform|Motion)?\b.*?</animate(?:Transform|Motion)?>',
          caseSensitive: false,
          dotAll: true,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'''\s(?:on[a-z]+|filter|mask|clip-path)=("[^"]*"|'[^']*'|[^\s>]+)''',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'''\s(?:href|xlink:href)=("[^"]*javascript:[^"]*"|'[^']*javascript:[^']*'|[^\s>]*javascript:[^\s>]*)''',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'currentColor', caseSensitive: false), '#111827')
      .replaceAll(RegExp(r'var\([^)]+\)', caseSensitive: false), '#111827');

  svg = _inlineSvgStyleBlocks(svg);
  svg = _inlineSvgStyleAttributes(svg);
  svg = _ensureSvgViewport(svg);

  if (!_hasVisibleSvgContent(svg)) return null;
  return svg;
}

String _inlineSvgStyleBlocks(String svg) {
  final classStyles = <String, Map<String, String>>{};
  final styleBlock = RegExp(
    r'<style\b[^>]*>(.*?)</style>',
    caseSensitive: false,
    dotAll: true,
  );
  for (final block in styleBlock.allMatches(svg)) {
    final css = block.group(1) ?? '';
    final rule = RegExp(r'\.([a-zA-Z0-9_-]+)\s*\{([^}]*)\}');
    for (final match in rule.allMatches(css)) {
      final className = match.group(1);
      if (className == null) continue;
      final attrs = _parseCssDeclarations(match.group(2) ?? '');
      if (attrs.isNotEmpty) classStyles[className] = attrs;
    }
  }
  svg = svg.replaceAll(styleBlock, '');
  if (classStyles.isEmpty) return svg;
  return svg.replaceAllMapped(RegExp(r'<([a-zA-Z][\w:-]*)([^>]*)>'), (match) {
    final tag = match.group(1) ?? '';
    var attrs = match.group(2) ?? '';
    final classAttr = RegExp(
      r'''\sclass=("([^"]*)"|'([^']*)')''',
      caseSensitive: false,
    ).firstMatch(attrs);
    final classes = (classAttr?.group(2) ?? classAttr?.group(3) ?? '')
        .split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty);
    for (final className in classes) {
      final style = classStyles[className];
      if (style == null) continue;
      attrs = _appendMissingSvgAttributes(attrs, style);
    }
    return '<$tag$attrs>';
  });
}

String _inlineSvgStyleAttributes(String svg) {
  return svg.replaceAllMapped(RegExp(r'<([a-zA-Z][\w:-]*)([^>]*)>'), (match) {
    final tag = match.group(1) ?? '';
    var attrs = match.group(2) ?? '';
    final style = RegExp(
      r'''\sstyle=("([^"]*)"|'([^']*)')''',
      caseSensitive: false,
    ).firstMatch(attrs);
    if (style == null) return match.group(0) ?? '';
    attrs = attrs.replaceFirst(style.group(0) ?? '', '');
    attrs = _appendMissingSvgAttributes(
      attrs,
      _parseCssDeclarations(style.group(2) ?? style.group(3) ?? ''),
    );
    return '<$tag$attrs>';
  });
}

Map<String, String> _parseCssDeclarations(String raw) {
  const allowed = {
    'fill',
    'stroke',
    'stroke-width',
    'stroke-linecap',
    'stroke-linejoin',
    'opacity',
    'fill-opacity',
    'stroke-opacity',
    'font-size',
    'font-weight',
    'font-family',
    'text-anchor',
  };
  final attrs = <String, String>{};
  for (final declaration in raw.split(';')) {
    final index = declaration.indexOf(':');
    if (index <= 0) continue;
    final name = declaration.substring(0, index).trim().toLowerCase();
    if (!allowed.contains(name)) continue;
    final value = declaration
        .substring(index + 1)
        .trim()
        .replaceAll('"', '&quot;');
    if (value.isEmpty) continue;
    attrs[name] = value;
  }
  return attrs;
}

String _appendMissingSvgAttributes(String attrs, Map<String, String> values) {
  var next = attrs;
  for (final entry in values.entries) {
    if (RegExp(
      '\\s${RegExp.escape(entry.key)}=',
      caseSensitive: false,
    ).hasMatch(next)) {
      continue;
    }
    next = '$next ${entry.key}="${entry.value}"';
  }
  return next;
}

String _ensureSvgViewport(String svg) {
  final open = RegExp(r'<svg\b([^>]*)>', caseSensitive: false).firstMatch(svg);
  if (open == null) return svg;
  var attrs = open.group(1) ?? '';
  if (!RegExp(r'\sxmlns=', caseSensitive: false).hasMatch(attrs)) {
    attrs = '$attrs xmlns="http://www.w3.org/2000/svg"';
  }
  if (!RegExp(r'\sviewBox=', caseSensitive: false).hasMatch(attrs)) {
    final width = _svgNumericAttribute(attrs, 'width') ?? 900;
    final height = _svgNumericAttribute(attrs, 'height') ?? 560;
    attrs = '$attrs viewBox="0 0 $width $height"';
  }
  return svg.replaceRange(open.start, open.end, '<svg$attrs>');
}

num? _svgNumericAttribute(String attrs, String name) {
  final match = RegExp(
    '\\s${RegExp.escape(name)}=("|\')?([0-9]+(?:\\.[0-9]+)?)',
    caseSensitive: false,
  ).firstMatch(attrs);
  return num.tryParse(match?.group(2) ?? '');
}

bool _hasVisibleSvgContent(String svg) {
  final elements = RegExp(
    r'<(path|circle|ellipse|line|polygon|polyline|text|rect)\b([^>]*)>',
    caseSensitive: false,
  ).allMatches(svg);
  for (final element in elements) {
    final tag = element.group(1)?.toLowerCase();
    final attrs = element.group(2) ?? '';
    if (tag == 'rect' && _rectLooksLikeOnlyCanvas(attrs)) continue;
    if (_svgElementLooksVisible(attrs)) return true;
  }
  return false;
}

bool _rectLooksLikeOnlyCanvas(String attrs) {
  final fill = _svgColorAttribute(attrs, 'fill');
  final stroke = _svgColorAttribute(attrs, 'stroke');
  final x = _svgNumericAttribute(attrs, 'x') ?? 0;
  final y = _svgNumericAttribute(attrs, 'y') ?? 0;
  final width = _svgNumericAttribute(attrs, 'width') ?? 0;
  final height = _svgNumericAttribute(attrs, 'height') ?? 0;
  return x == 0 &&
      y == 0 &&
      width > 0 &&
      height > 0 &&
      _svgColorIsInvisibleOnWhite(fill) &&
      (stroke == null || _svgColorIsInvisibleOnWhite(stroke));
}

bool _svgElementLooksVisible(String attrs) {
  final opacity = _svgOpacity(attrs, 'opacity');
  final fillOpacity = _svgOpacity(attrs, 'fill-opacity');
  final strokeOpacity = _svgOpacity(attrs, 'stroke-opacity');
  if (opacity == 0) return false;
  final fill = _svgColorAttribute(attrs, 'fill');
  final stroke = _svgColorAttribute(attrs, 'stroke');
  final hasVisibleFill =
      fill == null || (fillOpacity != 0 && !_svgColorIsInvisibleOnWhite(fill));
  final hasVisibleStroke =
      stroke != null &&
      strokeOpacity != 0 &&
      !_svgColorIsInvisibleOnWhite(stroke);
  return hasVisibleFill || hasVisibleStroke;
}

String? _svgColorAttribute(String attrs, String name) {
  final match = RegExp(
    '''\\s${RegExp.escape(name)}=("([^"]*)"|'([^']*)')''',
    caseSensitive: false,
  ).firstMatch(attrs);
  return (match?.group(2) ?? match?.group(3))?.trim().toLowerCase();
}

num? _svgOpacity(String attrs, String name) {
  final value = _svgNumericAttribute(attrs, name);
  if (value == null) return null;
  if (value <= 0) return 0;
  return value;
}

bool _svgColorIsInvisibleOnWhite(String? color) {
  if (color == null) return false;
  final value = color.trim().toLowerCase();
  return value == 'none' ||
      value == 'transparent' ||
      value == '#fff' ||
      value == '#ffffff' ||
      value == 'white' ||
      value == 'rgba(255,255,255,0)' ||
      value == 'rgba(255, 255, 255, 0)';
}

class LessonImageErrorView extends StatelessWidget {
  const LessonImageErrorView({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      label: 'Imagem indisponível',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: compact ? 26 : 34,
            color: palette.muted,
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              'Imagem indisponível',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DarkModeToggleBtn extends StatelessWidget {
  const _DarkModeToggleBtn({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final scope = SimThemeScope.of(context);
    final palette = SimThemeScope.paletteOf(context);
    return SimIconAction(
      icon: scope.darkMode
          ? Icons.light_mode_outlined
          : Icons.dark_mode_outlined,
      semanticLabel: scope.darkMode ? 'Modo claro' : 'Modo escuro',
      onPressed: scope.onToggleDarkMode,
      size: size,
      iconSize: 16,
      child: Icon(
        scope.darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: palette.text,
        size: 16,
      ),
    );
  }
}

class StatusLine extends StatelessWidget {
  const StatusLine({
    required this.icon,
    required this.text,
    this.loading = false,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String text;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final row = Row(
      children: [
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.text,
            ),
          )
        else
          Icon(icon, size: 16, color: palette.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: palette.muted, fontSize: 13, height: 1.35),
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SimRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SimSpacing.xs),
          child: row,
        ),
      ),
    );
  }
}
