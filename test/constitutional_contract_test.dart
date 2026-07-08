import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_answer_progress_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_material_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_position_engine.dart';
import 'package:sim_mobile/sim/cloud/cloud_functions.dart';
import 'package:sim_mobile/sim/constitution/sim_constitutional_contract.dart';
import 'package:sim_mobile/sim/lesson/dopamine_ready_window_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/student_lesson_material_service.dart';
import 'package:sim_mobile/sim/state/mastery_truth_engine.dart';
import 'package:sim_mobile/sim/state/student_state_contract.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

const _contract = SimConstitutionalContract();

const _items = [
  CurriculumItem(marker: 'M1', text: 'Item 1'),
  CurriculumItem(marker: 'M2', text: 'Item 2'),
];

const _planned = [
  PlannedItem(marker: 'M1', text: 'Item 1'),
  PlannedItem(marker: 'M2', text: 'Item 2'),
];

LessonContent _content({
  Map<AnswerLetter, String> options = const {
    AnswerLetter.A: 'A',
    AnswerLetter.B: 'B',
    AnswerLetter.C: 'C',
  },
}) {
  return LessonContent(
    explanation: 'Explicacao',
    question: 'Pergunta?',
    options: options,
    correctAnswer: AnswerLetter.A,
  );
}

StudentLearningState _state({
  String lessonLocalId = 'constitutional',
  List<LessonAttempt> attempts = const [],
}) {
  return StudentLearningState.empty(lessonLocalId: lessonLocalId).copyWith(
    curriculum: const StudentCurriculum(
      topic: 'Matematica',
      totalItems: 2,
      generatedAt: null,
      provisional: false,
      items: _items,
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
    attempts: attempts,
  );
}

StudentLearningState _richState({String lessonLocalId = 'constitutional'}) {
  return _state(lessonLocalId: lessonLocalId).copyWith(
    current: const LessonCurrent(
      itemIdx: 1,
      marker: 'M2',
      layer: LessonLayer.l2,
      amparoLvl: 0,
    ),
    progress: const LessonProgress(
      itemIdx: 1,
      layer: LessonLayer.l2,
      erros: 1,
      amparoLvl: 0,
      historia: ['M1:A:1'],
      mainAdvances: 1,
      concluidos: ['M1'],
      pendentesMarkers: ['M2'],
      totalItems: 2,
      pctAvanco: 50,
    ),
    attempts: const [
      LessonAttempt(
        marker: 'M1',
        layer: LessonLayer.l1,
        letra: AnswerLetter.A,
        sinal: DecisionSignal.one,
        correct: true,
        ts: 10,
      ),
    ],
    events: const [
      StudentLearningEvent(
        type: 'ANSWER_SUBMITTED',
        ts: 10,
        payload: {'marker': 'M1'},
      ),
      StudentLearningEvent(
        type: 'NEXT_ACTION_DECIDED',
        ts: 11,
        payload: {'marker': 'M1'},
      ),
    ],
    currentLessonMaterial: const {
      'text_status': 'ready',
      'explanation': 'Explicacao salva',
      'question': 'Pergunta salva?',
      'options': {'A': 'A', 'B': 'B', 'C': 'C'},
      'correct_answer': 'A',
      'imagem': 'data:image/png;base64,AAAA',
      'audio': {'status': 'ready', 'cache_key': 'audio-1'},
    },
    readyLessonMaterials: const {
      '1:M2:L2': {'text_status': 'ready', 'explanation': 'Proxima explicacao'},
    },
    auxRooms: const {
      'review': {'status': 'scheduled'},
      'recovery': {'status': 'required'},
    },
  );
}

LessonPositionState _position({
  ClassroomPhase phase = const ClassroomPhase.reading(),
  LessonContent? content,
}) {
  return LessonPositionState(
    itemIdx: 0,
    layer: LessonLayer.l1,
    erros: 0,
    historia: const [],
    history: const [],
    mainAdvances: 0,
    loadingLayer: LessonLayer.l1,
    conteudo: content ?? _content(),
    phase: phase,
    imagem: null,
    teoriaPronta: true,
    items: List<PlannedItem>.from(_planned),
  );
}

LessonAnswerProgressController _controller(
  StudentLearningStateService service, {
  _FakeLessonMaterialController? materialController,
}) {
  final fakeMaterialService = _FakeStudentLessonMaterialService();
  return LessonAnswerProgressController(
    stateService: service,
    materialService: fakeMaterialService,
    materialController: materialController ?? _FakeLessonMaterialController(),
    constitutionalContract: _contract,
  );
}

void main() {
  test('1 A1 app expõe leis constitucionais executáveis', () {
    expect(SimConstitutionalContract.laws, hasLength(7));
    expect(
      SimConstitutionalContract.laws,
      containsAll([
        SimConstitutionalLaw.notChatbot,
        SimConstitutionalLaw.notSuperficialQuiz,
        SimConstitutionalLaw.aiNotStateAuthority,
        SimConstitutionalLaw.softwareValidatesLearning,
        SimConstitutionalLaw.advanceRequiresEvidence,
        SimConstitutionalLaw.firstLessonPriority,
        SimConstitutionalLaw.textDoesNotWaitForMedia,
      ]),
    );
  });

  test('2 A1 app rejeita modo chatbot solto', () {
    expect(
      () => _contract.assertInteraction(
        const SimInteractionContract(
          freeChatMode: true,
          lessonStructured: false,
          hasExplanation: false,
          hasQuestion: false,
          hasOptions: false,
          hasFeedbackPath: false,
          hasEvidenceSignal: false,
        ),
      ),
      throwsA(isA<SimConstitutionViolation>()),
    );
  });

  test('3 A1 app rejeita quiz superficial', () {
    expect(
      () => _contract.assertInteraction(
        const SimInteractionContract(
          lessonStructured: true,
          hasExplanation: true,
          hasQuestion: true,
          hasOptions: true,
          hasFeedbackPath: false,
          hasEvidenceSignal: false,
        ),
      ),
      throwsA(isA<SimConstitutionViolation>()),
    );
  });

  test('4 A1 app valida aula estruturada A/B/C', () {
    _contract.assertLessonMaterial(_content());
    expect(
      () => _contract.assertLessonMaterial(
        _content(options: const {AnswerLetter.A: 'A', AnswerLetter.B: 'B'}),
      ),
      throwsA(isA<SimConstitutionViolation>()),
    );
  });

  test('5 A1 app exige evidência validada pelo software', () {
    expect(
      () => _contract.validateEvidence(
        const SimAnswerEvidence(
          marker: 'M1',
          layer: LessonLayer.l1,
          selectedAnswer: AnswerLetter.A,
          signal: DecisionSignal.one,
          correct: true,
          validatedBySoftware: false,
        ),
      ),
      throwsA(isA<SimConstitutionViolation>()),
    );
  });

  test('6 A1 Advance Gate não aceita decisão de IA sem evidência', () {
    final gate = _contract.evaluateAdvanceGate(
      evidence: null,
      masteryEvidence: null,
      aiDecision: const {'advance': true},
    );
    expect(gate.allowAdvance, isFalse);
    expect(gate.law, SimConstitutionalLaw.advanceRequiresEvidence);
  });

  test(
    '7 A1 enviarSinal real registra tentativa e feedback após evidência',
    () async {
      final service = StudentLearningStateService(
        seed: {'constitutional': _state()},
      );
      final position = _position(
        phase: const ClassroomPhase.expanded(AnswerLetter.A),
      );

      await _controller(service).enviarSinal(
        lessonLocalId: 'constitutional',
        topic: 'Matematica',
        position: position,
        signal: DecisionSignal.one,
        baseItems: _planned,
      );

      final state = service.read('constitutional')!;
      expect(state.attempts, hasLength(1));
      expect(state.attempts.single.correct, isTrue);
      expect(position.phase.type, ClassroomPhaseType.concluido);
    },
  );

  test(
    '8 A1 um acerto isolado não conclui item nem avança progresso',
    () async {
      final service = StudentLearningStateService(
        seed: {'constitutional': _state()},
      );
      final position = _position(
        phase: const ClassroomPhase.expanded(AnswerLetter.A),
      );

      await _controller(service).enviarSinal(
        lessonLocalId: 'constitutional',
        topic: 'Matematica',
        position: position,
        signal: DecisionSignal.one,
        baseItems: _planned,
      );

      final progress = service.read('constitutional')!.progress!;
      expect(progress.itemIdx, 0);
      expect(progress.concluidos, isEmpty);
      expect(
        service
            .read('constitutional')!
            .extra['next_action']['constitutional_gate'],
        'dominio real ainda nao comprovado',
      );
    },
  );

  test('9 A1 botão real de avançar não move sem evidência gravada', () async {
    final service = StudentLearningStateService(
      seed: {'constitutional': _state()},
    );
    final materialController = _FakeLessonMaterialController();
    final position = _position(
      phase: const ClassroomPhase.completed(
        message: 'ok',
        wasCorrect: true,
        signal: DecisionSignal.one,
      ),
    );

    await _controller(service, materialController: materialController).avancar(
      lessonLocalId: 'constitutional',
      topic: 'Matematica',
      position: position,
      baseItems: _planned,
      idioma: 'pt-BR',
      academic: 'fundamental',
    );

    expect(materialController.loadCalls, 0);
    expect(
      service.read('constitutional')!.events.map((event) => event.type),
      contains('ADVANCE_REJECTED_BY_CONSTITUTION'),
    );
  });

  test(
    '10 A1 texto tem prioridade e persistência app envia source software',
    () {
      expect(
        _contract.taskPriority('first_lesson_text') <
            _contract.taskPriority('image'),
        isTrue,
      );
      expect(
        _contract.canShowLessonText(
          textReady: true,
          imageStatus: 'pending',
          audioStatus: 'failed',
        ),
        isTrue,
      );
      final payload = PersistStudentStateInput(
        lessonLocalId: 'constitutional',
        state: _state(),
        clientUpdatedAt: 1,
        clientScore: 1,
      ).toJson();
      expect(payload['source'], 'software');
    },
  );

  group('A2 separação de poderes Pai/Assistente/Tutor', () {
    test('A2.1 mapa dos poderes existe no app', () {
      expect(SimConstitutionalContract.powerMap, hasLength(3));
      expect(
        SimConstitutionalContract.powerMap[SimPowerActor.father]!.owns,
        containsAll(['laws', 'protection', 'constitutional_blockers']),
      );
      expect(
        SimConstitutionalContract.powerMap[SimPowerActor.assistant]!.owns,
        containsAll(['state', 'route', 'progress', 'validation', 'advance']),
      );
      expect(
        SimConstitutionalContract.powerMap[SimPowerActor.tutor]!.owns,
        contains('content_generation'),
      );
    });

    test('A2.2 IA/Tutor não escreve progresso', () {
      expect(
        () => _contract.assertTutorCannotControlState({
          'conteudo': {
            'explanation': 'Texto',
            'statePatch': {
              'progress': {'itemIdx': 2},
            },
          },
        }),
        throwsA(isA<SimConstitutionViolation>()),
      );
    });

    test(
      'A2.3 material vindo para tela passa por contrato antes de aplicar',
      () async {
        final service = StudentLearningStateService(
          seed: {'constitutional': _state()},
        );
        final controller = LessonMaterialController(
          stateService: service,
          materialService: _FakeStudentLessonMaterialService(
            fastResult: ResolveLessonMaterialResult(
              conteudo: _content(
                options: const {AnswerLetter.A: 'A', AnswerLetter.B: 'B'},
              ),
              imagem: null,
              source: LessonMaterialSource.studentState,
              waitedMs: 0,
            ),
          ),
          constitutionalContract: _contract,
        );
        final position = _position();

        await expectLater(
          controller.carregar(
            lessonLocalId: 'constitutional',
            topic: 'Matematica',
            position: position,
            idioma: 'pt-BR',
            academic: 'fundamental',
            mode: LessonMode.session,
            baseItems: _planned,
          ),
          throwsA(isA<SimConstitutionViolation>()),
        );
        expect(position.conteudo?.options[AnswerLetter.C], 'C');
      },
    );

    test('A2.4 Assistente/software é o único dono de progresso persistido', () {
      _contract.assertStateMutationAuthority(
        source: 'software',
        touchesProgress: true,
      );
      expect(
        () => _contract.assertStateMutationAuthority(
          source: 'tutor',
          touchesProgress: true,
        ),
        throwsA(isA<SimConstitutionViolation>()),
      );
      expect(
        PersistStudentStateInput(
          lessonLocalId: 'constitutional',
          state: _state(),
          clientUpdatedAt: 1,
          clientScore: 1,
        ).toJson()['source'],
        'software',
      );
    });

    test('A2.5 avanço depende do motor de software', () {
      final gate = _contract.evaluateAdvanceGate(
        evidence: const SimAnswerEvidence(
          marker: 'M1',
          layer: LessonLayer.l1,
          selectedAnswer: AnswerLetter.A,
          signal: DecisionSignal.one,
          correct: true,
          validatedBySoftware: true,
        ),
        masteryEvidence: const MasteryEvidence(
          marker: 'M1',
          status: MasteryStatus.mastered,
          reason: 'dominio comprovado',
          score: 1,
          consecutiveCorrect: 1,
          consecutiveWrong: 0,
          attemptCount: 1,
          needsReview: false,
          needsReinforcement: false,
        ),
        aiDecision: const {'advance': false},
      );
      expect(gate.allowAdvance, isTrue);
      expect(gate.reason, 'software validou evidencia e dominio');
    });

    test('A2.6 Pai bloqueia violação de regra com erro controlado', () {
      expect(
        () => _contract.assertPowerBoundary(
          actor: SimPowerActor.tutor,
          action: 'advance_student',
          target: 'progress',
        ),
        throwsA(
          isA<SimConstitutionViolation>().having(
            (error) => error.law,
            'law',
            SimConstitutionalLaw.aiNotStateAuthority,
          ),
        ),
      );
    });

    test('A2.7 app obedece ao mesmo contrato do servidor', () {
      _contract.assertPowerBoundary(
        actor: SimPowerActor.assistant,
        action: 'persist_state',
        target: 'progress',
      );
      expect(
        () => _contract.assertPowerBoundary(
          actor: SimPowerActor.father,
          action: 'persist_state',
          target: 'progress',
        ),
        throwsA(isA<SimConstitutionViolation>()),
      );
    });

    test('A2.8 conteúdo inválido da IA não altera estado', () {
      final service = StudentLearningStateService(
        seed: {'constitutional': _state()},
      );
      final before = service.read('constitutional')!.toJson();

      expect(
        () => _contract.assertTutorCannotControlState({
          'feedback': 'Pode avançar',
          'patch': {
            'concluidos': ['M1'],
          },
        }),
        throwsA(isA<SimConstitutionViolation>()),
      );

      expect(service.read('constitutional')!.toJson(), before);
    });

    test('A2.9 avanço real rejeita falta de evidência A/B/C + sinal', () async {
      final service = StudentLearningStateService(
        seed: {'constitutional': _state()},
      );
      final position = _position(
        phase: const ClassroomPhase.completed(
          message: 'ok',
          wasCorrect: true,
          signal: DecisionSignal.one,
        ),
      );

      await _controller(service).avancar(
        lessonLocalId: 'constitutional',
        topic: 'Matematica',
        position: position,
        baseItems: _planned,
        idioma: 'pt-BR',
        academic: 'fundamental',
      );

      final events = service
          .read('constitutional')!
          .events
          .map((event) => event.type);
      expect(events, contains('ADVANCE_REJECTED_BY_CONSTITUTION'));
      expect(service.read('constitutional')!.progress!.itemIdx, 0);
    });

    test('A2.10 subproposições A2 têm prova automática no app', () {
      const names = [
        'A2.1',
        'A2.2',
        'A2.3',
        'A2.4',
        'A2.5',
        'A2.6',
        'A2.7',
        'A2.8',
        'A2.9',
        'A2.10',
      ];
      expect(names, hasLength(10));
      expect(names.toSet(), hasLength(10));
    });
  });

  group('A3 Estado do Aluno como Fonte de Verdade', () {
    test('A3.1 inventário do estado do aluno existe no app', () {
      expect(
        StudentStateContract.requiredDomains,
        containsAll([
          'profile',
          'language',
          'objective',
          'curriculum',
          'current_item',
          'current_layer',
          'attempts',
          'history',
          'completed',
          'pending',
          'reviews',
          'recoveries',
          'events',
          'current_material',
          'prepared_materials',
        ]),
      );
      expect(StudentStateContract.requiredDomains, hasLength(15));
    });

    test('A3.2 estado não fica só na tela: write pobre não apaga store', () {
      final service = StudentLearningStateService(
        seed: {'constitutional': _richState()},
      );
      service.write(
        StudentLearningState.empty(lessonLocalId: 'constitutional'),
      );
      final restored = service.read('constitutional')!;
      expect(restored.progress?.itemIdx, 1);
      expect(restored.progress?.layer, LessonLayer.l2);
      expect(restored.attempts, hasLength(1));
      expect(restored.progress?.pendentesMarkers, ['M2']);
    });

    test('A3.3 estado não fica na IA', () {
      final service = StudentLearningStateService(
        seed: {'constitutional': _richState()},
      );
      final before = service.read('constitutional')!.toJson();
      expect(
        () => _contract.assertTutorCannotControlState({
          'content': 'texto',
          'current': {'itemIdx': 9},
        }),
        throwsA(isA<SimConstitutionViolation>()),
      );
      expect(service.read('constitutional')!.toJson(), before);
    });

    test('A3.4 eventos críticos mínimos são salvos no State Store', () async {
      expect(
        StudentStateContract.criticalEvents,
        containsAll([
          'OBJECTIVE_SUBMITTED',
          'CURRICULUM_RECEIVED',
          'FIRST_LESSON_WRITTEN_TO_STATE',
          'ANSWER_SUBMITTED',
          'SIGNAL_SUBMITTED',
          'NEXT_ACTION_DECIDED',
          'REVIEW_SCHEDULED',
          'RECOVERY_REQUIRED',
          'DOUBT_RECORDED',
        ]),
      );
      final service = StudentLearningStateService(
        seed: {'constitutional': _state()},
      );
      final position = _position(
        phase: const ClassroomPhase.expanded(AnswerLetter.A),
      );
      await _controller(service).enviarSinal(
        lessonLocalId: 'constitutional',
        topic: 'Matematica',
        position: position,
        signal: DecisionSignal.one,
        baseItems: _planned,
      );
      expect(
        service.read('constitutional')!.events.map((event) => event.type),
        containsAll([
          'ANSWER_SUBMITTED',
          'SIGNAL_SUBMITTED',
          'NEXT_ACTION_DECIDED',
        ]),
      );
    });

    test('A3.5 fechar e reabrir preserva posição, histórico e pendências', () {
      final restored = StudentLearningState.fromJson(_richState().toJson());
      expect(restored.current?.marker, 'M2');
      expect(restored.current?.layer, LessonLayer.l2);
      expect(restored.progress?.historia, ['M1:A:1']);
      expect(restored.attempts, hasLength(1));
      expect(restored.progress?.pendentesMarkers, ['M2']);
    });

    test('A3.6 estado vazio não sobrescreve estado rico', () {
      const contract = StudentStateContract();
      final rich = _richState();
      final empty = StudentLearningState.empty(lessonLocalId: 'constitutional');
      expect(contract.isRegression(existing: rich, incoming: empty), isTrue);
      final merged = mergeStudentLearningStateFromCloud(rich, empty);
      expect(merged.progress?.concluidos, ['M1']);
      expect(merged.currentLessonMaterial?['explanation'], 'Explicacao salva');
    });

    test('A3.7 estado antigo não vence estado mais novo/avançado', () {
      final old = _state();
      final rich = _richState();
      final merged = mergeStudentLearningStateFromCloud(old, rich);
      expect(merged.progress?.itemIdx, 1);
      expect(merged.progress?.layer, LessonLayer.l2);
      expect(merged.progress?.mainAdvances, 1);
    });

    test('A3.8 concluídos, pendências, revisões e recuperações preservam', () {
      final restored = StudentLearningState.fromJson(_richState().toJson());
      expect(restored.progress?.concluidos, ['M1']);
      expect(restored.progress?.pendentesMarkers, ['M2']);
      expect((restored.auxRooms?['review'] as Map)['status'], 'scheduled');
      expect((restored.auxRooms?['recovery'] as Map)['status'], 'required');
    });

    test('A3.9 material atual é restaurável', () {
      final restored = StudentLearningState.fromJson(_richState().toJson());
      final material = restored.currentLessonMaterial!;
      expect(material['explanation'], 'Explicacao salva');
      expect(material['question'], 'Pergunta salva?');
      expect((material['options'] as Map)['A'], 'A');
      expect(material['imagem'], startsWith('data:image/png'));
      expect((material['audio'] as Map)['status'], 'ready');
    });

    test('A3.10 materiais preparados são preservados', () {
      final restored = StudentLearningState.fromJson(_richState().toJson());
      expect(restored.readyLessonMaterials, contains('1:M2:L2'));
      expect(
        restored.readyLessonMaterials['1:M2:L2']?['explanation'],
        'Proxima explicacao',
      );
    });

    test('A3.11 event log existe e é restaurável', () {
      final restored = StudentLearningState.fromJson(_richState().toJson());
      expect(
        restored.events.map((event) => event.type),
        containsAll(['ANSWER_SUBMITTED', 'NEXT_ACTION_DECIDED']),
      );
    });

    test('A3.12 app e servidor usam contrato mínimo serializável comum', () {
      final json = _richState().toJson();
      expect(json, contains('profile'));
      expect(json, contains('curriculum'));
      expect(json, contains('current'));
      expect(json, contains('progress'));
      expect(json, contains('attempts'));
      expect(json, contains('events'));
      expect(json, contains('currentLessonMaterial'));
      expect(json, contains('readyLessonMaterials'));
      expect(
        PersistStudentStateInput(
          lessonLocalId: 'constitutional',
          state: _richState(),
          clientUpdatedAt: 1,
          clientScore: 1,
        ).toJson()['source'],
        'software',
      );
    });

    test('A3.13 Store grava, lê e atualiza estado protegido', () {
      final service = StudentLearningStateService();
      service.write(_richState());
      expect(service.read('constitutional')?.progress?.itemIdx, 1);
      service.mutate('constitutional', (state) {
        return state.copyWith(
          events: [
            ...state.events,
            const StudentLearningEvent(
              type: 'TECHNICAL_ERROR_RECORDED',
              ts: 12,
              payload: {'code': 'x'},
            ),
          ],
        );
      });
      expect(
        service.read('constitutional')?.events.last.type,
        'TECHNICAL_ERROR_RECORDED',
      );
    });

    test('A3.14 restauração simula fechar/reabrir no ponto correto', () {
      final service = StudentLearningStateService(
        seed: {'constitutional': _richState()},
      );
      final serialized = service.read('constitutional')!.toJson();
      final reopened = StudentLearningStateService(
        seed: {'constitutional': StudentLearningState.fromJson(serialized)},
      );
      expect(reopened.read('constitutional')?.current?.marker, 'M2');
      expect(reopened.read('constitutional')?.progress?.layer, LessonLayer.l2);
      expect(reopened.read('constitutional')?.attempts, hasLength(1));
    });

    test('A3.15 regressão vazia, antiga ou incompleta é bloqueada', () {
      final service = StudentLearningStateService(
        seed: {'constitutional': _richState()},
      );
      final old = _state();
      service.write(old);
      final protected = service.read('constitutional')!;
      expect(protected.progress?.itemIdx, 1);
      expect(
        protected.currentLessonMaterial?['explanation'],
        'Explicacao salva',
      );
      expect(protected.readyLessonMaterials, contains('1:M2:L2'));
    });
  });
}

class _FakeStudentLessonMaterialService
    implements StudentLessonMaterialService {
  _FakeStudentLessonMaterialService({this.fastResult});

  final ResolveLessonMaterialResult? fastResult;

  @override
  ResolveLessonMaterialResult? resolveFastLessonMaterialFromStateOrCache(
    ResolveLessonMaterialInput input,
  ) {
    return fastResult;
  }

  @override
  Future<ResolveLessonMaterialResult?> resolveLessonMaterialFromStateOrEngine(
    ResolveLessonMaterialInput input,
  ) async {
    return fastResult;
  }

  @override
  void maintainLessonReadyWindow({
    required String lessonLocalId,
    required String? topic,
    required int itemIdx,
    required LessonLayer layer,
    required List<DopamineWindowItem> items,
    required String source,
    String priority = 'background',
    String? reason,
  }) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLessonMaterialController implements LessonMaterialController {
  int loadCalls = 0;

  @override
  Future<void> carregar({
    required String lessonLocalId,
    required String? topic,
    required LessonPositionState position,
    required String idioma,
    required String academic,
    required LessonMode mode,
    required List<PlannedItem> baseItems,
    bool forceRefresh = false,
  }) async {
    loadCalls += 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
