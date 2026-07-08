import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_t02_caller.dart';
import 'package:sim_mobile/sim/auxiliary/recovery_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/review_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_rooms.dart';
import 'package:sim_mobile/sim/constitution/sim_constitutional_contract.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/mastery_truth_engine.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

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
const _constitution = SimConstitutionalContract();

StudentLearningState _state({
  String lessonLocalId = 'a7-lesson',
  int itemIdx = 0,
  LessonLayer layer = LessonLayer.l1,
  List<LessonAttempt> attempts = const [],
  JsonMap? auxRooms,
  List<StudentLearningEvent> events = const [],
  JsonMap? currentLessonMaterial,
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
    events: events,
    auxRooms: auxRooms,
    currentLessonMaterial: currentLessonMaterial,
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

RecoveryRoomContext _recoveryContext(String lessonLocalId) {
  return RecoveryRoomContext(
    lessonLocalId: lessonLocalId,
    topic: 'Matematica',
    items: _auxItems,
    layer: LessonLayer.l1,
    profile: _profile,
  );
}

ReviewRoomContext _reviewContext(String lessonLocalId) {
  return ReviewRoomContext(
    lessonLocalId: lessonLocalId,
    topic: 'Matematica',
    items: _auxItems,
    fallbackStartIdx: 0,
    layer: LessonLayer.l1,
    profile: _profile,
  );
}

StudentLearningState _withPending(
  StudentLearningState state,
  LessonAttempt attempt,
) {
  return registerPendingFromAttempt(
    state.copyWith(attempts: [...state.attempts, attempt]),
    attempt,
  );
}

void main() {
  group('A7 - Recuperacao', () {
    test('A7.1 inventario da recuperacao existente no app', () async {
      final attempt = _attempt(correct: false, sinal: DecisionSignal.one);
      final base = _withPending(_state(), attempt);
      final states = {'a7-lesson': base};
      final client = _FakeT02Client();
      final service = _service(states, client);
      final recovery = RecoveryRoomService(service);
      final view = await recovery.startRecoveryRoom(
        _recoveryContext('a7-lesson'),
      );
      final saved = states['a7-lesson']!;
      final aux = ensureAuxRooms(saved);

      expect(pendingMapOf(aux).single['marker'], 'M1');
      expect((aux['recovery'] as Map)['currentQueue'], ['M1']);
      expect(view.status, RecoveryRoomStatus.intro);
      expect(client.auxCalls, 1);
      expect(service.shouldLessonBlockFinalCompletion('a7-lesson'), isTrue);
      expect(_truthEngine.evaluateMarker(saved, 'M1').needsReinforcement, true);
      expect(
        saved.events.map((event) => event.type),
        containsAll([
          'PENDING_REGISTERED',
          'RECOVERY_QUEUE_PREPARED',
          'RECOVERY_QUESTION_SHOWN',
          'RECOVERY_REQUIRED',
        ]),
      );
    });

    test('A7.2 fila de recuperacao e estruturada por rachaduras', () async {
      final repeatedWrong1 = _attempt(
        marker: 'M1',
        letra: AnswerLetter.C,
        sinal: DecisionSignal.two,
        correct: false,
        ts: 10,
      );
      final repeatedWrong2 = _attempt(
        marker: 'M1',
        letra: AnswerLetter.C,
        sinal: DecisionSignal.two,
        correct: false,
        ts: 11,
      );
      final falseMastery = _attempt(
        marker: 'M2',
        letra: AnswerLetter.C,
        sinal: DecisionSignal.one,
        correct: false,
        ts: 12,
      );
      final lowConfidence = _attempt(
        marker: 'M3',
        letra: AnswerLetter.B,
        sinal: DecisionSignal.three,
        correct: true,
        ts: 13,
      );
      var state = _withPending(_state(), repeatedWrong1);
      state = _withPending(state, repeatedWrong2);
      state = _withPending(state, falseMastery);
      state = _withPending(state, lowConfidence);
      const insufficient = MasteryEvidence(
        marker: 'M4',
        status: MasteryStatus.learning,
        reason: 'dominio insuficiente',
        score: 1,
        consecutiveCorrect: 1,
        consecutiveWrong: 0,
        attemptCount: 1,
        needsReview: true,
        needsReinforcement: false,
      );
      state = scheduleReviewFromEvidence(
        state,
        insufficient,
        layer: LessonLayer.l1,
        signal: DecisionSignal.three,
        now: 14,
      );
      final states = {'a7-lesson': state};
      final service = _service(states, _FakeT02Client());
      final queue = service.buildRecoveryQueueForLesson(
        lessonLocalId: 'a7-lesson',
        topic: 'Matematica',
        items: _auxItems,
      );
      final saved = states['a7-lesson']!;
      final recoveryState = ensureAuxRooms(saved)['recovery'] as Map;
      final currentItems = (recoveryState['currentItems'] as List)
          .whereType<Map>()
          .map((entry) => JsonMap.from(entry))
          .toList();

      expect(queue.queue, containsAll(['M1', 'M2', 'M3', 'M4']));
      expect(currentItems.map((entry) => entry['marker']), contains('M1'));
      expect(currentItems.map((entry) => entry['reason']), contains('wrong'));
      expect(
        currentItems.map((entry) => entry['reason']),
        contains('low_confidence_heavy'),
      );
      for (final item in currentItems) {
        expect(item['marker'], isNotEmpty);
        expect(item['reason'], isNotEmpty);
        expect(item['priority'], isNotEmpty);
        expect(item['origin'], isNotEmpty);
        expect(item['event'], 'RECOVERY_REQUIRED');
        expect(item['timestamp'], isNotNull);
        expect(item['lessonLocalId'], 'a7-lesson');
        expect(item['layer'], isNotNull);
      }
      expect(queue.signalByMarker['M1'], DecisionSignal.three);
      expect(queue.signalByMarker['M2'], DecisionSignal.three);
      expect(queue.signalByMarker['M3'], DecisionSignal.three);
    });

    test('A7.3 recuperacao pendente bloqueia conclusao falsa', () {
      final pending = _withPending(
        _state(layer: LessonLayer.l3),
        _attempt(
          layer: LessonLayer.l3,
          letra: AnswerLetter.C,
          sinal: DecisionSignal.one,
          correct: false,
        ),
      );
      final evidence = _truthEngine.evaluateMarker(pending, 'M1');
      final result = _constitution.evaluateAdvanceGate(
        evidence: const SimAnswerEvidence(
          marker: 'M1',
          layer: LessonLayer.l3,
          selectedAnswer: AnswerLetter.A,
          signal: DecisionSignal.one,
          correct: true,
          validatedBySoftware: true,
        ),
        masteryEvidence: evidence,
      );

      expect(shouldBlockFinalCompletionForRecovery(pending), isTrue);
      expect(pending.progress?.concluidos, isNot(contains('M1')));
      expect(evidence.needsReinforcement, isTrue);
      expect(result.allowAdvance, isFalse);
    });

    test('A7.4 sala de recuperacao preserva aula principal', () async {
      final base = _withPending(
        _state(
          itemIdx: 1,
          layer: LessonLayer.l2,
          currentLessonMaterial: const {'marker': 'M2', 'question': 'Atual'},
          readyLessonMaterials: const {
            '1:M2:L2': {'marker': 'M2', 'question': 'Atual'},
            '2:M3:L1': {'marker': 'M3', 'question': 'Proxima'},
          },
        ),
        _attempt(marker: 'M2', layer: LessonLayer.l2, correct: false),
      );
      final states = {'a7-lesson': base};
      final recovery = RecoveryRoomService(_service(states, _FakeT02Client()));
      final before = states['a7-lesson']!;

      final view = await recovery.startRecoveryRoom(
        _recoveryContext('a7-lesson'),
      );
      final after = states['a7-lesson']!;

      expect(view.status, RecoveryRoomStatus.intro);
      expect(after.current?.marker, before.current?.marker);
      expect(after.current?.layer, before.current?.layer);
      expect(after.progress?.historia, before.progress?.historia);
      expect(after.attempts, before.attempts);
      expect(after.currentLessonMaterial, before.currentLessonMaterial);
      expect(after.readyLessonMaterials, before.readyLessonMaterials);
    });

    test('A7.5 resposta de recuperacao vira evidencia propria', () async {
      final base = _withPending(
        _state(),
        _attempt(sinal: DecisionSignal.one, correct: false),
      );
      final states = {'a7-lesson': base};
      final recovery = RecoveryRoomService(_service(states, _FakeT02Client()));
      var view = await recovery.startRecoveryRoom(
        _recoveryContext('a7-lesson'),
      );

      view = recovery.continueRecovery(view);
      view = recovery.selectLetter(view, AnswerLetter.B);
      view = recovery.answerRecoveryRoom(
        _recoveryContext('a7-lesson'),
        view,
        DecisionSignal.one,
      );
      final saved = states['a7-lesson']!;
      final recorded = saved.events.lastWhere(
        (event) => event.type == 'RECOVERY_ANSWER_RECORDED',
      );

      expect(view.status, RecoveryRoomStatus.result);
      expect(saved.attempts.last.marker, 'M1');
      expect(saved.attempts.last.layer, LessonLayer.l1);
      expect(saved.attempts.last.letra, AnswerLetter.B);
      expect(saved.attempts.last.sinal, DecisionSignal.one);
      expect(saved.attempts.last.correct, isTrue);
      expect(saved.attempts.last.ts, greaterThan(0));
      expect(recorded.payload['marker'], 'M1');
      expect(recorded.payload['type'], 'recovery:0');
      expect(recorded.payload['slot'], 'recovery:0');
      expect(recorded.payload['letra'], 'B');
      expect(recorded.payload['sinal'], 1);
      expect(recorded.payload['correct'], isTrue);
    });

    test('A7.6 recuperacao atualiza evidencia por software', () async {
      final base = _withPending(
        _state(),
        _attempt(sinal: DecisionSignal.one, correct: false),
      );
      final states = {'a7-lesson': base};
      final recovery = RecoveryRoomService(_service(states, _FakeT02Client()));
      var view = await recovery.startRecoveryRoom(
        _recoveryContext('a7-lesson'),
      );
      view = recovery.continueRecovery(view);
      view = recovery.selectLetter(view, AnswerLetter.B);
      recovery.answerRecoveryRoom(
        _recoveryContext('a7-lesson'),
        view,
        DecisionSignal.one,
      );
      var saved = states['a7-lesson']!;
      expect(saved.truth.itemConsolidationStatus['M1'], 'mastered');
      expect(
        saved.truth.masteryEvidence.last['reason'],
        contains('recuperado'),
      );
      expect(pendingMapOf(ensureAuxRooms(saved)).single['status'], 'cleared');

      final stillFragile = _withPending(
        saved.copyWith(
          attempts: [
            ...saved.attempts,
            _attempt(
              marker: 'M2',
              letra: AnswerLetter.C,
              sinal: DecisionSignal.one,
              correct: false,
              ts: 20,
            ),
          ],
        ),
        _attempt(
          marker: 'M2',
          letra: AnswerLetter.C,
          sinal: DecisionSignal.one,
          correct: false,
          ts: 20,
        ),
      );
      states['a7-lesson'] = stillFragile;
      view = await recovery.startRecoveryRoom(_recoveryContext('a7-lesson'));
      view = recovery.continueRecovery(view);
      view = recovery.selectLetter(view, AnswerLetter.C);
      recovery.answerRecoveryRoom(
        _recoveryContext('a7-lesson'),
        view,
        DecisionSignal.two,
      );
      saved = states['a7-lesson']!;
      expect(saved.truth.itemConsolidationStatus['M2'], isNot('mastered'));
      expect(saved.truth.masteryEvidence.last['needs_reinforcement'], isTrue);
    });

    test(
      'A7.7 reparo suficiente libera, insuficiente mantem pendencia',
      () async {
        final states = {
          'a7-lesson': _withPending(
            _state(),
            _attempt(sinal: DecisionSignal.one, correct: false),
          ),
        };
        final recovery = RecoveryRoomService(
          _service(states, _FakeT02Client()),
        );
        var view = await recovery.startRecoveryRoom(
          _recoveryContext('a7-lesson'),
        );
        view = recovery.continueRecovery(view);
        view = recovery.selectLetter(view, AnswerLetter.C);
        recovery.answerRecoveryRoom(
          _recoveryContext('a7-lesson'),
          view,
          DecisionSignal.two,
        );
        expect(recovery.shouldStartRecoveryRoom('a7-lesson'), isTrue);

        view = await recovery.startRecoveryRoom(_recoveryContext('a7-lesson'));
        view = recovery.continueRecovery(view);
        view = recovery.selectLetter(view, AnswerLetter.B);
        recovery.answerRecoveryRoom(
          _recoveryContext('a7-lesson'),
          view,
          DecisionSignal.three,
        );
        expect(recovery.shouldStartRecoveryRoom('a7-lesson'), isTrue);

        view = await recovery.startRecoveryRoom(_recoveryContext('a7-lesson'));
        view = recovery.continueRecovery(view);
        view = recovery.selectLetter(view, AnswerLetter.B);
        view = recovery.answerRecoveryRoom(
          _recoveryContext('a7-lesson'),
          view,
          DecisionSignal.one,
        );
        expect(view.resultCorrect, isTrue);
        expect(recovery.shouldStartRecoveryRoom('a7-lesson'), isFalse);
        expect(
          pendingMapOf(ensureAuxRooms(states['a7-lesson']!)).last['status'],
          'cleared',
        );
      },
    );

    test('A7.8 recuperacao nao destroi historico nem materiais', () async {
      final base = _withPending(
        _state(
          itemIdx: 1,
          layer: LessonLayer.l2,
          currentLessonMaterial: const {'marker': 'M2', 'image': 'foto.png'},
          readyLessonMaterials: const {
            '1:M2:L2': {'marker': 'M2', 'question': 'Atual'},
            '2:M3:L1': {'marker': 'M3', 'question': 'Proxima'},
          },
        ),
        _attempt(marker: 'M2', layer: LessonLayer.l2, correct: false),
      );
      final states = {'a7-lesson': base};
      final recovery = RecoveryRoomService(_service(states, _FakeT02Client()));
      final before = states['a7-lesson']!;
      var view = await recovery.startRecoveryRoom(
        _recoveryContext('a7-lesson'),
      );
      view = recovery.continueRecovery(view);
      view = recovery.selectLetter(view, AnswerLetter.B);
      recovery.answerRecoveryRoom(
        _recoveryContext('a7-lesson'),
        view,
        DecisionSignal.one,
      );
      final after = states['a7-lesson']!;
      final restored = StudentLearningState.fromJson(after.toJson());

      expect(after.progress?.historia, before.progress?.historia);
      expect(after.progress?.concluidos, before.progress?.concluidos);
      expect(
        after.progress?.pendentesMarkers,
        before.progress?.pendentesMarkers,
      );
      expect(after.currentLessonMaterial, before.currentLessonMaterial);
      expect(after.readyLessonMaterials, before.readyLessonMaterials);
      expect(restored.currentLessonMaterial?['image'], 'foto.png');
      expect(restored.readyLessonMaterials.keys, contains('2:M3:L1'));
    });

    test('A7.9 revisao e advance gate enxergam recuperacao', () async {
      final reviewFailure = _withPending(
        _state(),
        _attempt(marker: 'M1', sinal: DecisionSignal.two, correct: true),
      );
      final states = {'a7-lesson': reviewFailure};
      final client = _FakeT02Client();
      final service = _service(states, client);
      final review = ReviewRoomService(service);
      var view = await review.startReviewRoom(_reviewContext('a7-lesson'), 5);
      view = review.selectLetter(view, AnswerLetter.C);
      review.answerReviewRoom(
        _reviewContext('a7-lesson'),
        view,
        DecisionSignal.one,
      );
      final saved = states['a7-lesson']!;
      final evidence = _truthEngine.evaluateMarker(saved, 'M1');
      final gate = _constitution.evaluateAdvanceGate(
        evidence: const SimAnswerEvidence(
          marker: 'M1',
          layer: LessonLayer.l1,
          selectedAnswer: AnswerLetter.C,
          signal: DecisionSignal.one,
          correct: false,
          validatedBySoftware: true,
        ),
        masteryEvidence: evidence,
      );

      expect(
        saved.events.map((event) => event.type),
        contains('REVIEW_ANSWER_RECORDED'),
      );
      expect(evidence.needsReinforcement, isTrue);
      expect(shouldBlockFinalCompletionForRecovery(saved), isTrue);
      expect(gate.allowAdvance, isFalse);
      expect(buildRecoveryQueue(saved), contains('M1'));
    });

    test('A7.10 recuperacao funciona de ponta a ponta', () async {
      final crack = _attempt(
        marker: 'M1',
        layer: LessonLayer.l1,
        letra: AnswerLetter.C,
        sinal: DecisionSignal.one,
        correct: false,
        ts: 100,
      );
      final base = _withPending(
        _state(
          attempts: [crack],
          readyLessonMaterials: const {
            '0:M1:L1': {'marker': 'M1', 'question': 'Aula atual'},
          },
        ),
        crack,
      );
      final states = {'a7-lesson': base};
      final recovery = RecoveryRoomService(_service(states, _FakeT02Client()));
      final before = states['a7-lesson']!;

      expect(recovery.shouldStartRecoveryRoom('a7-lesson'), isTrue);
      var view = await recovery.startRecoveryRoom(
        _recoveryContext('a7-lesson'),
      );
      expect(view.status, RecoveryRoomStatus.intro);
      expect(view.queue, ['M1']);

      view = recovery.continueRecovery(view);
      view = recovery.selectLetter(view, AnswerLetter.B);
      view = recovery.answerRecoveryRoom(
        _recoveryContext('a7-lesson'),
        view,
        DecisionSignal.one,
      );
      final afterRepair = states['a7-lesson']!;
      expect(view.status, RecoveryRoomStatus.result);
      expect(view.resultCorrect, isTrue);
      expect(afterRepair.truth.itemConsolidationStatus['M1'], 'mastered');
      expect(recovery.shouldStartRecoveryRoom('a7-lesson'), isFalse);
      expect(afterRepair.current?.marker, before.current?.marker);
      expect(afterRepair.progress?.historia, before.progress?.historia);
      expect(afterRepair.readyLessonMaterials, before.readyLessonMaterials);
      expect(
        afterRepair.events.any((event) => event.type.contains('ERROR')),
        isFalse,
      );

      final done = await recovery.nextRecoveryRoom(
        _recoveryContext('a7-lesson'),
        view,
      );
      final restored = StudentLearningState.fromJson(
        states['a7-lesson']!.toJson(),
      );
      expect(done.status, RecoveryRoomStatus.done);
      expect(restored.truth.itemConsolidationStatus['M1'], 'mastered');
      expect(pendingMapOf(ensureAuxRooms(restored)).last['status'], 'cleared');
    });
  });
}
