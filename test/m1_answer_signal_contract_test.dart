import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _fixturePath =
    '/root/sim-work/sim-api/docs/contracts/m1_answer_signal_fixture.json';

void main() {
  test('App accepts and rejects the shared M1.5 answer signal fixture', () {
    final fixtureFile = File(_fixturePath);
    expect(
      fixtureFile.existsSync(),
      isTrue,
      reason: 'M1.5 uses the server docs/contracts fixture as source.',
    );

    final decoded = jsonDecode(fixtureFile.readAsStringSync());
    expect(decoded, isA<Map<String, dynamic>>());
    final fixture = Map<String, dynamic>.from(decoded as Map);

    expect(fixture['contractName'], 'StudentAnswerSignalContract');
    expect(fixture['contractVersion'], 'sim.answer_signal.v1');

    final valid = Map<String, dynamic>.from(fixture['valid'] as Map);
    final validated = _validateAnswerSignal(valid);
    expect(validated.answer, valid['answer']);
    expect(validated.signal, valid['signal']);
    expect(validated.marker, valid['marker']);
    expect(validated.layer, valid['layer']);

    final expectedResponse = Map<String, dynamic>.from(
      fixture['expectedResponse'] as Map,
    );
    expect(expectedResponse['eventRecorded'], isTrue);
    expect(
      expectedResponse['nextAction'],
      isIn([
        'continue_same_item',
        'next_layer',
        'advance_item',
        'review',
        'required_recovery',
        'support',
        'pause',
      ]),
    );

    final invalidCases = (fixture['invalid'] as List)
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    expect(invalidCases, isNotEmpty);
    for (final invalid in invalidCases) {
      final payload = Map<String, dynamic>.from(invalid['payload'] as Map);
      expect(
        () => _validateAnswerSignal(payload),
        throwsA(
          isA<_AnswerSignalContractException>().having(
            (error) => error.code,
            'code',
            invalid['expectedCode'],
          ),
        ),
        reason: invalid['name']?.toString(),
      );
    }
  });
}

_ValidatedAnswerSignal _validateAnswerSignal(Map<String, dynamic> payload) {
  for (final key in [
    'eventId',
    'idempotencyKey',
    'lessonLocalId',
    'marker',
    'slotKey',
    'timestamp',
    'source',
  ]) {
    final value = payload[key];
    if (value is! String || value.trim().isEmpty) {
      throw const _AnswerSignalContractException();
    }
  }
  for (final key in ['itemIdx', 'layer', 'attempt']) {
    if (payload[key] is! num) throw const _AnswerSignalContractException();
  }
  final answer = payload['answer']?.toString().toUpperCase();
  if (!const ['A', 'B', 'C'].contains(answer)) {
    throw const _AnswerSignalContractException();
  }
  final signal = (payload['signal'] as num?)?.toInt();
  if (!const [1, 2, 3].contains(signal)) {
    throw const _AnswerSignalContractException();
  }
  if (payload['correct'] is! bool) throw const _AnswerSignalContractException();
  return _ValidatedAnswerSignal(
    answer: answer!,
    signal: signal!,
    marker: payload['marker'] as String,
    layer: (payload['layer'] as num).toInt(),
  );
}

class _ValidatedAnswerSignal {
  const _ValidatedAnswerSignal({
    required this.answer,
    required this.signal,
    required this.marker,
    required this.layer,
  });

  final String answer;
  final int signal;
  final String marker;
  final int layer;
}

class _AnswerSignalContractException implements Exception {
  const _AnswerSignalContractException();

  String get code => 'SIM_ANSWER_CONTRACT_INVALID';
}
