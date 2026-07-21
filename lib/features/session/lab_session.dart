import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../sim/billing/sim_server_billing_clients.dart';
import '../../sim/billing/checkout_return_controller.dart';
import '../../sim/billing/account_deletion.dart';
import '../../sim/billing/credits_functions.dart';
import '../../sim/billing/payment_return_store.dart';
import '../../sim/billing/payments_functions.dart';
import '../../sim/billing/play_billing_functions.dart';
import '../../sim/billing/sim_pricing.dart';
import '../../sim/cloud/cloud_functions.dart';
import '../../sim/cloud/sim_server_cloud_functions.dart';
import '../../sim/cloud/student_remote_vault_sync_engine.dart';
import '../../sim/cloud/supabase_client_contract.dart';
import '../../sim/cloud/supabase_flutter_session_provider.dart';
import '../../sim/config/sim_environment.dart';
import '../../sim/external_ai/sim_ai_server_config.dart';
import '../../sim/external_ai/sim_server_ai_clients.dart';
import '../../sim/external_ai/sim_server_attachment_client.dart';
import '../../sim/classroom/classroom_models.dart';
import '../../sim/classroom/lesson_runtime_engine.dart';
import '../../sim/classroom/lesson_main_view_model.dart';
import '../../sim/classroom/pedagogical_slot_visibility.dart';
import '../../sim/experience/student_experience_types.dart';
import '../../sim/experience/curriculum_utils.dart';
import '../../sim/experience/warmup_bridge_coordinator.dart';
import '../../sim/experience/warmup_bridge_service.dart';
import '../../sim/organism/sim_organism.dart';
import '../../sim/organism/sim_organism_provider.dart';
import '../../sim/placement/placement_route_controller.dart';
import '../../sim/reception/pedagogical_reception_builder.dart';
import '../../session/auth_session.dart';
import '../../session/entry_form_state.dart';
import '../../session/lesson_ui_state.dart';
import '../../session/navigation_state.dart';
import '../../sim/lesson/lesson_models.dart';
import '../../sim/localization/sim_locale_contract.dart';
import '../../sim/media/audio_core.dart';
import '../../sim/media/audio_preference.dart';
import '../../sim/media/doubt_audio.dart';
import '../../sim/media/lesson_audio_controller.dart';
import '../../sim/media/platform_audio_adapter.dart';
import '../../sim/media/student_lesson_media_service.dart';
import '../../sim/state/shared_prefs_state_storage.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/state/student_state_store.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/auxiliary/aux_room_models.dart';
import '../../sim/auxiliary/doubt_input_sheet.dart';
import '../../sim/auxiliary/doubt_t02_caller.dart';
import '../../sim/auxiliary/lesson_doubt_controller.dart';
import '../../sim/auxiliary/student_aux_rooms.dart' as aux_rooms;

import '../../core/utils/sim_constants.dart';

part 'lab_session_flows.dart';
part 'lab_session_backup_flows.dart';
part 'lab_session_entry_flows.dart';
part 'lab_session_warmup_flows.dart';
part 'lab_session_amparo_flows.dart';
part 'lab_session_aux_flows.dart';

class LabSession extends ChangeNotifier {
  LabSession({
    StudentStateStore? canonicalStore,
    this._attachmentClient,
    AccountDeletionGateway? accountDeletionGateway,
    Future<SimAttachmentFile?> Function(String source)? attachmentFilePicker,
    StudentStateCloudFunctions? drawerCloudFunctions,
    SupabaseSessionProvider? drawerSessionProvider,
    Future<String?> Function()? drawerBackupFileTextPicker,
    Future<String?> Function(String fileName, String text)?
    drawerBackupFileSaver,
    PlayBillingFunctions? playBillingFunctions,
    CreditsFunctions? creditsFunctions,
    this.warmupBridgeService,
    this.experiencePreparerOverride,
    this.prefs,
  }) : canonicalStore =
           canonicalStore ??
           StudentStateStore(local: _studentStateStorageForSession(prefs)) {
    _drawerCloudFunctions = drawerCloudFunctions;
    _drawerSessionProvider = drawerSessionProvider;
    _drawerBackupFileTextPicker = drawerBackupFileTextPicker;
    _drawerBackupFileSaver = drawerBackupFileSaver;
    _attachmentFilePicker = attachmentFilePicker;
    _accountDeletionGateway = accountDeletionGateway;
    _playBillingFunctions = playBillingFunctions;
    _creditsFunctions = creditsFunctions;
    entryForm.addListener(_notifyFromChild);
    authSession.addListener(_notifyFromChild);
    navigationState.addListener(_notifyFromChild);
    lessonUiState.addListener(_notifyFromChild);
  }

  final SharedPreferences? prefs;
  final Future<StudentExperienceResult> Function(StudentExperienceArgs args)?
  experiencePreparerOverride;
  final StudentStateStore? canonicalStore;
  final SimServerAttachmentClient? _attachmentClient;
  final WarmupBridgeService? warmupBridgeService;
  AccountDeletionGateway? _accountDeletionGateway;
  StudentStateCloudFunctions? _drawerCloudFunctions;
  SupabaseSessionProvider? _drawerSessionProvider;
  Future<String?> Function()? _drawerBackupFileTextPicker;
  Future<String?> Function(String fileName, String text)?
  _drawerBackupFileSaver;
  Future<SimAttachmentFile?> Function(String source)? _attachmentFilePicker;
  PlayBillingFunctions? _playBillingFunctions;
  CreditsFunctions? _creditsFunctions;

  bool get _runningUnderFlutterTest {
    return Platform.environment['FLUTTER_TEST'] == 'true' ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
  }

  late final EntryFormState entryForm = EntryFormState(
    attachmentClient: _attachmentClient,
    serverConfig: _serverConfig,
  );
  late final NavigationState navigationState = NavigationState();
  late final LessonUiState lessonUiState = LessonUiState();
  late final AuthSession authSession = AuthSession(
    navigation: navigationState,
    onAuthenticated: _onAuthenticated,
  );

  late final SimOrganismProvider simOrganismProvider = SimOrganismProvider(
    canonicalStore: canonicalStore!,
    aiConfig: _serverConfig(),
    prefs: prefs!,
    cloudFunctions: _cloudFunctionsForDrawer(),
    sessionProvider: _sessionProviderForDrawer(),
  );
  late final PaymentReturnStore _paymentReturnStore = PaymentReturnStore(
    storage: _paymentReturnStorageForSession(prefs),
  );
  SimOrganism? _activeOrganism;
  LessonRuntimeSnapshot? aulaSnapshot;
  bool aulaRuntimeLoading = false;
  bool aulaMenuLessonWaiting = false;
  String? aulaRuntimeError;
  SimWarmupLesson? warmupLesson;
  bool warmupLoading = false;
  String? warmupError;
  String? warmupSelectedAnswer;
  bool warmupWaitingForOfficialLesson = false;
  final WarmupBridgeCoordinator _warmupCoordinator = WarmupBridgeCoordinator();

  VisualLearningFeedbackReport get visualLearningFeedbackReport =>
      VisualLearningFeedbackReport.fromLesson(
        history: aulaSnapshot?.history ?? const [],
        doubt: lessonUiState.doubt,
        currentImageUrl: aulaSnapshot?.imagem,
      );

  VisualOperationalReport get visualOperationalReport =>
      VisualOperationalReport(feedback: visualLearningFeedbackReport);

  bool _creditsLoaded = false;
  Future<void>? _creditsLoadInFlight;
  Future<void>? _launchExperienceInFlight;
  int _experienceGeneration = 0;
  int _aulaRuntimeGeneration = 0;
  bool _entryOfficialLessonReady = false;
  late SimLocaleSettings localeSettings = SimLocaleSettings.load(prefs);

  late final AudioPreference _audioPreference = AudioPreference(
    storage: _audioPreferenceStorageForSession(prefs),
  );
  LessonAudioController? _lessonAudioController;
  DoubtAudio? _doubtAudio;
  String? _activeLessonMediaKey;
  SimOrganism? _activeLessonMediaOrganism;
  void Function()? _lessonImageUnsubscribe;
  void Function()? _aulaStateUnsubscribe;
  String? _aulaStateSubscriptionLessonId;
  bool _advancePendingReevaluationScheduled = false;
  int _autoAdvanceAulaGeneration = 0;
  int _doubtRequestSeq = 0;
  bool _disposed = false;

  void _notifyFromChild() {
    if (_disposed) return;
    notifyListeners();
  }

  StudentLearningState? get _activeCanonicalState {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return null;
    return canonicalStore?.readState(id);
  }

  LessonLayer get currentAulaLayer {
    final state = _activeCanonicalState;
    return state?.current?.layer ?? state?.progress?.layer ?? LessonLayer.l1;
  }

  int get currentAulaItemNumber {
    final state = _activeCanonicalState;
    return (state?.current?.itemIdx ?? state?.progress?.itemIdx ?? 0) + 1;
  }

  bool get authed => authSession.authed;
  set authed(bool value) => authSession.authed = value;
  bool get authReady => authSession.authReady;
  set authReady(bool value) => authSession.authReady = value;
  int get credits => authSession.credits;
  set credits(int value) => authSession.credits = value;
  bool get isUnlimited => authSession.isUnlimited;
  String? get userId => authSession.userId;
  String? get userEmail => authSession.userEmail;
  String? get userName => authSession.userName;
  String? get authError => authSession.authError;

  String get route => navigationState.route;
  set route(String value) => navigationState.route = value;
  String get returnTo => navigationState.returnTo;
  set returnTo(String value) => navigationState.returnTo = value;
  String? get externalDoorOpened => navigationState.externalDoorOpened;

  String? get selectedLanguageCode => entryForm.selectedLanguageCode;
  set selectedLanguageCode(String? value) =>
      entryForm.selectedLanguageCode = value;
  String? get stableLang => entryForm.stableLang;
  set stableLang(String? value) => entryForm.stableLang = value;
  String get interfaceLocaleTag =>
      localeSettings.resolveInterfaceLocale(PlatformDispatcher.instance.locale);
  String get learningLocaleTag =>
      normalizeSimLocaleTag(localeSettings.learningLocale);
  String get explanationLanguage =>
      simLanguageNameForLocale(localeSettings.learningLocale);
  SimLocaleContract get localeContract =>
      localeSettings.contract(PlatformDispatcher.instance.locale);
  String get otherLanguage => entryForm.otherLanguage;
  String get freeText => entryForm.freeText;
  set freeText(String value) => entryForm.freeText = value;
  String get preferredName => entryForm.preferredName;
  set preferredName(String value) => entryForm.preferredName = value;
  List<AttachmentDraft> get attachments => entryForm.attachments;
  String get attachmentsText => entryForm.attachmentsText;
  String get studentProfileNotes => entryForm.studentProfileNotes;
  String? get attachmentError => entryForm.attachmentError;
  Map<String, String> get guidedAnswers => entryForm.guidedAnswers;
  bool get interfaceLanguageSubmitted => entryForm.interfaceLanguageSubmitted;
  bool get learningLanguageSubmitted => entryForm.learningLanguageSubmitted;
  bool get profileNameSubmitted => entryForm.profileNameSubmitted;
  bool get profileAgeSubmitted => entryForm.profileAgeSubmitted;
  bool get profileDifficultiesSubmitted =>
      entryForm.profileDifficultiesSubmitted;
  bool get profileObservationSubmitted => entryForm.profileObservationSubmitted;
  String get studentAge => entryForm.studentAge;
  bool get ageNotDeclared => entryForm.ageNotDeclared;
  List<String> get profileDifficulties => entryForm.profileDifficulties;
  String get profileObservation => entryForm.profileObservation;
  String get ageRange => entryForm.ageRange;
  String get entryPath => entryForm.entryPath;
  bool get simLearningGoalSubmitted => entryForm.simLearningGoalSubmitted;
  bool get simLearningLevelSubmitted => entryForm.simLearningLevelSubmitted;
  String get materialType => entryForm.materialType;
  String get subject => entryForm.subject;
  String get topic => entryForm.topic;
  String get academicLevel => entryForm.academicLevel;
  String get countryCurriculum => entryForm.countryCurriculum;
  String get deadline => entryForm.deadline;
  String get deadlineCustom => entryForm.deadlineCustom;
  bool get traversalGoalSubmitted => entryForm.traversalGoalSubmitted;
  bool get traversalDeadlineSubmitted => entryForm.traversalDeadlineSubmitted;
  bool get traversalExpectedResultSubmitted =>
      entryForm.traversalExpectedResultSubmitted;
  String get traversalGoal => entryForm.traversalGoal;
  String get traversalGoalCustom => entryForm.traversalGoalCustom;
  String get expectedResult => entryForm.expectedResult;
  String get difficulties => entryForm.difficulties;
  String get learningPreference => entryForm.learningPreference;
  bool get materialEntryPath => entryForm.entryPath == 'material_help';

  String? get lessonLocalId => lessonUiState.lessonLocalId;
  set lessonLocalId(String? value) => lessonUiState.lessonLocalId = value;
  String get entryStatus => lessonUiState.entryStatus;
  set entryStatus(String value) => lessonUiState.entryStatus = value;
  String? get entryError => lessonUiState.entryError;
  set entryError(String? value) => lessonUiState.entryError = value;
  bool get placementStarted => lessonUiState.placementStarted;
  bool get placementDone => lessonUiState.placementDone;
  bool get doubtOpen => lessonUiState.doubtOpen;
  bool get audioEnabled => lessonUiState.audioEnabled;
  set audioEnabled(bool value) => lessonUiState.audioEnabled = value;
  bool get audioPlaying => lessonUiState.audioPlaying;
  set audioPlaying(bool value) => lessonUiState.audioPlaying = value;
  bool get audioLoading => lessonUiState.audioLoading;
  set audioLoading(bool value) => lessonUiState.audioLoading = value;
  String? get audioError => lessonUiState.audioError;
  set audioError(String? value) => lessonUiState.audioError = value;
  String get imageStatus => lessonUiState.imageStatus;
  set imageStatus(String value) => lessonUiState.imageStatus = value;
  String? get imageError => lessonUiState.imageError;
  set imageError(String? value) => lessonUiState.imageError = value;
  String get deleteConfirmation => lessonUiState.deleteConfirmation;
  String? get accountDeletionMessage => lessonUiState.accountDeletionMessage;

  ReviewRoomView? get reviewRoom => lessonUiState.reviewRoom;
  RecoveryRoomView? get recoveryRoom => lessonUiState.recoveryRoom;
  AmparoRoomView? get amparoRoom => lessonUiState.amparoRoom;
  DoubtState get doubt => lessonUiState.doubt;

  void setDoubt(DoubtState s) => lessonUiState.setDoubt(s);
  void resetDoubt() => lessonUiState.resetDoubt();
  void openReviewRoom() {
    if (recoveryRoom != null || amparoRoom != null) return;
    lessonUiState.openReviewRoom();
  }

  void closeReviewRoom() {
    _doubtAudio?.stopDoubtAudio();
    lessonUiState.closeReviewRoom();
  }

  void setReviewRoom(ReviewRoomView v) {
    if (v.status == ReviewRoomStatus.result ||
        v.status == ReviewRoomStatus.done ||
        v.letra != null) {
      _doubtAudio?.stopDoubtAudio();
    }
    lessonUiState.setReviewRoom(v);
  }

  void openRecoveryRoom() => lessonUiState.openRecoveryRoom();
  void closeRecoveryRoom() {
    _doubtAudio?.stopDoubtAudio();
    lessonUiState.closeRecoveryRoom();
  }

  void setRecoveryRoom(RecoveryRoomView v) {
    if (v.status == RecoveryRoomStatus.result ||
        v.status == RecoveryRoomStatus.done ||
        v.letra != null) {
      _doubtAudio?.stopDoubtAudio();
    }
    lessonUiState.setRecoveryRoom(v);
  }

  void openAmparoRoom() {
    if (recoveryRoom != null) return;
    lessonUiState.openAmparoRoom();
  }

  void closeAmparoRoom() {
    _doubtAudio?.stopDoubtAudio();
    lessonUiState.closeAmparoRoom();
    if (route == '/cyber/amparo') navigationState.openRoute('/cyber/aula');
  }

  void setAmparoRoom(AmparoRoomView v) {
    if (v.status == AmparoRoomStatus.result ||
        v.status == AmparoRoomStatus.done ||
        v.letra != null) {
      _doubtAudio?.stopDoubtAudio();
    }
    lessonUiState.setAmparoRoom(v);
  }

  void goPortal() => navigationState.goPortal();

  void goLogin({String target = '/'}) =>
      navigationState.goLogin(target: target);

  void bindRealAuth() => authSession.bindRealAuth();

  SupabaseClient? _supabaseClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void applySupabaseSession(Session? session) {
    authSession.applySupabaseSession(session);
  }

  // AuthSession keeps the real Supabase OAuth contract: OAuthProvider.google with queryParams {'prompt': 'select_account'} and email signInWithPassword.
  Future<void> signInWithGoogle() => authSession.signInWithGoogle();

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return authSession.signInWithEmailPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
  }) {
    return authSession.signUpWithEmailPassword(
      email: email,
      password: password,
      name: name,
    );
  }

  Future<void> signOutReal() => authSession.signOutReal();

  Future<void> _warmUpServer() async {
    if (_runningUnderFlutterTest) return;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client
          .getUrl(Uri.parse('$simApiBaseUrl/api/health'))
          .timeout(const Duration(seconds: 8));
      final res = await req.close().timeout(const Duration(seconds: 8));
      await res.drain<void>();
      client.close();
    } catch (_) {}
  }

  void start() {
    if (!authed) {
      debugPrint('[SIM] BLOCKED reason=not_authed');
      goLogin(target: '/cyber/idioma');
      return;
    }
    if (_creditsLoaded && credits <= 0) {
      debugPrint('[SIM] BLOCKED reason=credits_zero');
      openCredits();
      return;
    }
    unawaited(_warmUpServer());
    entryForm.resetLanguage();
    navigationState.openRoute('/cyber/idioma');
  }

  void chooseLanguage(String code, String name) {
    final stableLabel = code == 'other'
        ? name.trim()
        : stableLangLabelFor(code, name);
    final localeTag = normalizeSimLocaleTag(
      code == 'other' ? stableLabel : code,
    );
    setSimActiveLanguage(simUiCodeForLocaleTag(localeTag));
    localeSettings = localeSettings.copyWith(
      followDeviceInterface: false,
      manualInterfaceLocale: localeTag,
      learningLocale: localeTag,
      targetLanguage: null,
    );
    final p = prefs;
    if (p != null) unawaited(localeSettings.save(p));
    entryForm.updateLanguage(code, stableLabel);
    final cleanName = name.trim();
    if (code != 'other' || cleanName.isNotEmpty) {
      navigationState.openRoute('/cyber/objeto');
    }
  }

  void setOtherLanguage(String value) => entryForm.setOtherLanguage(value);

  Future<void> setInterfaceLanguage({
    required bool followDevice,
    String? localeTag,
  }) async {
    localeSettings = localeSettings.copyWith(
      followDeviceInterface: followDevice,
      manualInterfaceLocale: followDevice
          ? null
          : normalizeSimLocaleTag(localeTag),
    );
    final p = prefs ?? await SharedPreferences.getInstance();
    await localeSettings.save(p);
    setSimActiveLanguage(simUiCodeForLocaleTag(resolveInterfaceLocale()));
    notifyListeners();
  }

  Future<void> setLearningLanguage({
    required String localeTag,
    String? targetLanguage,
  }) async {
    final normalized = normalizeSimLocaleTag(localeTag);
    localeSettings = localeSettings.copyWith(
      learningLocale: normalized,
      targetLanguage: targetLanguage,
    );
    final p = prefs ?? await SharedPreferences.getInstance();
    await localeSettings.save(p);
    entryForm.updateLanguage(
      simUiCodeForLocaleTag(normalized),
      simLanguageNameForLocale(normalized),
    );
    notifyListeners();
  }

  String resolveInterfaceLocale([Locale? deviceLocale]) {
    return localeSettings.resolveInterfaceLocale(deviceLocale);
  }

  void setFreeText(String value) => entryForm.updateFreeText(value);

  void setPreferredName(String value) => entryForm.updatePreferredName(value);

  void submitProfileName() => entryForm.submitProfileName();

  void setStudentAge(String value) => entryForm.updateStudentAge(value);

  void submitStudentAge({bool notDeclared = false}) =>
      entryForm.submitStudentAge(notDeclared: notDeclared);

  void toggleProfileDifficulty(String value) =>
      entryForm.toggleProfileDifficulty(value);

  void submitProfileDifficulties() => entryForm.submitProfileDifficulties();

  void setProfileObservation(String value) =>
      entryForm.updateProfileObservation(value);

  void submitProfileObservation({bool skipped = false}) =>
      entryForm.submitProfileObservation(skipped: skipped);

  void setGuidedAnswer(String key, String value) {
    entryForm.updateGuidedAnswer(key, value);
  }

  void submitInterfaceLanguage() => entryForm.submitInterfaceLanguage();

  void submitLearningLanguage() => entryForm.submitLearningLanguage();

  void setPedagogicalEntryField(String key, String value) {
    entryForm.updatePedagogicalField(key, value);
  }

  void submitSimLearningGoal() => entryForm.submitSimLearningGoal();

  void submitSimLearningLevel() => entryForm.submitSimLearningLevel();

  void submitTraversalGoal() => entryForm.submitTraversalGoal();

  void submitTraversalDeadline() => entryForm.submitTraversalDeadline();

  void submitTraversalExpectedResult({bool skipped = false}) =>
      entryForm.submitTraversalExpectedResult(skipped: skipped);

  JsonMap buildPedagogicalFicha({String? objectiveOverride}) {
    return const PedagogicalReceptionBuilder().build(
      form: entryForm,
      appLocale: interfaceLocaleTag,
      lessonLocale: learningLocaleTag,
      explanationLanguage: explanationLanguage,
      targetLanguage: localeContract.targetLanguage,
      objectiveOverride: objectiveOverride,
    );
  }

  void addLabAttachment(String source) => entryForm.addLabAttachment(source);

  Future<String?> pickLabAttachment(String source) async {
    try {
      final injected = _attachmentFilePicker;
      final file = injected == null
          ? await _pickAttachmentFile(source)
          : await injected(source);
      if (file == null) return null;
      entryForm.addLabAttachmentFile(file);
      return null;
    } catch (error) {
      entryForm.failAttachmentSelection(error);
      return _attachmentPickErrorMessage(error);
    }
  }

  void removeAttachment(int index) => entryForm.removeAttachment(index);

  void clearAttachments() => entryForm.clearAttachments();

  Future<SimAttachmentFile?> _pickAttachmentFile(String source) async {
    if (source == 'document') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'txt', 'csv'],
        withData: true,
      );
      final picked = result?.files.singleOrNull;
      if (picked == null) return null;
      final bytes = picked.bytes ?? await _readPickedPath(picked.path);
      if (bytes == null || bytes.isEmpty) return null;
      return SimAttachmentFile(
        name: picked.name,
        contentType: _mimeForAttachmentName(picked.name),
        bytes: bytes,
      );
    }

    final imageSource = source == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;
    final picked = await ImagePicker().pickImage(
      source: imageSource,
      imageQuality: 92,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return null;
    return SimAttachmentFile(
      name: picked.name,
      contentType:
          picked.mimeType ?? _mimeForAttachmentName(picked.name, image: true),
      bytes: bytes,
    );
  }

  Future<List<int>?> _readPickedPath(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    return File(path).readAsBytes();
  }

  String _mimeForAttachmentName(String name, {bool image = false}) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return image ? 'image/jpeg' : 'application/pdf';
  }

  String _attachmentPickErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('permission') || text.contains('denied')) {
      return t('attachment_permission_denied');
    }
    if (text.contains('AUDIO_NOT_SUPPORTED')) {
      return entryFormAudioNotSupportedMessage;
    }
    if (text.contains('VIDEO_NOT_SUPPORTED')) {
      return entryFormVideoNotSupportedMessage;
    }
    return t('attachment_open_failed');
  }

  Future<StudentExperienceResult> _prepareExperienceWithAuthRetry({
    required String id,
    required StudentExperienceArgs args,
    required Future<StudentExperienceResult> Function(
      StudentExperienceArgs args,
    )?
    prepareOverride,
  }) async {
    var retriedAuth = false;
    while (true) {
      try {
        return prepareOverride == null
            ? await simOrganismProvider
                  .forLesson(id)
                  .experienceEngine
                  .prepareStudentExperienceEntry(args)
            : await prepareOverride(args);
      } on StudentExperienceEngineException catch (err) {
        if (err.error.kind != StudentExperienceErrorKind.auth || retriedAuth) {
          rethrow;
        }
        retriedAuth = true;
        final refreshed = prepareOverride != null
            ? true
            : await _refreshProtectedServerSession();
        if (!refreshed) rethrow;
        entryStatus = 't00_running';
        entryError = null;
        notifyListeners();
      }
    }
  }

  bool _isCurrentExperience(String id, int generation) {
    return lessonLocalId == id && _experienceGeneration == generation;
  }

  String preparationDebugSummary() {
    final client = _supabaseClientOrNull();
    final session = client?.auth.currentSession;
    final tokenPresent = (session?.accessToken.trim().isNotEmpty ?? false);
    return [
      'route=$route',
      'returnTo=$returnTo',
      'entry=$entryStatus',
      'authReady=$authReady',
      'authed=$authed',
      'supabase=${client != null}',
      'session=${session != null}',
      'token=$tokenPresent',
      'lesson=${lessonLocalId ?? '-'}',
    ].join(' | ');
  }

  Future<bool> _ensureProtectedServerSession({
    required String returnTo,
    bool forceRefresh = false,
  }) async {
    final token = await _freshServerAccessToken(forceRefresh: forceRefresh);
    if (token == null || token.trim().isEmpty) {
      debugPrint('[SIM] PROTECTED_SESSION_FAILED');
      goLogin(target: returnTo);
      return false;
    }
    return true;
  }

  Future<bool> _refreshProtectedServerSession() async {
    final token = await _freshServerAccessToken(forceRefresh: true);
    return token != null && token.trim().isNotEmpty;
  }

  Future<String?> _freshServerAccessToken({bool forceRefresh = false}) async {
    final client = _supabaseClientOrNull();
    if (client == null) return null;
    var session = client.auth.currentSession;
    if (session == null) {
      return null;
    }
    if (forceRefresh || session.isExpired) {
      try {
        final refreshed = await client.auth.refreshSession();
        session = refreshed.session ?? client.auth.currentSession;
      } catch (_) {
        return null;
      }
    }
    final token = session?.accessToken.trim();
    return token == null || token.isEmpty ? null : token;
  }

  void _onAuthenticated() {
    _loadCreditsFromServer();
    _hydrateActiveLessonFromCloud();
    final id = lessonLocalId;
    final shouldResumePreparation =
        navigationState.returnTo == '/cyber/curriculo' &&
        id != null &&
        id.trim().isNotEmpty &&
        (entryStatus == 'pedido_recebido' || entryStatus == 'erro');
    if (shouldResumePreparation) {
      unawaited(launchExperience());
    }
  }

  void _loadCreditsFromServer({bool keepCurrent = false}) {
    if (_creditsLoadInFlight != null) return;
    if (_runningUnderFlutterTest && _creditsFunctions == null) {
      _creditsLoaded = true;
      notifyListeners();
      return;
    }
    if (!keepCurrent) {
      authSession.credits = 1;
      authSession.isUnlimited = false;
    }
    _creditsLoaded = false;
    final load =
        (_creditsFunctions ?? SimServerCreditsClient(config: _serverConfig()))
            .getMyCredits()
            .then((snapshot) {
              authSession.credits = snapshot.balance;
              authSession.isUnlimited = snapshot.testCreditMode;
              _creditsLoaded = true;
              notifyListeners();
            })
            .catchError((_) {
              _creditsLoaded = false;
              notifyListeners();
            });
    _creditsLoadInFlight = load;
    unawaited(
      load.whenComplete(() {
        if (identical(_creditsLoadInFlight, load)) {
          _creditsLoadInFlight = null;
        }
      }),
    );
  }

  void _hydrateActiveLessonFromCloud() {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return;
    unawaited(_hydrateActiveLessonFromRemoteVault(id));
  }

  Future<void> _hydrateActiveLessonFromRemoteVault(String id) async {
    final engine = _remoteVaultSync();
    if (engine == null) return;
    try {
      final hydrated = await engine.hydrate(lessonLocalId: id);
      if (lessonLocalId != hydrated.lessonLocalId) return;
      if (route == '/cyber/aula') {
        await openAulaRuntime();
      } else {
        notifyListeners();
      }
    } catch (error) {
      final store = canonicalStore;
      if (store == null) return;
      final local = store.readState(id);
      store.writeState(
        local.copyWith(
          events: [
            ...local.events,
            StudentLearningEvent(
              type: 'REMOTE_VAULT_HYDRATE_FAILED',
              ts: DateTime.now().millisecondsSinceEpoch,
              payload: {'lessonLocalId': id, 'message': error.toString()},
            ),
          ],
        ),
      );
      notifyListeners();
    }
  }

  void _enqueueActiveLessonForRemoteVaultSync({required String reason}) {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return;
    _enqueueLessonForRemoteVaultSync(id, reason: reason);
  }

  void _enqueueLessonForRemoteVaultSync(
    String lessonLocalId, {
    required String reason,
  }) {
    final engine = _remoteVaultSync();
    if (engine == null) return;
    engine.enqueueState(lessonLocalId: lessonLocalId, reason: reason);
    unawaited(engine.drain());
  }

  StudentRemoteVaultSyncEngine? _remoteVaultSync() {
    if (canonicalStore == null || prefs == null) return null;
    return simOrganismProvider.remoteVaultSyncEngine;
  }

  SimAiServerConfig _serverConfig() {
    return SimAiServerConfig(
      baseUrl: simApiBaseUrl,
      t00Path: '/api/bootstrap-t00',
      t02Path: '/api/complete-lesson',
      accessTokenProvider: _freshServerAccessToken,
    );
  }

  StudentStateCloudFunctions _cloudFunctionsForDrawer() {
    return _drawerCloudFunctions ??= SimServerCloudFunctions(
      config: _serverConfig(),
    );
  }

  SupabaseSessionProvider _sessionProviderForDrawer() {
    return _drawerSessionProvider ??= const SupabaseFlutterSessionProvider();
  }

  void stopActiveAudio({bool notify = true}) {
    _lessonAudioController?.pararAudio();
    _doubtAudio?.stopDoubtAudio();
    audioPlaying = false;
    audioLoading = false;
    if (notify) notifyListeners();
  }

  Future<void> speakAuxRoomContent(
    AuxRoomContent content, {
    required String source,
  }) async {
    final parts = [
      content.explanation,
      content.question,
      content.options[AnswerLetter.A],
      content.options[AnswerLetter.B],
      content.options[AnswerLetter.C],
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join('. ');
    if (parts.isEmpty) return;
    final id = lessonLocalId ?? 'lesson';
    try {
      await _doubtAudioFor().speakText(
        parts,
        lang: stableLang ?? selectedLanguageCode,
        lessonKey: '$id:$source',
      );
    } catch (_) {
      audioError = t('audio_prepare_failed');
      notifyListeners();
    }
  }

  Future<void> toggleAudio() async {
    if (audioLoading) return;
    audioError = null;
    final id =
        lessonLocalId ??
        _deriveLessonLocalId(
          freeText.trim().isEmpty ? 'aula-sim' : freeText,
          selectedLanguageCode ?? stableLang ?? 'pt',
        );
    if (audioPlaying) {
      _lessonAudioController?.pararAudio();
      audioPlaying = false;
      audioLoading = false;
      notifyListeners();
      return;
    }
    audioEnabled = true;
    _audioPreference.setAudioEnabled(true);
    audioLoading = true;
    notifyListeners();
    await Future<void>.delayed(Duration.zero);
    try {
      final snapshot = aulaSnapshot;
      final controller = _audioControllerFor(id);
      final started = await controller.playConteudo(
        _currentLessonContentForAudio(),
        snapshot?.itemMarker ?? 'item-1',
        currentAulaLayer,
        language: stableLang,
      );
      audioPlaying = started && controller.falando;
      if (!started) {
        audioError = t('aula_audio_unavailable');
      }
    } catch (_) {
      audioError = t('audio_prepare_failed');
      audioPlaying = false;
    } finally {
      audioLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    entryForm.removeListener(_notifyFromChild);
    authSession.removeListener(_notifyFromChild);
    navigationState.removeListener(_notifyFromChild);
    lessonUiState.removeListener(_notifyFromChild);
    _aulaStateUnsubscribe?.call();
    _lessonImageUnsubscribe?.call();
    unawaited(_playBillingFunctions?.dispose());
    authSession.dispose();
    _lessonAudioController?.pararAudio();
    _doubtAudio?.stopDoubtAudio();
    super.dispose();
  }
}

bool _isFlutterTestEnvironment() {
  return Platform.environment['FLUTTER_TEST'] == 'true' ||
      WidgetsBinding.instance.runtimeType.toString().contains('Test');
}

StudentStateLocalStorage _studentStateStorageForSession(
  SharedPreferences? prefs,
) {
  if (prefs != null) return SharedPrefsStudentStateLocalStorage(prefs);
  if (_isFlutterTestEnvironment()) {
    return _TestOnlyVolatileStudentStateStorage();
  }
  return _ExplicitStudentStateStorageRequired();
}

PaymentReturnStorage _paymentReturnStorageForSession(SharedPreferences? prefs) {
  if (prefs != null) return SharedPrefsPaymentReturnStorage(prefs);
  if (_isFlutterTestEnvironment()) {
    return _TestOnlyVolatilePaymentReturnStorage();
  }
  throw StateError('PAYMENT_RETURN_STORAGE_REQUIRED');
}

AudioPreferenceStorage _audioPreferenceStorageForSession(
  SharedPreferences? prefs,
) {
  if (prefs != null) return SharedPrefsAudioPreferenceStorage(prefs);
  if (_isFlutterTestEnvironment()) {
    return _TestOnlyVolatileAudioPreferenceStorage();
  }
  throw StateError('AUDIO_PREFERENCE_STORAGE_REQUIRED');
}

class _ExplicitStudentStateStorageRequired implements StudentStateLocalStorage {
  Never _fail() => throw const StudentStateStorageException(
    'STUDENT_STATE_STORAGE_REQUIRED',
  );

  @override
  void deleteEvents(String lessonLocalId) => _fail();

  @override
  void deleteState(String lessonLocalId) => _fail();

  @override
  List<String> listStateIds() => _fail();

  @override
  String? readEvents(String lessonLocalId) => _fail();

  @override
  String? readState(String lessonLocalId) => _fail();

  @override
  void writeEvents(String lessonLocalId, String encoded) => _fail();

  @override
  void writeState(String lessonLocalId, String encoded) => _fail();
}

class _TestOnlyVolatileStudentStateStorage implements StudentStateLocalStorage {
  final Map<String, String> _states = {};
  final Map<String, String> _events = {};

  @override
  void deleteEvents(String lessonLocalId) {
    _events.remove(lessonLocalId);
  }

  @override
  void deleteState(String lessonLocalId) {
    _states.remove(lessonLocalId);
  }

  @override
  List<String> listStateIds() => _states.keys.toList();

  @override
  String? readEvents(String lessonLocalId) => _events[lessonLocalId];

  @override
  String? readState(String lessonLocalId) => _states[lessonLocalId];

  @override
  void writeEvents(String lessonLocalId, String encoded) {
    _events[lessonLocalId] = encoded;
  }

  @override
  void writeState(String lessonLocalId, String encoded) {
    _states[lessonLocalId] = encoded;
  }
}

class _TestOnlyVolatilePaymentReturnStorage implements PaymentReturnStorage {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  void remove(String key) {
    _values.remove(key);
  }

  @override
  void write(String key, String value) {
    _values[key] = value;
  }
}

class _TestOnlyVolatileAudioPreferenceStorage
    implements AudioPreferenceStorage {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) {
    _values[key] = value;
  }
}

String safeReturnTo(String raw) {
  if (!raw.startsWith('/')) return '/';
  if (raw.startsWith('//')) return '/';
  return raw;
}

String _deriveLessonLocalId(String objetivo, String idioma) {
  final obj = objetivo.trim().toLowerCase();
  final idi = idioma.trim().toLowerCase();
  final input = idi.isEmpty ? obj : '$idi|$obj';
  var h = 5381;
  for (final unit in input.codeUnits) {
    h = ((h << 5) + h) ^ unit;
  }
  final unsigned = h & 0xFFFFFFFF;
  return 'cyber-${unsigned.toRadixString(36)}';
}
