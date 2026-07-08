import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _fixturePath =
    '/root/sim-work/sim-api/docs/contracts/m1_student_event_fixture.json';

void main() {
  test('App accepts the shared M1.4 student event fixture idempotently', () {
    final fixtureFile = File(_fixturePath);
    expect(
      fixtureFile.existsSync(),
      isTrue,
      reason: 'M1.4 uses the server docs/contracts fixture as source.',
    );

    final decoded = jsonDecode(fixtureFile.readAsStringSync());
    expect(decoded, isA<Map<String, dynamic>>());
    final fixture = Map<String, dynamic>.from(decoded as Map);

    expect(fixture['contractName'], 'StudentEventContract');
    expect(fixture['contractVersion'], 'sim.student_event.v1');
    _expectNonEmptyString(fixture['lessonLocalId'], 'lessonLocalId');

    final events = (fixture['events'] as List)
        .whereType<Map>()
        .map((event) => Map<String, dynamic>.from(event))
        .toList();
    expect(events, isNotEmpty);
    for (final event in events) {
      _expectStudentEvent(event, fixture);
    }

    final result = _applyEventsIdempotently(events);
    final expected = Map<String, dynamic>.from(fixture['expected'] as Map);
    final progressDelta = Map<String, dynamic>.from(
      expected['progressDelta'] as Map,
    );

    expect(result.accepted.length, expected['uniqueEventCount']);
    expect(result.duplicateCount, expected['duplicateCount']);
    expect(result.attemptsAdded, progressDelta['attemptsAdded']);
    expect(result.mainAdvancesAdded, progressDelta['mainAdvancesAdded']);
  });
}

void _expectStudentEvent(
  Map<String, dynamic> event,
  Map<String, dynamic> root,
) {
  _expectNonEmptyString(event['eventId'], 'eventId');
  _expectNonEmptyString(event['idempotencyKey'], 'idempotencyKey');
  expect(event['lessonLocalId'], root['lessonLocalId']);
  expect(event['itemIdx'], isA<num>());
  _expectNonEmptyString(event['marker'], 'marker');
  expect((event['layer'] as num).toInt(), greaterThanOrEqualTo(1));
  _expectNonEmptyString(event['timestamp'], 'timestamp');
  expect(event['source'], 'sim_app_flutter');
  expect(
    event['type'],
    isIn([
      'ANSWER_SUBMITTED',
      'SIGNAL_SUBMITTED',
      'DOUBT_OPENED',
      'DOUBT_SUBMITTED',
      'REVIEW_OPENED',
      'REVIEW_ANSWERED',
      'RECOVERY_OPENED',
      'RECOVERY_ANSWERED',
      'ADVANCE_REQUESTED',
      'LOCAL_TECHNICAL_ERROR',
      'OFFLINE_SYNC_ENQUEUED',
    ]),
  );
  expect(event['payload'], isA<Map>());
}

_EventApplyResult _applyEventsIdempotently(List<Map<String, dynamic>> events) {
  final seen = <String>{};
  final accepted = <Map<String, dynamic>>[];
  var duplicateCount = 0;
  var attemptsAdded = 0;
  var mainAdvancesAdded = 0;

  for (final event in events) {
    final key = event['idempotencyKey'] as String;
    if (!seen.add(key)) {
      duplicateCount += 1;
      continue;
    }
    accepted.add(event);
    if (event['type'] == 'ANSWER_SUBMITTED') attemptsAdded += 1;
    if (event['type'] == 'ADVANCE_REQUESTED') mainAdvancesAdded += 1;
  }

  return _EventApplyResult(
    accepted: accepted,
    duplicateCount: duplicateCount,
    attemptsAdded: attemptsAdded,
    mainAdvancesAdded: mainAdvancesAdded,
  );
}

void _expectNonEmptyString(Object? value, String label) {
  expect(value, isA<String>(), reason: label);
  expect((value as String).trim(), isNotEmpty, reason: label);
}

class _EventApplyResult {
  const _EventApplyResult({
    required this.accepted,
    required this.duplicateCount,
    required this.attemptsAdded,
    required this.mainAdvancesAdded,
  });

  final List<Map<String, dynamic>> accepted;
  final int duplicateCount;
  final int attemptsAdded;
  final int mainAdvancesAdded;
}
