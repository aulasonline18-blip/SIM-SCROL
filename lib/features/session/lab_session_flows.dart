part of 'lab_session.dart';

const Duration _autoAdvanceAfterFeedbackDelay = Duration(milliseconds: 100);
String humanErrorMessage(
  Object? error, {
  String fallback =
      'Nao consegui concluir isso agora. Tente novamente em instantes.',
}) {
  final raw = error?.toString() ?? '';
  final lower = raw.toLowerCase();
  if (lower.contains('401') || lower.contains('403')) {
    return 'Sua sessao precisa ser renovada. Entre novamente para continuar.';
  }
  if (lower.contains('timeout')) {
    return 'A conexao demorou demais. Tente novamente em instantes.';
  }
  if (lower.contains('socket') || lower.contains('network')) {
    return 'A conexao parece instavel. Salvamos seu ponto e vamos tentar novamente.';
  }
  if (raw.contains('{') ||
      raw.contains('}') ||
      lower.contains('exception') ||
      lower.contains('stacktrace') ||
      lower.contains('api key') ||
      lower.contains('bearer')) {
    return fallback;
  }
  return raw.trim().isEmpty ? fallback : raw.trim();
}

extension LabSessionFlowExtensions on LabSession {
  void startNewLessonFromDrawer() {
    stopActiveAudio(notify: false);
    _resetActiveLessonMedia(clearSnapshot: true, clearSubscriptions: true);
    lessonLocalId = null;
    entryForm
      ..freeText = ''
      ..preferredName = ''
      ..attachmentsText = ''
      ..studentProfileNotes = ''
      ..clearGuidedAnswers()
      ..clearAttachments()
      ..resetLanguage();
    lessonUiState
      ..entryStatus = 'idle'
      ..entryError = null
      ..placementStarted = false
      ..placementDone = false
      ..doubtOpen = false
      ..reviewRoom = null
      ..recoveryRoom = null
      ..amparoRoom = null
      ..resetDoubt();
    navigationState.openRoute('/cyber/objeto');
    _notifyFromChild();
  }

  void openCreditsFromDrawer() {
    const target = '/cyber/aula';
    if (!authed) {
      goLogin(target: target);
      return;
    }
    returnTo = target;
    navigationState.openRoute('/creditos?returnTo=/cyber/aula');
    _notifyFromChild();
  }

  Future<bool> openDrawerLocalLesson(String lessonLocalId) async {
    final local = _readExistingLocalState(lessonLocalId);
    if (local != null && !_stateDeleted(local)) {
      _prepareDrawerLessonOpen(lessonLocalId);
      unawaited(_openDrawerLessonRuntimeWithHotText(lessonLocalId));
      return true;
    }
    return openDrawerCloudLesson(lessonLocalId);
  }

  void _prepareDrawerLessonOpen(String lessonLocalId) {
    final generation = ++_aulaRuntimeGeneration;
    stopActiveAudio(notify: false);
    aulaOpeningTransition = AulaOpeningTransition(
      targetLessonLocalId: lessonLocalId,
      previousSnapshot: aulaSnapshot,
      transitionStartedAt: DateTime.now(),
      status: AulaOpeningStatus.openingFromMenu,
      generation: generation,
    );
    _resetActiveLessonMedia(clearSnapshot: false, clearSubscriptions: true);
    aulaRuntimeLoading = false;
    aulaMenuLessonWaiting = true;
    aulaRuntimeError = null;
    this.lessonLocalId = lessonLocalId;
    navigationState.openRoute('/cyber/aula');
    _notifyFromChild();
  }

  Future<bool> deleteDrawerLocalLesson(String lessonLocalId) async {
    final store = canonicalStore;
    if (store == null) return false;
    store.tombstoneLesson(lessonLocalId);
    var cloudOk = true;
    if (authed) {
      cloudOk = await deleteDrawerCloudLesson(lessonLocalId);
    }
    if (this.lessonLocalId == lessonLocalId) {
      this.lessonLocalId = null;
      navigationState.goPortal();
    }
    _notifyFromChild();
    return cloudOk;
  }

  void retryExperience() {
    entryStatus = 'pedido_recebido';
    entryError = null;
    _notifyFromChild();
    unawaited(launchExperience());
  }

  void _saveProfileToState({
    required String id,
    required String objective,
    required String language,
    required SimLocaleContract locale,
    JsonMap guided = const {},
  }) {
    canonicalStore?.patchState(id, (state) {
      final base = _stateDeleted(state)
          ? StudentLearningState.empty(
              lessonLocalId: id,
              userId: userId,
              now: DateTime.now().millisecondsSinceEpoch,
            )
          : state;
      return base.copyWith(
        userId: userId,
        localeContract: locale,
        profile: base.profile.copyWith(
          preferredName: preferredName.trim().isEmpty
              ? base.profile.preferredName
              : preferredName.trim(),
          language: locale.learningLocale,
          stableLang: locale.explanationLanguage,
          objetivo: objective,
          targetTopic: objective,
          sessionGoal: objective,
          extra: {
            ...base.profile.extra,
            ...guided,
            ...locale.toJson(),
            'localeContract': locale.toJson(),
          },
        ),
      );
    }, allowLocalHousekeeping: true);
    canonicalStore?.appendEvent(
      lessonLocalId: id,
      type: 'STUDENT_FORM_SUBMITTED',
      payload: {
        'objective_length': objective.length,
        'language': language,
        ...locale.toJson(),
        'localeContract': locale.toJson(),
      },
      source: 'lab_session',
      userId: userId,
    );
  }

  String? _cleanOrNull(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  String _academicFromOnboarding(JsonMap guidedProfile) {
    for (final key in const ['academic_level', 'ACADEMIC_LEVEL', 'nivel']) {
      final value = guidedProfile[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return 'incerto';
  }

  String _studentProfileNotes({
    required String objective,
    required String guidedSummary,
    required String attachments,
  }) {
    return [
      objective,
      if (guidedSummary.trim().isNotEmpty)
        '--- guided_entry_profile ---\n$guidedSummary',
      if (attachments.trim().isNotEmpty) attachments,
    ].join('\n\n').trim();
  }

  void openCredits() {
    if (!authed) {
      goLogin(target: '/creditos');
      return;
    }
    navigationState.openRoute('/creditos');
    _notifyFromChild();
  }

  void openSupport(String path) {
    navigationState.openRoute(path);
    _notifyFromChild();
  }

  void openExternalDoor(String url) =>
      unawaited(navigationState.openExternalDoor(url));

  void openCheckoutReturn() => navigationState.openRoute('/checkout/return');

  StripeEnvironment get _stripeEnvironment =>
      SimEnvironment.stripeEnvironment == 'live'
      ? StripeEnvironment.live
      : StripeEnvironment.sandbox;

  Future<String?> startCreditsCheckout(String packId) async {
    if (!authed || (authSession.userId ?? '').trim().isEmpty) {
      return 'login_required';
    }
    _paymentReturnStore.saveReturnTo(
      route == '/creditos' ? '/cyber/aula' : route,
    );
    if (SimEnvironment.useGooglePlayBilling) {
      try {
        final outcome = await _playBilling().purchaseCreditPack(
          CreditPackIdWire.fromWire(packId),
        );
        switch (outcome.status) {
          case PlayBillingPurchaseStatus.completed:
            credits = outcome.balance;
            authSession.isUnlimited = false;
            _loadCreditsFromServer(keepCurrent: true);
            _notifyFromChild();
            return null;
          case PlayBillingPurchaseStatus.pending:
            return 'Compra pendente no Google Play.';
          case PlayBillingPurchaseStatus.canceled:
            return 'Compra cancelada.';
          case PlayBillingPurchaseStatus.failed:
            return outcome.error ?? 'google_play_billing_failed';
        }
      } catch (error) {
        return error.toString();
      }
    }
    final client = SimServerPaymentsClient(config: _serverConfig());
    try {
      final result = await client.createCreditsCheckoutHosted(
        CreateCreditsCheckoutHostedInput(
          packId: packId,
          successUrl:
              '${SimEnvironment.checkoutReturnOrigin}/checkout/return?session_id={CHECKOUT_SESSION_ID}',
          cancelUrl:
              '${SimEnvironment.checkoutReturnOrigin}/creditos?canceled=1',
          environment: _stripeEnvironment,
        ).validate(),
      );
      if (!result.ok) return result.error ?? 'checkout_failed';
      final url = result.url;
      if (url == null || url.isEmpty) return 'checkout_url_missing';
      openExternalDoor(url);
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  PlayBillingFunctions _playBilling() {
    return _playBillingFunctions ??= GooglePlayBillingFunctions(
      grantGateway: SimServerPlayBillingGrantClient(config: _serverConfig()),
    );
  }

  Future<CheckoutReturnState> confirmCheckoutReturn(String? sessionId) async {
    final controller = CheckoutReturnController(
      paymentsFunctions: SimServerPaymentsClient(config: _serverConfig()),
      returnStore: _paymentReturnStore,
      environment: _stripeEnvironment,
    );
    final state = await controller.confirm(sessionId);
    if (state.status == CheckoutStatusKind.complete) {
      authSession.credits = state.balance;
      authSession.isUnlimited = false;
      _notifyFromChild();
    }
    return state;
  }

  Future<SupabaseSession?> _drawerSession() async {
    if (!authed) return null;
    return _sessionProviderForDrawer().currentSession();
  }

  Future<List<StudentStateSummaryRow>> listDrawerCloudLessons() async {
    final local = _listDrawerLocalLessonSummaries();
    final session = await _drawerSession();
    if (session == null) return local;
    final rows = await _cloudFunctionsForDrawer().listStudentStateSummaries(
      session,
    );
    final byId = <String, StudentStateSummaryRow>{
      for (final row in local) row.lessonLocalId: row,
    };
    for (final row in rows.where((row) => !row.deleted)) {
      byId.putIfAbsent(row.lessonLocalId, () => row);
    }
    return byId.values.toList(growable: false);
  }

  Future<bool> openDrawerCloudLesson(String lessonLocalId) async {
    final local = _readExistingLocalState(lessonLocalId);
    if (local != null && !_stateDeleted(local)) {
      _prepareDrawerLessonOpen(lessonLocalId);
      unawaited(_openDrawerLessonRuntimeWithHotText(lessonLocalId));
      unawaited(_reconcileDrawerCloudLessonInBackground(lessonLocalId));
      return true;
    }
    final generation = ++_aulaRuntimeGeneration;
    aulaOpeningTransition = AulaOpeningTransition(
      targetLessonLocalId: lessonLocalId,
      previousSnapshot: aulaSnapshot,
      transitionStartedAt: DateTime.now(),
      status: AulaOpeningStatus.hydrating,
      generation: generation,
    );
    stopActiveAudio(notify: false);
    _resetActiveLessonMedia(clearSnapshot: false, clearSubscriptions: true);
    aulaRuntimeLoading = false;
    aulaMenuLessonWaiting = true;
    aulaRuntimeError = null;
    this.lessonLocalId = lessonLocalId;
    navigationState.openRoute('/cyber/aula');
    _notifyFromChild();
    final session = await _drawerSession();
    if (session == null) {
      if (_isCurrentAulaRuntime(lessonLocalId, generation)) {
        aulaRuntimeError = 'Sessao indisponivel para hidratar a aula.';
        aulaMenuLessonWaiting = false;
        _notifyFromChild();
      }
      return false;
    }
    final row = await _cloudFunctionsForDrawer().getStudentStateByLesson(
      lessonLocalId,
      session,
    );
    final rowLessonLocalId = row?.lessonLocalId.trim() ?? '';
    final hydratedLessonLocalId = rowLessonLocalId.isNotEmpty
        ? rowLessonLocalId
        : lessonLocalId.trim();
    final state = row?.state;
    if (state == null || _stateDeleted(state)) {
      if (_isCurrentAulaRuntime(lessonLocalId, generation)) {
        aulaRuntimeError = 'Aula remota indisponivel.';
        aulaMenuLessonWaiting = false;
        _notifyFromChild();
      }
      return false;
    }
    final hydrated = state.copyWith(
      lessonLocalId: hydratedLessonLocalId,
      profile: state.profile.copyWith(
        extra: {...state.profile.extra, 'lessonLocalId': hydratedLessonLocalId},
      ),
      extra: {
        ...state.extra,
        'lessonLocalId': hydratedLessonLocalId,
        'remoteHydratedAt': DateTime.now().millisecondsSinceEpoch,
        'remoteHydratedSource': 'drawer_cloud_lesson',
        'remoteHydratedWithoutMaterial':
            state.currentLessonMaterial == null &&
            state.readyLessonMaterials.isEmpty,
      },
    );
    canonicalStore?.writeState(hydrated);
    _prepareDrawerLessonOpen(hydrated.lessonLocalId);
    unawaited(_openDrawerLessonRuntimeWithHotText(hydrated.lessonLocalId));
    return true;
  }

  Future<void> _openDrawerLessonRuntimeWithHotText(String lessonLocalId) async {
    await openAulaRuntime(
      menuOpenPriority: true,
      suppressReadyWindowUntilVisibleLessonReady: true,
    );
    if (lessonLocalId != this.lessonLocalId) return;
    if (prefs == null) return;

    final organism = _organismForActiveLesson();
    final state = organism.stateService.read(lessonLocalId);
    final current = state?.current;
    final progress = state?.progress;
    final curriculum = state?.curriculum;
    if (state == null || curriculum?.items.isNotEmpty != true) return;

    final itemIdx = (current?.itemIdx ?? progress?.itemIdx ?? 0).clamp(
      0,
      curriculum!.items.length - 1,
    );
    final item = curriculum.items[itemIdx];
    final layer = current?.layer ?? progress?.layer ?? LessonLayer.l1;
    final marker = current?.marker ?? item.marker;
    final topic = curriculum.topic.trim().isNotEmpty
        ? curriculum.topic
        : state.profile.objetivo;

    void keepOfflineWindowWarm() {
      organism.materialService.prepareReadyWindowInBackground(
        lessonLocalId: lessonLocalId,
        topic: topic,
        itemIdx: itemIdx,
        layer: layer,
        marker: marker,
        source: 'drawer.aula.offline-window',
      );
    }

    if (_drawerAulaTextReady(aulaSnapshot)) {
      keepOfflineWindowWarm();
    }
  }

  bool _drawerAulaTextReady(LessonRuntimeSnapshot? snapshot) {
    final content = snapshot?.conteudo;
    if (snapshot?.hasCurriculum != true || content == null) return false;
    final optionsReady = content.options.values
        .where((option) => option.trim().isNotEmpty)
        .length;
    return content.explanation.trim().isNotEmpty &&
        content.question.trim().isNotEmpty &&
        optionsReady >= 3;
  }

  List<StudentStateSummaryRow> _listDrawerLocalLessonSummaries() {
    final store = canonicalStore;
    if (store == null) return const [];
    final rows = <StudentStateSummaryRow>[];
    for (final state in store.listLocalStates(includeDeleted: false)) {
      final row = summarizeStudentStateRow(
        StudentStateRow(
          lessonLocalId: state.lessonLocalId,
          state: state,
          highWaterMark: store.highWaterMark(state),
          schemaVersion: 1,
          updatedAt: state.updatedAt > 0
              ? DateTime.fromMillisecondsSinceEpoch(
                  state.updatedAt,
                ).toIso8601String()
              : null,
        ),
      );
      if (row != null && !row.deleted) rows.add(row);
    }
    return rows;
  }

  Future<void> _reconcileDrawerCloudLessonInBackground(
    String lessonLocalId,
  ) async {
    try {
      final session = await _drawerSession();
      if (session == null) {
        _recordRuntimeAudit(
          'REMOTE_IDENTITY_MISSING',
          source: 'LabSession.drawer_cloud_reconcile',
          details: {'targetLessonLocalId': lessonLocalId},
        );
        return;
      }
      await _cloudFunctionsForDrawer().getStudentStateByLesson(
        lessonLocalId,
        session,
      );
    } catch (error, stackTrace) {
      _recordRuntimeAudit(
        'DRAWER_CLOUD_RECONCILE_FAILED',
        source: 'LabSession.drawer_cloud_reconcile',
        details: {'targetLessonLocalId': lessonLocalId},
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> renameDrawerCloudLesson(
    String lessonLocalId,
    String name,
  ) async {
    final clean = name.trim();
    if (clean.isEmpty) return false;
    final session = await _drawerSession();
    if (session == null) return false;
    final local = _readExistingLocalState(lessonLocalId);
    final remote = local == null
        ? (await _cloudFunctionsForDrawer().getStudentStateByLesson(
            lessonLocalId,
            session,
          ))?.state
        : null;
    final base = local ?? remote;
    if (base == null || _stateDeleted(base)) return false;
    final renamed = base.copyWith(
      profile: base.profile.copyWith(
        objetivo: clean,
        targetTopic: clean,
        sessionGoal: clean,
      ),
      extra: {
        ...base.extra,
        'renamedAt': DateTime.now().millisecondsSinceEpoch,
      },
    );
    canonicalStore?.writeState(renamed);
    _enqueueLessonForRemoteVaultSync(lessonLocalId, reason: 'drawer_renamed');
    return true;
  }

  Future<bool> deleteDrawerCloudLesson(String lessonLocalId) async {
    final session = await _drawerSession();
    if (session == null) return false;
    await _cloudFunctionsForDrawer().deleteStudentStateByLesson(
      lessonLocalId,
      session,
    );
    if (_readExistingLocalState(lessonLocalId) != null) {
      canonicalStore?.tombstoneLesson(lessonLocalId);
    }
    if (this.lessonLocalId == lessonLocalId) {
      this.lessonLocalId = null;
      navigationState.goPortal();
    }
    return true;
  }

  StudentLearningState? _readExistingLocalState(String lessonLocalId) {
    final store = canonicalStore;
    if (store == null) return null;
    for (final state in store.listLocalStates(includeDeleted: true)) {
      if (state.lessonLocalId == lessonLocalId) return state;
    }
    return null;
  }

  bool _stateDeleted(StudentLearningState state) {
    return state.extra['deletedAt'] != null ||
        (state.extra['syncInfo'] is Map &&
            (state.extra['syncInfo'] as Map)['deletedAt'] != null);
  }

  LessonAudioController _audioControllerFor(String id) {
    final existing = _lessonAudioController;
    if (existing != null && existing.lessonLocalId == id) return existing;
    existing?.pararAudio();
    audioPlaying = false;
    audioLoading = false;
    final store = canonicalStore;
    final testAudio = _runningUnderFlutterTest;
    final controller = LessonAudioController(
      lessonLocalId: id,
      preference: _audioPreference,
      mediaService: StudentLessonMediaService(
        audioCore: AudioCore(
          preference: _audioPreference,
          playback: testAudio
              ? NoopAudioPlaybackAdapter()
              : PlatformAudioAdapter(),
          generatedAudioClient: testAudio
              ? null
              : SimServerGeneratedAudioClient(config: _serverConfig()),
          stableLangProvider: () => localeContract.explanationLanguage,
        ),
        readState: (lessonLocalId) =>
            store?.readState(lessonLocalId) ??
            StudentLearningState.empty(lessonLocalId: lessonLocalId),
        writeState: (state) => store?.writeState(state) ?? state,
      ),
    );
    _lessonAudioController = controller;
    return controller;
  }

  DoubtAudio _doubtAudioFor() {
    final existing = _doubtAudio;
    if (existing != null) return existing;
    final testAudio = _runningUnderFlutterTest;
    final audio = DoubtAudio(
      preference: _audioPreference,
      audioCore: AudioCore(
        preference: _audioPreference,
        playback: testAudio
            ? NoopAudioPlaybackAdapter()
            : PlatformAudioAdapter(),
        generatedAudioClient: testAudio
            ? null
            : SimServerGeneratedAudioClient(config: _serverConfig()),
        stableLangProvider: () => localeContract.explanationLanguage,
        onGeneratedAudioError: (_) {
          audioError = 'Áudio remoto indisponível.';
          _notifyFromChild();
        },
      ),
    );
    _doubtAudio = audio;
    return audio;
  }

  LessonContent _currentLessonContentForAudio() {
    final content = aulaSnapshot?.conteudo;
    if (content == null) {
      throw StateError('Conteudo de aula ainda nao esta pronto para audio.');
    }
    return content;
  }

  void _resetActiveLessonMedia({
    bool clearSnapshot = false,
    bool clearSubscriptions = false,
  }) {
    if (clearSubscriptions) {
      _lessonImageUnsubscribe?.call();
      _lessonImageUnsubscribe = null;
      _activeLessonMediaKey = null;
      _activeLessonMediaOrganism = null;
    }
    imageStatus = 'idle';
    imageError = null;
    lessonUiState.imageRequestId = null;
    lessonUiState.imageCacheKey = null;
    lessonUiState.imageCharged = null;
    lessonUiState.imageCacheHit = null;
    lessonUiState.imageRetryable = null;
    if (clearSnapshot) aulaSnapshot = null;
  }

  void _syncImageStateFromSnapshot() {
    if (aulaSnapshot?.imagem != null &&
        aulaSnapshot!.imagem!.trim().isNotEmpty) {
      imageStatus = 'ready';
      imageError = null;
      _syncImageMetadataFromSnapshot();
      return;
    }
    final metadata = aulaSnapshot?.imageMetadata;
    final status = metadata?.status?.trim().toLowerCase();
    if (status == null || status.isEmpty) return;
    _syncImageMetadataFromSnapshot();
    if (status == 'no_image') {
      imageStatus = 'idle';
      imageError = null;
      return;
    }
    if (_isPendingLessonImageStatus(status)) {
      imageStatus = 'loading';
      imageError = null;
      return;
    }
    if (status == 'failed' || status == 'error' || status == 'paid_offer') {
      imageStatus = 'failed';
      imageError = metadata?.n3Reason ?? t('aula_image_unavailable');
    }
  }

  bool _isPendingLessonImageStatus(String status) {
    return status == 'idle' ||
        status == 'queued' ||
        status == 'pending' ||
        status == 'processing' ||
        status == 'running';
  }

  void _syncImageMetadataFromSnapshot() {
    final metadata = aulaSnapshot?.imageMetadata;
    lessonUiState.imageRequestId = metadata?.requestId;
    lessonUiState.imageCacheKey = metadata?.cacheKey;
    lessonUiState.imageCharged = metadata?.charged;
    lessonUiState.imageCacheHit = metadata?.cacheHit;
    lessonUiState.imageRetryable = metadata?.retryable;
  }

  void _bindActiveLessonMedia(SimOrganism organism) {
    final key = organism.lessonRuntimeEngine.activeLessonKey();
    if (key == null) return;
    if (key == _activeLessonMediaKey &&
        identical(organism, _activeLessonMediaOrganism)) {
      return;
    }
    _lessonImageUnsubscribe?.call();
    _resetActiveLessonMedia();
    _activeLessonMediaKey = key;
    _activeLessonMediaOrganism = organism;
    _syncImageStateFromSnapshot();
    _lessonImageUnsubscribe = organism.eventBus.subscribe(key, (lesson) {
      final applied = organism.lessonRuntimeEngine.applyLessonUpdateForKey(
        key,
        lesson,
      );
      if (!applied) {
        _recordRuntimeAudit(
          'MEDIA_UPDATE_KEY_MISMATCH',
          source: 'LabSession.lesson_media_listener',
          details: {'activeKey': key},
        );
        return;
      }
      aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
      if (lesson.imagem != null && lesson.imagem!.trim().isNotEmpty) {
        imageStatus = 'ready';
        imageError = null;
      }
      _syncImageMetadataFromSnapshot();
      _notifyFromChild();
    });
  }

  SimOrganism _organismForActiveLesson() {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) {
      throw StateError('lessonLocalId ausente para abrir organismo SIM.');
    }
    final organism = simOrganismProvider.forLesson(id);
    _activeOrganism = organism;
    return organism;
  }

  LessonContent _devLessonContent() => const LessonContent(
    explanation:
        'Vamos estudar frações equivalentes com uma explicação curta antes do desafio.',
    question: 'Qual alternativa representa uma fração equivalente a 1/2?',
    options: {
      AnswerLetter.A: '1/3',
      AnswerLetter.B: '2/4',
      AnswerLetter.C: '3/5',
    },
    correctAnswer: AnswerLetter.B,
  );

  bool get _allowDevAulaHarness => !SimEnvironment.isProduction;

  LessonRuntimeSnapshot _devAulaSnapshot({
    ClassroomPhase phase = const ClassroomPhase.reading(),
  }) {
    final content = _devLessonContent();
    return LessonRuntimeSnapshot(
      authReady: authReady,
      authed: authed,
      hasCurriculum: true,
      isDone: false,
      viewModel: LessonMainViewModel(
        progress: 0,
        headerLabel: 'aula_item_of:1/1:aula_layer_1',
        options: [
          LessonOptionModel(
            letter: AnswerLetter.A,
            text: content.options[AnswerLetter.A] ?? '',
          ),
          LessonOptionModel(
            letter: AnswerLetter.B,
            text: content.options[AnswerLetter.B] ?? '',
          ),
          LessonOptionModel(
            letter: AnswerLetter.C,
            text: content.options[AnswerLetter.C] ?? '',
          ),
        ],
        locked: false,
        nextLabel: phase.type == ClassroomPhaseType.concluido
            ? 'aula_next'
            : '',
      ),
      phase: phase,
      history: const [],
      conteudo: content,
      imagem: null,
      itemMarker: 'M-1',
      itemText: 'Frações equivalentes',
    );
  }

  Future<void> openAulaRuntime({
    bool menuOpenPriority = false,
    bool suppressReadyWindowUntilVisibleLessonReady = false,
    AulaOpenOperationKind operationKind = AulaOpenOperationKind.open,
  }) => _openAulaRuntimeOnce(
    menuOpenPriority: menuOpenPriority,
    suppressReadyWindowUntilVisibleLessonReady:
        suppressReadyWindowUntilVisibleLessonReady,
    operationKind: operationKind,
  );

  Future<void> _openAulaRuntimeOnce({
    required bool menuOpenPriority,
    required bool suppressReadyWindowUntilVisibleLessonReady,
    required AulaOpenOperationKind operationKind,
  }) async {
    var id = lessonLocalId;
    if (id == null || id.trim().isEmpty) {
      aulaSnapshot = null;
      aulaRuntimeError = null;
      aulaMenuLessonWaiting = false;
      navigationState.openRoute('/cyber/objeto');
      _notifyFromChild();
      return;
    }
    if (_activateReadyNextCurriculumPartIfNeeded(id)) {
      id = lessonLocalId;
      if (id == null || id.trim().isEmpty) return;
    }
    final runtimeGeneration = ++_aulaRuntimeGeneration;
    if (operationKind == AulaOpenOperationKind.retry) {
      aulaOpeningTransition = AulaOpeningTransition(
        targetLessonLocalId: id,
        previousSnapshot: aulaSnapshot,
        transitionStartedAt: DateTime.now(),
        status: AulaOpeningStatus.retrying,
        generation: runtimeGeneration,
      );
    }
    aulaRuntimeLoading = true;
    if (menuOpenPriority && suppressReadyWindowUntilVisibleLessonReady) {
      aulaMenuLessonWaiting = true;
    }
    aulaRuntimeError = null;
    _notifyFromChild();
    try {
      if (prefs == null) {
        if (!_allowDevAulaHarness) {
          throw StateError('Aula de desenvolvimento bloqueada em production.');
        }
        aulaSnapshot = _devAulaSnapshot();
        return;
      }
      final organism = _organismForActiveLesson();
      final openLessonId = id;
      _bindActiveLessonState(organism);
      _scheduleAdvancePendingReevaluation(organism, reason: 'open_runtime');
      final snapshot = await organism.lessonRuntimeEngine.open(
        lessonLocalId: organism.lessonLocalId,
        authReady: authReady,
        authed: authed,
        menuOpenPriority: menuOpenPriority,
        suppressReadyWindowUntilVisibleLessonReady:
            suppressReadyWindowUntilVisibleLessonReady,
        onBackgroundResolved: (result) {
          _applyBackgroundResolvedLessonMaterial(
            organism: organism,
            lessonLocalId: openLessonId,
            generation: runtimeGeneration,
          );
        },
      );
      if (!_isCurrentAulaRuntime(id, runtimeGeneration)) return;
      aulaSnapshot = snapshot;
      aulaOpeningTransition = null;
      if (_drawerAulaTextReady(snapshot)) aulaMenuLessonWaiting = false;
      _bindActiveLessonMedia(organism);
      _reavaliarAvancoPendenteSePossivel(
        organism,
        lessonLocalId: organism.lessonLocalId,
        generation: runtimeGeneration,
        reason: 'open_runtime_snapshot',
      );
      _syncImageStateFromSnapshot();
      if (!suppressReadyWindowUntilVisibleLessonReady ||
          _drawerAulaTextReady(snapshot)) {
        _keepActiveAulaOfflineWindowWarm(
          organism,
          source: menuOpenPriority
              ? 'drawer.aula.visible-ready-window'
              : 'cyber.aula.runtime-open',
        );
      }
      if (aulaSnapshot?.hasCurriculum != true) {
        aulaRuntimeError = 'Aula sem curriculo no Estado do aluno.';
      }
    } catch (error) {
      if (!_isCurrentAulaRuntime(id, runtimeGeneration)) return;
      aulaRuntimeError = error.toString();
    } finally {
      if (_isCurrentAulaRuntime(id, runtimeGeneration)) {
        aulaRuntimeLoading = false;
        _notifyFromChild();
        final active = _activeOrganism;
        if (active != null) _drainPendingAulaIntents(active);
      }
    }
  }

  bool _isCurrentAulaRuntime(String lessonLocalId, int generation) =>
      this.lessonLocalId == lessonLocalId &&
      _aulaRuntimeGeneration == generation;

  void _applyBackgroundResolvedLessonMaterial({
    required SimOrganism organism,
    required String lessonLocalId,
    required int generation,
  }) {
    if (_disposed || _activeOrganism != organism) {
      _recordRuntimeAudit(
        'BACKGROUND_RESOLVED_STALE_GENERATION_IGNORED',
        source: 'LabSession.background_resolved',
        details: {
          'targetLessonLocalId': lessonLocalId,
          'generation': generation,
          'currentGeneration': _aulaRuntimeGeneration,
          'reason': _disposed ? 'disposed' : 'inactive_organism',
        },
      );
      return;
    }
    if (!_isCurrentAulaRuntime(lessonLocalId, generation)) {
      _recordRuntimeAudit(
        'BACKGROUND_RESOLVED_STALE_GENERATION_IGNORED',
        source: 'LabSession.background_resolved',
        details: {
          'targetLessonLocalId': lessonLocalId,
          'generation': generation,
          'currentGeneration': _aulaRuntimeGeneration,
          'reason': 'generation_or_lesson_mismatch',
        },
      );
      return;
    }
    aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
    aulaRuntimeLoading = false;
    aulaRuntimeError = null;
    aulaOpeningTransition = null;
    if (_drawerAulaTextReady(aulaSnapshot)) aulaMenuLessonWaiting = false;
    _bindActiveLessonMedia(organism);
    _syncImageStateFromSnapshot();
    _notifyFromChild();
    _drainPendingAulaIntents(organism);
    _keepActiveAulaOfflineWindowWarm(
      organism,
      source: 'cyber.aula.background-resolved',
    );
  }

  void _keepActiveAulaOfflineWindowWarm(
    SimOrganism organism, {
    required String source,
  }) {
    if (prefs == null) return;
    final id = organism.lessonLocalId;
    if (lessonLocalId != id) return;
    final state = organism.stateService.read(id);
    final curriculum = state?.curriculum;
    if (state == null || curriculum?.items.isNotEmpty != true) return;
    final current = state.current;
    final progress = state.progress;
    final itemIdx = (current?.itemIdx ?? progress?.itemIdx ?? 0).clamp(
      0,
      curriculum!.items.length - 1,
    );
    final item = curriculum.items[itemIdx];
    final layer = current?.layer ?? progress?.layer ?? LessonLayer.l1;
    final marker = current?.marker ?? item.marker;
    final topic = curriculum.topic.trim().isNotEmpty
        ? curriculum.topic
        : state.profile.objetivo;
    if (_isFlutterTestEnvironment()) return;
    organism.materialService.prepareReadyWindowInBackground(
      lessonLocalId: id,
      topic: topic,
      itemIdx: itemIdx,
      layer: layer,
      marker: marker,
      source: source,
    );
    unawaited(organism.readyWindowWorker.drainReadyWindowJobs(id));
  }

  void _bindActiveLessonState(SimOrganism organism) {
    if (_aulaStateSubscriptionLessonId == organism.lessonLocalId) return;
    _aulaStateUnsubscribe?.call();
    _aulaStateSubscriptionLessonId = organism.lessonLocalId;
    _aulaStateSeenEventCount =
        organism.stateService.read(organism.lessonLocalId)?.events.length ?? 0;
    _aulaStateUnsubscribe = organism.stateService.subscribe((changedLessonId) {
      if (_disposed || changedLessonId != _aulaStateSubscriptionLessonId) {
        return;
      }
      final active = _activeOrganism;
      if (active == null || active.lessonLocalId != changedLessonId) return;
      final state = active.stateService.read(changedLessonId);
      final eventCount = state?.events.length ?? 0;
      final latestEvent = state?.events.isNotEmpty == true
          ? state!.events.last
          : null;
      if (latestEvent?.type == 'LESSON_BACKGROUND_MATERIAL_FAILED') {
        aulaRuntimeLoading = false;
        aulaMenuLessonWaiting = false;
        aulaRuntimeError =
            'Nao consegui preparar esta parte agora. Tente novamente.';
        _notifyFromChild();
        return;
      }
      if (eventCount > _aulaStateSeenEventCount &&
          latestEvent != null &&
          _isAulaStateReevaluationEcho(latestEvent.type)) {
        _aulaStateSeenEventCount = eventCount;
        _recordRuntimeAudit(
          'LESSON_EVENT_ECHO_IGNORED',
          source: 'LabSession.state_listener',
          details: {
            'changedLessonId': changedLessonId,
            'eventType': latestEvent.type,
            'eventCount': eventCount,
          },
        );
        return;
      }
      _aulaStateSeenEventCount = eventCount;
      _scheduleAdvancePendingReevaluation(
        active,
        reason: latestEvent?.type ?? 'state_write',
      );
    });
  }

  void _scheduleAdvancePendingReevaluation(
    SimOrganism organism, {
    required String reason,
  }) {
    _advancePendingReevaluationLessonId = organism.lessonLocalId;
    _advancePendingReevaluationGeneration = _aulaRuntimeGeneration;
    _advancePendingReevaluationReason = reason;
    if (_advancePendingReevaluationScheduled) {
      _recordRuntimeAudit(
        'ADVANCE_REEVALUATION_COALESCED',
        source: 'LabSession.advance_reevaluation',
        details: {
          'lessonLocalId': organism.lessonLocalId,
          'generation': _aulaRuntimeGeneration,
          'reason': reason,
        },
      );
      return;
    }
    _advancePendingReevaluationScheduled = true;
    scheduleMicrotask(() {
      _advancePendingReevaluationScheduled = false;
      final scheduledLessonId = _advancePendingReevaluationLessonId;
      final scheduledGeneration = _advancePendingReevaluationGeneration;
      final scheduledReason = _advancePendingReevaluationReason;
      _advancePendingReevaluationLessonId = null;
      _advancePendingReevaluationGeneration = null;
      _advancePendingReevaluationReason = null;
      if (_disposed || _activeOrganism != organism) return;
      _reavaliarAvancoPendenteSePossivel(
        organism,
        lessonLocalId: scheduledLessonId,
        generation: scheduledGeneration,
        reason: scheduledReason,
      );
    });
  }

  void _reavaliarAvancoPendenteSePossivel(
    SimOrganism organism, {
    String? lessonLocalId,
    int? generation,
    String? reason,
  }) {
    if (_disposed || _activeOrganism != organism) return;
    final changed =
        organism.lessonRuntimeEngine.reavaliarMaterialVisivelSolicitado() ||
        organism.lessonRuntimeEngine.reavaliarAvancoPendente(
          recoverFailedJobs: false,
        ) ||
        organism.lessonRuntimeEngine.reavaliarMaterialAtualSePronto();
    if (!changed) {
      _recordRuntimeAudit(
        'ADVANCE_REEVALUATION_NO_CHANGE',
        source: 'LabSession.advance_reevaluation',
        details: {
          'lessonLocalId': lessonLocalId ?? organism.lessonLocalId,
          'generation': generation ?? _aulaRuntimeGeneration,
          'reason': reason ?? 'unknown',
        },
      );
      return;
    }
    aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
    if (_drawerAulaTextReady(aulaSnapshot)) aulaMenuLessonWaiting = false;
    aulaOpeningTransition = null;
    _bindActiveLessonMedia(organism);
    _syncImageStateFromSnapshot();
    _notifyFromChild();
    _drainPendingAulaIntents(organism);
  }

  void chooseAulaAnswer(String letter) {
    final snapshot = aulaSnapshot;
    if (snapshot?.conteudo == null ||
        snapshot?.phase.type == ClassroomPhaseType.processando) {
      aulaRuntimeError = 'A aula ainda esta preparando. Aguarde um instante.';
      _recordRuntimeAudit(
        'ANSWER_BLOCKED_BY_LOADING',
        source: 'LabSession.chooseAulaAnswer',
        details: {'letter': letter},
        notify: true,
      );
      return;
    }
    stopActiveAudio();
    final normalizedLetter = letter.trim().toUpperCase();
    final answer = switch (normalizedLetter) {
      'A' => AnswerLetter.A,
      'B' => AnswerLetter.B,
      'C' => AnswerLetter.C,
      _ => null,
    };
    if (answer == null) {
      aulaRuntimeError = 'Alternativa invalida. Escolha A, B ou C.';
      _recordRuntimeAudit(
        'ANSWER_REJECTED_INVALID_LETTER',
        details: {'letter': letter},
        source: 'LabSession.chooseAulaAnswer',
        notify: true,
      );
      return;
    }
    if (prefs == null || _runningUnderFlutterTest) {
      if (!_allowDevAulaHarness) {
        aulaRuntimeError = 'Aula de desenvolvimento bloqueada em production.';
        _notifyFromChild();
        return;
      }
      aulaSnapshot = _devAulaSnapshot(phase: ClassroomPhase.expanded(answer));
      _notifyFromChild();
      return;
    }
    final organism = _activeOrganism ?? _organismForActiveLesson();
    organism.lessonRuntimeEngine.select(answer);
    aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
    final accepted =
        aulaSnapshot?.phase.type == ClassroomPhaseType.expandida &&
        aulaSnapshot?.phase.letter == answer;
    if (!accepted) {
      aulaRuntimeError =
          'Nao consegui registrar a resposta nesta posicao. Tente novamente.';
      _recordRuntimeAudit(
        'ANSWER_REJECTED_NO_POSITION',
        details: {'letter': answer.name},
        source: 'LabSession.chooseAulaAnswer',
      );
    }
    _bindActiveLessonMedia(organism);
    _keepActiveAulaOfflineWindowWarm(
      organism,
      source: 'cyber.aula.answer-selected',
    );
    _notifyFromChild();
  }

  Future<void> submitAulaSignal(int value) async {
    if (aulaRuntimeLoading &&
        !hasValidPedagogicalContent(aulaSnapshot?.conteudo)) {
      aulaRuntimeError =
          'Estou registrando a aula. Aguarde um instante para qualificar.';
      _recordRuntimeAudit(
        'SIGNAL_BLOCKED_BY_LOADING',
        source: 'LabSession.submitAulaSignal',
        details: {'value': value},
        notify: true,
      );
      return;
    }
    stopActiveAudio();
    final signal = switch (value) {
      1 => DecisionSignal.one,
      2 => DecisionSignal.two,
      3 => DecisionSignal.three,
      _ => null,
    };
    if (signal == null) {
      aulaRuntimeError = 'Qualificador invalido. Escolha 1, 2 ou 3.';
      _recordRuntimeAudit(
        'SIGNAL_REJECTED_INVALID_VALUE',
        details: {'value': value},
        source: 'LabSession.submitAulaSignal',
        notify: true,
      );
      return;
    }
    if (prefs == null) {
      if (!_allowDevAulaHarness) {
        aulaRuntimeError = 'Aula de desenvolvimento bloqueada em production.';
        _notifyFromChild();
        return;
      }
      aulaSnapshot = _devAulaSnapshot(
        phase: ClassroomPhase.completed(
          message: 'aula_fb_correct',
          wasCorrect: true,
          signal: signal,
        ),
      );
      _notifyFromChild();
      return;
    }
    final organism = _activeOrganism ?? _organismForActiveLesson();
    await _doSignal(organism, signal);
  }

  Future<void> _doSignal(SimOrganism organism, DecisionSignal signal) async {
    aulaRuntimeError = null;
    _notifyFromChild();
    try {
      await organism.lessonRuntimeEngine.signal(signal);
      aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
      _bindActiveLessonMedia(organism);
      _notifyFromChild();
      _enqueueActiveLessonForRemoteVaultSync(reason: 'active_lesson_changed');
      _keepActiveAulaOfflineWindowWarm(organism, source: 'cyber.aula.signal');
      prefetchAuxRoomsAfterMainEvidence(organism);
      await _openTriggeredAmparoIfNeeded(organism);
      _scheduleAutoAdvanceAfterFeedback(organism);
    } catch (error) {
      aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
      aulaRuntimeError = humanErrorMessage(error);
      _recordRuntimeAudit(
        'SIGNAL_ERROR_CLASSIFIED',
        source: 'LabSession.submitAulaSignal',
        details: {'retryable': true, 'signal': signal.value},
        error: error,
      );
    } finally {
      _notifyFromChild();
    }
  }

  void _scheduleAutoAdvanceAfterFeedback(SimOrganism organism) {
    final phase = aulaSnapshot?.phase;
    if (phase?.type != ClassroomPhaseType.concluido ||
        phase?.wasCorrect != true) {
      return;
    }
    final generation = ++_autoAdvanceAulaGeneration;
    _pendingAutoAdvanceAfterFeedback = true;
    _pendingAutoAdvanceGeneration = generation;
    Future<void>.delayed(_autoAdvanceAfterFeedbackDelay, () async {
      await _tryConsumePendingAutoAdvance(organism, generation);
    });
  }

  Future<void> _tryConsumePendingAutoAdvance(
    SimOrganism organism,
    int generation,
  ) async {
    final canAdvance =
        !_disposed &&
        _pendingAutoAdvanceAfterFeedback &&
        generation == _pendingAutoAdvanceGeneration &&
        generation == _autoAdvanceAulaGeneration &&
        _activeOrganism == organism &&
        aulaSnapshot?.phase.type == ClassroomPhaseType.concluido &&
        aulaSnapshot?.phase.wasCorrect == true;
    if (!canAdvance) return;
    if (aulaRuntimeLoading) {
      _recordRuntimeAudit(
        'AUTO_ADVANCE_DEFERRED_BY_LOADING',
        source: 'LabSession.auto_advance',
        details: {'generation': generation},
      );
      return;
    }
    _pendingAutoAdvanceAfterFeedback = false;
    await advanceAula();
  }

  void _drainPendingAulaIntents(SimOrganism organism) {
    if (_disposed || aulaRuntimeLoading || _activeOrganism != organism) return;
    if (_pendingManualAdvance) {
      _pendingManualAdvance = false;
      _pendingAutoAdvanceAfterFeedback = false;
      _recordRuntimeAudit(
        'MANUAL_ADVANCE_PRIORITY_OVER_AUTO_PENDING',
        source: 'LabSession.advanceAula',
      );
      unawaited(advanceAula());
      return;
    }
    if (_pendingAutoAdvanceAfterFeedback) {
      unawaited(
        _tryConsumePendingAutoAdvance(organism, _pendingAutoAdvanceGeneration),
      );
      return;
    }
  }

  void setDeleteConfirmation(String value) =>
      lessonUiState.setDeleteConfirmation(value);

  void requestAccountDeletion() {
    unawaited(
      RequestAccountDeletionUseCase(
        lessonUiState: lessonUiState,
        authSession: authSession,
        navigationState: navigationState,
        gatewayFactory: () =>
            _accountDeletionGateway ??
            SimServerAccountDeletionGateway(config: _serverConfig()),
      ).execute(),
    );
  }

  Future<void> advanceAula() async {
    if (aulaRuntimeLoading) {
      _pendingManualAdvance = true;
      aulaRuntimeError =
          'A aula esta terminando de carregar. Vou avancar em seguida.';
      _recordRuntimeAudit(
        'MANUAL_ADVANCE_DEFERRED_BY_LOADING',
        source: 'LabSession.advanceAula',
        notify: true,
      );
      return;
    }
    _pendingManualAdvance = false;
    _autoAdvanceAulaGeneration++;
    var crossedToNextPart = false;
    var blockedByRecovery = false;
    SimOrganism? organism;
    try {
      organism = _activeOrganism ?? _organismForActiveLesson();
      final activeOrganism = organism;
      final advanceGeneration = _aulaRuntimeGeneration;
      stopActiveAudio(notify: false);
      aulaRuntimeLoading = true;
      aulaRuntimeError = null;
      _notifyFromChild();
      await activeOrganism.lessonRuntimeEngine.advance(
        onBackgroundResolved: (result) {
          _applyBackgroundResolvedLessonMaterial(
            organism: activeOrganism,
            lessonLocalId: activeOrganism.lessonLocalId,
            generation: advanceGeneration,
          );
        },
      );
      aulaSnapshot = activeOrganism.lessonRuntimeEngine.snapshot();
      _bindActiveLessonMedia(activeOrganism);
      _enqueueActiveLessonForRemoteVaultSync(reason: 'active_lesson_changed');
      _keepActiveAulaOfflineWindowWarm(
        activeOrganism,
        source: 'cyber.aula.advance',
      );
      final latestEvents = activeOrganism.stateService
          .read(activeOrganism.lessonLocalId)
          ?.events;
      blockedByRecovery =
          latestEvents?.isNotEmpty == true &&
          latestEvents!.last.type == 'FINAL_COMPLETION_BLOCKED_BY_PENDING';
      final currentId = lessonLocalId;
      if (aulaSnapshot?.isDone == true &&
          currentId != null &&
          _activateReadyNextCurriculumPartIfNeeded(currentId)) {
        crossedToNextPart = true;
      }
    } catch (error) {
      aulaRuntimeError = humanErrorMessage(error);
      _recordRuntimeAudit(
        'ADVANCE_ERROR_CLASSIFIED',
        source: 'LabSession.advanceAula',
        details: {'retryable': true},
        error: error,
      );
    } finally {
      aulaRuntimeLoading = false;
      _notifyFromChild();
      if (organism != null) _drainPendingAulaIntents(organism);
    }
    if (blockedByRecovery && recoveryRoom == null) {
      await startRecoveryRoom();
    }
    if (crossedToNextPart) await openAulaRuntime();
  }

  Future<void> continueAfterLessonDone() async {
    final currentId = lessonLocalId;
    if (currentId != null &&
        _activateReadyNextCurriculumPartIfNeeded(currentId)) {
      await openAulaRuntime();
      return;
    }
    if (currentId != null && _hasPendingNextCurriculumPart(currentId)) {
      aulaSnapshot = aulaSnapshot?.copyWith(
        isDone: false,
        phase: const ClassroomPhase.advancePending(
          message: 'aula_advance_preparing',
        ),
      );
      aulaRuntimeError = null;
      navigationState.openRoute('/cyber/aula');
      _notifyFromChild();
      unawaited(_retryOpenAulaWhenNextCurriculumPartIsReady(currentId));
      return;
    }
    openSupport('/cyber/objeto');
  }

  bool _hasPendingNextCurriculumPart(String currentLessonId) {
    if (prefs == null) return false;
    final organism = _organismForActiveLesson();
    final state = organism.stateService.read(currentLessonId);
    return state != null && hasPendingNextCurriculumPart(state);
  }

  bool _hasLocalOfficialAulaState() {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty || prefs == null) return false;
    try {
      final organism = _organismForActiveLesson();
      final state = organism.stateService.read(id);
      return state?.curriculum?.items.isNotEmpty == true &&
          (state?.current != null || state?.progress != null);
    } catch (error, stackTrace) {
      _recordRuntimeAudit(
        'LOCAL_OFFICIAL_AULA_STATE_CHECK_FAILED',
        source: 'LabSession.hasLocalOfficialAulaState',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> _retryOpenAulaWhenNextCurriculumPartIsReady(
    String currentLessonId,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!_disposed &&
        lessonLocalId == currentLessonId &&
        DateTime.now().isBefore(deadline)) {
      if (_activateReadyNextCurriculumPartIfNeeded(currentLessonId)) {
        await openAulaRuntime();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    if (!_disposed && lessonLocalId == currentLessonId) {
      aulaRuntimeError =
          'A proxima parte ainda esta preparando. Tente novamente em instantes.';
      _recordRuntimeAudit(
        'NEXT_PART_RETRY_TIMEOUT',
        source: 'LabSession.next_part_retry',
        details: {'currentLessonId': currentLessonId},
        notify: true,
      );
    }
  }
}
