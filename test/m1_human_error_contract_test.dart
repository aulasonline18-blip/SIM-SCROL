import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/errors/human_error_policy.dart';
import 'package:sim_mobile/sim/experience/student_experience_guards.dart';

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

  test('Proposicao G saneia erros tecnicos antes da UI', () {
    const forbidden = [
      'Exception',
      'StackTrace',
      'SocketException',
      'FormatException',
      'Null check operator',
      'TypeError',
      'undefined',
      'null',
      'HTTP 500',
      'HTTP 401',
      'XMLHttpRequest',
      'raw JSON',
      'access_token',
      'bearer',
      'prompt',
      'API key',
      '/root/',
      '.dart',
      '{"error"',
    ];
    final rawErrors = [
      'SimExternalAiException HTTP 401: {"error":"Unauthorized","reason":"invalid token","access_token":"secret"}',
      'SocketException: failed host lookup /root/app.dart',
      'FormatException: raw JSON {"error":"server","stack":"boom"}',
      'Null check operator used on a null value',
      'TypeError: undefined is not an object',
      'HTTP 500 {"error":"provider_down","prompt":"T00"}',
    ];

    for (final raw in rawErrors) {
      final message = humanErrorMessage(raw);
      expect(message.trim(), isNotEmpty);
      for (final term in forbidden) {
        expect(
          message.toLowerCase(),
          isNot(contains(term.toLowerCase())),
          reason: '$term leaked in $message',
        );
      }
    }

    final auth = classifyStudentExperienceError(
      'HTTP 401 {"error":"Unauthorized","bearer":"token"}',
    );
    expect(auth.message, contains('sessao'));
    expect(containsForbiddenTechnicalErrorText(auth.message), isFalse);

    final network = classifyStudentExperienceError(
      'SocketException: HTTP 500 {"stack":"boom"}',
    );
    expect(network.message, contains('conexao'));
    expect(containsForbiddenTechnicalErrorText(network.message), isFalse);
  });
}

void _expectNonEmptyString(Object? value, String label) {
  expect(value, isA<String>(), reason: label);
  expect((value as String).trim(), isNotEmpty, reason: label);
}
