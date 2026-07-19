import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/organism/sim_organism.dart';
import 'package:sim_mobile/sim/placement/placement_addendum.dart';
import 'package:sim_mobile/sim/placement/placement_blocks.dart';
import 'package:sim_mobile/sim/placement/placement_payload.dart';
import 'package:sim_mobile/sim/placement/placement_plan_engine.dart';
import 'package:sim_mobile/sim/placement/placement_route_controller.dart';
import 'package:sim_mobile/sim/placement/placement_scoring_engine.dart';
import 'package:sim_mobile/sim/placement/placement_state.dart';
import 'package:sim_mobile/sim/placement/placement_store.dart';
import 'package:sim_mobile/sim/placement/placement_t02_caller.dart';
import 'package:sim_mobile/sim/placement/student_placement_service.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

class FakePlacementT02 implements T02LessonClient {
  FakePlacementT02({this.fail = false});

  final bool fail;
  int placementCalls = 0;
  final requests = <T02LessonRequest>[];

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) async {
    if (fail) throw StateError('T02 indisponivel');
    placementCalls += 1;
    requests.add(request);
    return T02LessonMaterial(
      explanation: 'Diagnostico',
      question: 'Qual alternativa mostra dominio?',
      options: const {
        AnswerLetter.A: 'Domino',
        AnswerLetter.B: 'Ainda nao',
        AnswerLetter.C: 'Nao sei',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'A indica dominio.',
      whyWrong: null,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'fake-placement',
    );
  }

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) =>
      placement(request);

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) =>
      placement(request);

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) =>
      placement(request);
}

StudentLearningState _placementState({
  int itemCount = 3,
  StudentLearningState Function(StudentLearningState state)? patch,
}) {
  final items = [
    for (var i = 0; i < itemCount; i++)
      CurriculumItem(marker: 'M${i + 1}', text: 'Item ${i + 1}'),
  ];
  final state = StudentLearningState.empty(lessonLocalId: 'cyber-placement')
      .copyWith(
        profile: const StudentProfile(
          objetivo: 'Aprender algebra',
          stableLang: 'pt-BR',
          academicLevel: 'fundamental',
        ),
        curriculum: StudentCurriculum(
          topic: 'Aprender algebra',
          totalItems: itemCount,
          generatedAt: null,
          provisional: false,
          items: items,
        ),
      );
  return patch == null ? state : patch(state);
}

PlacementBlock _block(String marker, {int idx = 0}) => PlacementBlock(
  id: 'b-$marker',
  marker: marker,
  prompt: 'Pergunta $marker',
  choices: const [
    PlacementChoice(id: 'A', label: 'A', correct: true),
    PlacementChoice(id: 'B', label: 'B', correct: false),
    PlacementChoice(id: 'C', label: 'C', correct: false),
  ],
);

void main() {
  test('scorePlacement starts at first failed marker', () {
    final blocks = createPretestBlocks(_placementState().curriculum!.items);
    final result = scorePlacement(blocks, [
      PlacementAnswer(
        blockId: blocks[0].id,
        marker: 'M1',
        choiceId: blocks[0].choices.first.id,
        correct: true,
        answeredAt: 1,
      ),
      PlacementAnswer(
        blockId: blocks[1].id,
        marker: 'M2',
        choiceId: blocks[1].choices.last.id,
        correct: false,
        answeredAt: 2,
      ),
    ], now: 3);

    expect(result?.startMarker, 'M2');
    expect(result?.masteredMarkers, ['M1']);
    expect(result?.failedMarkers, ['M2']);
    expect(result?.confidence, isNotEmpty);
  });

  test(
    'StudentPlacementService writes canonical placement and legacy mirror',
    () {
      final stateService = StudentLearningStateService(
        seed: {'cyber-placement': _placementState()},
      );
      final service = StudentPlacementService(
        stateService: stateService,
        lessonLocalId: 'cyber-placement',
      );
      final blocks = createPretestBlocks(_placementState().curriculum!.items);
      service.update(
        PlacementState.empty().copyWith(
          status: PlacementStatus.running,
          choice: 'find_my_point',
          blocks: blocks,
          index: 1,
          source: 'adaptive_t02',
          confidence: 'medium',
          reason: 'diagnostico em curso',
          limited: true,
        ),
      );

      final state = stateService.read('cyber-placement')!;
      expect(service.read().status, PlacementStatus.running);
      expect(state.placement?['status'], 'running');
      expect(state.placement?['choice'], 'find_my_point');
      expect(state.placement?['confidence'], 'medium');
      expect(state.profile.extra['pretest_status'], 'running');
      expect(state.profile.extra['placement_choice'], 'find_my_point');
    },
  );

  test(
    'PlacementT02Caller uses real T02 with placement mode and literal addendum',
    () async {
      final t02 = FakePlacementT02();
      final caller = PlacementT02Caller(t02Client: t02, enabled: true);
      final context = buildPlacementContext(_placementState())!;

      final result = await caller.callPlacementT02(context);

      expect(t02.placementCalls, 3);
      expect(result?.blocks, hasLength(3));
      expect(result?.blocks.first.marker, 'M1');
      final request = t02.requests.first;
      expect(request.mode, 'placement');
      expect(request.addendum, placementAssessmentAddendum);
      expect(request.history, isEmpty);
      expect(request.marker, 'M1');
      expect(request.itemIdx, 0);
      expect(request.profile['student_profile_internal'], isA<Map>());
      expect(request.profile['target_topic'], 'Aprender algebra');
      expect(request.profile['guidance_for_T02'], placementAssessmentAddendum);
    },
  );

  test('PlacementRouteController runs adaptive question result flow', () async {
    final stateService = StudentLearningStateService(
      seed: {'cyber-placement': _placementState()},
    );
    final placementService = StudentPlacementService(
      stateService: stateService,
      lessonLocalId: 'cyber-placement',
    );
    final controller = PlacementRouteController(
      lessonLocalId: 'cyber-placement',
      stateService: stateService,
      store: PlacementStore(placementService),
      t02Caller: PlacementT02Caller(
        t02Client: FakePlacementT02(),
        enabled: true,
      ),
      enabled: true,
    );

    expect(controller.stage, PlacementLocalStage.choice);
    controller.chooseFindMyPoint();
    expect(controller.stage, PlacementLocalStage.running);
    await controller.startTest();
    expect(controller.stage, PlacementLocalStage.running);

    while (controller.stage == PlacementLocalStage.running &&
        controller.questionScreen() != null) {
      final firstChoice = controller.blocks[controller.index].choices.first.id;
      controller.answer(firstChoice);
    }

    expect(controller.stage, PlacementLocalStage.result);
    final placement = placementService.read();
    expect(placement.status, PlacementStatus.done);
    expect(placement.choice, 'find_my_point');
    expect(placement.result?.source, 'adaptive_t02');
    expect(placement.startItemIdx, 2);
    controller.continueToAula();
    expect(controller.destination, '/cyber/aula');
  });

  test(
    'PlacementPlanEngine creates short and strategic plans by curriculum size',
    () {
      const engine = PlacementPlanEngine();

      final small = engine.build(
        _placementState(itemCount: 5).curriculum!.items,
      );
      expect(small.strategy, 'small_ordered');
      expect(small.gates.map((gate) => gate.itemIdx), [0, 1, 2, 3, 4]);
      expect(small.maxQuestions, 5);

      final medium = engine.build(
        _placementState(itemCount: 12).curriculum!.items,
      );
      expect(medium.strategy, 'medium_boundary');
      expect(medium.gates.map((gate) => gate.itemIdx), [0, 6, 8]);
      expect(medium.maxQuestions, 6);

      final large = engine.build(
        _placementState(itemCount: 40).curriculum!.items,
      );
      expect(large.strategy, 'large_adaptive_boundary');
      expect(large.gates.map((gate) => gate.itemIdx), [0, 10, 20, 29]);
      expect(large.maxQuestions, 7);
    },
  );

  test('PlacementPlanEngine waits when curriculum is empty', () {
    const engine = PlacementPlanEngine();

    final plan = engine.build(const []);

    expect(plan.waitingForCurriculum, isTrue);
    expect(plan.gates, isEmpty);
    expect(plan.strategy, 'waiting_curriculum');
  });

  test(
    'PlacementScoringEngine starts safely before basic or uncertain gaps',
    () {
      final curriculum = _placementState(itemCount: 10).curriculum!.items;
      const engine = PlacementScoringEngine();
      final blocks = [_block('M1', idx: 0), _block('M6', idx: 5)];

      final basicFailure = engine.score(
        curriculumItems: curriculum,
        blocks: blocks,
        answers: [
          PlacementAnswer(
            blockId: 'b-M1',
            marker: 'M1',
            choiceId: 'B',
            correct: false,
            answeredAt: 1,
          ),
        ],
        now: 2,
      );

      expect(basicFailure?.startMarker, 'M1');
      expect(basicFailure?.confidence, 'high');

      final uncertain = engine.score(
        curriculumItems: curriculum,
        blocks: blocks,
        answers: [
          PlacementAnswer(
            blockId: 'b-M1',
            marker: 'M1',
            choiceId: 'A',
            correct: true,
            signal: 3,
            answeredAt: 1,
          ),
        ],
        now: 2,
      );

      expect(uncertain?.startMarker, 'M1');
      expect(uncertain?.uncertainMarkers, ['M1']);
    },
  );

  test(
    'PlacementScoringEngine does not let isolated advanced success skip base',
    () {
      final curriculum = _placementState(itemCount: 10).curriculum!.items;
      const engine = PlacementScoringEngine();

      final result = engine.score(
        curriculumItems: curriculum,
        blocks: [_block('M8', idx: 7)],
        answers: [
          PlacementAnswer(
            blockId: 'b-M8',
            marker: 'M8',
            choiceId: 'A',
            correct: true,
            answeredAt: 1,
          ),
        ],
        now: 2,
      );

      expect(result?.startMarker, 'M1');
      expect(result?.confidence, 'low');
    },
  );

  test('PlacementScoringEngine stops early when confidence is sufficient', () {
    final curriculum = _placementState(itemCount: 5).curriculum!.items;
    const engine = PlacementScoringEngine();

    final shouldStop = engine.shouldStopEarly(
      curriculumItems: curriculum,
      blocks: [_block('M1', idx: 0), _block('M2', idx: 1)],
      answers: [
        PlacementAnswer(
          blockId: 'b-M1',
          marker: 'M1',
          choiceId: 'B',
          correct: false,
          answeredAt: 1,
        ),
      ],
    );

    expect(shouldStop, isTrue);
  });

  test(
    'Placement answers do not contaminate official lesson authority',
    () async {
      final initial = _placementState();
      final stateService = StudentLearningStateService(
        seed: {'cyber-placement': initial},
      );
      final placementService = StudentPlacementService(
        stateService: stateService,
        lessonLocalId: 'cyber-placement',
      );
      final controller = PlacementRouteController(
        lessonLocalId: 'cyber-placement',
        stateService: stateService,
        store: PlacementStore(placementService),
        t02Caller: PlacementT02Caller(
          t02Client: FakePlacementT02(),
          enabled: true,
        ),
        enabled: true,
      );

      controller.chooseFindMyPoint();
      await controller.startTest();
      controller.answer(controller.blocks.first.choices.first.id);

      final state = stateService.read('cyber-placement')!;
      expect(state.current?.toJson(), initial.current?.toJson());
      expect(state.progress?.toJson(), initial.progress?.toJson());
      expect(state.attempts, initial.attempts);
      expect(state.truth.toJson(), initial.truth.toJson());
      expect(placementService.read().answers, isNotEmpty);
    },
  );

  test(
    'T02 failure creates safe result without fake question or blocking route',
    () async {
      final stateService = StudentLearningStateService(
        seed: {'cyber-placement': _placementState()},
      );
      final placementService = StudentPlacementService(
        stateService: stateService,
        lessonLocalId: 'cyber-placement',
      );
      final controller = PlacementRouteController(
        lessonLocalId: 'cyber-placement',
        stateService: stateService,
        store: PlacementStore(placementService),
        t02Caller: PlacementT02Caller(
          t02Client: FakePlacementT02(fail: true),
          enabled: true,
        ),
        enabled: true,
      );

      controller.chooseFindMyPoint();
      await controller.startTest();

      final placement = placementService.read();
      expect(controller.stage, PlacementLocalStage.result);
      expect(controller.blocks, isEmpty);
      expect(placement.status, PlacementStatus.done);
      expect(placement.startMarker, 'M1');
      expect(placement.confidence, 'low');
      expect(placement.source, 'adaptive_t02_failed_safe_start');
    },
  );

  test(
    '/cyber/placement is routed by SimOrganismRouter and no legacy api exists',
    () {
      const router = SimOrganismRouter();

      final decision = router.resolve(
        path: '/cyber/placement',
        authed: true,
        hasLanguage: true,
        hasObjective: true,
      );

      expect(decision.allowed, isTrue);
      expect(
        Directory('lib').listSync(recursive: true).whereType<File>().any((
          file,
        ) {
          if (!file.path.endsWith('.dart')) return false;
          return file.readAsStringSync().contains('/api/placement');
        }),
        isFalse,
      );
    },
  );
}
