part of 'lab_session.dart';

extension LabSessionEntryFlows on LabSession {
  bool saveObjectiveEntry() {
    final freeTrim = freeText.trim();
    if (freeTrim.length < 10) return false;
    final clipped = freeTrim.length > maxFreeText
        ? freeTrim.substring(0, maxFreeText)
        : freeTrim;
    entryForm.attachmentsText = entryForm.buildAttachmentsText();
    final ficha = buildPedagogicalFicha(objectiveOverride: clipped);
    final guided = _guidedProfileFields(clipped, ficha: ficha);
    final language = explanationLanguage;
    final id = _deriveLessonLocalId(clipped, learningLocaleTag);
    lessonLocalId = id;
    entryForm.studentProfileNotes = _studentProfileNotes(
      objective: clipped,
      guidedSummary:
          (guided['human_entry_summary'] ?? guided['guided_summary'])
              ?.toString() ??
          '',
      attachments: attachmentsText,
    );
    entryForm.freeText = clipped;
    _saveProfileToState(
      id: id,
      objective: clipped,
      language: language,
      locale: localeContract,
      guided: guided,
    );
    entryStatus = 'pedido_recebido';
    entryError = null;
    _experienceGeneration += 1;
    navigationState.openRoute('/cyber/curriculo');
    _notifyFromChild();
    return true;
  }

  Future<void> launchExperience() async {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) {
      entryStatus = 'erro';
      entryError =
          'Nao encontrei a aula atual. Troque o objetivo e tente novamente.';
      _notifyFromChild();
      return;
    }
    if (entryStatus == 't00_running' ||
        entryStatus == 't02_running' ||
        entryStatus == 'primeira_aula_pronta') {
      final inFlight = _launchExperienceInFlight;
      if (inFlight != null) await inFlight;
      return;
    }

    final generation = _experienceGeneration;
    final inFlight = _doLaunchExperience(id, generation);
    _launchExperienceInFlight = inFlight;
    try {
      await inFlight;
    } finally {
      if (identical(_launchExperienceInFlight, inFlight)) {
        _launchExperienceInFlight = null;
      }
    }
  }

  Future<void> _doLaunchExperience(String id, int generation) async {
    entryStatus = 't00_running';
    entryError = null;
    warmupLesson = null;
    warmupError = null;
    warmupSelectedAnswer = null;
    warmupWaitingForOfficialLesson = false;
    _resetEntryCoordinator(warmupExpected: false);
    _notifyFromChild();

    try {
      final prepareOverride = experiencePreparerOverride;
      if (prepareOverride == null && prefs != null) {
        final ready = await _ensureProtectedServerSession(
          returnTo: '/cyber/curriculo',
          forceRefresh: true,
        );
        if (!ready) {
          if (!_isCurrentExperience(id, generation)) return;
          entryStatus = 'erro';
          entryError = 'Entre novamente para preparar sua aula com segurança.';
          _notifyFromChild();
          return;
        }
      }
      debugPrint('[SIM] T00_STARTED');
      final ficha = buildPedagogicalFicha();
      final guidedProfile = _guidedProfileFields(freeText.trim(), ficha: ficha);
      final academic = _academicFromOnboarding(guidedProfile);
      final onboarding = <String, dynamic>{
        'objetivo': freeText.trim(),
        'free_text': freeText.trim(),
        ...localeContract.toJson(),
        'idioma': explanationLanguage,
        'language': learningLocaleTag,
        'stableLang': explanationLanguage,
        'STABLE_LANG': explanationLanguage,
        'ACADEMIC_LEVEL': academic,
        'academic_level': academic,
        'nivel': academic,
        'target_topic': freeText.trim(),
        'TARGET_TOPIC': freeText.trim(),
        'pedagogical_entry_ficha': ficha,
        ...guidedProfile,
        if (preferredName.trim().isNotEmpty)
          'preferred_name': preferredName.trim(),
        if (studentProfileNotes.isNotEmpty)
          'student_profile_notes': studentProfileNotes,
        if (attachmentsText.isNotEmpty) 'attachments_text': attachmentsText,
      };
      final args = StudentExperienceArgs(
        academic: academic,
        idioma: explanationLanguage,
        localeContract: localeContract,
        lessonLocalId: id,
        onboarding: onboarding,
        onStage: (stage) {
          final next = switch (stage) {
            StudentExperienceRouteStage.curriculum => 't00_running',
            StudentExperienceRouteStage.lesson => 't02_running',
            StudentExperienceRouteStage.ready => 'primeira_aula_pronta',
            StudentExperienceRouteStage.placement => 'placement',
            _ => entryStatus,
          };
          entryStatus = next;
          _notifyFromChild();
        },
      );

      unawaited(
        _prepareWarmupLesson(
          lessonLocalId: id,
          objective: freeText.trim(),
          onboarding: onboarding,
          academic: academic,
          generation: generation,
        ),
      );

      final result = await _prepareExperienceWithAuthRetry(
        id: id,
        args: args,
        prepareOverride: prepareOverride,
      );

      if (!_isCurrentExperience(id, generation)) return;
      _entryOfficialLessonReady = true;
      entryStatus = 'primeira_aula_pronta';
      _notifyFromChild();

      debugPrint('[SIM] CLASSROOM_OPENED route=${result.destination}');
      if (route == '/cyber/warmup' || warmupWaitingForOfficialLesson) {
        unawaited(_tryOpenOfficialAula(source: 'official_ready'));
      } else if (route == '/cyber/curriculo' && !_entryWarmupExpected) {
        navigationState.openRoute(result.destination);
        if (result.destination == '/cyber/aula') {
          _entryAulaNavigationStarted = true;
          unawaited(openAulaRuntime());
        }
      }
    } on StudentExperienceEngineException catch (err) {
      if (!_isCurrentExperience(id, generation)) return;
      debugPrint('[SIM] BLOCKED reason=${err.error.kind.name}');
      entryError = err.error.message;
      entryStatus = 'erro';
      _notifyFromChild();
    } catch (err) {
      if (!_isCurrentExperience(id, generation)) return;
      debugPrint('[SIM] BLOCKED reason=unexpected');
      entryError = humanErrorMessage(
        err,
        fallback:
            'Nao consegui preparar a entrada da aula agora. Toque para tentar novamente.',
      );
      entryStatus = 'erro';
      _notifyFromChild();
    }
  }

  Future<void> _prepareWarmupLesson({
    required String lessonLocalId,
    required String objective,
    required Map<String, dynamic> onboarding,
    required String academic,
    required int generation,
  }) async {
    _entryWarmupExpected = false;
    warmupLoading = false;
    warmupError = null;
    _notifyFromChild();
    if (_isCurrentExperience(lessonLocalId, generation)) {
      unawaited(_tryOpenOfficialAula(source: 'warmup_removed'));
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
    unawaited(continueFromWarmupToAula());
  }

  void openWarmupBridge({bool preparePlacement = false}) {
    final controller = activePlacementController;
    if (preparePlacement) {
      if (controller != null) {
        controller.chooseStart();
        unawaited(controller.startTest());
      }
    } else {
      controller?.skip();
    }
    navigationState.openRoute('/cyber/warmup');
    _notifyFromChild();
  }

  Future<void> continueFromWarmupToAula() async {
    final controller = activePlacementController;
    if (controller != null && controller.destination != '/cyber/aula') {
      controller.continueToAula();
    }
    warmupWaitingForOfficialLesson = false;
    _notifyFromChild();
    await _tryOpenOfficialAula(source: 'warmup_continue');
  }

  void _resetEntryCoordinator({required bool warmupExpected}) {
    _entryOfficialLessonReady = false;
    _entryWarmupExpected = warmupExpected;
    _entryAulaNavigationStarted = false;
  }

  Future<void> _tryOpenOfficialAula({required String source}) async {
    if (_entryAulaNavigationStarted) return;
    if (!_entryOfficialLessonReady) {
      if (_entryWarmupExpected || !_hasLocalOfficialAulaState()) return;
    }
    warmupWaitingForOfficialLesson = false;
    final controller = activePlacementController;
    if (controller == null) {
      _entryAulaNavigationStarted = true;
      debugPrint('[SIM] ENTRY_NAVIGATE_AULA source=$source placement=false');
      navigationState.openRoute('/cyber/aula');
      await openAulaRuntime();
      return;
    }
    if (controller.destination != '/cyber/aula') return;
    _entryAulaNavigationStarted = true;
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
