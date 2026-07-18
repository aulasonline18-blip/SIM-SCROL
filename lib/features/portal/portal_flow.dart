// ignore_for_file: unused_import, unnecessary_import
import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
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
import '../../sim/ui/widgets/doubt_progress_bar.dart';

import '../../core/utils/sim_constants.dart';
import '../session/lab_session.dart';
import '../portal/portal_flow.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screens.dart';
import '../onboarding/preparation_and_placement.dart';
import '../classroom/aux_room_screens.dart';
import '../classroom/aula_widgets.dart';
import '../billing/billing_and_simple_pages.dart';
import '../../shared/widgets/shared_widgets.dart';

class SimFrame extends StatelessWidget {
  const SimFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final palette = SimThemeScope.paletteOf(context);
    return ColoredBox(
      color: palette.frame,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: SimBreakpoints.frameMaxWidth(width),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class PortalScreen extends StatelessWidget {
  const PortalScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final displayBalance = session.authed ? session.credits : 0;
    final theme = SimThemeScope.of(context);
    final palette = SimThemeScope.paletteOf(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          const BackgroundDecor(),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        session.authed
                            ? SimAulaMenuButton(
                                onTap: () => showAulaMenu(context, session),
                              )
                            : const SizedBox(width: 38, height: 38),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SimIconAction(
                              icon: theme.darkMode
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              semanticLabel: theme.darkMode
                                  ? t('theme_light')
                                  : t('theme_dark'),
                              onPressed: theme.onToggleDarkMode,
                            ),
                            const SizedBox(width: 8),
                            CreditsPill(
                              value: displayBalance,
                              isUnlimited: session.isUnlimited,
                              onTap: session.openCredits,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    PortalHeroCard(session: session),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: pillDecorationFor(context),
                        child: Text(
                          '1/5',
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 12,
                            fontFamily: kMono,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PortalHeroCard extends StatefulWidget {
  const PortalHeroCard({required this.session, super.key});

  final LabSession session;

  @override
  State<PortalHeroCard> createState() => _PortalHeroCardState();
}

class _PortalHeroCardState extends State<PortalHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  );
  AudioPlayer? _arrivalPlayer;
  bool _playedArrivalTone = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        unawaited(_playArrivalTone());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduceMotion) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    unawaited(_arrivalPlayer?.dispose());
    super.dispose();
  }

  Future<void> _playArrivalTone() async {
    if (_playedArrivalTone || !mounted || !widget.session.audioEnabled) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    _playedArrivalTone = true;
    try {
      final player = AudioPlayer();
      _arrivalPlayer = player;
      await player.setVolume(0.08);
      await player.play(BytesSource(_SimArrivalTone.bytes()));
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await player.dispose();
      if (identical(_arrivalPlayer, player)) _arrivalPlayer = null;
    } catch (_) {
      // Decorative audio must never block the portal or its primary action.
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final curved = Curves.easeOutCubic.transform(_controller.value);
        final scale = lerpDouble(0.16, 1, curved)!;
        final opacity = Curves.easeOut.transform(
          _controller.value.clamp(0.0, 1.0),
        );
        final offset = Offset(
          lerpDouble(-18, 0, curved)!,
          lerpDouble(-10, 0, curved)!,
        );
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: offset,
            child: Transform.scale(
              alignment: Alignment.topLeft,
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
        decoration: glassDecorationFor(context, radius: 44),
        child: Column(
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 152,
                    height: 152,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: palette.border.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  Container(
                    width: 132,
                    height: 132,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: palette.dark ? Colors.white : palette.surface,
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(color: palette.border),
                      boxShadow: [
                        BoxShadow(
                          color: palette.shadow,
                          blurRadius: 30,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/monkey-logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'SIM',
              style: TextStyle(
                color: palette.text,
                fontSize: 68,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.36,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 32,
                  child: Divider(color: palette.primary, thickness: 1),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    t('portal_tagline'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 32,
                  child: Divider(color: palette.primary, thickness: 1),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 34 * 9.5),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${t('portal_statement_p1')} '),
                    TextSpan(
                      text: t('portal_statement_real_learning'),
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: t('portal_statement_p2')),
                    TextSpan(text: '${t('portal_statement_p3')} '),
                    TextSpan(
                      text: t('portal_statement_real_progress'),
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 15.5,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: DecoratedBox(
                decoration: primaryButtonDecorationFor(context, radius: 18),
                child: TextButton(
                  onPressed: widget.session.start,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: palette.dark
                              ? palette.onPrimary
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.border),
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          size: 16,
                          color: palette.dark ? palette.primary : simDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.session.authed
                              ? t('portal_btn_start')
                              : t('portal_btn_signin'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: palette.dark ? palette.onPrimary : simDark,
                          ),
                        ),
                      ),
                    ],
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

class _SimArrivalTone {
  const _SimArrivalTone._();

  static Uint8List? _cache;

  static Uint8List bytes() {
    final cached = _cache;
    if (cached != null) return cached;
    const sampleRate = 22050;
    const durationSeconds = 0.42;
    final sampleCount = (sampleRate * durationSeconds).round();
    final data = Uint8List(44 + sampleCount * 2);
    final bytes = ByteData.sublistView(data);

    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        data[offset + i] = value.codeUnitAt(i);
      }
    }

    writeAscii(0, 'RIFF');
    bytes.setUint32(4, 36 + sampleCount * 2, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    bytes.setUint32(40, sampleCount * 2, Endian.little);

    for (var i = 0; i < sampleCount; i++) {
      final t = i / sampleRate;
      final progress = i / sampleCount;
      final attack = (progress / 0.12).clamp(0.0, 1.0);
      final release = ((1 - progress) / 0.72).clamp(0.0, 1.0);
      final envelope = attack * release * release;
      final tone =
          (math.sin(2 * math.pi * 523.25 * t) * 0.58) +
          (math.sin(2 * math.pi * 659.25 * t) * 0.28) +
          (math.sin(2 * math.pi * 783.99 * t) * 0.14);
      final sample = (tone * envelope * 0.42 * 32767).round();
      bytes.setInt16(44 + (i * 2), sample, Endian.little);
    }
    _cache = data;
    return data;
  }
}

class HelpCard extends StatelessWidget {
  const HelpCard({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: glassDecorationFor(context, radius: 24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: Icon(
                  Icons.favorite_border,
                  color: palette.text,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('portal_help_title'),
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('portal_help_body'),
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 12,
            children: [
              ContactButton(
                asset: 'assets/whatsapp-logo.png',
                label: t('contact_whatsapp'),
                onTap: () => session.openExternalDoor(
                  'https://wa.me/message/RLCYEXAYFUIIA1',
                ),
              ),
              ContactButton(
                asset: 'assets/messenger-logo.png',
                label: t('contact_messenger'),
                onTap: () =>
                    session.openExternalDoor('https://m.me/61557707493807'),
              ),
            ],
          ),
          if (session.externalDoorOpened != null) ...[
            const SizedBox(height: 10),
            Text(
              t('external_door', {'url': session.externalDoorOpened}),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.muted,
                fontSize: 11,
                fontFamily: kMono,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ContactButton extends StatelessWidget {
  const ContactButton({
    required this.asset,
    required this.label,
    required this.onTap,
    super.key,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.surface,
            shape: BoxShape.circle,
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
