import 'package:flutter/material.dart';

import '../../features/session/lab_session.dart';
import '../../session/entry_form_state.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../sim/reception/pedagogical_reception_controller.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/sim_theme.dart';

class ConversationalEntryScreen extends StatelessWidget {
  const ConversationalEntryScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final routePath = Uri.tryParse(session.route)?.path ?? session.route;
    if (routePath == '/cyber/idioma') {
      return _LanguageScreen(session: session);
    }
    return _EntryScreen(session: session);
  }
}

class ObjetoScreen extends StatelessWidget {
  const ObjetoScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) => _EntryScreen(session: session);
}

class _EntryScreen extends StatefulWidget {
  const _EntryScreen({required this.session});

  final LabSession session;

  @override
  State<_EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<_EntryScreen> {
  late final TextEditingController objectiveController;
  late final TextEditingController nameController;
  late final TextEditingController levelController;
  late final TextEditingController purposeController;
  late final TextEditingController deadlineController;
  late final TextEditingController resultController;
  late final TextEditingController blockerController;
  late final TextEditingController preferenceController;
  late final TextEditingController materialTypeController;
  late final TextEditingController ageController;
  late final TextEditingController observationController;
  late final PedagogicalReceptionController reception;
  final scrollController = ScrollController();
  final blockKeys = <String, GlobalKey>{};
  String? error;

  LabSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    objectiveController = TextEditingController(text: session.freeText);
    nameController = TextEditingController(text: session.preferredName);
    levelController = TextEditingController(text: session.academicLevel);
    purposeController = TextEditingController(text: session.traversalGoal);
    deadlineController = TextEditingController(text: session.deadline);
    resultController = TextEditingController(text: session.expectedResult);
    blockerController = TextEditingController(text: session.difficulties);
    preferenceController = TextEditingController(
      text: session.learningPreference,
    );
    materialTypeController = TextEditingController(text: session.materialType);
    ageController = TextEditingController(text: session.studentAge);
    observationController = TextEditingController(
      text: session.profileObservation,
    );
    reception = PedagogicalReceptionController(form: session.entryForm)
      ..addListener(_handleReceptionChanged);
    session.addListener(_syncFromSession);
  }

  void _handleReceptionChanged() {
    if (!mounted) return;
    setState(() => error = reception.error);
    _scrollToActive();
  }

  void _syncFromSession() {
    if (!mounted) return;
    _syncText(objectiveController, session.freeText);
    _syncText(nameController, session.preferredName);
    _syncText(levelController, session.academicLevel);
    _syncText(purposeController, session.traversalGoal);
    _syncText(deadlineController, session.deadline);
    _syncText(resultController, session.expectedResult);
    _syncText(blockerController, session.difficulties);
    _syncText(preferenceController, session.learningPreference);
    _syncText(materialTypeController, session.materialType);
    _syncText(ageController, session.studentAge);
    _syncText(observationController, session.profileObservation);
    setState(() {});
  }

  void _syncText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _pickAttachment(String source) async {
    final message = await session.pickLabAttachment(source);
    if (!mounted) return;
    setState(() => error = message);
  }

  void _next() {
    reception.advance();
    _scrollToActive();
  }

  void _scrollToActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final step = reception.steps[reception.activeIndex];
      final context = blockKeys[step.id]?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  void _submit() {
    if (session.attachments.any(
      (attachment) => attachment.status == 'processing',
    )) {
      setState(
        () => error =
            'Estou lendo seu material. Aguarde terminar para continuar.',
      );
      _scrollToActive();
      return;
    }
    final current = reception.steps[reception.activeIndex];
    final validation = reception.validateStep(current.id);
    if (validation != null) {
      setState(() => error = validation);
      _scrollToActive();
      return;
    }
    final ok = session.saveObjectiveEntry();
    setState(
      () => error = ok ? null : 'Escreva um objetivo um pouco mais completo.',
    );
  }

  @override
  void dispose() {
    session.removeListener(_syncFromSession);
    reception.removeListener(_handleReceptionChanged);
    reception.dispose();
    scrollController.dispose();
    objectiveController.dispose();
    nameController.dispose();
    levelController.dispose();
    purposeController.dispose();
    deadlineController.dispose();
    resultController.dispose();
    blockerController.dispose();
    preferenceController.dispose();
    materialTypeController.dispose();
    ageController.dispose();
    observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final palette = SimThemeScope.paletteOf(context);
    final visibleSteps = reception.steps
        .take(reception.activeIndex + 1)
        .toList(growable: false);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: SimBreakpoints.learningMaxWidth(width),
            ),
            child: ListView(
              key: const Key('pedagogical-reception-scroll'),
              controller: scrollController,
              padding: SimBreakpoints.pagePadding(
                width,
              ).copyWith(top: 20, bottom: 28),
              children: [
                StepHeader(
                  title: 'Recepção pedagógica',
                  subtitle: 'Vou entender seu caso antes de preparar a aula.',
                ),
                const SizedBox(height: 16),
                _SimIntroBubble(
                  text:
                      'Me diga primeiro se você quer aprender um tema ou se trouxe um material específico.',
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < visibleSteps.length; i++) ...[
                  _ReceptionBlock(
                    key: blockKeys.putIfAbsent(
                      visibleSteps[i].id,
                      () => GlobalKey(),
                    ),
                    step: visibleSteps[i],
                    active: i == reception.activeIndex,
                    complete: i < reception.activeIndex,
                    summary: reception.summaryFor(visibleSteps[i].id),
                    error: i == reception.activeIndex ? error : null,
                    onEdit: () => reception.edit(visibleSteps[i].id),
                    child: _stepBody(visibleSteps[i].id),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody(String id) {
    switch (id) {
      case 'path':
        return Column(
          children: [
            _BigChoiceButton(
              key: const Key('reception-guided-path'),
              icon: Icons.route_outlined,
              title: 'Quero que o SIM monte meu caminho',
              body: 'Para aprender um tema sem trazer arquivo ou exercício.',
              selected: reception.path == PedagogicalReceptionPath.guided,
              onTap: () =>
                  reception.choosePath(PedagogicalReceptionPath.guided),
            ),
            const SizedBox(height: 10),
            _BigChoiceButton(
              key: const Key('reception-material-path'),
              icon: Icons.attach_file,
              title: 'Tenho um material e quero ajuda',
              body: 'Para foto, PDF, lista, prova, questão ou caderno.',
              selected: reception.path == PedagogicalReceptionPath.material,
              onTap: () =>
                  reception.choosePath(PedagogicalReceptionPath.material),
            ),
          ],
        );
      case 'objective':
        return _TextStep(
          key: const Key('reception-objective-input'),
          controller: objectiveController,
          label: 'O que você quer aprender?',
          help: 'Exemplo: frações, redação do ENEM ou cinemática.',
          minLines: 3,
          onChanged: session.setFreeText,
          onNext: _next,
        );
      case 'level':
        return _ChoiceTextStep(
          controller: levelController,
          label: 'Nível, série ou contexto',
          options: const [
            'Começando do zero',
            'Ensino fundamental',
            'Ensino médio',
            'Faculdade',
            'Trabalho',
          ],
          onChanged: (value) =>
              session.setPedagogicalEntryField('academic_level', value),
          onNext: _next,
        );
      case 'purpose':
        return _ChoiceTextStep(
          controller: purposeController,
          label: 'Finalidade',
          options: const [
            'Prova',
            'Tarefa',
            'Trabalho',
            'Aprender sozinho',
            'Concurso',
          ],
          onChanged: (value) =>
              session.setPedagogicalEntryField('traversal_goal', value),
          onNext: _next,
        );
      case 'deadline':
        return _ChoiceTextStep(
          controller: deadlineController,
          label: 'Prazo',
          options: const ['Sem prazo', 'Hoje', 'Esta semana', 'Este mês'],
          onChanged: (value) =>
              session.setPedagogicalEntryField('deadline', value),
          onNext: _next,
          optional: true,
        );
      case 'result':
        return _TextStep(
          controller: resultController,
          label: 'Resultado esperado',
          help:
              'Exemplo: resolver sozinho, explicar melhor ou passar na prova.',
          onChanged: (value) =>
              session.setPedagogicalEntryField('expected_result', value),
          onNext: _next,
          optional: true,
        );
      case 'blocker':
      case 'material_blocker':
        return _TextStep(
          controller: blockerController,
          label: 'Onde trava',
          help:
              'Pode ser uma dúvida específica ou uma parte que sempre confunde.',
          onChanged: (value) =>
              session.setPedagogicalEntryField('difficulties', value),
          onNext: _next,
          optional: true,
        );
      case 'style':
        return _ChoiceTextStep(
          controller: preferenceController,
          label: 'Condução preferida',
          options: const [
            'Passo a passo',
            'Com exemplos',
            'Com exercícios',
            'Revisando pontos fracos',
            'Direto ao ponto',
          ],
          onChanged: (value) =>
              session.setPedagogicalEntryField('learning_preference', value),
          onNext: _next,
          optional: true,
        );
      case 'material_type':
        return _ChoiceTextStep(
          controller: materialTypeController,
          label: 'Material',
          options: const [
            'Foto do caderno',
            'PDF',
            'Lista de exercícios',
            'Prova',
            'Questão',
            'Resposta que tentei fazer',
          ],
          onChanged: (value) =>
              session.setPedagogicalEntryField('material_type', value),
          onNext: _next,
        );
      case 'attachments':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AttachmentPreviewList(
              attachments: session.attachments,
              onRemove: session.removeAttachment,
            ),
            if (session.attachments.isEmpty)
              const Text('Você pode anexar agora ou descrever com texto.'),
            if (session.attachments.any((a) => a.status == 'processing'))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Estou lendo seu material...'),
              ),
            if (session.attachments.any((a) => a.status == 'ready'))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Consegui extrair o conteúdo.'),
              ),
            if (session.attachments.any((a) => a.status == 'error'))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Não consegui ler bem. Você pode descrever com texto.',
                ),
              ),
            if (session.attachmentError != null)
              SimChatError(text: session.attachmentError!),
            const SizedBox(height: 12),
            AttachmentMenu(onPick: _pickAttachment),
            const SizedBox(height: 12),
            PrimaryWideButton(label: 'Continuar', onPressed: _next),
          ],
        );
      case 'material_goal':
        return _TextStep(
          key: const Key('reception-material-goal-input'),
          controller: objectiveController,
          label: 'O que devo fazer com o material?',
          help: 'Exemplo: explique a questão 3 e monte uma aula curta.',
          minLines: 3,
          onChanged: session.setFreeText,
          onNext: _next,
        );
      case 'material_purpose':
        return _ChoiceTextStep(
          controller: purposeController,
          label: 'Para que você vai usar isso?',
          options: const [
            'Prova',
            'Tarefa',
            'Lista',
            'Revisão',
            'Entender um exercício',
          ],
          onChanged: (value) =>
              session.setPedagogicalEntryField('traversal_goal', value),
          onNext: _next,
        );
      case 'profile':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SmallTextField(
              controller: nameController,
              label: 'Como devo chamar você?',
              help: 'Opcional.',
              onChanged: session.setPreferredName,
            ),
            const SizedBox(height: 12),
            _SmallTextField(
              controller: ageController,
              label: 'Idade',
              help: 'Opcional. Ajuda a ajustar linguagem e exemplos.',
              onChanged: session.setStudentAge,
            ),
            const SizedBox(height: 12),
            _SmallTextField(
              controller: observationController,
              label: 'Observação livre',
              help: 'Algo que devo considerar na condução?',
              onChanged: session.setProfileObservation,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            PrimaryWideButton(label: 'Continuar', onPressed: _next),
          ],
        );
      case 'finish':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FinishSummary(lines: reception.finalSummaryLines()),
            const SizedBox(height: 14),
            PrimaryWideButton(
              key: const Key('reception-submit'),
              label: 'Preparar minha aula',
              onPressed: _submit,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _FinishSummary extends StatelessWidget {
  const _FinishSummary({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Column(
      key: const Key('reception-final-summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Com isso, consigo preparar uma aula mais certeira para você.',
          style: TextStyle(
            color: palette.text,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        for (final line in lines) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 18,
                color: palette.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  line,
                  style: TextStyle(color: palette.text, height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ReceptionBlock extends StatelessWidget {
  const _ReceptionBlock({
    required this.step,
    required this.active,
    required this.complete,
    required this.summary,
    required this.error,
    required this.onEdit,
    required this.child,
    super.key,
  });

  final PedagogicalReceptionStep step;
  final bool active;
  final bool complete;
  final String summary;
  final String? error;
  final VoidCallback onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('reception-turn-${step.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SimQuestionBubble(
          key: Key('reception-question-${step.id}'),
          active: active,
          title: step.title,
          help: step.help,
        ),
        if (complete && summary.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _StudentSummaryBubble(
            key: Key('reception-answer-${step.id}'),
            text: summary,
            onEdit: onEdit,
          ),
        ],
        if (active) ...[
          const SizedBox(height: 10),
          _ActiveReplyBubble(
            key: Key('reception-active-${step.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                child,
                if (error != null) SimChatError(text: error!),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SimIntroBubble extends StatelessWidget {
  const _SimIntroBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SimLearningSurface(
          tone: SimSurfaceTone.selected,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome, color: palette.primary, size: 18),
              const SizedBox(width: SimSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: palette.text, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimQuestionBubble extends StatelessWidget {
  const _SimQuestionBubble({
    required this.active,
    required this.title,
    required this.help,
    super.key,
  });

  final bool active;
  final String title;
  final String help;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SimLearningSurface(
          tone: active ? SimSurfaceTone.selected : SimSurfaceTone.soft,
          borderWidth: active ? 1.4 : 1,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SimTypography.lessonQuestion.copyWith(
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                help,
                style: SimTypography.muted.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentSummaryBubble extends StatelessWidget {
  const _StudentSummaryBubble({
    required this.text,
    required this.onEdit,
    super.key,
  });

  final String text;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SimLearningSurface(
          tone: SimSurfaceTone.success,
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  text,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SimTextAction(
                key: const Key('reception-edit-answer'),
                label: 'Editar',
                onPressed: onEdit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveReplyBubble extends StatelessWidget {
  const _ActiveReplyBubble({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SimLearningSurface(
          tone: SimSurfaceTone.elevated,
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ),
    );
  }
}

class _BigChoiceButton extends StatelessWidget {
  const _BigChoiceButton({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.selectedSurface : palette.surface,
        borderRadius: BorderRadius.circular(SimRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SimRadius.lg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.all(SimSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SimRadius.lg),
              border: Border.all(
                color: selected ? palette.primary : palette.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: selected
                      ? palette.primary
                      : palette.surfaceSoft,
                  child: Icon(
                    icon,
                    color: selected ? palette.onPrimary : palette.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: SimSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: SimTypography.action),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: SimTypography.caption.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
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

class _TextStep extends StatelessWidget {
  const _TextStep({
    required this.controller,
    required this.label,
    required this.help,
    required this.onChanged,
    required this.onNext,
    this.minLines = 2,
    this.optional = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String help;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final int minLines;
  final bool optional;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SmallTextField(
        controller: controller,
        label: label,
        help: help,
        onChanged: onChanged,
        maxLines: minLines,
      ),
      const SizedBox(height: 12),
      PrimaryWideButton(
        label: optional ? 'Continuar' : 'Salvar e continuar',
        onPressed: onNext,
      ),
    ],
  );
}

class _ChoiceTextStep extends StatelessWidget {
  const _ChoiceTextStep({
    required this.controller,
    required this.label,
    required this.options,
    required this.onChanged,
    required this.onNext,
    this.optional = false,
  });

  final TextEditingController controller;
  final String label;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final bool optional;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SimChatFieldLabel(label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            ChoiceChip(
              label: Text(option),
              selected: controller.text == option,
              onSelected: (_) {
                controller.text = option;
                onChanged(option);
              },
            ),
        ],
      ),
      const SizedBox(height: 10),
      SimInput(
        controller: controller,
        hint: optional
            ? 'Escreva outro ou deixe em branco.'
            : 'Escreva se preferir.',
        onChanged: onChanged,
      ),
      const SizedBox(height: 12),
      PrimaryWideButton(
        label: optional ? 'Continuar' : 'Salvar e continuar',
        onPressed: onNext,
      ),
    ],
  );
}

class _SmallTextField extends StatelessWidget {
  const _SmallTextField({
    required this.controller,
    required this.label,
    required this.help,
    required this.onChanged,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String help;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SimChatFieldLabel(label),
      const SizedBox(height: 4),
      Text(
        help,
        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
      ),
      const SizedBox(height: 8),
      SimInput(
        controller: controller,
        hint: '',
        maxLines: maxLines,
        onChanged: onChanged,
      ),
    ],
  );
}

class _LanguageScreen extends StatefulWidget {
  const _LanguageScreen({required this.session});

  final LabSession session;

  @override
  State<_LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<_LanguageScreen> {
  late final TextEditingController otherController;

  LabSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    otherController = TextEditingController(text: session.otherLanguage);
    session.addListener(_syncFromSession);
  }

  void _syncFromSession() {
    if (!mounted) return;
    if (otherController.text != session.otherLanguage) {
      otherController.value = TextEditingValue(
        text: session.otherLanguage,
        selection: TextSelection.collapsed(
          offset: session.otherLanguage.length,
        ),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    session.removeListener(_syncFromSession);
    otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final palette = SimThemeScope.paletteOf(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: SimBreakpoints.learningMaxWidth(width),
            ),
            child: ListView(
              key: const Key('language-screen'),
              padding: SimBreakpoints.pagePadding(
                width,
              ).copyWith(top: 20, bottom: 28),
              children: [
                StepHeader(
                  title: t('language_title'),
                  subtitle: t('language_subtitle'),
                ),
                const SizedBox(height: 16),
                SimChatBubble(
                  text: t('language_choose_label'),
                  supportingText: t('language_subtitle'),
                ),
                const SizedBox(height: 12),
                SimChatInputCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SimChatChoiceWrap(
                        children: [
                          for (final language in supportedLangs)
                            LanguageButton(
                              language: language,
                              selected:
                                  session.selectedLanguageCode == language.code,
                              onTap: () => session.chooseLanguage(
                                language.code,
                                language.name,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SimChatFieldLabel(t('language_other_label')),
                      const SizedBox(height: 8),
                      SimInput(
                        key: const Key('language-other-input'),
                        controller: otherController,
                        hint: t('language_other_placeholder'),
                        onChanged: session.setOtherLanguage,
                      ),
                      const SizedBox(height: 12),
                      PrimaryWideButton(
                        label: t('continue'),
                        onPressed: session.otherLanguage.trim().isEmpty
                            ? null
                            : () => session.chooseLanguage(
                                'other',
                                session.otherLanguage,
                              ),
                      ),
                    ],
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

class OnboardingChatFlow extends StatelessWidget {
  const OnboardingChatFlow({
    required this.children,
    required this.semanticLabel,
    this.scrollable = true,
    super.key,
  });

  final List<Widget> children;
  final String semanticLabel;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final content = Padding(
      padding: SimBreakpoints.pagePadding(
        width,
      ).copyWith(top: SimSpacing.lg, bottom: SimSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    return Semantics(
      label: semanticLabel,
      child: scrollable
          ? ListView(padding: EdgeInsets.zero, children: [content])
          : content,
    );
  }
}

class SimChatReveal extends StatelessWidget {
  const SimChatReveal({
    required this.child,
    this.delay = Duration.zero,
    super.key,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => child;
}

class SimChatBubble extends StatelessWidget {
  const SimChatBubble({required this.text, this.supportingText, super.key});

  final String text;
  final String? supportingText;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return SimLearningSurface(
      tone: SimSurfaceTone.selected,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: SimTypography.lessonQuestion.copyWith(color: palette.text),
          ),
          if (supportingText != null) ...[
            const SizedBox(height: 6),
            Text(
              supportingText!,
              style: SimTypography.muted.copyWith(color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class SimChatInputCard extends StatelessWidget {
  const SimChatInputCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => SimCard(child: child);
}

class SimChatChoiceWrap extends StatelessWidget {
  const SimChatChoiceWrap({required this.children, super.key})
    : staggered = false;

  const SimChatChoiceWrap.staggered({required this.children, super.key})
    : staggered = true;

  final List<Widget> children;
  final bool staggered;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: SimSpacing.sm,
    runSpacing: SimSpacing.sm,
    children: children,
  );
}

class SimChatSendButton extends StatelessWidget {
  const SimChatSendButton({
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SimIconAction(
    icon: Icons.arrow_forward,
    semanticLabel: semanticLabel,
    onPressed: onPressed,
  );
}

class SimChatChoiceChip extends StatelessWidget {
  const SimChatChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? palette.selectedSurface : palette.surface,
        borderRadius: BorderRadius.circular(SimRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SimRadius.lg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: SimTouch.min),
            padding: const EdgeInsets.symmetric(
              horizontal: SimSpacing.md,
              vertical: SimSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SimRadius.lg),
              border: Border.all(
                color: selected ? palette.primary : palette.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: SimTypography.label.copyWith(
                color: palette.text,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SimChatFieldLabel extends StatelessWidget {
  const SimChatFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Text(text, style: SimTypography.label.copyWith(color: palette.text));
  }
}

class SimChatError extends StatelessWidget {
  const SimChatError({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: SimStatusSurface(
      tone: SimSurfaceTone.danger,
      icon: Icons.error_outline,
      child: Text(text),
    ),
  );
}

class GuidedGroup {
  const GuidedGroup({
    required this.keyName,
    required this.titleKey,
    required this.optionKeys,
  });

  final String keyName;
  final String titleKey;
  final List<String> optionKeys;
}

class GuidedOnboardingSection extends StatelessWidget {
  const GuidedOnboardingSection({required this.session, super.key});

  final LabSession session;

  static const groups = <GuidedGroup>[
    GuidedGroup(
      keyName: 'goal',
      titleKey: 'guided_goal_title',
      optionKeys: [
        'guided_goal_school',
        'guided_goal_work',
        'guided_goal_self',
      ],
    ),
    GuidedGroup(
      keyName: 'level',
      titleKey: 'guided_level_title',
      optionKeys: [
        'guided_level_beginner',
        'guided_level_mid',
        'guided_level_high',
      ],
    ),
    GuidedGroup(
      keyName: 'preference',
      titleKey: 'guided_preference_title',
      optionKeys: [
        'guided_pref_fast',
        'guided_pref_examples',
        'guided_pref_step',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final group in groups) ...[
        SimChatFieldLabel(t(group.titleKey)),
        const SizedBox(height: 8),
        SimChatChoiceWrap(
          children: [
            for (final key in group.optionKeys)
              SimChatChoiceChip(
                label: t(key),
                selected: session.guidedAnswers[group.keyName] == key,
                onTap: () => session.setGuidedAnswer(group.keyName, key),
              ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    ],
  );
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < attachments.length; i++) ...[
        AttachmentChip(attachment: attachments[i], onRemove: () => onRemove(i)),
        const SizedBox(height: SimSpacing.sm),
      ],
    ],
  );
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
    final palette = SimThemeScope.paletteOf(context);
    final statusTone = switch (attachment.status) {
      'ready' => SimSurfaceTone.success,
      'error' => SimSurfaceTone.danger,
      'processing' => SimSurfaceTone.warning,
      _ => SimSurfaceTone.soft,
    };
    final statusIcon = switch (attachment.status) {
      'ready' => Icons.check_circle_outline,
      'error' => Icons.error_outline,
      'processing' => Icons.hourglass_top,
      _ => Icons.description_outlined,
    };
    return SimLearningSurface(
      tone: statusTone,
      padding: const EdgeInsets.all(SimSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: palette.surface,
            child: Icon(statusIcon, color: palette.text, size: 20),
          ),
          const SizedBox(width: SimSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SimTypography.label.copyWith(color: palette.text),
                ),
                const SizedBox(height: 3),
                Text(
                  _attachmentStatusText(attachment),
                  style: SimTypography.caption.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: SimSpacing.xs),
          SimIconAction(
            icon: Icons.close,
            semanticLabel: t('remove'),
            onPressed: onRemove,
            size: 40,
            iconSize: 18,
          ),
        ],
      ),
    );
  }

  String _attachmentStatusText(AttachmentDraft attachment) {
    return switch (attachment.status) {
      'processing' => 'Estou lendo seu material...',
      'ready' => 'Consegui extrair o conteúdo.',
      'error' =>
        attachment.error?.trim().isNotEmpty == true
            ? attachment.error!.trim()
            : 'Não consegui ler bem. Você pode descrever com texto.',
      _ => 'Material recebido.',
    };
  }
}

class AttachmentMenu extends StatelessWidget {
  const AttachmentMenu({required this.onPick, super.key});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MenuLine(
        icon: Icons.description_outlined,
        label: t('attach_file'),
        onTap: () => onPick('document'),
      ),
      const SizedBox(height: SimSpacing.sm),
      MenuLine(
        icon: Icons.photo_camera_outlined,
        label: t('attach_camera'),
        onTap: () => onPick('camera'),
      ),
      const SizedBox(height: SimSpacing.sm),
      MenuLine(
        icon: Icons.image_outlined,
        label: t('attach_image'),
        onTap: () => onPick('gallery'),
      ),
    ],
  );
}

class MenuLine extends StatelessWidget {
  const MenuLine({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SimActionButton(
    label: label,
    icon: icon,
    onPressed: onTap,
    tone: SimActionTone.secondary,
  );
}
