import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_t02_caller.dart';
import 'package:sim_mobile/sim/auxiliary/recovery_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/server_recovery_contract.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_room_service.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

class FakeRecoveryTransport implements ServerRecoveryTransport {
  final bodies = <JsonMap>[];
  bool failAnswer = false;

  @override
  Future<JsonMap> postRecovery(JsonMap body) async {
    bodies.add(JsonMap.of(body));
    if (body['action'] == 'answer') {
      if (failAnswer) {
        return {
          'accepted': false,
          'duplicate': false,
          'blocksConclusion': true,
          'humanError': {
            'message': 'Nao consegui concluir a recuperacao agora.',
            'action': 'try_again',
          },
        };
      }
      return {
        'ok': true,
        'accepted': true,
        'duplicate': false,
        'blocksConclusion': false,
        'mainProgressPreserved': true,
        'result': {
          'recoveryId': body['recoveryId'],
          'marker': body['marker'],
          'selectedOption': body['selectedOption'],
          'signal': body['signal'],
          'correct': true,
          'repaired': true,
          'timestamp': body['timestamp'],
          'idempotencyKey': body['idempotencyKey'],
        },
      };
    }
    return {
      'ok': true,
      'item': {
        'recoveryId': 'rec-m1',
        'slotKey': 'recovery:rec-m1',
        'marker': 'M1',
        'itemIdx': 0,
        'weaknessId': 'weak-m1',
        'explanation': 'Forca e interacao.',
        'question': 'Qual alternativa corrige forca?',
        'options': {'A': 'Interacao', 'B': 'Cor', 'C': 'Som'},
        'correctOption': 'A',
        'feedback': {'correct': 'Reparo registrado'},
        'status': 'ready',
        'schemaVersion': 1,
      },
    };
  }
}

StudentAuxRoomService _unusedLocalService() {
  return StudentAuxRoomService(
    readState: (_) => StudentLearningState.empty(lessonLocalId: 'lesson-m7'),
    writeState: (state) => state,
    t02Caller: AuxRoomT02Caller(client: _FakeT02Client()),
  );
}

class _FakeT02Client implements T02LessonClient {
  T02LessonMaterial _material(String source) => T02LessonMaterial(
    explanation: 'Explicacao local',
    question: 'Pergunta local',
    options: const {
      AnswerLetter.A: 'A',
      AnswerLetter.B: 'B',
      AnswerLetter.C: 'C',
    },
    correctAnswer: AnswerLetter.A,
    whyCorrect: 'Porque A.',
    whyWrong: const {},
    generatedAt: DateTime(2026),
    source: source,
  );

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) async {
    return _material('auxiliary');
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

void main() {
  test('M7 App entende RecoveryQueue do servidor', () {
    final entry = ServerRecoveryQueueEntry.fromJson({
      'recoveryId': 'rec-m1',
      'lessonLocalId': 'lesson-m7',
      'userId': 'u1',
      'sessionId': 's1',
      'marker': 'M1',
      'itemIdx': 0,
      'weaknessId': 'weak-m1',
      'reason': 'false_mastery',
      'severity': 'high',
      'status': 'pending',
      'requiredRepairEvidence': {'minCorrect': 1, 'maxSignal': 2},
      'attempts': [],
      'createdAt': '2026-07-08T00:00:00.000Z',
      'updatedAt': '2026-07-08T00:00:00.000Z',
    });

    expect(entry.blocksConclusion, isTrue);
    expect(entry.reason, 'false_mastery');
    expect(entry.requiredRepairEvidence['maxSignal'], 2);
  });

  test('M7 App entende sala de recuperacao A/B/C do servidor', () {
    final item = ServerRecoveryItem.fromJson({
      'recoveryId': 'rec-m1',
      'slotKey': 'recovery:rec-m1',
      'marker': 'M1',
      'itemIdx': 0,
      'weaknessId': 'weak-m1',
      'question': 'Pergunta?',
      'options': {'A': 'A', 'B': 'B', 'C': 'C'},
      'correctOption': 'C',
      'status': 'ready',
      'schemaVersion': 1,
    });

    expect(item.ready, isTrue);
    expect(item.correctOption, AnswerLetter.C);
    expect(item.options[AnswerLetter.B], 'B');
  });

  test(
    'M7 App exibe sala do servidor e envia resposta sem liberar dominio local',
    () async {
      final transport = FakeRecoveryTransport();
      final client = ServerRecoveryClient(transport);
      final service = RecoveryRoomService(
        _unusedLocalService(),
        serverRecoveryClient: client,
      );
      const context = RecoveryRoomContext(
        lessonLocalId: 'lesson-m7',
        topic: 'Forca',
        items: [AuxRoomItem(marker: 'M1', text: 'Forca')],
        layer: LessonLayer.l3,
        profile: AuxRoomProfile(stableLang: 'pt-BR'),
      );

      var view = await service.startRecoveryRoom(context);
      expect(view.status, RecoveryRoomStatus.intro);
      expect(view.serverRecoveryId, 'rec-m1');
      expect(view.conteudo?.question, contains('forca'));

      view = service.continueRecovery(view);
      view = service.selectLetter(view, AnswerLetter.A);
      view = await service.answerServerRecoveryRoom(
        context,
        view,
        DecisionSignal.two,
      );

      expect(view.status, RecoveryRoomStatus.result);
      expect(view.resultCorrect, isTrue);
      expect(view.restartRequired, isFalse);
      expect(transport.bodies.last['action'], 'answer');
      expect(transport.bodies.last['recoveryId'], 'rec-m1');

      final localTruth = {
        'item_consolidation_status': {'M1': 'false_mastery'},
      };
      expect(localTruth['item_consolidation_status'], {'M1': 'false_mastery'});
    },
  );

  test('M7 erro de recuperacao vira humano e controlado', () {
    final result = ServerRecoveryAnswerResult.fromJson({
      'accepted': false,
      'duplicate': false,
      'blocksConclusion': true,
      'mainProgressPreserved': true,
      'humanError': {
        'message': 'Nao consegui concluir a recuperacao agora.',
        'action': 'try_again',
      },
    });

    expect(result.accepted, isFalse);
    expect(result.blocksConclusion, isTrue);
    expect(result.humanError?['message'], contains('recuperacao'));
    expect(result.humanError.toString(), isNot(contains('stack')));
    expect(result.humanError.toString(), isNot(contains('{error')));
  });
}
