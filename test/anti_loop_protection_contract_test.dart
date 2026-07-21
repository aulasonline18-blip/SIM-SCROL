import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lei anti-loop existe e declara protecao constitucional', () {
    final law = File(
      'docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md',
    ).readAsStringSync();

    expect(law, contains('Codigo: LPTAL-1'));
    expect(
      law,
      contains('tao protegidas quanto prompts, T00, T02 e contrato N3'),
    );
    expect(law, contains('anti-loop-protection'));
    expect(law, contains('AiCostProtectionGate'));
    expect(law, contains('ai-cost-protection-gate'));
    expect(law, contains('Retry-After'));
    expect(law, contains('single-flight'));
    expect(law, contains('orcamento por minuto/hora'));
    expect(law, contains('AUDIO_ALREADY_RUNNING'));
    expect(law, contains('DOPAMINE_WINDOW_REQUEST_CAPPED'));
    expect(law, contains('.data/ai-usage-daily.json'));
    expect(law, contains('Versao: 1.1'));
    expect(law, contains('readyWindowWorkerMaxAttempts = 3'));
    expect(law, contains('readyWindowWorkerMaxJobsPerDrain = 15'));
    expect(law, contains('mesa diretora'));
    expect(law, contains('E proibido polling remoto por timer'));
    expect(law, contains('Job que atingiu falha permanente'));
  });

  test('travas anti-loop do app continuam presentes', () {
    final dopamine = File(
      'lib/sim/lesson/dopamine_ready_window_engine.dart',
    ).readAsStringSync();
    final media = File(
      'lib/sim/media/student_lesson_media_service.dart',
    ).readAsStringSync();
    final aiConfig = File(
      'lib/sim/external_ai/sim_ai_server_config.dart',
    ).readAsStringSync();
    final aiClients = File(
      'lib/sim/external_ai/sim_server_ai_clients.dart',
    ).readAsStringSync();
    final worker = File(
      'lib/sim/lesson/ready_window_worker.dart',
    ).readAsStringSync();
    final materialService = File(
      'lib/sim/lesson/student_lesson_material_service.dart',
    ).readAsStringSync();
    final entryFlows = File(
      'lib/features/session/lab_session_entry_flows.dart',
    ).readAsStringSync();
    final sessionFlows = File(
      'lib/features/session/lab_session_flows.dart',
    ).readAsStringSync();
    final session = File(
      'lib/features/session/lab_session.dart',
    ).readAsStringSync();
    final organismProvider = File(
      'lib/sim/organism/sim_organism_provider.dart',
    ).readAsStringSync();
    final readyWindowTest = File(
      'test/first_lesson_ready_window_test.dart',
    ).readAsStringSync();

    expect(dopamine, contains('const int offlineWarmCacheSize = 15'));
    expect(
      dopamine,
      contains('const int localLessonTraySize = offlineWarmCacheSize'),
    );
    expect(dopamine, contains('DOPAMINE_WINDOW_REQUEST_CAPPED'));
    expect(dopamine, contains('_boundedWindowLimit'));
    expect(dopamine, contains('_slotMediaAlreadyRequested'));
    expect(dopamine, contains('status != \'queued\' && status != \'running\''));
    expect(dopamine, contains('mediaType'));
    expect(media, contains('mediaType: SlotMediaType.audio'));
    expect(aiConfig, contains('retryAfter'));
    expect(aiConfig, contains('retry-after'));
    expect(aiClients, contains("'idempotencyKey': idempotencyKey"));
    expect(aiClients, contains('_t02IdempotencyKey'));
    expect(worker, contains('error.retryAfter'));
    expect(worker, contains('300000'));
    expect(worker, contains('readyWindowWorkerMaxAttempts = 3'));
    expect(worker, contains('readyWindowWorkerMaxJobsPerDrain = 15'));
    expect(worker, contains('READY_WINDOW_JOB_FAILED_PERMANENTLY'));
    expect(worker, isNot(contains('max_attempts\': null')));
    expect(materialService, contains('readyWindowWorkerMaxAttempts'));
    expect(materialService, contains("job['status'] == 'failed'"));
    expect(
      entryFlows,
      isNot(contains('while (_isCurrentExperience(id, generation))')),
    );
    expect(sessionFlows, contains('_aulaRuntimeOpen.run'));
    expect(session, contains('_SingleFlightOperation'));
    expect(session, contains('stopReadyWindowWorker()'));
    expect(organismProvider, contains('stopReadyWindowWorker()'));
    expect(readyWindowTest, contains('maxSlots: 50'));
    expect(readyWindowTest, contains('DOPAMINE_WINDOW_REQUEST_CAPPED'));
    expect(readyWindowTest, contains('expect(t02.calls, localLessonTraySize)'));
  });

  test('travas anti-loop do servidor continuam presentes', () {
    final audio = File(
      '/root/sim-work/sim-api/src/media/audio-controller.js',
    ).readAsStringSync();
    final router = File(
      '/root/sim-work/sim-api/src/app/router.js',
    ).readAsStringSync();
    final gate = File(
      '/root/sim-work/sim-api/src/ai/ai-cost-protection-gate.js',
    ).readAsStringSync();
    final t02 = File(
      '/root/sim-work/sim-api/src/t02/complete-lesson-controller.js',
    ).readAsStringSync();
    final mandatoryTest = File(
      '/root/sim-work/sim-api/test/ai_cost_protection_mandatory_law.test.js',
    ).readAsStringSync();
    final manifest = File(
      '/root/sim-work/sim-api/docs/migracao-sim-nv/protected-files.manifest.json',
    ).readAsStringSync();
    final serverTest = File(
      '/root/sim-work/sim-api/test/media_visual_n3_contract.test.js',
    ).readAsStringSync();

    expect(audio, contains('AUDIO_ALREADY_RUNNING'));
    expect(audio, contains("status === 'running'"));
    expect(router, contains('ai-usage-daily.json'));
    expect(router, contains('recordAiUsageDaily'));
    expect(router, contains('createAiCostProtectionGate'));
    expect(router, contains('aiCostGate.assertRouteBudget'));
    expect(router, contains('routeClass === \'audio\''));
    expect(gate, contains('AI_COST_BUDGET_EXCEEDED'));
    expect(gate, contains('AI_COST_SINGLE_FLIGHT_RUNNING'));
    expect(gate, contains('AI_COST_CIRCUIT_OPEN'));
    expect(t02, contains('costGate.run'));
    expect(t02, contains('fullJitter: true'));
    expect(
      mandatoryTest,
      contains('AI cost protection mandatory law tests passed'),
    );
    expect(manifest, contains('"id": "anti-loop-protection"'));
    expect(
      manifest,
      contains(
        '/root/SIM-SCROL/lib/sim/lesson/dopamine_ready_window_engine.dart',
      ),
    );
    expect(serverTest, contains('AUDIO_ALREADY_RUNNING'));
  });
}
