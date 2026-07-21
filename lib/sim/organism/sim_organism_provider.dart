import 'package:shared_preferences/shared_preferences.dart';

import '../cloud/cloud_queue.dart';
import '../cloud/cloud_functions.dart';
import '../cloud/shared_prefs_cloud_queue_storage.dart';
import '../cloud/sim_server_cloud_functions.dart';
import '../cloud/student_learning_sync.dart';
import '../cloud/student_remote_vault_sync_engine.dart';
import '../cloud/supabase_client_contract.dart';
import '../cloud/supabase_flutter_session_provider.dart';
import '../external_ai/sim_ai_server_config.dart';
import '../state/student_state_store.dart';
import '../state/student_state_store_adapter.dart';
import 'sim_organism.dart';

class SimOrganismProvider {
  SimOrganismProvider({
    required this.canonicalStore,
    required this.aiConfig,
    required this.prefs,
    this.cloudFunctions,
    this.sessionProvider,
  }) {
    remoteVaultQueue.wireCloudQueueLifecycle();
  }

  final StudentStateStore canonicalStore;
  final SimAiServerConfig aiConfig;
  final SharedPreferences prefs;
  final StudentStateCloudFunctions? cloudFunctions;
  final SupabaseSessionProvider? sessionProvider;
  final Map<String, SimOrganism> _organisms = {};
  String? _activeLessonLocalId;
  SupabaseSessionProvider get _resolvedSessionProvider =>
      sessionProvider ?? const SupabaseFlutterSessionProvider();
  late final StudentStateStoreAdapter _remoteVaultStateService =
      StudentStateStoreAdapter(canonicalStore);
  late final CloudQueue remoteVaultQueue = CloudQueue(
    storage: SharedPrefsCloudQueueStorage(prefs),
    stateService: _remoteVaultStateService,
    sessionProvider: _resolvedSessionProvider,
    cloudFunctions: cloudFunctions ?? SimServerCloudFunctions(config: aiConfig),
  );
  late final StudentLearningSync remoteVaultSync = StudentLearningSync(
    remoteVaultQueue,
  );
  late final StudentRemoteVaultSyncEngine remoteVaultSyncEngine =
      StudentRemoteVaultSyncEngine(
        store: canonicalStore,
        sync: remoteVaultSync,
      );

  SimOrganism forLesson(String lessonLocalId) {
    final previousId = _activeLessonLocalId;
    if (previousId != null && previousId != lessonLocalId) {
      _organisms[previousId]?.readyWindowWorker.stopReadyWindowWorker();
    }
    final existed = _organisms.containsKey(lessonLocalId);
    final organism = _organisms.putIfAbsent(
      lessonLocalId,
      () => SimOrganism.production(
        lessonLocalId: lessonLocalId,
        aiConfig: aiConfig,
        prefs: prefs,
        canonicalStore: canonicalStore,
        remoteVaultQueue: remoteVaultQueue,
      ),
    );
    if (existed && previousId != lessonLocalId) {
      organism.readyWindowWorker.startReadyWindowWorker(
        activeLessonLocalId: lessonLocalId,
      );
    }
    _activeLessonLocalId = lessonLocalId;
    return organism;
  }
}
