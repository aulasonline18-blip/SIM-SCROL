import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_visual_pipeline.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/sim/experience/student_experience_engine.dart';
import 'package:sim_mobile/sim/experience/student_experience_t00_adapter.dart';
import 'package:sim_mobile/sim/experience/student_experience_t02_adapter.dart';
import 'package:sim_mobile/sim/experience/student_experience_types.dart';
import 'package:sim_mobile/sim/lesson/dopamine_ready_window_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/media/lesson_visual_pipeline.dart';
import 'package:sim_mobile/sim/lesson/student_lesson_material_service.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/live_entry_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

class FakeT02Client implements T02LessonClient {
  FakeT02Client({
    this.visualTrigger,
    this.explanation,
    this.question,
    this.options,
  });

  final JsonMap? visualTrigger;
  final String? explanation;
  final String? question;
  final Map<AnswerLetter, String>? options;
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
      source: 'fake-t02',
      visualTrigger: visualTrigger,
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

class _StaleThenSvgVisualPipeline extends LessonVisualPipeline {
  _StaleThenSvgVisualPipeline({required this.releaseFirst})
    : super(
        imageClient: const FakeNoopImageClient(),
        visualRouterClient: const FakeVisualRouterClient(),
      );

  final Completer<void> releaseFirst;
  int calls = 0;
  final prompts = <String?>[];

  @override
  Future<LessonVisualResult> resolveVisual({
    required LessonVisualTrigger trigger,
    required String lessonKey,
    String? stableLang,
    String? academicLevel,
    bool allowPaidImages = false,
    String? acceptedOfferId,
    String? idempotencyKey,
  }) async {
    calls += 1;
    prompts.add(trigger.imagePrompt);
    if (calls == 1) {
      await releaseFirst.future;
      return const LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'skip_no_offer',
      );
    }
    return const LessonVisualResult(
      svg:
          'data:image/svg+xml;utf8,%3Csvg%20viewBox%3D%220%200%2010%2010%22%3E%3Ctext%3Equadratic%3C%2Ftext%3E%3C%2Fsvg%3E',
      dataUrl: null,
      source: 'local_software',
    );
  }
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
    'LessonOrchestrator carries T02 visual_trigger into free SVG image',
    () async {
      final trigger = <String, dynamic>{
        'needs_image': true,
        'pedagogical_need': 'helpful',
        'render_strategy': 'software',
        'svg_payload':
            '<svg viewBox="0 0 10 10"><rect width="10" height="10"/></svg>',
      };
      final cache = LessonMaterialCache();
      final bus = LessonEventBus();
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(visualTrigger: trigger),
        cache: cache,
        bus: bus,
        visualPipeline: fakeVisualPipeline(),
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

      expect(textLesson.conteudo.visualTrigger, trigger);
      expect(updates.first.conteudo.visualTrigger, trigger);
      final rendered = updates.last.imagem;
      expect(rendered, startsWith('data:image/svg+xml;utf8,'));
      expect(rendered, contains('%3Csvg'));
    },
  );

  test(
    'LessonOrchestrator uses local software before paid offer for quadratic lesson',
    () async {
      final trigger = <String, dynamic>{
        'needs_image': true,
        'pedagogical_need': 'important',
        'render_strategy': 'ai',
        'topic': 'apoio visual',
        'image_prompt': 'criar imagem de apoio para a aula',
      };
      final cache = LessonMaterialCache();
      final bus = LessonEventBus();
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(
          visualTrigger: trigger,
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
        visualPipeline: fakeVisualPipeline(),
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
      final offers = <LessonPaidImageOffer?>[];
      final unsubscribeOffer = bus.subscribePaidImageOffer(key, offers.add);
      addTearDown(unsubscribeOffer);
      final updates = <CompleteLesson>[];
      final unsubscribeLesson = bus.subscribe(key, updates.add);
      addTearDown(unsubscribeLesson);

      await orchestrator.prefetchCompleteLesson(params, priority: 'active');
      await Future<void>.delayed(Duration.zero);

      final rendered = updates.last.imagem;
      expect(rendered, startsWith('data:image/svg+xml;utf8,'));
      expect(cache.peek(key)?.imagem, rendered);
      expect(offers.whereType<LessonPaidImageOffer>(), isEmpty);
    },
  );

  test(
    'LessonOrchestrator uses lesson text over stale prompt for h(t) physics graph',
    () async {
      final stalePrompt = List.filled(
        90,
        'foto realista genérica de apoio visual sem fórmula nem eixo',
      ).join(' ');
      final trigger = <String, dynamic>{
        'needs_image': true,
        'pedagogical_need': 'important',
        'visual_type': 'photo',
        'topic': 'apoio visual',
        'image_prompt': stalePrompt,
      };
      final cache = LessonMaterialCache();
      final bus = LessonEventBus();
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(
          visualTrigger: trigger,
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
        visualPipeline: fakeVisualPipeline(),
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
      final offers = <LessonPaidImageOffer?>[];
      final unsubscribeOffer = bus.subscribePaidImageOffer(key, offers.add);
      addTearDown(unsubscribeOffer);
      final updates = <CompleteLesson>[];
      final unsubscribeLesson = bus.subscribe(key, updates.add);
      addTearDown(unsubscribeLesson);

      await orchestrator.prefetchCompleteLesson(params, priority: 'active');
      await Future<void>.delayed(Duration.zero);

      final rendered = updates.last.imagem;
      expect(rendered, startsWith('data:image/svg+xml;utf8,'));
      expect(rendered, contains('Par%C3%A1bola'));
      expect(cache.peek(key)?.imagem, rendered);
      expect(offers.whereType<LessonPaidImageOffer>(), isEmpty);
    },
  );

  test(
    'LessonOrchestrator ignores stale image decision after lesson content refresh',
    () async {
      final staleTrigger = <String, dynamic>{
        'needs_image': true,
        'pedagogical_need': 'important',
        'topic': 'foto realista',
        'visual_type': 'photo',
        'image_prompt': 'foto realista de apoio',
      };
      final freshTrigger = <String, dynamic>{
        'needs_image': true,
        'pedagogical_need': 'important',
        'topic': 'apoio visual',
        'image_prompt': 'criar imagem de apoio para a aula',
      };
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
            visualTrigger: staleTrigger,
          ),
          imagem: null,
          audioText: 'material antigo',
        ),
      );
      final bus = LessonEventBus();
      final releaseFirst = Completer<void>();
      final pipeline = _StaleThenSvgVisualPipeline(releaseFirst: releaseFirst);
      final t02 = FakeT02Client(
        visualTrigger: freshTrigger,
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
        visualPipeline: pipeline,
      );
      final offers = <LessonPaidImageOffer?>[];
      final unsubscribeOffer = bus.subscribePaidImageOffer(key, offers.add);
      addTearDown(unsubscribeOffer);
      final updates = <CompleteLesson>[];
      final unsubscribeLesson = bus.subscribe(key, updates.add);
      addTearDown(unsubscribeLesson);

      await orchestrator.prefetchCompleteLesson(params);
      await Future<void>.delayed(Duration.zero);
      expect(pipeline.calls, 1);

      await orchestrator.prefetchCompleteLesson(
        params,
        priority: 'active',
        forceRefresh: true,
      );
      expect(t02.calls, 1);
      expect(cache.peek(key)?.conteudo.question, contains('função quadrática'));

      releaseFirst.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(pipeline.calls, 2);
      expect(offers.whereType<LessonPaidImageOffer>(), isEmpty);
      expect(cache.peek(key)?.conteudo.question, contains('função quadrática'));
      expect(cache.peek(key)?.imagem, startsWith('data:image/svg+xml;utf8,'));
      expect(updates.last.imagem, cache.peek(key)?.imagem);
      expect(pipeline.prompts.first, contains('Pergunta antiga'));
      expect(pipeline.prompts.last, contains('função quadrática'));
    },
  );

  test(
    'LessonOrchestrator schedules fresh image funnel from cached text',
    () async {
      final trigger = <String, dynamic>{
        'needs_image': true,
        'pedagogical_need': 'important',
        'render_strategy': 'ai',
        'topic': 'apoio visual',
        'image_prompt': 'criar imagem de apoio para a aula',
      };
      final cache = LessonMaterialCache();
      final bus = LessonEventBus();
      final t02 = FakeT02Client();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: cache,
        bus: bus,
        visualPipeline: fakeVisualPipeline(),
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
      final offers = <LessonPaidImageOffer?>[];
      final unsubscribeOffer = bus.subscribePaidImageOffer(key, offers.add);
      addTearDown(unsubscribeOffer);
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
            visualTrigger: trigger,
          ),
          imagem: null,
          audioText: 'texto',
        ),
      );

      await orchestrator.prefetchCompleteLesson(params, priority: 'active');
      await Future<void>.delayed(Duration.zero);

      final rendered = updates.last.imagem;
      expect(t02.calls, 0);
      expect(rendered, startsWith('data:image/svg+xml;utf8,'));
      expect(cache.peek(key)?.imagem, rendered);
      expect(offers.whereType<LessonPaidImageOffer>(), isEmpty);
    },
  );

  test(
    'LessonOrchestrator renders math_template from visual_trigger',
    () async {
      final trigger = <String, dynamic>{
        'needs_image': true,
        'pedagogical_need': 'important',
        'render_strategy': 'software',
        'topic': 'função linear',
        'math_template': {
          'name': 'linear_function',
          'params': {
            'a': 2,
            'b': 1,
            'x_min': -3,
            'x_max': 3,
            'labels': {'title': 'y = 2x + 1'},
          },
        },
      };
      final cache = LessonMaterialCache();
      final bus = LessonEventBus();
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(visualTrigger: trigger),
        cache: cache,
        bus: bus,
        visualPipeline: fakeVisualPipeline(),
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

      final rendered = updates.last.imagem;
      expect(rendered, startsWith('data:image/svg+xml;utf8,'));
      expect(Uri.decodeComponent(rendered!), contains('y = 2'));
    },
  );

  test(
    'LessonOrchestrator publishes paid image offer by key after software funnel',
    () async {
      final trigger = <String, dynamic>{
        'needs_image': true,
        'pedagogical_need': 'important',
        'render_strategy': 'ai',
        'topic': 'foto realista de um coracao humano',
        'visual_type': 'anatomy',
        'image_prompt': 'foto realista de um coracao humano',
      };
      final cache = LessonMaterialCache();
      final bus = LessonEventBus();
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(visualTrigger: trigger),
        cache: cache,
        bus: bus,
        visualPipeline: fakeVisualPipeline(),
      );
      const params = CompleteLessonParams(
        lessonLocalId: 'cyber-paid-offer',
        item: 'Coracao humano',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
      );
      final key = lessonKeyFor(params);
      final offers = <LessonPaidImageOffer?>[];
      final unsubscribe = bus.subscribePaidImageOffer(key, offers.add);
      addTearDown(unsubscribe);
      final updates = <CompleteLesson>[];
      final unsubscribeLesson = bus.subscribe(key, updates.add);
      addTearDown(unsubscribeLesson);

      await orchestrator.prefetchCompleteLesson(params, priority: 'active');
      await Future<void>.delayed(Duration.zero);

      expect(cache.peek(key)?.imagem, isNull);
      expect(offers, isNotEmpty);
      expect(offers.last?.lessonKey, key);
      expect(offers.last?.offerId, startsWith('img_offer_'));
      expect(offers.last?.creditCost, 10);
      expect(offers.last?.prompt, contains('coracao humano'));
    },
  );

  test(
    'LessonOrchestrator can reset declined paid image offer by lesson key',
    () async {
      final trigger = <String, dynamic>{
        'needs_image': true,
        'pedagogical_need': 'important',
        'render_strategy': 'ai',
        'topic': 'foto realista de um coracao humano',
        'visual_type': 'anatomy',
        'image_prompt': 'foto realista de um coracao humano',
      };
      final cache = LessonMaterialCache();
      final bus = LessonEventBus();
      final paidPng =
          'data:image/png;base64,${base64Encode(img.encodePng(img.Image(width: 2, height: 2)))}';
      var paidCalls = 0;
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(visualTrigger: trigger),
        cache: cache,
        bus: bus,
        visualPipeline: fakeVisualPipeline(
          paidImageDataUrl: paidPng,
          onPaidImageGenerate: () => paidCalls += 1,
        ),
      );
      const params = CompleteLessonParams(
        lessonLocalId: 'cyber-paid-offer-reset',
        item: 'Coracao humano',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
      );
      final key = lessonKeyFor(params);
      final offers = <LessonPaidImageOffer?>[];
      final unsubscribe = bus.subscribePaidImageOffer(key, offers.add);
      addTearDown(unsubscribe);
      final updates = <CompleteLesson>[];
      final unsubscribeLesson = bus.subscribe(key, updates.add);
      addTearDown(unsubscribeLesson);

      await orchestrator.prefetchCompleteLesson(params, priority: 'active');
      await Future<void>.delayed(Duration.zero);
      expect(offers.whereType<LessonPaidImageOffer>(), hasLength(1));

      orchestrator.declinePaidImageOffer(key);
      await orchestrator.prefetchCompleteLesson(
        params,
        priority: 'active',
        forceRefresh: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(offers.whereType<LessonPaidImageOffer>(), hasLength(1));

      orchestrator.resetDeclinedPaidImageOffer(key);
      await Future<void>.delayed(Duration.zero);
      expect(offers.whereType<LessonPaidImageOffer>(), hasLength(2));

      final metadata = await orchestrator.acceptPaidImageOffer(key);
      expect(paidCalls, 1);
      expect(updates.last.imagem, startsWith('data:image/jpeg;base64,'));
      expect(cache.peek(key)?.imagem, updates.last.imagem);

      final replayMetadata = await orchestrator.acceptPaidImageOffer(key);
      expect(paidCalls, 1);
      expect(replayMetadata, metadata);
      expect(updates.last.imagem, cache.peek(key)?.imagem);
    },
  );

  test(
    'LessonEventBus replays pending paid image offer to late subscriber',
    () {
      final bus = LessonEventBus();
      const offer = LessonPaidImageOffer(
        offerId: 'img_offer_late',
        lessonKey: 'lesson-key',
        prompt: 'prompt',
        creditCost: 10,
        source: 'skip_no_offer',
      );
      bus.notifyPaidImageOffer('lesson-key', offer);
      final received = <LessonPaidImageOffer?>[];
      final unsubscribe = bus.subscribePaidImageOffer(
        'lesson-key',
        received.add,
      );
      addTearDown(unsubscribe);

      expect(received, [offer]);
      bus.clearPaidImageOffer('lesson-key');
      expect(received.last, isNull);
    },
  );

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
        imagem:
            'data:image/svg+xml;utf8,%3Csvg%20viewBox%3D%220%200%201%201%22%3E%3C/svg%3E',
        audioText: 'Explicacao. Pergunta',
      );

      final live = <CompleteLesson>[];
      final unsubscribeLive = bus.subscribe('lesson-key', live.add);
      addTearDown(unsubscribeLive);
      bus.notify('lesson-key', lesson);
      final received = <CompleteLesson>[];
      final unsubscribe = bus.subscribe('lesson-key', received.add);
      addTearDown(unsubscribe);

      expect(live.single.imagem, startsWith('data:image/svg+xml;utf8,'));
      expect(received.single.imagem, lesson.imagem);
      expect(received.single.conteudo.question, lesson.conteudo.question);
    },
  );

  test('review and recovery requests preserve visual_trigger', () async {
    final trigger = <String, dynamic>{
      'needs_image': true,
      'pedagogical_need': 'important',
      'render_strategy': 'software',
      'svg_payload':
          '<svg viewBox="0 0 10 10"><line x1="1" y1="1" x2="9" y2="9"/></svg>',
    };
    final t02 = FakeT02Client(visualTrigger: trigger);
    final orchestrator = LessonOrchestrator(
      t02Client: t02,
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
      visualPipeline: fakeVisualPipeline(),
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
    expect(review.conteudo.visualTrigger, trigger);
    expect(recovery.conteudo.visualTrigger, trigger);
  });

  test(
    'background prefetch does not create paid image without student action',
    () async {
      final trigger = <String, dynamic>{
        'needs_image': true,
        'pedagogical_need': 'important',
        'render_strategy': 'ai',
        'topic': 'coração humano realista',
        'image_prompt': 'foto realista de um coração humano',
      };
      final cache = LessonMaterialCache();
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(visualTrigger: trigger),
        cache: cache,
        bus: LessonEventBus(),
        visualPipeline: fakeVisualPipeline(),
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

      expect(lesson.conteudo.visualTrigger, trigger);
      expect(cache.peek(key)?.imagem, isNull);
    },
  );

  test('DopamineReadyWindowEngine prepares A/B/C slots from state', () async {
    final service = StudentLearningStateService(
      seed: {'cyber-ready': _stateWithCurriculum()},
    );
    final t02 = FakeT02Client();
    final orchestrator = LessonOrchestrator(
      t02Client: t02,
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
      visualPipeline: fakeVisualPipeline(),
    );
    final engine = DopamineReadyWindowEngine(
      service: service,
      orchestrator: orchestrator,
    );

    final result = await engine.runDopamineReadyWindowFromStudentState(
      lessonLocalId: 'cyber-ready',
      source: 'test',
      maxSlots: 3,
    );

    expect(result, [true, true, true]);
    expect(t02.calls, 3);
    expect(service.read('cyber-ready')?.readyLessonMaterials.length, 3);
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
        visualPipeline: fakeVisualPipeline(),
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
      visualPipeline: fakeVisualPipeline(),
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
    expect(event?.payload['windowSize'], 3);
    expect(event?.payload['cachedCount'], 3);
    expect(event?.payload['windowMarkers'], [
      {'marker': 'M1', 'layer': 1, 'offset': 0},
      {'marker': 'M1', 'layer': 2, 'offset': 1},
      {'marker': 'M1', 'layer': 3, 'offset': 2},
    ]);
  });

  test('maintainLessonReadyWindow does not duplicate active jobs', () {
    final service = StudentLearningStateService();
    service.ensure(lessonLocalId: 'cyber-window-dedupe');
    final orchestrator = LessonOrchestrator(
      t02Client: FakeT02Client(),
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
      visualPipeline: fakeVisualPipeline(),
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

  test(
    'ready state material schedules free software visual like SimWeb',
    () async {
      final trigger = {
        'needs_image': true,
        'pedagogical_need': 'helpful',
        'render_strategy': 'software',
        'visual_type': 'graph',
        'svg_payload':
            '<svg viewBox="0 0 10 10"><rect width="10" height="10"/></svg>',
      };
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
                'visual_trigger': trigger,
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
        visualPipeline: fakeVisualPipeline(),
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
      expect(updates.last.imagem, startsWith('data:'));
      expect(cache.peek(lessonKeyFor(params))?.imagem, updates.last.imagem);
    },
  );

  test('cached text-only material schedules free software visual', () async {
    final trigger = {
      'needs_image': true,
      'pedagogical_need': 'helpful',
      'render_strategy': 'software',
      'visual_type': 'graph',
      'svg_payload':
          '<svg viewBox="0 0 10 10"><circle cx="5" cy="5" r="4"/></svg>',
    };
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
          visualTrigger: trigger,
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
      visualPipeline: fakeVisualPipeline(),
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
    expect(updates.last.imagem, startsWith('data:'));
    expect(cache.peek(lessonKeyFor(params))?.imagem, updates.last.imagem);
  });

  test('StudentExperienceT02Adapter prepares first minimum lesson', () async {
    final service = StudentLearningStateService(
      seed: {'cyber-ready': _stateWithCurriculum()},
    );
    final t02 = FakeT02Client();
    final orchestrator = LessonOrchestrator(
      t02Client: t02,
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
      visualPipeline: fakeVisualPipeline(),
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
        visualPipeline: fakeVisualPipeline(),
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
        containsAll(['M1::L1::l1', 'M1::L2::l2', 'M1::L3::l3']),
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
        visualPipeline: fakeVisualPipeline(),
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
        visualPipeline: fakeVisualPipeline(),
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
