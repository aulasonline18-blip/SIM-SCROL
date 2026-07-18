import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Iterable<File> dartFilesUnder(String path) sync* {
    final root = Directory(path);
    if (!root.existsSync()) return;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) yield entity;
    }
  }

  test('M4: app nao possui cliente HTTP para advance gate remoto', () {
    final forbidden = <String>[
      '/api/advance-gate/answer',
      'SimServerAdvanceGateClient',
      'simAdvanceGateAnswerPath',
    ];

    final violations = <String>[];
    for (final file in dartFilesUnder('lib')) {
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

  test('M4: testes ativos nao recriam advance gate remoto', () {
    final forbidden = <String>[
      "import 'legacy/server_advance_gate_legacy.dart'",
      'import "legacy/server_advance_gate_legacy.dart"',
      'ServerAdvanceGateClient',
      'applyServerAdvanceGateDecision',
      'recordPendingServerAdvanceGate',
      '/api/advance-gate/answer',
      'simAdvanceGateAnswerPath',
      'serverAdvanceGateClient',
    ];
    final violations = <String>[];
    for (final file in dartFilesUnder('test')) {
      if (file.path == 'test/m4_advance_gate_server_contract_test.dart' ||
          file.path == 'test/p2_app_first_real_contract_test.dart') {
        continue;
      }
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
          'O legado de advance gate remoto deve ficar quarantinado; testes '
          'ativos da aula principal precisam provar motor local sem injetar '
          'decisor remoto.',
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
