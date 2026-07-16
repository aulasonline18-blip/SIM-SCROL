import 'dart:async';

import '../core/signal_tracker.dart';
import '../constitution/sim_constitutional_contract.dart';
import '../lesson/dopamine_ready_window_engine.dart';
import '../lesson/lesson_models.dart';
import '../lesson/student_lesson_material_service.dart';
import '../media/audio_core.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import '../state/learning_decision_engine.dart';
import '../state/student_lesson_executor.dart';
import '../state/mastery_truth_engine.dart';
import '../state/student_state_store.dart';
import 'classroom_models.dart';
import 'lesson_answer_feedback.dart';
import 'lesson_material_controller.dart';
import 'lesson_position_engine.dart';

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
    final localAttempt = LessonAttempt(
      marker: item.marker,
      layer: position.layer,
      letra: letter,
      sinal: signal,
      correct: correct,
      ts: answeredAt,
    );
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
    final stateWithLocalEvidence =
        currentState == null || position.isReviewAtivo
        ? currentState
        : _withLocalAttemptEvidence(currentState, localAttempt);
    if (stateWithLocalEvidence != null && !position.isReviewAtivo) {
      stateService.write(
        _withLocalAdvanceDecision(stateWithLocalEvidence, item.marker),
        scheduleShadow: false,
      );
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
      final completedPhase = position.phase;
      final next = nextLessonSlot(position.itemIdx, position.layer, baseItems);
      if (next != null &&
          _hasCorrectEvidenceForCurrentPosition(state, position)) {
        final previousItemIdx = position.itemIdx;
        final previousLayer = position.layer;
        final previousLoadingLayer = position.loadingLayer;
        final previousErros = position.erros;
        final previousHistoria = position.historia;
        final previousMainAdvances = position.mainAdvances;
        final previousPhase = position.phase;
        position.loadingLayer = next.layer;
        position.itemIdx = next.idx;
        position.layer = next.layer;
        position.erros = 0;
        position.historia = view.historia;
        position.mainAdvances = view.mainAdvances;
        final loadedPrepared = materialController.carregarRapidoSePronto(
          lessonLocalId: lessonLocalId,
          topic: topic,
          position: position,
          idioma: idioma,
          academic: academic,
          mode: _modeForNextMaterial(activeState, position.isReviewAtivo),
          baseItems: baseItems,
        );
        if (loadedPrepared) {
          _recordLocalPendingAdvanceDisplayed(
            lessonLocalId: lessonLocalId,
            fromItemIdx: previousItemIdx,
            fromLayer: previousLayer,
            toItemIdx: next.idx,
            toLayer: next.layer,
            marker: position.itemAtivo?.marker,
          );
          return;
        }
        position.itemIdx = previousItemIdx;
        position.layer = previousLayer;
        position.loadingLayer = previousLoadingLayer;
        position.erros = previousErros;
        position.historia = previousHistoria;
        position.mainAdvances = previousMainAdvances;
        position.phase = previousPhase;
      }
      position.historia = view.historia;
      position.mainAdvances = view.mainAdvances;
      position.erros = view.erros;
      position.phase = ClassroomPhase.advancePending(
        message: 'aula_advance_preparing',
        letter: completedPhase.letter ?? AnswerLetter.A,
        signal: completedPhase.signal ?? DecisionSignal.one,
      );
      materialService.maintainLessonReadyWindow(
        lessonLocalId: lessonLocalId,
        topic: topic,
        itemIdx: position.itemIdx,
        layer: position.layer,
        items: _dopamineItemsFromCurriculum(baseItems),
        source: 'cyber.aula.advance-cache-miss',
        priority: 'active',
        reason: 'advance_cache_miss_prepares_without_blocking_touch',
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

  bool _hasCorrectEvidenceForCurrentPosition(
    StudentLearningState state,
    LessonPositionState position,
  ) {
    final marker = position.itemAtivo?.marker ?? state.current?.marker;
    if (marker == null || marker.trim().isEmpty) return false;
    for (final attempt in state.attempts.reversed) {
      if (attempt.marker == marker && attempt.layer == position.layer) {
        return attempt.correct;
      }
    }
    return false;
  }

  StudentLearningState _withLocalAttemptEvidence(
    StudentLearningState state,
    LessonAttempt attempt,
  ) {
    return state.copyWith(attempts: [...state.attempts, attempt]);
  }

  StudentLearningState _withLocalAdvanceDecision(
    StudentLearningState state,
    String marker,
  ) {
    final progress = state.progress;
    final curriculum = state.curriculum;
    if (progress == null || curriculum == null) return state;
    final decision = decideNextActionFromState(state);
    final lastCurrentAttempt = state.attempts.reversed
        .cast<LessonAttempt?>()
        .firstWhere(
          (attempt) =>
              attempt?.marker == marker && attempt?.layer == progress.layer,
          orElse: () => null,
        );
    final applied = applyStudentDecision(
      progress,
      decision,
      itemIdx: progress.itemIdx,
      layer: progress.layer,
      totalItems: curriculum.items.length,
      marker: marker,
      markCurrentComplete: lastCurrentAttempt?.correct == true,
    );
    if (!applied.applied) return state;
    final nextProgress = applied.nextProgress;
    final nextMarker =
        nextProgress.itemIdx >= 0 &&
            nextProgress.itemIdx < curriculum.items.length
        ? curriculum.items[nextProgress.itemIdx].marker
        : null;
    final ts = DateTime.now().millisecondsSinceEpoch;
    return state.copyWith(
      updatedAt: ts,
      current: LessonCurrent(
        itemIdx: nextProgress.itemIdx,
        marker: nextMarker,
        layer: nextProgress.layer,
        amparoLvl: nextProgress.amparoLvl,
      ),
      progress: nextProgress,
      events: [
        ...state.events,
        StudentLearningEvent(
          type: 'LOCAL_ADVANCE_DECIDED',
          ts: ts,
          payload: {
            'action': decision.actionType.name,
            'reason': decision.reason,
            'fromMarker': marker,
            'toMarker': nextMarker,
            'toItemIdx': nextProgress.itemIdx,
            'toLayer': nextProgress.layer.value,
            'source': 'sim_app_local_advance_engine',
          },
        ),
        StudentLearningEvent(
          type: 'NEXT_ACTION_DECIDED',
          ts: ts,
          payload: {
            'action': decision.actionType.name,
            'reason': decision.reason,
            'source': 'sim_app_local_advance_engine',
          },
        ),
      ],
    );
  }

  void _recordLocalPendingAdvanceDisplayed({
    required String lessonLocalId,
    required int fromItemIdx,
    required LessonLayer fromLayer,
    required int toItemIdx,
    required LessonLayer toLayer,
    required String? marker,
  }) {
    final latest = stateService.read(lessonLocalId);
    final progress = latest?.progress;
    if (latest == null || progress == null) return;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final eventPayload = <String, dynamic>{
      'lessonLocalId': lessonLocalId,
      'fromItemIdx': fromItemIdx,
      'fromLayer': fromLayer.value,
      'toItemIdx': toItemIdx,
      'toLayer': toLayer.value,
      'reason': 'prepared_experience_displayed_from_local_state',
      'remoteConfirmation': 'not_required',
    };
    final localPendingAdvance = <String, dynamic>{
      'fromItemIdx': fromItemIdx,
      'fromLayer': fromLayer.value,
      'toItemIdx': toItemIdx,
      'toLayer': toLayer.value,
      'remoteConfirmation': 'not_required',
      'updatedAt': ts,
    };
    if (marker != null) {
      eventPayload['marker'] = marker;
      localPendingAdvance['marker'] = marker;
    }
    stateService.write(
      latest.copyWith(
        updatedAt: ts,
        current: LessonCurrent(
          itemIdx: toItemIdx,
          marker: marker,
          layer: toLayer,
          amparoLvl: progress.amparoLvl,
        ),
        progress: progress.copyWith(
          itemIdx: toItemIdx,
          layer: toLayer,
          erros: 0,
        ),
        events: [
          ...latest.events,
          StudentLearningEvent(
            type: 'LOCAL_PENDING_ADVANCE_DISPLAYED',
            ts: ts,
            payload: eventPayload,
          ),
        ],
        extra: {...latest.extra, 'localPendingAdvance': localPendingAdvance},
      ),
    );
  }
}

List<DopamineWindowItem> _dopamineItemsFromCurriculum(List<PlannedItem> items) {
  return items
      .map((item) => DopamineWindowItem(text: item.text, marker: item.marker))
      .toList(growable: false);
}
