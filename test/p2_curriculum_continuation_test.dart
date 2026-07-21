import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/experience/curriculum_utils.dart';
import 'package:sim_mobile/sim/experience/student_experience_t00_adapter.dart';
import 'package:sim_mobile/sim/experience/student_experience_types.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

void main() {
  test(
    'P2 prefetches, saves, displays and reopens the next curriculum part',
    () async {
      final service = StudentLearningStateService();
      final client = _P2T00Client();
      final adapter = StudentExperienceT00Adapter(
        service: service,
        client: client,
      );
      const args = StudentExperienceArgs(
        academic: 'ensino medio',
        idioma: 'pt',
        lessonLocalId: 'lesson-p2',
        localeContract: SimLocaleContract(
          interfaceLocale: 'pt-BR',
          learningLocale: 'pt-BR',
          explanationLanguage: 'Portuguese',
          targetLanguage: 'Portuguese',
        ),
        onboarding: {
          'objetivo': 'Matemática financeira para concurso',
          'free_text': 'Matemática financeira para concurso',
          'nivel': 'ensino medio',
        },
      );

      await adapter.startT00UntilFirstItem(args);

      final part1 = await _waitForState(
        service,
        'lesson-p2',
        (state) => state.curriculum?.items.length == 80,
      );
      expect(part1.curriculum?.globalPlan?.globalTotalItems, 360);
      expect(part1.curriculum?.globalPlan?.batchEndItem, 80);
      expect(
        part1.extra['nextCurriculumPartStatus'],
        anyOf('preparing', 'ready'),
      );

      final nextId = nextCurriculumPartLessonId(part1);
      expect(nextId, 'lesson-p2::part-2');

      final part2 = await _waitForState(
        service,
        nextId!,
        (state) => state.curriculum?.items.length == 80,
      );
      expect(client.continuationCalls, greaterThanOrEqualTo(1));
      expect(client.continuations.first['curriculum_continuation'], isTrue);
      expect(client.continuations.first['nextGlobalItemToRequest'], 81);
      expect(client.continuations.first['globalTotalItems'], 360);

      final refreshedPart1 = await _waitForState(
        service,
        'lesson-p2',
        (state) => state.extra['nextCurriculumPartStatus'] == 'ready',
      );
      expect(refreshedPart1.extra['nextCurriculumPartStatus'], 'ready');
      expect(
        readyNextCurriculumPart(service: service, state: refreshedPart1),
        isNotNull,
      );
      expect(part2.curriculum?.globalPlan?.partNumber, 2);
      expect(part2.curriculum?.globalPlan?.batchStartItem, 81);
      expect(part2.curriculum?.displayItemNumberForLocalIndex(0), 81);

      final vm = buildLessonMainViewModel(
        baseItems: const [PlannedItem(marker: 'M81', text: 'Item 81')],
        mainAdvances: 0,
        isReviewAtivo: false,
        itemAtivo: const PlannedItem(marker: 'M81', text: 'Item 81'),
        itemIdx: 0,
        layer: LessonLayer.l1,
        phase: const ClassroomPhase.reading(),
        conteudo: null,
        items: const [PlannedItem(marker: 'M81', text: 'Item 81')],
        globalPlan: part2.curriculum?.globalPlan,
      );
      expect(vm.headerLabel, 'aula_item_of:81/360:aula_layer_1');

      final restored = StudentLearningState.fromJson(part2.toJson());
      expect(restored.curriculum?.globalPlan?.batchStartItem, 81);
      expect(restored.extra['curriculumPlanRootLessonId'], 'lesson-p2');

      await adapter.startT00UntilFirstItem(args);
      expect(client.continuations.first['nextGlobalItemToRequest'], 81);
    },
  );

  test(
    'P2 does not mark next curriculum part ready while it is still partial',
    () async {
      final service = StudentLearningStateService();
      final client = _DelayedPart2T00Client();
      final adapter = StudentExperienceT00Adapter(
        service: service,
        client: client,
      );
      const args = StudentExperienceArgs(
        academic: 'ensino medio',
        idioma: 'pt',
        lessonLocalId: 'lesson-p2-delayed',
        localeContract: SimLocaleContract(
          interfaceLocale: 'pt-BR',
          learningLocale: 'pt-BR',
          explanationLanguage: 'Portuguese',
          targetLanguage: 'Portuguese',
        ),
        onboarding: {
          'objetivo': 'Matemática financeira para concurso',
          'free_text': 'Matemática financeira para concurso',
          'nivel': 'ensino medio',
        },
      );

      await adapter.startT00UntilFirstItem(args);
      final part1 = await _waitForState(
        service,
        'lesson-p2-delayed',
        (state) => state.curriculum?.items.length == 80,
      );
      final nextId = nextCurriculumPartLessonId(part1)!;
      final partialPart2 = await _waitForState(
        service,
        nextId,
        (state) => state.curriculum?.items.length == 1,
      );

      expect(partialPart2.curriculum?.provisional, isTrue);
      expect(
        readyNextCurriculumPart(
          service: service,
          state: service.read('lesson-p2-delayed')!,
        ),
        isNull,
      );
      expect(
        service.read('lesson-p2-delayed')?.extra['nextCurriculumPartStatus'],
        'preparing',
      );

      client.releasePart2Final.complete();
      final fullPart2 = await _waitForState(
        service,
        nextId,
        (state) => state.curriculum?.items.length == 80,
      );
      final refreshedPart1 = await _waitForState(
        service,
        'lesson-p2-delayed',
        (state) => state.extra['nextCurriculumPartStatus'] == 'ready',
      );

      expect(fullPart2.curriculum?.provisional, isFalse);
      expect(
        readyNextCurriculumPart(service: service, state: refreshedPart1),
        isNotNull,
      );
    },
  );
}

class _P2T00Client implements T00BootstrapClient {
  int continuationCalls = 0;
  JsonMap? lastContinuation;
  final List<JsonMap> continuations = [];

  @override
  Stream<T00BootstrapChunk> runBootstrap(T00BootstrapRequest request) async* {
    final isContinuation =
        request.onboarding['curriculum_continuation'] == true;
    if (isContinuation) {
      continuationCalls += 1;
      lastContinuation = request.onboarding;
      continuations.add(request.onboarding);
      final start =
          (request.onboarding['nextGlobalItemToRequest'] as int?) ?? 81;
      yield* _emitBatch(start);
      yield const T00BootstrapChunk(type: 'done', payload: {'ok': true});
      return;
    }

    yield T00BootstrapChunk(
      type: 't00_item_partial',
      payload: {'item': _item(1)},
    );
    yield T00BootstrapChunk(
      type: 't00_final',
      payload: {
        'curriculo': {
          'curriculum_plan': {
            'globalTotalItems': 360,
            'operationalBatchLimit': 80,
            'batchStartItem': 1,
            'batchEndItem': 80,
            'partNumber': 1,
            'partTitle': 'Matemática Financeira — Parte 1',
            'unitsCovered': 'fundamentos',
            'unitsPending': 'juros compostos; descontos',
            'nextGlobalItemToRequest': 81,
            'continuationNeeded': true,
            'continuationInstruction': 'Continue a partir do item 81.',
          },
          'items': List.generate(80, (index) => _item(index + 1)),
        },
      },
    );
    yield const T00BootstrapChunk(type: 'done', payload: {'ok': true});
  }

  JsonMap _item(int globalIndex) => {
    'marker': 'M$globalIndex',
    'title': 'Item $globalIndex',
    'microitem_for_teacher': 'Item $globalIndex',
    'global_item_index': globalIndex,
  };

  Stream<T00BootstrapChunk> _emitBatch(int start) async* {
    const globalTotal = 360;
    const limit = 80;
    final end = (start + limit - 1).clamp(start, globalTotal).toInt();
    final partNumber = ((start - 1) ~/ limit) + 1;
    final needsContinuation = end < globalTotal;
    yield T00BootstrapChunk(
      type: 't00_item_partial',
      payload: {'item': _item(start)},
    );
    yield T00BootstrapChunk(
      type: 't00_final',
      payload: {
        'curriculo': {
          'curriculum_plan': {
            'globalTotalItems': globalTotal,
            'operationalBatchLimit': limit,
            'batchStartItem': start,
            'batchEndItem': end,
            'partNumber': partNumber,
            'partTitle': 'Matemática Financeira — Parte $partNumber',
            'unitsCovered': 'juros compostos',
            'unitsPending': needsContinuation ? 'próximas unidades' : '',
            'nextGlobalItemToRequest': needsContinuation ? end + 1 : null,
            'continuationNeeded': needsContinuation,
            if (needsContinuation)
              'continuationInstruction': 'Continue do item ${end + 1}.',
          },
          'items': List.generate(
            end - start + 1,
            (index) => _item(index + start),
          ),
        },
      },
    );
  }
}

class _DelayedPart2T00Client extends _P2T00Client {
  final Completer<void> releasePart2Final = Completer<void>();

  @override
  Stream<T00BootstrapChunk> runBootstrap(T00BootstrapRequest request) async* {
    final isContinuation =
        request.onboarding['curriculum_continuation'] == true;
    if (!isContinuation) {
      yield* super.runBootstrap(request);
      return;
    }

    continuationCalls += 1;
    lastContinuation = request.onboarding;
    continuations.add(request.onboarding);
    final start = (request.onboarding['nextGlobalItemToRequest'] as int?) ?? 81;
    yield T00BootstrapChunk(
      type: 't00_item_partial',
      payload: {'item': _item(start)},
    );
    if (start == 81) await releasePart2Final.future;
    yield* _emitBatch(start);
    yield const T00BootstrapChunk(type: 'done', payload: {'ok': true});
  }
}

Future<StudentLearningState> _waitForState(
  StudentLearningStateService service,
  String lessonLocalId,
  bool Function(StudentLearningState state) predicate,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    final state = service.read(lessonLocalId);
    if (state != null && predicate(state)) return state;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  final state = service.read(lessonLocalId);
  fail('state $lessonLocalId did not satisfy predicate; state=$state');
}
