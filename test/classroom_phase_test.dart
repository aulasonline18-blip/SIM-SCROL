import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_answer_progress_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_hydration_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_material_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_position_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_session_engine.dart';
import 'package:sim_mobile/sim/classroom/server_advance_gate.dart';
import 'package:sim_mobile/sim/lesson/dopamine_ready_window_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/lesson/student_lesson_material_service.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';
import 'package:sim_mobile/sim/state/student_state_store_adapter.dart';

class FakeClassroomT02 implements T02LessonClient {
  int calls = 0;
  final requests = <T02LessonRequest>[];

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    calls += 1;
    requests.add(request);
    return T02LessonMaterial(
      explanation: 'Explicacao ${request.item} L${request.layer.value}',
      question: 'Pergunta ${request.marker ?? request.item}?',
      options: const {
        AnswerLetter.A: 'Alternativa A',
        AnswerLetter.B: 'Alternativa B',
        AnswerLetter.C: 'Alternativa C',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'A esta correta.',
      whyWrong: null,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'fake-classroom',
    );
  }

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) =>
      completeLesson(request);
}

class FakeServerAdvanceGateClient implements ServerAdvanceGateClient {
  FakeServerAdvanceGateClient(this.decision);

  final ServerAdvanceGateDecision decision;
  final requests = <ServerAdvanceGateRequest>[];

  @override
  Future<ServerAdvanceGateDecision> decide(
    ServerAdvanceGateRequest request,
  ) async {
    requests.add(request);
    return decision;
  }
}

class OfficialRouteAdvanceGateClient implements ServerAdvanceGateClient {
  final requests = <ServerAdvanceGateRequest>[];

  @override
  Future<ServerAdvanceGateDecision> decide(
    ServerAdvanceGateRequest request,
  ) async {
    requests.add(request);
    final isLastLayer = request.layer == LessonLayer.l3;
    final secureL1 =
        request.layer == LessonLayer.l1 &&
        request.correct &&
        request.signal == DecisionSignal.one;
    final nextItemIdx = isLastLayer ? request.itemIdx + 1 : request.itemIdx;
    final nextLayer = isLastLayer
        ? LessonLayer.l1
        : secureL1
        ? LessonLayer.l3
        : LessonLayerValue.fromValue(request.layer.value + 1);
    return ServerAdvanceGateDecision(
      accepted: true,
      decision: isLastLayer ? 'next_item' : 'next_layer',
      reason: isLastLayer
          ? (request.correct
                ? 'l3_to_next_item'
                : 'l3_completed_with_repair_due')
          : secureL1
          ? 'secure_l1_skip_to_layer_3'
          : request.layer == LessonLayer.l1
          ? (request.correct ? 'l1_to_layer_2' : 'l1_error_to_layer_2')
          : (request.correct ? 'l2_to_layer_3' : 'l2_error_to_layer_3'),
      nextItemIdx: nextItemIdx,
      nextLayer: nextLayer,
      highWaterMark: requests.length,
      events: [
        {
          'type': 'ADVANCE_GATE_DECIDED',
          'decision': isLastLayer ? 'next_item' : 'next_layer',
          'marker': request.marker,
          'layer': request.layer.value,
          'letra': request.selectedOption.name,
          'sinal': request.signal.value,
          'correct': request.correct,
        },
      ],
    );
  }
}

class FailingServerAdvanceGateClient implements ServerAdvanceGateClient {
  final requests = <ServerAdvanceGateRequest>[];

  @override
  Future<ServerAdvanceGateDecision> decide(
    ServerAdvanceGateRequest request,
  ) async {
    requests.add(request);
    throw Exception('advance gate unavailable');
  }
}

class FlakyServerAdvanceGateClient implements ServerAdvanceGateClient {
  final requests = <ServerAdvanceGateRequest>[];

  @override
  Future<ServerAdvanceGateDecision> decide(
    ServerAdvanceGateRequest request,
  ) async {
    requests.add(request);
    if (requests.length == 1) {
      throw Exception('advance gate unavailable');
    }
    return ServerAdvanceGateDecision(
      accepted: true,
      decision: 'next_layer',
      reason: 'retry_accepted',
      nextItemIdx: request.itemIdx,
      nextLayer: LessonLayer.l3,
      highWaterMark: 2,
      duplicate: true,
      events: [
        {
          'type': 'ADVANCE_GATE_DECIDED',
          'decision': 'next_layer',
          'marker': request.marker,
          'layer': request.layer.value,
          'letra': request.selectedOption.name,
          'sinal': request.signal.value,
          'correct': request.correct,
        },
      ],
    );
  }
}

StudentLearningState _classroomState() {
  const items = [
    CurriculumItem(marker: 'M1', text: 'Item 1'),
    CurriculumItem(marker: 'M2', text: 'Item 2'),
  ];
  return StudentLearningState.empty(lessonLocalId: 'cyber-class').copyWith(
    profile: const StudentProfile(
      objetivo: 'Aprender regra de tres',
      stableLang: 'pt-BR',
      nivel: 'base',
    ),
    curriculum: const StudentCurriculum(
      topic: 'Aprender regra de tres',
      totalItems: 2,
      generatedAt: null,
      provisional: false,
      items: items,
    ),
    current: const LessonCurrent(
      itemIdx: 0,
      marker: 'M1',
      layer: LessonLayer.l1,
      amparoLvl: 0,
    ),
    progress: const LessonProgress(
      itemIdx: 0,
      layer: LessonLayer.l1,
      erros: 0,
      amparoLvl: 0,
      historia: [],
      mainAdvances: 0,
      concluidos: [],
      pendentesMarkers: [],
      totalItems: 2,
      pctAvanco: 0,
    ),
  );
}

StudentLearningState _largeCurriculumBoundaryState() {
  final items = List<CurriculumItem>.generate(
    80,
    (index) => CurriculumItem(
      marker: 'M${index + 1}',
      text: 'Item ${index + 1}',
      extra: {'globalItemNumber': index + 1, 'partNumber': 1},
    ),
  );
  return StudentLearningState.empty(
    lessonLocalId: 'lesson-cg-root',
    userId: 'user-cg',
    now: 1,
  ).copyWith(
    profile: const StudentProfile(
      objetivo: 'Curriculo grande',
      stableLang: 'pt-BR',
      nivel: 'base',
    ),
    curriculum: StudentCurriculum(
      topic: 'Curriculo grande',
      totalItems: 80,
      generatedAt: null,
      provisional: false,
      items: items,
      globalPlan: const CurriculumGlobalPlan(
        globalTotalItems: 180,
        batchStartItem: 1,
        batchEndItem: 80,
        operationalBatchLimit: 80,
        partNumber: 1,
        nextGlobalItemToRequest: 81,
        continuationNeeded: true,
      ),
    ),
    current: const LessonCurrent(
      itemIdx: 79,
      marker: 'M80',
      layer: LessonLayer.l3,
      amparoLvl: 0,
    ),
    progress: const LessonProgress(
      itemIdx: 79,
      layer: LessonLayer.l3,
      erros: 0,
      amparoLvl: 0,
      historia: ['M1:L1:A:1'],
      mainAdvances: 79,
      concluidos: ['M1'],
      pendentesMarkers: [],
      totalItems: 180,
      pctAvanco: 43,
    ),
    extra: const {'curriculumPlanRootLessonId': 'lesson-cg-root'},
  );
}

LessonRuntimeEngine _runtime(
  StudentLearningStateService stateService,
  FakeClassroomT02 t02, {
  StudentStateStore? store,
  ServerAdvanceGateClient? serverAdvanceGateClient,
}) {
  final orchestrator = LessonOrchestrator(
    t02Client: t02,
    cache: LessonMaterialCache(),
    bus: LessonEventBus(),
  );
  late DopamineReadyWindowEngine readyWindow;
  late StudentLessonMaterialService materialService;
  readyWindow = DopamineReadyWindowEngine(
    service: stateService,
    orchestrator: orchestrator,
  );
  materialService = StudentLessonMaterialService(
    stateService: stateService,
    orchestrator: orchestrator,
    readyWindowEngine: readyWindow,
  );
  final materialController = LessonMaterialController(
    stateService: stateService,
    materialService: materialService,
  );
  return LessonRuntimeEngine(
    stateService: stateService,
    sessionEngine: LessonSessionEngine(service: stateService),
    hydrationEngine: LessonHydrationEngine(materialService: materialService),
    positionEngine: LessonPositionEngine(),
    materialController: materialController,
    answerController: LessonAnswerProgressController(
      stateService: stateService,
      materialService: materialService,
      materialController: materialController,
      store: store,
      serverAdvanceGateClient: serverAdvanceGateClient,
    ),
  );
}

void main() {
  test(
    'LessonRuntimeEngine opens classroom and loads first material',
    () async {
      final service = StudentLearningStateService(
        seed: {'cyber-class': _classroomState()},
      );
      final t02 = FakeClassroomT02();
      final runtime = _runtime(service, t02);

      final snap = await runtime.open(lessonLocalId: 'cyber-class');

      expect(snap.hasCurriculum, isTrue);
      expect(snap.phase.type, ClassroomPhaseType.lendo);
      expect(snap.conteudo?.question, 'Pergunta M1?');
      expect(t02.calls, greaterThanOrEqualTo(1));
    },
  );

  test(
    'LessonRuntimeEngine updates counter when T00 expands curriculum without reopening',
    () async {
      final initial = _classroomState().copyWith(
        curriculum: const StudentCurriculum(
          topic: 'Aprender regra de tres',
          totalItems: 1,
          generatedAt: null,
          provisional: true,
          items: [CurriculumItem(marker: 'M1', text: 'Item 1')],
        ),
        progress: const LessonProgress(
          itemIdx: 0,
          layer: LessonLayer.l1,
          erros: 0,
          amparoLvl: 0,
          historia: [],
          mainAdvances: 0,
          concluidos: [],
          pendentesMarkers: [],
          totalItems: 1,
          pctAvanco: 0,
        ),
      );
      final service = StudentLearningStateService(
        seed: {'cyber-class': initial},
      );
      final t02 = FakeClassroomT02();
      final runtime = _runtime(service, t02);

      final first = await runtime.open(lessonLocalId: 'cyber-class');
      expect(first.viewModel?.headerLabel, 'aula_item_of:1/1:aula_layer_1');

      service.mutate('cyber-class', (state) {
        return state.copyWith(
          curriculum: const StudentCurriculum(
            topic: 'Aprender regra de tres',
            totalItems: 3,
            generatedAt: null,
            provisional: false,
            items: [
              CurriculumItem(marker: 'M1', text: 'Item 1'),
              CurriculumItem(marker: 'M2', text: 'Item 2'),
              CurriculumItem(marker: 'M3', text: 'Item 3'),
            ],
          ),
        );
      });

      final expanded = runtime.snapshot();
      expect(expanded.viewModel?.headerLabel, 'aula_item_of:1/3:aula_layer_1');
      expect(expanded.itemMarker, 'M1');
    },
  );

  test('Classroom applies server decision from L1 to L3', () async {
    final service = StudentLearningStateService(
      seed: {'cyber-class': _classroomState()},
    );
    final t02 = FakeClassroomT02();
    final gate = FakeServerAdvanceGateClient(
      const ServerAdvanceGateDecision(
        accepted: true,
        decision: 'next_layer',
        reason: 'server_skip_to_l3',
        nextItemIdx: 0,
        nextLayer: LessonLayer.l3,
        highWaterMark: 2,
        events: [
          {'type': 'ADVANCE_GATE_DECIDED', 'decision': 'next_layer'},
        ],
      ),
    );
    final runtime = _runtime(service, t02, serverAdvanceGateClient: gate);
    await runtime.open(lessonLocalId: 'cyber-class');

    runtime.select(AnswerLetter.A);
    await runtime.signal(DecisionSignal.one);
    var snap = runtime.snapshot();

    expect(snap.phase.type, ClassroomPhaseType.concluido);
    expect(snap.history, hasLength(1));
    expect(service.read('cyber-class')?.progress?.layer, LessonLayer.l3);
    expect(gate.requests, hasLength(1));
    expect(gate.requests.single.questionText, isNotEmpty);
    expect(gate.requests.single.correctOption, AnswerLetter.A);
    expect(gate.requests.single.toJson()['evidence'], isA<Map>());

    await runtime.advance();
    snap = runtime.snapshot();

    expect(snap.phase.type, ClassroomPhaseType.lendo);
    expect(snap.itemMarker, 'M1');
    expect(service.read('cyber-class')?.current?.layer, LessonLayer.l3);
  });

  test(
    'Classroom follows official route after answer, signal and advance',
    () async {
      final service = StudentLearningStateService(
        seed: {'cyber-class': _classroomState()},
      );
      final t02 = FakeClassroomT02();
      final gate = OfficialRouteAdvanceGateClient();
      final runtime = _runtime(service, t02, serverAdvanceGateClient: gate);
      await runtime.open(lessonLocalId: 'cyber-class');

      runtime.select(AnswerLetter.B);
      await runtime.signal(DecisionSignal.two);
      expect(runtime.snapshot().phase.type, ClassroomPhaseType.concluido);
      expect(service.read('cyber-class')?.progress?.layer, LessonLayer.l2);
      await runtime.advance();
      expect(runtime.snapshot().phase.type, ClassroomPhaseType.lendo);
      expect(runtime.snapshot().itemMarker, 'M1');
      expect(service.read('cyber-class')?.current?.layer, LessonLayer.l2);

      runtime.select(AnswerLetter.C);
      await runtime.signal(DecisionSignal.three);
      expect(service.read('cyber-class')?.progress?.layer, LessonLayer.l3);
      await runtime.advance();
      expect(runtime.snapshot().phase.type, ClassroomPhaseType.lendo);
      expect(runtime.snapshot().itemMarker, 'M1');
      expect(service.read('cyber-class')?.current?.layer, LessonLayer.l3);

      runtime.select(AnswerLetter.B);
      await runtime.signal(DecisionSignal.one);
      expect(service.read('cyber-class')?.progress?.itemIdx, 1);
      expect(service.read('cyber-class')?.progress?.layer, LessonLayer.l1);
      await runtime.advance();
      expect(runtime.snapshot().phase.type, ClassroomPhaseType.lendo);
      expect(runtime.snapshot().itemMarker, 'M2');
      expect(service.read('cyber-class')?.current?.layer, LessonLayer.l1);

      expect(gate.requests.map((request) => request.layer), [
        LessonLayer.l1,
        LessonLayer.l2,
        LessonLayer.l3,
      ]);
    },
  );

  test(
    'CG-1 runtime atravessa Parte 1 para item global 81 servidor-first',
    () async {
      final service = StudentLearningStateService(
        seed: {'lesson-cg-root': _largeCurriculumBoundaryState()},
      );
      final t02 = FakeClassroomT02();
      final gate = FakeServerAdvanceGateClient(
        const ServerAdvanceGateDecision(
          accepted: true,
          decision: 'next_item',
          reason: 'l3_to_next_item',
          nextItemIdx: 80,
          nextLayer: LessonLayer.l1,
          nextGlobalItemNumber: 81,
          nextLocalItemIdx: 0,
          nextPartNumber: 2,
          authoritativeRootLessonLocalId: 'lesson-cg-root',
          authoritativePartLessonLocalId: 'lesson-cg-root::part-2',
          authoritativeLayer: LessonLayer.l1,
          partStatus: 'ready',
          nextPartStatus: 'ready',
          liveWindow: {
            'version': 1,
            'policy': 'current_plus_next_three',
            'slots': [
              {
                'itemIdx': 80,
                'layer': 1,
                'rootLessonLocalId': 'lesson-cg-root',
                'partLessonLocalId': 'lesson-cg-root::part-2',
                'partNumber': 2,
                'globalItemNumber': 81,
                'localItemIdx': 0,
                'item': {
                  'itemIdx': 80,
                  'localItemIdx': 0,
                  'globalItemNumber': 81,
                  'partNumber': 2,
                  'rootLessonLocalId': 'lesson-cg-root',
                  'partLessonLocalId': 'lesson-cg-root::part-2',
                  'marker': 'M81',
                  'title': 'Item 81',
                  'text': 'Item 81',
                },
              },
            ],
          },
          highWaterMark: 80,
          events: [
            {'type': 'ADVANCE_GATE_DECIDED', 'decision': 'next_item'},
          ],
        ),
      );
      final runtime = _runtime(service, t02, serverAdvanceGateClient: gate);
      await runtime.open(lessonLocalId: 'lesson-cg-root');

      expect(runtime.snapshot().itemMarker, 'M80');
      runtime.select(AnswerLetter.A);
      await runtime.signal(DecisionSignal.one);
      expect(runtime.snapshot().phase.type, ClassroomPhaseType.concluido);
      expect(service.read('lesson-cg-root')?.curriculum?.items, hasLength(81));
      expect(service.read('lesson-cg-root')?.current?.marker, 'M81');

      await runtime.advance();
      final snapshot = runtime.snapshot();
      final state = service.read('lesson-cg-root')!;

      expect(snapshot.phase.type, ClassroomPhaseType.lendo);
      expect(snapshot.itemMarker, 'M81');
      expect(snapshot.isDone, isFalse);
      expect(
        snapshot.viewModel?.headerLabel,
        'aula_item_of:81/180:aula_layer_1',
      );
      expect(state.lessonLocalId, 'lesson-cg-root');
      expect(state.progress?.itemIdx, 80);
      expect(state.progress?.layer, LessonLayer.l1);
      expect(state.progress?.historia, contains('M1:L1:A:1'));
      expect(
        state.curriculum?.items[80].extra['partLessonLocalId'],
        'lesson-cg-root::part-2',
      );
      expect(gate.requests.single.lessonLocalId, 'lesson-cg-root');
    },
  );

  test(
    'answer signal without server does not write false mastery truth',
    () async {
      final store = StudentStateStore(local: MemoryStudentStateLocalStorage());
      store.writeState(
        _classroomState().copyWith(
          attempts: const [
            LessonAttempt(
              marker: 'M1',
              layer: LessonLayer.l1,
              letra: AnswerLetter.B,
              sinal: DecisionSignal.one,
              correct: false,
              ts: 1,
            ),
          ],
        ),
      );
      final service = StudentStateStoreAdapter(store);
      final t02 = FakeClassroomT02();
      final runtime = _runtime(service, t02, store: store);
      await runtime.open(lessonLocalId: 'cyber-class');

      runtime.select(AnswerLetter.B);
      await runtime.signal(DecisionSignal.one);

      final state = store.readState('cyber-class');
      expect(state.extra['truth'], isNull);
      expect(state.truth.masteryEvidence, isEmpty);
      expect(
        state.queuedActions.map((action) => action['type']),
        contains('ADVANCE_GATE_PENDING'),
      );
      final eventTypes = store
          .getEventLog('cyber-class')
          .map((event) => event.type);
      expect(eventTypes, isNot(contains('MASTERY_EVALUATED')));
      expect(eventTypes, isNot(contains('WEAKNESS_REGISTERED')));
      expect(eventTypes, isNot(contains('REINFORCEMENT_REQUIRED')));
    },
  );

  test(
    'answer signal without server does not write mastery or advance events',
    () async {
      final store = StudentStateStore(local: MemoryStudentStateLocalStorage());
      store.writeState(
        _classroomState().copyWith(
          attempts: const [
            LessonAttempt(
              marker: 'M1',
              layer: LessonLayer.l1,
              letra: AnswerLetter.A,
              sinal: DecisionSignal.one,
              correct: true,
              ts: 1,
            ),
            LessonAttempt(
              marker: 'M1',
              layer: LessonLayer.l1,
              letra: AnswerLetter.A,
              sinal: DecisionSignal.one,
              correct: true,
              ts: 2,
            ),
          ],
        ),
      );
      final service = StudentStateStoreAdapter(store);
      final t02 = FakeClassroomT02();
      final runtime = _runtime(service, t02, store: store);
      await runtime.open(lessonLocalId: 'cyber-class');

      runtime.select(AnswerLetter.A);
      await runtime.signal(DecisionSignal.one);

      final state = store.readState('cyber-class');
      expect(state.extra['truth'], isNull);
      expect(state.truth.masteryEvidence, isEmpty);
      expect(
        state.queuedActions.map((action) => action['type']),
        contains('ADVANCE_GATE_PENDING'),
      );
      final eventTypes = store
          .getEventLog('cyber-class')
          .map((event) => event.type);
      expect(eventTypes, isNot(contains('NEXT_ACTION_DECIDED')));
      expect(eventTypes, isNot(contains('ITEM_MASTERED')));
      expect(eventTypes, isNot(contains('ITEM_ADVANCED')));
    },
  );

  test(
    'remote advance gate failure keeps explicit retry pending state',
    () async {
      final service = StudentLearningStateService(
        seed: {'cyber-class': _classroomState()},
      );
      final t02 = FakeClassroomT02();
      final gate = FailingServerAdvanceGateClient();
      final runtime = _runtime(service, t02, serverAdvanceGateClient: gate);
      await runtime.open(lessonLocalId: 'cyber-class');

      runtime.select(AnswerLetter.A);
      await runtime.signal(DecisionSignal.one);
      await Future<void>.delayed(Duration.zero);

      final snapshot = runtime.snapshot();
      expect(snapshot.phase.type, ClassroomPhaseType.concluido);
      expect(snapshot.phase.signal, DecisionSignal.one);
      expect(service.read('cyber-class')?.progress?.layer, LessonLayer.l1);
      expect(
        service
            .read('cyber-class')
            ?.queuedActions
            .map((action) => action['type']),
        contains('ADVANCE_GATE_PENDING'),
      );
    },
  );

  test(
    'remote advance gate retry reuses idempotency key and applies decision',
    () async {
      final service = StudentLearningStateService(
        seed: {'cyber-class': _classroomState()},
      );
      final t02 = FakeClassroomT02();
      final gate = FlakyServerAdvanceGateClient();
      final runtime = _runtime(service, t02, serverAdvanceGateClient: gate);
      await runtime.open(lessonLocalId: 'cyber-class');

      runtime.select(AnswerLetter.A);
      await runtime.signal(DecisionSignal.one);
      await Future<void>.delayed(Duration.zero);
      expect(runtime.snapshot().phase.type, ClassroomPhaseType.concluido);

      runtime.select(AnswerLetter.A);
      await runtime.signal(DecisionSignal.one);
      await Future<void>.delayed(Duration.zero);

      expect(gate.requests, hasLength(2));
      expect(
        gate.requests.first.idempotencyKey,
        gate.requests.last.idempotencyKey,
      );
      expect(runtime.snapshot().phase.type, ClassroomPhaseType.concluido);
      expect(service.read('cyber-class')?.progress?.layer, LessonLayer.l3);
      expect(
        service
            .read('cyber-class')
            ?.queuedActions
            .where((action) => action['type'] == 'ADVANCE_GATE_PENDING'),
        isEmpty,
      );
    },
  );

  test('LessonMainViewModel locks after completion and labels next layer', () {
    final vm = buildLessonMainViewModel(
      baseItems: const [PlannedItem(marker: 'M1', text: 'Item 1')],
      mainAdvances: 0,
      isReviewAtivo: false,
      itemAtivo: const PlannedItem(marker: 'M1', text: 'Item 1'),
      itemIdx: 0,
      layer: LessonLayer.l1,
      phase: const ClassroomPhase.completed(
        message: 'ok',
        wasCorrect: true,
        signal: DecisionSignal.one,
      ),
      conteudo: null,
      items: const [PlannedItem(marker: 'M1', text: 'Item 1')],
    );

    expect(vm.locked, isTrue);
    expect(vm.nextLabel, 'aula_layer_label_3');
  });
}
