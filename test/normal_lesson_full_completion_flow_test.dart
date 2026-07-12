import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_visual_pipeline.dart';
import 'package:sim_mobile/sim/classroom/amparo_controller.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_answer_progress_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_hydration_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_material_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_position_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_session_engine.dart';
import 'package:sim_mobile/sim/classroom/server_advance_gate.dart';
import 'package:sim_mobile/sim/experience/student_experience_engine.dart';
import 'package:sim_mobile/sim/experience/student_experience_t00_adapter.dart';
import 'package:sim_mobile/sim/experience/student_experience_t02_adapter.dart';
import 'package:sim_mobile/sim/experience/student_experience_types.dart';
import 'package:sim_mobile/sim/lesson/dopamine_ready_window_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/lesson/student_lesson_material_service.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

class FullFlowT00Client implements T00BootstrapClient {
  final requests = <T00BootstrapRequest>[];

  @override
  Stream<T00BootstrapChunk> runBootstrap(T00BootstrapRequest request) async* {
    requests.add(request);
    yield const T00BootstrapChunk(
      type: 't00_profile',
      payload: {
        'profile': 'Aluno direto, com exemplos progressivos.',
        'ficha_for_next': {
          'guidance_for_T02': 'Aula curta, pergunta objetiva e tres opcoes.',
          'student_profile_internal': {'pace': 'normal-completion'},
        },
      },
    );
    for (final item in _curriculumItems) {
      yield T00BootstrapChunk(
        type: 't00_item_partial',
        payload: {'item': item},
      );
    }
    yield const T00BootstrapChunk(
      type: 't00_final',
      payload: {'curriculum': _curriculumItems},
    );
  }
}

class FullFlowT02Client implements T02LessonClient {
  final requests = <T02LessonRequest>[];

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    requests.add(request);
    return T02LessonMaterial(
      explanation:
          'Texto ${request.marker} ${request.layer.value}: ${request.item}.',
      question: 'Qual alternativa resolve ${request.marker}?',
      options: const {
        AnswerLetter.A: 'Resposta correta',
        AnswerLetter.B: 'Distrator proximo',
        AnswerLetter.C: 'Distrator distante',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'A alternativa A segue a explicacao.',
      whyWrong: const {'B': 'confunde o passo', 'C': 'troca a regra'},
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'normal-flow-fake-t02',
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

class FullFlowAdvanceGateClient implements ServerAdvanceGateClient {
  final requests = <ServerAdvanceGateRequest>[];

  @override
  Future<ServerAdvanceGateDecision> decide(
    ServerAdvanceGateRequest request,
  ) async {
    requests.add(request);
    final isLastLayer = request.layer == LessonLayer.l3;
    final decision = isLastLayer ? 'next_item' : 'next_layer';
    final nextItemIdx = isLastLayer ? request.itemIdx + 1 : request.itemIdx;
    final nextLayer = isLastLayer
        ? LessonLayer.l1
        : LessonLayerValue.fromValue(request.layer.value + 1);
    return ServerAdvanceGateDecision(
      accepted: true,
      decision: decision,
      reason: 'test_server_$decision',
      nextItemIdx: nextItemIdx,
      nextLayer: nextLayer,
      highWaterMark: requests.length,
      events: [
        {
          'type': 'ADVANCE_GATE_DECIDED',
          'decision': decision,
          'marker': request.marker,
          'layer': request.layer.value,
          'letra': request.selectedOption.name,
          'sinal': request.signal.value,
        },
      ],
    );
  }
}

class PropositionEAdvanceGateClient implements ServerAdvanceGateClient {
  final requests = <ServerAdvanceGateRequest>[];

  @override
  Future<ServerAdvanceGateDecision> decide(
    ServerAdvanceGateRequest request,
  ) async {
    requests.add(request);
    expect(request.lessonLocalId, isNotEmpty);
    expect(request.marker, isNotEmpty);
    expect(request.questionId, isNotEmpty);
    expect(request.questionText, isNotEmpty);
    expect(request.correctOption, isNotNull);
    expect(request.currentState?.currentLessonMaterial, isNotNull);
    expect(request.currentState?.currentLessonMaterial?['correct_answer'], 'A');
    expect(request.idempotencyKey, contains(request.marker));

    if (!request.correct) {
      return ServerAdvanceGateDecision(
        accepted: true,
        decision: 'continue_same_item',
        reason: 'incorrect_answer_no_advancement',
        nextItemIdx: request.itemIdx,
        nextLayer: request.layer,
        highWaterMark: requests.length,
        events: [
          {
            'type': 'ADVANCE_GATE_DECIDED',
            'decision': 'continue_same_item',
            'reason': 'incorrect_answer_no_advancement',
            'ruleApplied': 'validated_error_no_advancement',
            'marker': request.marker,
            'layer': request.layer.value,
            'evidence': {
              'selectedOption': request.selectedOption.name,
              'correctOption': request.correctOption?.name,
              'signal': request.signal.value,
              'validatedCorrect': false,
            },
          },
        ],
      );
    }

    final isLayerThree = request.layer == LessonLayer.l3;
    final decision = isLayerThree ? 'next_item' : 'next_layer';
    final reason = isLayerThree
        ? 'validated_l3_to_next_item'
        : 'validated_correct_secure_l1_to_l3';
    final nextItemIdx = isLayerThree ? request.itemIdx + 1 : request.itemIdx;
    final nextLayer = isLayerThree ? LessonLayer.l1 : LessonLayer.l3;

    return ServerAdvanceGateDecision(
      accepted: true,
      decision: decision,
      reason: reason,
      nextItemIdx: nextItemIdx,
      nextLayer: nextLayer,
      highWaterMark: requests.length,
      events: [
        {
          'type': 'ADVANCE_GATE_DECIDED',
          'decision': decision,
          'reason': reason,
          'ruleApplied': reason,
          'marker': request.marker,
          'layer': request.layer.value,
          'before': {'itemIdx': request.itemIdx, 'layer': request.layer.value},
          'after': {'itemIdx': nextItemIdx, 'layer': nextLayer.value},
          'evidence': {
            'selectedOption': request.selectedOption.name,
            'correctOption': request.correctOption?.name,
            'signal': request.signal.value,
            'validatedCorrect': true,
          },
        },
      ],
    );
  }
}

class FullFlowHarness {
  FullFlowHarness({
    Map<String, StudentLearningState>? seed,
    ServerAdvanceGateClient? serverAdvanceGateClient,
  }) : service = StudentLearningStateService(seed: seed),
       t00 = FullFlowT00Client(),
       t02 = FullFlowT02Client(),
       advanceGate = serverAdvanceGateClient ?? FullFlowAdvanceGateClient() {
    orchestrator = LessonOrchestrator(
      t02Client: t02,
      cache: LessonMaterialCache(maxLessons: 3),
      bus: LessonEventBus(),
      visualPipeline: fakeVisualPipeline(),
    );
    readyWindow = DopamineReadyWindowEngine(
      service: service,
      orchestrator: orchestrator,
    );
    materialService = StudentLessonMaterialService(
      stateService: service,
      orchestrator: orchestrator,
      readyWindowEngine: readyWindow,
    );
    materialController = LessonMaterialController(
      stateService: service,
      materialService: materialService,
    );
    experience = StudentExperienceEngine(
      service: service,
      t00: StudentExperienceT00Adapter(service: service, client: t00),
      t02: StudentExperienceT02Adapter(
        service: service,
        materialService: materialService,
      ),
      placement: const SettledPlacementReader(settled: true),
    );
    runtime = LessonRuntimeEngine(
      stateService: service,
      sessionEngine: LessonSessionEngine(service: service),
      hydrationEngine: LessonHydrationEngine(materialService: materialService),
      positionEngine: LessonPositionEngine(),
      materialController: materialController,
      answerController: LessonAnswerProgressController(
        stateService: service,
        materialService: materialService,
        materialController: materialController,
        serverAdvanceGateClient: advanceGate,
      ),
    );
  }

  final StudentLearningStateService service;
  final FullFlowT00Client t00;
  final FullFlowT02Client t02;
  final dynamic advanceGate;
  late final LessonOrchestrator orchestrator;
  late final DopamineReadyWindowEngine readyWindow;
  late final StudentLessonMaterialService materialService;
  late final LessonMaterialController materialController;
  late final StudentExperienceEngine experience;
  late final LessonRuntimeEngine runtime;
}

const _curriculumItems = [
  {
    'order': 1,
    'marker': 'M1',
    'title': 'Frações equivalentes',
    'microitem_for_teacher': 'Reconhecer frações equivalentes simples',
  },
  {
    'order': 2,
    'marker': 'M2',
    'title': 'Comparação de frações',
    'microitem_for_teacher': 'Comparar frações com denominadores iguais',
  },
  {
    'order': 3,
    'marker': 'M3',
    'title': 'Soma de frações',
    'microitem_for_teacher': 'Somar frações com denominadores iguais',
  },
];

const _expectedPath = [
  (marker: 'M1', layer: LessonLayer.l1, signal: DecisionSignal.two),
  (marker: 'M1', layer: LessonLayer.l2, signal: DecisionSignal.two),
  (marker: 'M1', layer: LessonLayer.l3, signal: DecisionSignal.one),
  (marker: 'M2', layer: LessonLayer.l1, signal: DecisionSignal.two),
  (marker: 'M2', layer: LessonLayer.l2, signal: DecisionSignal.two),
  (marker: 'M2', layer: LessonLayer.l3, signal: DecisionSignal.one),
  (marker: 'M3', layer: LessonLayer.l1, signal: DecisionSignal.two),
  (marker: 'M3', layer: LessonLayer.l2, signal: DecisionSignal.two),
  (marker: 'M3', layer: LessonLayer.l3, signal: DecisionSignal.one),
];

void main() {
  test(
    'normal_lesson_full_completion_flow_test: login valido -> T00/T02 -> 3 itens x 3 layers -> conclusao com persistencia',
    () async {
      const lessonLocalId = 'normal-full-completion';
      var h = FullFlowHarness();

      final result = await h.experience.prepareStudentExperienceEntry(
        const StudentExperienceArgs(
          academic: 'fundamental',
          idioma: 'pt-BR',
          lessonLocalId: lessonLocalId,
          onboarding: {
            'objetivo': 'Aprender frações no fluxo normal',
            'free_text': 'Aprender frações no fluxo normal',
            'stable_lang': 'pt-BR',
            'academic_level': 'fundamental',
            'preferred_name': 'Ana',
          },
        ),
      );

      expect(result.destination, '/cyber/aula');
      await _waitUntil(
        () => h.service.read(lessonLocalId)?.curriculum?.items.length == 3,
      );
      expect(h.t00.requests, hasLength(1), reason: 'T00 deve ser chamado');
      expect(
        h.t00.requests.single.onboarding['stable_lang'],
        'pt-BR',
        reason: 'idioma escolhido deve governar o fluxo',
      );
      expect(h.t02.requests, isNotEmpty, reason: 'T02 deve preparar aula');

      var snap = await h.runtime.open(
        lessonLocalId: lessonLocalId,
        authReady: true,
        authed: true,
      );
      expect(snap.authReady, isTrue);
      expect(snap.authed, isTrue);
      expect(snap.hasCurriculum, isTrue);
      expect(snap.phase.type, ClassroomPhaseType.lendo);

      var totalRequests = h.t02.requests.length;
      var restoredOnce = false;

      for (var index = 0; index < _expectedPath.length; index++) {
        final step = _expectedPath[index];
        snap = h.runtime.snapshot();
        expect(snap.phase.type, ClassroomPhaseType.lendo);
        expect(snap.itemMarker, step.marker);
        expect(snap.conteudo?.explanation, isNotEmpty);
        expect(snap.conteudo?.question, isNotEmpty);
        expect(snap.conteudo?.options.keys, containsAll(AnswerLetter.values));
        expect(snap.imagem, isNull, reason: 'imagem nao deve bloquear texto');
        expect(
          h.service.read(lessonLocalId)?.audio.status,
          anyOf('idle', 'ready'),
          reason: 'audio nao deve bloquear a aula',
        );

        h.runtime.select(AnswerLetter.A);
        expect(h.runtime.snapshot().phase.letter, AnswerLetter.A);
        await h.runtime.signal(step.signal);

        var state = h.service.read(lessonLocalId)!;
        expect(state.attempts, hasLength(index + 1));
        expect(state.attempts.last.marker, step.marker);
        expect(state.attempts.last.layer, step.layer);
        expect(state.attempts.last.letra, AnswerLetter.A);
        expect(state.attempts.last.sinal, step.signal);
        expect(state.attempts.last.correct, isTrue);
        expect(
          state.events.map((event) => event.type),
          contains('ADVANCE_GATE_DECIDED'),
        );
        expect(h.advanceGate.requests, isNotEmpty);
        expect(h.advanceGate.requests.last.marker, step.marker);

        await h.runtime.advance();

        if (index == 3 && !restoredOnce) {
          final persisted = StudentLearningState.fromJson(
            h.service.read(lessonLocalId)!.toJson(),
          );
          expect(persisted.attempts, hasLength(4));
          expect(persisted.progress?.itemIdx, 1);
          expect(persisted.progress?.layer, LessonLayer.l2);

          totalRequests += h.t02.requests.length;
          h = FullFlowHarness(seed: {lessonLocalId: persisted});
          snap = await h.runtime.open(
            lessonLocalId: lessonLocalId,
            authReady: true,
            authed: true,
          );
          expect(snap.phase.type, ClassroomPhaseType.lendo);
          expect(snap.itemMarker, 'M2');
          expect(h.service.read(lessonLocalId)?.attempts, hasLength(4));
          restoredOnce = true;
        }
      }

      snap = h.runtime.snapshot();
      expect(snap.phase.type, ClassroomPhaseType.fim);
      expect(snap.isDone, isTrue);

      final finalState = h.service.read(lessonLocalId)!;
      expect(finalState.curriculum?.items, hasLength(3));
      expect(finalState.progress?.itemIdx, 3);
      expect(finalState.progress?.layer, LessonLayer.l1);
      expect(finalState.progress?.mainAdvances, greaterThanOrEqualTo(3));
      expect(finalState.progress?.pctAvanco, 100);
      expect(finalState.progress?.concluidos, containsAll(['M1', 'M2', 'M3']));
      expect(finalState.attempts, hasLength(9));
      expect(
        finalState.events.map((event) => event.type),
        contains('FINAL_COMPLETION_ALLOWED'),
      );
      expect(
        restoredOnce,
        isTrue,
        reason: 'estado deve sobreviver a reabertura',
      );
      expect(
        totalRequests + h.t02.requests.length,
        greaterThanOrEqualTo(9),
        reason: 'T02 deve ser chamado para aulas/layers do caminho normal',
      );
    },
  );

  test(
    'proposicao E: jornada real abre, erra, recebe amparo, acerta no servidor, salva, reabre e continua',
    () async {
      const lessonLocalId = 'proposicao-e-journey';
      final server = PropositionEAdvanceGateClient();
      var h = FullFlowHarness(serverAdvanceGateClient: server);

      final result = await h.experience.prepareStudentExperienceEntry(
        const StudentExperienceArgs(
          academic: 'fundamental',
          idioma: 'pt-BR',
          lessonLocalId: lessonLocalId,
          onboarding: {
            'objetivo': 'Aprender frações com apoio seguro',
            'free_text': 'Aprender frações com apoio seguro',
            'stable_lang': 'pt-BR',
            'academic_level': 'fundamental',
            'preferred_name': 'Ana',
          },
        ),
      );

      expect(result.destination, '/cyber/aula');
      await _waitUntil(
        () => h.service.read(lessonLocalId)?.currentLessonMaterial != null,
      );
      var state = h.service.read(lessonLocalId)!;
      expect(state.curriculum?.items.first.marker, 'M1');
      expect(state.current?.marker, 'M1');
      expect(state.currentLessonMaterial?['question'], isNotEmpty);
      expect(state.currentLessonMaterial?['correct_answer'], 'A');

      var snap = await h.runtime.open(
        lessonLocalId: lessonLocalId,
        authReady: true,
        authed: true,
      );
      expect(snap.phase.type, ClassroomPhaseType.lendo);
      expect(snap.itemMarker, 'M1');

      final wrongSteps = [
        (letter: AnswerLetter.B, signal: DecisionSignal.two),
        (letter: AnswerLetter.C, signal: DecisionSignal.three),
        (letter: AnswerLetter.B, signal: DecisionSignal.one),
      ];
      for (var index = 0; index < wrongSteps.length; index++) {
        final step = wrongSteps[index];
        h.runtime.select(step.letter);
        await h.runtime.signal(step.signal);
        state = h.service.read(lessonLocalId)!;
        expect(state.progress?.itemIdx, 0);
        expect(state.progress?.layer, LessonLayer.l1);
        expect(state.progress?.concluidos, isEmpty);
        expect(state.truth.itemConsolidationStatus['M1'], isNot('mastered'));
        expect(state.attempts.last.correct, isFalse);
        if (index < wrongSteps.length - 1) {
          await h.runtime.advance();
        }
      }

      state = h.service.write(
        const AmparoController().applyIfNeeded(
          state: h.service.read(lessonLocalId)!,
          correct: false,
          ts: 1000,
        ),
      );
      expect(state.progress?.amparoLvl, 1);
      expect(
        state.events.map((event) => event.type),
        contains('AMPARO_TRIGGERED'),
      );
      expect(state.truth.itemConsolidationStatus['M1'], isNot('mastered'));
      expect(state.truth.masteryEvidence, isEmpty);
      expect(state.truth.conquestRecords, isEmpty);

      await h.runtime.advance();
      snap = h.runtime.snapshot();
      expect(snap.phase.type, ClassroomPhaseType.lendo);
      expect(
        h.service
            .read(lessonLocalId)
            ?.events
            .where((event) => event.type == 'LESSON_TEXT_READY')
            .map((event) => event.payload['mode']),
        contains(LessonMode.amparo.name),
      );
      expect(h.service.read(lessonLocalId)?.progress?.layer, LessonLayer.l1);

      h.runtime.select(AnswerLetter.A);
      await h.runtime.signal(DecisionSignal.one);
      state = h.service.read(lessonLocalId)!;
      expect(server.requests.last.correct, isTrue);
      expect(state.progress?.itemIdx, 0);
      expect(state.progress?.layer, LessonLayer.l3);
      expect(state.progress?.concluidos, isEmpty);
      expect(state.attempts, hasLength(4));
      expect(
        state.events
            .lastWhere((event) => event.type == 'ADVANCE_GATE_DECIDED')
            .payload['ruleApplied'],
        'validated_correct_secure_l1_to_l3',
      );

      final persisted = StudentLearningState.fromJson(state.toJson());
      final staleCache = state.copyWith(
        progress: state.progress?.copyWith(
          itemIdx: 0,
          layer: LessonLayer.l1,
          concluidos: const [],
        ),
        attempts: const [],
        events: const [],
      );
      expect(staleCache.progress?.layer, LessonLayer.l1);
      h = FullFlowHarness(
        seed: {lessonLocalId: persisted},
        serverAdvanceGateClient: server,
      );
      snap = await h.runtime.open(
        lessonLocalId: lessonLocalId,
        authReady: true,
        authed: true,
      );

      final reopened = h.service.read(lessonLocalId)!;
      expect(snap.phase.type, ClassroomPhaseType.lendo);
      expect(reopened.current?.marker, 'M1');
      expect(reopened.progress?.layer, LessonLayer.l3);
      expect(reopened.progress?.amparoLvl, 1);
      expect(reopened.attempts, hasLength(4));
      expect(reopened.currentLessonMaterial?['question'], isNotEmpty);
      expect(
        reopened.events.map((event) => event.type),
        containsAll(['AMPARO_TRIGGERED', 'ADVANCE_GATE_DECIDED']),
      );
      expect(
        reopened.extra['serverAdvanceGate'],
        isA<Map>(),
        reason: 'decisao forte deve ficar rastreavel no estado',
      );
      expect(reopened.truth.itemConsolidationStatus['M1'], isNot('mastered'));
      expect(
        server.requests,
        hasLength(4),
        reason: 'toda tentativa A/B/C + sinal deve passar pelo servidor',
      );

      h.runtime.select(AnswerLetter.A);
      await h.runtime.signal(DecisionSignal.one);
      final postReopen = h.service.read(lessonLocalId)!;
      expect(
        server.requests,
        hasLength(5),
        reason: 'a acao apos reabertura tambem deve chamar o servidor',
      );
      expect(server.requests.last.marker, 'M1');
      expect(server.requests.last.layer, LessonLayer.l3);
      expect(server.requests.last.correct, isTrue);
      expect(postReopen.attempts, hasLength(5));
      expect(postReopen.attempts.last.marker, 'M1');
      expect(postReopen.attempts.last.layer, LessonLayer.l3);
      expect(postReopen.progress?.itemIdx, 1);
      expect(postReopen.progress?.layer, LessonLayer.l1);
      expect(postReopen.progress?.concluidos, contains('M1'));
      expect(postReopen.current?.marker, 'M2');
      expect(
        postReopen.events
            .lastWhere((event) => event.type == 'ADVANCE_GATE_DECIDED')
            .payload['decision'],
        'next_item',
      );
      expect(postReopen.truth.itemConsolidationStatus['M1'], isNot('mastered'));

      await h.runtime.advance();
      final continued = h.runtime.snapshot();
      expect(continued.phase.type, ClassroomPhaseType.lendo);
      expect(continued.itemMarker, 'M2');
      expect(continued.conteudo?.question, isNotEmpty);
      expect(h.service.read(lessonLocalId)?.progress?.layer, LessonLayer.l1);
      expect(
        h.service.read(lessonLocalId)?.attempts,
        hasLength(5),
        reason: 'continuar a aula nao pode duplicar tentativa restaurada',
      );
    },
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  if (condition()) return;
  fail('condicao esperada nao ocorreu antes do timeout');
}
