part of 'lab_session.dart';

extension LabSessionEntryFlows on LabSession {
  bool saveObjectiveEntry() {
    final freeTrim = freeText.trim();
    if (freeTrim.length < 10) return false;
    if (attachments.any((attachment) => attachment.status == 'processing')) {
      return false;
    }
    if (freeTrim.length > maxFreeText) return false;
    final clipped = freeTrim;
    if (entryForm.entryPath.trim().isEmpty) {
      entryForm.entryPath = 'guided_path';
    }
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
    _recordOnboardingFlowEvent(
      'ONBOARDING_OBJECTIVE_SAVED_IMMEDIATE',
      payload: {
        'entry_path': materialEntryPath ? 'material_help' : 'guided_path',
        'route': materialEntryPath ? '/cyber/curriculo' : '/cyber/placement',
      },
    );
    _enqueueLessonForRemoteVaultSync(id, reason: 'new_lesson_started');
    entryStatus = 'pedido_recebido';
    entryError = null;
    _experienceGeneration += 1;
    if (materialEntryPath) {
      _markPlacementSkippedForMaterial(id);
      navigationState.openRoute('/cyber/curriculo');
    } else {
      navigationState.openRoute('/cyber/placement');
    }
    unawaited(launchExperience());
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
    _resetEntryCoordinator(
      warmupExpected: warmupBridgeService != null || prefs != null,
    );
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
      SecureLogger.log('SIM', 'T00_STARTED');
      final ficha = buildPedagogicalFicha();
      final guidedProfile = _guidedProfileFields(freeText.trim(), ficha: ficha);
      final academic = _academicFromOnboarding(guidedProfile);
      final onboarding = <String, dynamic>{
        'objetivo': freeText.trim(),
        'free_text': freeText.trim(),
        ...localeContract.toJson(),
        'localeContract': localeContract.toJson(),
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
        'entry_path': materialEntryPath ? 'material_help' : 'guided_path',
        'material_based': materialEntryPath,
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
            StudentExperienceRouteStage.ready => 't02_running',
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
      await _ensureFirstAulaRenderedBeforeRelease(
        id: id,
        generation: generation,
      );
      if (!_isCurrentExperience(id, generation)) return;
      _warmupCoordinator.markOfficialReady();
      _syncEntryCoordinatorFields();
      entryStatus = 'primeira_aula_pronta';
      _notifyFromChild();

      SecureLogger.log('SIM', 'CLASSROOM_OPENED', {
        'route': result.destination,
      });
      if (route == '/cyber/warmup' || warmupWaitingForOfficialLesson) {
        unawaited(_tryOpenOfficialAula(source: 'official_ready'));
      } else if (route == '/cyber/curriculo' &&
          _warmupCoordinator.warmupUnavailableAfterExpected) {
        unawaited(_tryOpenOfficialAula(source: 'official_ready'));
      }
    } on StudentExperienceEngineException catch (err) {
      if (!_isCurrentExperience(id, generation)) return;
      SecureLogger.log('SIM', 'BLOCKED', {'reason': err.error.kind.name});
      entryError = err.error.message;
      entryStatus = 'erro';
      _notifyFromChild();
    } catch (err) {
      if (!_isCurrentExperience(id, generation)) return;
      SecureLogger.log('SIM', 'BLOCKED', {'reason': 'unexpected'});
      entryError = humanErrorMessage(
        err,
        fallback:
            'Nao consegui preparar a entrada da aula agora. Toque para tentar novamente.',
      );
      entryStatus = 'erro';
      _notifyFromChild();
    }
  }

  void _markPlacementSkippedForMaterial(String id) {
    canonicalStore?.patchState(id, (state) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final placement = {
        ...?state.placement,
        'status': 'skipped',
        'choice': 'material_based',
        'source': 'material_based_entry',
        'reason': 'Material trazido define o ponto inicial; sem nivelamento.',
        'updated_at': now,
        'finished_at': now,
      };
      return state.copyWith(
        placement: placement,
        events: [
          ...state.events,
          StudentLearningEvent(
            type: 'PLACEMENT_SKIPPED_MATERIAL_BASED',
            ts: now,
            payload: const {
              'choice': 'material_based',
              'route': '/cyber/curriculo',
            },
          ),
        ],
      );
    }, allowLocalHousekeeping: true);
  }

  Future<void> continueFromPreparationToAula() async {
    if (entryStatus != 'primeira_aula_pronta') {
      await launchExperience();
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
    await _tryOpenOfficialAula(source: 'preparation_continue');
  }

  Future<void> _ensureFirstAulaRenderedBeforeRelease({
    required String id,
    required int generation,
  }) async {
    await openAulaRuntime();
    if (!_isCurrentExperience(id, generation)) return;
    if (_isFirstAulaTextRendered(aulaSnapshot)) {
      SecureLogger.log('SIM', 'FIRST_AULA_RENDER_READY');
      return;
    }
    throw StateError(
      aulaRuntimeError ??
          'A primeira aula ainda nao carregou explicacao, questao e alternativas.',
    );
  }

  bool _isFirstAulaTextRendered(LessonRuntimeSnapshot? snapshot) {
    if (snapshot == null || snapshot.hasCurriculum != true) return false;
    final content = snapshot.conteudo;
    if (content == null) return false;
    final hasExplanation = content.explanation.trim().isNotEmpty;
    final hasQuestion = content.question.trim().isNotEmpty;
    final optionCount = content.options.values
        .where((option) => option.trim().isNotEmpty)
        .length;
    return hasExplanation && hasQuestion && optionCount >= 3;
  }
}
