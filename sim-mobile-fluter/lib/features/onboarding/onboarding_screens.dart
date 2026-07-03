// ignore_for_file: unused_import, unnecessary_import
import 'dart:async';
import 'dart:io';
import 'dart:ui';
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
import '../classroom/aula_screen.dart';
import '../classroom/aux_room_screens.dart';
import '../classroom/aula_widgets.dart';
import '../billing/billing_and_simple_pages.dart';
import '../../shared/widgets/shared_widgets.dart';

class IdiomaScreen extends StatefulWidget {
  const IdiomaScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<IdiomaScreen> createState() => _IdiomaScreenState();
}

class _IdiomaScreenState extends State<IdiomaScreen> {
  void _pick(String code, String name) {
    if (code == 'other') {
      widget.session.chooseLanguage(code, widget.session.otherLanguage.trim());
    } else {
      widget.session.chooseLanguage(code, name);
      Future.delayed(const Duration(milliseconds: 160), () {
        if (mounted) {
          // navigation is handled by session state change â€” just trigger it
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final palette = SimThemeScope.paletteOf(context);
    return CyberStepShell(
      step: 1,
      total: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your language',
            style: TextStyle(
              color: palette.text,
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'SIM will use this language for the app, lessons, explanations, images, audio and all guidance - from this point onward.',
            style: TextStyle(color: palette.muted, fontSize: 18, height: 1.45),
          ),
          const SizedBox(height: 28),
          for (final language in supportedLangs) ...[
            LanguageButton(
              language: language,
              active: session.selectedLanguageCode == language.code,
              onTap: () => _pick(language.code, language.name),
            ),
            const SizedBox(height: 12),
          ],
          LanguageButton(
            language: const SupportedLang(
              code: 'other',
              name: 'Other language',
              native: '',
              flag: '🌐',
            ),
            active: session.selectedLanguageCode == 'other',
            onTap: () => _pick('other', session.otherLanguage.trim()),
          ),
          if (session.selectedLanguageCode == 'other') ...[
            const SizedBox(height: 20),
            OtherLanguageBox(session: session),
          ],
        ],
      ),
    );
  }
}

class OtherLanguageBox extends StatefulWidget {
  const OtherLanguageBox({required this.session, super.key});

  final LabSession session;

  @override
  State<OtherLanguageBox> createState() => _OtherLanguageBoxState();
}

class _OtherLanguageBoxState extends State<OtherLanguageBox> {
  late final TextEditingController controller = TextEditingController(
    text: widget.session.otherLanguage,
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final value = controller.text.trim();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Type your language',
            style: TextStyle(
              color: palette.muted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Italian, German, Arabic, Kiribati...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: palette.muted),
            ),
            style: TextStyle(color: palette.text, fontSize: 18),
            onChanged: (v) {
              widget.session.setOtherLanguage(v);
              setState(() {});
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 56,
              child: DecoratedBox(
                decoration: primaryButtonDecorationFor(context, radius: 12),
                child: TextButton(
                  onPressed: value.isEmpty
                      ? null
                      : () => widget.session.chooseLanguage('other', value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        color: palette.dark ? palette.onPrimary : simDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ObjetoScreen extends StatefulWidget {
  const ObjetoScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<ObjetoScreen> createState() => _ObjetoScreenState();
}

class _ObjetoScreenState extends State<ObjetoScreen> {
  bool attachmentMenuOpen = false;
  bool sending = false;
  String? error;
  late final TextEditingController objectiveController = TextEditingController(
    text: widget.session.freeText,
  );
  late final TextEditingController nameController = TextEditingController(
    text: widget.session.preferredName,
  );

  bool get waitingAttachment => widget.session.attachments.any(
    (a) => a.status == 'uploading' || a.status == 'processing',
  );
  bool get objectiveTooShort => widget.session.freeText.trim().length < 10;
  bool get canContinue => !sending && !waitingAttachment && !objectiveTooShort;

  @override
  void dispose() {
    objectiveController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void showObjectiveRequired() {
    setState(() {
      error = widget.session.attachments.isNotEmpty
          ? objectiveRequiredWithAttachmentMessage
          : objectiveRequiredMessage;
    });
  }

  Future<void> saveAndContinue() async {
    if (waitingAttachment) return;
    if (objectiveTooShort) {
      showObjectiveRequired();
      return;
    }
    if (!canContinue) return;
    setState(() {
      error = null;
      sending = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 160));
    widget.session.saveObjectiveEntry();
  }

  Future<void> addAttachment(String source) async {
    if (widget.session.attachments.length >= maxAttachments) {
      setState(() => error = 'Limite de 3 anexos por envio.');
      return;
    }
    setState(() {
      error = null;
      attachmentMenuOpen = false;
    });
    final pickError = await widget.session.pickLabAttachment(source);
    if (!mounted || pickError == null) return;
    setState(() => error = pickError);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = maxFreeText - widget.session.freeText.length;
    return CyberStepShell(
      step: 3,
      total: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('objeto_h1'),
            style: const TextStyle(
              color: simDark,
              fontSize: 28,
              height: 1.12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          SimCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CardTitle(
                  icon: Icons.chat_bubble_outline,
                  title: 'What should SIM help with?',
                ),
                AttachmentPreviewList(
                  attachments: widget.session.attachments,
                  onRemove: (index) =>
                      setState(() => widget.session.removeAttachment(index)),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: simBorder),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Campo obrigatório',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Escreva o que você quer estudar. Se anexar um arquivo ou foto, explique o que deseja aprender com ele.',
                            style: TextStyle(
                              color: simMuted,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: objectiveController,
                            minLines: 6,
                            maxLines: 8,
                            maxLength: maxFreeText,
                            decoration: const InputDecoration(
                              hintText:
                                  'Ex: Quero estudar essa lista para a prova.',
                              border: InputBorder.none,
                              counterText: '',
                              contentPadding: EdgeInsets.only(bottom: 48),
                            ),
                            style: const TextStyle(
                              color: simDark,
                              fontSize: 16,
                              height: 1.4,
                            ),
                            onChanged: (value) {
                              widget.session.setFreeText(value);
                              if (error == objectiveRequiredMessage ||
                                  error ==
                                      objectiveRequiredWithAttachmentMessage) {
                                setState(() => error = null);
                              } else {
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                      Positioned(
                        left: 0,
                        bottom: 0,
                        child: IconButton(
                          tooltip: 'Abrir menu de anexos',
                          onPressed: () => setState(
                            () => attachmentMenuOpen = !attachmentMenuOpen,
                          ),
                          icon: const Icon(
                            Icons.attach_file,
                            color: simDark,
                            size: 24,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 12,
                        child: Text(
                          '${widget.session.freeText.length}/$maxFreeText',
                          style: const TextStyle(
                            color: simMuted,
                            fontSize: 12,
                            fontFamily: kMono,
                          ),
                        ),
                      ),
                      if (attachmentMenuOpen)
                        Positioned(
                          left: 4,
                          bottom: 46,
                          child: AttachmentMenu(onPick: addAttachment),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Conte do seu jeito. Quanto mais você explicar seu nível, dificuldade, prova, prazo e onde trava, melhor o SIM encontra seu ponto da travessia.',
                  style: TextStyle(color: simMuted, fontSize: 13, height: 1.35),
                ),
                if (widget.session.attachments.isNotEmpty &&
                    objectiveTooShort) ...[
                  const SizedBox(height: 8),
                  const Text(
                    objectiveRequiredWithAttachmentMessage,
                    style: TextStyle(color: Colors.black, fontSize: 13),
                  ),
                ],
                if (remaining < 0) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Texto muito longo.',
                    style: TextStyle(color: Colors.black, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          SimCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleIcon(icon: Icons.person_outline, top: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('objeto_preferred_name'),
                        style: const TextStyle(
                          color: simDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SimInput(
                        hint: t('objeto_name_placeholder'),
                        controller: nameController,
                        onChanged: widget.session.setPreferredName,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error!,
              style: const TextStyle(color: Colors.black, fontSize: 14),
            ),
          ],
          const SizedBox(height: 18),
          Semantics(
            button: true,
            enabled: canContinue,
            label: t('objeto_save_continue'),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: canContinue
                    ? saveAndContinue
                    : waitingAttachment
                    ? null
                    : showObjectiveRequired,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: simDark),
                    boxShadow: simShadowGlow,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (sending)
                        const Positioned(
                          left: 16,
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: simDark,
                            ),
                          ),
                        ),
                      if (!sending && !waitingAttachment && !objectiveTooShort)
                        const Positioned(
                          right: 16,
                          child: Icon(Icons.arrow_forward, color: simDark),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 42),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            sending
                                ? t('objetivo_reading')
                                : waitingAttachment
                                ? 'Aguardando leitura do anexo...'
                                : objectiveTooShort
                                ? t('objeto_helper')
                                : t('objeto_save_continue'),
                            style: SimTypography.action.copyWith(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GuidedOnboardingSection(session: widget.session),
        ],
      ),
    );
  }
}

class GuidedOnboardingSection extends StatelessWidget {
  const GuidedOnboardingSection({required this.session, super.key});

  final LabSession session;

  static const _groups = [
    _GuidedGroup(
      keyName: 'purpose',
      title: 'Qual resultado você quer?',
      options: [
        'Prova da escola',
        'Concurso',
        'Vestibular/ENEM',
        'Lista de exercícios',
        'Entender uma matéria',
      ],
    ),
    _GuidedGroup(
      keyName: 'level',
      title: 'Qual é seu ponto hoje?',
      options: [
        'Começando do zero',
        'Sei um pouco',
        'Erro muito',
        'Quero avançado',
      ],
    ),
    _GuidedGroup(
      keyName: 'blocker',
      title: 'Onde o estudo pesa?',
      options: [
        'Falta base',
        'Não entendo explicação',
        'Esqueço rápido',
        'Dificuldade de concentração',
        'Travou em exercícios',
      ],
    ),
    _GuidedGroup(
      keyName: 'deadline',
      title: 'Tem prazo?',
      options: ['Hoje', 'Esta semana', 'Este mês', 'Sem prazo'],
    ),
    _GuidedGroup(
      keyName: 'style',
      title: 'Como o SIM deve conduzir?',
      options: [
        'Bem simples',
        'Passo a passo',
        'Com imagens',
        'Com áudio',
        'Mais direto',
      ],
    ),
    _GuidedGroup(
      keyName: 'start',
      title: 'Como quer começar?',
      options: ['Do zero', 'Descobrir meu ponto', 'Ir direto para o que cai'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final answers = session.guidedAnswers;
    return SimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardTitle(
            icon: Icons.route_outlined,
            title: 'Monte sua travessia',
          ),
          const Text(
            'Responda o que souber. Isso ajuda o SIM a começar mais perto do seu nível e economizar passos.',
            style: TextStyle(color: simMuted, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),
          for (final group in _groups) ...[
            Text(
              group.title,
              style: const TextStyle(
                color: simDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in group.options)
                  _GuidedChip(
                    label: option,
                    selected: answers[group.keyName] == option,
                    onTap: () => session.setGuidedAnswer(
                      group.keyName,
                      answers[group.keyName] == option ? '' : option,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _GuidedGroup {
  const _GuidedGroup({
    required this.keyName,
    required this.title,
    required this.options,
  });

  final String keyName;
  final String title;
  final List<String> options;
}

class _GuidedChip extends StatelessWidget {
  const _GuidedChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? simDark : Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: selected ? simDark : simBorder),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : simDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AttachmentPreviewList extends StatelessWidget {
  const AttachmentPreviewList({
    required this.attachments,
    required this.onRemove,
    super.key,
  });

  final List<AttachmentDraft> attachments;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (int i = 0; i < attachments.length; i++)
            AttachmentChip(
              attachment: attachments[i],
              onRemove: () => onRemove(i),
            ),
        ],
      ),
    );
  }
}

class AttachmentChip extends StatelessWidget {
  const AttachmentChip({
    required this.attachment,
    required this.onRemove,
    super.key,
  });

  final AttachmentDraft attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final icon = attachment.type.startsWith('image/')
        ? '📷'
        : attachment.type == 'application/pdf'
        ? '📄'
        : '📝';
    final suffix =
        attachment.status == 'uploading' || attachment.status == 'processing'
        ? ' lendo...'
        : attachment.status == 'error'
        ? ' erro'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: simBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$icon ${attachment.name}$suffix',
            style: const TextStyle(color: simDark, fontSize: 12),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Text(
              '✕',
              style: TextStyle(color: simMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class AttachmentMenu extends StatelessWidget {
  const AttachmentMenu({required this.onPick, super.key});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: simBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33111827),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MenuLine(label: 'Anexar arquivo', onTap: () => onPick('document')),
            MenuLine(label: 'Tirar foto', onTap: () => onPick('camera')),
            MenuLine(label: 'Escolher imagem', onTap: () => onPick('image')),
          ],
        ),
      ),
    );
  }
}

class MenuLine extends StatelessWidget {
  const MenuLine({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(color: simDark, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
