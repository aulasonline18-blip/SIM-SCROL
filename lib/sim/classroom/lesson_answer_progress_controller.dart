import 'dart:async';

import '../core/signal_tracker.dart';
import '../lesson/dopamine_ready_window_engine.dart';
import '../lesson/lesson_models.dart';
import '../lesson/student_lesson_material_service.dart';
import '../media/audio_core.dart';
import '../auxiliary/amparo_room_engine.dart';
import '../auxiliary/recovery_room_service.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import '../state/learning_decision_engine.dart';
import '../state/student_lesson_executor.dart';
import '../state/mastery_truth_engine.dart';
import '../state/student_state_store.dart';
import 'classroom_models.dart';
import 'lesson_answer_feedback.dart';
import 'local_advance_engine.dart';
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
    LocalAdvanceEngine? localAdvanceEngine,
    SimConstitutionalContract? constitutionalContract,
  }) : signalTracker = signalTracker ?? SignalTracker(stateService),
       truthEngine = truthEngine ?? const MasteryTruthEngine(),
       localAdvanceEngine = localAdvanceEngine ?? const LocalAdvanceEngine(),
       constitutionalContract =
           constitutionalContract ?? const SimConstitutionalContract();

  final StudentLearningStateService stateService;
  final StudentLessonMaterialService materialService;
  final LessonMaterialController materialController;
  final StudentStateStore? store;
  final AudioCore? audioCore;
  final SignalTracker signalTracker;
  final MasteryTruthEngine truthEngine;
  final LocalAdvanceEngine localAdvanceEngine;
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
    if (phase.type != ClassroomPhaseType.expandida ||
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
      final stateWithAmparo = const AmparoGate().recordOfficialAttempt(
        stateWithLocalEvidence,
        localAttempt,
        itemIdx: position.itemIdx,
      );
      final stateWithTruth = _withLocalMasteryEvidence(
        stateWithAmparo,
        item.marker,
      );
      stateService.write(
        _withLocalAdvanceDecision(stateWithTruth, item.marker),
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
      if (state != null &&
          _blockFinalCompletionForRecovery(lessonLocalId, state)) {
        return;
      }
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
      if (next != null && _hasEvidenceForCurrentPosition(state, position)) {
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
        await materialController.carregarTextoDeAvanco(
          lessonLocalId: lessonLocalId,
          topic: topic,
          position: position,
          idioma: idioma,
          academic: academic,
          mode: _modeForNextMaterial(activeState, position.isReviewAtivo),
          baseItems: baseItems,
        );
        if (position.phase.type == ClassroomPhaseType.lendo &&
            position.conteudo != null) {
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
      final targetItemIdx = next?.idx ?? view.itemIdx;
      final targetLayer = next?.layer ?? view.layer;
      final targetMarker =
          targetItemIdx >= 0 && targetItemIdx < baseItems.length
          ? baseItems[targetItemIdx].marker
          : item.marker;
      position.phase = ClassroomPhase.advancePending(
        message: 'aula_advance_preparing',
        letter: completedPhase.letter ?? AnswerLetter.A,
        signal: completedPhase.signal ?? DecisionSignal.one,
      );
      _recordLocalAdvancePending(
        lessonLocalId: lessonLocalId,
        fromItemIdx: position.itemIdx,
        fromLayer: position.layer,
        toItemIdx: targetItemIdx,
        toLayer: targetLayer,
        fromMarker: item.marker,
        toMarker: targetMarker,
        letter: completedPhase.letter ?? AnswerLetter.A,
        signal: completedPhase.signal ?? DecisionSignal.one,
      );
      materialService.maintainLessonReadyWindow(
        lessonLocalId: lessonLocalId,
        topic: topic,
        itemIdx: targetItemIdx,
        layer: targetLayer,
        items: _dopamineItemsFromCurriculum(baseItems),
        source: 'cyber.aula.advance-cache-miss',
        priority: 'background',
        reason: 'advance_cache_miss_prepares_without_blocking_touch',
      );
      return;
    }

    if (!view.ended &&
        (view.itemIdx != position.itemIdx || view.layer != position.layer)) {
      final completedPhase = position.phase;
      final previousItemIdx = position.itemIdx;
      final previousLayer = position.layer;
      final previousLoadingLayer = position.loadingLayer;
      final previousErros = position.erros;
      final previousHistoria = position.historia;
      final previousMainAdvances = position.mainAdvances;
      final targetMarker = view.itemIdx >= 0 && view.itemIdx < baseItems.length
          ? baseItems[view.itemIdx].marker
          : item.marker;

      position.loadingLayer = view.layer;
      position.itemIdx = view.itemIdx;
      position.layer = view.layer;
      position.erros = view.erros;
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
          toItemIdx: view.itemIdx,
          toLayer: view.layer,
          marker: targetMarker,
        );
        return;
      }
      await materialController.carregarTextoDeAvanco(
        lessonLocalId: lessonLocalId,
        topic: topic,
        position: position,
        idioma: idioma,
        academic: academic,
        mode: _modeForNextMaterial(activeState, position.isReviewAtivo),
        baseItems: baseItems,
      );
      if (position.phase.type == ClassroomPhaseType.lendo &&
          position.conteudo != null) {
        _recordLocalPendingAdvanceDisplayed(
          lessonLocalId: lessonLocalId,
          fromItemIdx: previousItemIdx,
          fromLayer: previousLayer,
          toItemIdx: view.itemIdx,
          toLayer: view.layer,
          marker: targetMarker,
        );
        return;
      }

      position.itemIdx = previousItemIdx;
      position.layer = previousLayer;
      position.loadingLayer = previousLoadingLayer;
      position.erros = previousErros;
      position.historia = previousHistoria;
      position.mainAdvances = previousMainAdvances;
      position.phase = ClassroomPhase.advancePending(
        message: 'aula_advance_preparing',
        letter: completedPhase.letter ?? AnswerLetter.A,
        signal: completedPhase.signal ?? DecisionSignal.one,
      );
      _recordLocalAdvancePending(
        lessonLocalId: lessonLocalId,
        fromItemIdx: previousItemIdx,
        fromLayer: previousLayer,
        toItemIdx: view.itemIdx,
        toLayer: view.layer,
        fromMarker: item.marker,
        toMarker: targetMarker,
        letter: completedPhase.letter ?? AnswerLetter.A,
        signal: completedPhase.signal ?? DecisionSignal.one,
      );
      materialService.maintainLessonReadyWindow(
        lessonLocalId: lessonLocalId,
        topic: topic,
        itemIdx: view.itemIdx,
        layer: view.layer,
        items: _dopamineItemsFromCurriculum(baseItems),
        source: 'cyber.aula.advance-cache-miss',
        priority: 'background',
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
      if (_blockFinalCompletionForRecovery(lessonLocalId, state)) {
        return;
      }
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

    position.phase = ClassroomPhase.advancePending(
      message: 'aula_advance_preparing',
      letter: position.phase.letter ?? AnswerLetter.A,
      signal: position.phase.signal ?? DecisionSignal.one,
    );
    _recordLocalAdvancePending(
      lessonLocalId: lessonLocalId,
      fromItemIdx: position.itemIdx,
      fromLayer: position.layer,
      toItemIdx: view.itemIdx,
      toLayer: view.layer,
      fromMarker: item.marker,
      toMarker: view.itemIdx >= 0 && view.itemIdx < baseItems.length
          ? baseItems[view.itemIdx].marker
          : item.marker,
      letter: position.phase.letter ?? AnswerLetter.A,
      signal: position.phase.signal ?? DecisionSignal.one,
    );
    materialService.maintainLessonReadyWindow(
      lessonLocalId: lessonLocalId,
      topic: topic,
      itemIdx: view.itemIdx,
      layer: view.layer,
      items: _dopamineItemsFromCurriculum(baseItems),
      source: 'cyber.aula.advance-cache-miss',
      priority: 'background',
      reason: 'advance_cache_miss_prepares_without_blocking_touch',
    );
  }

  bool _blockFinalCompletionForRecovery(
    String lessonLocalId,
    StudentLearningState state,
  ) {
    if (!shouldBlockFinalCompletionByRecoveryGate(state)) return false;
    stateService.appendEvent(
      lessonLocalId,
      StudentLearningEvent(
        type: 'FINAL_COMPLETION_BLOCKED_BY_PENDING',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'pendingCount': ((state.auxRooms?['pendingMap'] as List?) ?? const [])
              .whereType<Map>()
              .where((entry) => entry['status'] == 'pending')
              .length,
          'requiresRecovery': true,
        },
      ),
    );
    return true;
  }

  LessonMode _modeForNextMaterial(
    StudentLearningState state,
    bool isReviewAtivo,
  ) {
    if (isReviewAtivo) return LessonMode.reforco;
    return LessonMode.session;
  }

  bool reavaliarAvancoPendente({
    required String lessonLocalId,
    required String? topic,
    required LessonPositionState position,
    required List<PlannedItem> baseItems,
    required String idioma,
    required String academic,
  }) {
    if (position.phase.type != ClassroomPhaseType.avancoPendente) {
      return false;
    }
    final state = stateService.read(lessonLocalId);
    final pending = state?.extra['advancePending'];
    if (state == null || pending is! Map) return false;
    final toItemIdx = (pending['toItemIdx'] as num?)?.toInt();
    final toLayer = LessonLayerValue.fromValue(pending['toLayer']);
    final toMarker = (pending['toMarker'] as String?)?.trim();
    if (toItemIdx == null || toItemIdx < 0 || toItemIdx >= baseItems.length) {
      return false;
    }
    final target = baseItems[toItemIdx];
    if (toMarker != null && toMarker.isNotEmpty && target.marker != toMarker) {
      return false;
    }

    final previousItemIdx = position.itemIdx;
    final previousLayer = position.layer;
    final previousLoadingLayer = position.loadingLayer;
    final previousErros = position.erros;
    final previousHistoria = position.historia;
    final previousMainAdvances = position.mainAdvances;
    final previousPhase = position.phase;

    position.itemIdx = toItemIdx;
    position.layer = toLayer;
    position.loadingLayer = toLayer;
    position.erros = 0;
    position.historia = state.progress?.historia ?? position.historia;
    position.mainAdvances =
        state.progress?.mainAdvances ?? position.mainAdvances;
    final loadedPrepared = materialController.carregarRapidoSePronto(
      lessonLocalId: lessonLocalId,
      topic: topic,
      position: position,
      idioma: idioma,
      academic: academic,
      mode: _modeForNextMaterial(state, target.isReview),
      baseItems: baseItems,
    );
    if (!loadedPrepared) {
      final failed = state.queuedActions.any((job) {
        if (job['type'] != 'PREPARE_READY_WINDOW' ||
            job['status'] != 'failed') {
          return false;
        }
        final payload = job['payload'];
        if (payload is! Map) return false;
        if ((payload['itemIdx'] as num?) == null || payload['layer'] == null) {
          return true;
        }
        return (payload['itemIdx'] as num?)?.toInt() == toItemIdx &&
            (LessonLayerValue.fromValue(payload['layer']) == toLayer ||
                payload['layer'] is num ||
                payload['layer'] is String) &&
            (toMarker == null ||
                toMarker.isEmpty ||
                (payload['marker'] as String?) == toMarker ||
                payload['marker'] == null);
      });
      position.itemIdx = previousItemIdx;
      position.layer = previousLayer;
      position.loadingLayer = previousLoadingLayer;
      position.erros = previousErros;
      position.historia = previousHistoria;
      position.mainAdvances = previousMainAdvances;
      position.phase = previousPhase;
      if (failed) {
        _updateAdvancePendingStatus(
          lessonLocalId: lessonLocalId,
          status: 'preparing',
        );
        materialService.maintainLessonReadyWindow(
          lessonLocalId: lessonLocalId,
          topic: topic,
          itemIdx: toItemIdx,
          layer: toLayer,
          items: _dopamineItemsFromCurriculum(baseItems),
          source: 'cyber.aula.advance-pending-recover',
          priority: 'background',
          reason: 'advance_pending_failed_job_recovered_without_manual_retry',
        );
        return true;
      }
      return false;
    }
    _recordLocalPendingAdvanceDisplayed(
      lessonLocalId: lessonLocalId,
      fromItemIdx: (pending['fromItemIdx'] as num?)?.toInt() ?? previousItemIdx,
      fromLayer: LessonLayerValue.fromValue(
        pending['fromLayer'] ?? previousLayer.value,
      ),
      toItemIdx: toItemIdx,
      toLayer: toLayer,
      marker: target.marker,
    );
    return true;
  }

  bool _hasEvidenceForCurrentPosition(
    StudentLearningState state,
    LessonPositionState position,
  ) {
    final marker = position.itemAtivo?.marker ?? state.current?.marker;
    if (marker == null || marker.trim().isEmpty) return false;
    return localAdvanceEngine.hasEvidenceForCurrentPosition(state, position);
  }

  StudentLearningState _withLocalAttemptEvidence(
    StudentLearningState state,
    LessonAttempt attempt,
  ) {
    return state.copyWith(attempts: [...state.attempts, attempt]);
  }

  StudentLearningState _withLocalMasteryEvidence(
    StudentLearningState state,
    String marker,
  ) {
    final evidence = truthEngine.evaluateMarker(state, marker);
    final withTruth = truthEngine.writeTruthToState(state, evidence);
    final ts = DateTime.now().millisecondsSinceEpoch;
    return withTruth.copyWith(
      events: [
        ...withTruth.events,
        StudentLearningEvent(
          type: 'MASTERY_EVIDENCE_EVALUATED',
          ts: ts,
          payload: {
            ...evidence.toJson(),
            'source': 'sim_app_local_truth_engine',
            'remoteConfirmation': 'not_required',
          },
        ),
      ],
    );
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
        extra: {
          ...latest.extra,
          'localPendingAdvance': localPendingAdvance,
          'advancePending': null,
        },
      ),
    );
  }

  void _recordLocalAdvancePending({
    required String lessonLocalId,
    required int fromItemIdx,
    required LessonLayer fromLayer,
    required int toItemIdx,
    required LessonLayer toLayer,
    required String fromMarker,
    required String toMarker,
    required AnswerLetter letter,
    required DecisionSignal signal,
  }) {
    final latest = stateService.read(lessonLocalId);
    if (latest == null) return;
    final ts = DateTime.now().millisecondsSinceEpoch;
    stateService.write(
      latest.copyWith(
        updatedAt: ts,
        extra: {
          ...latest.extra,
          'advancePending': {
            'status': 'preparing',
            'fromItemIdx': fromItemIdx,
            'fromLayer': fromLayer.value,
            'fromMarker': fromMarker,
            'toItemIdx': toItemIdx,
            'toLayer': toLayer.value,
            'toMarker': toMarker,
            'letter': letter.name,
            'signal': signal.value,
            'startedAt': ts,
            'reason': 'material_missing_after_valid_decision',
          },
        },
        events: [
          ...latest.events,
          StudentLearningEvent(
            type: 'ADVANCE_PENDING_WAITING_FOR_MATERIAL',
            ts: ts,
            payload: {
              'fromItemIdx': fromItemIdx,
              'fromLayer': fromLayer.value,
              'fromMarker': fromMarker,
              'toItemIdx': toItemIdx,
              'toLayer': toLayer.value,
              'toMarker': toMarker,
              'reason': 'material_missing_after_valid_decision',
            },
          ),
        ],
      ),
    );
  }

  void _updateAdvancePendingStatus({
    required String lessonLocalId,
    required String status,
  }) {
    final latest = stateService.read(lessonLocalId);
    final pending = latest?.extra['advancePending'];
    if (latest == null || pending is! Map) return;
    stateService.write(
      latest.copyWith(
        extra: {
          ...latest.extra,
          'advancePending': {
            ...Map<String, dynamic>.from(pending),
            'status': status,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
        },
      ),
    );
  }
}

List<DopamineWindowItem> _dopamineItemsFromCurriculum(List<PlannedItem> items) {
  return items
      .map((item) => DopamineWindowItem(text: item.text, marker: item.marker))
      .toList(growable: false);
}
