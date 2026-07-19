import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/auxiliary/amparo_room_engine.dart';
import 'package:sim_mobile/sim/auxiliary/amparo_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_addendums.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_t02_caller.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_rooms.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/organism/sim_organism.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  group('Sala Amparo constitucional', () {
    test('nao abre com 1 ou 2 agravantes', () {
      var state = _state();
      state = _gate(state, _attempt(false, DecisionSignal.one, 1));
      expect(_amparo(state)['pending'], isFalse);

      state = _gate(state, _attempt(false, DecisionSignal.two, 2));
      expect(_amparo(state)['pending'], isFalse);
      expect(_amparo(state)['sequenceCount'], 2);
    });

    test('abre com 3 erros consecutivos', () {
      var state = _state();
      for (var i = 1; i <= 3; i++) {
        state = _gate(state, _attempt(false, DecisionSignal.one, i));
      }

      expect(_amparo(state)['pending'], isTrue);
      expect(_amparo(state)['amparoLvl'], 1);
      expect(_amparo(state)['sequenceCount'], 0);
      expect(
        state.events.map((event) => event.type),
        contains('AMPARO_TRIGGERED'),
      );
    });

    test('abre com 3 sinais 3 consecutivos quando nao houve acerto', () {
      var state = _state();
      for (var i = 1; i <= 3; i++) {
        state = _gate(state, _attempt(false, DecisionSignal.three, i));
      }

      expect(_amparo(state)['pending'], isTrue);
      expect(_amparo(state)['recentAggravants'], isEmpty);
      expect((_amparo(state)['triggeredAggravants'] as List), hasLength(3));
    });

    test('abre com mistura consecutiva de erro e sinal 3', () {
      var state = _state();
      state = _gate(state, _attempt(false, DecisionSignal.one, 1));
      state = _gate(state, _attempt(false, DecisionSignal.three, 2));
      state = _gate(state, _attempt(false, DecisionSignal.two, 3));

      expect(_amparo(state)['pending'], isTrue);
      expect(_amparo(state)['amparoLvl'], 1);
    });

    test('qualquer acerto zera sequencia, mesmo acerto com sinal 3', () {
      var state = _state();
      state = _gate(state, _attempt(false, DecisionSignal.one, 1));
      state = _gate(state, _attempt(true, DecisionSignal.three, 2));
      state = _gate(state, _attempt(false, DecisionSignal.three, 3));

      expect(_amparo(state)['pending'], isFalse);
      expect(_amparo(state)['sequenceCount'], 1);
      expect(
        state.events.map((event) => event.type),
        contains('AMPARO_SEQUENCE_RESET'),
      );
    });

    test('sinal 2 correto nao conta como agravante', () {
      final state = _gate(_state(), _attempt(true, DecisionSignal.two, 1));

      expect(_amparo(state)['pending'], isFalse);
      expect(_amparo(state)['sequenceCount'], 0);
    });

    test('maximo de 3 ciclos de amparo', () {
      var state = _state();
      for (var cycle = 0; cycle < 4; cycle++) {
        for (var i = 0; i < 3; i++) {
          state = _gate(
            state,
            _attempt(false, DecisionSignal.three, cycle * 10 + i),
          );
        }
        final amparo = JsonMap.of(_amparo(state).cast<String, dynamic>())
          ..['pending'] = false;
        final aux = ensureAuxRooms(state)..['amparo'] = amparo;
        state = state.copyWith(auxRooms: aux);
      }

      expect(_amparo(state)['completedCycles'], 3);
      expect(_amparo(state)['amparoLvl'], 3);
    });

    test(
      'planta fixa tem as 3 estacoes constitucionais e nao usa T00 runtime',
      () {
        final stations = const AmparoPlanEngine().buildStations();
        final auxRuntime = Directory('lib/sim/auxiliary')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .map((file) => file.readAsStringSync())
            .join('\n');

        expect(stations.map((station) => station.marker), [
          'AMPARO_001',
          'AMPARO_002',
          'AMPARO_003',
        ]);
        expect(stations.map((station) => station.amparoType), [
          'reestablishment',
          'reconnection',
          'recovery_of_capacity',
        ]);
        expect(auxRuntime, isNot(contains('adendo_amparo_t00')));
        expect(auxRuntime, isNot(contains('T00Client')));
      },
    );

    test('T02 recebe mode amparo, nivel, estacao e adendo literal', () async {
      final client = _FakeT02();
      final service = _service({'L1': _triggeredState()}, client);
      final room = AmparoRoomService(service);
      final reference = File(
        '/root/SIM-REFERENCIA/prompts/adendo_amparo_t02.txt',
      ).readAsStringSync().replaceFirst('\uFEFF', '').trimRight();

      final view = await room.startAmparoRoom(_context());

      expect(view.status, AmparoRoomStatus.ready);
      expect(client.auxCalls, 1);
      expect(client.lastRequest?.mode, 'amparo');
      expect(client.lastRequest?.amparoLvl, 1);
      expect(client.lastRequest?.addendum, amparoRoomAddendum);
      expect(client.lastRequest?.addendum?.trimRight(), reference);
      expect(client.lastRequest?.marker, 'M2');
      expect(client.lastRequest?.profile['amparo_step_marker'], 'AMPARO_001');
      expect(client.lastRequest?.profile['amparo_type'], 'reestablishment');
      expect(client.lastRequest?.profile['current_question'], isNotEmpty);
    });

    test(
      'resposta fica em auxRooms.amparo e nao altera estado oficial',
      () async {
        final states = {'L1': _triggeredState()};
        final before = states['L1']!;
        final room = AmparoRoomService(_service(states, _FakeT02()));

        var view = await room.startAmparoRoom(_context());
        view = room.selectLetter(view, AnswerLetter.A);
        view = room.answerAmparoRoom(_context(), view, DecisionSignal.one);
        final after = states['L1']!;
        final attempt =
            (((ensureAuxRooms(after)['amparo'] as Map)['attempts'] as List)
                .cast<Map>()
                .single);
        final event = after.events.lastWhere(
          (event) => event.type == 'AMPARO_ANSWER_RECORDED',
        );

        expect(view.status, AmparoRoomStatus.result);
        expect(after.current?.marker, before.current?.marker);
        expect(after.progress?.itemIdx, before.progress?.itemIdx);
        expect(after.progress?.layer, before.progress?.layer);
        expect(after.attempts, before.attempts);
        expect(after.truth.toJson(), before.truth.toJson());
        expect(attempt['source'], 'amparo:0');
        expect(event.payload['authoritative'], isFalse);
        expect(event.payload['writesProgress'], isFalse);
        expect(event.payload['writesTruth'], isFalse);
        expect(event.payload['writesMastery'], isFalse);
        expect(event.payload['requiresServerDecision'], isFalse);
      },
    );

    test('falha T02 preserva aula principal', () async {
      final states = {'L1': _triggeredState()};
      final before = states['L1']!;
      final room = AmparoRoomService(_service(states, _FakeT02(fail: true)));

      final view = await room.startAmparoRoom(_context());
      final after = states['L1']!;

      expect(view.status, AmparoRoomStatus.failed);
      expect(view.errMsg, contains('preservada'));
      expect(after.current?.marker, before.current?.marker);
      expect(after.progress?.itemIdx, before.progress?.itemIdx);
      expect(after.attempts, before.attempts);
    });

    test('rota /cyber/amparo passa pelo roteador oficial', () {
      final allowed = const SimOrganismRouter().resolve(
        path: '/cyber/amparo',
        authed: true,
        hasLanguage: true,
        hasObjective: true,
      );
      final blocked = const SimOrganismRouter().resolve(
        path: '/cyber/amparo',
        authed: false,
        hasLanguage: true,
        hasObjective: true,
      );

      expect(allowed.allowed, isTrue);
      expect(blocked.destination, '/login');
    });

    test('UI nao chama T02 diretamente nem rota legada', () {
      final ui = Directory('lib/features/classroom')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');
      final runtime = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(ui, isNot(contains('T02LessonClient')));
      expect(ui, isNot(contains('AuxRoomT02Caller(')));
      expect(runtime, isNot(contains('/api/amparo')));
    });
  });
}

StudentLearningState _gate(StudentLearningState state, LessonAttempt attempt) {
  return const AmparoGate().recordOfficialAttempt(state, attempt, itemIdx: 1);
}

LessonAttempt _attempt(bool correct, DecisionSignal signal, int ts) {
  return LessonAttempt(
    marker: 'M2',
    layer: LessonLayer.l2,
    letra: correct ? AnswerLetter.A : AnswerLetter.B,
    sinal: signal,
    correct: correct,
    ts: ts,
  );
}

Map _amparo(StudentLearningState state) =>
    ensureAuxRooms(state)['amparo'] as Map;

StudentLearningState _triggeredState() {
  final aux = ensureAuxRooms(_state());
  aux['amparo'] = JsonMap.of(aux['amparo'] as JsonMap)
    ..['pending'] = true
    ..['amparoLvl'] = 1
    ..['completedCycles'] = 1
    ..['lastTriggeredMarker'] = 'M2'
    ..['lastTriggeredLayer'] = 2
    ..['triggeredAggravants'] = [
      {'marker': 'M2', 'layer': 2, 'sinal': 3, 'correct': false},
      {'marker': 'M2', 'layer': 2, 'sinal': 3, 'correct': false},
      {'marker': 'M2', 'layer': 2, 'sinal': 3, 'correct': false},
    ];
  return _state(auxRooms: aux);
}

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

AmparoRoomContext _context() {
  return const AmparoRoomContext(
    lessonLocalId: 'L1',
    topic: 'Matematica',
    items: [
      AuxRoomItem(marker: 'M1', text: 'Item 1', itemIdx: 0),
      AuxRoomItem(marker: 'M2', text: 'Frações equivalentes', itemIdx: 1),
    ],
    itemIdx: 1,
    marker: 'M2',
    layer: LessonLayer.l2,
    profile: AuxRoomProfile(
      stableLang: 'pt-BR',
      academicLevel: 'medio',
      preferredName: 'Ana',
      notes: 'perfil real',
    ),
    currentExplanation: 'Explicacao atual',
    currentQuestion: 'Qual fracao e equivalente a 1/2?',
    currentOptions: {
      AnswerLetter.A: '2/4',
      AnswerLetter.B: '3/4',
      AnswerLetter.C: '4/4',
    },
    selectedAnswer: AnswerLetter.B,
    correctAnswer: AnswerLetter.A,
    signal: DecisionSignal.three,
  );
}

StudentLearningState _state({JsonMap? auxRooms}) {
  return StudentLearningState.empty(lessonLocalId: 'L1').copyWith(
    profile: const StudentProfile(
      stableLang: 'pt-BR',
      academicLevel: 'medio',
      preferredName: 'Ana',
    ),
    curriculum: StudentCurriculum(
      topic: 'Matematica',
      totalItems: 2,
      generatedAt: 1,
      provisional: false,
      items: const [
        CurriculumItem(marker: 'M1', text: 'Item 1'),
        CurriculumItem(marker: 'M2', text: 'Frações equivalentes'),
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
      totalItems: 2,
      pctAvanco: 50,
    ),
    auxRooms: auxRooms,
  );
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
    if (fail) throw StateError('T02 offline');
    return T02LessonMaterial(
      explanation: 'Vamos reduzir o caminho.',
      question: 'Qual passo agora fica claro?',
      options: const {
        AnswerLetter.A: 'Caminho A',
        AnswerLetter.B: 'Caminho B',
        AnswerLetter.C: 'Caminho C',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'Caminho retomado.',
      whyWrong: const {},
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: request.mode,
    );
  }

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) =>
      auxiliaryRoom(request);

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) =>
      auxiliaryRoom(request);

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) =>
      auxiliaryRoom(request);
}
