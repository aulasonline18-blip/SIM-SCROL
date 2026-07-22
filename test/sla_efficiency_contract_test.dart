import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_answer_progress_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_hydration_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_material_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_position_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_session_engine.dart';
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

class _ThrowingT02Client implements T02LessonClient {
  int calls = 0;

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) {
    calls += 1;
    throw StateError('SLA hot path must not call T02/server');
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

class _BlockingT02Client implements T02LessonClient {
  int calls = 0;
  final firstCallStarted = Completer<void>();
  final release = Completer<void>();

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    calls += 1;
    if (!firstCallStarted.isCompleted) firstCallStarted.complete();
    await release.future;
    return T02LessonMaterial(
      explanation: 'Texto remoto ${request.marker}',
      question: 'Pergunta remota ${request.marker}?',
      options: const {
        AnswerLetter.A: 'A',
        AnswerLetter.B: 'B',
        AnswerLetter.C: 'C',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'A.',
      whyWrong: null,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'blocking-sla',
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

LessonRuntimeEngine _runtime(
  StudentLearningStateService stateService,
  T02LessonClient t02,
) {
  final orchestrator = LessonOrchestrator(
    t02Client: t02,
    cache: LessonMaterialCache(),
    bus: LessonEventBus(),
  );
  final readyWindow = DopamineReadyWindowEngine(
    service: stateService,
    orchestrator: orchestrator,
  );
  final materialService = StudentLessonMaterialService(
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
    ),
  );
}

StudentLearningState _state({
  String lessonLocalId = 'sla-lesson',
  Map<String, JsonMap>? readyLessonMaterials,
  JsonMap? currentLessonMaterial,
  LessonCurrent current = const LessonCurrent(
    itemIdx: 0,
    marker: 'M1',
    layer: LessonLayer.l1,
    amparoLvl: 0,
  ),
  LessonProgress progress = const LessonProgress(
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
}) {
  return StudentLearningState.empty(lessonLocalId: lessonLocalId).copyWith(
    profile: const StudentProfile(
      objetivo: 'Eficiência local',
      stableLang: 'pt-BR',
      nivel: 'base',
    ),
    curriculum: const StudentCurriculum(
      topic: 'Eficiência local',
      totalItems: 2,
      generatedAt: null,
      provisional: false,
      items: [
        CurriculumItem(marker: 'M1', text: 'Item 1'),
        CurriculumItem(marker: 'M2', text: 'Item 2'),
      ],
    ),
    current: current,
    progress: progress,
    currentLessonMaterial: currentLessonMaterial,
    readyLessonMaterials: readyLessonMaterials ?? const {},
  );
}

JsonMap _material({
  required int itemIdx,
  required String marker,
  required LessonLayer layer,
  String? image,
  String? audioText,
}) {
  return preparedMaterialFromLesson(
    lesson: CompleteLesson(
      conteudo: LessonContent(
        explanation: 'Texto preparado $marker L${layer.value}.',
        question: 'Pergunta preparada $marker L${layer.value}?',
        options: const {
          AnswerLetter.A: 'Alternativa A',
          AnswerLetter.B: 'Alternativa B',
          AnswerLetter.C: 'Alternativa C',
        },
        correctAnswer: AnswerLetter.A,
      ),
      imagem: image,
      audioText: audioText ?? '',
    ),
    itemIdx: itemIdx,
    marker: marker,
    layer: layer,
  );
}

Future<T> _measure<T>(
  FutureOr<T> Function() action, {
  required Duration below,
  required String reason,
}) async {
  final stopwatch = Stopwatch()..start();
  final result = await action();
  stopwatch.stop();
  expect(stopwatch.elapsed, lessThan(below), reason: reason);
  return result;
}

void main() {
  test('SLA-1 aula preparada abre localmente sem chamar servidor', () async {
    final material = _material(itemIdx: 0, marker: 'M1', layer: LessonLayer.l1);
    final service = StudentLearningStateService(
      seed: {
        'sla-lesson': _state(
          currentLessonMaterial: material,
          readyLessonMaterials: {
            preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): material,
          },
        ),
      },
    );
    final t02 = _ThrowingT02Client();
    final runtime = _runtime(service, t02);

    final snapshot = await _measure(
      () => runtime.open(lessonLocalId: 'sla-lesson'),
      below: const Duration(milliseconds: 500),
      reason: 'prepared classroom open must be local and comfortably <500ms',
    );

    expect(t02.calls, 0);
    expect(snapshot.phase.type, ClassroomPhaseType.lendo);
    expect(snapshot.conteudo?.question, 'Pergunta preparada M1 L1?');
    expect(snapshot.imagem, isNull);
  });

  test('SLA-2 cache miss retorna estado vivo sem aguardar T02', () async {
    final service = StudentLearningStateService(
      seed: {'sla-miss': _state(lessonLocalId: 'sla-miss')},
    );
    final t02 = _BlockingT02Client();
    final runtime = _runtime(service, t02);
    final before = service.read('sla-miss')!;

    final snapshot = await _measure(
      () => runtime.open(
        lessonLocalId: 'sla-miss',
        menuOpenPriority: true,
        suppressReadyWindowUntilVisibleLessonReady: true,
      ),
      below: const Duration(milliseconds: 500),
      reason: 'cache miss must return a living state without waiting T02',
    );

    expect(t02.calls, 1);
    expect(snapshot.phase.type, ClassroomPhaseType.avancoPendente);
    expect(snapshot.conteudo, isNull);
    final after = service.read('sla-miss')!;
    expect(after.current, before.current);
    expect(after.progress, before.progress);
    expect(after.queuedActions, isEmpty);
    expect(
      after.events.where(
        (event) => event.type == 'VISIBLE_REQUESTED_LESSON_WAITING',
      ),
      hasLength(1),
    );

    t02.release.complete();
    await t02.firstCallStarted.future;
  });

  test('SLA-3 avanço preparado é local e abaixo de 200ms', () async {
    final current = _material(itemIdx: 0, marker: 'M1', layer: LessonLayer.l1);
    final next = _material(itemIdx: 0, marker: 'M1', layer: LessonLayer.l3);
    final service = StudentLearningStateService(
      seed: {
        'sla-advance': _state(
          lessonLocalId: 'sla-advance',
          currentLessonMaterial: current,
          readyLessonMaterials: {
            preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): current,
            preparedLessonMaterialKey(0, 'M1', LessonLayer.l3): next,
          },
        ),
      },
    );
    final t02 = _ThrowingT02Client();
    final runtime = _runtime(service, t02);
    await runtime.open(lessonLocalId: 'sla-advance');

    runtime.select(AnswerLetter.A);
    await runtime.signal(DecisionSignal.one);

    await _measure(
      runtime.advance,
      below: const Duration(milliseconds: 200),
      reason: 'prepared next slot must advance locally and comfortably <200ms',
    );

    final snapshot = runtime.snapshot();
    expect(t02.calls, 0);
    expect(snapshot.phase.type, ClassroomPhaseType.lendo);
    expect(snapshot.conteudo?.question, 'Pergunta preparada M1 L3?');
  });

  test('SLA-5 resposta e feedback são locais e não chamam servidor', () async {
    final material = _material(itemIdx: 0, marker: 'M1', layer: LessonLayer.l1);
    final service = StudentLearningStateService(
      seed: {
        'sla-answer': _state(
          lessonLocalId: 'sla-answer',
          currentLessonMaterial: material,
          readyLessonMaterials: {
            preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): material,
          },
        ),
      },
    );
    final t02 = _ThrowingT02Client();
    final runtime = _runtime(service, t02);
    await runtime.open(lessonLocalId: 'sla-answer');

    runtime.select(AnswerLetter.A);
    await _measure(
      () => runtime.signal(DecisionSignal.one),
      below: const Duration(milliseconds: 500),
      reason: 'answer feedback must be observable without remote work',
    );

    final snapshot = runtime.snapshot();
    expect(t02.calls, 0);
    expect(snapshot.phase.type, ClassroomPhaseType.concluido);
    expect(snapshot.phase.signal, DecisionSignal.one);
    expect(snapshot.phase.wasCorrect, isTrue);
  });

  test(
    'SLA-4 texto válido vence loading e mídia ausente não bloqueia',
    () async {
      final textOnly = _material(
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l1,
        image: null,
        audioText: null,
      );
      final service = StudentLearningStateService(
        seed: {
          'sla-text': _state(
            lessonLocalId: 'sla-text',
            currentLessonMaterial: textOnly,
            readyLessonMaterials: {
              preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): textOnly,
            },
          ),
        },
      );
      final t02 = _ThrowingT02Client();
      final runtime = _runtime(service, t02);

      final snapshot = await runtime.open(lessonLocalId: 'sla-text');

      expect(t02.calls, 0);
      expect(snapshot.phase.type, ClassroomPhaseType.lendo);
      expect(snapshot.conteudo?.explanation, 'Texto preparado M1 L1.');
      expect(snapshot.conteudo?.options[AnswerLetter.A], isNotEmpty);
      expect(snapshot.imagem, isNull);
    },
  );

  test('SLA tests are local contracts and protected texts are not touched', () {
    final currentFile = File(
      'test/sla_efficiency_contract_test.dart',
    ).readAsStringSync();
    final imports = currentFile
        .split('\n')
        .where((line) => line.startsWith('import '))
        .join('\n');
    expect(
      imports,
      isNot(
        contains(
          'package:'
          'http',
        ),
      ),
    );
    expect(
      imports,
      isNot(
        contains(
          'Sim'
          'Http',
        ),
      ),
    );
    expect(
      imports,
      isNot(
        contains(
          'SimServer'
          'T02Client',
        ),
      ),
    );
    expect(
      currentFile,
      isNot(
        contains(
          'prompts'
          '/',
        ),
      ),
    );
    expect(
      currentFile,
      isNot(
        contains(
          'visual_router_'
          'n3.dart',
        ),
      ),
    );
  });
}
