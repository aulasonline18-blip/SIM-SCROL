import 'package:flutter_test/flutter_test.dart';
import 'support/memory_test_stores.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/sim/classroom/lesson_answer_progress_controller.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/organism/sim_organism.dart';
import 'package:sim_mobile/sim/organism/sim_organism_provider.dart';
import 'package:sim_mobile/sim/organism/sim_organism_router.dart';
import 'package:sim_mobile/sim/school/sim_school_routes.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

SimAiServerConfig _testConfig() => const SimAiServerConfig(
  baseUrl: 'http://localhost',
  t00Path: '/api/bootstrap-t00',
  t02Path: '/api/complete-lesson',
);

Future<SimOrganism> _makeOrganism({
  String id = 'test',
  StudentStateStore? store,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final provider = SimOrganismProvider(
    canonicalStore:
        store ?? StudentStateStore(local: MemoryStudentStateLocalStorage()),
    aiConfig: _testConfig(),
    prefs: prefs,
  );
  return provider.forLesson(id);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  test('organismo usa o canonicalStore externo quando fornecido', () async {
    final canonicalStore = StudentStateStore(
      local: MemoryStudentStateLocalStorage(),
    );
    final organism = await _makeOrganism(
      id: 'canonical-organism',
      store: canonicalStore,
    );

    organism.stateService.mutate(
      organism.lessonLocalId,
      (state) => state.copyWith(extra: const {'proof': 'canonical'}),
    );

    final stored = canonicalStore.readState('canonical-organism');
    expect(stored.extra['proof'], 'canonical');
  });

  test('provider entrega uma unica fila oficial de cofre remoto', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final canonicalStore = StudentStateStore(
      local: MemoryStudentStateLocalStorage(),
    );
    final provider = SimOrganismProvider(
      canonicalStore: canonicalStore,
      aiConfig: _testConfig(),
      prefs: prefs,
    );

    final aulaA = provider.forLesson('lesson-a');
    final aulaB = provider.forLesson('lesson-b');

    expect(identical(aulaA.cloudQueue, provider.remoteVaultQueue), isTrue);
    expect(identical(aulaB.cloudQueue, provider.remoteVaultQueue), isTrue);
    expect(identical(aulaA.cloudQueue, aulaB.cloudQueue), isTrue);

    provider.remoteVaultSyncEngine.enqueueState(
      lessonLocalId: 'lesson-a',
      reason: 'test_shared_remote_vault',
    );

    expect(provider.remoteVaultQueue.getQueueSnapshot(), contains('lesson-a'));
    expect(aulaA.cloudQueue.getQueueSnapshot(), contains('lesson-a'));
  });

  test('organismo ideal nasce com todos os orgaos vivos conectados', () async {
    final organism = await _makeOrganism();

    expect(organism.health.alive, isTrue);
    expect(organism.health.healthyOrgans, contains('sala_de_aula'));
    expect(organism.health.healthyOrgans, contains('nuvem_sync'));
    expect(organism.health.healthyOrgans, contains('creditos_pagamento'));
    expect(organism.health.serverOnlyOrgans, contains('/api/bootstrap-t00'));
    expect(
      organism.health.serverOnlyOrgans,
      contains('/api/generate-lesson-audio'),
    );
    expect(
      organism.health.serverOnlyOrgans,
      contains('/api/public/payments/webhook'),
    );
  });

  test(
    'organismo de producao nao injeta advance gate remoto na aula',
    () async {
      final organism = await _makeOrganism(id: 'remote-advance-organism');

      expect(
        organism.lessonRuntimeEngine.answerController,
        isA<LessonAnswerProgressController>(),
      );
    },
  );

  test(
    'roteador protege ambientes que precisam de identificacao, idioma e objetivo',
    () {
      const router = SimOrganismRouter();

      expect(
        router
            .resolve(
              path: '/cyber/aula',
              authed: false,
              hasLanguage: false,
              hasObjective: false,
            )
            .destination,
        '/login',
      );
      expect(
        router
            .resolve(
              path: '/cyber/aula',
              authed: true,
              hasLanguage: false,
              hasObjective: false,
            )
            .destination,
        '/cyber/idioma',
      );
      expect(
        router
            .resolve(
              path: '/cyber/aula',
              authed: true,
              hasLanguage: true,
              hasObjective: false,
            )
            .destination,
        '/cyber/objeto',
      );
      expect(
        router
            .resolve(
              path: '/api/bootstrap-t00',
              authed: true,
              hasLanguage: true,
              hasObjective: true,
            )
            .guard,
        SimOrganismRouteGuard.serverOnly,
      );
    },
  );

  test(
    'sync, creditos e portas externas permanecem disponiveis sem segredo no app',
    () async {
      final organism = await _makeOrganism();

      organism.sync.enqueuePatch(organism.lessonLocalId);
      expect(
        organism.sync.getQueueSnapshot(),
        contains(organism.lessonLocalId),
      );

      final whatsapp = findSimRoute('https://wa.me/message/RLCYEXAYFUIIA1');
      expect(whatsapp?.kind, SimRouteKind.external);
      expect(organism.health.promptsStayOnServer, isTrue);
      expect(organism.health.secretsStayOnServer, isTrue);
    },
  );

  // Teste de jornada viva omitido: requer T00/T02 via rede real
  // (servidor real) — não roda em CI sem servidor.
}
