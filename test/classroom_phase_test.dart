import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
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
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/lesson/student_lesson_material_service.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/live_entry_state.dart';
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

class FailingClassroomT02 implements T02LessonClient {
  int calls = 0;

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) {
    calls += 1;
    throw StateError('offline');
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

class PendingServerAdvanceGateClient implements ServerAdvanceGateClient {
  final requests = <ServerAdvanceGateRequest>[];
  final completer = Completer<ServerAdvanceGateDecision>();

  @override
  Future<ServerAdvanceGateDecision> decide(ServerAdvanceGateRequest request) {
    requests.add(request);
    return completer.future;
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
  T02LessonClient t02, {
  StudentStateStore? store,
  ServerAdvanceGateClient? serverAdvanceGateClient,
  LessonMaterialCache? cache,
}) {
  final orchestrator = LessonOrchestrator(
    t02Client: t02,
    cache: cache ?? LessonMaterialCache(),
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
    ),
  );
}

void _putPreparedMaterial(
  StudentLearningStateService service,
  String lessonLocalId, {
  required int itemIdx,
  required String marker,
  required LessonLayer layer,
  String? question,
}) {
  service.mutate(lessonLocalId, (state) {
    final material = preparedMaterialFromLesson(
      lesson: CompleteLesson(
        conteudo: LessonContent(
          explanation: 'Texto preparado $marker L${layer.value}.',
          question: question ?? 'Pergunta preparada $marker L${layer.value}?',
          options: const {
            AnswerLetter.A: 'A',
            AnswerLetter.B: 'B',
            AnswerLetter.C: 'C',
          },
          correctAnswer: AnswerLetter.A,
        ),
        imagem: null,
        audioText: 'Texto preparado $marker L${layer.value}.',
      ),
      itemIdx: itemIdx,
      marker: marker,
      layer: layer,
    );
    return state.copyWith(
      readyLessonMaterials: {
        ...state.readyLessonMaterials,
        preparedLessonMaterialKey(itemIdx, marker, layer): material,
      },
    );
  });
}

StudentStateStore _storeWithState(StudentLearningState state) {
  final store = StudentStateStore(local: MemoryStudentStateLocalStorage());
  store.writeState(state);
  return store;
}

StudentLearningState _classroomStateWithPreparedCurrent(String lessonLocalId) {
  final state = _classroomState().copyWith(lessonLocalId: lessonLocalId);
  JsonMap material(int itemIdx, String marker, LessonLayer layer) =>
      preparedMaterialFromLesson(
        lesson: CompleteLesson(
          conteudo: LessonContent(
            explanation: 'Texto preparado $marker L${layer.value}.',
            question: 'Pergunta preparada $marker L${layer.value}?',
            options: const {
              AnswerLetter.A: 'A',
              AnswerLetter.B: 'B',
              AnswerLetter.C: 'C',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: null,
          audioText: 'Texto preparado $marker L${layer.value}.',
        ),
        itemIdx: itemIdx,
        marker: marker,
        layer: layer,
      );
  return state.copyWith(
    readyLessonMaterials: {
      preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): material(
        0,
        'M1',
        LessonLayer.l1,
      ),
      preparedLessonMaterialKey(0, 'M1', LessonLayer.l3): material(
        0,
        'M1',
        LessonLayer.l3,
      ),
      preparedLessonMaterialKey(1, 'M2', LessonLayer.l1): material(
        1,
        'M2',
        LessonLayer.l1,
      ),
    },
  );
}

StudentLearningState _withAdvancePendingWithoutTarget(
  StudentLearningState state,
) {
  final nextReady = Map<String, JsonMap>.of(state.readyLessonMaterials)
    ..remove(preparedLessonMaterialKey(0, 'M1', LessonLayer.l2));
  return state.copyWith(
    readyLessonMaterials: nextReady,
    extra: {
      ...state.extra,
      'advancePending': {
        'status': 'preparing',
        'reason': 'test_pending_target_material',
        'fromItemIdx': 0,
        'fromLayer': LessonLayer.l1.value,
        'fromMarker': 'M1',
        'toItemIdx': 0,
        'toLayer': LessonLayer.l2.value,
        'toMarker': 'M1',
        'letter': AnswerLetter.A.name,
        'signal': DecisionSignal.two.value,
      },
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    'M-EXP3-B runtime reopens from hydrated cache without T02 when offline',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final seedState = _classroomState();
      final params = const CompleteLessonParams(
        lessonLocalId: 'cyber-class',
        item: 'Item 1',
        lang: 'pt-BR',
        academic: 'intermediario (base solida)',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
        itemIdx: 0,
        curriculumItems: [
          {
            'order': 1,
            'marker': 'M1',
            'title': 'Item 1',
            'text': 'Item 1',
            'purpose': 'Item 1',
            'microitem_for_teacher': 'Item 1',
          },
          {
            'order': 2,
            'marker': 'M2',
            'title': 'Item 2',
            'text': 'Item 2',
            'purpose': 'Item 2',
            'microitem_for_teacher': 'Item 2',
          },
        ],
        topic: 'Aprender regra de tres',
        pedagogicalEnvelope: {
          'marker': 'M1',
          'stable_lang': 'pt-BR',
          'original_text_preserved': 'Aprender regra de tres',
        },
      );
      final firstCache = LessonMaterialCache();
      expect(
        firstCache.putForParams(
          params,
          const CompleteLesson(
            conteudo: LessonContent(
              explanation: 'Texto persistido no boot.',
              question: 'Qual texto abre offline?',
              options: {
                AnswerLetter.A: 'O local',
                AnswerLetter.B: 'Um tecnico',
                AnswerLetter.C: 'Nenhum',
              },
              correctAnswer: AnswerLetter.A,
            ),
            imagem: null,
            audioText: 'Texto persistido no boot. Qual texto abre offline?',
          ),
        ),
        isTrue,
      );
      for (var i = 0; i < 20; i += 1) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await prefs.reload();
        if ((prefs.getString('sim-lesson-text-cache-v1') ?? '').contains(
          'Qual texto abre offline?',
        )) {
          break;
        }
      }
      await prefs.reload();

      final hydratedCache = LessonMaterialCache();
      hydratedCache.hydrateFromPreferences(prefs);
      final service = StudentLearningStateService(
        seed: {'cyber-class': seedState},
      );
      final t02 = FailingClassroomT02();
      final runtime = _runtime(service, t02, cache: hydratedCache);

      final snap = await runtime.open(lessonLocalId: 'cyber-class');

      expect(snap.phase.type, ClassroomPhaseType.lendo);
      expect(snap.conteudo?.question, 'Qual texto abre offline?');
      expect(snap.conteudo?.options.keys, containsAll(AnswerLetter.values));
      expect(t02.calls, 0);
    },
  );

  test(
    'M-EXP3-B runtime discards invalid hydrated cache and tries official route',
    () async {
      SharedPreferences.setMockInitialValues({
        'sim-lesson-text-cache-v1': jsonEncode({
          lessonKeyFor(
            const CompleteLessonParams(
              lessonLocalId: 'cyber-class',
              item: 'Item 1',
              lang: 'pt-BR',
              academic: 'intermediario (base solida)',
              layer: LessonLayer.l1,
              mode: LessonMode.session,
              marker: 'M1',
            ),
          ): {
            'savedAt': DateTime.now().millisecondsSinceEpoch,
            'lesson': {
              'conteudo': {
                'explanation': 'Invalido',
                'question': '',
                'options': {'A': 'A', 'B': '', 'C': 'C'},
                'correct_answer': 'A',
              },
              'audioText': 'Invalido',
            },
          },
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final hydratedCache = LessonMaterialCache();
      hydratedCache.hydrateFromPreferences(prefs);
      final service = StudentLearningStateService(
        seed: {'cyber-class': _classroomState()},
      );
      final t02 = FakeClassroomT02();
      final runtime = _runtime(service, t02, cache: hydratedCache);

      final snap = await runtime.open(lessonLocalId: 'cyber-class');

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

  test('Classroom applies local app-first decision from L1 to L3', () async {
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
    _putPreparedMaterial(
      service,
      'cyber-class',
      itemIdx: 0,
      marker: 'M1',
      layer: LessonLayer.l3,
    );

    runtime.select(AnswerLetter.A);
    await runtime.signal(DecisionSignal.one);
    var snap = runtime.snapshot();

    expect(snap.phase.type, ClassroomPhaseType.concluido);
    expect(snap.history, hasLength(1));
    expect(service.read('cyber-class')?.progress?.layer, LessonLayer.l3);
    expect(gate.requests, isEmpty);
    expect(
      service.read('cyber-class')?.events.map((event) => event.type),
      contains('LOCAL_ADVANCE_DECIDED'),
    );

    await runtime.advance();
    snap = runtime.snapshot();

    expect(snap.phase.type, ClassroomPhaseType.lendo);
    expect(snap.itemMarker, 'M1');
    expect(service.read('cyber-class')?.current?.layer, LessonLayer.l3);
  });

  test('M6.1 erro avanca do cache local sem T02 no toque', () async {
    final service = StudentLearningStateService(
      seed: {'cyber-class': _classroomState()},
    );
    final t02 = FakeClassroomT02();
    final cache = LessonMaterialCache();
    final runtime = _runtime(service, t02, cache: cache);
    await runtime.open(lessonLocalId: 'cyber-class');
    expect(t02.calls, 1);
    _putPreparedMaterial(
      service,
      'cyber-class',
      itemIdx: 0,
      marker: 'M1',
      layer: LessonLayer.l2,
      question: 'Reparo local preparado?',
    );

    runtime.select(AnswerLetter.B);
    await runtime.signal(DecisionSignal.three);
    expect(service.read('cyber-class')?.progress?.layer, LessonLayer.l2);
    await runtime.advance();
    final snap = runtime.snapshot();

    expect(snap.phase.type, ClassroomPhaseType.lendo);
    expect(snap.itemMarker, 'M1');
    expect(snap.conteudo?.question, 'Reparo local preparado?');
    expect(t02.calls, 1);
    expect(service.read('cyber-class')?.current?.layer, LessonLayer.l2);
  });

  test(
    'M6.1 servidor fora e bandeja vazia nao bloqueiam toque de avancar',
    () async {
      final service = StudentLearningStateService(
        seed: {'cyber-class': _classroomState()},
      );
      final t02 = FailingClassroomT02();
      final runtime = _runtime(service, FakeClassroomT02());
      await runtime.open(lessonLocalId: 'cyber-class');

      runtime.select(AnswerLetter.A);
      await runtime.signal(DecisionSignal.two);
      await runtime.advance();
      final snap = runtime.snapshot();

      expect(snap.phase.type, ClassroomPhaseType.avancoPendente);
      expect(snap.itemMarker, 'M1');
      expect(
        (service.read('cyber-class')?.extra['advancePending']
            as Map?)?['status'],
        'preparing',
      );
      expect(t02.calls, 0);
    },
  );

  test('M6.1 avancar nao chama carregar nem forceRefresh no toque', () {
    final source = File(
      'lib/sim/classroom/lesson_answer_progress_controller.dart',
    ).readAsStringSync();
    final start = source.indexOf('  Future<void> avancar({');
    final end = source.indexOf('  LessonMode _modeForNextMaterial', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final body = source.substring(start, end);

    expect(body, isNot(contains('forceRefresh')));
    expect(body, isNot(contains('materialController.carregar(')));
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
      _putPreparedMaterial(
        service,
        'cyber-class',
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l2,
      );
      _putPreparedMaterial(
        service,
        'cyber-class',
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l3,
      );
      _putPreparedMaterial(
        service,
        'cyber-class',
        itemIdx: 1,
        marker: 'M2',
        layer: LessonLayer.l1,
      );

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

      expect(gate.requests, isEmpty);
    },
  );

  test(
    'M-EXP4 avancar para proxima experiencia preparada sem chamar T02',
    () async {
      final service = StudentLearningStateService(
        seed: {'cyber-class': _classroomState()},
      );
      final t02 = FakeClassroomT02();
      final gate = FakeServerAdvanceGateClient(
        const ServerAdvanceGateDecision(
          accepted: true,
          decision: 'next_layer',
          reason: 'server_to_l2',
          nextItemIdx: 0,
          nextLayer: LessonLayer.l2,
          highWaterMark: 2,
          events: [
            {'type': 'ADVANCE_GATE_DECIDED', 'decision': 'next_layer'},
          ],
        ),
      );
      final runtime = _runtime(service, t02, serverAdvanceGateClient: gate);
      await runtime.open(lessonLocalId: 'cyber-class');
      expect(t02.calls, 1);

      service.mutate('cyber-class', (state) {
        final material = preparedMaterialFromLesson(
          lesson: const CompleteLesson(
            conteudo: LessonContent(
              explanation: 'Texto preparado L2.',
              question: 'Pergunta preparada L2?',
              options: {
                AnswerLetter.A: 'A preparada',
                AnswerLetter.B: 'B preparada',
                AnswerLetter.C: 'C preparada',
              },
              correctAnswer: AnswerLetter.A,
            ),
            imagem: null,
            audioText: 'Texto preparado L2. Pergunta preparada L2?',
          ),
          itemIdx: 0,
          marker: 'M1',
          layer: LessonLayer.l2,
        );
        return state.copyWith(
          readyLessonMaterials: {
            ...state.readyLessonMaterials,
            preparedLessonMaterialKey(0, 'M1', LessonLayer.l2): material,
          },
        );
      });

      runtime.select(AnswerLetter.A);
      await runtime.signal(DecisionSignal.two);
      await Future<void>.delayed(Duration.zero);
      await runtime.advance();
      final snap = runtime.snapshot();

      expect(snap.phase.type, ClassroomPhaseType.lendo);
      expect(snap.itemMarker, 'M1');
      expect(snap.conteudo?.question, 'Pergunta preparada L2?');
      expect(t02.calls, 1);
      expect(
        service
            .read('cyber-class')!
            .events
            .where((event) => event.type == 'INSTANT_EXPERIENCE_MEASURED')
            .last
            .payload['source'],
        LessonMaterialSource.studentState.name,
      );
    },
  );

  test(
    'M7.1 cache miss preserva alvo e reavalia quando material fica pronto',
    () async {
      final service = StudentLearningStateService(
        seed: {'cyber-class': _classroomState()},
      );
      final t02 = FakeClassroomT02();
      final runtime = _runtime(service, t02);
      await runtime.open(lessonLocalId: 'cyber-class');

      runtime.select(AnswerLetter.A);
      await runtime.signal(DecisionSignal.two);
      await runtime.advance();

      var snapshot = runtime.snapshot();
      expect(snapshot.phase.type, ClassroomPhaseType.avancoPendente);
      expect(snapshot.itemMarker, 'M1');
      final pending = service.read('cyber-class')?.extra['advancePending'];
      expect(pending, isA<Map>());
      expect((pending as Map)['toItemIdx'], 0);
      expect(pending['toLayer'], LessonLayer.l2.value);
      expect(pending['toMarker'], 'M1');

      service.mutate('cyber-class', (state) {
        final material = preparedMaterialFromLesson(
          lesson: const CompleteLesson(
            conteudo: LessonContent(
              explanation: 'Texto preparado depois do miss.',
              question: 'Material ficou pronto?',
              options: {
                AnswerLetter.A: 'Sim',
                AnswerLetter.B: 'Nao',
                AnswerLetter.C: 'Talvez',
              },
              correctAnswer: AnswerLetter.A,
            ),
            imagem: null,
            audioText: 'Texto preparado depois do miss.',
          ),
          itemIdx: 0,
          marker: 'M1',
          layer: LessonLayer.l2,
        );
        return state.copyWith(
          readyLessonMaterials: {
            ...state.readyLessonMaterials,
            preparedLessonMaterialKey(0, 'M1', LessonLayer.l2): material,
          },
        );
      });

      expect(runtime.reavaliarAvancoPendente(), isTrue);
      snapshot = runtime.snapshot();
      expect(snapshot.phase.type, ClassroomPhaseType.lendo);
      expect(snapshot.itemMarker, 'M1');
      expect(snapshot.viewModel?.headerLabel, 'aula_item_of:1/2:aula_layer_2');
      expect(snapshot.conteudo?.question, 'Material ficou pronto?');
      expect(service.read('cyber-class')?.current?.layer, LessonLayer.l2);
      expect(service.read('cyber-class')?.extra['advancePending'], isNull);
      expect(t02.calls, 1);
    },
  );

  test(
    'M7.1 worker falho fecha advancePending com erro humano recuperavel',
    () async {
      final service = StudentLearningStateService(
        seed: {'cyber-class': _classroomState()},
      );
      final t02 = FakeClassroomT02();
      final runtime = _runtime(service, t02);
      await runtime.open(lessonLocalId: 'cyber-class');

      runtime.select(AnswerLetter.A);
      await runtime.signal(DecisionSignal.two);
      await runtime.advance();
      expect(runtime.snapshot().phase.type, ClassroomPhaseType.avancoPendente);

      service.mutate('cyber-class', (state) {
        return state.copyWith(
          queuedActions: [
            for (final job in state.queuedActions)
              if (job['type'] == 'PREPARE_READY_WINDOW' &&
                  (job['payload'] as Map?)?['itemIdx'] == 0 &&
                  (job['payload'] as Map?)?['layer'] == LessonLayer.l2.value)
                {
                  ...job,
                  'status': 'failed',
                  'error': 'T02 retornou material invalido',
                }
              else
                job,
          ],
        );
      });

      expect(runtime.reavaliarAvancoPendente(), isTrue);
      final snapshot = runtime.snapshot();
      expect(snapshot.phase.type, ClassroomPhaseType.erroEngine);
      expect(snapshot.phase.message, 'aula_advance_pending');
      expect(
        (service.read('cyber-class')?.extra['advancePending']
            as Map?)?['status'],
        'failed',
      );
    },
  );

  test('M7.1 multiplos toques em advancePending nao duplicam avanco', () async {
    final service = StudentLearningStateService(
      seed: {'cyber-class': _classroomState()},
    );
    final t02 = FakeClassroomT02();
    final cache = LessonMaterialCache();
    final runtime = _runtime(service, t02, cache: cache);
    await runtime.open(lessonLocalId: 'cyber-class');

    runtime.select(AnswerLetter.A);
    await runtime.signal(DecisionSignal.two);
    await runtime.advance();
    await runtime.advance();
    await runtime.advance();
    expect(runtime.snapshot().phase.type, ClassroomPhaseType.avancoPendente);

    service.mutate('cyber-class', (state) {
      final material = preparedMaterialFromLesson(
        lesson: const CompleteLesson(
          conteudo: LessonContent(
            explanation: 'Texto unico.',
            question: 'Avancou uma vez?',
            options: {
              AnswerLetter.A: 'Sim',
              AnswerLetter.B: 'Nao',
              AnswerLetter.C: 'Duplicou',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: null,
          audioText: 'Texto unico.',
        ),
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l2,
      );
      return state.copyWith(
        readyLessonMaterials: {
          ...state.readyLessonMaterials,
          preparedLessonMaterialKey(0, 'M1', LessonLayer.l2): material,
        },
      );
    });

    expect(runtime.reavaliarAvancoPendente(), isTrue);
    expect(runtime.reavaliarAvancoPendente(), isFalse);
    final state = service.read('cyber-class')!;
    expect(state.current?.itemIdx, 0);
    expect(state.current?.layer, LessonLayer.l2);
    expect(
      state.events.where(
        (event) => event.type == 'LOCAL_PENDING_ADVANCE_DISPLAYED',
      ),
      hasLength(1),
    );
  });

  test(
    'M7.1 LabSession reavalia via subscription quando material fica pronto',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _storeWithState(
        _classroomStateWithPreparedCurrent('lesson-session-pending'),
      );
      final session = LabSession(canonicalStore: store, prefs: prefs)
        ..authed = true
        ..authReady = true
        ..lessonLocalId = 'lesson-session-pending'
        ..route = '/cyber/aula';
      var notifyCount = 0;
      session.addListener(() => notifyCount += 1);

      await session.openAulaRuntime();
      expect(session.aulaSnapshot, isNotNull);
      expect(session.aulaSnapshot?.phase.type, ClassroomPhaseType.lendo);
      expect(
        session.aulaSnapshot?.conteudo?.question,
        'Pergunta preparada M1 L1?',
      );
      final organism = session.simOrganismProvider.forLesson(
        'lesson-session-pending',
      );

      organism.stateService.mutate(
        'lesson-session-pending',
        _withAdvancePendingWithoutTarget,
        scheduleShadow: false,
      );
      organism.lessonRuntimeEngine.restoreTransientSnapshot(
        session.aulaSnapshot!.copyWith(
          phase: const ClassroomPhase.advancePending(
            message: 'aula_advance_preparing',
            letter: AnswerLetter.A,
            signal: DecisionSignal.two,
          ),
        ),
      );
      session.aulaSnapshot = organism.lessonRuntimeEngine.snapshot();

      expect(
        session.aulaSnapshot?.phase.type,
        ClassroomPhaseType.avancoPendente,
      );
      expect(session.aulaSnapshot?.itemMarker, 'M1');
      final pending = store
          .readState('lesson-session-pending')
          .extra['advancePending'];
      expect(pending, isA<Map>());
      final beforeReadyNotifyCount = notifyCount;

      _putPreparedMaterial(
        organism.stateService,
        'lesson-session-pending',
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l2,
        question: 'Pergunta entregue pela subscription?',
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(notifyCount, greaterThan(beforeReadyNotifyCount));
      expect(session.aulaSnapshot?.phase.type, ClassroomPhaseType.lendo);
      expect(
        session.aulaSnapshot?.conteudo?.question,
        'Pergunta entregue pela subscription?',
      );
      expect(
        session.aulaSnapshot?.viewModel?.headerLabel,
        'aula_item_of:1/2:aula_layer_2',
      );
      expect(
        store.readState('lesson-session-pending').extra['advancePending'],
        isNull,
      );
    },
  );

  test(
    'M7.1 troca de aula ignora resultado atrasado da aula anterior',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = StudentStateStore(local: MemoryStudentStateLocalStorage())
        ..writeState(_classroomStateWithPreparedCurrent('lesson-session-a'))
        ..writeState(
          _classroomStateWithPreparedCurrent('lesson-session-b').copyWith(
            profile: const StudentProfile(
              objetivo: 'Aula B',
              stableLang: 'pt-BR',
              nivel: 'base',
            ),
          ),
        );
      final session = LabSession(canonicalStore: store, prefs: prefs)
        ..authed = true
        ..authReady = true
        ..lessonLocalId = 'lesson-session-a'
        ..route = '/cyber/aula';
      var notifyCount = 0;
      session.addListener(() => notifyCount += 1);

      await session.openAulaRuntime();
      final organismA = session.simOrganismProvider.forLesson(
        'lesson-session-a',
      );
      organismA.stateService.mutate(
        'lesson-session-a',
        _withAdvancePendingWithoutTarget,
        scheduleShadow: false,
      );
      organismA.lessonRuntimeEngine.restoreTransientSnapshot(
        session.aulaSnapshot!.copyWith(
          phase: const ClassroomPhase.advancePending(
            message: 'aula_advance_preparing',
            letter: AnswerLetter.A,
            signal: DecisionSignal.two,
          ),
        ),
      );
      session.aulaSnapshot = organismA.lessonRuntimeEngine.snapshot();
      expect(
        session.aulaSnapshot?.phase.type,
        ClassroomPhaseType.avancoPendente,
      );

      session.lessonLocalId = 'lesson-session-b';
      await session.openAulaRuntime();
      expect(session.aulaSnapshot, isNotNull);
      expect(session.aulaSnapshot?.phase.type, ClassroomPhaseType.lendo);
      final snapshotBQuestion = session.aulaSnapshot?.conteudo?.question;
      final notifyBeforeLateA = notifyCount;

      _putPreparedMaterial(
        organismA.stateService,
        'lesson-session-a',
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l2,
        question: 'Resultado atrasado da aula A',
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(session.lessonLocalId, 'lesson-session-b');
      expect(session.aulaSnapshot, isNotNull);
      expect(session.aulaSnapshot?.phase.type, ClassroomPhaseType.lendo);
      expect(session.aulaSnapshot?.conteudo?.question, snapshotBQuestion);
      expect(
        session.aulaSnapshot?.conteudo?.question,
        isNot('Resultado atrasado da aula A'),
      );
      expect(notifyCount, notifyBeforeLateA);

      session.lessonLocalId = 'lesson-session-a';
      await session.openAulaRuntime();
      expect(session.aulaSnapshot, isNotNull);
      expect(session.aulaSnapshot?.itemMarker, 'M1');
    },
  );

  test('M7 avanca cinco posicoes usando cache local sem novo T02', () async {
    final service = StudentLearningStateService(
      seed: {'cyber-class': _classroomState()},
    );
    final t02 = FakeClassroomT02();
    final cache = LessonMaterialCache();
    final runtime = _runtime(service, t02, cache: cache);
    await runtime.open(lessonLocalId: 'cyber-class');
    expect(t02.calls, 1);

    CompleteLesson material(String marker, LessonLayer layer) => CompleteLesson(
      conteudo: LessonContent(
        explanation: 'Texto preparado $marker L${layer.value}.',
        question: 'Pergunta preparada $marker L${layer.value}?',
        options: const {
          AnswerLetter.A: 'A',
          AnswerLetter.B: 'B',
          AnswerLetter.C: 'C',
        },
        correctAnswer: AnswerLetter.A,
      ),
      imagem: null,
      audioText: 'Texto preparado $marker L${layer.value}.',
    );

    for (final entry in const [
      (idx: 0, marker: 'M1', item: 'Item 1', layer: LessonLayer.l2),
      (idx: 0, marker: 'M1', item: 'Item 1', layer: LessonLayer.l3),
      (idx: 1, marker: 'M2', item: 'Item 2', layer: LessonLayer.l1),
      (idx: 1, marker: 'M2', item: 'Item 2', layer: LessonLayer.l2),
      (idx: 1, marker: 'M2', item: 'Item 2', layer: LessonLayer.l3),
    ]) {
      final params = CompleteLessonParams(
        lessonLocalId: 'cyber-class',
        item: entry.item,
        lang: 'pt-BR',
        academic: nivelToAcademic('base'),
        layer: entry.layer,
        mode: LessonMode.session,
        marker: entry.marker,
        topic: 'Aprender regra de tres',
        itemIdx: entry.idx,
        curriculumItems: const [
          {'marker': 'M1', 'text': 'Item 1'},
          {'marker': 'M2', 'text': 'Item 2'},
        ],
        pedagogicalEnvelope: const {},
      );
      cache.put(lessonKeyFor(params), material(entry.marker, entry.layer));
    }

    for (var step = 0; step < 5; step++) {
      runtime.select(AnswerLetter.A);
      await runtime.signal(DecisionSignal.two);
      await runtime.advance();
      expect(runtime.snapshot().phase.type, ClassroomPhaseType.lendo);
      expect(t02.calls, 1, reason: 'step $step');
    }

    final snapshot = runtime.snapshot();
    expect(snapshot.itemMarker, 'M2');
    expect(service.read('cyber-class')?.current?.layer, LessonLayer.l3);
    expect(snapshot.conteudo?.question, 'Pergunta preparada M2 L3?');
    expect(
      service
          .read('cyber-class')!
          .events
          .where((event) => event.type == 'INSTANT_EXPERIENCE_MEASURED'),
      hasLength(greaterThanOrEqualTo(5)),
    );
  });

  test(
    'M-EXP4 avanço com servidor pendente usa experiência preparada sem T02',
    () async {
      final service = StudentLearningStateService(
        seed: {'cyber-class': _classroomState()},
      );
      final t02 = FakeClassroomT02();
      final gate = PendingServerAdvanceGateClient();
      final runtime = _runtime(service, t02, serverAdvanceGateClient: gate);
      await runtime.open(lessonLocalId: 'cyber-class');
      expect(t02.calls, 1);

      service.mutate('cyber-class', (state) {
        final prepared = preparedMaterialFromLesson(
          lesson: const CompleteLesson(
            conteudo: LessonContent(
              explanation: 'Texto local enquanto servidor confirma.',
              question: 'Servidor pendente bloqueou?',
              options: {
                AnswerLetter.A: 'Nao',
                AnswerLetter.B: 'Sim',
                AnswerLetter.C: 'Chamou T02',
              },
              correctAnswer: AnswerLetter.A,
            ),
            imagem: null,
            audioText:
                'Texto local enquanto servidor confirma. Servidor pendente bloqueou?',
          ),
          itemIdx: 0,
          marker: 'M1',
          layer: LessonLayer.l2,
        );
        return state.copyWith(
          readyLessonMaterials: {
            ...state.readyLessonMaterials,
            preparedLessonMaterialKey(0, 'M1', LessonLayer.l2): prepared,
          },
        );
      });

      runtime.select(AnswerLetter.A);
      await runtime.signal(DecisionSignal.two);
      expect(gate.requests, isEmpty);
      final afterSignal = service.read('cyber-class')!;
      expect(afterSignal.current?.layer, LessonLayer.l2);
      expect(afterSignal.attempts, hasLength(1));
      expect(afterSignal.attempts.single.marker, 'M1');
      expect(afterSignal.attempts.single.layer, LessonLayer.l1);
      expect(afterSignal.attempts.single.letra, AnswerLetter.A);
      expect(afterSignal.attempts.single.sinal, DecisionSignal.two);
      expect(afterSignal.attempts.single.correct, isTrue);

      await runtime.advance();
      final snap = runtime.snapshot();
      final state = service.read('cyber-class')!;
      final metric = state.events.lastWhere(
        (event) => event.type == 'INSTANT_EXPERIENCE_MEASURED',
      );
      final window = state.events.lastWhere(
        (event) => event.type == 'CACHE_WINDOW_UPDATED',
      );

      expect(snap.phase.type, ClassroomPhaseType.lendo);
      expect(snap.itemMarker, 'M1');
      expect(snap.conteudo?.question, 'Servidor pendente bloqueou?');
      expect(t02.calls, 1);
      expect(metric.payload['textReadyMs'], 0);
      expect(metric.payload['source'], LessonMaterialSource.studentState.name);
      expect(window.payload['currentLayer'], LessonLayer.l2.value);
      expect(window.payload['windowSize'], 4);
      expect(state.current?.layer, LessonLayer.l2);
      expect(state.progress?.layer, LessonLayer.l2);
      expect(
        state.queuedActions.map((action) => action['type']),
        isNot(contains('ADVANCE_GATE_PENDING')),
      );
      expect(
        state.events.map((event) => event.type),
        contains('LOCAL_ADVANCE_DECIDED'),
      );
      expect(state.progress?.concluidos, isNot(contains('M1')));
      expect(
        state.events.map((event) => event.type),
        isNot(contains('ITEM_MASTERED')),
      );
    },
  );

  test('M-EXP4 servidor pendente reabre no avanço local exibido', () async {
    final service = StudentLearningStateService(
      seed: {'cyber-class': _classroomState()},
    );
    final t02 = FakeClassroomT02();
    final gate = PendingServerAdvanceGateClient();
    final runtime = _runtime(service, t02, serverAdvanceGateClient: gate);
    await runtime.open(lessonLocalId: 'cyber-class');
    expect(t02.calls, 1);

    service.mutate('cyber-class', (state) {
      final prepared = preparedMaterialFromLesson(
        lesson: const CompleteLesson(
          conteudo: LessonContent(
            explanation: 'Texto local retomavel enquanto servidor confirma.',
            question: 'Reabriu no avanco local?',
            options: {
              AnswerLetter.A: 'Sim',
              AnswerLetter.B: 'Nao',
              AnswerLetter.C: 'Chamou T02',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: null,
          audioText:
              'Texto local retomavel enquanto servidor confirma. Reabriu no avanco local?',
        ),
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l2,
      );
      return state.copyWith(
        readyLessonMaterials: {
          ...state.readyLessonMaterials,
          preparedLessonMaterialKey(0, 'M1', LessonLayer.l2): prepared,
        },
      );
    });

    runtime.select(AnswerLetter.A);
    await runtime.signal(DecisionSignal.two);
    expect(gate.requests, isEmpty);
    expect(service.read('cyber-class')?.attempts, hasLength(1));
    await runtime.advance();

    final advanced = runtime.snapshot();
    expect(advanced.phase.type, ClassroomPhaseType.lendo);
    expect(advanced.conteudo?.question, 'Reabriu no avanco local?');

    final saved = service.read('cyber-class')!;
    expect(saved.current?.layer, LessonLayer.l2);
    expect(saved.progress?.layer, LessonLayer.l2);
    expect(
      saved.queuedActions.map((action) => action['type']),
      isNot(contains('ADVANCE_GATE_PENDING')),
    );

    final reopened = _runtime(service, t02, serverAdvanceGateClient: gate);
    final reopenedSnap = await reopened.open(lessonLocalId: 'cyber-class');

    expect(reopenedSnap.phase.type, ClassroomPhaseType.lendo);
    expect(reopenedSnap.itemMarker, 'M1');
    expect(reopenedSnap.conteudo?.question, 'Reabriu no avanco local?');
    expect(t02.calls, 1);
    expect(
      service
          .read('cyber-class')!
          .queuedActions
          .map((action) => action['type']),
      isNot(contains('ADVANCE_GATE_PENDING')),
    );
  });

  test(
    'M-EXP4 fechar e reabrir aula volta ao ultimo item camada material',
    () async {
      final resumed = _classroomState().copyWith(
        current: const LessonCurrent(
          itemIdx: 1,
          marker: 'M2',
          layer: LessonLayer.l1,
          amparoLvl: 0,
        ),
        progress: const LessonProgress(
          itemIdx: 1,
          layer: LessonLayer.l1,
          erros: 0,
          amparoLvl: 0,
          historia: ['M1:L3:A:1'],
          mainAdvances: 1,
          concluidos: ['M1'],
          pendentesMarkers: [],
          totalItems: 2,
          pctAvanco: 50,
        ),
        readyLessonMaterials: {
          preparedLessonMaterialKey(
            1,
            'M2',
            LessonLayer.l1,
          ): preparedMaterialFromLesson(
            lesson: const CompleteLesson(
              conteudo: LessonContent(
                explanation: 'Texto retomado M2.',
                question: 'Retomou no M2?',
                options: {
                  AnswerLetter.A: 'Sim',
                  AnswerLetter.B: 'Nao',
                  AnswerLetter.C: 'Inicio',
                },
                correctAnswer: AnswerLetter.A,
              ),
              imagem: null,
              audioText: 'Texto retomado M2. Retomou no M2?',
            ),
            itemIdx: 1,
            marker: 'M2',
            layer: LessonLayer.l1,
          ),
        },
      );
      final service = StudentLearningStateService(
        seed: {'cyber-class': resumed},
      );
      final t02 = FailingClassroomT02();
      final runtime = _runtime(service, t02);

      final snap = await runtime.open(lessonLocalId: 'cyber-class');

      expect(snap.phase.type, ClassroomPhaseType.lendo);
      expect(snap.itemMarker, 'M2');
      expect(snap.conteudo?.question, 'Retomou no M2?');
      expect(t02.calls, 0);
    },
  );

  test('M-EXP4 offline abre experiencia preparada', () async {
    final prepared = _classroomState().copyWith(
      readyLessonMaterials: {
        preparedLessonMaterialKey(
          0,
          'M1',
          LessonLayer.l1,
        ): preparedMaterialFromLesson(
          lesson: const CompleteLesson(
            conteudo: LessonContent(
              explanation: 'Texto offline instantaneo.',
              question: 'Abriu offline?',
              options: {
                AnswerLetter.A: 'Sim',
                AnswerLetter.B: 'Nao',
                AnswerLetter.C: 'Erro tecnico',
              },
              correctAnswer: AnswerLetter.A,
            ),
            imagem: null,
            audioText: 'Texto offline instantaneo. Abriu offline?',
          ),
          itemIdx: 0,
          marker: 'M1',
          layer: LessonLayer.l1,
        ),
      },
    );
    final service = StudentLearningStateService(
      seed: {'cyber-class': prepared},
    );
    final t02 = FailingClassroomT02();
    final runtime = _runtime(service, t02);

    final snap = await runtime.open(lessonLocalId: 'cyber-class');

    expect(snap.phase.type, ClassroomPhaseType.lendo);
    expect(snap.conteudo?.question, 'Abriu offline?');
    expect(t02.calls, 0);
  });

  test(
    'M-EXP4 servidor offline nao bloqueia avanco preparado nem chama T02',
    () async {
      final service = StudentLearningStateService(
        seed: {'cyber-class': _classroomState()},
      );
      final t02 = FakeClassroomT02();
      final gate = FailingServerAdvanceGateClient();
      final runtime = _runtime(service, t02, serverAdvanceGateClient: gate);
      await runtime.open(lessonLocalId: 'cyber-class');
      expect(t02.calls, 1);

      service.mutate('cyber-class', (state) {
        final prepared = preparedMaterialFromLesson(
          lesson: const CompleteLesson(
            conteudo: LessonContent(
              explanation: 'Texto preparado mesmo sem servidor.',
              question: 'Servidor offline travou?',
              options: {
                AnswerLetter.A: 'Nao',
                AnswerLetter.B: 'Sim',
                AnswerLetter.C: 'Chamou T02',
              },
              correctAnswer: AnswerLetter.A,
            ),
            imagem: null,
            audioText: 'Texto preparado mesmo sem servidor.',
          ),
          itemIdx: 0,
          marker: 'M1',
          layer: LessonLayer.l2,
        );
        return state.copyWith(
          readyLessonMaterials: {
            ...state.readyLessonMaterials,
            preparedLessonMaterialKey(0, 'M1', LessonLayer.l2): prepared,
          },
        );
      });

      runtime.select(AnswerLetter.A);
      await runtime.signal(DecisionSignal.two);
      await Future<void>.delayed(Duration.zero);

      final afterSignal = service.read('cyber-class')!;
      expect(afterSignal.attempts, hasLength(1));
      expect(
        afterSignal.queuedActions.map((action) => action['type']),
        isNot(contains('ADVANCE_GATE_PENDING')),
      );

      await runtime.advance();
      final snap = runtime.snapshot();
      final state = service.read('cyber-class')!;

      expect(snap.phase.type, ClassroomPhaseType.lendo);
      expect(snap.conteudo?.question, 'Servidor offline travou?');
      expect(t02.calls, 1);
      expect(gate.requests, isEmpty);
      expect(state.current?.layer, LessonLayer.l2);
      expect(state.progress?.layer, LessonLayer.l2);
      expect(state.attempts, hasLength(1));
      expect(
        state.queuedActions.map((action) => action['type']),
        isNot(contains('ADVANCE_GATE_PENDING')),
      );
    },
  );

  test('M-EXP4 material de slot errado e recusado', () async {
    final wrongSlot = _classroomState().copyWith(
      current: const LessonCurrent(
        itemIdx: 1,
        marker: 'M2',
        layer: LessonLayer.l1,
        amparoLvl: 0,
      ),
      progress: const LessonProgress(
        itemIdx: 1,
        layer: LessonLayer.l1,
        erros: 0,
        amparoLvl: 0,
        historia: [],
        mainAdvances: 1,
        concluidos: ['M1'],
        pendentesMarkers: [],
        totalItems: 2,
        pctAvanco: 50,
      ),
      readyLessonMaterials: {
        preparedLessonMaterialKey(1, 'M2', LessonLayer.l1): {
          ...preparedMaterialFromLesson(
            lesson: const CompleteLesson(
              conteudo: LessonContent(
                explanation: 'Texto contaminado.',
                question: 'Slot errado?',
                options: {
                  AnswerLetter.A: 'A',
                  AnswerLetter.B: 'B',
                  AnswerLetter.C: 'C',
                },
                correctAnswer: AnswerLetter.A,
              ),
              imagem: null,
              audioText: 'Texto contaminado. Slot errado?',
            ),
            itemIdx: 0,
            marker: 'M1',
            layer: LessonLayer.l1,
          ),
          'for_itemIdx': 0,
          'for_marker': 'M1',
        },
      },
    );
    final service = StudentLearningStateService(
      seed: {'cyber-class': wrongSlot},
    );
    final t02 = FakeClassroomT02();
    final runtime = _runtime(service, t02);

    final snap = await runtime.open(lessonLocalId: 'cyber-class');

    expect(snap.phase.type, ClassroomPhaseType.lendo);
    expect(snap.itemMarker, 'M2');
    expect(snap.conteudo?.question, 'Pergunta M2?');
    expect(t02.calls, 1);
  });

  test('M-EXP4 avanco dispara janela viva atual mais proximas tres', () async {
    final service = StudentLearningStateService(
      seed: {'cyber-class': _classroomState()},
    );
    final t02 = FakeClassroomT02();
    final gate = FakeServerAdvanceGateClient(
      const ServerAdvanceGateDecision(
        accepted: true,
        decision: 'next_layer',
        reason: 'server_to_l2',
        nextItemIdx: 0,
        nextLayer: LessonLayer.l2,
        highWaterMark: 2,
        events: [
          {'type': 'ADVANCE_GATE_DECIDED', 'decision': 'next_layer'},
        ],
      ),
    );
    final runtime = _runtime(service, t02, serverAdvanceGateClient: gate);
    await runtime.open(lessonLocalId: 'cyber-class');

    runtime.select(AnswerLetter.A);
    await runtime.signal(DecisionSignal.two);
    await Future<void>.delayed(Duration.zero);
    await runtime.advance();

    final event = service
        .read('cyber-class')!
        .events
        .lastWhere((event) => event.type == 'CACHE_WINDOW_UPDATED');
    expect(event.payload['currentItemIdx'], 0);
    expect(event.payload['currentLayer'], LessonLayer.l2.value);
    expect(event.payload['windowSize'], 4);
  });

  test('M-EXP5 mede tempo ate primeiro texto em caminho preparado', () async {
    final prepared = _classroomState().copyWith(
      readyLessonMaterials: {
        preparedLessonMaterialKey(
          0,
          'M1',
          LessonLayer.l1,
        ): preparedMaterialFromLesson(
          lesson: const CompleteLesson(
            conteudo: LessonContent(
              explanation: 'Texto medido.',
              question: 'Foi instantaneo?',
              options: {
                AnswerLetter.A: 'Sim',
                AnswerLetter.B: 'Nao',
                AnswerLetter.C: 'Talvez',
              },
              correctAnswer: AnswerLetter.A,
            ),
            imagem: null,
            audioText: 'Texto medido. Foi instantaneo?',
          ),
          itemIdx: 0,
          marker: 'M1',
          layer: LessonLayer.l1,
        ),
      },
    );
    final service = StudentLearningStateService(
      seed: {'cyber-class': prepared},
    );
    final t02 = FailingClassroomT02();
    final runtime = _runtime(service, t02);

    await runtime.open(lessonLocalId: 'cyber-class');

    final metric = service
        .read('cyber-class')!
        .events
        .lastWhere((event) => event.type == 'INSTANT_EXPERIENCE_MEASURED');
    expect(metric.payload['textReadyMs'], 0);
    expect(metric.payload['source'], LessonMaterialSource.studentState.name);
    expect(metric.payload['mediaMeasuredSeparately'], isTrue);
    expect(t02.calls, 0);
  });

  test('M-EXP5 mede tempo entre experiencias preparadas', () async {
    final service = StudentLearningStateService(
      seed: {'cyber-class': _classroomState()},
    );
    service.mutate('cyber-class', (state) {
      return state.copyWith(
        readyLessonMaterials: {
          ...state.readyLessonMaterials,
          preparedLessonMaterialKey(
            0,
            'M1',
            LessonLayer.l1,
          ): preparedMaterialFromLesson(
            lesson: const CompleteLesson(
              conteudo: LessonContent(
                explanation: 'Texto L1 preparado.',
                question: 'L1 pronta?',
                options: {
                  AnswerLetter.A: 'Sim',
                  AnswerLetter.B: 'Nao',
                  AnswerLetter.C: 'Talvez',
                },
                correctAnswer: AnswerLetter.A,
              ),
              imagem: null,
              audioText: 'Texto L1 preparado. L1 pronta?',
            ),
            itemIdx: 0,
            marker: 'M1',
            layer: LessonLayer.l1,
          ),
          preparedLessonMaterialKey(
            0,
            'M1',
            LessonLayer.l2,
          ): preparedMaterialFromLesson(
            lesson: const CompleteLesson(
              conteudo: LessonContent(
                explanation: 'Texto L2 preparado.',
                question: 'L2 pronta?',
                options: {
                  AnswerLetter.A: 'Sim',
                  AnswerLetter.B: 'Nao',
                  AnswerLetter.C: 'Talvez',
                },
                correctAnswer: AnswerLetter.A,
              ),
              imagem: null,
              audioText: 'Texto L2 preparado. L2 pronta?',
            ),
            itemIdx: 0,
            marker: 'M1',
            layer: LessonLayer.l2,
          ),
        },
      );
    });
    final t02 = FailingClassroomT02();
    final gate = FakeServerAdvanceGateClient(
      const ServerAdvanceGateDecision(
        accepted: true,
        decision: 'next_layer',
        reason: 'server_to_l2',
        nextItemIdx: 0,
        nextLayer: LessonLayer.l2,
        highWaterMark: 2,
        events: [
          {'type': 'ADVANCE_GATE_DECIDED', 'decision': 'next_layer'},
        ],
      ),
    );
    final runtime = _runtime(service, t02, serverAdvanceGateClient: gate);

    await runtime.open(lessonLocalId: 'cyber-class');
    runtime.select(AnswerLetter.A);
    await runtime.signal(DecisionSignal.two);
    await Future<void>.delayed(Duration.zero);
    await runtime.advance();

    final metrics = service
        .read('cyber-class')!
        .events
        .where((event) => event.type == 'INSTANT_EXPERIENCE_MEASURED')
        .toList();
    expect(metrics, hasLength(greaterThanOrEqualTo(2)));
    expect(metrics.last.ts - metrics.first.ts, greaterThanOrEqualTo(0));
    expect(metrics.last.payload['textReadyMs'], 0);
    expect(t02.calls, 0);
  });

  test(
    'M-EXP5 confirma que midia e medida separadamente e nao bloqueia texto',
    () async {
      final prepared = _classroomState().copyWith(
        readyLessonMaterials: {
          preparedLessonMaterialKey(
            0,
            'M1',
            LessonLayer.l1,
          ): preparedMaterialFromLesson(
            lesson: const CompleteLesson(
              conteudo: LessonContent(
                explanation: 'Texto antes da midia.',
                question: 'Texto esperou midia?',
                options: {
                  AnswerLetter.A: 'Nao',
                  AnswerLetter.B: 'Sim',
                  AnswerLetter.C: 'Travou',
                },
                correctAnswer: AnswerLetter.A,
              ),
              imagem: null,
              audioText: 'Texto antes da midia. Texto esperou midia?',
            ),
            itemIdx: 0,
            marker: 'M1',
            layer: LessonLayer.l1,
          ),
        },
      );
      final service = StudentLearningStateService(
        seed: {'cyber-class': prepared},
      );
      final t02 = FailingClassroomT02();
      final runtime = _runtime(service, t02);

      final snap = await runtime.open(lessonLocalId: 'cyber-class');

      final metric = service
          .read('cyber-class')!
          .events
          .lastWhere((event) => event.type == 'INSTANT_EXPERIENCE_MEASURED');
      expect(snap.phase.type, ClassroomPhaseType.lendo);
      expect(snap.conteudo?.question, 'Texto esperou midia?');
      expect(snap.imagem, isNull);
      expect(metric.payload['mediaMeasuredSeparately'], isTrue);
      expect(metric.payload['textReadyMs'], 0);
      expect(t02.calls, 0);
    },
  );

  test('M-EXP5 confirma tamanho e contagem de cache quente frio', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cache = LessonMaterialCache(maxLessons: 1, ttlMs: 1);
    const params = CompleteLessonParams(
      lessonLocalId: 'cyber-class',
      item: 'Item 1',
      lang: 'pt-BR',
      academic: 'intermediario (base solida)',
      layer: LessonLayer.l1,
      mode: LessonMode.session,
      marker: 'M1',
      itemIdx: 0,
      curriculumItems: [
        {
          'marker': 'M1',
          'text': 'Item 1',
          'rootLessonLocalId': 'cyber-class',
          'partNumber': 1,
          'globalItemNumber': 1,
          'localItemIndex': 0,
        },
      ],
    );
    cache.putForParams(
      params,
      const CompleteLesson(
        conteudo: LessonContent(
          explanation: 'Texto cache.',
          question: 'Cache medido?',
          options: {
            AnswerLetter.A: 'Sim',
            AnswerLetter.B: 'Nao',
            AnswerLetter.C: 'Talvez',
          },
          correctAnswer: AnswerLetter.A,
        ),
        imagem: 'data:image/png;base64,abc',
        audioText: 'Texto cache. Cache medido?',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    cache.trimWarmCache();

    expect(cache.warmEntryCount, 0);
    expect(cache.coldEntryCount, 1);
    expect(cache.coldEntry(lessonKeyFor(params))?.hadMaterial, isTrue);
    expect(cache.coldEntry(lessonKeyFor(params))?.toJson()['imagem'], isNull);
    expect(prefs.getString('sim-lesson-text-cache-v1'), isNotNull);
  });

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
      service.mutate('lesson-cg-root', (state) {
        final current = state.curriculum!;
        return state.copyWith(
          curriculum: StudentCurriculum(
            topic: current.topic,
            totalItems: 180,
            generatedAt: current.generatedAt,
            provisional: current.provisional,
            globalPlan: current.globalPlan,
            items: [
              ...current.items,
              const CurriculumItem(
                marker: 'M81',
                text: 'Item 81',
                title: 'Item 81',
                extra: {
                  'itemIdx': 80,
                  'localItemIdx': 0,
                  'globalItemNumber': 81,
                  'partNumber': 2,
                  'rootLessonLocalId': 'lesson-cg-root',
                  'partLessonLocalId': 'lesson-cg-root::part-2',
                },
              ),
            ],
          ),
        );
      });

      expect(runtime.snapshot().itemMarker, 'M80');
      runtime.select(AnswerLetter.A);
      await runtime.signal(DecisionSignal.one);
      expect(runtime.snapshot().phase.type, ClassroomPhaseType.concluido);
      expect(service.read('lesson-cg-root')?.curriculum?.items, hasLength(81));
      expect(service.read('lesson-cg-root')?.current?.marker, 'M81');
      _putPreparedMaterial(
        service,
        'lesson-cg-root',
        itemIdx: 80,
        marker: 'M81',
        layer: LessonLayer.l1,
      );

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
      expect(gate.requests, isEmpty);
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
        isNot(contains('ADVANCE_GATE_PENDING')),
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
        isNot(contains('ADVANCE_GATE_PENDING')),
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
    'M-EXP4 tentativa repetida legitima no mesmo marker layer nao e apagada',
    () async {
      final service = StudentLearningStateService(
        seed: {
          'cyber-class': _classroomState().copyWith(
            attempts: const [
              LessonAttempt(
                marker: 'M1',
                layer: LessonLayer.l1,
                letra: AnswerLetter.A,
                sinal: DecisionSignal.one,
                correct: true,
                ts: 1,
              ),
            ],
          ),
        },
      );
      final t02 = FakeClassroomT02();
      final gate = FakeServerAdvanceGateClient(
        const ServerAdvanceGateDecision(
          accepted: true,
          decision: 'next_layer',
          reason: 'accepted_repeated_attempt',
          nextItemIdx: 0,
          nextLayer: LessonLayer.l3,
          highWaterMark: 1,
          events: [
            {'type': 'ADVANCE_GATE_DECIDED', 'decision': 'next_layer'},
          ],
        ),
      );
      final runtime = _runtime(service, t02, serverAdvanceGateClient: gate);
      await runtime.open(lessonLocalId: 'cyber-class');

      runtime.select(AnswerLetter.A);
      await runtime.signal(DecisionSignal.one);

      final afterLocalEvidence = service.read('cyber-class')!;
      expect(afterLocalEvidence.attempts, hasLength(2));
      expect(afterLocalEvidence.attempts.first.ts, 1);
      expect(afterLocalEvidence.attempts.last.ts, isNot(1));
      expect(gate.requests, isEmpty);

      await Future<void>.delayed(Duration.zero);

      final afterRemoteDecision = service.read('cyber-class')!;
      expect(afterRemoteDecision.attempts, hasLength(2));
      expect(
        afterRemoteDecision.queuedActions.where(
          (action) => action['type'] == 'ADVANCE_GATE_PENDING',
        ),
        isEmpty,
      );
      expect(afterRemoteDecision.progress?.layer, LessonLayer.l3);
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
      expect(service.read('cyber-class')?.progress?.layer, LessonLayer.l3);
      expect(
        service
            .read('cyber-class')
            ?.queuedActions
            .map((action) => action['type']),
        isNot(contains('ADVANCE_GATE_PENDING')),
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

      expect(gate.requests, isEmpty);
      expect(runtime.snapshot().phase.type, ClassroomPhaseType.concluido);
      expect(service.read('cyber-class')?.progress?.layer, LessonLayer.l3);
      expect(service.read('cyber-class')?.attempts, hasLength(2));
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
