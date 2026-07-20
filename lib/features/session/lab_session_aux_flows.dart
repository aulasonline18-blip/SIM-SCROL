part of 'lab_session.dart';

extension LabSessionAuxFlowExtensions on LabSession {
  void prefetchAuxRoomsAfterMainEvidence(SimOrganism organism) {
    try {
      final reviewContext = _reviewRoomContext(organism);
      organism.auxRoomsController.prefetchReview(reviewContext);
      organism.auxRoomsController.prefetchRecovery(RecoveryRoomContext(lessonLocalId: reviewContext.lessonLocalId, topic: reviewContext.topic, items: reviewContext.items, layer: reviewContext.layer, profile: reviewContext.profile));
    } catch (_) {}
  }
  ReviewRoomContext _reviewRoomContext(SimOrganism organism) {
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
    final progress = state.progress;
    return ReviewRoomContext(
      lessonLocalId: organism.lessonLocalId,
      topic:
          curriculum?.topic ??
          state.profile.objetivo ??
          state.profile.targetTopic ??
          '',
      items: items,
      fallbackStartIdx: progress?.itemIdx ?? state.current?.itemIdx ?? 0,
      layer: progress?.layer ?? state.current?.layer ?? LessonLayer.l1,
      profile: AuxRoomProfile(
        stableLang: state.profile.stableLang ?? state.profile.language,
        academicLevel: state.profile.academicLevel ?? state.profile.nivel,
        preferredName: state.profile.preferredName,
        notes: state.profile.extra['student_profile_internal']?.toString(),
        extra: state.profile.toJson(),
      ),
    );
  }
  RecoveryRoomContext _recoveryRoomContext(SimOrganism organism) {
    final reviewContext = _reviewRoomContext(organism);
    return RecoveryRoomContext(lessonLocalId: reviewContext.lessonLocalId, topic: reviewContext.topic, items: reviewContext.items, layer: reviewContext.layer, profile: reviewContext.profile);
  }
  Future<void> startReviewRoom(int count) async {
    ReviewRoomView? previous;
    try {
      final organism = _activeOrganism ?? _organismForActiveLesson();
      if (recoveryRoom != null) return;
      previous = lessonUiState.reviewRoom;
      final context = _reviewRoomContext(organism);
      organism.auxRoomsController.openReviewInstant(context, count);
      setReviewRoom(organism.auxRoomsController.review);
      unawaited(organism.auxRoomsController.resolveReview(context).then((_) {
        final current = reviewRoom;
        final resolved = organism.auxRoomsController.review;
        if (current == null || current.idx != resolved.idx) return;
        if (current.status == ReviewRoomStatus.intro ||
            current.status == ReviewRoomStatus.preparing) {
          setReviewRoom(resolved);
        }
      }).catchError((_) {
        final current = reviewRoom;
        if (current != null) {
          setReviewRoom(current.copyWith(status: ReviewRoomStatus.failed, errMsg: 'Nao consegui preparar a revisao agora. Sua aula foi preservada.'));
        }
      }));
    } catch (error) {
      setReviewRoom(
        ReviewRoomView(
          status: ReviewRoomStatus.failed,
          count: count == 10 ? 10 : 5,
          queue: previous?.queue ?? const [],
          idx: previous?.idx ?? 0,
          errMsg:
              'Nao consegui abrir a revisao agora. Sua aula foi preservada.',
        ),
      );
    }
  }
  void reviewSelecionar(AnswerLetter letter) {
    final organism = _activeOrganism ?? _organismForActiveLesson();
    organism.auxRoomsController.reviewSelecionar(letter);
    setReviewRoom(organism.auxRoomsController.review);
  }
  void reviewContinue() {
    final current = reviewRoom;
    if (current == null) return;
    setReviewRoom(current.copyWith(status: ReviewRoomStatus.answering));
  }
  Future<void> reviewSignal(DecisionSignal signal) async {
    try {
      final organism = _activeOrganism ?? _organismForActiveLesson();
      await organism.auxRoomsController.reviewEnviarSinal(
        _reviewRoomContext(organism),
        signal,
      );
      setReviewRoom(organism.auxRoomsController.review);
      _enqueueActiveLessonForRemoteVaultSync(reason: 'active_lesson_changed');
    } catch (error) {
      final current = reviewRoom;
      setReviewRoom(
        (current ??
                const ReviewRoomView(
                  status: ReviewRoomStatus.failed,
                  count: 5,
                  queue: [],
                  idx: 0,
                ))
            .copyWith(
              status: ReviewRoomStatus.failed,
              errMsg:
                  'Nao consegui enviar a revisao agora. Sua aula foi preservada.',
            ),
      );
    }
  }
  Future<void> reviewNext() async {
    try {
      final organism = _activeOrganism ?? _organismForActiveLesson();
      await organism.auxRoomsController.reviewNext(
        _reviewRoomContext(organism),
      );
      setReviewRoom(organism.auxRoomsController.review);
    } catch (error) {
      final current = reviewRoom;
      setReviewRoom(
        (current ??
                const ReviewRoomView(
                  status: ReviewRoomStatus.failed,
                  count: 5,
                  queue: [],
                  idx: 0,
                ))
            .copyWith(
              status: ReviewRoomStatus.failed,
              errMsg:
                  'Nao consegui preparar a proxima revisao agora. Sua aula foi preservada.',
            ),
      );
    }
  }
  Future<void> startRecoveryRoom() async {
    try {
      final organism = _activeOrganism ?? _organismForActiveLesson();
      final context = _recoveryRoomContext(organism);
      organism.auxRoomsController.openRecoveryInstant(context);
      final opened = organism.auxRoomsController.recovery;
      if (opened != null) setRecoveryRoom(opened);
      unawaited(organism.auxRoomsController.resolveRecovery(context).then((_) {
        final current = recoveryRoom;
        final resolved = organism.auxRoomsController.recovery;
        if (current == null || resolved == null || current.idx != resolved.idx) return;
        if (current.status == RecoveryRoomStatus.intro ||
            current.status == RecoveryRoomStatus.preparing) {
          setRecoveryRoom(resolved);
        }
      }).catchError((_) {
        final current = recoveryRoom;
        if (current != null) {
          setRecoveryRoom(current.copyWith(status: RecoveryRoomStatus.failed, errMsg: 'Nao consegui preparar a recuperacao agora. Sua aula foi preservada.'));
        }
      }));
    } catch (error) {
      setRecoveryRoom(
        const RecoveryRoomView(
          status: RecoveryRoomStatus.failed,
          queue: [],
          idx: 0,
          errMsg:
              'Nao consegui abrir a recuperacao agora. Sua aula foi preservada.',
        ),
      );
    }
  }
  void recoverySelecionar(AnswerLetter letter) {
    final organism = _activeOrganism ?? _organismForActiveLesson();
    organism.auxRoomsController.recoverySelecionar(letter);
    final view = organism.auxRoomsController.recovery;
    if (view != null) setRecoveryRoom(view);
  }
  void recoveryContinue() {
    final organism = _activeOrganism ?? _organismForActiveLesson();
    organism.auxRoomsController.continueRecovery();
    final view = organism.auxRoomsController.recovery;
    if (view != null) setRecoveryRoom(view);
  }
  Future<void> recoverySignal(DecisionSignal signal) async {
    try {
      final organism = _activeOrganism ?? _organismForActiveLesson();
      await organism.auxRoomsController.recoveryEnviarSinal(
        _recoveryRoomContext(organism),
        signal,
      );
      final view = organism.auxRoomsController.recovery;
      if (view != null) setRecoveryRoom(view);
      _enqueueActiveLessonForRemoteVaultSync(reason: 'active_lesson_changed');
    } catch (error) {
      final current = recoveryRoom;
      setRecoveryRoom(
        (current ??
                const RecoveryRoomView(
                  status: RecoveryRoomStatus.failed,
                  queue: [],
                  idx: 0,
                ))
            .copyWith(
              status: RecoveryRoomStatus.failed,
              errMsg:
                  'Nao consegui enviar a recuperacao agora. Sua aula foi preservada.',
            ),
      );
    }
  }
  Future<void> recoveryNext() async {
    try {
      final organism = _activeOrganism ?? _organismForActiveLesson();
      await organism.auxRoomsController.recoveryNext(
        _recoveryRoomContext(organism),
      );
      final view = organism.auxRoomsController.recovery;
      if (view != null) setRecoveryRoom(view);
    } catch (error) {
      final current = recoveryRoom;
      setRecoveryRoom(
        (current ??
                const RecoveryRoomView(
                  status: RecoveryRoomStatus.failed,
                  queue: [],
                  idx: 0,
                ))
            .copyWith(
              status: RecoveryRoomStatus.failed,
              errMsg:
                  'Nao consegui preparar a proxima recuperacao agora. Sua aula foi preservada.',
            ),
      );
    }
  }
  void finishRecovery() {
    final organism = _activeOrganism ?? _organismForActiveLesson();
    organism.auxRoomsController.finishRecovery(organism.lessonLocalId);
    final view = organism.auxRoomsController.recovery;
    if (view != null) setRecoveryRoom(view);
  }
}
