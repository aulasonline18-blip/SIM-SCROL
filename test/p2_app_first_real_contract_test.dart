import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  Iterable<File> dartFilesUnder(String path) sync* {
    final root = Directory(path);
    if (!root.existsSync()) return;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) yield entity;
    }
  }

  test('P2: runtime produtivo nao usa servidor como gate do toque simples', () {
    final organism = read('lib/sim/organism/sim_organism.dart');
    final session = [
      read('lib/features/session/lab_session.dart'),
      read('lib/features/session/lab_session_flows.dart'),
    ].join('\n');
    final materialController = read(
      'lib/sim/classroom/lesson_material_controller.dart',
    );
    final materialService = read(
      'lib/sim/lesson/student_lesson_material_service.dart',
    );
    final experienceEngine = read(
      'lib/sim/experience/student_experience_engine.dart',
    );
    final auxService = read('lib/sim/auxiliary/student_aux_room_service.dart');

    expect(organism, isNot(contains('runShadowDecision(')));
    expect(organism, isNot(contains('ServerReviewClient(')));
    expect(organism, isNot(contains('ServerRecoveryClient(')));

    expect(session, isNot(contains("state?.extra['serverAdvanceGate']")));
    expect(session, contains('_hasLocalOfficialAulaState'));
    expect(session, contains('_listDrawerLocalLessonSummaries'));
    expect(session, contains('_reconcileDrawerCloudLessonInBackground'));

    expect(
      materialController,
      contains('material_missing_prepare_without_fallback'),
    );
    expect(materialController, isNot(contains('_localFallbackMaterial')));
    expect(
      materialController,
      isNot(contains('LessonMaterialSource.localFallback')),
    );
    expect(
      materialController,
      isNot(contains('A primeira aula foi liberada, mas a tela nao encontrou')),
    );
    expect(materialService, contains('this.allowRemoteOrder = false'));
    expect(materialService, contains('priority: \'background\''));
    expect(experienceEngine, isNot(contains('T02 obrigatorio')));

    expect(auxService, contains("'requiresServerDecision': false"));
    expect(auxService, contains('sim_app_local_aux_evidence'));
    expect(auxService, isNot(contains('_localAuxRoomFallbackContent')));
  });

  test('P2: marcadores de gate remoto ficam fora do runtime principal', () {
    final forbiddenRuntimeSnippets = [
      "priority: 'active'",
      'priority: "active"',
      "requiresServerDecision': true",
      '"requiresServerDecision": true',
      'ServerAdvanceGateClient',
      'serverAdvanceGate',
      'applyServerAdvanceGateDecision',
      'recordPendingServerAdvanceGate',
      '/api/advance-gate/answer',
    ];

    for (final file in dartFilesUnder('lib')) {
      final path = file.path;
      final text = file.readAsStringSync();
      for (final snippet in forbiddenRuntimeSnippets) {
        expect(text, isNot(contains(snippet)), reason: '$snippet em $path');
      }
    }
  });
}
