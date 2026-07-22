part of 'lab_session.dart';

extension LabSessionAmparoFlowExtensions on LabSession {
  AmparoRoomContext _amparoRoomContext(SimOrganism organism) {
    final state = organism.stateService.ensure(
      lessonLocalId: organism.lessonLocalId,
    );
    final curriculum = state.curriculum;
    final items = [
      for (final indexed
          in (curriculum?.items ?? const <CurriculumItem>[]).indexed)
        AuxRoomItem(
          marker: indexed.$2.marker,
          text: indexed.$2.text,
          itemIdx: indexed.$1,
        ),
    ];
    final snapshot = aulaSnapshot;
    final content = snapshot?.conteudo;
    final progress = state.progress;
    final current = state.current;
    return AmparoRoomContext(
      lessonLocalId: organism.lessonLocalId,
      topic:
          curriculum?.topic ??
          state.profile.objetivo ??
          state.profile.targetTopic ??
          '',
      items: items,
      itemIdx: current?.itemIdx ?? progress?.itemIdx ?? 0,
      marker: snapshot?.itemMarker ?? current?.marker,
      layer: current?.layer ?? progress?.layer ?? LessonLayer.l1,
      profile: AuxRoomProfile(
        stableLang: state.profile.stableLang ?? state.profile.language,
        academicLevel: state.profile.academicLevel ?? state.profile.nivel,
        preferredName: state.profile.preferredName,
        notes: state.profile.extra['student_profile_internal']?.toString(),
        localeContract: localeContract,
        extra: state.profile.toJson(),
      ),
      currentExplanation: content?.explanation ?? '',
      currentQuestion: content?.question ?? '',
      currentOptions: content?.options ?? const {},
      selectedAnswer: snapshot?.phase.letter,
      correctAnswer: content?.correctAnswer,
      signal: snapshot?.phase.signal,
    );
  }

  Future<void> startAmparoRoom() async {
    try {
      final organism = _activeOrganism ?? _organismForActiveLesson();
      if (recoveryRoom != null) return;
      navigationState.openRoute('/cyber/amparo');
      final context = _amparoRoomContext(organism);
      organism.auxRoomsController.openAmparoInstant(context);
      final opened = organism.auxRoomsController.amparo;
      if (opened != null) setAmparoRoom(opened);
      unawaited(
        organism.auxRoomsController
            .resolveAmparo(context)
            .then((_) {
              final current = amparoRoom;
              final resolved = organism.auxRoomsController.amparo;
              if (current == null || resolved == null) return;
              if (current.idx != resolved.idx) return;
              if (current.status != AmparoRoomStatus.intro &&
                  current.status != AmparoRoomStatus.preparing) {
                return;
              }
              setAmparoRoom(resolved);
            })
            .catchError((Object error, StackTrace stackTrace) {
              _recordRuntimeAudit(
                'AMPARO_ROUTE_FAILURE',
                source: 'LabSession.amparo_resolve',
                error: error,
                stackTrace: stackTrace,
              );
              final current = amparoRoom;
              if (current == null) return;
              setAmparoRoom(
                current.copyWith(
                  status: AmparoRoomStatus.failed,
                  errMsg:
                      'Nao consegui preparar o amparo agora. Sua aula foi preservada.',
                ),
              );
            }),
      );
    } catch (error, stackTrace) {
      _recordRuntimeAudit(
        'AMPARO_ROUTE_FAILURE',
        source: 'LabSession.startAmparoRoom',
        error: error,
        stackTrace: stackTrace,
      );
      setAmparoRoom(
        const AmparoRoomView(
          status: AmparoRoomStatus.failed,
          stations: [],
          idx: 0,
          amparoLvl: 0,
          errMsg:
              'Nao consegui preparar o amparo agora. Sua aula foi preservada.',
        ),
      );
    }
  }

  void amparoSelecionar(AnswerLetter letter) {
    final organism = _activeOrganism ?? _organismForActiveLesson();
    organism.auxRoomsController.amparoSelecionar(letter);
    final view = organism.auxRoomsController.amparo;
    if (view != null) setAmparoRoom(view);
  }

  Future<void> amparoSignal(DecisionSignal signal) async {
    try {
      final organism = _activeOrganism ?? _organismForActiveLesson();
      await organism.auxRoomsController.amparoEnviarSinal(
        _amparoRoomContext(organism),
        signal,
      );
      final view = organism.auxRoomsController.amparo;
      if (view != null) setAmparoRoom(view);
      _enqueueActiveLessonForRemoteVaultSync(reason: 'active_lesson_changed');
    } catch (_) {
      final current = amparoRoom;
      setAmparoRoom(
        (current ??
                const AmparoRoomView(
                  status: AmparoRoomStatus.failed,
                  stations: [],
                  idx: 0,
                  amparoLvl: 0,
                ))
            .copyWith(
              status: AmparoRoomStatus.failed,
              errMsg:
                  'Nao consegui enviar o amparo agora. Sua aula foi preservada.',
            ),
      );
    }
  }

  Future<void> amparoNext() async {
    try {
      final organism = _activeOrganism ?? _organismForActiveLesson();
      await organism.auxRoomsController.amparoNext(
        _amparoRoomContext(organism),
      );
      final view = organism.auxRoomsController.amparo;
      if (view != null) setAmparoRoom(view);
    } catch (_) {
      final current = amparoRoom;
      setAmparoRoom(
        (current ??
                const AmparoRoomView(
                  status: AmparoRoomStatus.failed,
                  stations: [],
                  idx: 0,
                  amparoLvl: 0,
                ))
            .copyWith(
              status: AmparoRoomStatus.failed,
              errMsg:
                  'Nao consegui preparar o proximo amparo agora. Sua aula foi preservada.',
            ),
      );
    }
  }

  void finishAmparo() {
    final organism = _activeOrganism ?? _organismForActiveLesson();
    organism.auxRoomsController.finishAmparo(organism.lessonLocalId);
    final view = organism.auxRoomsController.amparo;
    if (view != null) setAmparoRoom(view);
    closeAmparoRoom();
  }

  Future<void> _openTriggeredAmparoIfNeeded(SimOrganism organism) async {
    if (recoveryRoom != null || amparoRoom != null) return;
    if (!organism.auxRoomsController.shouldStartAmparo(
      organism.lessonLocalId,
    )) {
      return;
    }
    await startAmparoRoom();
  }
}
