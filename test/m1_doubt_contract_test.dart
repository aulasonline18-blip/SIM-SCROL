import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _fixturePath =
    '/root/sim-work/sim-api/docs/contracts/m1_doubt_fixture.json';

void main() {
  test('App accepts the shared M1.6 doubt fixture without state mutation', () {
    final fixtureFile = File(_fixturePath);
    expect(fixtureFile.existsSync(), isTrue);

    final decoded = jsonDecode(fixtureFile.readAsStringSync());
    expect(decoded, isA<Map<String, dynamic>>());
    final fixture = Map<String, dynamic>.from(decoded as Map);

    expect(fixture['contractName'], 'DoubtRoomContract');
    expect(fixture['contractVersion'], 'sim.doubt.v1');

    final request = Map<String, dynamic>.from(fixture['request'] as Map);
    final response = Map<String, dynamic>.from(fixture['response'] as Map);
    _validateDoubtRequest(request);
    _validateDoubtResponse(response);

    expect(request['marker'], 'M1');
    expect(request['layer'], 1);
    expect(request['selectedAnswer'], 'A');
  });
}

void _validateDoubtRequest(Map<String, dynamic> request) {
  for (final key in [
    'eventId',
    'idempotencyKey',
    'lessonLocalId',
    'marker',
    'currentQuestion',
    'studentQuestion',
  ]) {
    _expectNonEmptyString(request[key], key);
  }
  expect(request['itemIdx'], isA<num>());
  expect((request['layer'] as num).toInt(), greaterThanOrEqualTo(1));
  expect(request['selectedAnswer'], anyOf(isNull, isIn(['A', 'B', 'C'])));

  final context = Map<String, dynamic>.from(request['lessonContext'] as Map);
  _expectNonEmptyString(context['explanation'], 'lessonContext.explanation');
  _expectNonEmptyString(context['slotKey'], 'lessonContext.slotKey');
  final options = Map<String, dynamic>.from(context['options'] as Map);
  _expectNonEmptyString(options['A'], 'options.A');
  _expectNonEmptyString(options['B'], 'options.B');
  _expectNonEmptyString(options['C'], 'options.C');

  expect(request['minimalHistory'], isA<List>());
  final idioma = Map<String, dynamic>.from(request['idioma'] as Map);
  _expectNonEmptyString(idioma['interfaceLocale'], 'idioma.interfaceLocale');
  _expectNonEmptyString(idioma['learningLocale'], 'idioma.learningLocale');
}

void _validateDoubtResponse(Map<String, dynamic> response) {
  expect(response['ok'], isTrue);
  _expectNonEmptyString(response['answer'], 'answer');
  expect(response['eventRecorded'], isTrue);
  final mutation = Map<String, dynamic>.from(response['stateMutation'] as Map);
  expect(mutation['progressChanged'], isFalse);
  expect(mutation['domainChanged'], isFalse);
  expect(mutation['answerErased'], isFalse);
}

void _expectNonEmptyString(Object? value, String label) {
  expect(value, isA<String>(), reason: label);
  expect((value as String).trim(), isNotEmpty, reason: label);
}
