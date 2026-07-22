import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String readRequired(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Missing required file: $path');
  return file.readAsStringSync();
}

void expectContains(String content, String needle, String label) {
  expect(content, contains(needle), reason: '$label must contain $needle');
}

void main() {
  test('manifest protege os guardas reais do app', () {
    final manifest = jsonDecode(
      readRequired('/root/sim-work/sim-api/docs/guardas-antigasto.manifest.json'),
    ) as Map<String, dynamic>;
    expect(manifest['protectedGroup'], 'guardas-antigasto');
    expect(manifest['requiresExplicitAuthorization'], isTrue);
    final appGuards = manifest['appGuards'] as List<dynamic>;
    expect(appGuards.map((guard) => guard['id']), containsAll([
      'APP-WINDOW-001',
      'APP-WORKER-001',
      'APP-IDEMPOTENCY-001',
      'APP-RETRY-001',
      'APP-CACHE-001',
      'APP-READINESS-001',
      'APP-SYNC-001',
      'APP-SYNC-002',
    ]));

    for (final rawGuard in appGuards) {
      final guard = rawGuard as Map<String, dynamic>;
      final repo = (guard['repo'] as String?) ?? Directory.current.path;
      final file = '$repo/${guard['file']}';
      final content = readRequired(file);
      for (final needle in guard['mustContain'] as List<dynamic>) {
        expectContains(content, needle as String, guard['id'] as String);
      }
    }
  });

  test('janela de 15, worker, idempotencia, Retry-After, cache e fila continuam protegidos', () {
    final dopamine = readRequired('lib/sim/lesson/dopamine_ready_window_engine.dart');
    expectContains(dopamine, 'const int offlineWarmCacheSize = 15', 'DopamineReadyWindowEngine');
    expectContains(dopamine, 'const int localLessonTraySize = offlineWarmCacheSize', 'DopamineReadyWindowEngine');
    expectContains(dopamine, 'class DopamineReadyWindowEngine', 'DopamineReadyWindowEngine');

    final worker = readRequired('lib/sim/lesson/ready_window_worker.dart');
    expectContains(worker, 'class ReadyWindowWorker', 'ReadyWindowWorker');
    expectContains(worker, 'error.retryAfter', 'ReadyWindowWorker');
    expectContains(worker, 'readyWindowWorkerMaxAttempts', 'ReadyWindowWorker');

    final t02Client = readRequired('lib/sim/external_ai/sim_server_ai_clients.dart');
    expectContains(t02Client, '_t02IdempotencyKey', 'SimServerT02Client');
    expectContains(t02Client, "'idempotencyKey': idempotencyKey", 'SimServerT02Client');

    final aiConfig = readRequired('lib/sim/external_ai/sim_ai_server_config.dart');
    expectContains(aiConfig, 'Duration? _retryAfter', 'SimAiServerConfig');
    expectContains(aiConfig, "headers['Retry-After']", 'SimAiServerConfig');
    expectContains(aiConfig, 'retry_after', 'SimAiServerConfig');

    final cache = readRequired('lib/sim/lesson/lesson_material_cache.dart');
    expectContains(cache, 'class LessonMaterialCache', 'LessonMaterialCache');
    expectContains(cache, 'putForParams', 'LessonMaterialCache');
    expectContains(cache, 'peek', 'LessonMaterialCache');

    final readiness = readRequired('lib/sim/lesson/lesson_readiness_resolver.dart');
    expectContains(readiness, 'class LessonReadinessResolver', 'LessonReadinessResolver');
    expectContains(readiness, 'peekCachedLesson', 'LessonReadinessResolver');

    final queue = readRequired('lib/sim/cloud/cloud_queue.dart');
    expectContains(queue, 'class CloudQueue', 'CloudQueue');
    expectContains(queue, 'abstract interface class DurableCloudQueueStorage', 'CloudQueue');
    expectContains(queue, '_flushingIds', 'CloudQueue');

    final driftQueue = readRequired('lib/sim/cloud/drift_cloud_queue_storage.dart');
    expectContains(driftQueue, 'class DriftCloudQueueStorage', 'DriftCloudQueueStorage');
    expectContains(driftQueue, 'StudentStateDriftDatabase', 'DriftCloudQueueStorage');
    expectContains(driftQueue, 'transaction', 'DriftCloudQueueStorage');
    expectContains(driftQueue, '_migrateLegacy', 'DriftCloudQueueStorage');
  });

  test('sentinela nao autoriza tocar prompt, adendo ou N3', () {
    final manifest = readRequired(
      '/root/sim-work/sim-api/docs/guardas-antigasto.manifest.json',
    );
    expectContains(manifest, 'touch_prompts_adendos_n3', 'manifest forbidden list');
    expectContains(manifest, '/root/SIM-SCROL/lib/sim/media/visual_router_n3.dart', 'manifest protected surfaces');
    expect(manifest, isNot(contains('rewrite_prompt')));
  });
}
