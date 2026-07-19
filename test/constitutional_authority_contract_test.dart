import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_position_engine.dart';
import 'package:sim_mobile/sim/classroom/local_advance_engine.dart';
import 'package:sim_mobile/sim/experience/start_first_lesson_use_case.dart';
import 'package:sim_mobile/sim/experience/student_experience_types.dart';
import 'package:sim_mobile/sim/lesson/dopamine_ready_window_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/lesson/lesson_readiness_resolver.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/organism/sim_organism.dart';
import 'package:sim_mobile/sim/state/live_entry_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';
import 'package:sim_mobile/sim/state/student_state_store_adapter.dart';

import 'support/memory_test_stores.dart';

void main() {
  group('Autoridade constitucional do SIM App', () {
    test('StudentStateStore e a fonte unica de estado', () {
      final store = StudentStateStore(local: MemoryStudentStateLocalStorage());
      final adapter = StudentStateStoreAdapter(store);

      adapter.write(
        StudentLearningState.empty(lessonLocalId: 'L1').copyWith(
          current: const LessonCurrent(
            itemIdx: 0,
            marker: 'M1',
            layer: LessonLayer.l1,
            amparoLvl: 0,
          ),
        ),
      );

      expect(store.readState('L1').current?.marker, 'M1');
      store.writeState(
        store
            .readState('L1')
            .copyWith(
              current: const LessonCurrent(
                itemIdx: 1,
                marker: 'M2',
                layer: LessonLayer.l1,
                amparoLvl: 0,
              ),
            ),
      );
      expect(adapter.read('L1')?.current?.marker, 'M2');
    });

    test('LessonReadinessResolver e a unica definicao de aula pronta', () {
      final material = preparedMaterialFromLesson(
        lesson: _lesson('M1'),
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l1,
      );
      final state = StudentLearningState.empty(lessonLocalId: 'L1').copyWith(
        readyLessonMaterials: {
          preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): material,
        },
      );
      final resolver = const LessonReadinessResolver();

      final ready = resolver.resolveFromState(
        state: state,
        identity: const LessonReadinessIdentity(
          lessonLocalId: 'L1',
          itemIdx: 0,
          marker: 'M1',
          layer: LessonLayer.l1,
        ),
      );
      final stale = resolver.resolveFromState(
        state: state,
        identity: const LessonReadinessIdentity(
          lessonLocalId: 'L1',
          itemIdx: 1,
          marker: 'M2',
          layer: LessonLayer.l1,
        ),
      );

      expect(ready.status, LessonReadinessStatus.readyFromState);
      expect(ready.lesson?.conteudo.question, 'Pergunta M1?');
      expect(stale.status, LessonReadinessStatus.missing);
      expect(stale.isReady, isFalse);
    });

    test('cache de material nao tem autoridade para alterar progresso', () {
      final service = StudentLearningStateService();
      final state = StudentLearningState.empty(lessonLocalId: 'L1').copyWith(
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
          pendentesMarkers: ['M1'],
          totalItems: 1,
          pctAvanco: 0,
        ),
        readyLessonMaterials: {
          preparedLessonMaterialKey(
            0,
            'M1',
            LessonLayer.l1,
          ): preparedMaterialFromLesson(
            lesson: _lesson('M1'),
            itemIdx: 0,
            marker: 'M1',
            layer: LessonLayer.l1,
          ),
        },
      );
      service.write(state);

      final result = const LessonReadinessResolver().resolveFromState(
        state: service.read('L1'),
        identity: const LessonReadinessIdentity(
          lessonLocalId: 'L1',
          itemIdx: 0,
          marker: 'M1',
          layer: LessonLayer.l1,
        ),
      );

      expect(result.isReady, isTrue);
      expect(service.read('L1')?.current?.marker, 'M1');
      expect(service.read('L1')?.progress?.mainAdvances, 0);
      expect(service.read('L1')?.attempts, isEmpty);
    });

    test('DopamineReadyWindowEngine e dono da janela quente e morna', () {
      final engine = DopamineReadyWindowEngine(
        service: StudentLearningStateService(),
        orchestrator: _orchestrator(),
      );
      final items = List.generate(
        20,
        (index) => DopamineWindowItem(
          text: 'Item ${index + 1}',
          marker: 'M${index + 1}',
        ),
      );

      final plan = engine.buildDopamineWindowPlan(
        fromIdx: 0,
        layer: LessonLayer.l1,
        items: items,
      );

      expect(plan, hasLength(15));
      expect(plan.take(4).map((slot) => slot.idx), [0, 0, 0, 1]);
      expect(plan.take(4).map((slot) => slot.layer), [
        LessonLayer.l1,
        LessonLayer.l2,
        LessonLayer.l3,
        LessonLayer.l1,
      ]);
    });

    test('StartFirstLessonUseCase abre shell e prioriza primeira aula', () {
      final service = StudentLearningStateService();
      final useCase = StartFirstLessonUseCase(service: service);
      final curriculum = _curriculum();
      final first = FirstCurriculumItem(
        curriculum: curriculum,
        item: curriculum.items.first,
        itemIndex: 0,
        marker: 'M1',
      );

      useCase.openShell(
        args: const StudentExperienceArgs(
          academic: 'fundamental',
          idioma: 'pt-BR',
          lessonLocalId: 'L1',
          onboarding: {'objetivo': 'frações'},
        ),
        first: first,
      );

      final state = service.read('L1');
      expect(state?.current?.marker, 'M1');
      expect(state?.progress?.itemIdx, 0);
      expect(
        readLiveEntryState(service, 'L1').status,
        LiveEntryStatus.showingFirstLesson,
      );
      expect(
        state?.events.map((event) => event.payload['event']),
        contains('firstLessonShellOpened'),
      );
    });

    test('LocalAdvanceEngine so permite avanco com evidencia local', () {
      final engine = const LocalAdvanceEngine();
      final position = LessonPositionState(
        itemIdx: 0,
        layer: LessonLayer.l1,
        erros: 0,
        historia: const [],
        history: const [],
        mainAdvances: 0,
        loadingLayer: LessonLayer.l1,
        conteudo: null,
        phase: const ClassroomPhase.reading(),
        imagem: null,
        teoriaPronta: false,
        items: const [PlannedItem(text: 'Item 1', marker: 'M1')],
      );
      final withoutEvidence = StudentLearningState.empty(lessonLocalId: 'L1');
      final withEvidence = withoutEvidence.copyWith(
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
      );

      expect(
        engine.hasEvidenceForCurrentPosition(withoutEvidence, position),
        isFalse,
      );
      expect(
        engine.hasEvidenceForCurrentPosition(withEvidence, position),
        isTrue,
      );
    });

    test('rotas protegidas passam pelo SimOrganismRouter oficial', () {
      const router = SimOrganismRouter();

      expect(
        router
            .resolve(
              path: '/cyber/aula',
              authed: false,
              hasLanguage: true,
              hasObjective: true,
            )
            .guard,
        SimOrganismRouteGuard.needsAuth,
      );
      expect(
        router
            .resolve(
              path: '/cyber/aula',
              authed: true,
              hasLanguage: false,
              hasObjective: true,
            )
            .guard,
        SimOrganismRouteGuard.needsLanguage,
      );
      expect(
        router
            .resolve(
              path: '/cyber/aula',
              authed: true,
              hasLanguage: true,
              hasObjective: false,
            )
            .guard,
        SimOrganismRouteGuard.needsObjective,
      );
      expect(
        router
            .resolve(
              path: '/cyber/aula',
              authed: true,
              hasLanguage: true,
              hasObjective: true,
            )
            .allowed,
        isTrue,
      );
      expect(
        router
            .resolve(
              path: '/cyber/warmup',
              authed: false,
              hasLanguage: true,
              hasObjective: true,
            )
            .guard,
        SimOrganismRouteGuard.needsAuth,
      );
      expect(
        router
            .resolve(
              path: '/cyber/warmup',
              authed: true,
              hasLanguage: false,
              hasObjective: true,
            )
            .guard,
        SimOrganismRouteGuard.needsLanguage,
      );
      expect(
        router
            .resolve(
              path: '/cyber/warmup',
              authed: true,
              hasLanguage: true,
              hasObjective: false,
            )
            .guard,
        SimOrganismRouteGuard.needsObjective,
      );
      expect(
        router
            .resolve(
              path: '/cyber/warmup',
              authed: true,
              hasLanguage: true,
              hasObjective: true,
            )
            .allowed,
        isTrue,
      );
    });
  });
}

CompleteLesson _lesson(String marker) {
  return CompleteLesson(
    conteudo: LessonContent(
      explanation: 'Explicacao $marker',
      question: 'Pergunta $marker?',
      options: const {
        AnswerLetter.A: 'A',
        AnswerLetter.B: 'B',
        AnswerLetter.C: 'C',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'Correto.',
      whyWrong: null,
    ),
    imagem: null,
    audioText: 'Explicacao $marker. Pergunta $marker?',
  );
}

StudentCurriculum _curriculum() {
  return const StudentCurriculum(
    topic: 'Frações',
    totalItems: 2,
    generatedAt: null,
    provisional: false,
    items: [
      CurriculumItem(marker: 'M1', text: 'Frações equivalentes'),
      CurriculumItem(marker: 'M2', text: 'Comparar frações'),
    ],
  );
}

LessonOrchestrator _orchestrator() {
  return LessonOrchestrator(
    t02Client: _FakeT02Client(),
    cache: LessonMaterialCache(),
    bus: LessonEventBus(),
  );
}

class _FakeT02Client implements T02LessonClient {
  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    return T02LessonMaterial(
      explanation: 'Explicacao ${request.marker}',
      question: 'Pergunta ${request.marker}?',
      options: const {
        AnswerLetter.A: 'A',
        AnswerLetter.B: 'B',
        AnswerLetter.C: 'C',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'Correto.',
      whyWrong: null,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'fake',
    );
  }

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) {
    return completeLesson(request);
  }

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) {
    return completeLesson(request);
  }

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) {
    return completeLesson(request);
  }
}
