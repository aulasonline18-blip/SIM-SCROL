part of 'lab_session.dart';

const Duration _autoAdvanceAfterFeedbackDelay = Duration(milliseconds: 900);
String humanErrorMessage(Object? error, {
  String fallback = 'Nao consegui concluir isso agora. Tente novamente em instantes.',
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
    _aulaRuntimeGeneration++;
    stopActiveAudio(notify: false);
    _resetActiveLessonMedia(clearSnapshot: true, clearSubscriptions: true);
    aulaRuntimeLoading = false;
    aulaMenuLessonWaiting = false;
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
        profile: base.profile.copyWith(
          preferredName: preferredName.trim().isEmpty
              ? base.profile.preferredName
              : preferredName.trim(),
          language: locale.learningLocale,
          stableLang: locale.explanationLanguage,
          objetivo: objective,
          targetTopic: objective,
          sessionGoal: objective,
          extra: {...base.profile.extra, ...guided, ...locale.toJson()},
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
      },
      source: 'lab_session',
      userId: userId,
    );
  }

  JsonMap _guidedProfileFields(String objective, {JsonMap ficha = const {}}) {
    final answers = guidedAnswers;
    String? value(String key) {
      final raw = answers[key]?.trim();
      return raw == null || raw.isEmpty ? null : raw;
    }

    final purpose = value('purpose');
    final level = value('level') ?? _cleanOrNull(academicLevel);
    final blocker = value('blocker') ?? _cleanOrNull(difficulties);
    final deadline = value('deadline') ?? _cleanOrNull(this.deadline);
    final style = value('style') ?? _cleanOrNull(learningPreference);
    final start = value('start');

    final summaryLines = [
      if (purpose != null) 'Objetivo real: $purpose',
      if (level != null) 'Nivel percebido: $level',
      if (blocker != null) 'Onde trava: $blocker',
      if (deadline != null) 'Prazo/prova: $deadline',
      if (style != null) 'Como prefere ser conduzido: $style',
      if (start != null) 'Ponto de partida desejado: $start',
    ];
    final guidedSummary = summaryLines.join('\n');

    final fields = <String, dynamic>{};
    if (guidedSummary.isNotEmpty) fields['guided_summary'] = guidedSummary;
    if (purpose != null) {
      fields['real_use_goal'] = purpose;
      fields['exam_goal'] = purpose;
    }
    if (objective.trim().isNotEmpty) {
      fields['learning_goal'] = objective.trim();
    }
    if (level != null) {
      fields['academic_level'] = level;
      fields['nivel'] = level;
    }
    if (blocker != null) {
      fields['known_weaknesses'] = blocker;
      fields['learning_care_notes'] = blocker;
    }
    if (deadline != null) {
      fields['session_goal'] = deadline;
      fields['SESSION_GOAL'] = deadline;
    }
    if (style != null) {
      fields['attention_profile'] = style;
      fields['motivation_profile'] = style;
    }
    if (start != null) fields['prior_knowledge'] = start;
    if (answers.isNotEmpty) fields['guided_answers'] = JsonMap.from(answers);
    if (ficha.isNotEmpty) {
      fields['pedagogical_entry_ficha'] = ficha;
      for (final key in const [
        'entry_path',
        'age_range',
        'material_type',
        'material_based',
        'attachments_text',
        'student_profile_notes',
        'subject',
        'topic',
        'country_curriculum',
        'human_summary',
      ]) {
        final value = ficha[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          fields[key == 'human_summary' ? 'human_entry_summary' : key] = value;
        }
      }
    }
    return fields;
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
        '--- Ficha guiada da travessia ---\n$guidedSummary',
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

  Map<String, dynamic> _cyberLessonFromState(StudentLearningState state) {
    final curriculum = state.curriculum;
    final progress = state.progress;
    final layerNumber = switch (progress?.layer ??
        state.current?.layer ??
        LessonLayer.l1) {
      LessonLayer.l1 => 1,
      LessonLayer.l2 => 2,
      LessonLayer.l3 => 3,
    };
    return {
      'id': state.lessonLocalId,
      'name':
          state.profile.objetivo ?? curriculum?.topic ?? state.lessonLocalId,
      'createdAt': state.createdAt,
      'updatedAt': state.updatedAt,
      'onboarding': {
        ...state.profile.toJson(),
        'lessonLocalId': state.lessonLocalId,
        'objetivo': state.profile.objetivo ?? curriculum?.topic ?? '',
        'stableLang': state.profile.stableLang ?? state.profile.language ?? '',
      },
      'curriculo': {
        'topic': curriculum?.topic ?? state.profile.objetivo ?? '',
        'geradoEm': curriculum?.generatedAt ?? state.updatedAt,
        'provisional': curriculum?.provisional ?? false,
        'items': [
          for (final item in curriculum?.items ?? const <CurriculumItem>[])
            {
              ...item.toJson(),
              'id': item.marker,
              'title': item.title ?? item.text,
              'titulo': item.title ?? item.text,
              'item_name': item.text,
              'microitem_for_teacher': item.microitemForTeacher ?? item.text,
            },
        ],
      },
      'progress': {
        'itemIdx': progress?.itemIdx ?? state.current?.itemIdx ?? 0,
        'layer': layerNumber,
        'erros': progress?.erros ?? 0,
        'amparoLvl': progress?.amparoLvl ?? 0,
        'historia': progress?.historia ?? const <String>[],
        'mainAdvances': progress?.mainAdvances ?? 0,
        'concluidos': progress?.concluidos ?? const <String>[],
        'pendentes':
            progress?.pendentesMarkers
                .map((marker) => {'marker': marker})
                .toList() ??
            const <Map<String, dynamic>>[],
        'tentativas': [
          for (final attempt in state.attempts)
            {
              'marker': attempt.marker,
              'layer': switch (attempt.layer) {
                LessonLayer.l1 => 1,
                LessonLayer.l2 => 2,
                LessonLayer.l3 => 3,
              },
              'letra': attempt.letra.name,
              'sinal': attempt.sinal.value,
              'correct': attempt.correct,
              'ts': attempt.ts,
            },
        ],
      },
    };
  }

  Set<String> _lessonIdsFromBackup(Map<String, dynamic> backup) {
    final ids = <String>{};
    final states = backup['studentLearningStates'];
    if (states is Map) {
      ids.addAll(
        states.keys.map((key) => key.toString()).where((key) => key.isNotEmpty),
      );
    }
    final lessons = backup['lessons'];
    if (lessons is List) {
      for (final lesson in lessons.whereType<Map>()) {
        final id = lesson['id']?.toString().trim();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
    }
    final state = backup['state'];
    if (state is Map) {
      final id = state['lessonLocalId']?.toString().trim();
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    return ids;
  }

  void openSupport(String path) {
    navigationState.openRoute(path);
    _notifyFromChild();
  }

  void openExternalDoor(String url) => navigationState.openExternalDoor(url);

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
    final session = await _drawerSession();
    if (session == null) return false;
    final row = await _cloudFunctionsForDrawer().getStudentStateByLesson(
      lessonLocalId,
      session,
    );
    final rowLessonLocalId = row?.lessonLocalId.trim() ?? '';
    final hydratedLessonLocalId = rowLessonLocalId.isNotEmpty
        ? rowLessonLocalId
        : lessonLocalId.trim();
    final state = row?.state;
    if (state == null || _stateDeleted(state)) return false;
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
      if (session == null) return;
      await _cloudFunctionsForDrawer().getStudentStateByLesson(
        lessonLocalId,
        session,
      );
    } catch (_) {}
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
          stableLangProvider: () =>
              stableLang ?? selectedLanguageCode ?? 'pt-BR',
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
        stableLangProvider: () => stableLang ?? selectedLanguageCode ?? 'pt-BR',
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
      if (!applied) return;
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
  }) async {
    if (aulaRuntimeLoading) return;
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) {
      aulaSnapshot = null;
      aulaRuntimeError = null;
      aulaMenuLessonWaiting = false;
      navigationState.openRoute('/cyber/objeto');
      _notifyFromChild();
      return;
    }
    final runtimeGeneration = ++_aulaRuntimeGeneration;
    if (_activateReadyNextCurriculumPartIfNeeded(id)) {
      unawaited(openAulaRuntime());
      return;
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
      final snapshot = await organism.lessonRuntimeEngine.open(
        lessonLocalId: organism.lessonLocalId,
        authReady: authReady,
        authed: authed,
        menuOpenPriority: menuOpenPriority,
        suppressReadyWindowUntilVisibleLessonReady:
            suppressReadyWindowUntilVisibleLessonReady,
      );
      if (!_isCurrentAulaRuntime(id, runtimeGeneration)) return;
      aulaSnapshot = snapshot;
      if (_drawerAulaTextReady(snapshot)) aulaMenuLessonWaiting = false;
      _bindActiveLessonState(organism);
      _bindActiveLessonMedia(organism);
      _reavaliarAvancoPendenteSePossivel(organism);
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
      }
    }
  }

  bool _isCurrentAulaRuntime(String lessonLocalId, int generation) =>
      this.lessonLocalId == lessonLocalId &&
      _aulaRuntimeGeneration == generation;

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
    _aulaStateUnsubscribe = organism.stateService.subscribe((changedLessonId) {
      if (_disposed || changedLessonId != _aulaStateSubscriptionLessonId) {
        return;
      }
      final active = _activeOrganism;
      if (active == null || active.lessonLocalId != changedLessonId) return;
      final state = active.stateService.read(changedLessonId);
      if (state?.extra['advancePending'] is! Map &&
          aulaSnapshot?.phase.type != ClassroomPhaseType.avancoPendente) {
        return;
      }
      _scheduleAdvancePendingReevaluation(active);
    });
  }

  void _scheduleAdvancePendingReevaluation(SimOrganism organism) {
    if (_advancePendingReevaluationScheduled) return;
    _advancePendingReevaluationScheduled = true;
    scheduleMicrotask(() {
      _advancePendingReevaluationScheduled = false;
      if (_disposed || _activeOrganism != organism) return;
      _reavaliarAvancoPendenteSePossivel(organism);
    });
  }

  void _reavaliarAvancoPendenteSePossivel(SimOrganism organism) {
    if (_disposed || _activeOrganism != organism) return;
    final changed =
        organism.lessonRuntimeEngine.reavaliarMaterialVisivelSolicitado() ||
        organism.lessonRuntimeEngine.reavaliarAvancoPendente();
    if (!changed) return;
    aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
    if (_drawerAulaTextReady(aulaSnapshot)) aulaMenuLessonWaiting = false;
    _bindActiveLessonMedia(organism);
    _syncImageStateFromSnapshot();
    _notifyFromChild();
  }

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

  void chooseAulaAnswer(String letter) {
    if (aulaRuntimeLoading &&
        !hasValidPedagogicalContent(aulaSnapshot?.conteudo)) {
      return;
    }
    stopActiveAudio();
    final answer = AnswerLetter.values.firstWhere(
      (value) => value.name == letter,
      orElse: () => AnswerLetter.A,
    );
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
      return;
    }
    if (aulaSnapshot?.phase.type == ClassroomPhaseType.avancoPendente) return;
    stopActiveAudio();
    final signal = switch (value) {
      1 => DecisionSignal.one,
      2 => DecisionSignal.two,
      3 => DecisionSignal.three,
      _ => DecisionSignal.one,
    };
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
      _enqueueActiveLessonForRemoteVaultSync(reason: 'active_lesson_changed');
      _keepActiveAulaOfflineWindowWarm(organism, source: 'cyber.aula.signal');
      prefetchAuxRoomsAfterMainEvidence(organism);
      await _openTriggeredAmparoIfNeeded(organism);
      _scheduleAutoAdvanceAfterFeedback(organism);
    } catch (error) {
      aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
      aulaRuntimeError = error.toString();
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
    Future<void>.delayed(_autoAdvanceAfterFeedbackDelay, () async {
      final canAdvance =
          !_disposed &&
          generation == _autoAdvanceAulaGeneration &&
          _activeOrganism == organism &&
          aulaSnapshot?.phase.type == ClassroomPhaseType.concluido &&
          aulaSnapshot?.phase.wasCorrect == true;
      if (!canAdvance) return;
      if (aulaRuntimeLoading) {
        Future<void>.delayed(const Duration(milliseconds: 1000), () async {
          if (!aulaRuntimeLoading) await advanceAula();
        });
        return;
      }
      await advanceAula();
    });
  }

  void setDeleteConfirmation(String value) =>
      lessonUiState.setDeleteConfirmation(value);

  void requestAccountDeletion() {
    unawaited(_requestAccountDeletion());
  }

  Future<void> _requestAccountDeletion() async {
    if (lessonUiState.accountDeletionLoading) return;
    final confirmation = lessonUiState.deleteConfirmation.trim();
    if (confirmation != 'DELETAR') {
      lessonUiState.failAccountDeletionRequest(
        'Digite DELETAR para confirmar a solicitação.',
      );
      return;
    }
    final id = (authSession.userId ?? '').trim();
    if (!authed || id.isEmpty) {
      lessonUiState.failAccountDeletionRequest(
        'Entre na sua conta para solicitar exclusão.',
      );
      return;
    }
    lessonUiState.beginAccountDeletionRequest();
    try {
      final gateway =
          _accountDeletionGateway ??
          SimServerAccountDeletionGateway(config: _serverConfig());
      await gateway.requestAccountDeletion(
        AccountDeletionRequest(
          userId: id,
          confirmation: confirmation,
          emailSnapshot: authSession.userEmail,
        ),
      );
      lessonUiState.completeAccountDeletionRequest();
      await authSession.signOutReal();
      navigationState.openRoute('/');
    } catch (error) {
      lessonUiState.failAccountDeletionRequest(
        t('account_delete_failed', {'error': error}),
      );
    }
  }

  Future<void> advanceAula() async {
    if (aulaRuntimeLoading) return;
    _autoAdvanceAulaGeneration++;
    final organism = _activeOrganism ?? _organismForActiveLesson();
    stopActiveAudio(notify: false);
    aulaRuntimeLoading = true;
    aulaRuntimeError = null;
    _notifyFromChild();
    var crossedToNextPart = false;
    var blockedByRecovery = false;
    try {
      await organism.lessonRuntimeEngine.advance();
      aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
      _bindActiveLessonMedia(organism);
      _enqueueActiveLessonForRemoteVaultSync(reason: 'active_lesson_changed');
      _keepActiveAulaOfflineWindowWarm(organism, source: 'cyber.aula.advance');
      final latestEvents = organism.stateService
          .read(organism.lessonLocalId)
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
      aulaRuntimeError = error.toString();
    } finally {
      aulaRuntimeLoading = false;
      _notifyFromChild();
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

  Future<void> _retryOpenAulaWhenNextCurriculumPartIsReady(String currentLessonId) async {
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
  }
}
