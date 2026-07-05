import '../lesson/lesson_models.dart';
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
    required this.itemMarker,
    required this.itemText,
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
  final String? itemMarker;
  final String? itemText;

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
    Object? itemMarker = _unset,
    Object? itemText = _unset,
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
      itemMarker: identical(itemMarker, _unset)
          ? this.itemMarker
          : itemMarker as String?,
      itemText: identical(itemText, _unset)
          ? this.itemText
          : itemText as String?,
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
      pedagogicalEnvelope: currentState?.profile.toJson() ?? const {},
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
    if (lesson.imagem != null && lesson.imagem!.trim().isNotEmpty) {
      position.teoriaPronta = true;
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
  }

  Future<LessonRuntimeSnapshot> open({
    required String lessonLocalId,
    bool authReady = true,
    bool authed = true,
  }) async {
    final session = sessionEngine.read(lessonLocalId);
    _session = session;
    if (!authReady || !authed) {
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
        itemMarker: null,
        itemText: null,
      );
    }
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
        itemMarker: null,
        itemText: null,
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

  Future<void> advance() async {
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
    );
  }

  LessonRuntimeSnapshot snapshot() {
    _refreshSessionFromState();
    final position = _position;
    final session = _session;
    if (position == null || session == null) {
      return const LessonRuntimeSnapshot(
        authReady: true,
        authed: true,
        hasCurriculum: false,
        isDone: false,
        viewModel: null,
        phase: ClassroomPhase.loading(),
        history: [],
        conteudo: null,
        imagem: null,
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
    );
    return LessonRuntimeSnapshot(
      authReady: true,
      authed: true,
      hasCurriculum: session.curriculum != null && session.baseItems.isNotEmpty,
      isDone: position.phase.type == ClassroomPhaseType.fim,
      viewModel: vm,
      phase: position.phase,
      history: position.history,
      conteudo: position.conteudo,
      imagem: position.imagem,
      itemMarker: position.itemAtivo?.marker,
      itemText: position.itemAtivo?.text,
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
