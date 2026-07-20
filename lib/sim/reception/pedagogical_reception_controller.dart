import 'package:flutter/foundation.dart';

import '../../session/entry_form_state.dart';

enum PedagogicalReceptionPath { guided, material }

class PedagogicalReceptionStep {
  const PedagogicalReceptionStep({
    required this.id,
    required this.title,
    required this.help,
    required this.required,
  });

  final String id;
  final String title;
  final String help;
  final bool required;
}

class PedagogicalReceptionController extends ChangeNotifier {
  PedagogicalReceptionController({required this.form});

  final EntryFormState form;
  int activeIndex = 0;
  String? error;

  PedagogicalReceptionPath? get path {
    return switch (form.entryPath) {
      'guided_path' => PedagogicalReceptionPath.guided,
      'material_help' => PedagogicalReceptionPath.material,
      _ => null,
    };
  }

  bool get hasProcessingAttachment =>
      form.attachments.any((attachment) => attachment.status == 'processing');

  bool get hasAttachmentError =>
      form.attachments.any((attachment) => attachment.status == 'error');

  List<PedagogicalReceptionStep> get steps {
    final selected = path;
    return [
      const PedagogicalReceptionStep(
        id: 'path',
        title: 'Como vamos começar?',
        help: 'Escolha o jeito mais parecido com o que você precisa agora.',
        required: true,
      ),
      if (selected == PedagogicalReceptionPath.guided) ...const [
        PedagogicalReceptionStep(
          id: 'objective',
          title: 'O que você quer aprender?',
          help: 'Conte do jeito que você falaria para um professor.',
          required: true,
        ),
        PedagogicalReceptionStep(
          id: 'level',
          title: 'Qual nível ou contexto devo considerar?',
          help: 'Isso ajusta a linguagem, os exemplos e o ponto de partida.',
          required: true,
        ),
        PedagogicalReceptionStep(
          id: 'purpose',
          title: 'Para que você está estudando isso?',
          help:
              'Prova, tarefa, trabalho ou curiosidade pedem conduções diferentes.',
          required: true,
        ),
        PedagogicalReceptionStep(
          id: 'deadline',
          title: 'Tem prazo?',
          help: 'Se não tiver, seguimos com calma.',
          required: false,
        ),
        PedagogicalReceptionStep(
          id: 'result',
          title: 'O que você quer conseguir fazer no final?',
          help: 'Uma meta clara ajuda a aula a mirar no uso real.',
          required: false,
        ),
        PedagogicalReceptionStep(
          id: 'blocker',
          title: 'Onde costuma travar?',
          help:
              'Diga o ponto que costuma confundir, atrasar ou dar insegurança.',
          required: false,
        ),
        PedagogicalReceptionStep(
          id: 'style',
          title: 'Como prefere ser conduzido?',
          help: 'Escolha o ritmo que mais ajuda você a continuar.',
          required: false,
        ),
      ] else if (selected == PedagogicalReceptionPath.material) ...const [
        PedagogicalReceptionStep(
          id: 'material_type',
          title: 'Que tipo de material você trouxe?',
          help: 'Pode ser foto, PDF, lista, prova, questão ou caderno.',
          required: true,
        ),
        PedagogicalReceptionStep(
          id: 'attachments',
          title: 'Envie o material',
          help: 'Até 3 arquivos. Use PDF, texto, CSV, foto ou imagem.',
          required: false,
        ),
        PedagogicalReceptionStep(
          id: 'material_goal',
          title: 'O que você quer que o SIM faça com esse material?',
          help: 'Explique o pedido principal em uma frase ou duas.',
          required: true,
        ),
        PedagogicalReceptionStep(
          id: 'material_blocker',
          title: 'Onde você travou?',
          help:
              'Se o arquivo não ficar claro, sua descrição ainda guia a aula.',
          required: false,
        ),
        PedagogicalReceptionStep(
          id: 'material_purpose',
          title: 'Isso é para quê?',
          help: 'Isso muda a profundidade e o tipo de ajuda.',
          required: true,
        ),
      ],
      const PedagogicalReceptionStep(
        id: 'profile',
        title: 'Algum cuidado para adaptar a aula?',
        help:
            'Nome, idade e observações são opcionais, mas ajudam o tom da aula.',
        required: false,
      ),
      const PedagogicalReceptionStep(
        id: 'finish',
        title: 'Foi isso que eu entendi.',
        help: 'Confira rápido. Se algo estiver errado, toque em editar.',
        required: true,
      ),
    ];
  }

  void choosePath(PedagogicalReceptionPath value) {
    form.updatePedagogicalField(
      'entry_path',
      value == PedagogicalReceptionPath.material
          ? 'material_help'
          : 'guided_path',
    );
    if (value == PedagogicalReceptionPath.material) {
      form.updatePedagogicalField('topic', '');
    }
    error = null;
    activeIndex = 1;
    notifyListeners();
  }

  bool advance() {
    final current = steps[activeIndex];
    final validation = validateStep(current.id);
    if (validation != null) {
      error = validation;
      notifyListeners();
      return false;
    }
    error = null;
    if (activeIndex < steps.length - 1) {
      activeIndex += 1;
      notifyListeners();
    }
    return true;
  }

  void edit(String id) {
    final index = steps.indexWhere((step) => step.id == id);
    if (index < 0) return;
    activeIndex = index;
    error = null;
    notifyListeners();
  }

  String? validateStep(String id) {
    switch (id) {
      case 'path':
        return path == null ? 'Escolha um caminho para começar.' : null;
      case 'objective':
        return form.freeText.trim().length < 10
            ? 'Escreva um pouco mais sobre o que você quer aprender.'
            : null;
      case 'level':
        return form.academicLevel.trim().isEmpty
            ? 'Informe o nível, série ou contexto.'
            : null;
      case 'purpose':
        return form.traversalGoal.trim().isEmpty
            ? 'Conte para que você está estudando.'
            : null;
      case 'material_type':
        return form.materialType.trim().isEmpty
            ? 'Escolha o tipo de material.'
            : null;
      case 'attachments':
        return hasProcessingAttachment
            ? 'Estou lendo seu material. Aguarde terminar para continuar.'
            : null;
      case 'material_goal':
        return form.freeText.trim().length < 10
            ? 'Escreva um pouco mais sobre o que você quer fazer com o material.'
            : null;
      case 'material_purpose':
        return form.traversalGoal.trim().isEmpty
            ? 'Escolha ou descreva para que é esse material.'
            : null;
      case 'finish':
        return validateAll();
      default:
        return null;
    }
  }

  String? validateAll() {
    for (final step in steps) {
      if (step.id == 'finish') continue;
      final validation = validateStep(step.id);
      if (validation != null) return validation;
    }
    return null;
  }

  String summaryFor(String id) {
    switch (id) {
      case 'path':
        return path == PedagogicalReceptionPath.material
            ? 'Tenho um material e quero ajuda'
            : path == PedagogicalReceptionPath.guided
            ? 'Quero que o SIM monte meu caminho'
            : '';
      case 'objective':
      case 'material_goal':
        return form.freeText.trim();
      case 'level':
        return form.academicLevel.trim();
      case 'purpose':
      case 'material_purpose':
        return form.traversalGoal.trim();
      case 'deadline':
        return form.deadlineCustom.trim().isNotEmpty
            ? form.deadlineCustom.trim()
            : form.deadline.trim();
      case 'result':
        return form.expectedResult.trim();
      case 'blocker':
      case 'material_blocker':
        return form.difficulties.trim();
      case 'style':
        return form.learningPreference.trim();
      case 'material_type':
        return form.materialType.trim();
      case 'attachments':
        final ready = form.attachments.where((a) => a.status == 'ready').length;
        if (form.attachments.isEmpty) {
          return 'Sem anexo; vou usar sua descrição.';
        }
        final names = form.attachments
            .map((attachment) => attachment.name.trim())
            .where((name) => name.isNotEmpty)
            .join(', ');
        final status =
            '$ready de ${form.attachments.length} material(is) lido(s).';
        return names.isEmpty ? status : '$status\n$names';
      case 'profile':
        return [
          form.preferredName.trim(),
          form.studentAge.trim(),
          form.profileObservation.trim(),
        ].where((value) => value.isNotEmpty).join(' · ');
      case 'finish':
        return finalSummaryLines().join('\n');
      default:
        return '';
    }
  }

  List<String> finalSummaryLines() {
    final lines = <String>[
      path == PedagogicalReceptionPath.material
          ? 'Vou usar seu material como ponto de partida.'
          : 'Vou montar um caminho e encontrar o ponto certo para começar.',
      if (form.freeText.trim().isNotEmpty) 'Objetivo: ${form.freeText.trim()}',
      if (form.materialType.trim().isNotEmpty)
        'Material: ${form.materialType.trim()}',
      if (form.attachments.isNotEmpty) summaryFor('attachments'),
      if (form.academicLevel.trim().isNotEmpty)
        'Contexto: ${form.academicLevel.trim()}',
      if (form.traversalGoal.trim().isNotEmpty)
        'Uso: ${form.traversalGoal.trim()}',
      if (_effectiveDeadline().isNotEmpty) 'Prazo: ${_effectiveDeadline()}',
      if (form.expectedResult.trim().isNotEmpty)
        'Meta: ${form.expectedResult.trim()}',
      if (form.difficulties.trim().isNotEmpty)
        'Atenção: ${form.difficulties.trim()}',
      if (form.learningPreference.trim().isNotEmpty)
        'Condução: ${form.learningPreference.trim()}',
      if (summaryFor('profile').trim().isNotEmpty)
        'Cuidado: ${summaryFor('profile').trim()}',
    ];
    return lines
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
  }

  String _effectiveDeadline() {
    final custom = form.deadlineCustom.trim();
    return custom.isNotEmpty ? custom : form.deadline.trim();
  }
}
