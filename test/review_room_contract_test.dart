import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_addendums.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_t02_caller.dart';
import 'package:sim_mobile/sim/auxiliary/review_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_rooms.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  group('Sala de Revisao constitucional', () {
    test('ReviewRoomService cria escolha com 5 como padrao', () {
      final review = ReviewRoomService(_service({'L1': _state()}, _FakeT02()));

      final view = review.createReviewChoiceView();

      expect(view.status, ReviewRoomStatus.choose);
      expect(view.count, 5);
      expect(view.queue, isEmpty);
    });

    test(
      'fila prioriza pendencias reais antigas e respeita limite 5',
      () async {
        final states = {
          'L1': _state(auxRooms: _pendingAux(['M3', 'M1', 'M2'])),
        };
        final review = ReviewRoomService(_service(states, _FakeT02()));

        final view = await review.startReviewRoom(_context('L1'), 5);

        expect(view.status, ReviewRoomStatus.ready);
        expect(view.queue, ['M3', 'M1', 'M2']);
        final savedReview = ensureAuxRooms(states['L1']!)['review'] as Map;
        expect(savedReview['requestedCount'], 5);
        expect(savedReview['currentQueue'], ['M3', 'M1', 'M2']);
      },
    );

    test('startReviewRoom(10) respeita limite 10', () async {
      final markers = List.generate(12, (index) => 'M${index + 1}');
      final states = {
        'L1': _state(itemCount: 12, auxRooms: _pendingAux(markers)),
      };
      final review = ReviewRoomService(_service(states, _FakeT02()));

      final view = await review.startReviewRoom(
        _context('L1', itemCount: 12),
        10,
      );

      expect(view.count, 10);
      expect(view.queue, markers.take(10));
    });

    test(
      'sem pendencia usa curriculo pelo cursor e avanca cursor ao terminar',
      () async {
        final states = {'L1': _state(auxRooms: _reviewCursorAux(2))};
        final review = ReviewRoomService(_service(states, _FakeT02()));
        var view = await review.startReviewRoom(_context('L1'), 5);

        expect(view.queue, ['M3', 'M4', 'M1', 'M2']);

        while (view.status != ReviewRoomStatus.done) {
          view = await review.nextReviewRoom(_context('L1'), view);
        }
        final savedReview = ensureAuxRooms(states['L1']!)['review'] as Map;
        expect(savedReview['sequentialCursor'], 3);
        expect(
          states['L1']!.events.map((event) => event.type),
          contains('REVIEW_CURSOR_UPDATED'),
        );
      },
    );

    test(
      'AuxRoomT02Caller chama T02 real com mode review, adendo e ficha',
      () async {
        final client = _FakeT02();
        final caller = AuxRoomT02Caller(client: client);
        final reference = File(
          '/root/SIM-REFERENCIA/prompts/adendo_revision.txt',
        ).readAsStringSync().replaceFirst('\uFEFF', '').trimRight();

        final result = await caller.call(
          lessonLocalId: 'L1',
          mode: AuxRoomMode.review,
          profile: const AuxRoomProfile(
            stableLang: 'pt-BR',
            academicLevel: 'medio',
            preferredName: 'Ana',
            notes: 'fica insegura com fracoes',
          ),
          marker: 'M2',
          item: 'Frações equivalentes',
          signal: DecisionSignal.two,
          itemIdx: 1,
          confirmEnabled: true,
        );

        expect(result.aborted, isFalse);
        expect(client.auxCalls, 1);
        expect(client.lastRequest?.mode, 'review');
        expect(client.lastRequest?.addendum, reviewRoomAddendum);
        expect(client.lastRequest?.addendum?.trimRight(), reference);
        expect(client.lastRequest?.profile['preferredName'], 'Ana');
        expect(
          client.lastRequest?.profile['notes'],
          'fica insegura com fracoes',
        );
        expect(client.lastRequest?.marker, 'M2');
        expect(client.lastRequest?.itemIdx, 1);
        expect(result.conteudo?.explanation, isNotEmpty);
        expect(result.conteudo?.question, isNotEmpty);
        expect(result.conteudo?.options.keys, containsAll(AnswerLetter.values));
      },
    );

    test(
      'resposta da revisao e auxiliar e nao altera estado oficial',
      () async {
        final states = {
          'L1': _state(auxRooms: _pendingAux(['M2'])),
        };
        final before = states['L1']!;
        final review = ReviewRoomService(_service(states, _FakeT02()));

        var view = await review.startReviewRoom(_context('L1'), 5);
        view = review.selectLetter(view, AnswerLetter.A);
        view = review.answerReviewRoom(
          _context('L1'),
          view,
          DecisionSignal.one,
        );
        final after = states['L1']!;
        final event = after.events.lastWhere(
          (event) => event.type == 'REVIEW_ANSWER_RECORDED',
        );
        final auxReview = ensureAuxRooms(after)['review'] as Map;
        final auxAttempts = (auxReview['attempts'] as List).cast<Map>();

        expect(view.status, ReviewRoomStatus.result);
        expect(after.attempts, before.attempts);
        expect(after.current?.marker, before.current?.marker);
        expect(after.current?.layer, before.current?.layer);
        expect(after.progress?.itemIdx, before.progress?.itemIdx);
        expect(after.progress?.layer, before.progress?.layer);
        expect(
          after.truth.itemConsolidationStatus,
          before.truth.itemConsolidationStatus,
        );
        expect(event.payload['authoritative'], isFalse);
        expect(event.payload['strongEffect'], isFalse);
        expect(event.payload['writesProgress'], isFalse);
        expect(event.payload['writesTruth'], isFalse);
        expect(event.payload['writesMastery'], isFalse);
        expect(event.payload['auxiliary'], isTrue);
        expect(auxAttempts.single['source'], 'review:0');
        expect(auxAttempts.single['authoritative'], isFalse);
      },
    );

    test(
      'falha T02 preserva aula principal e nao cria material fake',
      () async {
        final states = {
          'L1': _state(auxRooms: _pendingAux(['M2'])),
        };
        final before = states['L1']!;
        final review = ReviewRoomService(
          _service(states, _FakeT02(fail: true)),
        );

        final view = await review.startReviewRoom(_context('L1'), 5);
        final after = states['L1']!;

        expect(view.status, ReviewRoomStatus.failed);
        expect(view.conteudo, isNull);
        expect(view.errMsg, contains('preservada'));
        expect(after.current?.marker, before.current?.marker);
        expect(after.progress?.itemIdx, before.progress?.itemIdx);
        expect(after.attempts, before.attempts);
      },
    );

    test('recuperacao ativa tem prioridade sobre revisao manual', () {
      final session = LabSession();
      session.openRecoveryRoom();
      session.openReviewRoom();

      expect(session.recoveryRoom, isNotNull);
      expect(session.reviewRoom, isNull);
    });

    test('UI nao chama T02 direto', () {
      final ui = Directory('lib/features/classroom')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(ui, isNot(contains('T02LessonClient')));
      expect(ui, isNot(contains('AuxRoomT02Caller(')));
      expect(ui, isNot(contains('.auxiliaryRoom(')));
    });
  });
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

ReviewRoomContext _context(String lessonId, {int itemCount = 4}) {
  return ReviewRoomContext(
    lessonLocalId: lessonId,
    topic: 'Matematica',
    items: [
      for (var i = 0; i < itemCount; i++)
        AuxRoomItem(marker: 'M${i + 1}', text: 'Item ${i + 1}', itemIdx: i),
    ],
    fallbackStartIdx: 0,
    layer: LessonLayer.l2,
    profile: const AuxRoomProfile(
      stableLang: 'pt-BR',
      academicLevel: 'medio',
      preferredName: 'Ana',
      notes: 'perfil real',
    ),
  );
}

StudentLearningState _state({JsonMap? auxRooms, int itemCount = 4}) {
  final items = [
    for (var i = 0; i < itemCount; i++)
      CurriculumItem(marker: 'M${i + 1}', text: 'Item ${i + 1}'),
  ];
  return StudentLearningState.empty(lessonLocalId: 'L1').copyWith(
    profile: const StudentProfile(
      stableLang: 'pt-BR',
      academicLevel: 'medio',
      preferredName: 'Ana',
    ),
    curriculum: StudentCurriculum(
      topic: 'Matematica',
      totalItems: items.length,
      generatedAt: 1,
      provisional: false,
      items: items,
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
      totalItems: 4,
      pctAvanco: 25,
    ),
    auxRooms: auxRooms,
  );
}

JsonMap _pendingAux(List<String> markers) {
  final aux = createEmptyAuxRooms();
  aux['pendingMap'] = [
    for (var i = 0; i < markers.length; i++)
      {
        'marker': markers[i],
        'itemIdx': i,
        'layer': 2,
        'signal': 2,
        'reason': 'low_confidence_light',
        'priority': 'medium',
        'origin': 'test',
        'lessonLocalId': 'L1',
        'firstRegisteredAt': i + 1,
        'lastUpdatedAt': i + 1,
        'clearedAt': null,
        'status': 'pending',
      },
  ];
  return aux;
}

JsonMap _reviewCursorAux(int cursor) {
  final aux = createEmptyAuxRooms();
  final review = JsonMap.of(aux['review'] as JsonMap)
    ..['sequentialCursor'] = cursor;
  aux['review'] = review;
  return aux;
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
      explanation: 'Explicacao ${request.mode} ${request.marker}',
      question: 'Pergunta ${request.marker}?',
      options: const {
        AnswerLetter.A: 'Opcao A',
        AnswerLetter.B: 'Opcao B',
        AnswerLetter.C: 'Opcao C',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'Porque A.',
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
