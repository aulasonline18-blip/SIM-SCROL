import 'dart:async';

import '../core/signal_tracker.dart';
import '../constitution/sim_constitutional_contract.dart';
import '../external_ai/sim_ai_server_config.dart';
import '../lesson/dopamine_ready_window_engine.dart';
import '../lesson/lesson_models.dart';
import '../lesson/student_lesson_material_service.dart';
import '../media/audio_core.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import '../state/student_lesson_executor.dart';
import '../state/mastery_truth_engine.dart';
import '../state/student_state_store.dart';
import 'classroom_models.dart';
import 'lesson_answer_feedback.dart';
import 'lesson_material_controller.dart';
import 'lesson_position_engine.dart';
import 'server_advance_gate.dart';

class LessonAnswerProgressController {
  LessonAnswerProgressController({
    required this.stateService,
    required this.materialService,
    required this.materialController,
    this.store,
    this.audioCore,
    SignalTracker? signalTracker,
    MasteryTruthEngine? truthEngine,
    SimConstitutionalContract? constitutionalContract,
    this.serverAdvanceGateClient,
  }) : signalTracker = signalTracker ?? SignalTracker(stateService),
       constitutionalContract =
           constitutionalContract ?? const SimConstitutionalContract();

  final StudentLearningStateService stateService;
  final StudentLessonMaterialService materialService;
  final LessonMaterialController materialController;
  final StudentStateStore? store;
  final AudioCore? audioCore;
  final SignalTracker signalTracker;
  final SimConstitutionalContract constitutionalContract;
  final ServerAdvanceGateClient? serverAdvanceGateClient;

  void selecionar(LessonPositionState position, AnswerLetter letter) {
    audioCore?.stop();
    position.phase = ClassroomPhase.expanded(letter);
  }

  Future<void> enviarSinal({
    required String lessonLocalId,
    required String? topic,
    required LessonPositionState position,
    required DecisionSignal signal,
    required List<PlannedItem> baseItems,
  }) async {
    final phase = position.phase;
    final content = position.conteudo;
    final item = position.itemAtivo;
    if ((phase.type != ClassroomPhaseType.expandida &&
            phase.type != ClassroomPhaseType.avancoPendente) ||
        phase.letter == null ||
        content == null ||
        item == null) {
      return;
    }

    audioCore?.stop();
    constitutionalContract.assertLessonMaterial(content);
    final letter = phase.letter!;
    final correct = letter == content.correctAnswer;
    final constitutionalEvidence = SimAnswerEvidence(
      marker: item.marker,
      layer: position.layer,
      selectedAnswer: letter,
      signal: signal,
      correct: correct,
      validatedBySoftware: true,
    );
    constitutionalContract.validateEvidence(constitutionalEvidence);
    final questionId = [
      item.marker,
      'layer-${position.layer.value}',
      content.question,
    ].join('::');
    final answeredAt = DateTime.now().millisecondsSinceEpoch;
    final entry = QuestionHistoryEntry(
      id: questionId,
      text: content.question,
      options: [
        QuestionOptionEntry(
          id: AnswerLetter.A,
          text: content.options[AnswerLetter.A] ?? '',
        ),
        QuestionOptionEntry(
          id: AnswerLetter.B,
          text: content.options[AnswerLetter.B] ?? '',
        ),
        QuestionOptionEntry(
          id: AnswerLetter.C,
          text: content.options[AnswerLetter.C] ?? '',
        ),
      ],
      chosenOptionId: letter,
      correct: correct,
      imageUrl: position.imagem,
      answeredAt: answeredAt,
    );
    // Prevent double-tap (only block if the immediately preceding entry is identical)
    final lastEntry = position.history.isEmpty ? null : position.history.last;
    if (lastEntry == null ||
        lastEntry.id != entry.id ||
        lastEntry.chosenOptionId != entry.chosenOptionId) {
      position.history = [...position.history, entry];
    }

    final currentState = stateService.read(lessonLocalId);
    final request = currentState == null || position.isReviewAtivo
        ? null
        : ServerAdvanceGateRequest(
            lessonLocalId: lessonLocalId,
            userId: currentState.userId,
            marker: item.marker,
            itemIdx: position.itemIdx,
            layer: position.layer,
            selectedOption: letter,
            signal: signal,
            correct: correct,
            questionId: questionId,
            questionText: content.question,
            correctOption: content.correctAnswer,
            attempts: currentState.attempts,
            history: position.historia,
            highWaterMark: currentState.syncStatus?.highWaterMark,
            pending: currentState.auxRooms ?? const {},
            currentState: currentState,
            idempotencyKey: [
              lessonLocalId,
              item.marker,
              position.layer.value,
              letter.name,
              signal.value,
              questionId,
            ].join(':'),
          );
    if (request != null) {
      final pending = recordPendingServerAdvanceGate(
        state: currentState!,
        request: request,
        error: const SimExternalAiException(
          'Confirmacao de avanco pendente.',
          code: 'ADVANCE_GATE_CONFIRMATION_PENDING',
        ),
      );
      stateService.write(pending);
    }

    final message = buildLessonAnswerFeedback(
      correct: correct,
      signal: signal,
      isReview: position.isReviewAtivo,
    );
    position.phase = ClassroomPhase.completed(
      message: message,
      wasCorrect: correct,
      signal: signal,
    );
    final submittedAt = DateTime.now().millisecondsSinceEpoch;
    stateService.appendEvents(lessonLocalId, [
      StudentLearningEvent(
        type: 'ANSWER_SUBMITTED',
        ts: submittedAt,
        payload: {
          'marker': item.marker,
          'layer': position.layer.value,
          'letra': letter.name,
          'sinal': signal.value,
          'correct': correct,
          'isReview': position.isReviewAtivo,
        },
      ),
      StudentLearningEvent(
        type: 'SIGNAL_SUBMITTED',
        ts: submittedAt,
        payload: {
          'marker': item.marker,
          'layer': position.layer.value,
          'sinal': signal.value,
          'letra': letter.name,
        },
      ),
    ]);

    final remoteClient = serverAdvanceGateClient;
    if (remoteClient != null && request != null) {
      unawaited(
        _confirmServerAdvanceGate(
          remoteClient: remoteClient,
          request: request,
          topic: topic,
          position: position,
          baseItems: baseItems,
          letter: letter,
          signal: signal,
        ),
      );
    }
  }

  Future<void> _confirmServerAdvanceGate({
    required ServerAdvanceGateClient remoteClient,
    required ServerAdvanceGateRequest request,
    required String? topic,
    required LessonPositionState position,
    required List<PlannedItem> baseItems,
    required AnswerLetter letter,
    required DecisionSignal signal,
  }) async {
    try {
      final decision = await remoteClient.decide(request);
      final latestState =
          stateService.read(request.lessonLocalId) ?? request.currentState;
      if (latestState == null) return;
      final nextState = applyServerAdvanceGateDecision(
        state: latestState,
        request: request,
        decision: decision,
      );
      final savedState = stateService.write(
        nextState,
        acceptServerAuthority: true,
      );
      if (hasPendingCgPartTransition(savedState)) {
        position.phase = const ClassroomPhase.engineError(
          'aula_next_part_preparing',
        );
        return;
      }
      final view = activeLessonView(savedState);
      if (view != null && !view.ended) {
        materialService.maintainLessonReadyWindow(
          lessonLocalId: request.lessonLocalId,
          topic: topic,
          itemIdx: view.itemIdx,
          layer: view.layer,
          items: dopamineItemsFromCurriculum(baseItems),
          source: 'cyber.aula.server-advance-gate',
          priority: 'active',
          reason: 'server_decision_prepares_next_experience',
        );
      }
    } catch (error) {
      final latestState =
          stateService.read(request.lessonLocalId) ?? request.currentState;
      if (latestState == null) return;
      final pending = recordPendingServerAdvanceGate(
        state: latestState,
        request: request,
        error: error,
      );
      stateService.write(pending);
      if (position.phase.type == ClassroomPhaseType.processando &&
          position.phase.letter == letter &&
          position.phase.signal == signal) {
        position.phase = ClassroomPhase.advancePending(
          message: 'aula_advance_pending',
          letter: letter,
          signal: signal,
        );
      }
    }
  }

  Future<void> avancar({
    required String lessonLocalId,
    required String? topic,
    required LessonPositionState position,
    required List<PlannedItem> baseItems,
    required String idioma,
    required String academic,
  }) async {
    if (position.phase.type != ClassroomPhaseType.concluido) return;
    audioCore?.stop();
    final item = position.itemAtivo;
    final state = stateService.read(lessonLocalId);
    final view = state == null ? null : activeLessonView(state);
    if (item == null) {
      position.phase = const ClassroomPhase.doneEnd();
      stateService.appendEvent(
        lessonLocalId,
        StudentLearningEvent(
          type: 'FINAL_COMPLETION_ALLOWED',
          ts: DateTime.now().millisecondsSinceEpoch,
          payload: {
            'itemIdx': view?.itemIdx ?? position.itemIdx,
            'layer': (view?.layer ?? position.layer).value,
            'totalItens': baseItems.length,
            'mainAdvances': view?.mainAdvances ?? position.mainAdvances,
          },
        ),
      );
      return;
    }
    if (view == null || state == null) {
      position.phase = const ClassroomPhase.doneEnd();
      return;
    }
    if (!_hasEvidenceForCurrentPosition(state, position)) {
      stateService.appendEvent(
        lessonLocalId,
        StudentLearningEvent(
          type: 'ADVANCE_REJECTED_BY_CONSTITUTION',
          ts: DateTime.now().millisecondsSinceEpoch,
          payload: {
            'itemIdx': position.itemIdx,
            'layer': position.layer.value,
            'reason': 'advance_requires_evidence',
          },
        ),
      );
      return;
    }
    final activeState = state;
    if (!view.ended &&
        view.itemIdx == position.itemIdx &&
        view.layer == position.layer) {
      position.historia = view.historia;
      position.mainAdvances = view.mainAdvances;
      position.erros = view.erros;
      position.phase = const ClassroomPhase.loading();
      await materialController.carregar(
        lessonLocalId: lessonLocalId,
        topic: topic,
        position: position,
        idioma: idioma,
        academic: academic,
        mode: _modeForNextMaterial(activeState, position.isReviewAtivo),
        baseItems: baseItems,
        forceRefresh: true,
      );
      return;
    }

    position.loadingLayer = view.layer;
    position.itemIdx = view.itemIdx;
    position.layer = view.layer;
    position.erros = view.erros;
    position.historia = view.historia;
    position.mainAdvances = view.mainAdvances;
    if (view.ended) {
      position.phase = const ClassroomPhase.doneEnd();
      stateService.appendEvent(
        lessonLocalId,
        StudentLearningEvent(
          type: 'FINAL_COMPLETION_ALLOWED',
          ts: DateTime.now().millisecondsSinceEpoch,
          payload: {
            'itemIdx': view.itemIdx,
            'layer': view.layer.value,
            'totalItens': baseItems.length,
            'mainAdvances': view.mainAdvances,
          },
        ),
      );
      return;
    }

    materialService.maintainLessonReadyWindow(
      lessonLocalId: lessonLocalId,
      topic: topic,
      itemIdx: view.itemIdx,
      layer: view.layer,
      items: baseItems
          .map(
            (item) => DopamineWindowItem(text: item.text, marker: item.marker),
          )
          .toList(),
      source: 'cyber.aula.after-answer',
      priority: 'background',
      reason: 'answer_advanced_position',
    );
    position.phase = const ClassroomPhase.loading();
    await materialController.carregar(
      lessonLocalId: lessonLocalId,
      topic: topic,
      position: position,
      idioma: idioma,
      academic: academic,
      mode: _modeForNextMaterial(activeState, position.isReviewAtivo),
      baseItems: baseItems,
    );
  }

  LessonMode _modeForNextMaterial(
    StudentLearningState state,
    bool isReviewAtivo,
  ) {
    if (isReviewAtivo) return LessonMode.reforco;
    final amparoLvl = state.progress?.amparoLvl ?? 0;
    if (amparoLvl > 0) return LessonMode.amparo;
    final nextAction = state.extra['next_action'];
    if (nextAction is Map && nextAction['action'] == 'needsReinforcement') {
      return LessonMode.reforco;
    }
    return LessonMode.session;
  }

  bool _hasEvidenceForCurrentPosition(
    StudentLearningState state,
    LessonPositionState position,
  ) {
    final marker = position.itemAtivo?.marker ?? state.current?.marker;
    if (marker == null || marker.trim().isEmpty) return false;
    return state.attempts.any(
      (attempt) => attempt.marker == marker && attempt.layer == position.layer,
    );
  }
}
