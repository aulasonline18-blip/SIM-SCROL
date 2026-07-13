import 'dart:async';
import 'dart:convert';

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
  Future<void> hydrate() async {
    hydrateStarted = true;
    await releaseHydrate.future;
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

void main() {
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
        priority: 'active',
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

      await orchestrator.prefetchCompleteLesson(params, priority: 'active');
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

      await orchestrator.prefetchCompleteLesson(params, priority: 'active');
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
        priority: 'active',
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

      await orchestrator.prefetchCompleteLesson(params, priority: 'active');
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

    await orchestrator.prefetchCompleteLesson(params, priority: 'active');
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
        priority: 'active',
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
        priority: 'active',
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

  test('DopamineReadyWindowEngine prepares A/B/C/D slots from state', () async {
    final service = StudentLearningStateService(
      seed: {'cyber-ready': _stateWithCurriculum()},
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
      maxSlots: 4,
    );

    expect(result, [true, true, true, true]);
    expect(t02.calls, 4);
    expect(service.read('cyber-ready')?.readyLessonMaterials.length, 4);
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
    expect(event?.payload['currentItemIdx'], 0);
    expect(event?.payload['currentLayer'], 1);
    expect(event?.payload['windowSize'], 4);
    expect(event?.payload['cachedCount'], 4);
    expect(event?.payload['windowMarkers'], [
      {'marker': 'M1', 'layer': 1, 'offset': 0},
      {'marker': 'M1', 'layer': 2, 'offset': 1},
      {'marker': 'M1', 'layer': 3, 'offset': 2},
      {'marker': 'M2', 'layer': 1, 'offset': 3},
    ]);
  });

  test(
    'ready window from L3 keeps next item L1/L2/L3 possible experiences',
    () {
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
      expect(event?.payload['windowSize'], 4);
      expect(event?.payload['windowMarkers'], [
        {'marker': 'M1', 'layer': 3, 'offset': 0},
        {'marker': 'M2', 'layer': 1, 'offset': 1},
        {'marker': 'M2', 'layer': 2, 'offset': 2},
        {'marker': 'M2', 'layer': 3, 'offset': 3},
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
        source: 'test-window',
        items: const [
          DopamineWindowItem(text: 'Item 1', marker: 'M1'),
          DopamineWindowItem(text: 'Item 2', marker: 'M2'),
        ],
      );
    }

    final state = service.read('cyber-window-dedupe');
    expect(state?.queuedActions, hasLength(1));
    expect(
      state?.queuedActions.single['idempotency_key'],
      'test-window:cyber-window-dedupe:0:L1',
    );
    expect(
      state?.events.where((event) => event.type == 'CACHE_WINDOW_UPDATED'),
      hasLength(2),
    );
  });

  test(
    'loaded active lesson keeps current plus three next slots queued',
    () async {
      final service = StudentLearningStateService();
      service.ensure(lessonLocalId: 'cyber-loaded-window');
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
      expect(state?.queuedActions.single['type'], 'PREPARE_READY_WINDOW');
      expect(state?.queuedActions.single['source'], 'cyber.aula.loaded-window');
      final event = state?.events.lastWhere(
        (event) => event.type == 'CACHE_WINDOW_UPDATED',
      );
      expect(event?.payload['windowSize'], 4);
      expect(event?.payload['windowMarkers'], [
        {'marker': 'M1', 'layer': 1, 'offset': 0},
        {'marker': 'M1', 'layer': 2, 'offset': 1},
        {'marker': 'M1', 'layer': 3, 'offset': 2},
        {'marker': 'M2', 'layer': 1, 'offset': 3},
      ]);
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

  test('server-classroom pending image stays text-only in the app', () async {
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
        source: 'server-classroom',
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
    'server-classroom pending image is refreshed into the live lesson cache',
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
          source: 'server-classroom',
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
          source: 'server-classroom',
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
        priority: 'active',
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

  test(
    'onboarding abre sala antes do T02 lento terminar e preenche depois',
    () async {
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

      final result = await engine.prepareStudentExperienceEntry(
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

      expect(result.destination, '/cyber/aula');
      expect(t02.requests, hasLength(1));
      final shell = service.read('cyber-rocket');
      expect(shell?.current?.marker, 'M1');
      expect(shell?.currentLessonMaterial, isNull);
      final shellEvents = shell?.events
          .where((event) => event.type == 'PROGRESS_UPDATED')
          .map((event) => event.payload['event'])
          .toList();
      expect(shellEvents, contains('firstLessonShellOpened'));
      expect(shellEvents, contains('t02FirstLessonStarted'));
      expect(
        readLiveEntryState(service, 'cyber-rocket').status,
        LiveEntryStatus.showingFirstLesson,
      );

      t02.firstLesson.complete(t02._material(t02.requests.first));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final ready = service.read('cyber-rocket');
      expect(ready?.currentLessonMaterial?['text_status'], 'ready');
      final readyEvents = ready?.events
          .where((event) => event.type == 'PROGRESS_UPDATED')
          .map((event) => event.payload['event'])
          .toList();
      expect(readyEvents, contains('t02FirstMinimumLessonReady'));
      expect(readyEvents, contains('timeToFirstQuestion'));
      releaseFinal.complete();
    },
  );

  test(
    'placement aparece quando necessario enquanto primeiro minimo prepara em background',
    () async {
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

      final result = await engine.prepareStudentExperienceEntry(
        const StudentExperienceArgs(
          academic: 'fundamental',
          idioma: 'pt-BR',
          lessonLocalId: 'cyber-no-placement-block',
          onboarding: {'objetivo': 'Aprender frações'},
        ),
      );

      expect(result.destination, '/cyber/placement');
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
      expect(t02.requests, hasLength(1));
      t02.firstLesson.complete(t02._material(t02.requests.first));
      releaseFinal.complete();
    },
  );
}
