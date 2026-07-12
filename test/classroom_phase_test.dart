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
