import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_material_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_position_engine.dart';
import 'package:sim_mobile/sim/lesson/dopamine_ready_window_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/lesson/lesson_readiness_resolver.dart';
import 'package:sim_mobile/sim/lesson/student_lesson_material_service.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/live_entry_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

void main() {
  group('L4 runtime/renderizacao com locale textual', () {
    test(
      'carregarRapidoSePronto rejeita material visivel de idioma errado',
      () {
        final locale = _locale();
        final wrong = locale
            .copyWith(explanationLanguage: 'English')
            .normalized();
        final harness = _Harness(locale);
        harness.seedReadyMaterial(_material(wrong));

        final opened = harness.controller.carregarRapidoSePronto(
          lessonLocalId: 'lesson-l4',
          topic: 'English',
          position: harness.position,
          idioma: 'Portuguese',
          academic: 'base',
          mode: LessonMode.session,
          baseItems: harness.items,
        );

        expect(opened, isFalse);
        expect(harness.position.conteudo, isNull);
        expect(harness.position.phase.type, ClassroomPhaseType.carregando);
        final latest = harness.service.read('lesson-l4');
        expect(
          latest?.events.last.payload['status'],
          LessonReadinessStatus.staleLocale.name,
        );
      },
    );

    test('carregarRapidoSePronto renderiza material correto rapidamente', () {
      final locale = _locale();
      final harness = _Harness(locale);
      harness.seedReadyMaterial(_material(locale));

      final opened = harness.controller.carregarRapidoSePronto(
        lessonLocalId: 'lesson-l4',
        topic: 'English',
        position: harness.position,
        idioma: 'Portuguese',
        academic: 'base',
        mode: LessonMode.session,
        baseItems: harness.items,
      );

      expect(opened, isTrue);
      expect(harness.position.conteudo?.question, 'Pergunta M1?');
      expect(harness.position.phase.type, ClassroomPhaseType.lendo);
      expect(harness.position.teoriaPronta, isTrue);
      expect(
        harness.controller.lastAppliedMaterialSource,
        LessonMaterialSource.studentState,
      );
    });
  });
}

class _Harness {
  _Harness(this.localeContract) {
    service.write(
      StudentLearningState.empty(
        lessonLocalId: 'lesson-l4',
      ).copyWith(localeContract: localeContract),
    );
    final orchestrator = LessonOrchestrator(
      t02Client: _FakeT02Client(),
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
    );
    final readyWindow = DopamineReadyWindowEngine(
      service: service,
      orchestrator: orchestrator,
    );
    final materialService = StudentLessonMaterialService(
      stateService: service,
      orchestrator: orchestrator,
      readyWindowEngine: readyWindow,
    );
    controller = LessonMaterialController(
      stateService: service,
      materialService: materialService,
    );
  }

  final SimLocaleContract localeContract;
  final StudentLearningStateService service = StudentLearningStateService();
  late final LessonMaterialController controller;
  final List<PlannedItem> items = const [
    PlannedItem(marker: 'M1', text: 'Verb to be'),
  ];
  late final LessonPositionState position = LessonPositionState(
    itemIdx: 0,
    layer: LessonLayer.l1,
    erros: 0,
    historia: const [],
    history: const [],
    mainAdvances: 0,
    loadingLayer: LessonLayer.l1,
    conteudo: null,
    phase: const ClassroomPhase.loading(),
    imagem: null,
    teoriaPronta: false,
    items: items,
  );

  void seedReadyMaterial(JsonMap material) {
    service.mutate('lesson-l4', (state) {
      return state.copyWith(
        readyLessonMaterials: {
          preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): material,
        },
      );
    });
  }
}

JsonMap _material(SimLocaleContract locale) {
  return preparedMaterialFromLesson(
    lesson: CompleteLesson(
      conteudo: const LessonContent(
        explanation: 'Explicacao M1 em portugues.',
        question: 'Pergunta M1?',
        options: {
          AnswerLetter.A: 'I am',
          AnswerLetter.B: 'I was',
          AnswerLetter.C: 'I will',
        },
        correctAnswer: AnswerLetter.A,
        whyCorrect: 'Correto.',
      ),
      imagem: null,
      audioText: 'Explicacao M1 em portugues.',
      localeContract: locale,
    ),
    itemIdx: 0,
    marker: 'M1',
    layer: LessonLayer.l1,
  );
}

SimLocaleContract _locale() => SimLocaleContract.fromUserSelection(
  interfaceLocale: 'pt-BR',
  learningLocale: 'en',
  explanationLanguage: 'Portuguese',
  targetLanguage: 'English',
);

class _FakeT02Client implements T02LessonClient {
  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    throw StateError('server must not be called by classroom locale tests');
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
