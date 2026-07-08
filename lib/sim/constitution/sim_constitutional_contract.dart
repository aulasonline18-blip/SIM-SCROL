import '../lesson/lesson_models.dart';
import '../state/mastery_truth_engine.dart';
import '../state/student_learning_state.dart';

enum SimConstitutionalLaw {
  notChatbot,
  notSuperficialQuiz,
  aiNotStateAuthority,
  softwareValidatesLearning,
  advanceRequiresEvidence,
  firstLessonPriority,
  textDoesNotWaitForMedia,
}

enum SimPowerActor { father, assistant, tutor }

class SimConstitutionViolation implements Exception {
  const SimConstitutionViolation(this.law, this.message);

  final SimConstitutionalLaw law;
  final String message;

  @override
  String toString() => 'SimConstitutionViolation(${law.name}): $message';
}

class SimInteractionContract {
  const SimInteractionContract({
    required this.lessonStructured,
    required this.hasExplanation,
    required this.hasQuestion,
    required this.hasOptions,
    required this.hasFeedbackPath,
    required this.hasEvidenceSignal,
    this.freeChatMode = false,
  });

  final bool lessonStructured;
  final bool hasExplanation;
  final bool hasQuestion;
  final bool hasOptions;
  final bool hasFeedbackPath;
  final bool hasEvidenceSignal;
  final bool freeChatMode;
}

class SimAnswerEvidence {
  const SimAnswerEvidence({
    required this.marker,
    required this.layer,
    required this.selectedAnswer,
    required this.signal,
    required this.correct,
    required this.validatedBySoftware,
  });

  final String marker;
  final LessonLayer layer;
  final AnswerLetter selectedAnswer;
  final DecisionSignal signal;
  final bool correct;
  final bool validatedBySoftware;
}

class SimAdvanceGateResult {
  const SimAdvanceGateResult({
    required this.allowAdvance,
    required this.reason,
    required this.law,
  });

  final bool allowAdvance;
  final String reason;
  final SimConstitutionalLaw law;
}

class SimPowerMapEntry {
  const SimPowerMapEntry({
    required this.actor,
    required this.owns,
    required this.may,
    required this.forbidden,
  });

  final SimPowerActor actor;
  final List<String> owns;
  final List<String> may;
  final List<String> forbidden;
}

class SimConstitutionalContract {
  const SimConstitutionalContract();

  static const laws = SimConstitutionalLaw.values;

  static const powerMap = {
    SimPowerActor.father: SimPowerMapEntry(
      actor: SimPowerActor.father,
      owns: ['laws', 'protection', 'constitutional_blockers'],
      may: ['block_violation', 'validate_contract', 'audit_power_boundary'],
      forbidden: ['generate_content', 'own_progress'],
    ),
    SimPowerActor.assistant: SimPowerMapEntry(
      actor: SimPowerActor.assistant,
      owns: ['state', 'route', 'progress', 'validation', 'advance'],
      may: [
        'persist_state',
        'validate_learning',
        'apply_advance_gate',
        'route_next_step',
      ],
      forbidden: ['generate_unvalidated_content'],
    ),
    SimPowerActor.tutor: SimPowerMapEntry(
      actor: SimPowerActor.tutor,
      owns: ['content_generation'],
      may: [
        'generate_lesson_text',
        'generate_feedback_text',
        'generate_visual_request',
      ],
      forbidden: [
        'mutate_state',
        'decide_final_progress',
        'advance_student',
        'mark_mastery',
      ],
    ),
  };

  static const _stateControlKeys = {
    'progress',
    'progresso',
    'advance',
    'avancar',
    'concluded',
    'concluidos',
    'concluído',
    'concluido',
    'mastery',
    'dominio',
    'domínio',
    'current',
    'itemidx',
    'item_idx',
    'currentitem',
    'current_item',
    'layer',
    'camada',
    'statepatch',
    'state_patch',
    'finalizada',
    'finished',
  };

  bool _containsStateControlKey(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        if (_stateControlKeys.contains(key)) return true;
        if (_containsStateControlKey(entry.value)) return true;
      }
      return false;
    }
    if (value is Iterable) {
      return value.any(_containsStateControlKey);
    }
    return false;
  }

  void assertPowerBoundary({
    required SimPowerActor actor,
    required String action,
    required String target,
  }) {
    final intent = '$action $target'.toLowerCase();
    final stateIntent = RegExp(
      r'(state|estado|progress|progresso|advance|avancar|mastery|dominio|domínio|current|layer|camada)',
    ).hasMatch(intent);
    if (actor == SimPowerActor.tutor && stateIntent) {
      throw const SimConstitutionViolation(
        SimConstitutionalLaw.aiNotStateAuthority,
        'Tutor/IA gera conteudo, mas nao controla estado, progresso ou avanco',
      );
    }
    if (stateIntent && actor != SimPowerActor.assistant) {
      throw const SimConstitutionViolation(
        SimConstitutionalLaw.softwareValidatesLearning,
        'estado, progresso e avanco pertencem ao Assistente/software',
      );
    }
  }

  void assertTutorCannotControlState(Object? payload) {
    if (_containsStateControlKey(payload)) {
      throw const SimConstitutionViolation(
        SimConstitutionalLaw.aiNotStateAuthority,
        'resposta de IA invalida nao pode alterar progresso',
      );
    }
  }

  void assertInteraction(SimInteractionContract contract) {
    if (contract.freeChatMode) {
      throw const SimConstitutionViolation(
        SimConstitutionalLaw.notChatbot,
        'SIM nao pode operar como chatbot solto',
      );
    }
    if (!contract.lessonStructured ||
        !contract.hasExplanation ||
        !contract.hasQuestion) {
      throw const SimConstitutionViolation(
        SimConstitutionalLaw.notChatbot,
        'SIM precisa de aula estruturada com explicacao e pergunta',
      );
    }
    if (!contract.hasOptions ||
        !contract.hasFeedbackPath ||
        !contract.hasEvidenceSignal) {
      throw const SimConstitutionViolation(
        SimConstitutionalLaw.notSuperficialQuiz,
        'SIM nao pode ser quiz superficial sem feedback e evidencia',
      );
    }
  }

  void assertLessonMaterial(LessonContent content) {
    assertInteraction(
      SimInteractionContract(
        lessonStructured: true,
        hasExplanation: content.explanation.trim().isNotEmpty,
        hasQuestion: content.question.trim().isNotEmpty,
        hasOptions:
            (content.options[AnswerLetter.A] ?? '').trim().isNotEmpty &&
            (content.options[AnswerLetter.B] ?? '').trim().isNotEmpty &&
            (content.options[AnswerLetter.C] ?? '').trim().isNotEmpty,
        hasFeedbackPath: content.correctAnswer.name.isNotEmpty,
        hasEvidenceSignal: true,
      ),
    );
  }

  AnswerLetter validateAnswerLetter(Object? value) {
    final raw = value is AnswerLetter ? value.name : value?.toString().trim();
    final answer = AnswerLetter.values.where((letter) => letter.name == raw);
    if (answer.length != 1) {
      throw const SimConstitutionViolation(
        SimConstitutionalLaw.notSuperficialQuiz,
        'resposta principal precisa ser A, B ou C',
      );
    }
    return answer.single;
  }

  DecisionSignal validateDecisionSignal(Object? value) {
    if (value is DecisionSignal) return value;
    final signal = value is num
        ? value.toInt()
        : int.tryParse(value?.toString().trim() ?? '');
    return switch (signal) {
      1 => DecisionSignal.one,
      2 => DecisionSignal.two,
      3 => DecisionSignal.three,
      _ => throw const SimConstitutionViolation(
        SimConstitutionalLaw.advanceRequiresEvidence,
        'sinal de confianca precisa ser 1, 2 ou 3',
      ),
    };
  }

  LessonAttempt validateAttempt(LessonAttempt attempt) {
    if (attempt.marker.trim().isEmpty) {
      throw const SimConstitutionViolation(
        SimConstitutionalLaw.advanceRequiresEvidence,
        'tentativa exige marker/itemId',
      );
    }
    if (attempt.ts <= 0) {
      throw const SimConstitutionViolation(
        SimConstitutionalLaw.advanceRequiresEvidence,
        'tentativa exige timestamp valido',
      );
    }
    validateAnswerLetter(attempt.letra);
    validateDecisionSignal(attempt.sinal);
    return attempt;
  }

  SimAnswerEvidence validateEvidence(SimAnswerEvidence evidence) {
    if (evidence.marker.trim().isEmpty) {
      throw const SimConstitutionViolation(
        SimConstitutionalLaw.advanceRequiresEvidence,
        'marker obrigatorio para evidencia',
      );
    }
    if (!evidence.validatedBySoftware) {
      throw const SimConstitutionViolation(
        SimConstitutionalLaw.softwareValidatesLearning,
        'correcao precisa ser validada pelo software',
      );
    }
    return evidence;
  }

  SimAdvanceGateResult evaluateAdvanceGate({
    required SimAnswerEvidence? evidence,
    required MasteryEvidence? masteryEvidence,
    Object? aiDecision,
  }) {
    if (evidence == null) {
      return const SimAdvanceGateResult(
        allowAdvance: false,
        reason: 'sem evidencia',
        law: SimConstitutionalLaw.advanceRequiresEvidence,
      );
    }
    final checked = validateEvidence(evidence);
    if (!checked.correct) {
      return const SimAdvanceGateResult(
        allowAdvance: false,
        reason: 'resposta incorreta',
        law: SimConstitutionalLaw.softwareValidatesLearning,
      );
    }
    if (masteryEvidence == null ||
        masteryEvidence.marker != checked.marker ||
        masteryEvidence.status != MasteryStatus.mastered) {
      return const SimAdvanceGateResult(
        allowAdvance: false,
        reason: 'dominio real ainda nao comprovado',
        law: SimConstitutionalLaw.advanceRequiresEvidence,
      );
    }
    return const SimAdvanceGateResult(
      allowAdvance: true,
      reason: 'software validou evidencia e dominio',
      law: SimConstitutionalLaw.advanceRequiresEvidence,
    );
  }

  void assertStateMutationAuthority({
    required String source,
    required bool touchesProgress,
  }) {
    final normalized = source.trim().toLowerCase();
    if (normalized == 'ai' && touchesProgress) {
      throw const SimConstitutionViolation(
        SimConstitutionalLaw.aiNotStateAuthority,
        'IA nao pode governar estado ou progresso',
      );
    }
    if (touchesProgress &&
        normalized != 'software' &&
        normalized != 'app' &&
        normalized != 'server') {
      throw const SimConstitutionViolation(
        SimConstitutionalLaw.softwareValidatesLearning,
        'mutacao de progresso exige autoridade do software',
      );
    }
  }

  bool canShowLessonText({
    required bool textReady,
    required String imageStatus,
    required String audioStatus,
  }) {
    return textReady;
  }

  int taskPriority(String kind) {
    return switch (kind) {
      'critical_state_save' => 0,
      'first_lesson_text' => 1,
      'current_lesson_text' => 2,
      'answer_validation' => 3,
      'image' || 'visual' => 6,
      'audio' => 7,
      'curriculum_expansion' => 8,
      _ => 9,
    };
  }
}
