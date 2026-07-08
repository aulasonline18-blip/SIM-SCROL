import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _fixturePath =
    '/root/sim-work/sim-api/docs/contracts/m1_review_fixture.json';

void main() {
  test(
    'App accepts the shared M1.7 review fixture preserving main progress',
    () {
      final file = File(_fixturePath);
      expect(file.existsSync(), isTrue);
      final fixture = Map<String, dynamic>.from(
        jsonDecode(file.readAsStringSync()) as Map,
      );

      expect(fixture['contractName'], 'ReviewContract');
      expect(fixture['contractVersion'], 'sim.review.v1');
      _validateReview(fixture);
    },
  );
}

void _validateReview(Map<String, dynamic> fixture) {
  final req = Map<String, dynamic>.from(fixture['request'] as Map);
  for (final key in [
    'eventId',
    'idempotencyKey',
    'lessonLocalId',
    'reviewQueueId',
    'marker',
    'layer',
    'timestamp',
  ]) {
    _expectNonEmptyString(req[key], key);
  }
  expect(req['itemIdx'], isA<num>());
  expect(req['answer'], isIn(['A', 'B', 'C']));
  expect(req['signal'], isIn([1, 2, 3]));

  final before = Map<String, dynamic>.from(fixture['before'] as Map);
  final queue = before['reviewQueue'] as List;
  expect(
    queue.any((item) => item['reviewQueueId'] == req['reviewQueueId']),
    isTrue,
  );

  final response = Map<String, dynamic>.from(fixture['response'] as Map);
  expect(response['ok'], isTrue);
  expect(response['reviewResult'], isIn(['passed', 'failed', 'needs_recheck']));
  expect(response['eventRecorded'], isTrue);
  expect(response['mainProgressPreserved'], isTrue);

  final after = Map<String, dynamic>.from(fixture['after'] as Map);
  expect(after['mainProgress'], before['mainProgress']);
}

void _expectNonEmptyString(Object? value, String label) {
  expect(value, isA<String>(), reason: label);
  expect((value as String).trim(), isNotEmpty, reason: label);
}
