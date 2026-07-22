import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../billing/account_deletion.dart';
import '../billing/credits_route_controller.dart';
import '../billing/payment_return_store.dart';
import '../billing/sim_server_billing_clients.dart';
import '../auxiliary/amparo_room_service.dart';
import '../auxiliary/aux_room_t02_caller.dart';
import '../auxiliary/aux_rooms_controller.dart';
import '../auxiliary/recovery_room_service.dart';
import '../auxiliary/review_room_service.dart';
import '../auxiliary/student_aux_room_service.dart';
import '../classroom/lesson_answer_progress_controller.dart';
import '../classroom/lesson_hydration_engine.dart';
import '../classroom/lesson_material_controller.dart';
import '../classroom/lesson_position_engine.dart';
import '../classroom/lesson_runtime_engine.dart';
import '../classroom/lesson_session_engine.dart';
import '../cloud/cloud_queue.dart';
import '../cloud/lesson_cloud_bootstrap.dart';
import '../cloud/lesson_curriculum_sync_engine.dart';
import '../cloud/student_learning_sync.dart';
import '../config/sim_api_routes.dart';
import '../experience/student_experience_engine.dart';
import '../experience/student_experience_placement_adapter.dart';
import '../experience/start_first_lesson_use_case.dart';
import '../experience/student_experience_t00_adapter.dart';
import '../experience/student_experience_t02_adapter.dart';
import '../experience/warmup_bridge_service.dart';
import '../lesson/dopamine_ready_window_engine.dart';
import '../lesson/lesson_event_bus.dart';
import '../lesson/lesson_material_cache.dart';
import '../lesson/lesson_orchestrator.dart';
import '../lesson/ready_window_worker.dart';
import '../lesson/student_lesson_material_service.dart';
import '../media/audio_core.dart';
import '../media/audio_preference.dart';
import '../media/lesson_audio_controller.dart';
import '../media/lesson_visual_pipeline.dart';
import '../media/student_lesson_media_service.dart';
import '../placement/placement_route_controller.dart';
import '../placement/placement_store.dart';
import '../placement/placement_t02_caller.dart';
import '../placement/student_placement_service.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import '../state/student_state_store.dart';
import '../state/student_state_store_adapter.dart';
import '../external_ai/sim_ai_server_config.dart';
import '../external_ai/sim_server_ai_clients.dart';
import '../media/platform_audio_adapter.dart';

enum SimOrganismRouteGuard {
  open,
  needsAuth,
  needsLanguage,
  needsObjective,
  serverOnly,
  unknown,
}

class SimRouteDecision {
  const SimRouteDecision({
    required this.requested,
    required this.destination,
    required this.guard,
  });

  final String requested;
  final String destination;
  final SimOrganismRouteGuard guard;

  bool get allowed =>
      requested == destination && guard == SimOrganismRouteGuard.open;
}

class SimOrganismRouter {
  const SimOrganismRouter();

  static const _screenRoutes = {
    '/',
    '/login',
    '/cyber/idioma',
    '/cyber/objeto',
    '/cyber/curriculo',
    '/cyber/placement',
    '/cyber/warmup',
    '/cyber/amparo',
    '/cyber/aula',
    '/creditos',
    '/checkout/return',
    '/pai',
    '/privacidade',
    '/termos',
    '/conta/deletar',
  };

  static const _serverRoutes = {
    SimApiRoutes.t00Bootstrap,
    SimApiRoutes.t02CompleteLesson,
    SimApiRoutes.generateLessonAudio,
  };

  SimRouteDecision resolve({
    required String path,
    required bool authed,
    required bool hasLanguage,
    required bool hasObjective,
  }) {
    if (_serverRoutes.contains(path)) {
      return SimRouteDecision(
        requested: path,
        destination: '/',
        guard: SimOrganismRouteGuard.serverOnly,
      );
    }
    if (!_screenRoutes.contains(path) && !path.startsWith('https://')) {
      return SimRouteDecision(
        requested: path,
        destination: '/',
        guard: SimOrganismRouteGuard.unknown,
      );
    }
    if (path.startsWith('https://')) {
      return SimRouteDecision(
        requested: path,
        destination: path,
        guard: SimOrganismRouteGuard.open,
      );
    }
    if (_requiresAuth(path) && !authed) {
      return SimRouteDecision(
        requested: path,
        destination: '/login',
        guard: SimOrganismRouteGuard.needsAuth,
      );
    }
    if (_requiresLanguage(path) && !hasLanguage) {
      return SimRouteDecision(
        requested: path,
        destination: '/cyber/idioma',
        guard: SimOrganismRouteGuard.needsLanguage,
      );
    }
    if (_requiresObjective(path) && !hasObjective) {
      return SimRouteDecision(
        requested: path,
        destination: '/cyber/objeto',
        guard: SimOrganismRouteGuard.needsObjective,
      );
    }
    return SimRouteDecision(
      requested: path,
      destination: path,
      guard: SimOrganismRouteGuard.open,
    );
  }

  bool _requiresAuth(String path) => const {
    '/cyber/idioma',
    '/cyber/objeto',
    '/cyber/curriculo',
    '/cyber/placement',
    '/cyber/warmup',
    '/cyber/amparo',
    '/cyber/aula',
    '/creditos',
    '/checkout/return',
    '/pai',
    '/conta/deletar',
  }.contains(path);

  bool _requiresLanguage(String path) => const {
    '/cyber/objeto',
    '/cyber/curriculo',
    '/cyber/placement',
    '/cyber/warmup',
    '/cyber/amparo',
    '/cyber/aula',
  }.contains(path);

  bool _requiresObjective(String path) => const {
    '/cyber/curriculo',
    '/cyber/placement',
    '/cyber/warmup',
    '/cyber/aula',
  }.contains(path);
}

class SimOrganismHealthReport {
  const SimOrganismHealthReport({
    required this.healthyOrgans,
    required this.serverOnlyOrgans,
    required this.unresolvedDoors,
    required this.promptsStayOnServer,
    required this.secretsStayOnServer,
    required this.hasCompleteSchoolMap,
  });

  final List<String> healthyOrgans;
  final List<String> serverOnlyOrgans;
  final List<String> unresolvedDoors;
  final bool promptsStayOnServer;
  final bool secretsStayOnServer;
  final bool hasCompleteSchoolMap;

  bool get alive =>
      healthyOrgans.isNotEmpty &&
      unresolvedDoors.isEmpty &&
      promptsStayOnServer &&
      secretsStayOnServer &&
      hasCompleteSchoolMap;
}

SimOrganismHealthReport buildSimOrganismHealthReport() =>
    const SimOrganismHealthReport(
      healthyOrgans: [
        'portal',
        'login',
        'objetivo',
        'aula',
        'midia',
        'sync',
        'billing',
      ],
      serverOnlyOrgans: [
        SimApiRoutes.t00Bootstrap,
        SimApiRoutes.t02CompleteLesson,
        SimApiRoutes.generateLessonAudio,
      ],
      unresolvedDoors: [],
      promptsStayOnServer: true,
      secretsStayOnServer: true,
      hasCompleteSchoolMap: true,
    );

class SimOrganism {
  SimOrganism._({
    required this.lessonLocalId,
    required this.stateService,
    required this.router,
    required this.health,
    required this.cache,
    required this.eventBus,
    required this.lessonOrchestrator,
    required this.readyWindowEngine,
    required this.readyWindowWorker,
    required this.materialService,
    required this.warmupBridgeService,
    required this.experienceEngine,
    required this.placementService,
    required this.placementController,
    required this.lessonRuntimeEngine,
    required this.cloudQueue,
    required this.sync,
    required this.cloudBootstrap,
    required this.curriculumSync,
    required this.audioPreference,
    required this.audioCore,
    required this.mediaService,
    required this.lessonAudioController,
    required this.creditsController,
    required this.accountDeletionController,
    required this.auxRoomsController,
  });

  final String lessonLocalId;
  final StudentLearningStateService stateService;
  final SimOrganismRouter router;
  final SimOrganismHealthReport health;
  final LessonMaterialCache cache;
  final LessonEventBus eventBus;
  final LessonOrchestrator lessonOrchestrator;
  final DopamineReadyWindowEngine readyWindowEngine;
  final ReadyWindowWorker readyWindowWorker;
  final StudentLessonMaterialService materialService;
  final WarmupBridgeService warmupBridgeService;
  final StudentExperienceEngine experienceEngine;
  final StudentPlacementService placementService;
  final PlacementRouteController placementController;
  final LessonRuntimeEngine lessonRuntimeEngine;
  final CloudQueue cloudQueue;
  final StudentLearningSync sync;
  final LessonCloudBootstrap cloudBootstrap;
  final LessonCurriculumSyncEngine curriculumSync;
  final AudioPreference audioPreference;
  final AudioCore audioCore;
  final StudentLessonMediaService mediaService;
  final LessonAudioController lessonAudioController;
  final CreditsRouteController creditsController;
  final AccountDeletionController accountDeletionController;
  final AuxRoomsController auxRoomsController;

  StudentLearningState get activeState {
    return stateService.ensure(lessonLocalId: lessonLocalId);
  }

  static SimOrganism production({
    required String lessonLocalId,
    required SimAiServerConfig aiConfig,
    required SharedPreferences prefs,
    StudentStateStore? canonicalStore,
    AudioPlaybackAdapter? playback,
    required CloudQueue remoteVaultQueue,
    bool autoStartReadyWindowWorker = true,
  }) {
    if (canonicalStore == null) {
      throw const StudentStateStorageException(
        'CANONICAL_STUDENT_STATE_STORE_REQUIRED',
      );
    }
    final activeStore = canonicalStore;
    final stateAdapter = StudentStateStoreAdapter(activeStore);
    final StudentLearningStateService stateService = stateAdapter;
    stateService.ensure(lessonLocalId: lessonLocalId);

    final t00Client = SimServerT00Client(config: aiConfig);
    final t02Client = SimServerT02Client(config: aiConfig);
    final warmupBridgeService = WarmupBridgeService(t02Client: t02Client);
    final cache = LessonMaterialCache();
    unawaited(cache.hydrate());
    final eventBus = LessonEventBus();
    final orchestrator = LessonOrchestrator(
      t02Client: t02Client,
      cache: cache,
      bus: eventBus,
      visualPipeline: S12VisualPipeline(
        n3Client: VisualRouterN3Client(config: aiConfig),
      ),
    );
    final readyWindowEngine = DopamineReadyWindowEngine(
      service: stateService,
      orchestrator: orchestrator,
    );
    final audioPreference = AudioPreference(
      storage: SharedPrefsAudioPreferenceStorage(prefs),
    );
    final audioCore = AudioCore(
      preference: audioPreference,
      playback: playback ?? PlatformAudioAdapter(),
      generatedAudioClient: SimServerGeneratedAudioClient(config: aiConfig),
      stableLangProvider: () =>
          stateService.read(lessonLocalId)?.profile.stableLang ?? '',
    );
    final mediaService = StudentLessonMediaService(
      audioCore: audioCore,
      readState: (id) => stateService.ensure(lessonLocalId: id),
      writeState: stateService.write,
    );
    orchestrator.setAudioTextPreparer((params, lesson) {
      mediaService.prepareLessonAudioText(
        LessonMediaPosition(
          lessonLocalId: params.lessonLocalId,
          itemMarker: params.marker,
          layer: params.layer,
        ),
        [
          lesson.conteudo.explanation,
          lesson.conteudo.question,
          lesson.conteudo.options[AnswerLetter.A],
          lesson.conteudo.options[AnswerLetter.B],
          lesson.conteudo.options[AnswerLetter.C],
        ],
        params.effectiveLocaleContract,
      );
    });
    final materialService = StudentLessonMaterialService(
      stateService: stateService,
      orchestrator: orchestrator,
      readyWindowEngine: readyWindowEngine,
      mediaService: mediaService,
    );
    final readyWindowWorker = ReadyWindowWorker(
      service: stateService,
      processor: readyWindowEngine.runDopamineReadyWindowFromStudentState,
    );

    final t00Adapter = StudentExperienceT00Adapter(
      service: stateService,
      client: t00Client,
      onCurriculumExpanded: materialService.prepareReadyWindowInBackground,
    );
    final startFirstLesson = StartFirstLessonUseCase(service: stateService);
    final t02Adapter = StudentExperienceT02Adapter(
      service: stateService,
      materialService: materialService,
      startFirstLesson: startFirstLesson,
    );
    final placementService = StudentPlacementService(
      stateService: stateService,
      lessonLocalId: lessonLocalId,
    );
    final placementStore = PlacementStore(placementService);
    const placementEnabled = true;
    final placementController = PlacementRouteController(
      lessonLocalId: lessonLocalId,
      stateService: stateService,
      store: placementStore,
      t02Caller: PlacementT02Caller(
        t02Client: t02Client,
        enabled: placementEnabled,
      ),
      enabled: placementEnabled,
    );
    final placementReader = _OrganismPlacementDecisionReader(
      StudentExperiencePlacementAdapter(
        service: placementService,
        enabled: placementEnabled,
      ),
    );
    final experienceEngine = StudentExperienceEngine(
      service: stateService,
      t00: t00Adapter,
      t02: t02Adapter,
      placement: placementReader,
      startFirstLesson: startFirstLesson,
    );

    final lessonMaterialController = LessonMaterialController(
      stateService: stateService,
      materialService: materialService,
    );
    final auxRoomService = StudentAuxRoomService(
      readState: (id) => stateService.ensure(lessonLocalId: id),
      writeState: stateService.write,
      t02Caller: AuxRoomT02Caller(client: t02Client),
    );
    final auxRoomsController = AuxRoomsController(
      reviewRoomService: ReviewRoomService(auxRoomService),
      recoveryRoomService: RecoveryRoomService(auxRoomService),
      amparoRoomService: AmparoRoomService(auxRoomService),
    );
    final lessonRuntimeEngine = LessonRuntimeEngine(
      stateService: stateService,
      sessionEngine: LessonSessionEngine(service: stateService),
      hydrationEngine: LessonHydrationEngine(materialService: materialService),
      positionEngine: LessonPositionEngine(),
      materialController: lessonMaterialController,
      answerController: LessonAnswerProgressController(
        stateService: stateService,
        materialService: materialService,
        materialController: lessonMaterialController,
        store: activeStore,
        audioCore: audioCore,
      ),
    );

    final cloudQueue = remoteVaultQueue;
    stateAdapter.onWrite = (id) =>
        cloudQueue.enqueueStudentStateSync(lessonLocalId: id);
    if (autoStartReadyWindowWorker) {
      readyWindowWorker.startReadyWindowWorker(
        activeLessonLocalId: lessonLocalId,
      );
    }
    final sync = StudentLearningSync(cloudQueue);
    final cloudBootstrap = LessonCloudBootstrap(sync: sync);
    final curriculumSync = LessonCurriculumSyncEngine(
      stateService: stateService,
    );
    final lessonAudioController = LessonAudioController(
      lessonLocalId: lessonLocalId,
      mediaService: mediaService,
      preference: audioPreference,
    );
    final returnStore = PaymentReturnStore(
      storage: SharedPrefsPaymentReturnStorage(prefs),
    );
    final creditsController = CreditsRouteController(
      creditsFunctions: SimServerCreditsClient(config: aiConfig),
      paymentsFunctions: SimServerPaymentsClient(config: aiConfig),
      returnStore: returnStore,
    );
    final accountDeletionController = AccountDeletionController(
      gateway: SimServerAccountDeletionGateway(config: aiConfig),
    );

    return SimOrganism._(
      lessonLocalId: lessonLocalId,
      stateService: stateService,
      router: const SimOrganismRouter(),
      health: buildSimOrganismHealthReport(),
      cache: cache,
      eventBus: eventBus,
      lessonOrchestrator: orchestrator,
      readyWindowEngine: readyWindowEngine,
      readyWindowWorker: readyWindowWorker,
      materialService: materialService,
      warmupBridgeService: warmupBridgeService,
      experienceEngine: experienceEngine,
      placementService: placementService,
      placementController: placementController,
      lessonRuntimeEngine: lessonRuntimeEngine,
      cloudQueue: cloudQueue,
      sync: sync,
      cloudBootstrap: cloudBootstrap,
      curriculumSync: curriculumSync,
      audioPreference: audioPreference,
      audioCore: audioCore,
      mediaService: mediaService,
      lessonAudioController: lessonAudioController,
      creditsController: creditsController,
      accountDeletionController: accountDeletionController,
      auxRoomsController: auxRoomsController,
    );
  }
}

class _OrganismPlacementDecisionReader implements PlacementDecisionReader {
  const _OrganismPlacementDecisionReader(this.adapter);

  final StudentExperiencePlacementAdapter adapter;

  @override
  bool get settled => adapter.readPlacementDecision().settled;

  @override
  PlacementDecision readPlacementDecision() => adapter.readPlacementDecision();

  @override
  StartPosition resolveStartPosition(
    StudentCurriculum curriculum,
    PlacementDecision decision,
  ) {
    return adapter.resolveStartPosition(curriculum, decision.placement);
  }
}
