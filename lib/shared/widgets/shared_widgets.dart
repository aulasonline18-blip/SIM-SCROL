// ignore_for_file: unused_import, unnecessary_import
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../sim/billing/sim_server_billing_clients.dart';
import '../../sim/cloud/sim_server_cloud_functions.dart';
import '../../sim/cloud/cloud_functions.dart';
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
import '../../sim/school/aula_drawer_contract.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/sim_theme.dart';
import '../../sim/ui/widgets/cyber_step_shell.dart';
import '../../sim/ui/widgets/sim_preparation_experience.dart';
import '../../sim/ui/widgets/sim_typewriter.dart';
import '../../sim/auxiliary/aux_room_models.dart';
import '../../sim/ui/widgets/doubt_progress_bar.dart';

import '../../core/utils/sim_constants.dart';
import '../../features/session/lab_session.dart';
import '../../features/portal/portal_flow.dart';
import '../../features/auth/login_screen.dart';
import '../../features/onboarding/onboarding_screens.dart';
import '../../features/onboarding/preparation_and_placement.dart';
import '../../features/classroom/aula_screen.dart';
import '../../features/classroom/aux_room_screens.dart';
import '../../features/classroom/aula_widgets.dart';
import '../../features/billing/billing_and_simple_pages.dart';

class PrimaryWideButton extends StatelessWidget {
  const PrimaryWideButton({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SimActionButton(
      label: label,
      onPressed: onTap,
      tone: SimActionTone.primary,
    );
  }
}

class SecondaryWideButton extends StatelessWidget {
  const SecondaryWideButton({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SimActionButton(
      label: label,
      onPressed: onTap,
      tone: SimActionTone.secondary,
      height: 50,
    );
  }
}

class AnswerButton extends StatelessWidget {
  const AnswerButton({
    required this.label,
    required this.text,
    required this.active,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String text;
  final bool active;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _PressScale(
        enabled: enabled,
        child: Semantics(
          button: true,
          enabled: enabled,
          selected: active,
          excludeSemantics: true,
          label: t('answer_option_named', {'label': label}),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(SimRadius.xl),
              child: Opacity(
                opacity: enabled ? 1 : 0.6,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: SimTouch.min),
                  padding: const EdgeInsets.all(SimSpacing.lg),
                  decoration: BoxDecoration(
                    color: palette.surfaceSoft,
                    borderRadius: BorderRadius.circular(SimRadius.xl),
                    border: Border.all(
                      color: active ? palette.primary : palette.border,
                      width: active ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: palette.shadow,
                        blurRadius: 18,
                        spreadRadius: -10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final badge = Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: active ? simGradientPrimary : null,
                          color: active ? null : const Color(0x0DFFFFFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active
                                ? palette.primary
                                : palette.border.withValues(alpha: 0.5),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontFamily: kMono,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: active ? simDark : palette.text,
                          ),
                        ),
                      );
                      final copy = Text(
                        text,
                        style: SimTypography.lessonBody.copyWith(
                          height: 1.35,
                          color: palette.text,
                        ),
                      );
                      if (constraints.maxWidth < 84) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [badge, const SizedBox(height: 10), copy],
                        );
                      }
                      return Row(
                        children: [
                          badge,
                          const SizedBox(width: 16),
                          Expanded(child: copy),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled
          ? (_) => setState(() => _pressed = true)
          : null,
      onPointerUp: widget.enabled
          ? (_) => setState(() => _pressed = false)
          : null,
      onPointerCancel: widget.enabled
          ? (_) => setState(() => _pressed = false)
          : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.99 : 1,
        child: widget.child,
      ),
    );
  }
}

class SimAulaMenuButton extends StatelessWidget {
  const SimAulaMenuButton({
    required this.onTap,
    this.size = 38,
    this.semanticLabel = 'Abrir menu da aula',
    super.key,
  });

  final VoidCallback onTap;
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return SimIconAction(
      icon: Icons.menu,
      semanticLabel: semanticLabel,
      onPressed: onTap,
      size: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            Container(
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                color: palette.text,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow.withValues(alpha: 0.35),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void showAulaMenu(
  BuildContext context,
  LabSession session, {
  double textScale = 1,
}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'menu',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) {
      final sw = MediaQuery.of(ctx).size.width;
      final drawerW = (sw * 0.88).clamp(0.0, 360.0);
      final palette = SimThemeScope.paletteOf(ctx);
      return MediaQuery(
        data: MediaQuery.of(
          ctx,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedBuilder(
            animation: anim1,
            builder: (_, child) => Transform.translate(
              offset: Offset(-drawerW * (1 - anim1.value), 0),
              child: child,
            ),
            child: Material(
              color: palette.surface,
              child: SizedBox(
                width: drawerW,
                height: double.infinity,
                child: SafeArea(
                  child: _AulaDrawerContent(
                    session: session,
                    onClose: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim1, anim2, child) => child,
  );
}

class _AulaDrawerContent extends StatefulWidget {
  const _AulaDrawerContent({required this.session, required this.onClose});
  final LabSession session;
  final VoidCallback onClose;
  @override
  State<_AulaDrawerContent> createState() => _AulaDrawerContentState();
}

class _AulaDrawerContentState extends State<_AulaDrawerContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _renameCtrl = TextEditingController();
  String? _feedback;
  bool _cloudLoading = false;
  List<StudentStateSummaryRow> _cloudLessons = const [];
  int _visibleLessonCount = aulaDrawerInitialVisible;
  String? _renamingLessonId;
  String? _renamingCloudId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _renameCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_refreshCloudLessons());
  }

  void _flash(String msg) {
    setState(() => _feedback = msg);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _feedback = null);
    });
  }

  void _handleNovaAula() {
    widget.onClose();
    widget.session.startNewLessonFromDrawer();
  }

  void _handleOpenCurrentLesson() {
    widget.onClose();
    final id = widget.session.lessonLocalId;
    if (id != null && id.trim().isNotEmpty) {
      widget.session.openSupport('/cyber/aula');
      unawaited(widget.session.openAulaRuntime());
    } else {
      widget.session.startNewLessonFromDrawer();
    }
  }

  void _handleSupportRoute(String route) {
    widget.onClose();
    widget.session.openSupport(route);
  }

  void _handleExternalDoor(String url) {
    widget.onClose();
    widget.session.openExternalDoor(url);
  }

  Future<void> _handleOpenLesson(String lessonLocalId) async {
    final ok = await widget.session.openDrawerLocalLesson(lessonLocalId);
    if (ok) {
      widget.onClose();
      return;
    }
    _flash(t('curriculo_nao_encontrado'));
  }

  Future<void> _refreshCloudLessons() async {
    if (!widget.session.authed) return;
    setState(() => _cloudLoading = true);
    try {
      final rows = await widget.session.listDrawerCloudLessons();
      if (!mounted) return;
      setState(() {
        _cloudLessons = rows;
        _cloudLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cloudLoading = false);
      _flash(t('drawer_import_cloud_failed'));
    }
  }

  Future<void> _handleOpenCloudLesson(StudentStateSummaryRow row) async {
    final ok = await widget.session.openDrawerCloudLesson(row.lessonLocalId);
    if (ok) {
      widget.onClose();
      return;
    }
    _flash(t('curriculo_nao_encontrado'));
  }

  void _startRename(StudentLearningState state) {
    setState(() {
      _renamingLessonId = state.lessonLocalId;
      _renameCtrl.text = _lessonTitle(state);
    });
  }

  void _startRenameCloud(StudentStateSummaryRow row) {
    setState(() {
      _renamingCloudId = row.lessonLocalId;
      _renameCtrl.text = row.tema;
    });
  }

  void _confirmRename() {
    final id = _renamingLessonId;
    if (id == null) return;
    final store = widget.session.canonicalStore;
    if (store == null) return;
    final clean = _renameCtrl.text.trim();
    if (clean.isEmpty) {
      setState(() => _renamingLessonId = null);
      return;
    }
    store.renameLesson(id, clean);
    setState(() {
      _renamingLessonId = null;
      _renameCtrl.clear();
    });
    _flash(t('renomear'));
  }

  Future<void> _confirmRenameCloud() async {
    final id = _renamingCloudId;
    if (id == null) return;
    final clean = _renameCtrl.text.trim();
    if (clean.isEmpty) {
      setState(() => _renamingCloudId = null);
      return;
    }
    final ok = await widget.session.renameDrawerCloudLesson(id, clean);
    if (!ok) {
      _flash(t('drawer_rename_error'));
      return;
    }
    setState(() {
      _renamingCloudId = null;
      _renameCtrl.clear();
    });
    await _refreshCloudLessons();
    _flash(t('renomear'));
  }

  Future<void> _handleDelete(StudentLearningState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('confirmar_apagar')),
        content: Text(_lessonTitle(state)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t('fechar')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t('apagar')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = await widget.session.deleteDrawerLocalLesson(
      state.lessonLocalId,
    );
    if (!deleted) _flash(t('drawer_delete_cloud_error'));
    setState(() {});
    _flash(t('lesson_deleted'));
  }

  Future<void> _handleDeleteCloud(StudentStateSummaryRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('drawer_delete_account_confirm')),
        content: Text(row.tema),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t('fechar')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t('apagar')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = await widget.session.deleteDrawerCloudLesson(
      row.lessonLocalId,
    );
    if (!deleted) {
      _flash(t('drawer_delete_error'));
      return;
    }
    await _refreshCloudLessons();
    setState(() {});
    _flash(t('lesson_deleted'));
  }

  Future<void> _handleExportBackup() async {
    try {
      final backup = widget.session.buildDrawerBackupText();
      final file = await widget.session.writeDrawerBackupFile(backup);
      await Clipboard.setData(ClipboardData(text: backup));
      _flash('${t('drawer_backup_exported')} ${file.path}');
    } catch (_) {
      _flash(t('curriculo_nao_encontrado'));
    }
  }

  Future<void> _handleImportBackup() async {
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('importar')),
        content: Text(t('backup_import_file_help')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t('fechar')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('paste'),
            child: Text(t('backup_paste_manual')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('file'),
            child: Text(t('backup_select_file')),
          ),
        ],
      ),
    );
    if (mode == null) return;
    if (mode == 'file') {
      try {
        final raw = await widget.session.pickDrawerBackupFileText();
        if (raw == null) return;
        await _importBackupRaw(raw);
      } catch (_) {
        _flash(t('backup_invalido'));
      }
      return;
    }
    final raw = await _showPasteBackupDialog();
    if (raw == null) return;
    await _importBackupRaw(raw);
  }

  Future<String?> _showPasteBackupDialog() async {
    var pastedText = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('importar')),
        content: TextField(
          onChanged: (value) => pastedText = value,
          minLines: 6,
          maxLines: 10,
          decoration: InputDecoration(
            hintText: t('backup_paste_hint'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t('fechar')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(pastedText),
            child: Text(t('importar')),
          ),
        ],
      ),
    );
  }

  Future<void> _importBackupRaw(String raw) async {
    try {
      await widget.session.importDrawerBackup(raw);
      _flash(t('drawer_import_cloud_ok'));
      await _refreshCloudLessons();
      setState(() {});
    } catch (_) {
      _flash(t('backup_invalido'));
    }
  }

  Future<void> _handleExportStatus() async {
    try {
      final status = widget.session.buildDrawerStatusText();
      final file = await widget.session.writeDrawerStatusFile(status);
      await Clipboard.setData(ClipboardData(text: status));
      _flash('${t('drawer_status_exported')} ${file.path}');
    } catch (_) {
      _flash(t('curriculo_nao_encontrado'));
    }
  }

  Future<void> _handleLogout() async {
    widget.onClose();
    await widget.session.signOutReal();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final panelBg = palette.surface;
    final footerBg = palette.surfaceSoft;
    final border = palette.border;
    final text = palette.text;
    final muted = palette.muted;

    final session = widget.session;
    final lessonId = session.lessonLocalId;
    final state = lessonId != null
        ? session.canonicalStore?.readState(lessonId)
        : null;
    final localStates =
        session.canonicalStore?.listLocalStates() ?? <StudentLearningState>[];
    final localIds = localStates.map((state) => state.lessonLocalId).toSet();
    final cloudOnly = _cloudLessons
        .where((row) => !localIds.contains(row.lessonLocalId))
        .toList(growable: false);
    final filteredCloud = cloudOnly.where(_matchesCloudSearch).toList();
    final filteredStates = localStates.where(_matchesStateSearch).toList();
    final totalRows = filteredCloud.length + filteredStates.length;
    final visibleCloud = filteredCloud
        .take(_visibleLessonCount)
        .toList(growable: false);
    final localVisibleSlots = (_visibleLessonCount - visibleCloud.length).clamp(
      0,
      _visibleLessonCount,
    );
    final visibleStates = filteredStates
        .take(localVisibleSlots)
        .toList(growable: false);
    final shownRows = visibleCloud.length + visibleStates.length;
    final hasMoreLessons = shownRows < totalRows;
    final total = state?.curriculum?.totalItems ?? 0;
    final advances = state?.progress?.mainAdvances ?? 0;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: panelBg,
            border: Border(bottom: BorderSide(color: border, width: 1)),
          ),
          child: Row(
            children: [
              Text(
                t('menu').toUpperCase(),
                style: TextStyle(
                  fontFamily: kMono,
                  fontSize: 11,
                  letterSpacing: 0.22 * 11,
                  color: muted,
                ),
              ),
              const Spacer(),
              SimIconAction(
                icon: Icons.close,
                onPressed: widget.onClose,
                semanticLabel: t('close_menu'),
                size: 36,
              ),
            ],
          ),
        ),

        // Top: Nova Aula + Recarregar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: border, width: 1)),
          ),
          child: Column(
            children: [
              Semantics(
                button: true,
                label: t('nova_aula'),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: Ink(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: simPrimaryGradient(context),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: palette.shadow,
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: _handleNovaAula,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Text(
                              '＋',
                              style: TextStyle(
                                color: palette.dark
                                    ? palette.onPrimary
                                    : simDark,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              t('nova_aula'),
                              style: TextStyle(
                                color: palette.dark
                                    ? palette.onPrimary
                                    : simDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Recarregar créditos
              Semantics(
                button: true,
                label: t('recarregar_creditos'),
                child: Material(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      widget.onClose();
                      session.openCreditsFromDrawer();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          const Text('⚡', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t('recarregar_creditos'),
                              style: TextStyle(
                                color: text,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            t('top_up'),
                            style: TextStyle(
                              fontFamily: kMono,
                              fontSize: 10,
                              color: muted,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DrawerActionLine(
                      icon: Icons.menu_book_outlined,
                      label: t('menu_open_lesson'),
                      compact: true,
                      onTap: _handleOpenCurrentLesson,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _DrawerActionLine(
                      icon: Icons.supervisor_account_outlined,
                      label: t('parent_panel'),
                      compact: true,
                      onTap: () => _handleSupportRoute('/pai'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _DrawerContactLine(
                      asset: 'assets/whatsapp-logo.png',
                      label: 'WhatsApp',
                      onTap: () => _handleExternalDoor(
                        'https://wa.me/message/RLCYEXAYFUIIA1',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _DrawerContactLine(
                      asset: 'assets/messenger-logo.png',
                      label: 'Messenger',
                      onTap: () =>
                          _handleExternalDoor('https://m.me/61557707493807'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _DrawerActionLine(
                      icon: Icons.privacy_tip_outlined,
                      label: t('privacy'),
                      compact: true,
                      onTap: () => _handleSupportRoute('/privacidade'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _DrawerActionLine(
                      icon: Icons.description_outlined,
                      label: t('terms'),
                      compact: true,
                      onTap: () => _handleSupportRoute('/termos'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Middle: History / lesson list
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('historico').toUpperCase(),
                  style: TextStyle(
                    fontFamily: kMono,
                    fontSize: 10,
                    letterSpacing: 0.22 * 10,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 8),
                if (_cloudLoading &&
                    localStates.isEmpty &&
                    _cloudLessons.isEmpty)
                  Text(
                    t('searching_account'),
                    style: TextStyle(color: muted, fontSize: 12),
                  )
                else if (localStates.isEmpty && _cloudLessons.isEmpty)
                  Text(
                    session.authed
                        ? t('no_account_lessons')
                        : t('historico_vazio'),
                    style: TextStyle(color: muted, fontSize: 12),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: border),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (_) => setState(
                              () => _visibleLessonCount =
                                  aulaDrawerInitialVisible,
                            ),
                            style: TextStyle(color: text, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: t('drawer_search_placeholder'),
                              hintStyle: TextStyle(color: muted, fontSize: 14),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$shownRows/$totalRows',
                        style: TextStyle(
                          fontFamily: kMono,
                          fontSize: 10,
                          color: muted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (totalRows == 0)
                    Text(
                      t('drawer_search_empty'),
                      style: TextStyle(color: muted, fontSize: 12),
                    )
                  else ...[
                    for (final lesson in visibleCloud) ...[
                      _DrawerCloudLessonRow(
                        row: lesson,
                        renaming: _renamingCloudId == lesson.lessonLocalId,
                        renameController: _renameCtrl,
                        onOpen: () => unawaited(_handleOpenCloudLesson(lesson)),
                        onStartRename: () => _startRenameCloud(lesson),
                        onConfirmRename: () => unawaited(_confirmRenameCloud()),
                        onCancelRename: () =>
                            setState(() => _renamingCloudId = null),
                        onDelete: () => unawaited(_handleDeleteCloud(lesson)),
                      ),
                      const SizedBox(height: 6),
                    ],
                    for (final lesson in visibleStates) ...[
                      _DrawerLessonRow(
                        state: lesson,
                        active: session.lessonLocalId == lesson.lessonLocalId,
                        renaming: _renamingLessonId == lesson.lessonLocalId,
                        renameController: _renameCtrl,
                        onOpen: () =>
                            unawaited(_handleOpenLesson(lesson.lessonLocalId)),
                        onStartRename: () => _startRename(lesson),
                        onConfirmRename: _confirmRename,
                        onCancelRename: () =>
                            setState(() => _renamingLessonId = null),
                        onDelete: () => unawaited(_handleDelete(lesson)),
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (hasMoreLessons)
                      Semantics(
                        button: true,
                        label: t('drawer_load_more'),
                        child: Material(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () => setState(
                              () => _visibleLessonCount += aulaDrawerPageSize,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: border),
                              ),
                              child: Text(
                                t('drawer_load_more'),
                                style: TextStyle(
                                  color: text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: footerBg,
            border: Border(top: BorderSide(color: border, width: 1)),
          ),
          child: Column(
            children: [
              // Status line
              if (total > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        t('drawer_progress'),
                        style: TextStyle(
                          fontFamily: kMono,
                          fontSize: 11,
                          color: muted,
                        ),
                      ),
                      const Spacer(),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: kMono,
                            fontSize: 11,
                            color: text,
                          ),
                          children: [
                            TextSpan(text: '$advances/$total'),
                            const TextSpan(text: ' · '),
                            TextSpan(
                              text:
                                  '${state?.progress?.concluidos.length ?? 0}',
                              style: const TextStyle(color: Color(0xFF0A8A5A)),
                            ),
                            const TextSpan(text: ' ok'),
                            if ((state?.progress?.pendentesMarkers.length ??
                                    0) >
                                0) ...[
                              const TextSpan(text: ' · '),
                              TextSpan(
                                text:
                                    '${state?.progress?.pendentesMarkers.length ?? 0}',
                                style: const TextStyle(
                                  color: Color(0xFFC47A00),
                                ),
                              ),
                              const TextSpan(text: ' pend.'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Export / Import / Status
              Row(
                children: [
                  _DrawerFooterBtn(
                    label: t('exportar'),
                    onTap: _handleExportBackup,
                  ),
                  const SizedBox(width: 6),
                  _DrawerFooterBtn(
                    label: t('importar'),
                    onTap: _handleImportBackup,
                  ),
                  const SizedBox(width: 6),
                  _DrawerFooterBtn(
                    label: t('status'),
                    onTap: _handleExportStatus,
                  ),
                ],
              ),
              if (_feedback != null) ...[
                const SizedBox(height: 6),
                Text(
                  _feedback!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: text, fontSize: 11),
                ),
              ],
              if (session.authed) ...[
                const SizedBox(height: 8),
                // Logout button
                Semantics(
                  button: true,
                  label: t('logout'),
                  child: Material(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: _handleLogout,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, size: 16, color: text),
                            const SizedBox(width: 8),
                            Text(
                              t('logout'),
                              style: TextStyle(
                                color: text,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SimTextAction(
                  label: t('delete_account_request'),
                  semanticLabel: t('delete_account_request'),
                  onPressed: () {
                    widget.onClose();
                    session.openSupport('/conta/deletar');
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool _matchesStateSearch(StudentLearningState state) {
    return matchesLessonSearch(_searchCtrl.text, [
      _lessonTitle(state),
      state.profile.language,
      state.profile.stableLang,
      state.profile.academicLevel,
      state.profile.nivel,
      state.lessonLocalId,
      state.current?.marker,
    ]);
  }

  bool _matchesCloudSearch(StudentStateSummaryRow row) {
    return matchesLessonSearch(_searchCtrl.text, [
      row.tema,
      row.idioma,
      row.nivel,
      row.lessonLocalId,
      row.lessonCloudId,
      row.markerAtual,
    ]);
  }
}

String _lessonTitle(StudentLearningState state) {
  final title = state.profile.objetivo ?? state.curriculum?.topic;
  final clean = title?.trim();
  if (clean != null && clean.isNotEmpty) return clean;
  return state.lessonLocalId;
}

class _DrawerLessonRow extends StatelessWidget {
  const _DrawerLessonRow({
    required this.state,
    required this.active,
    required this.renaming,
    required this.renameController,
    required this.onOpen,
    required this.onStartRename,
    required this.onConfirmRename,
    required this.onCancelRename,
    required this.onDelete,
  });

  final StudentLearningState state;
  final bool active;
  final bool renaming;
  final TextEditingController renameController;
  final VoidCallback onOpen;
  final VoidCallback onStartRename;
  final VoidCallback onConfirmRename;
  final VoidCallback onCancelRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final border = palette.border;
    final text = palette.text;
    final muted = palette.muted;
    final total = state.curriculum?.totalItems ?? 0;
    final advances = state.progress?.itemIdx ?? 0;
    final pct = total > 0 ? ((advances / total) * 100).round() : 0;
    final pending = state.progress?.pendentesMarkers.length ?? 0;
    if (renaming) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: renameController,
                autofocus: true,
                style: TextStyle(color: text, fontSize: 13),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (_) => onConfirmRename(),
              ),
            ),
            _DrawerIconButton(label: '✓', onTap: onConfirmRename),
            _DrawerIconButton(label: '✕', onTap: onCancelRename),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: active ? palette.surfaceSoft : palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? palette.primary : border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: t('open_lesson_named', {'title': _lessonTitle(state)}),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lessonTitle(state),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$pct% · $advances/$total'
                          '${pending > 0 ? ' · $pending pend.' : ''}',
                          style: TextStyle(
                            fontFamily: kMono,
                            fontSize: 10,
                            color: muted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _DrawerIconButton(label: t('renomear'), onTap: onStartRename),
          _DrawerIconButton(label: t('apagar'), onTap: onDelete),
        ],
      ),
    );
  }
}

class _DrawerCloudLessonRow extends StatelessWidget {
  const _DrawerCloudLessonRow({
    required this.row,
    required this.renaming,
    required this.renameController,
    required this.onOpen,
    required this.onStartRename,
    required this.onConfirmRename,
    required this.onCancelRename,
    required this.onDelete,
  });

  final StudentStateSummaryRow row;
  final bool renaming;
  final TextEditingController renameController;
  final VoidCallback onOpen;
  final VoidCallback onStartRename;
  final VoidCallback onConfirmRename;
  final VoidCallback onCancelRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final border = palette.border;
    final text = palette.text;
    final muted = palette.muted;
    final total = row.totalItens;
    final adv = row.concluidos > row.itemIdx ? row.concluidos : row.itemIdx;
    final pct = total > 0 ? ((adv / total) * 100).round() : 0;
    if (renaming) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: renameController,
                autofocus: true,
                style: TextStyle(color: text, fontSize: 13),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (_) => onConfirmRename(),
              ),
            ),
            _DrawerIconButton(label: '✓', onTap: onConfirmRename),
            _DrawerIconButton(label: '✕', onTap: onCancelRename),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: t('open_lesson_named', {
                'title': row.tema.trim().isEmpty ? row.lessonLocalId : row.tema,
              }),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.tema.trim().isEmpty
                              ? row.lessonLocalId
                              : row.tema,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$pct% · $adv/$total',
                          style: TextStyle(
                            fontFamily: kMono,
                            fontSize: 10,
                            color: muted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _DrawerIconButton(label: t('renomear'), onTap: onStartRename),
          _DrawerIconButton(label: t('apagar'), onTap: onDelete),
        ],
      ),
    );
  }
}

class _DrawerIconButton extends StatelessWidget {
  const _DrawerIconButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final glyph = label == t('renomear')
        ? '✎'
        : label == t('apagar')
        ? '🗑'
        : label;
    final color = label == t('apagar') ? const Color(0xFFC47A00) : palette.text;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 30,
            height: 30,
            child: Center(
              child: Text(
                glyph,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerFooterBtn extends StatelessWidget {
  const _DrawerFooterBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: palette.surface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.border),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerActionLine extends StatelessWidget {
  const _DrawerActionLine({
    required this.icon,
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: compact ? 42 : 44),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 12,
              vertical: compact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: palette.text),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerContactLine extends StatelessWidget {
  const _DrawerContactLine({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 42),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Image.asset(asset, width: 18, height: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SupportedLang {
  const SupportedLang({
    required this.code,
    required this.name,
    required this.native,
    required this.flag,
  });
  final String code;
  final String name;
  final String native;
  final String flag;
}

const supportedLangs = <SupportedLang>[
  SupportedLang(code: 'en', name: 'English', native: 'English', flag: '🇺🇸'),
  SupportedLang(
    code: 'pt',
    name: 'Portuguese',
    native: 'Português',
    flag: '🇧🇷',
  ),
  SupportedLang(code: 'es', name: 'Spanish', native: 'Español', flag: '🇪🇸'),
  SupportedLang(code: 'fr', name: 'French', native: 'Français', flag: '🇫🇷'),
  SupportedLang(code: 'ja', name: 'Japanese', native: '日本語', flag: '🇯🇵'),
];

class LanguageButton extends StatelessWidget {
  const LanguageButton({
    required this.language,
    required this.active,
    required this.onTap,
    super.key,
  });

  final SupportedLang language;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final label = language.native.isEmpty
        ? language.name
        : '${language.name} · ${language.native}';
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: active ? simPrimaryGradient(context) : null,
          color: active ? null : palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? palette.primary : palette.border),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: active ? palette.onPrimary : palette.text,
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Text(language.flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StepHeader extends StatelessWidget {
  const StepHeader({
    required this.step,
    required this.total,
    required this.label,
    super.key,
  });

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final pct = step / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(color: palette.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: palette.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SimInput extends StatelessWidget {
  const SimInput({
    required this.hint,
    required this.onChanged,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    super.key,
  });

  final String hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: palette.surfaceSoft,
        hintStyle: TextStyle(color: palette.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.primary),
        ),
      ),
      style: TextStyle(color: palette.text),
    );
  }
}

class SimCard extends StatelessWidget {
  const SimCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }
}

class CardTitle extends StatelessWidget {
  const CardTitle({required this.icon, required this.title, super.key});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: palette.text,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CircleIcon extends StatelessWidget {
  const CircleIcon({required this.icon, this.top = 0, super.key});

  final IconData icon;
  final double top;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: palette.surfaceSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: palette.text, size: 18),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 14,
                spreadRadius: -6,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: palette.text, size: 20),
        ),
      ),
    );
  }
}

class CreditsPill extends StatelessWidget {
  const CreditsPill({
    required this.value,
    required this.onTap,
    this.isUnlimited = false,
    super.key,
  });

  final int value;
  final VoidCallback onTap;
  final bool isUnlimited;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: pillDecorationFor(context),
        child: Row(
          children: [
            Icon(Icons.link, color: palette.text, size: 17),
            const SizedBox(width: 8),
            Text(
              isUnlimited ? '∞' : '$value',
              style: TextStyle(
                color: palette.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Â§3.1 BackgroundDecor â€” gradiente vertical + anÃ©is radiais laterais
class BackgroundDecor extends StatelessWidget {
  const BackgroundDecor({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Stack(
      children: [
        // Camada 0: gradiente 180deg #FFFFFF 0% â†’ #F3F4F6 60% â†’ #FFFFFF 100%
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                palette.background,
                palette.surfaceSoft,
                palette.background,
              ],
              stops: [0, 0.6, 1],
            ),
          ),
          child: SizedBox.expand(),
        ),
        // Camada 1: anÃ©is radiais esquerda (top 25%, left -6px, 160Ã—420)
        Positioned(
          top: MediaQuery.of(context).size.height * 0.25,
          left: -6,
          child: Opacity(
            opacity: 0.4,
            child: _RadialRings(width: 160, height: 420),
          ),
        ),
        // Camada 2: anÃ©is radiais direita (bottom 40px, 160Ã—380)
        Positioned(
          bottom: 40,
          right: 0,
          child: Opacity(
            opacity: 0.4,
            child: _RadialRings(width: 160, height: 380),
          ),
        ),
      ],
    );
  }
}

class _RadialRings extends StatelessWidget {
  const _RadialRings({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _RadialRingsPainter(),
    );
  }
}

class _RadialRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          const Color(0x14111827) // rgba(17,24,39,0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final cx = size.width / 2;
    final cy = size.height / 2;
    double r = 19;
    while (r < size.width * 1.5) {
      canvas.drawCircle(Offset(cx, cy), r, paint);
      r += 19;
    }
  }

  @override
  bool shouldRepaint(_RadialRingsPainter oldDelegate) => false;
}

BoxDecoration glassDecoration({required double radius}) {
  return BoxDecoration(
    color: Colors.white.withAlpha(217),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white),
    boxShadow: const [
      BoxShadow(
        color: Color(0x2E111827),
        blurRadius: 60,
        offset: Offset(0, 30),
      ),
      BoxShadow(
        color: Color(0x2E243447),
        blurRadius: 30,
        offset: Offset(0, 10),
      ),
    ],
  );
}

BoxDecoration glassDecorationFor(
  BuildContext context, {
  required double radius,
}) {
  final palette = SimThemeScope.paletteOf(context);
  return BoxDecoration(
    color: palette.surface.withValues(alpha: palette.dark ? 0.86 : 0.92),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: palette.dark
          ? palette.border.withValues(alpha: 0.8)
          : Colors.white.withValues(alpha: 0.95),
    ),
    boxShadow: [
      BoxShadow(
        color: palette.shadow,
        blurRadius: palette.dark ? 36 : 60,
        offset: const Offset(0, 24),
      ),
    ],
  );
}

BoxDecoration pillDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: simBorder),
    boxShadow: const [
      BoxShadow(color: Color(0x2E243447), blurRadius: 14, offset: Offset(0, 4)),
    ],
  );
}

BoxDecoration pillDecorationFor(BuildContext context) {
  final palette = SimThemeScope.paletteOf(context);
  return BoxDecoration(
    color: palette.surface,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: palette.border),
    boxShadow: [
      BoxShadow(color: palette.shadow, blurRadius: 14, offset: Offset(0, 4)),
    ],
  );
}

BoxDecoration primaryButtonDecoration({required double radius}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      colors: [Colors.white, simLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: simBorder),
    boxShadow: const [
      BoxShadow(
        color: Color(0x33111827),
        blurRadius: 28,
        offset: Offset(0, 12),
      ),
    ],
  );
}

LinearGradient simPrimaryGradient(BuildContext context) {
  final palette = SimThemeScope.paletteOf(context);
  if (!palette.dark) return simGradientPrimary;
  return const LinearGradient(
    colors: [Color(0xFFE5E7EB), Color(0xFF94A3B8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

BoxDecoration primaryButtonDecorationFor(
  BuildContext context, {
  required double radius,
}) {
  final palette = SimThemeScope.paletteOf(context);
  return BoxDecoration(
    gradient: simPrimaryGradient(context),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: palette.border),
    boxShadow: [
      BoxShadow(color: palette.shadow, blurRadius: 24, offset: Offset(0, 10)),
    ],
  );
}
