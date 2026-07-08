import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _fixturePath =
    '/root/sim-work/sim-api/docs/contracts/m1_human_error_fixture.json';

void main() {
  test(
    'App accepts the shared M1.11 human error fixture without raw leakage',
    () {
      final file = File(_fixturePath);
      expect(file.existsSync(), isTrue);
      final fixture = Map<String, dynamic>.from(
        jsonDecode(file.readAsStringSync()) as Map,
      );

      expect(fixture['contractName'], 'HumanTechnicalErrorContract');
      expect(fixture['contractVersion'], 'sim.error.v1');
      final normalized = Map<String, dynamic>.from(
        fixture['normalized'] as Map,
      );
      expect(normalized['ok'], isFalse);
      expect(normalized['contractVersion'], 'sim.error.v1');
      _expectNonEmptyString(normalized['requestId'], 'requestId');
      expect(normalized['status'], 'failed');

      final humanError = Map<String, dynamic>.from(
        normalized['humanError'] as Map,
      );
      _expectNonEmptyString(humanError['message'], 'humanError.message');
      expect(
        humanError['action'],
        isIn(['retry', 'continue', 'restore', 'contact_support', 'none']),
      );

      final technical = Map<String, dynamic>.from(
        normalized['technical'] as Map,
      );
      _expectNonEmptyString(technical['code'], 'technical.code');
      expect(technical['retryable'], isA<bool>());
      expect(technical['httpStatus'], isA<num>());

      for (final forbidden in fixture['forbiddenForStudent'] as List) {
        expect(
          (humanError['message'] as String).contains(forbidden.toString()),
          isFalse,
          reason: '$forbidden must not be shown to student',
        );
      }
    },
  );
}

void _expectNonEmptyString(Object? value, String label) {
  expect(value, isA<String>(), reason: label);
  expect((value as String).trim(), isNotEmpty, reason: label);
}
