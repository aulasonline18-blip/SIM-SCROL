part of 'lab_session.dart';

extension LabSessionWarmupFlowExtensions on LabSession {
  Future<void> _prepareWarmupLesson({
    required String lessonLocalId,
    required String objective,
    required Map<String, dynamic> onboarding,
    required String academic,
    required int generation,
  }) async {
    final service =
        warmupBridgeService ??
        (prefs == null ? null : _organismForActiveLesson().warmupBridgeService);
    if (service == null || objective.trim().isEmpty) {
      _warmupCoordinator.markWarmupUnavailable();
      _syncEntryCoordinatorFields();
      warmupLoading = false;
      warmupError = null;
      _notifyFromChild();
      if (_isCurrentExperience(lessonLocalId, generation)) {
        unawaited(_tryOpenOfficialAula(source: 'warmup_unavailable'));
      }
      return;
    }
    warmupLoading = true;
    warmupError = null;
    _notifyFromChild();
    try {
      final lesson = await service.prepare(
        WarmupBridgeRequest(
          lessonLocalId: lessonLocalId,
          objective: objective,
          ficha: JsonMap.from(onboarding),
          locale: localeContract,
          academic: academic,
        ),
      );
      if (!_isCurrentExperience(lessonLocalId, generation)) return;
      warmupLesson = lesson;
      warmupLoading = false;
      warmupError = null;
      _recordOnboardingFlowEvent(
        'PREPARATION_GATE_WARMUP_READY',
        payload: const {'route': '/cyber/curriculo'},
      );
      canonicalStore?.patchState(lessonLocalId, (state) {
        return state.copyWith(
          extra: {...state.extra, 'warmup': lesson.toJson()},
        );
      });
      _notifyFromChild();
      unawaited(_tryOpenOfficialAula(source: 'warmup_ready'));
    } catch (error) {
      if (!_isCurrentExperience(lessonLocalId, generation)) return;
      SecureLogger.log('SIM', 'WARMUP_PREPARE_FAILED');
      _warmupCoordinator.markWarmupUnavailable();
      _syncEntryCoordinatorFields();
      warmupLoading = false;
      warmupError = humanErrorMessage(
        error,
        fallback:
            'Nao consegui preparar o aquecimento agora. Continue para a aula principal.',
      );
      _notifyFromChild();
      unawaited(_tryOpenOfficialAula(source: 'warmup_failed'));
    }
  }

  void chooseWarmupAnswer(String answer) {
    final normalized = answer.trim().toUpperCase();
    if (!const {'A', 'B', 'C'}.contains(normalized)) return;
    warmupSelectedAnswer = normalized;
    final id = lessonLocalId;
    final lesson = warmupLesson;
    if (id != null && lesson != null) {
      canonicalStore?.patchState(id, (state) {
        return state.copyWith(
          extra: {
            ...state.extra,
            'warmup': {
              ...lesson.toJson(),
              'selectedAnswer': normalized,
              'selectedAt': DateTime.now().millisecondsSinceEpoch,
            },
          },
        );
      });
    }
    _notifyFromChild();
  }

  void openWarmupBridge({bool preparePlacement = false}) {
    final controller = activePlacementController;
    if (preparePlacement) {
      if (controller != null) {
        controller.chooseFindMyPoint();
        _prefetchPlacementTest(controller);
      } else {
        _writePlacementChoiceFallback(
          status: 'requested',
          choice: 'find_my_point',
          source: 'adaptive_t02',
          reason: 'Nivelamento escolhido antes do controlador ativo.',
        );
      }
    } else {
      if (controller != null) {
        controller.skip();
      } else {
        _writePlacementChoiceFallback(
          status: 'skipped',
          choice: 'start_from_zero',
          source: 'choice_gate',
          reason: 'Aluno escolheu começar do início.',
          finished: true,
        );
      }
    }
    _recordOnboardingFlowEvent(
      preparePlacement
          ? 'PLACEMENT_CHOICE_FIND_MY_POINT_IMMEDIATE'
          : 'PLACEMENT_CHOICE_START_FROM_ZERO_IMMEDIATE',
      payload: const {'route': '/cyber/curriculo'},
    );
    unawaited(launchExperience());
    if (warmupLesson != null) {
      _recordOnboardingFlowEvent(
        'WARMUP_OPENED_WITH_READY_LESSON',
        payload: const {'source': 'legacy_bridge'},
      );
      navigationState.openRoute('/cyber/warmup');
    } else {
      _recordOnboardingFlowEvent(
        'PREPARATION_GATE_WAITING_FOR_WARMUP',
        payload: const {'source': 'legacy_bridge'},
      );
      navigationState.openRoute('/cyber/curriculo');
    }
    _notifyFromChild();
  }

  void choosePlacementStartFromZeroThenPreparation() {
    final controller = activePlacementController;
    if (controller != null) {
      controller.skip();
    } else {
      _writePlacementChoiceFallback(
        status: 'skipped',
        choice: 'start_from_zero',
        source: 'choice_gate',
        reason: 'Aluno escolheu começar do início.',
        finished: true,
      );
    }
    _recordOnboardingFlowEvent(
      'PLACEMENT_CHOICE_START_FROM_ZERO_IMMEDIATE',
      payload: const {'route': '/cyber/curriculo'},
    );
    unawaited(launchExperience());
    navigationState.openRoute('/cyber/curriculo');
    _notifyFromChild();
  }

  void choosePlacementFindMyPointThenPreparation() {
    final controller = activePlacementController;
    if (controller != null) {
      controller.chooseFindMyPoint();
      _prefetchPlacementTest(controller);
    } else {
      _writePlacementChoiceFallback(
        status: 'requested',
        choice: 'find_my_point',
        source: 'adaptive_t02',
        reason: 'Aluno pediu para encontrar o ponto inicial.',
      );
    }
    _recordOnboardingFlowEvent(
      'PLACEMENT_CHOICE_FIND_MY_POINT_IMMEDIATE',
      payload: const {'route': '/cyber/curriculo'},
    );
    unawaited(launchExperience());
    navigationState.openRoute('/cyber/curriculo');
    _notifyFromChild();
  }

  bool get canContinueFromPreparationGate {
    if (warmupLesson != null) return true;
    if (entryStatus != 'primeira_aula_pronta') return false;
    return !_warmupCoordinator.warmupExpected ||
        _warmupCoordinator.warmupUnavailableAfterExpected ||
        warmupError != null;
  }

  Future<void> continueFromPreparationToWarmup() async {
    if (warmupLesson != null) {
      _recordOnboardingFlowEvent(
        'PREPARATION_GATE_RELEASED_TO_WARMUP',
        payload: const {'route': '/cyber/warmup'},
      );
      _recordOnboardingFlowEvent(
        'WARMUP_OPENED_WITH_READY_LESSON',
        payload: const {'source': 'preparation_gate'},
      );
      navigationState.openRoute('/cyber/warmup');
      _notifyFromChild();
      return;
    }
    if (entryStatus != 'primeira_aula_pronta') {
      _recordOnboardingFlowEvent(
        'PREPARATION_GATE_WAITING_FOR_WARMUP',
        payload: {'entry_status': entryStatus},
      );
      unawaited(launchExperience());
      _notifyFromChild();
      return;
    }
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return;
    if (!_isFirstAulaTextRendered(aulaSnapshot)) {
      entryStatus = 't02_running';
      _notifyFromChild();
      await _ensureFirstAulaRenderedBeforeRelease(
        id: id,
        generation: _experienceGeneration,
      );
      if (!_isFirstAulaTextRendered(aulaSnapshot)) return;
      entryStatus = 'primeira_aula_pronta';
      _notifyFromChild();
    }
    if (_warmupCoordinator.warmupUnavailableAfterExpected) {
      _recordOnboardingFlowEvent(
        'PREPARATION_GATE_OFFICIAL_READY',
        payload: const {'warmup': 'unavailable'},
      );
      await _tryOpenOfficialAula(source: 'preparation_continue');
      return;
    }
    if (!_warmupCoordinator.warmupExpected) {
      _recordOnboardingFlowEvent(
        'PREPARATION_GATE_OFFICIAL_READY',
        payload: const {'warmup': 'not_expected'},
      );
      await _tryOpenOfficialAula(source: 'preparation_continue');
    }
  }

  void _prefetchPlacementTest(PlacementRouteController controller) {
    _recordOnboardingFlowEvent(
      'PLACEMENT_PRETEST_PREFETCH_STARTED',
      payload: const {'route': '/cyber/curriculo'},
    );
    unawaited(
      controller
          .startTest()
          .then((_) {
            if (controller.questionScreen() != null ||
                controller.resultScreen() != null) {
              _recordOnboardingFlowEvent(
                'PLACEMENT_PRETEST_READY_BEFORE_OPEN',
                payload: const {'route': '/cyber/placement'},
              );
            }
            _notifyFromChild();
          })
          .catchError((Object error, StackTrace stackTrace) {
            _recordRuntimeAudit(
              'PLACEMENT_PREFETCH_FAILURE',
              source: 'LabSession.placement_prefetch',
              error: error,
              stackTrace: stackTrace,
            );
            _notifyFromChild();
          }),
    );
  }

  void _writePlacementChoiceFallback({
    required String status,
    required String choice,
    required String source,
    required String reason,
    bool finished = false,
  }) {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    canonicalStore?.patchState(id, (state) {
      return state.copyWith(
        placement: {
          ...?state.placement,
          'status': status,
          'choice': choice,
          'source': source,
          'reason': reason,
          'updated_at': now,
          if (finished) 'finished_at': now,
          if (!finished) 'started_at': now,
        },
      );
    }, allowLocalHousekeeping: true);
  }

  Future<void> continueFromWarmupToAula() async {
    warmupWaitingForOfficialLesson = _warmupCoordinator.requestContinue();
    _notifyFromChild();
    if (warmupWaitingForOfficialLesson) return;
    await _tryOpenOfficialAula(source: 'warmup_continue');
  }

  void _resetEntryCoordinator({required bool warmupExpected}) {
    _warmupCoordinator.reset(warmupExpected: warmupExpected);
    _syncEntryCoordinatorFields();
  }

  void _syncEntryCoordinatorFields() {
    _entryOfficialLessonReady = _warmupCoordinator.officialLessonReady;
  }

  Future<void> _tryOpenOfficialAula({required String source}) async {
    _syncEntryCoordinatorFields();
    if (!_warmupCoordinator.shouldOpenOfficialAula(
      route: route,
      hasLocalOfficialAulaState: _hasLocalOfficialAulaState(),
    )) {
      return;
    }
    warmupWaitingForOfficialLesson = false;
    final controller = activePlacementController;
    if (controller == null) {
      if (_placementChoiceRequiresGate()) {
        navigationState.openRoute('/cyber/placement');
        _notifyFromChild();
        return;
      }
      _warmupCoordinator.markAulaNavigationStarted();
      _syncEntryCoordinatorFields();
      SecureLogger.log('SIM', 'ENTRY_NAVIGATE_AULA', {
        'source': source,
        'placement': false,
      });
      navigationState.openRoute('/cyber/aula');
      await openAulaRuntime();
      return;
    }
    final placement = controller.store.readPlacement();
    if (placement.choice == 'find_my_point' &&
        controller.destination != '/cyber/aula') {
      navigationState.openRoute('/cyber/placement');
      unawaited(_startPlacementAfterOfficialLesson(controller));
      _notifyFromChild();
      return;
    }
    if (controller.destination != '/cyber/aula') return;
    _warmupCoordinator.markAulaNavigationStarted();
    _syncEntryCoordinatorFields();
    SecureLogger.log('SIM', 'ENTRY_NAVIGATE_AULA', {
      'source': source,
      'placement': true,
    });
    await openAulaAfterPlacementIfReady();
  }

  bool _placementChoiceRequiresGate() {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return false;
    final placement = canonicalStore?.readState(id).placement;
    if (placement == null) return false;
    return placement['choice'] == 'find_my_point' &&
        placement['status'] != 'done' &&
        placement['status'] != 'skipped';
  }

  Future<void> _startPlacementAfterOfficialLesson(
    PlacementRouteController controller,
  ) async {
    await controller.startTest();
    _notifyFromChild();
  }

  void _recordOnboardingFlowEvent(String type, {JsonMap payload = const {}}) {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    canonicalStore?.patchState(id, (state) {
      return state.copyWith(
        events: [
          ...state.events,
          StudentLearningEvent(type: type, ts: now, payload: payload),
        ],
      );
    }, allowLocalHousekeeping: true);
  }
}

extension LabSessionDoubtFlowExtensions on LabSession {
  void toggleDoubt() {
    final opening = !lessonUiState.doubtOpen;
    lessonUiState.toggleDoubt();
    final context = _doubtEventContext(requestId: _currentDoubtRequestId());
    if (context != null) {
      _recordDoubtEvent(opening ? 'DOUBT_OPENED' : 'DOUBT_DISMISSED', context);
    }
  }

  Future<void> submitDoubt(DoubtInputDraft input) async {
    if (lessonUiState.doubt.status == DoubtStatus.processing) return;
    final validation = input.validate();
    if (validation != null) {
      setDoubt(
        DoubtState(
          status: DoubtStatus.error,
          progress: 0,
          sheetOpen: true,
          error: validation,
        ),
      );
      return;
    }
    if (lessonUiState.doubtOpen) lessonUiState.toggleDoubt();
    final snapshot = aulaSnapshot;
    final content = snapshot?.conteudo;
    final requestId = _nextDoubtRequestId();
    final submittedPayload = _doubtEventContext(
      requestId: requestId,
      input: input,
    );
    if (submittedPayload != null) {
      _recordDoubtEvent('DOUBT_SUBMITTED', submittedPayload);
      _recordDoubtEvent('DOUBT_SUBMITTED_IMMEDIATE', submittedPayload);
    }
    if (prefs == null || _runningUnderFlutterTest) {
      _failDoubt(submittedPayload);
      return;
    }
    if (content == null) {
      _failDoubt(submittedPayload);
      return;
    }
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) {
      _failDoubt(submittedPayload);
      return;
    }
    final state = _activeCanonicalState;
    final profile = state?.profile;
    final controller = LessonDoubtController(
      caller: DoubtT02Caller(
        client: SimServerT02Client(config: _serverConfig()),
      ),
    );
    setDoubt(const DoubtState(status: DoubtStatus.processing, progress: 15));
    await controller.submitDoubt(
      lessonLocalId: id,
      profile: AuxRoomProfile(
        stableLang: profile?.stableLang ?? stableLang ?? selectedLanguageCode,
        academicLevel:
            profile?.academicLevel ?? profile?.nivel ?? 'ensino_medio',
        preferredName: profile?.preferredName ?? preferredName,
        notes: studentProfileNotes.isNotEmpty ? studentProfileNotes : null,
        localeContract: localeContract,
        extra: profile?.extra ?? const {},
      ),
      itemText: snapshot?.itemText ?? content.question,
      currentContent: '${content.explanation}\n\n${content.question}'.trim(),
      currentQuestion: content.question,
      currentOptions: content.options,
      layer: currentAulaLayer,
      itemIdx: (state?.current?.itemIdx ?? state?.progress?.itemIdx ?? 0),
      marker: snapshot?.itemMarker ?? state?.current?.marker,
      input: input,
      isScopeStillCurrent: _isDoubtScopeStillCurrent,
      onStaleIgnored: (scope) {
        final payload = submittedPayload;
        if (payload == null) return;
        _recordDoubtEvent('DOUBT_ANSWER_STALE_IGNORED', {
          ...payload,
          'scopeKey': scope.key,
        });
      },
    );
    setDoubt(controller.state);
    if (controller.state.status == DoubtStatus.explaining) {
      _finishDoubtSuccess(
        requestId: requestId,
        input: input,
        response: controller.state.response,
        id: id,
        marker: snapshot?.itemMarker,
        lang: profile?.stableLang ?? stableLang ?? selectedLanguageCode,
      );
    } else if (controller.state.status == DoubtStatus.error &&
        submittedPayload != null) {
      _recordDoubtEvent('DOUBT_FAILED', submittedPayload);
    }
  }

  void _failDoubt(Map<String, dynamic>? payload) {
    if (payload != null) _recordDoubtEvent('DOUBT_FAILED', payload);
    setDoubt(
      const DoubtState(
        status: DoubtStatus.error,
        progress: 0,
        error: defaultDoubtError,
      ),
    );
  }

  void _finishDoubtSuccess({
    required String requestId,
    required DoubtInputDraft input,
    required DoubtResponse? response,
    required String id,
    required String? marker,
    required String? lang,
  }) {
    final readyPayload = _doubtEventContext(
      requestId: requestId,
      input: input,
      response: response,
    );
    if (readyPayload != null) {
      _recordDoubtEvent('DOUBT_ANSWER_READY', readyPayload);
      _recordDoubtEvent('DOUBT_ANSWER_APPLIED', readyPayload);
    }
    final text = response?.explanation;
    if (text != null && text.trim().isNotEmpty) {
      unawaited(
        _doubtAudioFor().speakDoubt(
          text,
          lang: lang ?? localeContract.explanationLanguage,
          localeContract: localeContract,
          lessonKey: '$id:${marker ?? 'item'}',
        ),
      );
    }
    _enqueueActiveLessonForRemoteVaultSync(reason: 'active_lesson_changed');
  }

  String _currentDoubtRequestId() => 'doubt-open-${_doubtRequestSeq + 1}';

  String _nextDoubtRequestId() {
    _doubtRequestSeq += 1;
    return 'doubt-${DateTime.now().microsecondsSinceEpoch}-$_doubtRequestSeq';
  }

  bool _isDoubtScopeStillCurrent(DoubtRequestScope scope) {
    final state = _activeCanonicalState;
    final snapshot = aulaSnapshot;
    final marker = snapshot?.itemMarker ?? state?.current?.marker;
    final itemIdx = state?.current?.itemIdx ?? state?.progress?.itemIdx ?? 0;
    final layer =
        state?.current?.layer ?? state?.progress?.layer ?? LessonLayer.l1;
    return lessonLocalId == scope.lessonLocalId &&
        marker == scope.marker &&
        itemIdx == scope.itemIdx &&
        layer == scope.layer;
  }

  Map<String, dynamic>? _doubtEventContext({
    required String requestId,
    DoubtInputDraft? input,
    DoubtResponse? response,
  }) {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return null;
    final state = _activeCanonicalState;
    final snapshot = aulaSnapshot;
    final image = input?.image;
    return {
      'lessonLocalId': id,
      'marker': snapshot?.itemMarker ?? state?.current?.marker,
      'itemIdx': state?.current?.itemIdx ?? state?.progress?.itemIdx ?? 0,
      'layer':
          (state?.current?.layer ?? state?.progress?.layer ?? LessonLayer.l1)
              .value,
      'hasText': (input?.cleanText ?? '').isNotEmpty,
      'hasImage': image != null,
      'imageType': image?.type,
      'imageSize': image?.size,
      'requestId': requestId,
      'idempotencyKey': requestId,
      'source': 'doubt',
      'authoritative': false,
      'writesProgress': false,
      'writesTruth': false,
      'writesMastery': false,
      'itemAdvanced': false,
      'layerChanged': false,
      'nextAction': 'return_to_lesson',
      if (response != null) 'explanationLength': response.explanation.length,
      if (response != null) 'visualTrigger': response.visualTrigger,
    };
  }

  void _recordDoubtEvent(String type, Map<String, dynamic> payload) {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return;
    canonicalStore?.patchState(
      id,
      (state) => aux_rooms.recordDoubtAuxiliaryEvent(
        state,
        type: type,
        payload: payload,
      ),
      allowLocalHousekeeping: true,
    );
  }
}
