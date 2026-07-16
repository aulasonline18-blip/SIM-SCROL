import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M4: app nao possui cliente HTTP para advance gate remoto', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final forbidden = <String>[
      '/api/advance-gate/answer',
      'SimServerAdvanceGateClient',
      'simAdvanceGateAnswerPath',
    ];

    final violations = <String>[];
    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      for (final fragment in forbidden) {
        if (content.contains(fragment)) {
          violations.add('${file.path}: $fragment');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'O caminho quente A/B/C + sinal + avanço e 100% local. '
          'O app nao pode conter cliente HTTP nem endpoint de advance gate.',
    );
  });
}
