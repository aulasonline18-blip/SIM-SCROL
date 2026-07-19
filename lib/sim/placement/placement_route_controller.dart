import '../experience/student_experience_store.dart';
import '../experience/student_experience_types.dart';
import '../state/student_learning_state_service.dart';
import 'placement_blocks.dart';
import 'placement_payload.dart';
import 'placement_plan_engine.dart';
import 'placement_scoring_engine.dart';
import 'placement_state.dart';
import 'placement_store.dart';
import 'placement_t02_caller.dart';

enum PlacementLocalStage { choice, intro, running, result, redirectToAula }

class PlacementChoiceScreenModel {
  const PlacementChoiceScreenModel({
    this.titleKey = 'placement_choice_h1',
    this.bodyKey = 'placement_choice_body',
    this.startBeginningKey = 'placement_start_beginning',
    this.takeQuickKey = 'placement_take_quick',
  });

  final String titleKey;
  final String bodyKey;
  final String startBeginningKey;
  final String takeQuickKey;
}

class PlacementIntroScreenModel {
  const PlacementIntroScreenModel({
    this.titleKey = 'placement_intro_h1',
    this.bodyKey = 'placement_intro_body',
    this.startKey = 'placement_start',
    this.preparingKey = 'placement_preparing',
  });

  final String titleKey;
  final String bodyKey;
  final String startKey;
  final String preparingKey;
}

class PlacementQuestionScreenModel {
  const PlacementQuestionScreenModel({
    required this.questionOfKey,
    required this.prompt,
    required this.choiceLabels,
  });

  final String questionOfKey;
  final String prompt;
  final List<String> choiceLabels;
}

class PlacementResultScreenModel {
  const PlacementResultScreenModel({
    required this.startMarker,
    this.titleKey = 'placement_result_h1',
    this.bodyKey = 'placement_result_body',
    this.startingAtKey = 'placement_starting_at',
    this.continueKey = 'continue',
  });

  final String startMarker;
  final String titleKey;
  final String bodyKey;
  final String startingAtKey;
  final String continueKey;
}

class PlacementRouteController {
  PlacementRouteController({
    required this.lessonLocalId,
    required this.stateService,
    required this.store,
    required this.t02Caller,
    required this.enabled,
  }) {
    final initial = store.readPlacement();
    blocks = initial.blocks;
    answers = initial.answers;
    result = initial.result;
    index = _resumePlacementIndex(initial);
    stage = switch (initial.status) {
      PlacementStatus.requested ||
      PlacementStatus.waitingPreparation ||
      PlacementStatus.running => PlacementLocalStage.running,
      PlacementStatus.done when initial.result != null =>
        PlacementLocalStage.result,
      _ =>
        enabled
            ? PlacementLocalStage.choice
            : PlacementLocalStage.redirectToAula,
    };
  }

  final String lessonLocalId;
  final StudentLearningStateService stateService;
  final PlacementStore store;
  final PlacementT02Caller t02Caller;
  final bool enabled;
  final PlacementPlanEngine planEngine = const PlacementPlanEngine();
  final PlacementScoringEngine scoringEngine = const PlacementScoringEngine();

  late PlacementLocalStage stage;
  List<PlacementBlock> blocks = const [];
  List<PlacementAnswer> answers = const [];
  int index = 0;
  PlacementResult? result;
  bool starting = false;

  String? get destination {
    return stage == PlacementLocalStage.redirectToAula ? '/cyber/aula' : null;
  }

  PlacementChoiceScreenModel choiceScreen() =>
      const PlacementChoiceScreenModel();

  PlacementIntroScreenModel introScreen() => const PlacementIntroScreenModel();

  PlacementQuestionScreenModel? questionScreen() {
    if (index < 0 || index >= blocks.length) return null;
    final block = blocks[index];
    return PlacementQuestionScreenModel(
      questionOfKey: 'placement_question_of',
      prompt: block.prompt,
      choiceLabels: block.choices.map((choice) => choice.label).toList(),
    );
  }

  PlacementResultScreenModel? resultScreen() {
    final current = result;
    return current == null
        ? null
        : PlacementResultScreenModel(startMarker: current.startMarker);
  }

  void skip() {
    store.resetPlacement();
    store.writePlacement(
      PlacementStoreState(
        pretestStatus: PlacementStatus.skipped,
        choice: 'start_from_zero',
        startMarker: null,
        startItemIdx: null,
        pretestSource: 'choice_gate',
        pretestFinishedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    publishStudentExperienceEvent(
      stateService,
      lessonLocalId,
      StudentExperienceEventType.placementStartFromZeroClicked,
      {'route': '/cyber/aula'},
    );
    stage = PlacementLocalStage.redirectToAula;
  }

  void chooseFindMyPoint() {
    store.writePlacement(
      PlacementStoreState(
        pretestStatus: PlacementStatus.requested,
        choice: 'find_my_point',
        pretestSource: 'adaptive_t02',
        pretestStartedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    stage = PlacementLocalStage.running;
  }

  Future<void> startTest() async {
    if (starting) return;
    starting = true;
    try {
      final context = buildPlacementContext(stateService.read(lessonLocalId));
      if (context == null) {
        blocks = const [];
        store.writePlacement(
          const PlacementStoreState(
            pretestStatus: PlacementStatus.waitingPreparation,
            choice: 'find_my_point',
            pretestSource: 'adaptive_t02',
            reason: 'Curriculo ainda vazio; aguardando preparacao.',
          ),
        );
        stage = PlacementLocalStage.running;
      } else {
        final plan = planEngine.build(context.curriculumItems);
        if (plan.waitingForCurriculum) {
          store.writePlacement(
            const PlacementStoreState(
              pretestStatus: PlacementStatus.waitingPreparation,
              choice: 'find_my_point',
              pretestSource: 'adaptive_t02',
              reason: 'Curriculo ainda vazio; aguardando preparacao.',
            ),
          );
          stage = PlacementLocalStage.running;
          return;
        }
        final PlacementT02Result? t02;
        try {
          t02 = await t02Caller.callPlacementT02ForPlan(context, plan);
        } catch (_) {
          _fallBackToBeginningAfterPlacementFailure();
          return;
        }
        if (t02?.blocks.isNotEmpty != true) {
          _fallBackToBeginningAfterPlacementFailure();
          return;
        }
        blocks = t02!.blocks;
        answers = [];
        index = 0;
        result = null;
        store.writePlacement(
          PlacementStoreState(
            pretestStatus: PlacementStatus.running,
            choice: 'find_my_point',
            pretestBlocks: blocks,
            pretestAnswers: answers,
            pretestResult: null,
            startMarker: null,
            startItemIdx: null,
            pretestIndex: 0,
            pretestSource: 'adaptive_t02',
            pretestLimited: false,
            pretestStartedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
      stage = PlacementLocalStage.running;
    } finally {
      starting = false;
    }
  }

  void answer(String choiceId) {
    if (index < 0 || index >= blocks.length) return;
    final block = blocks[index];
    final choice = block.choices
        .where((candidate) => candidate.id == choiceId)
        .firstOrNull;
    if (choice == null) return;
    final next = PlacementAnswer(
      blockId: block.id,
      marker: block.marker,
      choiceId: choice.id,
      correct: choice.correct,
      answeredAt: DateTime.now().millisecondsSinceEpoch,
    );
    answers = [...answers, next];
    final currentState = stateService.read(lessonLocalId);
    final curriculum = currentState?.curriculum;
    final shouldStop =
        curriculum != null &&
        scoringEngine.shouldStopEarly(
          curriculumItems: curriculum.items,
          blocks: blocks,
          answers: answers,
        );
    if (!shouldStop && index + 1 < blocks.length) {
      index += 1;
      store.writePlacement(
        PlacementStoreState(
          pretestStatus: PlacementStatus.running,
          pretestAnswers: answers,
          pretestIndex: index,
        ),
      );
      return;
    }

    store.writePlacement(
      const PlacementStoreState(pretestStatus: PlacementStatus.scoring),
    );
    result = curriculum == null
        ? null
        : scoringEngine.score(
            curriculumItems: curriculum.items,
            blocks: blocks,
            answers: answers,
          );
    if (result == null) {
      _fallBackToBeginningAfterPlacementFailure();
      return;
    }
    store.writePlacement(
      PlacementStoreState(
        pretestStatus: PlacementStatus.done,
        choice: 'find_my_point',
        pretestAnswers: answers,
        pretestResult: result,
        startMarker: result?.startMarker,
        startItemIdx: result?.startItemIdx,
        pretestIndex: index,
        pretestSource: result?.source,
        confidence: result?.confidence,
        reason: result?.reason,
        pretestFinishedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    stage = PlacementLocalStage.result;
  }

  void _fallBackToBeginningAfterPlacementFailure() {
    final state = stateService.read(lessonLocalId);
    final first = state?.curriculum?.items.firstOrNull;
    result = first == null
        ? null
        : PlacementResult(
            startMarker: first.marker,
            startItemIdx: 0,
            masteredMarkers: const [],
            uncertainMarkers: const [],
            failedMarkers: const [],
            testedMarkers: const [],
            confidence: 'low',
            reason:
                'Nao consegui diagnosticar com seguranca; inicio seguro no começo.',
            source: 'adaptive_t02_failed_safe_start',
            scoredAt: DateTime.now().millisecondsSinceEpoch,
          );
    store.writePlacement(
      PlacementStoreState(
        pretestStatus: first == null
            ? PlacementStatus.failed
            : PlacementStatus.done,
        choice: 'find_my_point',
        pretestResult: result,
        startMarker: result?.startMarker,
        startItemIdx: result?.startItemIdx,
        pretestSource: result?.source ?? 'adaptive_t02_failed',
        confidence: result?.confidence ?? 'low',
        reason: result?.reason ?? 'Curriculo ainda indisponivel.',
        pretestFinishedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    stage = first == null
        ? PlacementLocalStage.running
        : PlacementLocalStage.result;
  }

  void continueToAula() {
    publishStudentExperienceEvent(
      stateService,
      lessonLocalId,
      StudentExperienceEventType.placementContinueToAula,
      {'route': '/cyber/aula'},
    );
    stage = PlacementLocalStage.redirectToAula;
  }

  int _resumePlacementIndex(PlacementState initial) {
    final blocksCount = initial.blocks.length;
    final raw = initial.index;
    final byAnswers = initial.answers.length;
    final value = raw.isFinite ? raw : byAnswers;
    final max = blocksCount - 1;
    if (max < 0) return 0;
    return value.clamp(0, max);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
