part of 'lab_session.dart';

extension LabSessionPlacementFlowExtensions on LabSession {
  bool _activateReadyNextCurriculumPartIfNeeded(String currentLessonId) {
    if (prefs == null) return false;
    final organism = _organismForActiveLesson();
    final state = organism.stateService.read(currentLessonId);
    if (state == null || state.curriculum?.items.isNotEmpty != true) {
      return false;
    }
    final itemCount = state.curriculum!.items.length;
    final progressIdx = state.progress?.itemIdx ?? state.current?.itemIdx ?? 0;
    final finished =
        state.extra['finalizada'] == true ||
        progressIdx >= itemCount ||
        (state.progress?.mainAdvances ?? 0) >= itemCount;
    if (!finished) return false;

    final next = readyNextCurriculumPart(
      service: organism.stateService,
      state: state,
    );
    if (next == null) return false;
    lessonLocalId = next.lessonLocalId;
    navigationState.openRoute('/cyber/aula');
    return true;
  }

  void preparationDone() {
    lessonUiState.markPreparationDone();
    navigationState.openRoute('/cyber/warmup');
    _enqueueActiveLessonForRemoteVaultSync(reason: 'active_lesson_changed');
  }

  PlacementRouteController? get activePlacementController {
    if (lessonLocalId == null || lessonLocalId!.trim().isEmpty) return null;
    try {
      return _organismForActiveLesson().placementController;
    } catch (_) {
      return null;
    }
  }

  Future<void> openAulaAfterPlacementIfReady() async {
    final controller = activePlacementController;
    if (controller?.destination != '/cyber/aula') return;
    _applyPlacementStartMarkerIfNeeded();
    navigationState.openRoute('/cyber/aula');
    await openAulaRuntime();
  }

  void _applyPlacementStartMarkerIfNeeded() {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return;

    final organism = _organismForActiveLesson();
    final placement = organism.placementService.read();
    final startMarker = placement.startMarker?.trim();
    if (startMarker == null || startMarker.isEmpty) return;

    final state = organism.stateService.read(id);
    final curriculum = state?.curriculum;
    if (state == null || curriculum == null || curriculum.items.isEmpty) {
      return;
    }

    final itemIndex =
        placement.startItemIdx != null &&
            placement.startItemIdx! >= 0 &&
            placement.startItemIdx! < curriculum.items.length &&
            curriculum.items[placement.startItemIdx!].marker == startMarker
        ? placement.startItemIdx!
        : curriculum.items.indexWhere((item) => item.marker == startMarker);
    if (itemIndex < 0) return;
    if (state.current?.marker == startMarker &&
        state.current?.itemIdx == itemIndex) {
      return;
    }

    final totalItems = curriculum.items.length;
    final percent = totalItems == 0
        ? 0
        : ((itemIndex / totalItems) * 100).round().clamp(0, 100);

    organism.stateService.mutate(id, (currentState) {
      final progress = currentState.progress;
      return currentState.copyWith(
        current: LessonCurrent(
          itemIdx: itemIndex,
          marker: startMarker,
          layer: LessonLayer.l1,
          amparoLvl: 0,
        ),
        progress:
            progress?.copyWith(
              itemIdx: itemIndex,
              layer: LessonLayer.l1,
              amparoLvl: 0,
              mainAdvances: itemIndex > progress.mainAdvances
                  ? itemIndex
                  : progress.mainAdvances,
              totalItems: totalItems,
              pctAvanco: percent,
            ) ??
            LessonProgress(
              itemIdx: itemIndex,
              layer: LessonLayer.l1,
              erros: 0,
              amparoLvl: 0,
              historia: const [],
              mainAdvances: itemIndex,
              concluidos: const [],
              pendentesMarkers: const [],
              totalItems: totalItems,
              pctAvanco: percent,
            ),
        events: [
          ...currentState.events,
          StudentLearningEvent(
            type: 'PLACEMENT_START_APPLIED',
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: {
              'start_marker': startMarker,
              'item_idx': itemIndex,
              'total_items': totalItems,
            },
          ),
        ],
      );
    });
    _enqueueActiveLessonForRemoteVaultSync(reason: 'active_lesson_changed');
  }

  void skipPlacement() {
    choosePlacementStartFromZeroThenPreparation();
  }

  Future<void> startPlacementTest() async {
    final controller = activePlacementController;
    if (controller == null) {
      lessonUiState.startPlacement();
      _notifyFromChild();
      return;
    }
    controller.chooseFindMyPoint();
    _notifyFromChild();
    await controller.startTest();
    _notifyFromChild();
  }

  void answerPlacement(String choiceId) {
    final controller = activePlacementController;
    if (controller == null) return;
    controller.answer(choiceId);
    _notifyFromChild();
  }

  void startPlacement() => lessonUiState.startPlacement();

  void finishPlacement() {
    final controller = activePlacementController;
    if (controller != null) {
      controller.continueToAula();
      if (_entryOfficialLessonReady || _hasLocalOfficialAulaState()) {
        unawaited(_tryOpenOfficialAula(source: 'placement_finished'));
      } else {
        warmupWaitingForOfficialLesson = false;
        navigationState.openRoute('/cyber/aula');
        unawaited(openAulaRuntime());
      }
      _notifyFromChild();
      return;
    }
    lessonUiState.finishPlacement();
    if (_entryOfficialLessonReady || _hasLocalOfficialAulaState()) {
      unawaited(_tryOpenOfficialAula(source: 'placement_finished'));
    } else {
      navigationState.openRoute('/cyber/aula');
      unawaited(openAulaRuntime());
    }
  }
}
