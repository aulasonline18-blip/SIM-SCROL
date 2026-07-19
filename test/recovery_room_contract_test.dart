import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_addendums.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_t02_caller.dart';
import 'package:sim_mobile/sim/auxiliary/recovery_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_rooms.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/mastery_truth_engine.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  group('Sala de Recuperacao constitucional', () {
    test('nao inicia sem pendencia forte', () async {
      final states = {'L1': _state()};
      final recovery = RecoveryRoomService(_service(states, _FakeT02()));

      expect(recovery.shouldStartRecoveryRoom('L1'), isFalse);
      final view = await recovery.startRecoveryRoom(_context('L1'));

      expect(view.status, RecoveryRoomStatus.done);
      expect(
        states['L1']!.events.map((e) => e.type),
        isNot(contains('RECOVERY_REQUIRED')),
      );
    });

    test(
      'erro, sinal 3 e baixo dominio forte registram pendencia bloqueante',
      () {
        var state = _state();
        state = registerPendingFromAttempt(
          state,
          _attempt(marker: 'M1', correct: false, sinal: DecisionSignal.one),
        );
        state = registerPendingFromAttempt(
          state,
          _attempt(marker: 'M2', correct: true, sinal: DecisionSignal.three),
        );
        state = scheduleReviewFromEvidence(
          state,
          const MasteryEvidence(
            marker: 'M3',
            status: MasteryStatus.falseMastery,
            reason: 'false_mastery',
            score: 0,
            consecutiveCorrect: 1,
            consecutiveWrong: 1,
            attemptCount: 2,
            needsReview: true,
            needsReinforcement: true,
          ),
          layer: LessonLayer.l2,
          signal: DecisionSignal.three,
          now: 30,
        );

        final pending = pendingMapOf(ensureAuxRooms(state));
        expect(
          pending.map((e) => e['marker']),
          containsAll(['M1', 'M2', 'M3']),
        );
        expect(shouldBlockFinalCompletionForRecovery(state), isTrue);
        expect(pending.every(isStrongRecoveryPending), isTrue);
      },
    );

    test(
      'fila ordena high antes de medium, deduplica marker e preserva campos',
      () {
        final aux = createEmptyAuxRooms();
        aux['pendingMap'] = [
          _pending(
            'M2',
            priority: 'medium',
            ts: 1,
            signal: 2,
            reason: 'review_failed',
          ),
          _pending('M1', priority: 'high', ts: 5, signal: 3, reason: 'wrong'),
          _pending(
            'M3',
            priority: 'high',
            ts: 2,
            signal: 3,
            reason: 'low_confidence_heavy',
          ),
          _pending('M1', priority: 'high', ts: 8, signal: 3, reason: 'wrong'),
        ];
        final states = {'L1': _state(auxRooms: aux)};
        final built = _service(states, _FakeT02()).buildRecoveryQueueForLesson(
          lessonLocalId: 'L1',
          topic: 'Matematica',
          items: _items,
        );
        final recovery = ensureAuxRooms(states['L1']!)['recovery'] as Map;
        final currentItems = (recovery['currentItems'] as List).cast<Map>();

        expect(built.queue, ['M3', 'M1', 'M2']);
        expect(currentItems.first['marker'], 'M3');
        for (final item in currentItems) {
          expect(item['marker'], isNotEmpty);
          expect(item['reason'], isNotEmpty);
          expect(item['priority'], isNotEmpty);
          expect(item['origin'], isNotEmpty);
          expect(item['timestamp'], isNotNull);
          expect(item['signal'], isNotNull);
        }
      },
    );

    test(
      'start registra eventos obrigatorios e chama T02 unico com adendo oficial',
      () async {
        final client = _FakeT02();
        final states = {
          'L1': _state(auxRooms: _auxWith([_pending('M2')])),
        };
        final recovery = RecoveryRoomService(_service(states, client));
        final reference = File(
          '/root/SIM-REFERENCIA/prompts/adendo_recovery.txt',
        ).readAsStringSync().replaceFirst('\uFEFF', '').trimRight();

        final view = await recovery.startRecoveryRoom(_context('L1'));

        expect(view.status, RecoveryRoomStatus.intro);
        expect(client.auxCalls, 1);
        expect(client.lastRequest?.mode, 'recovery');
        expect(client.lastRequest?.addendum, recoveryRoomAddendum);
        expect(client.lastRequest?.addendum?.trimRight(), reference);
        expect(client.lastRequest?.profile['preferredName'], 'Ana');
        expect(client.lastRequest?.marker, 'M2');
        expect(client.lastRequest?.itemIdx, 1);
        expect(view.conteudo?.explanation, isNotEmpty);
        expect(view.conteudo?.question, isNotEmpty);
        expect(view.conteudo?.options.keys, containsAll(AnswerLetter.values));
        expect(
          states['L1']!.events.map((e) => e.type),
          containsAll([
            'RECOVERY_QUEUE_PREPARED',
            'RECOVERY_REQUIRED',
            'RECOVERY_STARTED',
            'FINAL_COMPLETION_BLOCKED_BY_PENDING',
            'RECOVERY_QUESTION_SHOWN',
          ]),
        );
      },
    );

    test(
      'resposta auxiliar nao altera current, progress, attempts ou mastery final',
      () async {
        final states = {
          'L1': _state(auxRooms: _auxWith([_pending('M1')])),
        };
        final before = states['L1']!;
        final recovery = RecoveryRoomService(_service(states, _FakeT02()));
        var view = await recovery.startRecoveryRoom(_context('L1'));
        view = recovery.continueRecovery(view);
        view = recovery.selectLetter(view, AnswerLetter.A);
        view = recovery.answerRecoveryRoom(
          _context('L1'),
          view,
          DecisionSignal.one,
        );
        final after = states['L1']!;
        final event = after.events.lastWhere(
          (e) => e.type == 'RECOVERY_ANSWER_RECORDED',
        );
        final auxAttempts =
            ((ensureAuxRooms(after)['recovery'] as Map)['attempts'] as List)
                .cast<Map>();

        expect(view.status, RecoveryRoomStatus.result);
        expect(after.current?.marker, before.current?.marker);
        expect(after.progress?.itemIdx, before.progress?.itemIdx);
        expect(after.progress?.layer, before.progress?.layer);
        expect(after.attempts, before.attempts);
        expect(
          after.truth.itemConsolidationStatus,
          before.truth.itemConsolidationStatus,
        );
        expect(event.payload['authoritative'], isFalse);
        expect(event.payload['strongEffect'], isFalse);
        expect(event.payload['writesProgress'], isFalse);
        expect(event.payload['writesTruth'], isFalse);
        expect(event.payload['auxiliary'], isTrue);
        expect(auxAttempts.single['source'], 'recovery:0');
        expect(auxAttempts.single['writesProgress'], isFalse);
      },
    );

    test(
      'reparo correto com sinal 1 ou 2 limpa; erro ou sinal 3 mantem',
      () async {
        for (final signal in [DecisionSignal.one, DecisionSignal.two]) {
          final states = {
            'L1': _state(auxRooms: _auxWith([_pending('M1')])),
          };
          final recovery = RecoveryRoomService(_service(states, _FakeT02()));
          var view = await recovery.startRecoveryRoom(_context('L1'));
          view = recovery.continueRecovery(view);
          view = recovery.selectLetter(view, AnswerLetter.A);
          recovery.answerRecoveryRoom(_context('L1'), view, signal);
          expect(recovery.shouldStartRecoveryRoom('L1'), isFalse);
        }

        final states = {
          'L1': _state(auxRooms: _auxWith([_pending('M1')])),
        };
        final recovery = RecoveryRoomService(_service(states, _FakeT02()));
        var view = await recovery.startRecoveryRoom(_context('L1'));
        view = recovery.continueRecovery(view);
        view = recovery.selectLetter(view, AnswerLetter.C);
        recovery.answerRecoveryRoom(_context('L1'), view, DecisionSignal.two);
        expect(recovery.shouldStartRecoveryRoom('L1'), isTrue);

        view = await recovery.startRecoveryRoom(_context('L1'));
        view = recovery.continueRecovery(view);
        view = recovery.selectLetter(view, AnswerLetter.A);
        recovery.answerRecoveryRoom(_context('L1'), view, DecisionSignal.three);
        expect(recovery.shouldStartRecoveryRoom('L1'), isTrue);
      },
    );

    test(
      'quando pendencias acabam registra conclusao auxiliar e gate libera',
      () async {
        final states = {
          'L1': _state(auxRooms: _auxWith([_pending('M1')])),
        };
        final recovery = RecoveryRoomService(_service(states, _FakeT02()));
        var view = await recovery.startRecoveryRoom(_context('L1'));
        view = recovery.continueRecovery(view);
        view = recovery.selectLetter(view, AnswerLetter.A);
        view = recovery.answerRecoveryRoom(
          _context('L1'),
          view,
          DecisionSignal.one,
        );

        final done = await recovery.nextRecoveryRoom(_context('L1'), view);
        final finished = recovery.finishRecoveryRoom('L1', done);

        expect(done.status, RecoveryRoomStatus.done);
        expect(finished.status, RecoveryRoomStatus.done);
        expect(isFinalBlockedByRecovery(recovery, 'L1'), isFalse);
        expect(
          states['L1']!.events.map((e) => e.type),
          containsAll(['RECOVERY_COMPLETED', 'FINAL_COMPLETION_ALLOWED']),
        );
      },
    );

    test(
      'falha T02 preserva aula principal e nao reintroduz rota legada',
      () async {
        final states = {
          'L1': _state(auxRooms: _auxWith([_pending('M1')])),
        };
        final before = states['L1']!;
        final recovery = RecoveryRoomService(
          _service(states, _FakeT02(fail: true)),
        );

        final view = await recovery.startRecoveryRoom(_context('L1'));
        final source = Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .map((file) => file.readAsStringSync())
            .join('\n');

        expect(view.status, RecoveryRoomStatus.failed);
        expect(view.conteudo, isNull);
        expect(view.errMsg, contains('preservada'));
        expect(states['L1']!.current?.marker, before.current?.marker);
        expect(states['L1']!.progress?.itemIdx, before.progress?.itemIdx);
        expect(states['L1']!.attempts, before.attempts);
        expect(source, isNot(contains('/api/recovery')));
      },
    );
  });
}

const _items = [
  AuxRoomItem(marker: 'M1', text: 'Item 1', itemIdx: 0),
  AuxRoomItem(marker: 'M2', text: 'Item 2', itemIdx: 1),
  AuxRoomItem(marker: 'M3', text: 'Item 3', itemIdx: 2),
];

StudentAuxRoomService _service(
  Map<String, StudentLearningState> states,
  _FakeT02 client,
) {
  return StudentAuxRoomService(
    readState: (id) => states[id]!,
    writeState: (state) => states[state.lessonLocalId] = state,
    t02Caller: AuxRoomT02Caller(client: client),
  );
}

RecoveryRoomContext _context(String lessonId) => RecoveryRoomContext(
  lessonLocalId: lessonId,
  topic: 'Matematica',
  items: _items,
  layer: LessonLayer.l2,
  profile: const AuxRoomProfile(
    stableLang: 'pt-BR',
    academicLevel: 'medio',
    preferredName: 'Ana',
    notes: 'perfil real',
  ),
);

StudentLearningState _state({JsonMap? auxRooms}) {
  return StudentLearningState.empty(lessonLocalId: 'L1', now: 1).copyWith(
    profile: const StudentProfile(
      stableLang: 'pt-BR',
      academicLevel: 'medio',
      preferredName: 'Ana',
    ),
    curriculum: const StudentCurriculum(
      topic: 'Matematica',
      totalItems: 3,
      generatedAt: 1,
      provisional: false,
      items: [
        CurriculumItem(marker: 'M1', text: 'Item 1'),
        CurriculumItem(marker: 'M2', text: 'Item 2'),
        CurriculumItem(marker: 'M3', text: 'Item 3'),
      ],
    ),
    current: const LessonCurrent(
      itemIdx: 1,
      marker: 'M2',
      layer: LessonLayer.l2,
      amparoLvl: 0,
    ),
    progress: const LessonProgress(
      itemIdx: 1,
      layer: LessonLayer.l2,
      erros: 0,
      amparoLvl: 0,
      historia: ['M1'],
      mainAdvances: 1,
      concluidos: ['M1'],
      pendentesMarkers: [],
      totalItems: 3,
      pctAvanco: 33,
    ),
    auxRooms: auxRooms,
  );
}

LessonAttempt _attempt({
  required String marker,
  required bool correct,
  required DecisionSignal sinal,
}) {
  return LessonAttempt(
    marker: marker,
    layer: LessonLayer.l2,
    letra: correct ? AnswerLetter.A : AnswerLetter.C,
    sinal: sinal,
    correct: correct,
    ts: 10,
  );
}

JsonMap _auxWith(List<JsonMap> pending) {
  final aux = createEmptyAuxRooms();
  aux['pendingMap'] = pending;
  return aux;
}

JsonMap _pending(
  String marker, {
  String priority = 'high',
  int ts = 1,
  int signal = 3,
  String reason = 'wrong',
}) {
  return {
    'marker': marker,
    'itemIdx': marker == 'M2' ? 1 : 0,
    'layer': 2,
    'signal': signal,
    'reason': reason,
    'priority': priority,
    'origin': 'test',
    'lessonLocalId': 'L1',
    'firstRegisteredAt': ts,
    'lastUpdatedAt': ts,
    'clearedAt': null,
    'status': 'pending',
  };
}

class _FakeT02 implements T02LessonClient {
  _FakeT02({this.fail = false});

  final bool fail;
  int auxCalls = 0;
  T02LessonRequest? lastRequest;

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) async {
    auxCalls += 1;
    lastRequest = request;
    if (fail) throw StateError('T02 indisponivel');
    return T02LessonMaterial(
      explanation: 'Explicacao ${request.mode}',
      question: 'Pergunta ${request.marker}?',
      options: const {
        AnswerLetter.A: 'Opcao A',
        AnswerLetter.B: 'Opcao B',
        AnswerLetter.C: 'Opcao C',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'Porque A.',
      whyWrong: const {'B': 'Nao.', 'C': 'Nao.'},
      generatedAt: DateTime(2026),
      source: 'auxiliary',
    );
  }

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async =>
      auxiliaryRoom(request);

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) async =>
      auxiliaryRoom(request);

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) async =>
      auxiliaryRoom(request);
}
