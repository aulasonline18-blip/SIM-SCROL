import '../lesson/lesson_models.dart';
import '../lesson/student_lesson_material_service.dart';
import '../media/lesson_image_api_contract.dart';
import '../state/live_entry_state.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'classroom_models.dart';
import 'lesson_answer_progress_controller.dart';
import 'lesson_hydration_engine.dart';
import 'lesson_main_view_model.dart';
import 'lesson_material_controller.dart';
import 'lesson_position_engine.dart';
import 'lesson_session_engine.dart';

class LessonRuntimeSnapshot {
  const LessonRuntimeSnapshot({
    required this.authReady,
    required this.authed,
    required this.hasCurriculum,
    required this.isDone,
    required this.viewModel,
    required this.phase,
    required this.history,
    required this.conteudo,
    required this.imagem,
    this.imageMetadata,
    required this.itemMarker,
    required this.itemText,
    this.itemUnit,
    this.itemTitle,
  });

  final bool authReady;
  final bool authed;
  final bool hasCurriculum;
  final bool isDone;
  final LessonMainViewModel? viewModel;
  final ClassroomPhase phase;
  final List<QuestionHistoryEntry> history;
  final LessonContent? conteudo;
  final String? imagem;
  final LessonImageGenerationMetadata? imageMetadata;
  final String? itemMarker;
  final String? itemText;
  final String? itemUnit;
  final String? itemTitle;

  static const Object _unset = Object();

  LessonRuntimeSnapshot copyWith({
    bool? authReady,
    bool? authed,
    bool? hasCurriculum,
    bool? isDone,
    Object? viewModel = _unset,
    ClassroomPhase? phase,
    List<QuestionHistoryEntry>? history,
    Object? conteudo = _unset,
    Object? imagem = _unset,
    Object? imageMetadata = _unset,
    Object? itemMarker = _unset,
    Object? itemText = _unset,
    Object? itemUnit = _unset,
    Object? itemTitle = _unset,
  }) {
    return LessonRuntimeSnapshot(
      authReady: authReady ?? this.authReady,
      authed: authed ?? this.authed,
      hasCurriculum: hasCurriculum ?? this.hasCurriculum,
      isDone: isDone ?? this.isDone,
      viewModel: identical(viewModel, _unset)
          ? this.viewModel
          : viewModel as LessonMainViewModel?,
      phase: phase ?? this.phase,
      history: history ?? this.history,
      conteudo: identical(conteudo, _unset)
          ? this.conteudo
          : conteudo as LessonContent?,
      imagem: identical(imagem, _unset) ? this.imagem : imagem as String?,
      imageMetadata: identical(imageMetadata, _unset)
          ? this.imageMetadata
          : imageMetadata as LessonImageGenerationMetadata?,
      itemMarker: identical(itemMarker, _unset)
          ? this.itemMarker
          : itemMarker as String?,
      itemText: identical(itemText, _unset)
          ? this.itemText
          : itemText as String?,
      itemUnit: identical(itemUnit, _unset)
          ? this.itemUnit
          : itemUnit as String?,
      itemTitle: identical(itemTitle, _unset)
          ? this.itemTitle
          : itemTitle as String?,
    );
  }
}

class LessonRuntimeEngine {
  LessonRuntimeEngine({
    required this.stateService,
    required this.sessionEngine,
    required this.hydrationEngine,
    required this.positionEngine,
    required this.materialController,
    required this.answerController,
  });

  final StudentLearningStateService stateService;
  final LessonSessionEngine sessionEngine;
  final LessonHydrationEngine hydrationEngine;
  final LessonPositionEngine positionEngine;
  final LessonMaterialController materialController;
  final LessonAnswerProgressController answerController;

  LessonPositionState? _position;
  LessonSessionSnapshot? _session;
  bool _lastAuthReady = true;
  bool _lastAuthed = true;

  CompleteLessonParams? activeLessonParams() {
    _refreshSessionFromState();
    final position = _position;
    final session = _session;
    final item = position?.itemAtivo;
    if (position == null || session == null || item == null) return null;
    final currentState = stateService.read(session.lessonLocalId);
    return CompleteLessonParams(
      lessonLocalId: session.lessonLocalId,
      item: item.text,
      lang: session.idioma,
      academic: session.academic,
      layer: position.layer,
      mode: LessonMode.session,
      errCount: position.erros,
      history: position.historia,
      marker: item.marker,
      amparoLvl: currentState?.progress?.amparoLvl,
      curriculumItems: _curriculumSnapshot(currentState?.curriculum),
      topic: currentState?.profile.objetivo ?? currentState?.curriculum?.topic,
      itemIdx: position.itemIdx,
      pedagogicalEnvelope: currentState?.profile.toJson() ?? const {},
      localeContract: currentState?.localeContract,
    );
  }

  String? activeLessonKey() {
    final params = activeLessonParams();
    return params == null ? null : lessonKeyFor(params);
  }

  bool applyLessonUpdateForKey(String key, CompleteLesson lesson) {
    _refreshSessionFromState();
    final position = _position;
    final activeKey = activeLessonKey();
    if (position == null || activeKey == null || activeKey != key) {
      return false;
    }
    position.conteudo = lesson.conteudo;
    position.imagem = lesson.imagem;
    position.imageMetadata = lesson.imageMetadata;
    position.teoriaPronta = true;
    if (position.phase.type == ClassroomPhaseType.avancoPendente) {
      position.phase = const ClassroomPhase.reading();
    }
    return true;
  }

  void restoreTransientSnapshot(LessonRuntimeSnapshot snapshot) {
    final position = _position;
    if (position == null) return;
    position.phase = snapshot.phase;
    position.history = snapshot.history;
    position.conteudo = snapshot.conteudo;
    position.imagem = snapshot.imagem;
    position.imageMetadata = snapshot.imageMetadata;
  }

  Future<LessonRuntimeSnapshot> open({
    required String lessonLocalId,
    bool authReady = true,
    bool authed = true,
    bool menuOpenPriority = false,
    bool suppressReadyWindowUntilVisibleLessonReady = false,
    void Function(ResolveLessonMaterialResult result)? onBackgroundResolved,
  }) async {
    _lastAuthReady = authReady;
    _lastAuthed = authed;
    final session = sessionEngine.read(lessonLocalId);
    _session = session;
    if (session.curriculum == null || session.baseItems.isEmpty) {
      return LessonRuntimeSnapshot(
        authReady: authReady,
        authed: authed,
        hasCurriculum: false,
        isDone: false,
        viewModel: null,
        phase: const ClassroomPhase.loading(),
        history: const [],
        conteudo: null,
        imagem: null,
        imageMetadata: null,
        itemMarker: null,
        itemText: null,
        itemUnit: null,
        itemTitle: null,
      );
    }

    final hydration = hydrationEngine.hydrate(
      state: session.state,
      baseItems: session.baseItems,
      lessonLocalId: lessonLocalId,
      topic: session.curriculum?.topic ?? session.onboarding.objetivo,
      idioma: session.idioma,
      academic: session.academic,
    );
    final position = positionEngine.create(
      initialProgress: hydration.initialProgress,
      initialFastLesson: hydration.initialFastLesson,
      baseItems: session.baseItems,
    );
    _position = position;
    if (hydration.initialFastLesson == null && position.itemAtivo != null) {
      await materialController.carregar(
        lessonLocalId: lessonLocalId,
        topic: session.curriculum?.topic ?? session.onboarding.objetivo,
        position: position,
        idioma: session.idioma,
        academic: session.academic,
        mode: LessonMode.session,
        baseItems: session.baseItems,
        allowRemoteOrder: menuOpenPriority,
        waitAfterOrderMs: 0,
        missingSource: menuOpenPriority
            ? 'drawer.aula.visible-request'
            : 'cyber.aula.local-preparation',
        missingPriority: menuOpenPriority ? 'hot-local' : 'background',
        missingReason: menuOpenPriority
            ? 'drawer_visible_lesson_not_ready_yet'
            : 'material_missing_prepare_without_fallback',
        remoteOrderPriority: menuOpenPriority ? 'hot-local' : 'background',
        suppressReadyWindowUntilVisibleLessonReady:
            suppressReadyWindowUntilVisibleLessonReady,
        onBackgroundResolved: onBackgroundResolved,
      );
    }
    return snapshot();
  }

  void select(AnswerLetter letter) {
    final position = _position;
    if (position == null) return;
    answerController.selecionar(position, letter);
  }

  Future<void> signal(DecisionSignal signal) async {
    _refreshSessionFromState();
    final position = _position;
    final session = _session;
    if (position == null || session == null) return;
    await answerController.enviarSinal(
      lessonLocalId: session.lessonLocalId,
      topic: session.curriculum?.topic ?? session.onboarding.objetivo,
      position: position,
      signal: signal,
      baseItems: session.baseItems,
    );
  }

  Future<void> advance({
    void Function(ResolveLessonMaterialResult result)? onBackgroundResolved,
  }) async {
    _refreshSessionFromState();
    final position = _position;
    final session = _session;
    if (position == null || session == null) return;
    await answerController.avancar(
      lessonLocalId: session.lessonLocalId,
      topic: session.curriculum?.topic ?? session.onboarding.objetivo,
      position: position,
      baseItems: session.baseItems,
      idioma: session.idioma,
      academic: session.academic,
      onBackgroundResolved: onBackgroundResolved,
    );
  }

  bool reavaliarAvancoPendente({bool recoverFailedJobs = true}) {
    _refreshSessionFromState();
    final position = _position;
    final session = _session;
    if (position == null || session == null) return false;
    return answerController.reavaliarAvancoPendente(
      lessonLocalId: session.lessonLocalId,
      topic: session.curriculum?.topic ?? session.onboarding.objetivo,
      position: position,
      baseItems: session.baseItems,
      idioma: session.idioma,
      academic: session.academic,
      recoverFailedJobs: recoverFailedJobs,
    );
  }

  bool reavaliarMaterialVisivelSolicitado() {
    _refreshSessionFromState();
    final position = _position;
    final session = _session;
    if (position == null || session == null) return false;
    if (position.phase.type != ClassroomPhaseType.avancoPendente) {
      return false;
    }
    final state = stateService.read(session.lessonLocalId);
    if (state?.extra['advancePending'] is Map) return false;
    if (position.itemAtivo == null) return false;
    return materialController.carregarRapidoSePronto(
      lessonLocalId: session.lessonLocalId,
      topic: session.curriculum?.topic ?? session.onboarding.objetivo,
      position: position,
      idioma: session.idioma,
      academic: session.academic,
      mode: LessonMode.session,
      baseItems: session.baseItems,
    );
  }

  bool reavaliarMaterialAtualSePronto() {
    _refreshSessionFromState();
    final position = _position;
    final session = _session;
    if (position == null || session == null || position.itemAtivo == null) {
      return false;
    }
    final renderedQuestion = position.conteudo?.question.trim();
    final key = preparedLessonMaterialKey(
      position.itemIdx,
      position.itemAtivo?.marker,
      position.layer,
    );
    final prepared = stateService
        .read(session.lessonLocalId)
        ?.readyLessonMaterials[key];
    final preparedQuestion =
        (prepared?['question'] as String?)?.trim() ??
        (prepared?['pergunta'] as String?)?.trim();
    if (position.phase.type == ClassroomPhaseType.lendo &&
        renderedQuestion != null &&
        renderedQuestion.isNotEmpty &&
        renderedQuestion == preparedQuestion) {
      return false;
    }
    return materialController.carregarRapidoSePronto(
      lessonLocalId: session.lessonLocalId,
      topic: session.curriculum?.topic ?? session.onboarding.objetivo,
      position: position,
      idioma: session.idioma,
      academic: session.academic,
      mode: LessonMode.session,
      baseItems: session.baseItems,
    );
  }

  LessonRuntimeSnapshot snapshot() {
    _refreshSessionFromState();
    final position = _position;
    final session = _session;
    if (position == null || session == null) {
      return LessonRuntimeSnapshot(
        authReady: _lastAuthReady,
        authed: _lastAuthed,
        hasCurriculum: false,
        isDone: false,
        viewModel: null,
        phase: const ClassroomPhase.loading(),
        history: const [],
        conteudo: null,
        imagem: null,
        imageMetadata: null,
        itemMarker: null,
        itemText: null,
      );
    }
    final vm = buildLessonMainViewModel(
      baseItems: session.baseItems,
      mainAdvances: position.mainAdvances,
      isReviewAtivo: position.isReviewAtivo,
      itemAtivo: position.itemAtivo,
      itemIdx: position.itemIdx,
      layer: position.layer,
      phase: position.phase,
      conteudo: position.conteudo,
      items: position.items,
      globalPlan: session.curriculum?.globalPlan,
    );
    return LessonRuntimeSnapshot(
      authReady: _lastAuthReady,
      authed: _lastAuthed,
      hasCurriculum: session.curriculum != null && session.baseItems.isNotEmpty,
      isDone: position.phase.type == ClassroomPhaseType.fim,
      viewModel: vm,
      phase: position.phase,
      history: position.history,
      conteudo: position.conteudo,
      imagem: position.imagem,
      imageMetadata: position.imageMetadata,
      itemMarker: position.itemAtivo?.marker,
      itemText: position.itemAtivo?.text,
      itemUnit: position.itemAtivo?.unit,
      itemTitle: position.itemAtivo?.title ?? position.itemAtivo?.text,
    );
  }

  void _refreshSessionFromState() {
    final currentSession = _session;
    if (currentSession == null) return;
    final latestSession = sessionEngine.read(currentSession.lessonLocalId);
    _session = latestSession;
    final position = _position;
    if (position != null) {
      positionEngine.mergeBaseItems(position, latestSession.baseItems);
    }
  }
}

List<JsonMap> _curriculumSnapshot(StudentCurriculum? curriculum) {
  final items = curriculum?.items ?? const <CurriculumItem>[];
  return [
    for (var index = 0; index < items.length; index += 1)
      {
        'order': index + 1,
        'marker': items[index].marker,
        if ((items[index].unit ?? '').trim().isNotEmpty)
          'unit': items[index].unit!.trim(),
        'title': items[index].title ?? items[index].text,
        'text': items[index].text,
        'purpose': items[index].teacherText,
        'microitem_for_teacher': items[index].teacherText,
      },
  ];
}
