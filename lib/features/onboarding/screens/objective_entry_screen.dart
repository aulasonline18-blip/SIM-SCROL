part of '../onboarding_screens.dart';

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
  late final ObjectiveEntryViewModel viewModel;
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
    viewModel = ObjectiveEntryViewModel(session: session, reception: reception);
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
    viewModel.advance();
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
    if (viewModel.hasProcessingAttachment) {
      setState(
        () => error =
            'Estou lendo seu material. Aguarde terminar para continuar.',
      );
      _scrollToActive();
      return;
    }
    final validation = viewModel.validateActiveStep();
    if (validation != null) {
      setState(() => error = validation);
      _scrollToActive();
      return;
    }
    final ok = viewModel.submitObjectiveEntry();
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
    final visibleSteps = viewModel.visibleSteps;
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
                    summary: viewModel.summaryFor(visibleSteps[i].id),
                    error: i == reception.activeIndex ? error : null,
                    onEdit: () => viewModel.edit(visibleSteps[i].id),
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
            _FinishSummary(lines: viewModel.finalSummaryLines()),
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
