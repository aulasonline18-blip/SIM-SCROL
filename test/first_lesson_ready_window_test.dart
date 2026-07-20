import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/sim/experience/student_experience_engine.dart';
import 'package:sim_mobile/sim/experience/student_experience_t00_adapter.dart';
import 'package:sim_mobile/sim/experience/student_experience_t02_adapter.dart';
import 'package:sim_mobile/sim/experience/student_experience_types.dart';
import 'package:sim_mobile/sim/classroom/lesson_answer_progress_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_hydration_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_session_engine.dart';
import 'package:sim_mobile/sim/lesson/dopamine_ready_window_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/lesson/ready_window_worker.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_material_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_position_engine.dart';
import 'package:sim_mobile/sim/lesson/student_lesson_material_service.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/live_entry_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

const _serverRasterDataUrl = 'data:image/png;base64,AAAA';

class FakeT02Client implements T02LessonClient {
  FakeT02Client({
    this.explanation,
    this.question,
    this.options,
    this.source = 'fake-t02',
    this.imageDataUrl,
    this.imageStatus,
  });

  final String? explanation;
  final String? question;
  final Map<AnswerLetter, String>? options;
  final String source;
  final String? imageDataUrl;
  final String? imageStatus;
  int calls = 0;
  final requests = <T02LessonRequest>[];

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    calls += 1;
    requests.add(request);
    return T02LessonMaterial(
      explanation: explanation ?? 'Explicacao de ${request.item}',
      question: question ?? 'Pergunta?',
      options:
          options ??
          const {
            AnswerLetter.A: 'A certa',
            AnswerLetter.B: 'B errada',
            AnswerLetter.C: 'C errada',
          },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'Porque sim.',
      whyWrong: null,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: source,
      imageDataUrl: imageDataUrl,
      imageStatus: imageStatus,
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

class FailingT02Client implements T02LessonClient {
  FailingT02Client([this.error = 'offline']);

  final String error;
  int calls = 0;

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) {
    calls += 1;
    throw StateError(error);
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

class BlockingT02Client implements T02LessonClient {
  BlockingT02Client();

  final firstCallStarted = Completer<void>();
  final release = Completer<void>();
  int calls = 0;
  final requests = <T02LessonRequest>[];

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    calls += 1;
    requests.add(request);
    if (!firstCallStarted.isCompleted) firstCallStarted.complete();
    await release.future;
    return T02LessonMaterial(
      explanation: 'Explicacao bloqueada de ${request.item}',
      question: 'Pergunta bloqueada?',
      options: const {
        AnswerLetter.A: 'A certa',
        AnswerLetter.B: 'B errada',
        AnswerLetter.C: 'C errada',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'Porque sim.',
      whyWrong: null,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'blocking-t02',
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

class SequenceT02Client implements T02LessonClient {
  SequenceT02Client(this.materials);

  final List<T02LessonMaterial> materials;
  int calls = 0;
  final requests = <T02LessonRequest>[];

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    requests.add(request);
    final index = calls.clamp(0, materials.length - 1);
    calls += 1;
    return materials[index];
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

class AuditT00Client implements T00BootstrapClient {
  AuditT00Client({required this.releaseFinal});

  final Completer<void> releaseFinal;
  final requests = <T00BootstrapRequest>[];

  @override
  Stream<T00BootstrapChunk> runBootstrap(T00BootstrapRequest request) async* {
    requests.add(request);
    yield const T00BootstrapChunk(
      type: 't00_item_partial',
      payload: {
        'item': {
          'order': 1,
          'marker': 'M1',
          'title': 'Frações',
          'microitem_for_teacher': 'Entender metade e um quarto',
        },
      },
    );
    await releaseFinal.future;
    yield const T00BootstrapChunk(
      type: 't00_final',
      payload: {
        'curriculum': [
          {
            'order': 1,
            'marker': 'M1',
            'title': 'Frações',
            'microitem_for_teacher': 'Entender metade e um quarto',
          },
        ],
      },
    );
  }
}

class GiantCurriculumT00Client implements T00BootstrapClient {
  GiantCurriculumT00Client({required this.releaseFinal});

  final Completer<void> releaseFinal;
  final requests = <T00BootstrapRequest>[];

  @override
  Stream<T00BootstrapChunk> runBootstrap(T00BootstrapRequest request) async* {
    requests.add(request);
    yield const T00BootstrapChunk(
      type: 't00_item_partial',
      payload: {
        'item': {
          'order': 1,
          'marker': 'M1',
          'title': 'Frações',
          'microitem_for_teacher': 'Entender metade rapidamente',
        },
      },
    );
    await releaseFinal.future;
    yield T00BootstrapChunk(
      type: 't00_final',
      payload: {
        'curriculum': [
          for (var i = 1; i <= 2500; i++)
            {
              'order': i,
              'marker': 'M$i',
              'title': 'Item $i',
              'microitem_for_teacher': 'Microitem $i',
            },
        ],
      },
    );
  }
}

class BlockingHydrateCache extends LessonMaterialCache {
  BlockingHydrateCache({required this.releaseHydrate});

  final Completer<void> releaseHydrate;
  bool hydrateStarted = false;

  @override
  Future<LessonMaterialCacheAudit> hydrate() async {
    hydrateStarted = true;
    await releaseHydrate.future;
    return const LessonMaterialCacheAudit(ok: true, code: 'TEST_RELEASED');
  }
}

class FastStartT02Client implements T02LessonClient {
  final requests = <T02LessonRequest>[];

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    requests.add(request);
    return T02LessonMaterial(
      explanation: 'Primeiro texto essencial.',
      question: 'Qual alternativa representa metade?',
      options: const {
        AnswerLetter.A: '1/2',
        AnswerLetter.B: '1/3',
        AnswerLetter.C: '1/4',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: '1/2 e metade.',
      whyWrong: const {'B': 'menor que metade', 'C': 'um quarto'},
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'fast-start-t02',
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

class AuditT02Client implements T02LessonClient {
  final requests = <T02LessonRequest>[];
  final l2 = Completer<T02LessonMaterial>();
  final l3 = Completer<T02LessonMaterial>();

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) {
    requests.add(request);
    return switch (request.layer) {
      LessonLayer.l1 => Future.value(_material(request)),
      LessonLayer.l2 => l2.future,
      LessonLayer.l3 => l3.future,
    };
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

  T02LessonMaterial _material(T02LessonRequest request) => T02LessonMaterial(
    explanation: 'Explicacao ${request.layer.name}',
    question: 'Pergunta ${request.layer.name}?',
    options: const {
      AnswerLetter.A: 'A certa',
      AnswerLetter.B: 'B errada',
      AnswerLetter.C: 'C errada',
    },
    correctAnswer: AnswerLetter.A,
    whyCorrect: 'Porque sim.',
    whyWrong: const {'B': 'nao', 'C': 'nao'},
    generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
    source: 'audit-t02',
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

class SlowFirstT02Client implements T02LessonClient {
  final requests = <T02LessonRequest>[];
  final firstLesson = Completer<T02LessonMaterial>();

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) {
    requests.add(request);
    if (request.layer == LessonLayer.l1) return firstLesson.future;
    return Future.value(_material(request));
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

  T02LessonMaterial _material(T02LessonRequest request) => T02LessonMaterial(
    explanation: 'Explicacao ${request.item}',
    question: 'Pergunta inicial?',
    options: const {
      AnswerLetter.A: 'A certa',
      AnswerLetter.B: 'B errada',
      AnswerLetter.C: 'C errada',
    },
    correctAnswer: AnswerLetter.A,
    whyCorrect: 'Porque sim.',
    whyWrong: const {'B': 'nao', 'C': 'nao'},
    generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
    source: 'slow-first-t02',
  );
}

class BlockingVisualRefreshT02Client implements T02LessonClient {
  final requests = <T02LessonRequest>[];
  final visualRefresh = Completer<T02LessonMaterial>();

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) {
    requests.add(request);
    if (request.marker == 'M1' && request.layer == LessonLayer.l1) {
      return visualRefresh.future;
    }
    return Future.value(material(request));
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

  T02LessonMaterial material(T02LessonRequest request) => T02LessonMaterial(
    explanation: 'Explicacao ${request.marker}/${request.layer.name}',
    question: 'Pergunta ${request.marker}/${request.layer.name}?',
    options: const {
      AnswerLetter.A: 'A certa',
      AnswerLetter.B: 'B errada',
      AnswerLetter.C: 'C errada',
    },
    correctAnswer: AnswerLetter.A,
    whyCorrect: 'Porque sim.',
    whyWrong: const {'B': 'nao', 'C': 'nao'},
    generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
    source: 'blocking-visual-refresh-t02',
    imageStatus: 'failed',
    imageError: 'HTTP 500 stack trace tecnico',
  );
}

class BackgroundGateT02Client implements T02LessonClient {
  final requests = <T02LessonRequest>[];
  final backgroundStarted = Completer<void>();
  final releaseBackground = Completer<void>();

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    requests.add(request);
    if (request.layer == LessonLayer.l1) {
      if (!backgroundStarted.isCompleted) backgroundStarted.complete();
      await releaseBackground.future;
    }
    return T02LessonMaterial(
      explanation: 'Explicacao ${request.marker}/${request.layer.name}',
      question: 'Pergunta ${request.marker}/${request.layer.name}?',
      options: const {
        AnswerLetter.A: 'A certa',
        AnswerLetter.B: 'B errada',
        AnswerLetter.C: 'C errada',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'Porque sim.',
      whyWrong: const {'B': 'nao', 'C': 'nao'},
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'background-gate-t02',
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

StudentLearningState _stateWithCurriculum() {
  const items = [
    CurriculumItem(marker: 'M1', text: 'Item 1'),
    CurriculumItem(marker: 'M2', text: 'Item 2'),
  ];
  return StudentLearningState.empty(lessonLocalId: 'cyber-ready').copyWith(
    profile: const StudentProfile(
      objetivo: 'Objetivo',
      stableLang: 'pt',
      academicLevel: 'fundamental',
    ),
    curriculum: const StudentCurriculum(
      topic: 'Objetivo',
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

StudentLearningState _stateWithFiveItems() {
  final items = List<CurriculumItem>.generate(
    5,
    (index) =>
        CurriculumItem(marker: 'M${index + 1}', text: 'Item ${index + 1}'),
  );
  return StudentLearningState.empty(
    lessonLocalId: 'cyber-offline-warm',
  ).copyWith(
    profile: const StudentProfile(
      objetivo: 'Objetivo offline',
      stableLang: 'pt',
      academicLevel: 'fundamental',
    ),
    curriculum: StudentCurriculum(
      topic: 'Objetivo offline',
      totalItems: 5,
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
      totalItems: 5,
      pctAvanco: 0,
    ),
  );
}

void main() {
  test('M7 app code does not call legacy server-classroom slot route', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('/api/server-classroom/slot') ||
          source.contains('server-classroom/slot')) {
        offenders.add(entity.path);
      }
    }

    expect(offenders, isEmpty);
  });

  test('LessonMaterialCache keeps only three living lessons', () {
    final cache = LessonMaterialCache(maxLessons: 3);
    for (var i = 0; i < 4; i++) {
      cache.put(
        'k$i',
        CompleteLesson(
          conteudo: LessonContent(
            explanation: 'E$i',
            question: 'Q',
            options: const {
              AnswerLetter.A: 'A',
              AnswerLetter.B: 'B',
              AnswerLetter.C: 'C',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: null,
          audioText: 'E$i. Q',
        ),
      );
    }

    expect(cache.peek('k0'), isNull);
    expect(cache.peek('k1'), isNotNull);
    expect(cache.peek('k3'), isNotNull);
  });

  test(
    'M-EXP3: warm cache limits to 15 and preserves hot ready window keys',
    () {
      final cache = LessonMaterialCache();
      final hotKeys = ['k2', 'k3', 'k4', 'k5'];
      for (var i = 0; i < 20; i++) {
        final key = 'k$i';
        cache.put(
          key,
          CompleteLesson(
            conteudo: LessonContent(
              explanation: 'Exp $i',
              question: 'Pergunta $i?',
              options: const {
                AnswerLetter.A: 'A',
                AnswerLetter.B: 'B',
                AnswerLetter.C: 'C',
              },
              correctAnswer: AnswerLetter.A,
            ),
            imagem: 'data:image/png;base64,$i',
            audioText: 'Exp $i. Pergunta $i?',
          ),
        );
        if (i == 9) {
          cache.trimWarmCache(protectedKeys: hotKeys);
        }
      }

      cache.trimWarmCache(protectedKeys: hotKeys);

      expect(cache.warmEntryCount, lessThanOrEqualTo(15));
      for (final key in hotKeys) {
        expect(cache.peek(key), isNotNull, reason: key);
      }
      expect(
        cache.warmKeys
            .where((key) => !hotKeys.contains(key))
            .map((key) => cache.peek(key)?.imagem)
            .whereType<String>(),
        isEmpty,
      );
    },
  );

  test(
    'M7 warm offline cache keeps 15 experiences without reducing hot window',
    () {
      final cache = LessonMaterialCache();
      final hotKeys = <String>{'k0', 'k1', 'k2', 'k3'};
      for (var i = 0; i < 15; i++) {
        cache.put(
          'k$i',
          CompleteLesson(
            conteudo: LessonContent(
              explanation: 'Exp $i',
              question: 'Pergunta $i?',
              options: const {
                AnswerLetter.A: 'A',
                AnswerLetter.B: 'B',
                AnswerLetter.C: 'C',
              },
              correctAnswer: AnswerLetter.A,
            ),
            imagem: null,
            audioText: 'Exp $i. Pergunta $i?',
          ),
        );
      }
      cache.protectWarmKeys(hotKeys);

      expect(cache.warmEntryCount, 15);
      for (final key in hotKeys) {
        expect(cache.peek(key), isNotNull, reason: key);
      }
    },
  );

  test(
    'M7 background ready window fills warm cache without expanding hot state window',
    () async {
      final service = StudentLearningStateService(
        seed: {'cyber-offline-warm': _stateWithFiveItems()},
      );
      final t02 = FakeT02Client();
      final cache = LessonMaterialCache();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: cache,
        bus: LessonEventBus(),
      );
      final engine = DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      );

      final result = await engine.runDopamineReadyWindowFromStudentState(
        lessonLocalId: 'cyber-offline-warm',
        source: 'm7-offline-warm-test',
        maxSlots: 15,
        itemIdx: 0,
        layer: LessonLayer.l1,
        marker: 'M1',
        topic: 'Objetivo offline',
      );

      expect(result, hasLength(15));
      expect(result.every((ready) => ready), isTrue);
      expect(cache.warmEntryCount, 15);
      expect(
        service.read('cyber-offline-warm')?.readyLessonMaterials,
        hasLength(localLessonTraySize),
      );
      expect(t02.calls, 15);
    },
  );

  test('M7 slow warm fill does not block hot fifteen-slot window', () async {
    final service = StudentLearningStateService(
      seed: {'cyber-offline-warm': _stateWithFiveItems()},
    );
    final cache = LessonMaterialCache();
    final seedT02 = FakeT02Client();
    final seedOrchestrator = LessonOrchestrator(
      t02Client: seedT02,
      cache: cache,
      bus: LessonEventBus(),
    );
    final seedEngine = DopamineReadyWindowEngine(
      service: service,
      orchestrator: seedOrchestrator,
    );
    final seedHot = await seedEngine.runDopamineReadyWindowFromStudentState(
      lessonLocalId: 'cyber-offline-warm',
      source: 'm7-hot-seed',
      maxSlots: localLessonTraySize,
      itemIdx: 0,
      layer: LessonLayer.l1,
      marker: 'M1',
      topic: 'Objetivo offline',
    );
    expect(seedHot, hasLength(localLessonTraySize));
    expect(seedHot.every((ready) => ready), isTrue);
    expect(seedT02.calls, localLessonTraySize);
    expect(cache.warmEntryCount, localLessonTraySize);
    expect(
      service.read('cyber-offline-warm')?.readyLessonMaterials,
      hasLength(localLessonTraySize),
    );

    final t02 = BlockingT02Client();
    final orchestrator = LessonOrchestrator(
      t02Client: t02,
      cache: cache,
      bus: LessonEventBus(),
    );
    final engine = DopamineReadyWindowEngine(
      service: service,
      orchestrator: orchestrator,
    );

    final warm = engine.runDopamineReadyWindowFromStudentState(
      lessonLocalId: 'cyber-offline-warm',
      source: 'm7-warm-slow',
      maxSlots: 15,
      itemIdx: 0,
      layer: LessonLayer.l1,
      marker: 'M1',
      topic: 'Objetivo offline',
    );
    await t02.firstCallStarted.future;

    final hot = await engine
        .runDopamineReadyWindowFromStudentState(
          lessonLocalId: 'cyber-offline-warm',
          source: 'm7-hot-after-warm',
          maxSlots: localLessonTraySize,
          itemIdx: 0,
          layer: LessonLayer.l1,
          marker: 'M1',
          topic: 'Objetivo offline',
        )
        .timeout(const Duration(milliseconds: 200));

    expect(hot, hasLength(localLessonTraySize));
    expect(hot.every((ready) => ready), isTrue);
    expect(
      service.read('cyber-offline-warm')?.readyLessonMaterials,
      hasLength(localLessonTraySize),
    );
    expect(t02.calls, greaterThan(0));
    expect(t02.calls, lessThanOrEqualTo(localLessonTraySize));

    t02.release.complete();
    final warmResult = await warm;
    expect(warmResult, hasLength(15));
    expect(cache.warmEntryCount, 15);
  });

  test('M7 worker active hot job does not wait for running warm job', () async {
    final service = StudentLearningStateService(
      seed: {
        'cyber-worker':
            StudentLearningState.empty(lessonLocalId: 'cyber-worker').copyWith(
              queuedActions: [
                {
                  'job_id': 'warm-job',
                  'type': 'PREPARE_READY_WINDOW',
                  'status': 'queued',
                  'idempotency_key': 'warm',
                  'priority': 'background',
                  'source': 'warm-offline-cache',
                  'payload': {
                    'maxSlots': 15,
                    'itemIdx': 0,
                    'layer': LessonLayer.l1.value,
                    'marker': 'M1',
                  },
                  'created_at': 1,
                  'started_at': null,
                  'finished_at': null,
                  'error': null,
                  'attempts': 0,
                  'max_attempts': null,
                  'next_retry_at': null,
                },
              ],
            ),
      },
    );
    final warmStarted = Completer<void>();
    final releaseWarm = Completer<void>();
    final processed = <String>[];
    final worker = ReadyWindowWorker(
      service: service,
      processor:
          ({
            required lessonLocalId,
            required source,
            maxSlots,
            returnMode = false,
            itemIdx,
            layer,
            marker,
            topic,
          }) async {
            processed.add('$source:$maxSlots');
            if (source.contains('warm-offline-cache')) {
              if (!warmStarted.isCompleted) warmStarted.complete();
              await releaseWarm.future;
            }
            return List<bool>.filled(maxSlots ?? localLessonTraySize, true);
          },
    );

    final warm = worker.drainReadyWindowJobs('cyber-worker');
    await warmStarted.future;

    service.mutate('cyber-worker', (state) {
      return state.copyWith(
        queuedActions: [
          ...state.queuedActions,
          {
            'job_id': 'hot-job',
            'type': 'PREPARE_READY_WINDOW',
            'status': 'queued',
            'idempotency_key': 'hot',
            'priority': 'hot-local',
            'source': 'hot-visible-window',
            'payload': {
              'maxSlots': localLessonTraySize,
              'itemIdx': 0,
              'layer': LessonLayer.l1.value,
              'marker': 'M1',
            },
            'created_at': 2,
            'started_at': null,
            'finished_at': null,
            'error': null,
            'attempts': 0,
            'max_attempts': null,
            'next_retry_at': null,
          },
        ],
      );
    });

    final hot = await worker
        .drainReadyWindowJobs('cyber-worker')
        .timeout(const Duration(milliseconds: 200));

    expect(hot, hasLength(localLessonTraySize));
    expect(processed, contains('job:warm-offline-cache:15'));
    expect(processed, contains('job:hot-visible-window:$localLessonTraySize'));
    expect(
      service
          .read('cyber-worker')!
          .queuedActions
          .firstWhere((job) => job['job_id'] == 'hot-job')['status'],
      'done',
    );

    releaseWarm.complete();
    await warm;
  });

  test('M7 warm cache expires by lastAccessedAt after seven days', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final eightDaysAgo = now - const Duration(days: 8).inMilliseconds;
    final sixDaysAgo = now - const Duration(days: 6).inMilliseconds;
    Map<String, Object?> lessonJson(String text) => {
      'savedAt': eightDaysAgo,
      'lastAccessedAt': text == 'fresh' ? sixDaysAgo : eightDaysAgo,
      'lesson': {
        'conteudo': {
          'explanation': 'Exp $text',
          'question': 'Pergunta $text?',
          'options': {'A': 'A', 'B': 'B', 'C': 'C'},
          'correct_answer': 'A',
        },
        'audioText': 'Exp $text. Pergunta $text?',
      },
    };
    SharedPreferences.setMockInitialValues({
      'sim-lesson-text-cache-v1': jsonEncode({
        'version': 2,
        'warm': {'fresh': lessonJson('fresh'), 'expired': lessonJson('old')},
        'cold': const {},
      }),
    });

    final cache = LessonMaterialCache();
    await cache.hydrate();

    expect(cache.peek('fresh')?.conteudo.question, 'Pergunta fresh?');
    expect(cache.peek('expired'), isNull);
    expect(cache.coldEntry('expired'), isNotNull);
  });

  test(
    'M-EXP3-B: expired warm experience demotes to cold index without heavy media',
    () async {
      final cache = LessonMaterialCache(ttlMs: 1);
      const params = CompleteLessonParams(
        lessonLocalId: 'lesson-cold',
        item: 'Item frio',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
        itemIdx: 0,
        curriculumItems: [
          {
            'marker': 'M1',
            'text': 'Item frio',
            'rootLessonLocalId': 'lesson-cold',
            'partNumber': 1,
            'globalItemNumber': 1,
            'localItemIndex': 0,
          },
        ],
      );
      final key = lessonKeyFor(params);
      cache.putForParams(
        params,
        const CompleteLesson(
          conteudo: LessonContent(
            explanation: 'Texto que pode esfriar.',
            question: 'Pergunta fria?',
            options: {
              AnswerLetter.A: 'A',
              AnswerLetter.B: 'B',
              AnswerLetter.C: 'C',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: 'data:image/png;base64,PESADA',
          audioText: 'Texto que pode esfriar. Pergunta fria?',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 5));
      cache.trimWarmCache();

      expect(cache.peek(key), isNull);
      final cold = cache.coldEntry(key);
      expect(cold, isNotNull);
      expect(cold!.lessonKey, key);
      expect(cold.lessonLocalId, 'lesson-cold');
      expect(cold.marker, 'M1');
      expect(cold.layer, LessonLayer.l1);
      expect(cold.status, 'cold-index');
      expect(cold.toJson().containsKey('imagem'), isFalse);
      expect(cold.toJson().containsKey('audio'), isFalse);
    },
  );

  test(
    'M-EXP3-B: autolimpeza preserves strong state progress events and hot window',
    () {
      final strongState = _stateWithCurriculum().copyWith(
        lessonLocalId: 'lesson-clean-state',
        events: const [
          StudentLearningEvent(type: 'ANSWER_RECORDED', ts: 1, payload: {}),
        ],
        progress: const LessonProgress(
          itemIdx: 0,
          layer: LessonLayer.l1,
          erros: 0,
          amparoLvl: 0,
          historia: ['tentativa'],
          mainAdvances: 1,
          concluidos: ['M0'],
          pendentesMarkers: [],
          totalItems: 2,
          pctAvanco: 50,
        ),
      );
      final cache = LessonMaterialCache(maxLessons: 2);
      final hot = <String>[];
      for (var i = 0; i < 4; i++) {
        final params = CompleteLessonParams(
          lessonLocalId: 'lesson-clean-state',
          item: 'Item $i',
          lang: 'pt-BR',
          academic: 'fundamental',
          layer: LessonLayer.l1,
          mode: LessonMode.session,
          marker: 'M$i',
          itemIdx: i,
          curriculumItems: [
            {
              'marker': 'M$i',
              'text': 'Item $i',
              'rootLessonLocalId': 'lesson-clean-state',
              'partNumber': 1,
              'globalItemNumber': i + 1,
              'localItemIndex': i,
            },
          ],
        );
        final key = lessonKeyFor(params);
        if (i >= 2) hot.add(key);
        cache.putForParams(
          params,
          CompleteLesson(
            conteudo: LessonContent(
              explanation: 'Texto $i',
              question: 'Pergunta $i?',
              options: const {
                AnswerLetter.A: 'A',
                AnswerLetter.B: 'B',
                AnswerLetter.C: 'C',
              },
              correctAnswer: AnswerLetter.A,
            ),
            imagem: 'data:image/png;base64,$i',
            audioText: 'Texto $i. Pergunta $i?',
          ),
        );
      }

      cache.trimWarmCache(protectedKeys: hot, maxWarmLessons: 2);

      expect(cache.warmEntryCount, 2);
      for (final key in hot) {
        expect(cache.peek(key), isNotNull);
      }
      expect(strongState.progress?.mainAdvances, 1);
      expect(strongState.events.single.type, 'ANSWER_RECORDED');
      expect(strongState.progress?.historia, ['tentativa']);
    },
  );

  test(
    'M-EXP3: prepared local material reopens without unnecessary T02 call',
    () async {
      const params = CompleteLessonParams(
        lessonLocalId: 'cyber-resume-local',
        item: 'Item 1',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
      );
      final prepared = preparedMaterialFromLesson(
        lesson: const CompleteLesson(
          conteudo: LessonContent(
            explanation: 'Texto retomado local.',
            question: 'Qual alternativa abre?',
            options: {
              AnswerLetter.A: 'A local',
              AnswerLetter.B: 'B local',
              AnswerLetter.C: 'C local',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: null,
          audioText: 'Texto retomado local. Qual alternativa abre?',
        ),
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l1,
      );
      final service = StudentLearningStateService(
        seed: {
          'cyber-resume-local': _stateWithCurriculum().copyWith(
            lessonLocalId: 'cyber-resume-local',
            current: const LessonCurrent(
              itemIdx: 0,
              marker: 'M1',
              layer: LessonLayer.l1,
              amparoLvl: 0,
            ),
            readyLessonMaterials: {
              preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): prepared,
            },
          ),
        },
      );
      final t02 = FakeT02Client();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
      );
      final materialService = StudentLessonMaterialService(
        stateService: service,
        orchestrator: orchestrator,
        readyWindowEngine: DopamineReadyWindowEngine(
          service: service,
          orchestrator: orchestrator,
        ),
      );

      final result = await materialService
          .resolveLessonMaterialFromStateOrEngine(
            ResolveLessonMaterialInput(
              lessonLocalId: 'cyber-resume-local',
              topic: 'Objetivo',
              itemIdx: 0,
              marker: 'M1',
              layer: LessonLayer.l1,
              params: params,
            ),
          );

      expect(result?.conteudo.question, 'Qual alternativa abre?');
      expect(result?.source, LessonMaterialSource.studentState);
      expect(t02.calls, 0);
    },
  );

  test('M-EXP3: offline prepared lesson opens with text and A/B/C', () async {
    const params = CompleteLessonParams(
      lessonLocalId: 'cyber-offline-ready',
      item: 'Item 1',
      lang: 'pt-BR',
      academic: 'fundamental',
      layer: LessonLayer.l1,
      mode: LessonMode.session,
      marker: 'M1',
    );
    final cache = LessonMaterialCache();
    cache.put(
      lessonKeyFor(params),
      const CompleteLesson(
        conteudo: LessonContent(
          explanation: 'Texto offline preparado.',
          question: 'O que abre sem internet?',
          options: {
            AnswerLetter.A: 'Texto',
            AnswerLetter.B: 'Nada',
            AnswerLetter.C: 'Erro tecnico',
          },
          correctAnswer: AnswerLetter.A,
        ),
        imagem: null,
        audioText: 'Texto offline preparado. O que abre sem internet?',
      ),
    );
    final service = StudentLearningStateService(
      seed: {
        'cyber-offline-ready': _stateWithCurriculum().copyWith(
          lessonLocalId: 'cyber-offline-ready',
        ),
      },
    );
    final t02 = FailingT02Client();
    final orchestrator = LessonOrchestrator(
      t02Client: t02,
      cache: cache,
      bus: LessonEventBus(),
    );
    final materialService = StudentLessonMaterialService(
      stateService: service,
      orchestrator: orchestrator,
      readyWindowEngine: DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      ),
    );

    final result = await materialService.resolveLessonMaterialFromStateOrEngine(
      ResolveLessonMaterialInput(
        lessonLocalId: 'cyber-offline-ready',
        topic: 'Objetivo',
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l1,
        params: params,
        allowRemoteOrder: true,
      ),
    );

    expect(result?.conteudo.explanation, 'Texto offline preparado.');
    expect(result?.conteudo.options.keys, containsAll(AnswerLetter.values));
    expect(result?.source, LessonMaterialSource.memoryCacheFromMotor);
    expect(t02.calls, 0);
  });

  test(
    'resolveLessonMaterialFromStateOrEngine applies waitAfterOrderMs as active wait limit',
    () async {
      const params = CompleteLessonParams(
        lessonLocalId: 'cyber-wait-contract',
        item: 'Item 1',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
      );
      final service = StudentLearningStateService(
        seed: {
          'cyber-wait-contract': _stateWithCurriculum().copyWith(
            lessonLocalId: 'cyber-wait-contract',
          ),
        },
      );
      final t02 = BlockingT02Client();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
      );
      final materialService = StudentLessonMaterialService(
        stateService: service,
        orchestrator: orchestrator,
        readyWindowEngine: DopamineReadyWindowEngine(
          service: service,
          orchestrator: orchestrator,
        ),
      );

      final startedAt = DateTime.now();
      final result = await materialService
          .resolveLessonMaterialFromStateOrEngine(
            ResolveLessonMaterialInput(
              lessonLocalId: 'cyber-wait-contract',
              topic: 'Objetivo',
              itemIdx: 0,
              marker: 'M1',
              layer: LessonLayer.l1,
              params: params,
              waitBeforeOrderMs: 0,
              waitAfterOrderMs: 5,
              allowRemoteOrder: true,
            ),
          );

      expect(result, isNull);
      expect(t02.calls, 1);
      expect(
        DateTime.now().difference(startedAt).inMilliseconds,
        lessThan(500),
      );
      final waitEvents = service
          .read('cyber-wait-contract')!
          .events
          .where((event) => event.type == 'LESSON_MATERIAL_WAIT_APPLIED')
          .toList();
      expect(waitEvents, hasLength(1));
      expect(waitEvents.single.payload['stage'], 'after_order_timeout');
      expect(waitEvents.single.payload['waitAfterOrderMs'], 5);
      expect(waitEvents.single.payload['resolved'], isFalse);
    },
  );

  test(
    'LessonOrchestrator stores image only when T02 returns ready image data',
    () async {
      final cache = LessonMaterialCache();
      final bus = LessonEventBus();
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(imageDataUrl: _serverRasterDataUrl),
        cache: cache,
        bus: bus,
      );
      const params = CompleteLessonParams(
        lessonLocalId: 'cyber-visual',
        item: 'Plano cartesiano',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
      );
      final key = lessonKeyFor(params);
      final updates = <CompleteLesson>[];
      final unsubscribe = bus.subscribe(key, updates.add);
      addTearDown(unsubscribe);

      final textLesson = await orchestrator.prefetchCompleteLesson(
        params,
        priority: 'hot-local',
      );
      await Future<void>.delayed(Duration.zero);

      expect(textLesson.imagem, _serverRasterDataUrl);
      expect(updates.first.imagem, _serverRasterDataUrl);
      final rendered = updates.last.imagem;
      expect(rendered, _serverRasterDataUrl);
    },
  );

  test(
    'LessonOrchestrator uses server raster before any app paid offer',
    () async {
      final cache = LessonMaterialCache();
      final bus = LessonEventBus();
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(
          imageDataUrl: _serverRasterDataUrl,
          explanation:
              'Uma função quadrática é uma função do segundo grau, '
              'com forma geral f(x)=ax²+bx+c. O gráfico é uma parábola.',
          question:
              'Observe a função f(x)=2x²-3x+1. Quais são os coeficientes a, b e c?',
          options: const {
            AnswerLetter.A: 'a=2, b=-3, c=1',
            AnswerLetter.B: 'a=5, b=4, c=0',
            AnswerLetter.C: 'a=1, b=2, c=-7',
          },
        ),
        cache: cache,
        bus: bus,
      );
      const params = CompleteLessonParams(
        lessonLocalId: 'cyber-poor-trigger-quadratic',
        item: 'Função quadrática',
        lang: 'pt-BR',
        academic: 'ensino médio',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
      );
      final key = lessonKeyFor(params);
      final updates = <CompleteLesson>[];
      final unsubscribeLesson = bus.subscribe(key, updates.add);
      addTearDown(unsubscribeLesson);

      await orchestrator.prefetchCompleteLesson(params, priority: 'hot-local');
      await Future<void>.delayed(Duration.zero);

      final rendered = updates.last.imagem;
      expect(rendered, _serverRasterDataUrl);
      expect(cache.peek(key)?.imagem, rendered);
    },
  );

  test(
    'LessonOrchestrator stores ready server raster for h(t) material',
    () async {
      final cache = LessonMaterialCache();
      final bus = LessonEventBus();
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(
          imageDataUrl: _serverRasterDataUrl,
          explanation:
              'Ao substituir t por zero na função, a altura inicial aparece '
              'no termo constante. Isso conecta a fórmula ao ponto inicial '
              'do gráfico no eixo vertical.',
          question:
              'A altura (h) de uma bola lançada para cima, em metros, é '
              'descrita pela função h(t) = -2t^2 + 8t + 10, onde t é o '
              'tempo em segundos. Qual é a altura inicial da bola no momento '
              'do lançamento (t = 0)?',
          options: const {
            AnswerLetter.A: '10 metros',
            AnswerLetter.B: '8 metros',
            AnswerLetter.C: '2 metros',
          },
        ),
        cache: cache,
        bus: bus,
      );
      const params = CompleteLessonParams(
        lessonLocalId: 'cyber-ht-physics-graph',
        item: 'Item 5',
        lang: 'pt-BR',
        academic: 'ensino médio',
        layer: LessonLayer.l3,
        mode: LessonMode.session,
        marker: 'M5',
      );
      final key = lessonKeyFor(params);
      final updates = <CompleteLesson>[];
      final unsubscribeLesson = bus.subscribe(key, updates.add);
      addTearDown(unsubscribeLesson);

      await orchestrator.prefetchCompleteLesson(params, priority: 'hot-local');
      await Future<void>.delayed(Duration.zero);

      final rendered = updates.last.imagem;
      expect(rendered, _serverRasterDataUrl);
      expect(cache.peek(key)?.imagem, rendered);
    },
  );

  test(
    'LessonOrchestrator ignores stale image decision after lesson content refresh',
    () async {
      const params = CompleteLessonParams(
        lessonLocalId: 'cyber-stale-image-decision',
        item: 'Função quadrática',
        lang: 'pt-BR',
        academic: 'ensino médio',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M5',
      );
      final key = lessonKeyFor(params);
      final cache = LessonMaterialCache();
      cache.put(
        key,
        CompleteLesson(
          conteudo: LessonContent(
            explanation: 'material antigo sem contexto suficiente',
            question: 'Pergunta antiga',
            options: const {
              AnswerLetter.A: 'A',
              AnswerLetter.B: 'B',
              AnswerLetter.C: 'C',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: null,
          audioText: 'material antigo',
        ),
      );
      final bus = LessonEventBus();
      final t02 = FakeT02Client(
        explanation:
            'Para achar o cruzamento com o eixo Y em uma função quadrática, usamos x = 0.',
        question:
            'Dada a função quadrática f(x) = 3x² + 4x - 7, qual é o ponto onde a parábola cruza o eixo Y?',
        options: const {
          AnswerLetter.A: '(0, -7)',
          AnswerLetter.B: '(-7, 0)',
          AnswerLetter.C: '(0, 4)',
        },
      );
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: cache,
        bus: bus,
      );
      final updates = <CompleteLesson>[];
      final unsubscribeLesson = bus.subscribe(key, updates.add);
      addTearDown(unsubscribeLesson);

      await orchestrator.prefetchCompleteLesson(params);
      await Future<void>.delayed(Duration.zero);

      await orchestrator.prefetchCompleteLesson(
        params,
        priority: 'hot-local',
        forceRefresh: true,
      );
      expect(t02.calls, 1);
      expect(cache.peek(key)?.conteudo.question, contains('função quadrática'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cache.peek(key)?.conteudo.question, contains('função quadrática'));
      expect(cache.peek(key)?.imagem, isNull);
      expect(updates.last.imagem, isNull);
    },
  );

  test(
    'LessonOrchestrator does not create image from cached visual trigger',
    () async {
      final cache = LessonMaterialCache();
      final bus = LessonEventBus();
      final t02 = FakeT02Client();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: cache,
        bus: bus,
      );
      const params = CompleteLessonParams(
        lessonLocalId: 'cyber-cache-linear',
        item: 'Equação do primeiro grau',
        lang: 'pt-BR',
        academic: 'ensino médio',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
      );
      final key = lessonKeyFor(params);
      final updates = <CompleteLesson>[];
      final unsubscribeLesson = bus.subscribe(key, updates.add);
      addTearDown(unsubscribeLesson);
      cache.put(
        key,
        CompleteLesson(
          conteudo: LessonContent(
            explanation:
                'Uma equação do primeiro grau, também conhecida como equação linear, '
                'tem forma y = ax + b e pode ser representada por uma reta no gráfico.',
            question: 'Qual é a forma geral da equação linear?',
            options: const {
              AnswerLetter.A: 'y = ax + b',
              AnswerLetter.B: 'ax² + bx + c = 0',
              AnswerLetter.C: 'a/x + b = 0',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: null,
          audioText: 'texto',
        ),
      );

      await orchestrator.prefetchCompleteLesson(params, priority: 'hot-local');
      await Future<void>.delayed(Duration.zero);

      expect(t02.calls, 0);
      expect(updates, isEmpty);
      expect(cache.peek(key)?.imagem, isNull);
    },
  );

  test('LessonOrchestrator does not render math template locally', () async {
    final cache = LessonMaterialCache();
    final bus = LessonEventBus();
    final orchestrator = LessonOrchestrator(
      t02Client: FakeT02Client(),
      cache: cache,
      bus: bus,
    );
    const params = CompleteLessonParams(
      lessonLocalId: 'cyber-math-template',
      item: 'Função linear',
      lang: 'pt-BR',
      academic: 'fundamental',
      layer: LessonLayer.l1,
      mode: LessonMode.session,
      marker: 'M1',
    );
    final key = lessonKeyFor(params);
    final updates = <CompleteLesson>[];
    final unsubscribe = bus.subscribe(key, updates.add);
    addTearDown(unsubscribe);

    await orchestrator.prefetchCompleteLesson(params, priority: 'hot-local');
    await Future<void>.delayed(Duration.zero);

    expect(updates.single.imagem, isNull);
  });

  test(
    'LessonEventBus delivers live image and replays image to late subscriber',
    () {
      final bus = LessonEventBus();
      const lesson = CompleteLesson(
        conteudo: LessonContent(
          explanation: 'Explicacao',
          question: 'Pergunta',
          options: {
            AnswerLetter.A: 'A',
            AnswerLetter.B: 'B',
            AnswerLetter.C: 'C',
          },
          correctAnswer: AnswerLetter.A,
        ),
        imagem: _serverRasterDataUrl,
        audioText: 'Explicacao. Pergunta',
      );

      final live = <CompleteLesson>[];
      final unsubscribeLive = bus.subscribe('lesson-key', live.add);
      addTearDown(unsubscribeLive);
      bus.notify('lesson-key', lesson);
      final received = <CompleteLesson>[];
      final unsubscribe = bus.subscribe('lesson-key', received.add);
      addTearDown(unsubscribe);

      expect(live.single.imagem, _serverRasterDataUrl);
      expect(received.single.imagem, lesson.imagem);
      expect(received.single.conteudo.question, lesson.conteudo.question);
    },
  );

  test(
    'review and recovery requests do not depend on visual trigger',
    () async {
      final t02 = FakeT02Client();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
      );

      final review = await orchestrator.prefetchCompleteLesson(
        const CompleteLessonParams(
          lessonLocalId: 'cyber-review',
          item: 'Revisão de função',
          lang: 'pt-BR',
          academic: 'fundamental',
          layer: LessonLayer.l2,
          mode: LessonMode.reforco,
          marker: 'M1',
        ),
        priority: 'hot-local',
      );
      final recovery = await orchestrator.prefetchCompleteLesson(
        const CompleteLessonParams(
          lessonLocalId: 'cyber-recovery',
          item: 'Recuperação de função',
          lang: 'pt-BR',
          academic: 'fundamental',
          layer: LessonLayer.l1,
          mode: LessonMode.amparo,
          amparoLvl: 1,
          marker: 'M1',
        ),
        priority: 'hot-local',
      );

      expect(t02.requests.map((request) => request.mode), [
        LessonMode.reforco.name,
        LessonMode.amparo.name,
      ]);
      expect(review.conteudo.explanation, isNotEmpty);
      expect(recovery.conteudo.explanation, isNotEmpty);
    },
  );

  test(
    'background prefetch does not invent local image when server has none',
    () async {
      final cache = LessonMaterialCache();
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(),
        cache: cache,
        bus: LessonEventBus(),
      );
      const params = CompleteLessonParams(
        lessonLocalId: 'cyber-paid-bg',
        item: 'Sistema circulatório',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
      );
      final key = lessonKeyFor(params);

      final lesson = await orchestrator.prefetchCompleteLesson(
        params,
        priority: 'background',
      );
      await Future<void>.delayed(Duration.zero);

      expect(lesson.imagem, isNull);
      expect(cache.peek(key)?.imagem, isNull);
    },
  );

  test(
    'DopamineReadyWindowEngine prepares fifteen-slot live window from state',
    () async {
      final service = StudentLearningStateService(
        seed: {
          'cyber-ready': _stateWithFiveItems().copyWith(
            lessonLocalId: 'cyber-ready',
          ),
        },
      );
      final t02 = FakeT02Client();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
      );
      final engine = DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      );

      final result = await engine.runDopamineReadyWindowFromStudentState(
        lessonLocalId: 'cyber-ready',
        source: 'test',
        maxSlots: localLessonTraySize,
      );

      expect(result, List<bool>.filled(localLessonTraySize, true));
      expect(t02.calls, localLessonTraySize);
      expect(
        service.read('cyber-ready')?.readyLessonMaterials.length,
        localLessonTraySize,
      );
      final prepared = service.read('cyber-ready')!.readyLessonMaterials;
      for (final material in prepared.values) {
        expect(material['explanation'], isNotEmpty);
        expect(material['question'], isNotEmpty);
        expect(material['options'], isA<Map>());
        expect(material['correct_answer'], 'A');
        expect(material['for_itemIdx'], isA<int>());
        expect(material['for_layer'], isA<String>());
      }
    },
  );

  test(
    'M-EXP1: slow image refresh for current slot does not block text slots B/C/D',
    () async {
      final preparedA = preparedMaterialFromLesson(
        lesson: CompleteLesson(
          conteudo: LessonContent(
            explanation: 'Texto atual ja pronto.',
            question: 'Pergunta atual?',
            options: const {
              AnswerLetter.A: 'A certa',
              AnswerLetter.B: 'B errada',
              AnswerLetter.C: 'C errada',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: null,
          audioText: 'Texto atual ja pronto. Pergunta atual?',
        ),
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l1,
      );
      final service = StudentLearningStateService(
        seed: {
          'cyber-image-nonblocking': _stateWithFiveItems().copyWith(
            lessonLocalId: 'cyber-image-nonblocking',
            readyLessonMaterials: {
              preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): preparedA,
            },
          ),
        },
      );
      final t02 = BlockingVisualRefreshT02Client();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
        imageRefreshDelays: const [Duration.zero],
      );
      final engine = DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      );

      final result = await engine
          .runDopamineReadyWindowFromStudentState(
            lessonLocalId: 'cyber-image-nonblocking',
            source: 'm-exp1-image',
            maxSlots: localLessonTraySize,
          )
          .timeout(const Duration(milliseconds: 500));

      expect(result, List<bool>.filled(localLessonTraySize, true));
      expect(
        t02.requests
            .map((request) => '${request.marker}:${request.layer.name}')
            .toSet(),
        containsAll({'M1:l2', 'M1:l3', 'M2:l1'}),
      );
      expect(
        service
            .read('cyber-image-nonblocking')!
            .readyLessonMaterials
            .values
            .map((material) => material['question']),
        everyElement(isNot(contains('HTTP'))),
      );
      if (!t02.visualRefresh.isCompleted) {
        t02.visualRefresh.complete(t02.material(t02.requests.first));
      }
    },
  );

  test(
    'M-EXP1: pending audio notification does not block text slots B/C/D',
    () async {
      final service = StudentLearningStateService(
        seed: {
          'cyber-audio-nonblocking': _stateWithFiveItems().copyWith(
            lessonLocalId: 'cyber-audio-nonblocking',
          ),
        },
      );
      final t02 = FakeT02Client();
      final audioPending = Completer<void>();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
        onAudioTextReady: (_, _) {
          unawaited(audioPending.future);
        },
      );
      final engine = DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      );

      final result = await engine.runDopamineReadyWindowFromStudentState(
        lessonLocalId: 'cyber-audio-nonblocking',
        source: 'm-exp1-audio',
        maxSlots: localLessonTraySize,
      );

      expect(result, List<bool>.filled(localLessonTraySize, true));
      expect(t02.calls, localLessonTraySize);
      expect(audioPending.isCompleted, isFalse);
      audioPending.complete();
    },
  );

  test(
    'M-EXP2: ready window queues secondary media only after textual window',
    () async {
      final service = StudentLearningStateService(
        seed: {
          'cyber-media-priority': _stateWithFiveItems().copyWith(
            lessonLocalId: 'cyber-media-priority',
          ),
        },
      );
      final t02 = FakeT02Client(imageStatus: 'processing');
      final audioPrepared = <String>[];
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
        imageRefreshDelays: const [Duration.zero],
        onAudioTextReady: (params, _) {
          audioPrepared.add('${params.marker}:${params.layer.name}');
        },
      );
      final engine = DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      );

      final result = await engine.runDopamineReadyWindowFromStudentState(
        lessonLocalId: 'cyber-media-priority',
        source: 'm-exp2-media',
        maxSlots: localLessonTraySize,
      );

      expect(result, List<bool>.filled(localLessonTraySize, true));
      final events = service.read('cyber-media-priority')!.events;
      final firstMediaIndex = events.indexWhere(
        (event) =>
            event.type == 'DOPAMINE_SLOT_AUDIO_QUEUED' ||
            event.type == 'DOPAMINE_SLOT_IMAGE_QUEUED',
      );
      final readyBeforeMedia = events
          .take(firstMediaIndex)
          .where((event) => event.type == 'DOPAMINE_SLOT_READY')
          .length;
      expect(readyBeforeMedia, localLessonTraySize);
      final trailingSlots = [
        'B',
        'C',
        'D',
        for (var index = 5; index <= localLessonTraySize; index++) 'W$index',
      ];
      expect(
        events
            .where(
              (event) =>
                  event.type == 'DOPAMINE_SLOT_AUDIO_QUEUED' ||
                  event.type == 'DOPAMINE_SLOT_IMAGE_QUEUED',
            )
            .map(
              (event) =>
                  '${event.type}:${event.payload['slot']}:${event.payload['priority']}',
            )
            .toList(),
        [
          'DOPAMINE_SLOT_AUDIO_QUEUED:A:current',
          'DOPAMINE_SLOT_IMAGE_QUEUED:A:current',
          for (final slot in trailingSlots)
            'DOPAMINE_SLOT_AUDIO_QUEUED:$slot:next',
          for (final slot in trailingSlots)
            'DOPAMINE_SLOT_IMAGE_QUEUED:$slot:next',
        ],
      );
      expect(audioPrepared, hasLength(localLessonTraySize));
      expect(audioPrepared, contains('M5:l3'));
    },
  );

  test(
    'M-EXP2: ready window does not queue secondary media twice for same slot',
    () async {
      final service = StudentLearningStateService(
        seed: {
          'cyber-media-dedupe': _stateWithFiveItems().copyWith(
            lessonLocalId: 'cyber-media-dedupe',
          ),
        },
      );
      final t02 = FakeT02Client(imageStatus: 'processing');
      final audioPrepared = <String>[];
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
        imageRefreshDelays: const [],
        onAudioTextReady: (params, _) {
          audioPrepared.add('${params.marker}:${params.layer.name}');
        },
      );
      final engine = DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      );

      await engine.runDopamineReadyWindowFromStudentState(
        lessonLocalId: 'cyber-media-dedupe',
        source: 'm-exp2-media',
        maxSlots: localLessonTraySize,
      );
      await engine.runDopamineReadyWindowFromStudentState(
        lessonLocalId: 'cyber-media-dedupe',
        source: 'm-exp2-media',
        maxSlots: localLessonTraySize,
      );

      final events = service.read('cyber-media-dedupe')!.events;
      final queued = events
          .where(
            (event) =>
                event.type == 'DOPAMINE_SLOT_AUDIO_QUEUED' ||
                event.type == 'DOPAMINE_SLOT_IMAGE_QUEUED',
          )
          .toList(growable: false);
      expect(queued, hasLength(localLessonTraySize * 2));
      expect(
        queued.map((event) => event.payload['mediaKey']).toSet(),
        hasLength(localLessonTraySize * 2),
      );
      expect(audioPrepared, hasLength(localLessonTraySize));
      expect(t02.calls, localLessonTraySize);
    },
  );

  test(
    'M-EXP2: ready window caps oversized requests at constitutional tray size',
    () async {
      final service = StudentLearningStateService(
        seed: {
          'cyber-window-cap': _stateWithFiveItems().copyWith(
            lessonLocalId: 'cyber-window-cap',
          ),
        },
      );
      final t02 = FakeT02Client();
      final engine = DopamineReadyWindowEngine(
        service: service,
        orchestrator: LessonOrchestrator(
          t02Client: t02,
          cache: LessonMaterialCache(),
          bus: LessonEventBus(),
        ),
      );

      final result = await engine.runDopamineReadyWindowFromStudentState(
        lessonLocalId: 'cyber-window-cap',
        source: 'm-exp2-cap',
        maxSlots: 50,
      );

      expect(result, hasLength(localLessonTraySize));
      expect(t02.calls, localLessonTraySize);
      expect(
        service
            .read('cyber-window-cap')!
            .events
            .where((event) => event.type == 'DOPAMINE_WINDOW_REQUEST_CAPPED')
            .single
            .payload,
        containsPair('accepted', localLessonTraySize),
      );
    },
  );

  test(
    'M-EXP1: CG-1 boundary metadata is sent with current textual slot',
    () async {
      const items = [
        CurriculumItem(
          marker: 'M80',
          text: 'Item global 80',
          extra: {
            'globalItemNumber': 80,
            'partNumber': 1,
            'localItemIndex': 79,
          },
        ),
        CurriculumItem(
          marker: 'M81',
          text: 'Item global 81',
          extra: {
            'globalItemNumber': 81,
            'partNumber': 2,
            'localItemIndex': 0,
            'globalMarker': 'G81',
          },
        ),
      ];
      final service = StudentLearningStateService(
        seed: {
          'cyber-cg-boundary':
              StudentLearningState.empty(
                lessonLocalId: 'cyber-cg-boundary',
              ).copyWith(
                profile: const StudentProfile(
                  objetivo: 'Objetivo CG',
                  stableLang: 'pt',
                  academicLevel: 'fundamental',
                ),
                curriculum: const StudentCurriculum(
                  topic: 'Objetivo CG',
                  totalItems: 2,
                  generatedAt: null,
                  provisional: false,
                  items: items,
                ),
                current: const LessonCurrent(
                  itemIdx: 1,
                  marker: 'M81',
                  layer: LessonLayer.l1,
                  amparoLvl: 0,
                ),
                progress: const LessonProgress(
                  itemIdx: 1,
                  layer: LessonLayer.l1,
                  erros: 0,
                  amparoLvl: 0,
                  historia: [],
                  mainAdvances: 0,
                  concluidos: [],
                  pendentesMarkers: [],
                  totalItems: 2,
                  pctAvanco: 50,
                ),
              ),
        },
      );
      final t02 = FakeT02Client();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
      );
      final engine = DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      );

      final result = await engine.runDopamineReadyWindowFromStudentState(
        lessonLocalId: 'cyber-cg-boundary',
        source: 'm-exp1-cg',
        maxSlots: 1,
      );

      expect(result, [true]);
      expect(t02.requests.single.marker, 'M81');
      expect(t02.requests.single.itemIdx, 1);
      expect(t02.requests.single.curriculumItems[1]['globalItemNumber'], 81);
      expect(t02.requests.single.curriculumItems[1]['partNumber'], 2);
      expect(t02.requests.single.curriculumItems[1]['localItemIndex'], 0);
      final key = preparedLessonMaterialKey(1, 'M81', LessonLayer.l1);
      final prepared = service
          .read('cyber-cg-boundary')!
          .readyLessonMaterials[key]!;
      expect(prepared['for_itemIdx'], 1);
      expect(prepared['for_marker'], 'M81');
      expect(prepared['for_layer'], LessonLayer.l1.name);
    },
  );

  test(
    'M-EXP3-B: cache preserves validated CG-1 part 2 cold index metadata',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const params = CompleteLessonParams(
        lessonLocalId: 'lesson-cg-part-2',
        item: 'Item global 81',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l2,
        mode: LessonMode.session,
        marker: 'M81',
        itemIdx: 0,
        curriculumItems: [
          {
            'marker': 'M81',
            'text': 'Item global 81',
            'rootLessonLocalId': 'lesson-cg-root',
            'partLessonLocalId': 'lesson-cg-part-2',
            'partNumber': 2,
            'globalItemNumber': 81,
            'localItemIndex': 0,
          },
        ],
      );
      final key = lessonKeyFor(params);
      final cache = LessonMaterialCache(maxLessons: 1);
      expect(
        cache.putForParams(
          params,
          const CompleteLesson(
            conteudo: LessonContent(
              explanation: 'Texto oficial da parte 2.',
              question: 'Qual item global?',
              options: {
                AnswerLetter.A: '81',
                AnswerLetter.B: '1 local sem raiz',
                AnswerLetter.C: 'parte solta',
              },
              correctAnswer: AnswerLetter.A,
            ),
            imagem: null,
            audioText: 'Texto oficial da parte 2. Qual item global?',
          ),
        ),
        isTrue,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final hydrated = LessonMaterialCache(maxLessons: 1);
      hydrated.hydrateFromPreferences(prefs);
      final cold = hydrated.coldEntry(key);

      expect(cold, isNotNull);
      expect(cold!.rootLessonLocalId, 'lesson-cg-root');
      expect(cold.partLessonLocalId, 'lesson-cg-part-2');
      expect(cold.partNumber, 2);
      expect(cold.globalItemNumber, 81);
      expect(cold.localItemIndex, 0);
      expect(cold.marker, 'M81');
      expect(cold.itemIdx, 0);
      expect(cold.layer, LessonLayer.l2);
      expect(hydrated.peek(key)?.conteudo.question, 'Qual item global?');
    },
  );

  test(
    'M-EXP3-B: cache refuses CG-1 part 2 without official minimum metadata',
    () {
      const params = CompleteLessonParams(
        lessonLocalId: 'lesson-cg-part-2-untrusted',
        item: 'Item global sem raiz',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M81',
        itemIdx: 0,
        curriculumItems: [
          {'marker': 'M81', 'text': 'Item global sem raiz', 'partNumber': 2},
        ],
      );
      final cache = LessonMaterialCache();
      final key = lessonKeyFor(params);

      final accepted = cache.putForParams(
        params,
        const CompleteLesson(
          conteudo: LessonContent(
            explanation: 'Texto nao confiavel.',
            question: 'Pode cachear?',
            options: {
              AnswerLetter.A: 'Nao',
              AnswerLetter.B: 'Sim',
              AnswerLetter.C: 'Inventar raiz',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: null,
          audioText: 'Texto nao confiavel. Pode cachear?',
        ),
      );

      expect(accepted, isFalse);
      expect(cache.peek(key), isNull);
      expect(cache.coldEntry(key), isNull);
    },
  );

  test('M-EXP3-B: cache refuses CG-1 part 2 without partLessonLocalId', () {
    const params = CompleteLessonParams(
      lessonLocalId: 'lesson-cg-part-2-without-part-id',
      item: 'Item global 81',
      lang: 'pt-BR',
      academic: 'fundamental',
      layer: LessonLayer.l1,
      mode: LessonMode.session,
      marker: 'M81',
      itemIdx: 0,
      curriculumItems: [
        {
          'marker': 'M81',
          'text': 'Item global 81',
          'rootLessonLocalId': 'lesson-cg-root',
          'partNumber': 2,
          'globalItemNumber': 81,
          'localItemIndex': 0,
        },
      ],
    );
    final cache = LessonMaterialCache();
    final key = lessonKeyFor(params);

    final accepted = cache.putForParams(
      params,
      const CompleteLesson(
        conteudo: LessonContent(
          explanation: 'Texto oficial incompleto.',
          question: 'Pode cachear Parte 2 sem partLessonLocalId?',
          options: {
            AnswerLetter.A: 'Nao',
            AnswerLetter.B: 'Sim',
            AnswerLetter.C: 'Tratar como parte solta',
          },
          correctAnswer: AnswerLetter.A,
        ),
        imagem: null,
        audioText:
            'Texto oficial incompleto. Pode cachear Parte 2 sem partLessonLocalId?',
      ),
    );

    expect(accepted, isFalse);
    expect(cache.coldEntry(key), isNull);
    expect(cache.peek(key), isNull);
  });

  test('prepared material key contains item marker and layer', () {
    expect(
      preparedLessonMaterialKey(2, 'M3', LessonLayer.l2),
      'I2::M3::L2::l2',
    );
  });

  test(
    'invalid ready state material is discarded and T02 is called again',
    () async {
      final service = StudentLearningStateService(
        seed: {
          'cyber-ready': _stateWithCurriculum().copyWith(
            readyLessonMaterials: {
              preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): {
                'text_status': 'ready',
                'explanation': '',
                'question': 'Pergunta?',
                'options': {'A': 'A', 'B': 'B', 'C': 'C'},
                'correct_answer': 'A',
                'for_itemIdx': 0,
                'for_marker': 'M1',
                'for_layer': LessonLayer.l1.name,
              },
            },
          ),
        },
      );
      final t02 = FakeT02Client();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
      );
      final materialService = StudentLessonMaterialService(
        stateService: service,
        orchestrator: orchestrator,
        readyWindowEngine: DopamineReadyWindowEngine(
          service: service,
          orchestrator: orchestrator,
        ),
      );

      final result = await materialService
          .resolveLessonMaterialFromStateOrEngine(
            ResolveLessonMaterialInput(
              lessonLocalId: 'cyber-ready',
              topic: 'Objetivo',
              itemIdx: 0,
              marker: 'M1',
              layer: LessonLayer.l1,
              params: const CompleteLessonParams(
                lessonLocalId: 'cyber-ready',
                item: 'Item 1',
                lang: 'pt',
                academic: 'fundamental',
                layer: LessonLayer.l1,
                mode: LessonMode.session,
                marker: 'M1',
              ),
              allowRemoteOrder: true,
            ),
          );

      expect(result?.conteudo.explanation, 'Explicacao de Item 1');
      expect(t02.calls, 1);
      expect(
        service.read('cyber-ready')?.events.map((event) => event.type),
        contains('LESSON_MATERIAL_INVALID_DISCARDED'),
      );
    },
  );

  test(
    'M-EXP3: ready material from wrong slot is ignored and official T02 is requested',
    () async {
      final service = StudentLearningStateService(
        seed: {
          'cyber-wrong-slot': _stateWithCurriculum().copyWith(
            lessonLocalId: 'cyber-wrong-slot',
            readyLessonMaterials: {
              preparedLessonMaterialKey(0, 'M1', LessonLayer.l2): {
                'text_status': 'ready',
                'explanation': 'Texto de outra camada.',
                'question': 'Pergunta errada?',
                'options': {'A': 'A', 'B': 'B', 'C': 'C'},
                'correct_answer': 'A',
                'for_itemIdx': 0,
                'for_marker': 'M1',
                'for_layer': LessonLayer.l2.name,
              },
            },
          ),
        },
      );
      final t02 = FakeT02Client();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
      );
      final materialService = StudentLessonMaterialService(
        stateService: service,
        orchestrator: orchestrator,
        readyWindowEngine: DopamineReadyWindowEngine(
          service: service,
          orchestrator: orchestrator,
        ),
      );

      final result = await materialService
          .resolveLessonMaterialFromStateOrEngine(
            ResolveLessonMaterialInput(
              lessonLocalId: 'cyber-wrong-slot',
              topic: 'Objetivo',
              itemIdx: 0,
              marker: 'M1',
              layer: LessonLayer.l1,
              params: const CompleteLessonParams(
                lessonLocalId: 'cyber-wrong-slot',
                item: 'Item 1',
                lang: 'pt',
                academic: 'fundamental',
                layer: LessonLayer.l1,
                mode: LessonMode.session,
                marker: 'M1',
              ),
              allowRemoteOrder: true,
            ),
          );

      expect(result?.conteudo.explanation, 'Explicacao de Item 1');
      expect(t02.calls, 1);
    },
  );

  test('maintainLessonReadyWindow mirrors cache window metadata to state', () {
    final service = StudentLearningStateService();
    service.ensure(lessonLocalId: 'cyber-window');
    final orchestrator = LessonOrchestrator(
      t02Client: FakeT02Client(),
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
    );
    final materialService = StudentLessonMaterialService(
      stateService: service,
      orchestrator: orchestrator,
      readyWindowEngine: DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      ),
    );

    materialService.maintainLessonReadyWindow(
      lessonLocalId: 'cyber-window',
      topic: 'Funções',
      itemIdx: 0,
      layer: LessonLayer.l1,
      source: 'test-window',
      items: const [
        DopamineWindowItem(text: 'Item 1', marker: 'M1'),
        DopamineWindowItem(text: 'Item 2', marker: 'M2'),
      ],
    );

    final state = service.read('cyber-window');
    final event = state?.events.singleWhere(
      (event) => event.type == 'CACHE_WINDOW_UPDATED',
    );
    expect(state?.queuedActions, hasLength(1));
    expect(state?.queuedActions.map((job) => job['payload']?['maxSlots']), [
      offlineWarmCacheSize,
    ]);
    expect(event?.payload['currentItemIdx'], 0);
    expect(event?.payload['currentLayer'], 1);
    expect(event?.payload['windowSize'], 6);
    expect(event?.payload['cachedCount'], 6);
    expect(event?.payload['windowMarkers'], [
      {'marker': 'M1', 'layer': 1, 'offset': 0},
      {'marker': 'M1', 'layer': 2, 'offset': 1},
      {'marker': 'M1', 'layer': 3, 'offset': 2},
      {'marker': 'M2', 'layer': 1, 'offset': 3},
      {'marker': 'M2', 'layer': 2, 'offset': 4},
      {'marker': 'M2', 'layer': 3, 'offset': 5},
    ]);
  });

  test('ready window from L3 keeps all remaining positions', () {
    final service = StudentLearningStateService();
    service.ensure(lessonLocalId: 'cyber-window-l3');
    final orchestrator = LessonOrchestrator(
      t02Client: FakeT02Client(),
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
    );
    final materialService = StudentLessonMaterialService(
      stateService: service,
      orchestrator: orchestrator,
      readyWindowEngine: DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      ),
    );

    materialService.maintainLessonReadyWindow(
      lessonLocalId: 'cyber-window-l3',
      topic: 'Funções',
      itemIdx: 0,
      layer: LessonLayer.l3,
      source: 'test-window-l3',
      items: const [
        DopamineWindowItem(text: 'Item 1', marker: 'M1'),
        DopamineWindowItem(text: 'Item 2', marker: 'M2'),
      ],
    );

    final event = service
        .read('cyber-window-l3')
        ?.events
        .singleWhere((event) => event.type == 'CACHE_WINDOW_UPDATED');
    final expectedMarkers = [
      {'marker': 'M1', 'layer': 3, 'offset': 0},
      {'marker': 'M2', 'layer': 1, 'offset': 1},
      {'marker': 'M2', 'layer': 2, 'offset': 2},
      {'marker': 'M2', 'layer': 3, 'offset': 3},
    ];
    expect(event?.payload['windowSize'], expectedMarkers.length);
    expect(event?.payload['windowMarkers'], expectedMarkers);
  });

  test(
    'ready window accepts fewer than fifteen only at real curriculum end',
    () {
      final service = StudentLearningStateService();
      service.ensure(lessonLocalId: 'cyber-window-end');
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(),
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
      );
      final materialService = StudentLessonMaterialService(
        stateService: service,
        orchestrator: orchestrator,
        readyWindowEngine: DopamineReadyWindowEngine(
          service: service,
          orchestrator: orchestrator,
        ),
      );

      materialService.maintainLessonReadyWindow(
        lessonLocalId: 'cyber-window-end',
        topic: 'Funções',
        itemIdx: 1,
        layer: LessonLayer.l3,
        source: 'test-window-end',
        items: const [
          DopamineWindowItem(text: 'Item 1', marker: 'M1'),
          DopamineWindowItem(text: 'Item 2', marker: 'M2'),
        ],
      );

      final event = service
          .read('cyber-window-end')
          ?.events
          .singleWhere((event) => event.type == 'CACHE_WINDOW_UPDATED');
      expect(event?.payload['windowSize'], 1);
      expect(event?.payload['windowMarkers'], [
        {'marker': 'M2', 'layer': 3, 'offset': 0},
      ]);
    },
  );

  test('maintainLessonReadyWindow does not duplicate active jobs', () {
    final service = StudentLearningStateService();
    service.ensure(lessonLocalId: 'cyber-window-dedupe');
    final orchestrator = LessonOrchestrator(
      t02Client: FakeT02Client(),
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
    );
    final materialService = StudentLessonMaterialService(
      stateService: service,
      orchestrator: orchestrator,
      readyWindowEngine: DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      ),
    );

    for (var i = 0; i < 2; i++) {
      materialService.maintainLessonReadyWindow(
        lessonLocalId: 'cyber-window-dedupe',
        topic: 'Funções',
        itemIdx: 0,
        layer: LessonLayer.l1,
        source: i == 0 ? 'test-window' : 'test-window-second-source',
        items: const [
          DopamineWindowItem(text: 'Item 1', marker: 'M1'),
          DopamineWindowItem(text: 'Item 2', marker: 'M2'),
        ],
      );
    }

    final state = service.read('cyber-window-dedupe');
    expect(state?.queuedActions, hasLength(1));
    final hotJob = state?.queuedActions.firstWhere(
      (job) =>
          job['idempotency_key'] == 'ready-window:cyber-window-dedupe:0:M1:L1',
    );
    expect(
      hotJob?['idempotency_key'],
      'ready-window:cyber-window-dedupe:0:M1:L1',
    );
    expect(hotJob?['payload']?['maxSlots'], offlineWarmCacheSize);
    expect(
      state?.events.where((event) => event.type == 'CACHE_WINDOW_UPDATED'),
      hasLength(2),
    );

    materialService.maintainLessonReadyWindow(
      lessonLocalId: 'cyber-window-dedupe',
      topic: 'Funções',
      itemIdx: 0,
      layer: LessonLayer.l1,
      source: 'test-window-visible-active',
      priority: 'hot-local',
      items: const [
        DopamineWindowItem(text: 'Item 1', marker: 'M1'),
        DopamineWindowItem(text: 'Item 2', marker: 'M2'),
      ],
    );

    final upgraded = service.read('cyber-window-dedupe')?.queuedActions;
    final upgradedHot = upgraded?.firstWhere(
      (job) =>
          job['idempotency_key'] == 'ready-window:cyber-window-dedupe:0:M1:L1',
    );
    expect(upgraded, hasLength(1));
    expect(upgradedHot?['priority'], 'hot-local');
    expect(upgradedHot?['source'], 'test-window-visible-active');
  });

  test(
    'loaded active lesson keeps fifteen-slot offline window queued',
    () async {
      final service = StudentLearningStateService();
      service.ensure(lessonLocalId: 'cyber-loaded-window');
      final initialMaterial = preparedMaterialFromLesson(
        lesson: const CompleteLesson(
          conteudo: LessonContent(
            explanation: 'Texto preparado Item 1 L1.',
            question: 'Pergunta preparada Item 1 L1?',
            options: {
              AnswerLetter.A: 'A certa',
              AnswerLetter.B: 'B errada',
              AnswerLetter.C: 'C errada',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: null,
          audioText: 'Texto preparado Item 1 L1. Pergunta preparada Item 1 L1?',
        ),
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l1,
      );
      service.mutate('cyber-loaded-window', (state) {
        return state.copyWith(
          currentLessonMaterial: initialMaterial,
          readyLessonMaterials: {
            preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): initialMaterial,
          },
        );
      });
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(),
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
      );
      final materialService = StudentLessonMaterialService(
        stateService: service,
        orchestrator: orchestrator,
        readyWindowEngine: DopamineReadyWindowEngine(
          service: service,
          orchestrator: orchestrator,
        ),
      );
      final controller = LessonMaterialController(
        stateService: service,
        materialService: materialService,
      );
      final items = const [
        PlannedItem(marker: 'M1', text: 'Item 1'),
        PlannedItem(marker: 'M2', text: 'Item 2'),
      ];
      final position = LessonPositionState(
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

      await controller.carregar(
        lessonLocalId: 'cyber-loaded-window',
        topic: 'Funções',
        position: position,
        idioma: 'pt-BR',
        academic: 'fundamental',
        mode: LessonMode.session,
        baseItems: items,
      );

      final state = service.read('cyber-loaded-window');
      expect(position.teoriaPronta, isTrue);
      expect(state?.queuedActions, hasLength(1));
      final hotJob = state?.queuedActions.firstWhere(
        (job) => job['source'] == 'cyber.aula.cache-window',
      );
      expect(hotJob?['type'], 'PREPARE_READY_WINDOW');
      expect(hotJob?['priority'], 'hot-local');
      expect(hotJob?['payload']?['maxSlots'], offlineWarmCacheSize);
      final event = state?.events.lastWhere(
        (event) => event.type == 'CACHE_WINDOW_UPDATED',
      );
      expect(event?.payload['windowSize'], 6);
      expect(event?.payload['windowMarkers'], [
        {'marker': 'M1', 'layer': 1, 'offset': 0},
        {'marker': 'M1', 'layer': 2, 'offset': 1},
        {'marker': 'M1', 'layer': 3, 'offset': 2},
        {'marker': 'M2', 'layer': 1, 'offset': 3},
        {'marker': 'M2', 'layer': 2, 'offset': 4},
        {'marker': 'M2', 'layer': 3, 'offset': 5},
      ]);
    },
  );

  test(
    'drawer lesson priority asks visible lesson before ready window',
    () async {
      const lessonId = 'drawer-visible-first';
      final service = StudentLearningStateService(
        seed: {
          lessonId: _stateWithFiveItems().copyWith(lessonLocalId: lessonId),
        },
      );
      final t02 = BlockingT02Client();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
      );
      final materialService = StudentLessonMaterialService(
        stateService: service,
        orchestrator: orchestrator,
        readyWindowEngine: DopamineReadyWindowEngine(
          service: service,
          orchestrator: orchestrator,
        ),
      );
      final controller = LessonMaterialController(
        stateService: service,
        materialService: materialService,
      );
      final items = List<PlannedItem>.generate(
        5,
        (index) =>
            PlannedItem(marker: 'M${index + 1}', text: 'Item ${index + 1}'),
      );
      final position = LessonPositionState(
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

      final load = controller.carregar(
        lessonLocalId: lessonId,
        topic: 'Menu',
        position: position,
        idioma: 'pt-BR',
        academic: 'fundamental',
        mode: LessonMode.session,
        baseItems: items,
        allowRemoteOrder: true,
        remoteOrderPriority: 'hot-local',
        missingSource: 'drawer.aula.visible-request',
        missingPriority: 'hot-local',
        suppressReadyWindowUntilVisibleLessonReady: true,
      );
      await t02.firstCallStarted.future;

      final waitingState = service.read(lessonId)!;
      expect(t02.calls, 1);
      expect(t02.requests.single.marker, 'M1');
      expect(t02.requests.single.layer, LessonLayer.l1);
      expect(waitingState.queuedActions, isEmpty);
      expect(
        waitingState.events.where(
          (event) => event.type == 'CACHE_WINDOW_UPDATED',
        ),
        isEmpty,
      );

      t02.release.complete();
      await load;

      final readyState = service.read(lessonId)!;
      expect(position.teoriaPronta, isTrue);
      expect(position.conteudo?.explanation, contains('Item 1'));
      expect(readyState.queuedActions, hasLength(1));
      expect(readyState.queuedActions.single['priority'], 'hot-local');
      expect(readyState.queuedActions.single['type'], 'PREPARE_READY_WINDOW');
      expect(
        readyState.events.where(
          (event) => event.type == 'CACHE_WINDOW_UPDATED',
        ),
        isNotEmpty,
      );
    },
  );

  test('drawer visible lesson failure does not start window retries', () async {
    const lessonId = 'drawer-visible-fails';
    final service = StudentLearningStateService(
      seed: {lessonId: _stateWithFiveItems().copyWith(lessonLocalId: lessonId)},
    );
    final t02 = FailingT02Client('rate limited');
    final orchestrator = LessonOrchestrator(
      t02Client: t02,
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
    );
    final materialService = StudentLessonMaterialService(
      stateService: service,
      orchestrator: orchestrator,
      readyWindowEngine: DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      ),
    );
    final controller = LessonMaterialController(
      stateService: service,
      materialService: materialService,
    );
    final items = List<PlannedItem>.generate(
      5,
      (index) =>
          PlannedItem(marker: 'M${index + 1}', text: 'Item ${index + 1}'),
    );
    final position = LessonPositionState(
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

    await controller.carregar(
      lessonLocalId: lessonId,
      topic: 'Menu',
      position: position,
      idioma: 'pt-BR',
      academic: 'fundamental',
      mode: LessonMode.session,
      baseItems: items,
      allowRemoteOrder: true,
      waitAfterOrderMs: 100,
      remoteOrderPriority: 'hot-local',
      missingSource: 'drawer.aula.visible-request',
      missingPriority: 'hot-local',
      suppressReadyWindowUntilVisibleLessonReady: true,
    );

    final state = service.read(lessonId)!;
    expect(t02.calls, 1);
    expect(position.teoriaPronta, isFalse);
    expect(position.phase.type, ClassroomPhaseType.avancoPendente);
    expect(state.queuedActions, isEmpty);
    expect(
      state.events.where(
        (event) => event.type == 'VISIBLE_REQUESTED_LESSON_WAITING',
      ),
      hasLength(1),
    );
    expect(
      state.events.where((event) => event.type == 'CACHE_WINDOW_UPDATED'),
      isEmpty,
    );
  });

  test(
    'visible lesson proactively prepares L2 L3 and next item before answer',
    () async {
      const lessonId = 'cyber-proactive-window';
      final initialMaterial = preparedMaterialFromLesson(
        lesson: const CompleteLesson(
          conteudo: LessonContent(
            explanation: 'Texto preparado Item 1 L1.',
            question: 'Pergunta preparada Item 1 L1?',
            options: {
              AnswerLetter.A: 'A certa',
              AnswerLetter.B: 'B errada',
              AnswerLetter.C: 'C errada',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: null,
          audioText: 'Texto preparado Item 1 L1. Pergunta preparada Item 1 L1?',
        ),
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l1,
      );
      final service = StudentLearningStateService(
        seed: {
          lessonId: _stateWithFiveItems().copyWith(
            lessonLocalId: lessonId,
            currentLessonMaterial: initialMaterial,
            readyLessonMaterials: {
              preparedLessonMaterialKey(0, 'M1', LessonLayer.l1):
                  initialMaterial,
            },
          ),
        },
      );
      final t02 = FakeT02Client();
      final cache = LessonMaterialCache();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: cache,
        bus: LessonEventBus(),
      );
      final engine = DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      );
      final materialService = StudentLessonMaterialService(
        stateService: service,
        orchestrator: orchestrator,
        readyWindowEngine: engine,
      );
      final controller = LessonMaterialController(
        stateService: service,
        materialService: materialService,
      );
      final worker = ReadyWindowWorker(
        service: service,
        processor:
            ({
              required lessonLocalId,
              required source,
              maxSlots,
              returnMode = false,
              itemIdx,
              layer,
              marker,
              topic,
            }) {
              return engine.runDopamineReadyWindowFromStudentState(
                lessonLocalId: lessonLocalId,
                source: source,
                maxSlots: maxSlots,
                returnMode: returnMode,
                itemIdx: itemIdx,
                layer: layer,
                marker: marker,
                topic: topic,
              );
            },
      );
      final items = List<PlannedItem>.generate(
        5,
        (index) =>
            PlannedItem(marker: 'M${index + 1}', text: 'Item ${index + 1}'),
      );
      final position = LessonPositionState(
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

      await controller.carregar(
        lessonLocalId: lessonId,
        topic: 'Objetivo offline',
        position: position,
        idioma: 'pt-BR',
        academic: 'fundamental',
        mode: LessonMode.session,
        baseItems: items,
      );
      expect(position.phase.type, ClassroomPhaseType.lendo);
      expect(t02.calls, 0);

      await worker.drainReadyWindowJobs(lessonId);

      final ready = service.read(lessonId)?.readyLessonMaterials ?? const {};
      expect(
        ready.keys,
        containsAll([
          preparedLessonMaterialKey(0, 'M1', LessonLayer.l1),
          preparedLessonMaterialKey(0, 'M1', LessonLayer.l2),
          preparedLessonMaterialKey(0, 'M1', LessonLayer.l3),
          preparedLessonMaterialKey(1, 'M2', LessonLayer.l1),
        ]),
      );
      expect(ready, hasLength(localLessonTraySize));
      expect(t02.calls, lessThanOrEqualTo(15));
    },
  );

  test(
    'moving position refills hot window and prunes passed ready material',
    () {
      final service = StudentLearningStateService(
        seed: {
          'cyber-refill-window': _stateWithFiveItems().copyWith(
            lessonLocalId: 'cyber-refill-window',
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
              totalItems: 5,
              pctAvanco: 20,
            ),
            readyLessonMaterials: {
              preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): {
                'text_status': 'ready',
                'for_itemIdx': 0,
                'for_marker': 'M1',
                'for_layer': LessonLayer.l1.name,
              },
              preparedLessonMaterialKey(1, 'M2', LessonLayer.l1): {
                'text_status': 'ready',
                'for_itemIdx': 1,
                'for_marker': 'M2',
                'for_layer': LessonLayer.l1.name,
              },
            },
          ),
        },
      );
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(),
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
      );
      final materialService = StudentLessonMaterialService(
        stateService: service,
        orchestrator: orchestrator,
        readyWindowEngine: DopamineReadyWindowEngine(
          service: service,
          orchestrator: orchestrator,
        ),
      );

      materialService.maintainLessonReadyWindow(
        lessonLocalId: 'cyber-refill-window',
        topic: 'Objetivo offline',
        itemIdx: 1,
        layer: LessonLayer.l1,
        source: 'test-refill-after-advance',
        priority: 'hot-local',
        items: const [
          DopamineWindowItem(text: 'Item 1', marker: 'M1'),
          DopamineWindowItem(text: 'Item 2', marker: 'M2'),
          DopamineWindowItem(text: 'Item 3', marker: 'M3'),
          DopamineWindowItem(text: 'Item 4', marker: 'M4'),
          DopamineWindowItem(text: 'Item 5', marker: 'M5'),
        ],
      );

      final state = service.read('cyber-refill-window');
      expect(
        state?.readyLessonMaterials.keys,
        isNot(contains(preparedLessonMaterialKey(0, 'M1', LessonLayer.l1))),
      );
      expect(
        state?.readyLessonMaterials.keys,
        contains(preparedLessonMaterialKey(1, 'M2', LessonLayer.l1)),
      );
      final event = state?.events.lastWhere(
        (event) => event.type == 'CACHE_WINDOW_UPDATED',
      );
      expect(event?.payload['windowMarkers'], [
        {'marker': 'M2', 'layer': 1, 'offset': 0},
        {'marker': 'M2', 'layer': 2, 'offset': 1},
        {'marker': 'M2', 'layer': 3, 'offset': 2},
        {'marker': 'M3', 'layer': 1, 'offset': 3},
        {'marker': 'M3', 'layer': 2, 'offset': 4},
        {'marker': 'M3', 'layer': 3, 'offset': 5},
        {'marker': 'M4', 'layer': 1, 'offset': 6},
        {'marker': 'M4', 'layer': 2, 'offset': 7},
        {'marker': 'M4', 'layer': 3, 'offset': 8},
        {'marker': 'M5', 'layer': 1, 'offset': 9},
        {'marker': 'M5', 'layer': 2, 'offset': 10},
        {'marker': 'M5', 'layer': 3, 'offset': 11},
      ]);
      final hotJob = state?.queuedActions.firstWhere(
        (job) =>
            job['idempotency_key'] ==
            'ready-window:cyber-refill-window:1:M2:L1',
      );
      expect(hotJob?['priority'], 'hot-local');
    },
  );

  test('invalid persistent cache entries are ignored', () async {
    SharedPreferences.setMockInitialValues({
      'sim-lesson-text-cache-v1': jsonEncode({
        'bad': {
          'savedAt': DateTime.now().millisecondsSinceEpoch,
          'lesson': {
            'conteudo': {
              'explanation': 'Exp',
              'question': 'Pergunta?',
              'options': {'A': 'A', 'B': '', 'C': 'C'},
              'correct_answer': 'A',
            },
            'audioText': 'Exp. Pergunta?',
          },
        },
      }),
    });

    final cache = LessonMaterialCache();
    await cache.hydrate();

    expect(cache.peek('bad'), isNull);
  });

  test('ready state material keeps text-only material text-only', () async {
    final params = const CompleteLessonParams(
      lessonLocalId: 'cyber-ready',
      item: 'Plano cartesiano',
      lang: 'pt-BR',
      academic: 'fundamental',
      layer: LessonLayer.l1,
      mode: LessonMode.session,
      marker: 'M1',
    );
    final service = StudentLearningStateService(
      seed: {
        'cyber-ready': _stateWithCurriculum().copyWith(
          readyLessonMaterials: {
            preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): {
              'text_status': 'ready',
              'explanation': 'Observe o eixo x e o eixo y.',
              'question': 'Onde fica a origem?',
              'options': {'A': 'No zero', 'B': 'No topo', 'C': 'Na borda'},
              'correct_answer': 'A',
              'for_itemIdx': 0,
              'for_marker': 'M1',
              'for_layer': LessonLayer.l1.name,
            },
          },
        ),
      },
    );
    final cache = LessonMaterialCache();
    final bus = LessonEventBus();
    final updates = <CompleteLesson>[];
    final unsubscribe = bus.subscribe(lessonKeyFor(params), updates.add);
    addTearDown(unsubscribe);
    final orchestrator = LessonOrchestrator(
      t02Client: FakeT02Client(),
      cache: cache,
      bus: bus,
    );
    final materialService = StudentLessonMaterialService(
      stateService: service,
      orchestrator: orchestrator,
      readyWindowEngine: DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      ),
    );

    final result = materialService.resolveFastLessonMaterialFromStateOrCache(
      ResolveLessonMaterialInput(
        lessonLocalId: 'cyber-ready',
        topic: 'Objetivo',
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l1,
        params: params,
        allowRemoteOrder: true,
      ),
    );

    expect(result?.conteudo.question, 'Onde fica a origem?');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(updates.last.imagem, isNull);
    expect(cache.peek(lessonKeyFor(params))?.imagem, isNull);
  });

  test('cached text-only material does not schedule visual route', () async {
    final params = const CompleteLessonParams(
      lessonLocalId: 'cyber-cache',
      item: 'Plano cartesiano',
      lang: 'pt-BR',
      academic: 'fundamental',
      layer: LessonLayer.l1,
      mode: LessonMode.session,
      marker: 'M1',
    );
    final cache = LessonMaterialCache();
    cache.put(
      lessonKeyFor(params),
      CompleteLesson(
        conteudo: LessonContent(
          explanation: 'Veja o plano.',
          question: 'Qual eixo é horizontal?',
          options: const {
            AnswerLetter.A: 'x',
            AnswerLetter.B: 'y',
            AnswerLetter.C: 'z',
          },
          correctAnswer: AnswerLetter.A,
        ),
        imagem: null,
        audioText: 'Veja o plano. Qual eixo é horizontal?',
      ),
    );
    final service = StudentLearningStateService(
      seed: {'cyber-cache': _stateWithCurriculum()},
    );
    final bus = LessonEventBus();
    final updates = <CompleteLesson>[];
    final unsubscribe = bus.subscribe(lessonKeyFor(params), updates.add);
    addTearDown(unsubscribe);
    final orchestrator = LessonOrchestrator(
      t02Client: FakeT02Client(),
      cache: cache,
      bus: bus,
    );
    final materialService = StudentLessonMaterialService(
      stateService: service,
      orchestrator: orchestrator,
      readyWindowEngine: DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      ),
    );

    final result = materialService.resolveFastLessonMaterialFromStateOrCache(
      ResolveLessonMaterialInput(
        lessonLocalId: 'cyber-cache',
        topic: 'Objetivo',
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l1,
        params: params,
        allowRemoteOrder: true,
      ),
    );

    expect(result?.imagem, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(updates, isEmpty);
    expect(cache.peek(lessonKeyFor(params))?.imagem, isNull);
    expect(
      service.read('cyber-cache')?.currentLessonMaterial?['imagem'],
      isNull,
    );
    expect(
      service
          .read('cyber-cache')
          ?.readyLessonMaterials[preparedLessonMaterialKey(
        0,
        'M1',
        LessonLayer.l1,
      )]?['imagem'],
      isNull,
    );
  });

  test('complete-lesson pending image stays text-only in the app', () async {
    const params = CompleteLessonParams(
      lessonLocalId: 'cyber-server-visual',
      item: 'Imagem governada pelo servidor',
      lang: 'pt-BR',
      academic: 'fundamental',
      layer: LessonLayer.l1,
      mode: LessonMode.session,
      marker: 'M1',
    );
    final service = StudentLearningStateService(
      seed: {'cyber-server-visual': _stateWithCurriculum()},
    );
    final cache = LessonMaterialCache();
    final bus = LessonEventBus();
    final orchestrator = LessonOrchestrator(
      t02Client: FakeT02Client(
        source: 'complete-lesson',
        imageStatus: 'processing',
        explanation: 'Texto da aula chega antes da imagem.',
        question: 'O que o App deve fazer?',
        options: const {
          AnswerLetter.A: 'Exibir texto',
          AnswerLetter.B: 'Criar imagem local',
          AnswerLetter.C: 'Mudar progresso',
        },
      ),
      cache: cache,
      bus: bus,
      imageRefreshDelays: const [Duration(milliseconds: 1)],
    );
    final materialService = StudentLessonMaterialService(
      stateService: service,
      orchestrator: orchestrator,
      readyWindowEngine: DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      ),
    );

    final result = await materialService.resolveLessonMaterialFromStateOrEngine(
      ResolveLessonMaterialInput(
        lessonLocalId: 'cyber-server-visual',
        topic: 'Objetivo',
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l1,
        params: params,
        allowRemoteOrder: true,
      ),
    );

    expect(
      result?.conteudo.explanation,
      'Texto da aula chega antes da imagem.',
    );
    expect(result?.imagem, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cache.peek(lessonKeyFor(params))?.imagem, isNull);
  });

  test(
    'complete-lesson pending image is refreshed into the live lesson cache',
    () async {
      const params = CompleteLessonParams(
        lessonLocalId: 'cyber-server-visual-refresh',
        item: 'Imagem chega depois do texto',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
      );
      final t02 = SequenceT02Client([
        T02LessonMaterial(
          explanation: 'Texto pronto antes da imagem.',
          question: 'O que deve acontecer?',
          options: const {
            AnswerLetter.A: 'A imagem entra depois',
            AnswerLetter.B: 'A aula trava',
            AnswerLetter.C: 'O aluno perde progresso',
          },
          correctAnswer: AnswerLetter.A,
          whyCorrect: 'A midia completa a aula em segundo plano.',
          whyWrong: null,
          generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          source: 'complete-lesson',
          imageStatus: 'processing',
        ),
        T02LessonMaterial(
          explanation: 'Texto pronto antes da imagem.',
          question: 'O que deve acontecer?',
          options: const {
            AnswerLetter.A: 'A imagem entra depois',
            AnswerLetter.B: 'A aula trava',
            AnswerLetter.C: 'O aluno perde progresso',
          },
          correctAnswer: AnswerLetter.A,
          whyCorrect: 'A midia completa a aula em segundo plano.',
          whyWrong: null,
          generatedAt: DateTime.fromMillisecondsSinceEpoch(2),
          source: 'complete-lesson',
          imageDataUrl: _serverRasterDataUrl,
          imageStatus: 'ready',
        ),
      ]);
      final cache = LessonMaterialCache();
      final bus = LessonEventBus();
      final updates = <CompleteLesson>[];
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: cache,
        bus: bus,
        imageRefreshDelays: const [Duration(milliseconds: 1)],
        onImageReady: (_, lesson) => updates.add(lesson),
      );

      final first = await orchestrator.prefetchCompleteLesson(
        params,
        priority: 'hot-local',
      );

      expect(first.imagem, isNull);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(t02.calls, 2);
      expect(cache.peek(lessonKeyFor(params))?.imagem, _serverRasterDataUrl);
      expect(updates.single.imagem, _serverRasterDataUrl);
    },
  );

  test('StudentExperienceT02Adapter prepares first minimum lesson', () async {
    final service = StudentLearningStateService(
      seed: {'cyber-ready': _stateWithCurriculum()},
    );
    final t02 = FakeT02Client();
    final orchestrator = LessonOrchestrator(
      t02Client: t02,
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
    final adapter = StudentExperienceT02Adapter(
      service: service,
      materialService: materialService,
    );
    final first = FirstCurriculumItem(
      curriculum: service.read('cyber-ready')!.curriculum!,
      item: service.read('cyber-ready')!.curriculum!.items.first,
      itemIndex: 0,
      marker: 'M1',
    );

    await adapter.prepareFirstMinimumLesson(
      args: const StudentExperienceArgs(
        academic: 'fundamental',
        idioma: 'pt-BR',
        lessonLocalId: 'cyber-ready',
        onboarding: {'objetivo': 'Objetivo'},
      ),
      first: first,
    );

    final state = service.read('cyber-ready');
    expect(state?.current?.marker, 'M1');
    expect(
      readLiveEntryState(service, 'cyber-ready').status,
      LiveEntryStatus.firstLessonReady,
    );
    expect(state?.readyLessonMaterials.values.first['text_status'], 'ready');
    expect(
      state?.events.map((event) => event.type),
      contains('LESSON_TEXT_READY'),
    );
  });

  test(
    'Proposicao F: primeira aula funcional nasce antes de imagem, cache, sync e curriculo gigante',
    () async {
      final service = StudentLearningStateService();
      final releaseFinalCurriculum = Completer<void>();
      final releaseCacheHydrate = Completer<void>();
      final t00 = GiantCurriculumT00Client(
        releaseFinal: releaseFinalCurriculum,
      );
      final t02 = FastStartT02Client();
      final cache = BlockingHydrateCache(releaseHydrate: releaseCacheHydrate);
      var syncStarted = false;
      final syncRelease = Completer<void>();
      service.subscribe((lessonLocalId) {
        if (lessonLocalId == 'cyber-fast-start') {
          syncStarted = true;
          unawaited(syncRelease.future);
        }
      });
      unawaited(cache.hydrate());

      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: cache,
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
      final materialController = LessonMaterialController(
        stateService: service,
        materialService: materialService,
      );
      final engine = StudentExperienceEngine(
        service: service,
        t00: StudentExperienceT00Adapter(service: service, client: t00),
        t02: StudentExperienceT02Adapter(
          service: service,
          materialService: materialService,
        ),
        placement: const SettledPlacementReader(settled: true),
      );

      final result = await engine.prepareStudentExperienceEntry(
        const StudentExperienceArgs(
          academic: 'fundamental',
          idioma: 'pt-BR',
          lessonLocalId: 'cyber-fast-start',
          onboarding: {
            'objetivo': 'Aprender frações no celular fraco',
            'academic_level': 'fundamental',
          },
        ),
      );

      expect(result.destination, '/cyber/aula');
      expect(cache.hydrateStarted, isTrue);
      expect(releaseCacheHydrate.isCompleted, isFalse);
      expect(releaseFinalCurriculum.isCompleted, isFalse);
      expect(syncStarted, isTrue);

      await _waitUntil(
        () =>
            service
                .read('cyber-fast-start')
                ?.currentLessonMaterial?['text_status'] ==
            'ready',
      );
      final state = service.read('cyber-fast-start')!;
      expect(state.curriculum?.items, hasLength(1));
      expect(state.current?.marker, 'M1');
      expect(state.currentLessonMaterial?['explanation'], isNotEmpty);
      expect(state.currentLessonMaterial?['question'], isNotEmpty);
      expect(state.currentLessonMaterial?['options'], isA<Map>());
      expect(state.currentLessonMaterial?['imagem'], isNull);
      expect(state.progress?.itemIdx, 0);
      expect(state.progress?.layer, LessonLayer.l1);
      expect(
        state.events.map((event) => event.type),
        contains('LESSON_TEXT_READY'),
      );
      expect(
        state.events
            .where((event) => event.type == 'PROGRESS_UPDATED')
            .map((event) => event.payload['event']),
        containsAll([
          't00FirstItemReceived',
          'firstLessonShellOpened',
          't02FirstMinimumLessonReady',
          'timeToFirstQuestion',
        ]),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        cache
            .peekCachedLesson(
              lessonKeyFor(
                const CompleteLessonParams(
                  lessonLocalId: 'cyber-fast-start',
                  item: 'Entender metade rapidamente',
                  lang: 'pt-BR',
                  academic: 'fundamental',
                  layer: LessonLayer.l1,
                  mode: LessonMode.session,
                  marker: 'M1',
                  topic: 'Aprender frações no celular fraco',
                  itemIdx: 0,
                ),
              ),
            )
            ?.imagem,
        isNull,
      );

      final runtime = LessonRuntimeEngine(
        stateService: service,
        sessionEngine: LessonSessionEngine(service: service),
        hydrationEngine: LessonHydrationEngine(
          materialService: materialService,
        ),
        positionEngine: LessonPositionEngine(),
        materialController: materialController,
        answerController: LessonAnswerProgressController(
          stateService: service,
          materialService: materialService,
          materialController: materialController,
        ),
      );
      var snap = await runtime.open(
        lessonLocalId: 'cyber-fast-start',
        authReady: true,
        authed: true,
      );
      expect(snap.phase.type, ClassroomPhaseType.lendo);
      expect(snap.conteudo?.question, 'Qual alternativa representa metade?');
      runtime.select(AnswerLetter.A);
      snap = runtime.snapshot();
      expect(snap.phase.type, ClassroomPhaseType.expandida);
      expect(snap.phase.letter, AnswerLetter.A);

      releaseCacheHydrate.complete();
      syncRelease.complete();
      releaseFinalCurriculum.complete();
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'Teste 1: onboarding abre primeira aula no primeiro parcial e prepara B/C em background',
    () async {
      final service = StudentLearningStateService();
      final releaseFinal = Completer<void>();
      final t00 = AuditT00Client(releaseFinal: releaseFinal);
      final t02 = AuditT02Client();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
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
      final engine = StudentExperienceEngine(
        service: service,
        t00: StudentExperienceT00Adapter(service: service, client: t00),
        t02: StudentExperienceT02Adapter(
          service: service,
          materialService: materialService,
        ),
        placement: const SettledPlacementReader(settled: true),
      );

      final result = await engine.prepareStudentExperienceEntry(
        const StudentExperienceArgs(
          academic: 'fundamental',
          idioma: 'pt-BR',
          lessonLocalId: 'cyber-audit-1',
          onboarding: {
            'objetivo': 'Aprender frações',
            'stable_lang': 'pt-BR',
            'academic_level': 'fundamental',
            'preferred_name': 'Ana',
            'student_profile_internal': {'pace': 'visual'},
          },
        ),
      );

      expect(result.destination, '/cyber/aula');
      expect(t00.requests, hasLength(1));
      await _waitUntil(() => t02.requests.isNotEmpty);
      expect(t02.requests, isNotEmpty);
      final firstRequest = t02.requests.first;
      expect(firstRequest.item, 'Entender metade e um quarto');
      expect(firstRequest.marker, 'M1');
      expect(firstRequest.layer, LessonLayer.l1);
      expect(firstRequest.lang, 'pt-BR');
      expect(firstRequest.academic, 'fundamental');
      expect(firstRequest.profile['stable_lang'], 'pt-BR');
      expect(firstRequest.profile['academic_level'], 'fundamental');
      expect(firstRequest.profile['student_profile_internal'], {
        'pace': 'visual',
      });

      final openedState = service.read('cyber-audit-1');
      final openedProgressEvents = openedState?.events
          .where((event) => event.type == 'PROGRESS_UPDATED')
          .map((event) => event.payload['event'])
          .toList();
      expect(openedState?.curriculum?.items, hasLength(1));
      expect(openedState?.current?.marker, 'M1');
      expect(
        openedProgressEvents,
        isNot(contains('t00FinalCurriculumReceived')),
      );
      expect(openedProgressEvents, contains('t00FirstItemReceived'));
      expect(openedProgressEvents, contains('firstLessonShellOpened'));
      expect(openedProgressEvents, contains('timeToClassroom'));

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final readyState = service.read('cyber-audit-1');
      expect(readyState?.currentLessonMaterial?['text_status'], 'ready');
      expect(
        readyState?.events.map((event) => event.type),
        contains('BACKGROUND_READY_WINDOW_STARTED'),
      );

      expect(
        t02.requests.where((request) => request.layer == LessonLayer.l2),
        hasLength(1),
      );

      t02.l2.complete(t02._material(t02.requests.last));
      await Future<void>.delayed(Duration.zero);
      expect(
        t02.requests.where((request) => request.layer == LessonLayer.l3),
        hasLength(1),
      );
      t02.l3.complete(t02._material(t02.requests.last));
      await Future<void>.delayed(Duration.zero);

      final beforeFinal = service.read('cyber-audit-1');
      final beforeFinalProgressEvents = beforeFinal?.events
          .where((event) => event.type == 'PROGRESS_UPDATED')
          .map((event) => event.payload['event'])
          .toList();
      expect(
        beforeFinalProgressEvents,
        isNot(contains('t00FinalCurriculumReceived')),
      );
      expect(
        beforeFinal?.readyLessonMaterials.keys,
        containsAll([
          preparedLessonMaterialKey(0, 'M1', LessonLayer.l1),
          preparedLessonMaterialKey(0, 'M1', LessonLayer.l2),
          preparedLessonMaterialKey(0, 'M1', LessonLayer.l3),
        ]),
      );

      releaseFinal.complete();
    },
  );

  test('onboarding abre sala antes do T02 minimo concluir', () async {
    final service = StudentLearningStateService();
    final releaseFinal = Completer<void>();
    final t00 = AuditT00Client(releaseFinal: releaseFinal);
    final t02 = SlowFirstT02Client();
    final orchestrator = LessonOrchestrator(
      t02Client: t02,
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
    );
    final materialService = StudentLessonMaterialService(
      stateService: service,
      orchestrator: orchestrator,
      readyWindowEngine: DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      ),
    );
    final engine = StudentExperienceEngine(
      service: service,
      t00: StudentExperienceT00Adapter(service: service, client: t00),
      t02: StudentExperienceT02Adapter(
        service: service,
        materialService: materialService,
      ),
      placement: const SettledPlacementReader(settled: true),
    );

    final resultFuture = engine.prepareStudentExperienceEntry(
      const StudentExperienceArgs(
        academic: 'fundamental',
        idioma: 'pt-BR',
        lessonLocalId: 'cyber-rocket',
        onboarding: {
          'objetivo': 'Aprender frações',
          'academic_level': 'fundamental',
        },
      ),
    );

    await _waitUntil(() => t02.requests.isNotEmpty);
    expect(t02.requests, hasLength(1));
    var completedBeforeT02 = false;
    unawaited(resultFuture.then((_) => completedBeforeT02 = true));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(completedBeforeT02, isTrue);

    final result = await resultFuture;
    expect(result.destination, '/cyber/aula');

    final waiting = service.read('cyber-rocket');
    expect(waiting?.current?.marker, 'M1');
    expect(waiting?.currentLessonMaterial, isNull);
    expect(
      readLiveEntryState(service, 'cyber-rocket').status,
      LiveEntryStatus.showingFirstLesson,
    );

    t02.firstLesson.complete(t02._material(t02.requests.first));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      t02.requests.where((request) => request.layer == LessonLayer.l1),
      hasLength(1),
    );
    final ready = service.read('cyber-rocket');
    expect(ready?.current?.marker, 'M1');
    expect(ready?.currentLessonMaterial?['text_status'], 'ready');
    final readyEvents = ready?.events
        .where((event) => event.type == 'PROGRESS_UPDATED')
        .map((event) => event.payload['event'])
        .toList();
    expect(readyEvents, contains('firstLessonShellOpened'));
    expect(readyEvents, contains('t02FirstLessonStarted'));
    expect(readyEvents, contains('t02FirstMinimumLessonReady'));
    expect(readyEvents, contains('timeToFirstQuestion'));
    expect(
      readLiveEntryState(service, 'cyber-rocket').status,
      LiveEntryStatus.showingFirstLesson,
    );
    releaseFinal.complete();
  });

  test('placement so aparece depois da primeira aula minima', () async {
    final service = StudentLearningStateService();
    final releaseFinal = Completer<void>();
    final t00 = AuditT00Client(releaseFinal: releaseFinal);
    final t02 = SlowFirstT02Client();
    final orchestrator = LessonOrchestrator(
      t02Client: t02,
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
    );
    final materialService = StudentLessonMaterialService(
      stateService: service,
      orchestrator: orchestrator,
      readyWindowEngine: DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      ),
    );
    final engine = StudentExperienceEngine(
      service: service,
      t00: StudentExperienceT00Adapter(service: service, client: t00),
      t02: StudentExperienceT02Adapter(
        service: service,
        materialService: materialService,
      ),
      placement: const SettledPlacementReader(settled: false),
    );

    final resultFuture = engine.prepareStudentExperienceEntry(
      const StudentExperienceArgs(
        academic: 'fundamental',
        idioma: 'pt-BR',
        lessonLocalId: 'cyber-no-placement-block',
        onboarding: {'objetivo': 'Aprender frações'},
      ),
    );

    await _waitUntil(() => t02.requests.isNotEmpty);
    var completedBeforeT02 = false;
    unawaited(resultFuture.then((_) => completedBeforeT02 = true));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(completedBeforeT02, isTrue);
    final result = await resultFuture;
    expect(result.destination, '/cyber/placement');

    t02.firstLesson.complete(t02._material(t02.requests.first));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    final events = service
        .read('cyber-no-placement-block')
        ?.events
        .where((event) => event.type == 'PROGRESS_UPDATED')
        .map((event) => event.payload['event'])
        .toList();
    expect(events, contains('placementRequired'));
    expect(events, contains('placementScreenReleasedAfterSlotA'));
    expect(events, isNot(contains('firstLessonShellOpened')));
    expect(
      t02.requests.where((request) => request.layer == LessonLayer.l1),
      hasLength(1),
    );
    releaseFinal.complete();
  });

  test('M-EXP3: health reports fifteen textual slots and media pending', () {
    const lessonId = 'cyber-window-health';
    final prepared = preparedMaterialFromLesson(
      lesson: const CompleteLesson(
        conteudo: LessonContent(
          explanation: 'Texto pronto sem imagem.',
          question: 'Pergunta pronta?',
          options: {
            AnswerLetter.A: 'A',
            AnswerLetter.B: 'B',
            AnswerLetter.C: 'C',
          },
          correctAnswer: AnswerLetter.A,
        ),
        imagem: null,
        audioText: 'Texto pronto sem imagem. Pergunta pronta?',
      ),
      itemIdx: 0,
      marker: 'M1',
      layer: LessonLayer.l1,
    );
    final service = StudentLearningStateService(
      seed: {
        lessonId: _stateWithFiveItems().copyWith(
          lessonLocalId: lessonId,
          readyLessonMaterials: {
            preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): prepared,
          },
        ),
      },
    );
    final orchestrator = LessonOrchestrator(
      t02Client: FakeT02Client(),
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
    );
    final engine = DopamineReadyWindowEngine(
      service: service,
      orchestrator: orchestrator,
    );
    final items = List<DopamineWindowItem>.generate(
      5,
      (index) => DopamineWindowItem(
        text: 'Item ${index + 1}',
        marker: 'M${index + 1}',
      ),
    );
    final slots = engine.buildDopamineReadySlots(
      lessonLocalId: lessonId,
      source: 'health-test',
      items: items,
      currentItemIdx: 0,
      currentLayer: LessonLayer.l1,
      buildParams: (item, layer) => CompleteLessonParams(
        lessonLocalId: lessonId,
        item: item.text,
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: layer,
        mode: LessonMode.session,
        marker: item.marker,
        itemIdx: items.indexOf(item),
      ),
    );

    final health = engine.inspectDopamineReadyWindow(
      lessonLocalId: lessonId,
      slots: slots,
      source: 'health-test',
    );

    expect(health.expectedCount, localLessonTraySize);
    expect(health.readyCount, 1);
    expect(health.hotTextReadyCount, 1);
    expect(health.mediaPendingCount, 1);
    expect(health.missingSlots, hasLength(localLessonTraySize - 1));
    expect(health.windowStart?['marker'], 'M1');
    expect(health.windowStart?['layer'], LessonLayer.l1.value);
  });

  test('M-EXP3: one-item curriculum expects only three real slots', () {
    const lessonId = 'cyber-small-window-health';
    final service = StudentLearningStateService();
    service.ensure(lessonLocalId: lessonId);
    final orchestrator = LessonOrchestrator(
      t02Client: FakeT02Client(),
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
    );
    final engine = DopamineReadyWindowEngine(
      service: service,
      orchestrator: orchestrator,
    );
    final slots = engine.buildDopamineReadySlots(
      lessonLocalId: lessonId,
      source: 'small-health',
      items: const [DopamineWindowItem(text: 'Item unico', marker: 'M1')],
      currentItemIdx: 0,
      currentLayer: LessonLayer.l1,
      buildParams: (item, layer) => CompleteLessonParams(
        lessonLocalId: lessonId,
        item: item.text,
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: layer,
        mode: LessonMode.session,
        marker: item.marker,
        itemIdx: 0,
      ),
    );

    final health = engine.inspectDopamineReadyWindow(
      lessonLocalId: lessonId,
      slots: slots,
      source: 'small-health',
    );

    expect(slots.map((slot) => slot.layer), [
      LessonLayer.l1,
      LessonLayer.l2,
      LessonLayer.l3,
    ]);
    expect(health.expectedCount, 3);
    expect(health.missingSlots, hasLength(3));
  });

  test(
    'M-EXP3: stale wrong slot is discarded through readiness resolver',
    () async {
      const lessonId = 'cyber-stale-window';
      final wrong = preparedMaterialFromLesson(
        lesson: const CompleteLesson(
          conteudo: LessonContent(
            explanation: 'Texto errado.',
            question: 'Pergunta errada?',
            options: {
              AnswerLetter.A: 'A',
              AnswerLetter.B: 'B',
              AnswerLetter.C: 'C',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: null,
          audioText: 'Texto errado.',
        ),
        itemIdx: 0,
        marker: 'M1',
        layer: LessonLayer.l2,
      );
      final service = StudentLearningStateService(
        seed: {
          lessonId: _stateWithFiveItems().copyWith(
            lessonLocalId: lessonId,
            readyLessonMaterials: {
              preparedLessonMaterialKey(0, 'M1', LessonLayer.l1): wrong,
            },
          ),
        },
      );
      final t02 = FakeT02Client();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
      );
      final engine = DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      );

      final result = await engine.runDopamineReadyWindowFromStudentState(
        lessonLocalId: lessonId,
        source: 'stale-test',
        maxSlots: 1,
      );

      expect(result, [true]);
      expect(t02.calls, 1);
      final key = preparedLessonMaterialKey(0, 'M1', LessonLayer.l1);
      expect(
        service.read(lessonId)!.readyLessonMaterials[key]?['for_layer'],
        'l1',
      );
      expect(
        service
            .read(lessonId)!
            .events
            .where(
              (event) => event.type == 'DOPAMINE_WINDOW_SLOT_STALE_DISCARDED',
            ),
        hasLength(1),
      );
    },
  );

  test(
    'M-EXP3: hot-local textual request is not blocked by old background',
    () async {
      final t02 = BackgroundGateT02Client();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
      );
      const backgroundParams = CompleteLessonParams(
        lessonLocalId: 'cyber-hot-bypass',
        item: 'Item 1',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
        itemIdx: 0,
      );
      const hotParams = CompleteLessonParams(
        lessonLocalId: 'cyber-hot-bypass',
        item: 'Item 1',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l2,
        mode: LessonMode.session,
        marker: 'M1',
        itemIdx: 0,
      );

      final background = orchestrator.prefetchCompleteLesson(
        backgroundParams,
        priority: 'background',
        deferMedia: true,
      );
      await t02.backgroundStarted.future;
      final hot = await orchestrator
          .prefetchCompleteLesson(
            hotParams,
            priority: 'hot-local',
            deferMedia: true,
          )
          .timeout(const Duration(milliseconds: 300));

      expect(hot.conteudo.question, contains('l2'));
      expect(
        t02.requests.map((request) => request.layer).toList(),
        containsAllInOrder([LessonLayer.l1, LessonLayer.l2]),
      );
      t02.releaseBackground.complete();
      await background;
    },
  );
}
