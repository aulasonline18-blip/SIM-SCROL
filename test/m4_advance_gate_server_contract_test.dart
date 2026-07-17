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

  test('P2: caminho produtivo A/B/C+sinal nao injeta advance remoto', () {
    final productionOrganism = File(
      'lib/sim/organism/sim_organism.dart',
    ).readAsStringSync();
    final answerController = File(
      'lib/sim/classroom/lesson_answer_progress_controller.dart',
    ).readAsStringSync();
    final runtimeEngine = File(
      'lib/sim/classroom/lesson_runtime_engine.dart',
    ).readAsStringSync();

    expect(
      productionOrganism,
      isNot(contains("server_advance_gate")),
      reason:
          'O organismo de producao nao pode importar nem conectar advance remoto.',
    );
    expect(
      productionOrganism,
      isNot(contains("ServerAdvanceGateClient")),
      reason:
          'A aula produtiva deve receber A/B/C+sinal pelo controller local.',
    );
    expect(
      answerController,
      isNot(contains("ServerAdvanceGateClient")),
      reason:
          'LessonAnswerProgressController e o orgao local do toque simples.',
    );
    expect(
      answerController,
      isNot(contains(".decide(")),
      reason:
          'Enviar sinal nao pode chamar decisor remoto; decide por software local.',
    );
    expect(
      runtimeEngine,
      isNot(contains("ServerAdvanceGateClient")),
      reason:
          'LessonRuntimeEngine.signal/advance nao pode depender de cliente remoto.',
    );
  });
}
