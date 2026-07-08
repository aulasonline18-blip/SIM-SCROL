import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _fixturePath =
    '/root/sim-work/sim-api/docs/contracts/m1_recovery_fixture.json';

void main() {
  test('App accepts the shared M1.8 recovery fixture blocking conclusion', () {
    final file = File(_fixturePath);
    expect(file.existsSync(), isTrue);
    final fixture = Map<String, dynamic>.from(
      jsonDecode(file.readAsStringSync()) as Map,
    );

    expect(fixture['contractName'], 'RecoveryContract');
    expect(fixture['contractVersion'], 'sim.recovery.v1');
    _validateRecovery(fixture);
  });
}

void _validateRecovery(Map<String, dynamic> fixture) {
  final req = Map<String, dynamic>.from(fixture['request'] as Map);
  for (final key in [
    'eventId',
    'idempotencyKey',
    'lessonLocalId',
    'recoveryQueueId',
    'reason',
    'priority',
    'marker',
    'layer',
    'timestamp',
  ]) {
    _expectNonEmptyString(req[key], key);
  }
  expect(req['priority'], isIn(['low', 'medium', 'high']));
  expect(
    req['reason'],
    isIn([
      'wrong_answer',
      'false_mastery',
      'low_confidence',
      'review_failed',
      'repeated_error',
    ]),
  );
  expect(req['answer'], isIn(['A', 'B', 'C']));
  expect(req['signal'], isIn([1, 2, 3]));

  final before = Map<String, dynamic>.from(fixture['before'] as Map);
  expect(before['canConclude'], isFalse);
  expect(
    (before['pendingRecovery'] as List).any(
      (item) =>
          item['recoveryQueueId'] == req['recoveryQueueId'] &&
          item['blocksConclusion'] == true,
    ),
    isTrue,
  );

  final response = Map<String, dynamic>.from(fixture['response'] as Map);
  expect(response['ok'], isTrue);
  expect(
    response['repairStatus'],
    isIn(['released', 'still_pending', 'escalated']),
  );
  expect(response['pendingStillBlocksConclusion'], isTrue);
  expect((response['evidenceUpdate'] as Map)['repairSufficient'], isFalse);

  final after = Map<String, dynamic>.from(fixture['after'] as Map);
  expect(after['canConclude'], isFalse);
  expect(
    (after['pendingRecovery'] as List).any(
      (item) =>
          item['recoveryQueueId'] == req['recoveryQueueId'] &&
          item['blocksConclusion'] == true,
    ),
    isTrue,
  );
}

void _expectNonEmptyString(Object? value, String label) {
  expect(value, isA<String>(), reason: label);
  expect((value as String).trim(), isNotEmpty, reason: label);
}
