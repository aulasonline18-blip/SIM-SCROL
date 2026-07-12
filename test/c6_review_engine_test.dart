import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_t02_caller.dart';
import 'package:sim_mobile/sim/auxiliary/review_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_rooms.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/internal_organs_governor.dart';
import 'package:sim_mobile/sim/state/mastery_truth_engine.dart';
import 'package:sim_mobile/sim/state/student_lesson_executor.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

class _FakeT02Client implements T02LessonClient {
  int auxCalls = 0;

  T02LessonMaterial _material(String source) => T02LessonMaterial(
    explanation: 'Explicacao $source',
    question: 'Pergunta $source',
    options: const {
      AnswerLetter.A: 'Opcao A',
      AnswerLetter.B: 'Opcao B',
      AnswerLetter.C: 'Opcao C',
    },
    correctAnswer: AnswerLetter.B,
    whyCorrect: 'Porque B.',
    whyWrong: const {},
    generatedAt: DateTime(2026),
    source: source,
  );

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) async {
    auxCalls += 1;
    return _material(request.mode);
  }

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    return _material('complete');
  }

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) async {
    return _material('doubt');
  }

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) async {
    return _material('placement');
  }
}

const _items = [
  CurriculumItem(marker: 'M1', text: 'Frações'),
  CurriculumItem(marker: 'M2', text: 'Decimais'),
  CurriculumItem(marker: 'M3', text: 'Porcentagem'),
];
const _auxItems = [
  AuxRoomItem(marker: 'M1', text: 'Frações'),
  AuxRoomItem(marker: 'M2', text: 'Decimais'),
  AuxRoomItem(marker: 'M3', text: 'Porcentagem'),
];
const _profile = AuxRoomProfile(
  stableLang: 'Portuguese',
  academicLevel: 'ensino_medio',
  preferredName: 'Aluno',
);
const _truthEngine = MasteryTruthEngine();

StudentLearningState _state({
  String lessonLocalId = 'c6-lesson',
  int itemIdx = 0,
  LessonLayer layer = LessonLayer.l1,
  List<LessonAttempt> attempts = const [],
  JsonMap? auxRooms,
  Map<String, JsonMap> readyLessonMaterials = const {},
}) {
  final now = DateTime(2026).millisecondsSinceEpoch;
  final marker = itemIdx >= 0 && itemIdx < _items.length
      ? _items[itemIdx].marker
      : null;
  return StudentLearningState.empty(
    lessonLocalId: lessonLocalId,
    now: now,
  ).copyWith(
    profile: const StudentProfile(
      stableLang: 'Portuguese',
      academicLevel: 'ensino_medio',
      preferredName: 'Aluno',
    ),
    curriculum: StudentCurriculum(
      topic: 'Matematica',
      totalItems: _items.length,
      generatedAt: now,
      provisional: false,
      items: _items,
    ),
    current: LessonCurrent(
      itemIdx: itemIdx,
      marker: marker,
      layer: layer,
      amparoLvl: 0,
    ),
    progress: LessonProgress(
      itemIdx: itemIdx,
      layer: layer,
      erros: 0,
      amparoLvl: 0,
      historia: const ['M0'],
      mainAdvances: itemIdx,
      concluidos: const ['M0'],
      pendentesMarkers: const ['PX'],
      totalItems: _items.length,
      pctAvanco: itemIdx == 0 ? 0 : 33,
    ),
    attempts: attempts,
    auxRooms: auxRooms,
    readyLessonMaterials: readyLessonMaterials,
  );
}

LessonAttempt _attempt({
  String marker = 'M1',
  LessonLayer layer = LessonLayer.l1,
  AnswerLetter letra = AnswerLetter.A,
  DecisionSignal sinal = DecisionSignal.two,
  bool correct = true,
  int ts = 1,
}) {
  return LessonAttempt(
    marker: marker,
    layer: layer,
    letra: letra,
    sinal: sinal,
    correct: correct,
    ts: ts,
  );
}

StudentAuxRoomService _service(
  Map<String, StudentLearningState> states,
  _FakeT02Client client,
) {
  return StudentAuxRoomService(
    readState: (id) => states[id]!,
    writeState: (state) => states[state.lessonLocalId] = state,
    t02Caller: AuxRoomT02Caller(client: client),
  );
}

ReviewRoomContext _context(String lessonLocalId) {
  return ReviewRoomContext(
    lessonLocalId: lessonLocalId,
    topic: 'Matematica',
    items: _auxItems,
    fallbackStartIdx: 0,
    layer: LessonLayer.l1,
    profile: _profile,
  );
}

void main() {
  group('C/A6 - Revisao', () {
    test('C1 inventario do motor de revisao existente', () async {
      final attempt = _attempt();
      final base = registerPendingFromAttempt(
        _state(attempts: [attempt]),
        attempt,
      );
      final states = {'c6-lesson': base};
      final client = _FakeT02Client();
      final service = _service(states, client);
      final review = ReviewRoomService(service);
      final view = await review.startReviewRoom(_context('c6-lesson'), 5);

      final store = StudentStateStore(local: MemoryStudentStateLocalStorage());
      store.writeState(_state(lessonLocalId: 'store-lesson'));
      final governor = AuxiliaryStateGovernor(store: store);
      final event = governor.scheduleReview(
        lessonLocalId: 'store-lesson',
        marker: 'M1',
        reason: 'needs review',
      );

      expect(pendingMapOf(ensureAuxRooms(base)).single['marker'], 'M1');
      expect(view.status, ReviewRoomStatus.ready);
      expect(view.queue, contains('M1'));
      expect(client.auxCalls, 1);
      expect(event.type, 'REVIEW_SCHEDULED');
      expect(event.payload['marker'], 'M1');
      expect(_truthEngine.evaluateMarker(base, 'M1').needsReview, isTrue);
    });

    test('C2 fila de revisao estruturada fica no estado e restaura', () {
      final attempt = _attempt(
        marker: 'M1',
        layer: LessonLayer.l2,
        sinal: DecisionSignal.three,
        correct: true,
        ts: 20,
      );
      final withPending = registerPendingFromAttempt(
        _state(attempts: [attempt]),
        attempt,
      );
      final states = {'c6-lesson': withPending};
      final client = _FakeT02Client();
      final service = _service(states, client);
      final queue = service.buildReviewQueueForLesson(
        lessonLocalId: 'c6-lesson',
        topic: 'Matematica',
        items: _auxItems,
        count: 5,
        fallbackStartIdx: 0,
      );
      final saved = states['c6-lesson']!;
      final aux = ensureAuxRooms(saved);
      final pending = pendingMapOf(aux).single;
      final review = aux['review'] as Map;
      final restored = StudentLearningState.fromJson(saved.toJson());
      final restoredReview = ensureAuxRooms(restored)['review'] as Map;

      expect(queue, ['M1']);
      expect(pending['marker'], 'M1');
      expect(pending['reason'], 'low_confidence_heavy');
      expect(pending['layer'], 2);
      expect(pending['signal'], 3);
      expect(pending['firstRegisteredAt'], 20);
      expect(review['currentQueue'], ['M1']);
      expect(review['requestedCount'], 5);
      expect(review['sourceLessonLocalId'], 'c6-lesson');
      expect(restoredReview['currentQueue'], ['M1']);
    });

    test('C3 baixa confianca agenda revisao com prioridade auditavel', () {
      final lightAttempt = _attempt(
        marker: 'M1',
        sinal: DecisionSignal.two,
        correct: true,
        ts: 30,
      );
      final heavyAttempt = _attempt(
        marker: 'M2',
        sinal: DecisionSignal.three,
        correct: true,
        ts: 31,
      );
      final state = registerPendingFromAttempt(
        registerPendingFromAttempt(
          _state(attempts: [lightAttempt, heavyAttempt]),
          lightAttempt,
        ),
        heavyAttempt,
      );
      final aux = ensureAuxRooms(state);
      final pending = pendingMapOf(aux);
      final reviewEvents = state.events
          .where((event) => event.type == 'REVIEW_SCHEDULED')
          .toList();

      expect(pending.map((entry) => entry['marker']), ['M1', 'M2']);
      expect(pending[0]['reason'], 'low_confidence_light');
      expect(pending[0]['signal'], 2);
      expect(pending[1]['reason'], 'low_confidence_heavy');
      expect(pending[1]['signal'], 3);
      expect(reviewEvents, hasLength(2));
      expect(reviewEvents[0].payload['priority'], 'medium');
      expect(reviewEvents[1].payload['priority'], 'high');
    });

    test('C4 erro agenda revisao sem substituir recuperacao obrigatoria', () {
      final wrongAttempt = _attempt(
        marker: 'M1',
        letra: AnswerLetter.C,
        sinal: DecisionSignal.one,
        correct: false,
        ts: 40,
      );
      final stateWithAttempt = _state(attempts: [wrongAttempt]);
      final state = registerPendingFromAttempt(stateWithAttempt, wrongAttempt);
      final evidence = _truthEngine.evaluateMarker(state, 'M1');
      final states = {'c6-lesson': state};
      final client = _FakeT02Client();
      final service = _service(states, client);
      final reviewQueue = service.buildReviewQueueForLesson(
        lessonLocalId: 'c6-lesson',
        topic: 'Matematica',
        items: _auxItems,
        count: 5,
        fallbackStartIdx: 0,
      );
      final recovery = service.buildRecoveryQueueForLesson(
        lessonLocalId: 'c6-lesson',
        topic: 'Matematica',
        items: _auxItems,
      );
      final pending = pendingMapOf(ensureAuxRooms(states['c6-lesson']!)).single;
      final reviewEvent = state.events.lastWhere(
        (event) => event.type == 'REVIEW_SCHEDULED',
      );

      expect(evidence.status, MasteryStatus.falseMastery);
      expect(evidence.needsReinforcement, isTrue);
      expect(pending['reason'], 'wrong');
      expect(pending['signal'], 3);
      expect(reviewEvent.payload['priority'], 'high');
      expect(reviewQueue, ['M1']);
      expect(recovery.queue, ['M1']);
      expect(recovery.signalByMarker['M1'], DecisionSignal.three);
    });

    test('C5 consolidacao parcial agenda revisao sem apagar historico', () {
      final answered = processAnswerWithEngine(
        _state(layer: LessonLayer.l3),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 50,
      );
      final evidence = _truthEngine.evaluateMarker(answered, 'M1');
      final withTruth = _truthEngine.writeTruthToState(answered, evidence);
      final withReview = scheduleReviewFromEvidence(
        withTruth,
        evidence,
        layer: LessonLayer.l3,
        signal: DecisionSignal.one,
        now: 51,
      );
      final pending = pendingMapOf(ensureAuxRooms(withReview)).single;

      expect(answered.progress?.itemIdx, 1);
      expect(answered.progress?.concluidos, isNot(contains('M1')));
      expect(evidence.status, MasteryStatus.learning);
      expect(evidence.needsReview, isTrue);
      expect(pending['marker'], 'M1');
      expect(pending['layer'], 3);
      expect(pending['reason'], 'um acerto isolado nao prova dominio');
      expect(withReview.progress?.historia, contains('M0'));
      expect(withReview.attempts.single.marker, 'M1');
      expect(
        withReview.events
            .lastWhere((event) => event.type == 'REVIEW_SCHEDULED')
            .payload['masteryStatus'],
        'learning',
      );
    });

    test(
      'C6 sala de revisao abre separada sem corromper aula principal',
      () async {
        final attempt = _attempt(
          marker: 'M2',
          sinal: DecisionSignal.two,
          ts: 60,
        );
        final base = registerPendingFromAttempt(
          _state(
            itemIdx: 1,
            layer: LessonLayer.l2,
            attempts: [attempt],
            readyLessonMaterials: const {
              '1:M2:L2': {'marker': 'M2', 'question': 'Aula principal'},
            },
          ),
          attempt,
        );
        final states = {'c6-lesson': base};
        final client = _FakeT02Client();
        final service = _service(states, client);
        final review = ReviewRoomService(service);
        final before = states['c6-lesson']!;

        final view = await review.startReviewRoom(_context('c6-lesson'), 5);
        final afterOpen = states['c6-lesson']!;
        final done = await review.nextReviewRoom(_context('c6-lesson'), view);
        final afterDone = states['c6-lesson']!;

        expect(view.status, ReviewRoomStatus.ready);
        expect(view.queue.first, 'M2');
        expect(afterOpen.current?.marker, before.current?.marker);
        expect(afterOpen.current?.layer, before.current?.layer);
        expect(afterOpen.progress?.itemIdx, before.progress?.itemIdx);
        expect(afterOpen.readyLessonMaterials, before.readyLessonMaterials);
        expect(done.status, ReviewRoomStatus.done);
        expect(afterDone.current?.marker, 'M2');
        expect(afterDone.progress?.layer, LessonLayer.l2);
      },
    );

    test(
      'C7 resposta de revisao e registrada como evidencia propria',
      () async {
        final attempt = _attempt(
          marker: 'M1',
          sinal: DecisionSignal.two,
          ts: 70,
        );
        final base = registerPendingFromAttempt(
          _state(attempts: [attempt]),
          attempt,
        );
        final states = {'c6-lesson': base};
        final client = _FakeT02Client();
        final review = ReviewRoomService(_service(states, client));
        var view = await review.startReviewRoom(_context('c6-lesson'), 5);

        view = review.selectLetter(view, AnswerLetter.B);
        view = review.answerReviewRoom(
          _context('c6-lesson'),
          view,
          DecisionSignal.one,
        );
        final saved = states['c6-lesson']!;
        final recorded = saved.events.lastWhere(
          (event) => event.type == 'REVIEW_ANSWER_RECORDED',
        );

        expect(view.status, ReviewRoomStatus.result);
        expect(saved.attempts.last.marker, 'M1');
        expect(saved.attempts.last.layer, LessonLayer.l1);
        expect(saved.attempts.last.letra, AnswerLetter.B);
        expect(saved.attempts.last.sinal, DecisionSignal.one);
        expect(saved.attempts.last.correct, isTrue);
        expect(saved.attempts.last.ts, greaterThan(0));
        expect(recorded.payload['marker'], 'M1');
        expect(recorded.payload['type'], 'review');
        expect(recorded.payload['slot'], 'review:0');
        expect(recorded.payload['letra'], 'B');
        expect(recorded.payload['sinal'], 1);
        expect(recorded.payload['correct'], isTrue);
        expect(recorded.payload['question'], 'Pergunta review');
      },
    );

    test('C8 revisao local registra apoio sem gravar dominio forte', () async {
      final initialAttempt = _attempt(marker: 'M1', sinal: DecisionSignal.two);
      final base = registerPendingFromAttempt(
        _state(attempts: [initialAttempt]),
        initialAttempt,
      );
      final states = {'c6-lesson': base};
      final client = _FakeT02Client();
      final review = ReviewRoomService(_service(states, client));
      var view = await review.startReviewRoom(_context('c6-lesson'), 5);

      view = review.selectLetter(view, AnswerLetter.B);
      review.answerReviewRoom(_context('c6-lesson'), view, DecisionSignal.one);
      var saved = states['c6-lesson']!;
      expect(saved.truth.itemConsolidationStatus['M1'], isNot('mastered'));
      expect(saved.events.last.payload['authoritative'], isFalse);
      expect(saved.events.last.payload['writesTruth'], isFalse);
      expect(saved.events.last.payload['requiresServerDecision'], isTrue);

      final wrongAttempt = _attempt(
        marker: 'M2',
        letra: AnswerLetter.C,
        sinal: DecisionSignal.two,
        correct: false,
        ts: 80,
      );
      states['c6-lesson'] = registerPendingFromAttempt(
        saved.copyWith(attempts: [...saved.attempts, wrongAttempt]),
        wrongAttempt,
      );
      view = await review.startReviewRoom(_context('c6-lesson'), 5);
      view = review.selectLetter(view, AnswerLetter.C);
      review.answerReviewRoom(_context('c6-lesson'), view, DecisionSignal.two);
      saved = states['c6-lesson']!;
      expect(saved.truth.itemConsolidationStatus['M2'], isNot('mastered'));
      expect(saved.truth.itemConsolidationStatus['M2'], isNot('mastered'));

      final lowConfidenceAttempt = _attempt(
        marker: 'M3',
        sinal: DecisionSignal.three,
        correct: true,
        ts: 90,
      );
      states['c6-lesson'] = registerPendingFromAttempt(
        saved.copyWith(attempts: [...saved.attempts, lowConfidenceAttempt]),
        lowConfidenceAttempt,
      );
      view = await review.startReviewRoom(_context('c6-lesson'), 5);
      view = review.selectLetter(view, AnswerLetter.B);
      review.answerReviewRoom(
        _context('c6-lesson'),
        view,
        DecisionSignal.three,
      );
      saved = states['c6-lesson']!;
      expect(saved.truth.itemConsolidationStatus['M3'], isNot('mastered'));
      expect(
        pendingMapOf(ensureAuxRooms(saved)).any(
          (entry) => entry['marker'] == 'M3' && entry['status'] == 'pending',
        ),
        isTrue,
      );
    });

    test('C9 revisao nao apaga nem retrocede progresso principal', () async {
      final attempt = _attempt(
        marker: 'M2',
        sinal: DecisionSignal.two,
        ts: 100,
      );
      final base = registerPendingFromAttempt(
        _state(
          itemIdx: 1,
          layer: LessonLayer.l2,
          attempts: [attempt],
          readyLessonMaterials: const {
            '1:M2:L2': {'marker': 'M2', 'question': 'Aula principal'},
            '2:M3:L1': {'marker': 'M3', 'question': 'Proxima aula'},
          },
        ),
        attempt,
      );
      final states = {'c6-lesson': base};
      final client = _FakeT02Client();
      final review = ReviewRoomService(_service(states, client));
      final before = states['c6-lesson']!;
      var view = await review.startReviewRoom(_context('c6-lesson'), 5);

      view = review.selectLetter(view, AnswerLetter.B);
      review.answerReviewRoom(_context('c6-lesson'), view, DecisionSignal.one);
      final after = states['c6-lesson']!;
      final restored = StudentLearningState.fromJson(after.toJson());

      expect(after.current?.itemIdx, before.current?.itemIdx);
      expect(after.current?.marker, before.current?.marker);
      expect(after.current?.layer, before.current?.layer);
      expect(after.progress?.itemIdx, before.progress?.itemIdx);
      expect(after.progress?.layer, before.progress?.layer);
      expect(after.progress?.historia, before.progress?.historia);
      expect(after.progress?.concluidos, before.progress?.concluidos);
      expect(
        after.progress?.pendentesMarkers,
        before.progress?.pendentesMarkers,
      );
      expect(after.readyLessonMaterials, before.readyLessonMaterials);
      expect(restored.current?.marker, 'M2');
      expect(restored.readyLessonMaterials.keys, contains('2:M3:L1'));
    });

    test('C10 revisao funciona de ponta a ponta', () async {
      final fragileAttempt = _attempt(
        marker: 'M1',
        layer: LessonLayer.l1,
        letra: AnswerLetter.A,
        sinal: DecisionSignal.three,
        correct: true,
        ts: 110,
      );
      final base = registerPendingFromAttempt(
        _state(
          itemIdx: 0,
          layer: LessonLayer.l1,
          attempts: [fragileAttempt],
          readyLessonMaterials: const {
            '0:M1:L1': {'marker': 'M1', 'question': 'Aula atual'},
          },
        ),
        fragileAttempt,
      );
      final states = {'c6-lesson': base};
      final client = _FakeT02Client();
      final review = ReviewRoomService(_service(states, client));
      final before = states['c6-lesson']!;

      expect(pendingMapOf(ensureAuxRooms(before)).single['marker'], 'M1');

      var view = await review.startReviewRoom(_context('c6-lesson'), 5);
      expect(view.status, ReviewRoomStatus.ready);
      expect(view.queue.first, 'M1');

      view = review.selectLetter(view, AnswerLetter.B);
      view = review.answerReviewRoom(
        _context('c6-lesson'),
        view,
        DecisionSignal.one,
      );
      expect(view.status, ReviewRoomStatus.result);
      expect(view.resultCorrect, isTrue);
      expect(view.errMsg, isNull);

      var saved = states['c6-lesson']!;
      expect(
        saved.events.map((event) => event.type),
        contains('REVIEW_ANSWER_RECORDED'),
      );
      expect(saved.truth.itemConsolidationStatus['M1'], isNot('mastered'));
      expect(saved.current?.marker, before.current?.marker);
      expect(saved.progress?.itemIdx, before.progress?.itemIdx);
      expect(saved.readyLessonMaterials, before.readyLessonMaterials);
      expect(pendingMapOf(ensureAuxRooms(saved)).single['status'], 'pending');
      expect(saved.events.last.payload['authoritative'], isFalse);
      expect(saved.events.last.payload['writesTruth'], isFalse);
      expect(
        saved.events.any((event) => event.type.contains('ERROR')),
        isFalse,
      );

      view = await review.nextReviewRoom(_context('c6-lesson'), view);
      expect(view.status, ReviewRoomStatus.done);
      saved = states['c6-lesson']!;
      final restored = StudentLearningState.fromJson(saved.toJson());
      final restoredReview = ensureAuxRooms(restored)['review'] as Map;

      expect(restored.truth.itemConsolidationStatus['M1'], isNot('mastered'));
      expect(restored.current?.marker, 'M1');
      expect(restoredReview['currentIndex'], greaterThanOrEqualTo(1));
      expect(
        restored.events.map((event) => event.type),
        contains('REVIEW_CURSOR_UPDATED'),
      );
    });
  });
}
