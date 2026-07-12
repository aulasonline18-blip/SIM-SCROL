import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/auxiliary/server_review_contract.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

class FakeReviewTransport implements ServerReviewTransport {
  final bodies = <JsonMap>[];

  @override
  Future<JsonMap> postReview(JsonMap body) async {
    bodies.add(JsonMap.of(body));
    if (body['action'] == 'answer') {
      return {
        'ok': true,
        'accepted': true,
        'duplicate': false,
        'mainProgressPreserved': true,
        'result': {
          'reviewId': body['reviewId'],
          'marker': body['marker'],
          'selectedOption': body['selectedOption'],
          'signal': body['signal'],
          'correct': true,
          'timestamp': body['timestamp'],
          'idempotencyKey': body['idempotencyKey'],
        },
        'evidence': {
          'item_consolidation_status': {'M1': 'needs_review'},
        },
        'contractVersion': 'sim.auxiliary.review.v1',
        'flow': 'review',
        'nextAction': 'return_to_lesson',
        'stateEffect': {
          'strongAdvance': false,
          'writesProgress': false,
          'preservesCurrent': true,
        },
      };
    }
    return {
      'ok': true,
      'item': {
        'reviewId': 'rev-m1',
        'slotKey': 'review:rev-m1',
        'marker': 'M1',
        'itemIdx': 0,
        'layer': 'review',
        'question': 'Qual alternativa define melhor forca?',
        'options': {'A': 'Interacao', 'B': 'Cor', 'C': 'Som'},
        'correctOption': 'A',
        'explanation': 'Forca e interacao.',
        'feedback': {'correct': 'Registrado'},
        'status': 'ready',
        'schemaVersion': 1,
        'updatedAt': '2026-07-08T00:00:00.000Z',
        'humanError': null,
        'contractVersion': 'sim.auxiliary.review.v1',
        'flow': 'review',
        'nextAction': 'show_aux_room',
        'stateEffect': {
          'strongAdvance': false,
          'writesProgress': false,
          'preservesCurrent': true,
        },
      },
    };
  }
}

void main() {
  test('M6 App entende ReviewSchedule do servidor', () {
    final schedule = ServerReviewSchedule.fromJson({
      'reviewId': 'rev-m1',
      'lessonLocalId': 'lesson-m6',
      'userId': 'u1',
      'sessionId': 's1',
      'marker': 'M1',
      'itemIdx': 0,
      'dueAt': '2026-07-08T00:00:00.000Z',
      'reviewType': 'quick',
      'priority': 'high',
      'reason': 'low_confidence',
      'sourceEvidence': {'status': 'needs_review'},
      'completed': false,
      'createdAt': '2026-07-08T00:00:00.000Z',
      'updatedAt': '2026-07-08T00:00:00.000Z',
    });

    expect(schedule.reviewId, 'rev-m1');
    expect(schedule.marker, 'M1');
    expect(schedule.priority, 'high');
    expect(schedule.completed, isFalse);
    expect(schedule.sourceEvidence['status'], 'needs_review');
  });

  test('M6 App entende item de revisao A/B/C do servidor', () {
    final item = ServerReviewItem.fromJson({
      'reviewId': 'rev-m1',
      'slotKey': 'review:rev-m1',
      'marker': 'M1',
      'itemIdx': 0,
      'question': 'Pergunta?',
      'options': {'A': 'A', 'B': 'B', 'C': 'C'},
      'correctOption': 'B',
      'status': 'ready',
      'schemaVersion': 1,
      'updatedAt': '2026-07-08T00:00:00.000Z',
    });

    expect(item.ready, isTrue);
    expect(item.correctOption, AnswerLetter.B);
    expect(item.options[AnswerLetter.C], 'C');
    expect(item.contractVersion, 'sim.auxiliary.review.v1');
    expect(item.flow, 'review');
    expect(item.nextAction, 'show_aux_room');
  });

  test('M6 App envia resposta de revisao sem decidir dominio final', () async {
    final transport = FakeReviewTransport();
    final client = ServerReviewClient(transport);

    final item = await client.next(
      lessonLocalId: 'lesson-m6',
      idempotencyKey: 'open-review-m1',
    );
    expect(item, isNotNull);
    expect(item!.ready, isTrue);

    final before = {
      'lessonLocalId': 'lesson-m6',
      'current': {'itemIdx': 0, 'layer': 2},
      'truth': {
        'item_consolidation_status': {'M1': 'needs_review'},
      },
    };

    final result = await client.answer(
      const ServerReviewAnswerRequest(
        lessonLocalId: 'lesson-m6',
        reviewId: 'rev-m1',
        marker: 'M1',
        selectedOption: AnswerLetter.A,
        signal: DecisionSignal.two,
        idempotencyKey: 'answer-review-m1',
        timestamp: '2026-07-08T00:00:01.000Z',
      ),
    );

    expect(result.accepted, isTrue);
    expect(result.correct, isTrue);
    expect(result.mainProgressPreserved, isTrue);
    expect(result.contractVersion, 'sim.auxiliary.review.v1');
    expect(result.flow, 'review');
    expect(result.nextAction, 'return_to_lesson');
    expect(result.stateEffect['strongAdvance'], isFalse);
    expect(result.stateEffect['writesProgress'], isFalse);
    expect(transport.bodies.last['action'], 'answer');
    expect(transport.bodies.last['idempotencyKey'], 'answer-review-m1');

    final after = before;
    expect((after['current'] as Map)['itemIdx'], 0);
    expect((after['current'] as Map)['layer'], 2);
    expect(
      ((after['truth'] as Map)['item_consolidation_status'] as Map)['M1'],
      'needs_review',
    );
  });

  test('M6 erro de revisao vira humano e controlado', () {
    final result = ServerReviewAnswerResult.fromJson({
      'accepted': false,
      'duplicate': false,
      'humanError': {
        'message': 'Nao consegui concluir a revisao agora.',
        'action': 'try_again',
      },
    });

    expect(result.accepted, isFalse);
    expect(result.humanError?['message'], contains('revisao'));
    expect(result.humanError.toString(), isNot(contains('stack')));
    expect(result.humanError.toString(), isNot(contains('{error')));
  });
}
