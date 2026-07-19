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
      canonicalStore?.patchState(lessonLocalId, (state) {
        return state.copyWith(
          extra: {...state.extra, 'warmup': lesson.toJson()},
        );
      });
      if (route == '/cyber/curriculo') {
        navigationState.openRoute('/cyber/warmup');
      }
      _notifyFromChild();
      unawaited(_tryOpenOfficialAula(source: 'warmup_ready'));
    } catch (error) {
      if (!_isCurrentExperience(lessonLocalId, generation)) return;
      debugPrint('[SIM] WARMUP_PREPARE_FAILED');
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
        unawaited(controller.startTest());
      }
    } else {
      controller?.skip();
    }
    unawaited(launchExperience());
    navigationState.openRoute('/cyber/warmup');
    _notifyFromChild();
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
      _warmupCoordinator.markAulaNavigationStarted();
      _syncEntryCoordinatorFields();
      debugPrint('[SIM] ENTRY_NAVIGATE_AULA source=$source placement=false');
      navigationState.openRoute('/cyber/aula');
      await openAulaRuntime();
      return;
    }
    final placement = controller.store.readPlacement();
    if (placement.choice == 'find_my_point' &&
        controller.destination != '/cyber/aula') {
      navigationState.openRoute('/cyber/placement');
      _notifyFromChild();
      return;
    }
    if (controller.destination != '/cyber/aula') return;
    _warmupCoordinator.markAulaNavigationStarted();
    _syncEntryCoordinatorFields();
    debugPrint('[SIM] ENTRY_NAVIGATE_AULA source=$source placement=true');
    await openAulaAfterPlacementIfReady();
  }

  bool _hasLocalOfficialAulaState() {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty || prefs == null) return false;
    try {
      final organism = _organismForActiveLesson();
      final state = organism.stateService.read(id);
      return state?.curriculum?.items.isNotEmpty == true &&
          (state?.current != null || state?.progress != null);
    } catch (_) {
      return false;
    }
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
    }
    final text = response?.explanation;
    if (text != null && text.trim().isNotEmpty) {
      unawaited(
        _doubtAudioFor().speakDoubt(
          text,
          lang: lang,
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
