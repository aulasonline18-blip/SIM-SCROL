// ignore_for_file: unused_import, unnecessary_import
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../sim/billing/sim_server_billing_clients.dart';
import '../../sim/billing/checkout_return_controller.dart';
import '../../sim/billing/account_deletion.dart';
import '../../sim/billing/payment_return_store.dart';
import '../../sim/billing/payments_functions.dart';
import '../../sim/billing/play_billing_functions.dart';
import '../../sim/billing/sim_pricing.dart';
import '../../sim/analytics/visual_learning_feedback.dart';
import '../../sim/cloud/cloud_functions.dart';
import '../../sim/cloud/sim_server_cloud_functions.dart';
import '../../sim/cloud/supabase_client_contract.dart';
import '../../sim/cloud/supabase_flutter_session_provider.dart';
import '../../sim/cloud/supabase_student_state_cloud_storage.dart';
import '../../sim/config/sim_environment.dart';
import '../../sim/external_ai/sim_ai_server_config.dart';
import '../../sim/external_ai/sim_server_ai_clients.dart';
import '../../sim/external_ai/sim_server_attachment_client.dart';
import '../../sim/classroom/classroom_models.dart';
import '../../sim/classroom/lesson_runtime_engine.dart';
import '../../sim/classroom/lesson_main_view_model.dart';
import '../../sim/experience/student_experience_types.dart';
import '../../sim/organism/sim_organism.dart';
import '../../sim/organism/sim_organism_provider.dart';
import '../../sim/placement/placement_route_controller.dart';
import '../../session/auth_session.dart';
import '../../session/entry_form_state.dart';
import '../../session/lesson_ui_state.dart';
import '../../session/navigation_state.dart';
import '../../sim/lesson/lesson_models.dart';
import '../../sim/lesson/lesson_event_bus.dart';
import '../../sim/media/audio_core.dart';
import '../../sim/media/audio_preference.dart';
import '../../sim/media/doubt_audio.dart';
import '../../sim/media/image_data_url_compression.dart';
import '../../sim/media/lesson_audio_controller.dart';
import '../../sim/media/platform_audio_adapter.dart';
import '../../sim/media/s12_visual_pipeline.dart';
import '../../sim/media/student_lesson_media_service.dart';
import '../../sim/media/visual_funnel_telemetry.dart';
import '../../sim/state/shared_prefs_state_storage.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/state/student_state_store.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/widgets/cyber_step_shell.dart';
import '../../sim/ui/widgets/sim_preparation_experience.dart';
import '../../sim/ui/widgets/sim_typewriter.dart';
import '../../sim/auxiliary/aux_room_models.dart';
import '../../sim/auxiliary/doubt_input_sheet.dart';
import '../../sim/auxiliary/doubt_t02_caller.dart';
import '../../sim/auxiliary/lesson_doubt_controller.dart';
import '../../sim/ui/widgets/doubt_progress_bar.dart';

import '../../core/utils/sim_constants.dart';
import '../session/lab_session.dart';
import '../portal/portal_flow.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screens.dart';
import '../onboarding/preparation_and_placement.dart';
import '../classroom/aula_screen.dart';
import '../classroom/aux_room_screens.dart';
import '../classroom/aula_widgets.dart';
import '../billing/billing_and_simple_pages.dart';
import '../../shared/widgets/shared_widgets.dart';

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
    this.experiencePreparerOverride,
    this.prefs,
  }) : canonicalStore =
           canonicalStore ??
           StudentStateStore(local: MemoryStudentStateLocalStorage()) {
    _drawerCloudFunctions = drawerCloudFunctions;
    _drawerSessionProvider = drawerSessionProvider;
    _drawerBackupFileTextPicker = drawerBackupFileTextPicker;
    _drawerBackupFileSaver = drawerBackupFileSaver;
    _attachmentFilePicker = attachmentFilePicker;
    _accountDeletionGateway = accountDeletionGateway;
    _playBillingFunctions = playBillingFunctions;
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
  AccountDeletionGateway? _accountDeletionGateway;
  StudentStateCloudFunctions? _drawerCloudFunctions;
  SupabaseSessionProvider? _drawerSessionProvider;
  Future<String?> Function()? _drawerBackupFileTextPicker;
  Future<String?> Function(String fileName, String text)?
  _drawerBackupFileSaver;
  Future<SimAttachmentFile?> Function(String source)? _attachmentFilePicker;
  PlayBillingFunctions? _playBillingFunctions;

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
  );
  final PaymentReturnStore _paymentReturnStore = PaymentReturnStore();
  SimOrganism? _activeOrganism;
  LessonRuntimeSnapshot? aulaSnapshot;
  bool aulaRuntimeLoading = false;
  String? aulaRuntimeError;

  VisualLearningFeedbackReport get visualLearningFeedbackReport =>
      buildVisualLearningFeedbackReport(
        history: aulaSnapshot?.history ?? const [],
        doubt: lessonUiState.doubt,
        currentImageUrl: aulaSnapshot?.imagem,
      );

  VisualOperationalReport get visualOperationalReport =>
      VisualOperationalReport(
        funnel:
            _activeOrganism?.visualTelemetry.snapshot() ??
            const VisualFunnelSnapshot(
              total: 0,
              software: 0,
              paidOffer: 0,
              paidReady: 0,
              noImage: 0,
              failed: 0,
            ),
        feedback: visualLearningFeedbackReport,
      );

  bool _creditsLoaded = false;
  Future<void>? _creditsLoadInFlight;
  Future<void>? _launchExperienceInFlight;
  int _experienceGeneration = 0;

  late final AudioPreference _audioPreference = AudioPreference(
    storage: prefs == null ? null : SharedPrefsAudioPreferenceStorage(prefs!),
  );
  LessonAudioController? _lessonAudioController;
  DoubtAudio? _doubtAudio;
  String? _activeLessonMediaKey;
  SimOrganism? _activeLessonMediaOrganism;
  void Function()? _lessonImageUnsubscribe;
  void Function()? _lessonImageOfferUnsubscribe;
  LessonPaidImageOffer? _activePaidImageOffer;
  final Set<String> _declinedPaidImageOfferKeys = {};
  String? lessonImageOfferId;
  bool lessonImageOfferLoading = false;

  void _notifyFromChild() => notifyListeners();

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
  String get otherLanguage => entryForm.otherLanguage;
  String get freeText => entryForm.freeText;
  set freeText(String value) => entryForm.freeText = value;
  String get preferredName => entryForm.preferredName;
  set preferredName(String value) => entryForm.preferredName = value;
  bool get allowPaidImages => entryForm.allowPaidImages;
  List<AttachmentDraft> get attachments => entryForm.attachments;
  String get attachmentsText => entryForm.attachmentsText;
  String get studentProfileNotes => entryForm.studentProfileNotes;
  String? get attachmentError => entryForm.attachmentError;
  Map<String, String> get guidedAnswers => entryForm.guidedAnswers;

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
  DoubtState get doubt => lessonUiState.doubt;

  void setDoubt(DoubtState s) => lessonUiState.setDoubt(s);
  void resetDoubt() => lessonUiState.resetDoubt();
  void openReviewRoom() => lessonUiState.openReviewRoom();
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

  void startNewLessonFromDrawer() {
    stopActiveAudio(notify: false);
    _resetActiveLessonMedia(clearSnapshot: true, clearSubscriptions: true);
    lessonLocalId = null;
    entryForm
      ..freeText = ''
      ..preferredName = ''
      ..attachmentsText = ''
      ..studentProfileNotes = ''
      ..clearGuidedAnswers()
      ..clearAttachments()
      ..resetLanguage();
    lessonUiState
      ..entryStatus = 'idle'
      ..entryError = null
      ..placementStarted = false
      ..placementDone = false
      ..doubtOpen = false
      ..reviewRoom = null
      ..recoveryRoom = null
      ..resetDoubt();
    navigationState.openRoute('/cyber/objeto');
    notifyListeners();
  }

  void openCreditsFromDrawer() {
    const target = '/cyber/aula';
    if (!authed) {
      goLogin(target: target);
      return;
    }
    returnTo = target;
    navigationState.openRoute('/creditos?returnTo=/cyber/aula');
    notifyListeners();
  }

  Future<bool> openDrawerLocalLesson(String lessonLocalId) async {
    final local = _readExistingLocalState(lessonLocalId);
    if (local != null && !_stateDeleted(local)) {
      this.lessonLocalId = lessonLocalId;
      navigationState.openRoute('/cyber/aula');
      unawaited(openAulaRuntime());
      return true;
    }
    return openDrawerCloudLesson(lessonLocalId);
  }

  Future<bool> deleteDrawerLocalLesson(String lessonLocalId) async {
    final store = canonicalStore;
    if (store == null) return false;
    store.tombstoneLesson(lessonLocalId);
    var cloudOk = true;
    if (authed) {
      cloudOk = await deleteDrawerCloudLesson(lessonLocalId);
    }
    if (this.lessonLocalId == lessonLocalId) {
      this.lessonLocalId = null;
      navigationState.goPortal();
    }
    notifyListeners();
    return cloudOk;
  }

  String buildDrawerBackupText() {
    final store = canonicalStore;
    if (store == null) {
      throw StateError('Backup indisponivel.');
    }
    final states = store.listLocalStates(includeDeleted: false);
    if (states.isEmpty) {
      throw StateError('Nenhuma aula para exportar.');
    }
    final snapshots = <String, dynamic>{};
    final lessons = <Map<String, dynamic>>[];
    for (final state in states) {
      snapshots[state.lessonLocalId] = state.toJson();
      lessons.add(_cyberLessonFromState(state));
    }
    final file = <String, dynamic>{
      'magic': 'SIM_CYBER_BACKUP_V1',
      'exportedAt': DateTime.now().millisecondsSinceEpoch,
      'lessons': lessons,
      'studentLearningStates': snapshots,
    };
    final encoded = base64.encode(utf8.encode(jsonEncode(file)));
    return [
      'SIM — BACKUP DE AULA',
      'SIM_CYBER_V1_BEGIN',
      encoded,
      'SIM_CYBER_V1_END',
    ].join('\n');
  }

  Future<File> writeDrawerBackupFile(String text) async {
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final fileName = 'sim-backup-$stamp.txt';
    final savedPath = await _saveTextFile(fileName: fileName, text: text);
    if (savedPath != null && savedPath.trim().isNotEmpty) {
      return File(savedPath);
    }
    final file = File('${Directory.systemTemp.path}/$fileName');
    return file.writeAsString(text);
  }

  Future<String?> pickDrawerBackupFileText() async {
    final injected = _drawerBackupFileTextPicker;
    if (injected != null) return injected();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'json'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return null;
    final bytes = file.bytes;
    if (bytes != null) return utf8.decode(bytes);
    final path = file.path;
    if (path == null || path.trim().isEmpty) return null;
    return File(path).readAsString();
  }

  String buildDrawerStatusText() {
    final id = lessonLocalId;
    final store = canonicalStore;
    if (id == null || store == null) {
      throw StateError('Curriculo nao encontrado.');
    }
    final state = store.readState(id);
    final progress = state.progress;
    final curriculum = state.curriculum;
    return [
      'SIM - STATUS PEDAGOGICO',
      'Objetivo: ${state.profile.objetivo ?? '-'}',
      'Topico: ${curriculum?.topic ?? '-'}',
      'Item: ${state.current?.marker ?? '-'}',
      'Camada: ${state.current?.layer.name ?? '-'}',
      'Progresso: ${progress?.concluidos.length ?? 0}/${curriculum?.totalItems ?? 0}',
      'Tentativas: ${state.attempts.length}',
    ].join('\n');
  }

  Future<File> writeDrawerStatusFile(String text) async {
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final fileName = 'sim-status-$stamp.txt';
    final savedPath = await _saveTextFile(fileName: fileName, text: text);
    if (savedPath != null && savedPath.trim().isNotEmpty) {
      return File(savedPath);
    }
    final file = File('${Directory.systemTemp.path}/$fileName');
    return file.writeAsString(text);
  }

  Future<String?> _saveTextFile({
    required String fileName,
    required String text,
  }) async {
    final injected = _drawerBackupFileSaver;
    if (injected != null) return injected(fileName, text);
    try {
      return await FilePicker.platform.saveFile(
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        bytes: Uint8List.fromList(utf8.encode(text)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<StudentLearningState> importDrawerBackup(String raw) async {
    final store = canonicalStore;
    if (store == null) {
      throw StateError('Backup indisponivel.');
    }
    final backup = store.parseBackupText(raw);
    final ids = _lessonIdsFromBackup(backup);
    final state = store.importBackup(backup);
    lessonLocalId = state.lessonLocalId;
    if (authed) {
      final session = await _drawerSession();
      if (session != null) {
        for (final id in ids.isEmpty ? <String>[state.lessonLocalId] : ids) {
          final imported = _readExistingLocalState(id);
          if (imported == null || _stateDeleted(imported)) continue;
          await _cloudFunctionsForDrawer().persistStudentState(
            PersistStudentStateInput(
              lessonLocalId: id,
              state: imported,
              clientUpdatedAt: imported.updatedAt,
              clientScore: scoreOfStudentLearningState(imported),
              schemaVersion: studentLearningStateSchemaVersion,
            ),
            session,
          );
        }
      }
    }
    notifyListeners();
    return state;
  }

  Future<void> _warmUpServer() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final req = await client
          .getUrl(Uri.parse('$simApiBaseUrl/health'))
          .timeout(const Duration(seconds: 8));
      final res = await req.close().timeout(const Duration(seconds: 8));
      await res.drain<void>();
      client.close();
    } catch (_) {}
  }

  void start() {
    if (!authed) {
      debugPrint('[SIM] BLOCKED reason=not_authed');
      goLogin(target: '/');
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
    setSimActiveLanguage(code == 'other' ? stableLabel : code);
    entryForm.updateLanguage(code, stableLabel);
    final cleanName = name.trim();
    if (code != 'other' || cleanName.isNotEmpty) {
      navigationState.openRoute('/cyber/objeto');
    }
  }

  void setOtherLanguage(String value) => entryForm.setOtherLanguage(value);

  void setFreeText(String value) => entryForm.updateFreeText(value);

  void setPreferredName(String value) => entryForm.updatePreferredName(value);

  void setGuidedAnswer(String key, String value) {
    entryForm.updateGuidedAnswer(key, value);
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
      return 'Permissao negada para acessar o anexo.';
    }
    if (text.contains('AUDIO_NOT_SUPPORTED')) {
      return entryFormAudioNotSupportedMessage;
    }
    if (text.contains('VIDEO_NOT_SUPPORTED')) {
      return entryFormVideoNotSupportedMessage;
    }
    return 'Nao foi possivel abrir o anexo.';
  }

  bool saveObjectiveEntry() {
    final freeTrim = freeText.trim();
    if (freeTrim.length < 10) return false;
    final clipped = freeTrim.length > maxFreeText
        ? freeTrim.substring(0, maxFreeText)
        : freeTrim;
    entryForm.attachmentsText = entryForm.buildAttachmentsText();
    final guided = _guidedProfileFields(clipped);
    final language = stableLang ?? 'English';
    final id = _deriveLessonLocalId(clipped, selectedLanguageCode ?? language);
    lessonLocalId = id;
    entryForm.studentProfileNotes = _studentProfileNotes(
      objective: clipped,
      guidedSummary: guided['guided_summary']?.toString() ?? '',
      attachments: attachmentsText,
    );
    entryForm.freeText = clipped;
    _saveProfileToState(
      id: id,
      objective: clipped,
      language: language,
      guided: guided,
    );
    entryStatus = 'pedido_recebido';
    entryError = null;
    _experienceGeneration += 1;
    navigationState.openRoute('/cyber/curriculo');
    notifyListeners();
    return true;
  }

  Future<void> launchExperience() async {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) {
      entryStatus = 'erro';
      entryError =
          'Nao encontrei a aula atual. Troque o objetivo e tente novamente.';
      notifyListeners();
      return;
    }
    if (entryStatus == 't00_running' ||
        entryStatus == 't02_running' ||
        entryStatus == 'primeira_aula_pronta') {
      final inFlight = _launchExperienceInFlight;
      if (inFlight != null) await inFlight;
      return;
    }

    final generation = _experienceGeneration;
    final inFlight = _doLaunchExperience(id, generation);
    _launchExperienceInFlight = inFlight;
    try {
      await inFlight;
    } finally {
      if (identical(_launchExperienceInFlight, inFlight)) {
        _launchExperienceInFlight = null;
      }
    }
  }

  Future<void> _doLaunchExperience(String id, int generation) async {
    entryStatus = 't00_running';
    entryError = null;
    notifyListeners();

    try {
      final prepareOverride = experiencePreparerOverride;
      if (prepareOverride == null && prefs != null) {
        final ready = await _ensureProtectedServerSession(
          returnTo: '/cyber/curriculo',
          forceRefresh: true,
        );
        if (!ready) {
          if (!_isCurrentExperience(id, generation)) return;
          entryStatus = 'erro';
          entryError = 'Entre novamente para preparar sua aula com segurança.';
          notifyListeners();
          return;
        }
      }
      debugPrint('[SIM] T00_STARTED lessonLocalId=$id');
      final onboarding = <String, dynamic>{
        'objetivo': freeText.trim(),
        'free_text': freeText.trim(),
        'idioma': stableLang ?? 'pt-BR',
        'language': selectedLanguageCode ?? stableLang ?? 'pt-BR',
        'stableLang': stableLang ?? 'pt-BR',
        'STABLE_LANG': stableLang ?? 'pt-BR',
        'ACADEMIC_LEVEL': 'incerto',
        'academic_level': 'incerto',
        'nivel': 'incerto',
        'target_topic': freeText.trim(),
        'TARGET_TOPIC': freeText.trim(),
        ..._guidedProfileFields(freeText.trim()),
        if (preferredName.trim().isNotEmpty)
          'preferred_name': preferredName.trim(),
        if (studentProfileNotes.isNotEmpty)
          'student_profile_notes': studentProfileNotes,
        if (attachmentsText.isNotEmpty) 'attachments_text': attachmentsText,
      };
      final args = StudentExperienceArgs(
        academic: 'incerto',
        idioma: stableLang ?? 'pt-BR',
        lessonLocalId: id,
        onboarding: onboarding,
        onStage: (stage) {
          final next = switch (stage) {
            StudentExperienceRouteStage.curriculum => 't00_running',
            StudentExperienceRouteStage.lesson => 't02_running',
            StudentExperienceRouteStage.ready => 'primeira_aula_pronta',
            StudentExperienceRouteStage.placement => 'placement',
            _ => entryStatus,
          };
          entryStatus = next;
          notifyListeners();
        },
      );

      final result = await _prepareExperienceWithAuthRetry(
        id: id,
        args: args,
        prepareOverride: prepareOverride,
      );

      if (!_isCurrentExperience(id, generation)) return;
      entryStatus = 'primeira_aula_pronta';
      notifyListeners();

      debugPrint('[SIM] CLASSROOM_OPENED route=${result.destination}');
      navigationState.openRoute(result.destination);
      if (result.destination == '/cyber/aula') {
        unawaited(openAulaRuntime());
      }
    } on StudentExperienceEngineException catch (err) {
      if (!_isCurrentExperience(id, generation)) return;
      debugPrint('[SIM] BLOCKED reason=${err.error.message}');
      entryError = err.error.message;
      entryStatus = 'erro';
      notifyListeners();
    } catch (err) {
      if (!_isCurrentExperience(id, generation)) return;
      debugPrint('[SIM] BLOCKED reason=${err.toString()}');
      entryError = err.toString();
      entryStatus = 'erro';
      notifyListeners();
    }
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

  void retryExperience() {
    entryStatus = 'pedido_recebido';
    entryError = null;
    notifyListeners();
    unawaited(launchExperience());
  }

  void _saveProfileToState({
    required String id,
    required String objective,
    required String language,
    JsonMap guided = const {},
  }) {
    canonicalStore?.patchState(id, (state) {
      return state.copyWith(
        userId: userId,
        profile: state.profile.copyWith(
          preferredName: preferredName.trim().isEmpty
              ? state.profile.preferredName
              : preferredName.trim(),
          language: selectedLanguageCode ?? language,
          stableLang: stableLang ?? language,
          objetivo: objective,
          targetTopic: objective,
          sessionGoal: objective,
          extra: {...state.profile.extra, ...guided},
        ),
      );
    });
    canonicalStore?.appendEvent(
      lessonLocalId: id,
      type: 'STUDENT_FORM_SUBMITTED',
      payload: {'objective_length': objective.length, 'language': language},
      source: 'lab_session',
      userId: userId,
    );
  }

  JsonMap _guidedProfileFields(String objective) {
    final answers = guidedAnswers;
    String? value(String key) {
      final raw = answers[key]?.trim();
      return raw == null || raw.isEmpty ? null : raw;
    }

    final purpose = value('purpose');
    final level = value('level');
    final blocker = value('blocker');
    final deadline = value('deadline');
    final style = value('style');
    final start = value('start');

    final summaryLines = [
      if (purpose != null) 'Objetivo real: $purpose',
      if (level != null) 'Nivel percebido: $level',
      if (blocker != null) 'Onde trava: $blocker',
      if (deadline != null) 'Prazo/prova: $deadline',
      if (style != null) 'Como prefere ser conduzido: $style',
      if (start != null) 'Ponto de partida desejado: $start',
    ];
    final guidedSummary = summaryLines.join('\n');

    final fields = <String, dynamic>{};
    if (guidedSummary.isNotEmpty) fields['guided_summary'] = guidedSummary;
    if (purpose != null) {
      fields['real_use_goal'] = purpose;
      fields['exam_goal'] = purpose;
    }
    if (objective.trim().isNotEmpty) {
      fields['learning_goal'] = objective.trim();
    }
    if (level != null) {
      fields['academic_level'] = level;
      fields['nivel'] = level;
    }
    if (blocker != null) {
      fields['known_weaknesses'] = blocker;
      fields['learning_care_notes'] = blocker;
    }
    if (deadline != null) {
      fields['session_goal'] = deadline;
      fields['SESSION_GOAL'] = deadline;
    }
    if (style != null) {
      fields['attention_profile'] = style;
      fields['motivation_profile'] = style;
    }
    if (start != null) fields['prior_knowledge'] = start;
    if (answers.isNotEmpty) fields['guided_answers'] = JsonMap.from(answers);
    return fields;
  }

  String _studentProfileNotes({
    required String objective,
    required String guidedSummary,
    required String attachments,
  }) {
    return [
      objective,
      if (guidedSummary.trim().isNotEmpty)
        '--- Ficha guiada da travessia ---\n$guidedSummary',
      if (attachments.trim().isNotEmpty) attachments,
    ].join('\n\n').trim();
  }

  void openCredits() {
    if (!authed) {
      goLogin(target: '/creditos');
      return;
    }
    navigationState.openRoute('/creditos');
    notifyListeners();
  }

  Map<String, dynamic> _cyberLessonFromState(StudentLearningState state) {
    final curriculum = state.curriculum;
    final progress = state.progress;
    final layerNumber = switch (progress?.layer ??
        state.current?.layer ??
        LessonLayer.l1) {
      LessonLayer.l1 => 1,
      LessonLayer.l2 => 2,
      LessonLayer.l3 => 3,
    };
    return {
      'id': state.lessonLocalId,
      'name':
          state.profile.objetivo ?? curriculum?.topic ?? state.lessonLocalId,
      'createdAt': state.createdAt,
      'updatedAt': state.updatedAt,
      'onboarding': {
        ...state.profile.toJson(),
        'lessonLocalId': state.lessonLocalId,
        'objetivo': state.profile.objetivo ?? curriculum?.topic ?? '',
        'stableLang': state.profile.stableLang ?? state.profile.language ?? '',
      },
      'curriculo': {
        'topic': curriculum?.topic ?? state.profile.objetivo ?? '',
        'geradoEm': curriculum?.generatedAt ?? state.updatedAt,
        'provisional': curriculum?.provisional ?? false,
        'items': [
          for (final item in curriculum?.items ?? const <CurriculumItem>[])
            {
              ...item.toJson(),
              'id': item.marker,
              'title': item.title ?? item.text,
              'titulo': item.title ?? item.text,
              'item_name': item.text,
              'microitem_for_teacher': item.microitemForTeacher ?? item.text,
            },
        ],
      },
      'progress': {
        'itemIdx': progress?.itemIdx ?? state.current?.itemIdx ?? 0,
        'layer': layerNumber,
        'erros': progress?.erros ?? 0,
        'amparoLvl': progress?.amparoLvl ?? 0,
        'historia': progress?.historia ?? const <String>[],
        'mainAdvances': progress?.mainAdvances ?? 0,
        'concluidos': progress?.concluidos ?? const <String>[],
        'pendentes':
            progress?.pendentesMarkers
                .map((marker) => {'marker': marker})
                .toList() ??
            const <Map<String, dynamic>>[],
        'tentativas': [
          for (final attempt in state.attempts)
            {
              'marker': attempt.marker,
              'layer': switch (attempt.layer) {
                LessonLayer.l1 => 1,
                LessonLayer.l2 => 2,
                LessonLayer.l3 => 3,
              },
              'letra': attempt.letra.name,
              'sinal': attempt.sinal.value,
              'correct': attempt.correct,
              'ts': attempt.ts,
            },
        ],
      },
    };
  }

  Set<String> _lessonIdsFromBackup(Map<String, dynamic> backup) {
    final ids = <String>{};
    final states = backup['studentLearningStates'];
    if (states is Map) {
      ids.addAll(
        states.keys.map((key) => key.toString()).where((key) => key.isNotEmpty),
      );
    }
    final lessons = backup['lessons'];
    if (lessons is List) {
      for (final lesson in lessons.whereType<Map>()) {
        final id = lesson['id']?.toString().trim();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
    }
    final state = backup['state'];
    if (state is Map) {
      final id = state['lessonLocalId']?.toString().trim();
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    return ids;
  }

  void openSupport(String path) {
    navigationState.openRoute(path);
    notifyListeners();
  }

  void openExternalDoor(String url) => navigationState.openExternalDoor(url);

  void openCheckoutReturn() => navigationState.openRoute('/checkout/return');

  StripeEnvironment get _stripeEnvironment =>
      SimEnvironment.stripeEnvironment == 'live'
      ? StripeEnvironment.live
      : StripeEnvironment.sandbox;

  Future<String?> startCreditsCheckout(String packId) async {
    if (!authed || (authSession.userId ?? '').trim().isEmpty) {
      return 'login_required';
    }
    _paymentReturnStore.saveReturnTo(
      route == '/creditos' ? '/cyber/aula' : route,
    );
    if (SimEnvironment.useGooglePlayBilling) {
      try {
        final outcome = await _playBilling().purchaseCreditPack(
          CreditPackIdWire.fromWire(packId),
        );
        switch (outcome.status) {
          case PlayBillingPurchaseStatus.completed:
            credits = outcome.balance;
            authSession.isUnlimited = false;
            _loadCreditsFromServer(keepCurrent: true);
            notifyListeners();
            return null;
          case PlayBillingPurchaseStatus.pending:
            return 'Compra pendente no Google Play.';
          case PlayBillingPurchaseStatus.canceled:
            return 'Compra cancelada.';
          case PlayBillingPurchaseStatus.failed:
            return outcome.error ?? 'google_play_billing_failed';
        }
      } catch (error) {
        return error.toString();
      }
    }
    final client = SimServerPaymentsClient(config: _serverConfig());
    try {
      final result = await client.createCreditsCheckoutHosted(
        CreateCreditsCheckoutHostedInput(
          packId: packId,
          successUrl:
              '${SimEnvironment.checkoutReturnOrigin}/checkout/return?session_id={CHECKOUT_SESSION_ID}',
          cancelUrl:
              '${SimEnvironment.checkoutReturnOrigin}/creditos?canceled=1',
          environment: _stripeEnvironment,
        ).validate(),
      );
      if (!result.ok) return result.error ?? 'checkout_failed';
      final url = result.url;
      if (url == null || url.isEmpty) return 'checkout_url_missing';
      openExternalDoor(url);
      return null;
    } catch (error) {
      return error.toString();
    }
  }

  PlayBillingFunctions _playBilling() {
    return _playBillingFunctions ??= GooglePlayBillingFunctions(
      grantGateway: SimServerPlayBillingGrantClient(config: _serverConfig()),
    );
  }

  Future<CheckoutReturnState> confirmCheckoutReturn(String? sessionId) async {
    final controller = CheckoutReturnController(
      paymentsFunctions: SimServerPaymentsClient(config: _serverConfig()),
      returnStore: _paymentReturnStore,
      environment: _stripeEnvironment,
    );
    final state = await controller.confirm(sessionId);
    if (state.status == CheckoutStatusKind.complete) {
      authSession.credits = state.balance;
      authSession.isUnlimited = false;
      notifyListeners();
    }
    return state;
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
    if (!keepCurrent) {
      authSession.credits = 1;
      authSession.isUnlimited = false;
    }
    _creditsLoaded = false;
    final load = SimServerCreditsClient(config: _serverConfig())
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
    final store = canonicalStore;
    if (store == null) return;
    unawaited(
      store.hydrateFromCloud(id).catchError((_) => store.readState(id)),
    );
  }

  void _persistActiveLessonToCloud() {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return;
    final store = canonicalStore;
    if (store == null) return;
    unawaited(store.persistCloud(id).catchError((_) {}));
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

  Future<SupabaseSession?> _drawerSession() async {
    if (!authed) return null;
    return _sessionProviderForDrawer().currentSession();
  }

  Future<List<StudentStateSummaryRow>> listDrawerCloudLessons() async {
    final session = await _drawerSession();
    if (session == null) return const [];
    final rows = await _cloudFunctionsForDrawer().listStudentStateSummaries(
      session,
    );
    return rows.where((row) => !row.deleted).toList(growable: false);
  }

  Future<bool> openDrawerCloudLesson(String lessonLocalId) async {
    final session = await _drawerSession();
    if (session == null) return false;
    final row = await _cloudFunctionsForDrawer().getStudentStateByLesson(
      lessonLocalId,
      session,
    );
    final state = row?.state;
    if (state == null || _stateDeleted(state)) return false;
    canonicalStore?.writeState(state);
    this.lessonLocalId = state.lessonLocalId;
    navigationState.openRoute('/cyber/aula');
    unawaited(openAulaRuntime());
    return true;
  }

  Future<bool> renameDrawerCloudLesson(
    String lessonLocalId,
    String name,
  ) async {
    final clean = name.trim();
    if (clean.isEmpty) return false;
    final session = await _drawerSession();
    if (session == null) return false;
    final local = _readExistingLocalState(lessonLocalId);
    final remote = local == null
        ? (await _cloudFunctionsForDrawer().getStudentStateByLesson(
            lessonLocalId,
            session,
          ))?.state
        : null;
    final base = local ?? remote;
    if (base == null || _stateDeleted(base)) return false;
    final renamed = base.copyWith(
      profile: base.profile.copyWith(
        objetivo: clean,
        targetTopic: clean,
        sessionGoal: clean,
      ),
      extra: {
        ...base.extra,
        'renamedAt': DateTime.now().millisecondsSinceEpoch,
      },
    );
    canonicalStore?.writeState(renamed);
    await _cloudFunctionsForDrawer().persistStudentState(
      PersistStudentStateInput(
        lessonLocalId: lessonLocalId,
        state: renamed,
        clientUpdatedAt: renamed.updatedAt,
        clientScore: scoreOfStudentLearningState(renamed),
        schemaVersion: studentLearningStateSchemaVersion,
      ),
      session,
    );
    return true;
  }

  Future<bool> deleteDrawerCloudLesson(String lessonLocalId) async {
    final session = await _drawerSession();
    if (session == null) return false;
    await _cloudFunctionsForDrawer().deleteStudentStateByLesson(
      lessonLocalId,
      session,
    );
    if (_readExistingLocalState(lessonLocalId) != null) {
      canonicalStore?.tombstoneLesson(lessonLocalId);
    }
    if (this.lessonLocalId == lessonLocalId) {
      this.lessonLocalId = null;
      navigationState.goPortal();
    }
    return true;
  }

  StudentLearningState? _readExistingLocalState(String lessonLocalId) {
    final store = canonicalStore;
    if (store == null) return null;
    for (final state in store.listLocalStates(includeDeleted: true)) {
      if (state.lessonLocalId == lessonLocalId) return state;
    }
    return null;
  }

  bool _stateDeleted(StudentLearningState state) {
    return state.extra['deletedAt'] != null ||
        (state.extra['syncInfo'] is Map &&
            (state.extra['syncInfo'] as Map)['deletedAt'] != null);
  }

  LessonAudioController _audioControllerFor(String id) {
    final existing = _lessonAudioController;
    if (existing != null && existing.lessonLocalId == id) return existing;
    existing?.pararAudio();
    audioPlaying = false;
    audioLoading = false;
    final store = canonicalStore;
    final controller = LessonAudioController(
      lessonLocalId: id,
      preference: _audioPreference,
      mediaService: StudentLessonMediaService(
        audioCore: AudioCore(
          preference: _audioPreference,
          playback: PlatformAudioAdapter(),
          generatedAudioClient: SimServerGeneratedAudioClient(
            config: _serverConfig(),
          ),
          stableLangProvider: () =>
              stableLang ?? selectedLanguageCode ?? 'pt-BR',
        ),
        readState: (lessonLocalId) =>
            store?.readState(lessonLocalId) ??
            StudentLearningState.empty(lessonLocalId: lessonLocalId),
        writeState: (state) => store?.writeState(state) ?? state,
      ),
    );
    _lessonAudioController = controller;
    return controller;
  }

  DoubtAudio _doubtAudioFor() {
    final existing = _doubtAudio;
    if (existing != null) return existing;
    final audio = DoubtAudio(
      preference: _audioPreference,
      audioCore: AudioCore(
        preference: _audioPreference,
        playback: PlatformAudioAdapter(),
        generatedAudioClient: SimServerGeneratedAudioClient(
          config: _serverConfig(),
        ),
        stableLangProvider: () => stableLang ?? selectedLanguageCode ?? 'pt-BR',
        onGeneratedAudioError: (_) {
          audioError = 'Áudio remoto indisponível.';
          notifyListeners();
        },
      ),
    );
    _doubtAudio = audio;
    return audio;
  }

  LessonContent _currentLessonContentForAudio() {
    final content = aulaSnapshot?.conteudo;
    if (content == null) {
      throw StateError('Conteudo de aula ainda nao esta pronto para audio.');
    }
    return content;
  }

  JsonMap? get currentVisualTrigger => aulaSnapshot?.conteudo?.visualTrigger;

  String? get lessonPaidImagePrompt {
    final offer = _activePaidImageOffer;
    if (offer == null) return null;
    if (_declinedPaidImageOfferKeys.contains(offer.offerId)) return null;
    if (aulaSnapshot?.imagem != null) return null;
    return offer.prompt;
  }

  bool get hasLessonPaidImageOffer =>
      _activePaidImageOffer != null &&
      lessonPaidImagePrompt != null &&
      imageStatus != 'declined';

  void _resetActiveLessonMedia({
    bool clearSnapshot = false,
    bool clearSubscriptions = false,
  }) {
    if (clearSubscriptions) {
      _lessonImageUnsubscribe?.call();
      _lessonImageOfferUnsubscribe?.call();
      _lessonImageUnsubscribe = null;
      _lessonImageOfferUnsubscribe = null;
      _activeLessonMediaKey = null;
      _activeLessonMediaOrganism = null;
    }
    _activePaidImageOffer = null;
    _declinedPaidImageOfferKeys.clear();
    lessonImageOfferId = null;
    lessonImageOfferLoading = false;
    imageStatus = 'idle';
    imageError = null;
    lessonUiState.imageRequestId = null;
    lessonUiState.imageCacheKey = null;
    lessonUiState.imageCharged = null;
    lessonUiState.imageCacheHit = null;
    lessonUiState.imageRetryable = null;
    if (clearSnapshot) aulaSnapshot = null;
  }

  void _syncImageStateFromSnapshot() {
    if (aulaSnapshot?.imagem != null &&
        aulaSnapshot!.imagem!.trim().isNotEmpty) {
      imageStatus = 'ready';
      imageError = null;
      _activePaidImageOffer = null;
      lessonImageOfferId = null;
    }
  }

  void _bindActiveLessonMedia(SimOrganism organism) {
    final key = organism.lessonRuntimeEngine.activeLessonKey();
    if (key == null) return;
    if (key == _activeLessonMediaKey &&
        identical(organism, _activeLessonMediaOrganism)) {
      return;
    }
    _lessonImageUnsubscribe?.call();
    _lessonImageOfferUnsubscribe?.call();
    _resetActiveLessonMedia();
    _activeLessonMediaKey = key;
    _activeLessonMediaOrganism = organism;
    _syncImageStateFromSnapshot();
    _activePaidImageOffer = null;
    _lessonImageUnsubscribe = organism.eventBus.subscribe(key, (lesson) {
      if (lesson.imagem == null || lesson.imagem!.trim().isEmpty) return;
      final applied = organism.lessonRuntimeEngine.applyLessonUpdateForKey(
        key,
        lesson,
      );
      if (!applied) return;
      aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
      imageStatus = 'ready';
      imageError = null;
      _activePaidImageOffer = null;
      organism.eventBus.clearPaidImageOffer(key);
      notifyListeners();
    });
    _lessonImageOfferUnsubscribe = organism.eventBus.subscribePaidImageOffer(
      key,
      (offer) {
        if (offer == null) {
          if (_activePaidImageOffer?.lessonKey == key) {
            _activePaidImageOffer = null;
          }
          notifyListeners();
          return;
        }
        if (_declinedPaidImageOfferKeys.contains(offer.offerId)) return;
        if (aulaSnapshot?.imagem != null) return;
        _activePaidImageOffer = offer;
        lessonImageOfferId = offer.offerId;
        if (imageStatus != 'loading') imageStatus = 'offer';
        notifyListeners();
      },
    );
  }

  LessonMediaPosition? _activeImageMediaPosition() {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return null;
    return LessonMediaPosition(
      lessonLocalId: id,
      itemMarker: aulaSnapshot?.itemMarker,
      layer: currentAulaLayer,
    );
  }

  void _markLessonImageStarted(String? cacheKey) {
    final id = lessonLocalId;
    final position = _activeImageMediaPosition();
    if (id == null || position == null || canonicalStore == null) return;
    _audioControllerFor(
      id,
    ).mediaService.markLessonImageStarted(position, cacheKey: cacheKey);
  }

  void _markLessonImageReady({
    required String? cacheKey,
    required String imageUrl,
  }) {
    final id = lessonLocalId;
    final position = _activeImageMediaPosition();
    if (id == null || position == null || canonicalStore == null) return;
    _audioControllerFor(id).mediaService.markLessonImageReady(
      position,
      cacheKey: cacheKey,
      imageUrl: imageUrl,
    );
  }

  void _markLessonImageFailed(String error) {
    final id = lessonLocalId;
    final position = _activeImageMediaPosition();
    if (id == null || position == null || canonicalStore == null) return;
    _audioControllerFor(
      id,
    ).mediaService.markLessonImageFailed(position, error: error);
  }

  void declineLessonPaidImage() {
    final offer = _activePaidImageOffer;
    if (offer != null) {
      _declinedPaidImageOfferKeys.add(offer.offerId);
      _activeOrganism?.lessonOrchestrator.declinePaidImageOffer(
        offer.lessonKey,
      );
      _activeOrganism?.eventBus.clearPaidImageOffer(offer.lessonKey);
    }
    _activePaidImageOffer = null;
    imageStatus = 'declined';
    imageError = null;
    lessonUiState.imageRequestId = null;
    lessonUiState.imageRetryable = null;
    lessonImageOfferId = null;
    notifyListeners();
  }

  void buyImageCredits() {
    final offer = _activePaidImageOffer;
    if (offer != null) {
      _declinedPaidImageOfferKeys.remove(offer.offerId);
      _activeOrganism?.lessonOrchestrator.resetDeclinedPaidImageOffer(
        offer.lessonKey,
      );
    }
    navigationState.openRoute('/creditos?returnTo=/cyber/aula');
    notifyListeners();
  }

  Future<void> acceptLessonPaidImage() async {
    final offer = _activePaidImageOffer;
    if (offer == null || _activeOrganism == null || lessonImageOfferLoading) {
      return;
    }
    final key = offer.lessonKey;
    final offerId = offer.offerId;
    lessonImageOfferId = offerId;
    lessonImageOfferLoading = true;
    imageStatus = 'loading';
    imageError = null;
    lessonUiState.imageRequestId = null;
    lessonUiState.imageCacheKey = null;
    lessonUiState.imageCharged = null;
    lessonUiState.imageCacheHit = null;
    lessonUiState.imageRetryable = null;
    _markLessonImageStarted(offerId);
    notifyListeners();
    try {
      await _activeOrganism!.lessonOrchestrator.acceptPaidImageOffer(key);
      final cached = _activeOrganism!.lessonOrchestrator.peekCachedLesson(key);
      final dataUrl = cached?.imagem;
      if (dataUrl == null || dataUrl.trim().isEmpty) {
        throw StateError('Imagem indisponivel.');
      }
      if (aulaSnapshot?.imagem != dataUrl) {
        aulaSnapshot = aulaSnapshot?.copyWith(imagem: dataUrl);
      }
      imageStatus = 'ready';
      imageError = null;
      _activePaidImageOffer = null;
      _markLessonImageReady(cacheKey: offerId, imageUrl: dataUrl);
    } on SimExternalAiException catch (error) {
      lessonUiState.imageRequestId = error.requestId;
      lessonUiState.imageRetryable = error.retryable;
      imageStatus = 'error';
      imageError = 'Imagem indisponível. A aula continua sem imagem.';
      _markLessonImageFailed(
        [
          if (error.code != null) error.code,
          if (error.statusCode != null) 'HTTP ${error.statusCode}',
          if (error.requestId != null) 'requestId=${error.requestId}',
        ].whereType<String>().join(' | '),
      );
    } catch (error) {
      imageStatus = 'error';
      imageError = 'Imagem indisponível. A aula continua sem imagem.';
      _markLessonImageFailed(error.toString());
    } finally {
      lessonImageOfferLoading = false;
      notifyListeners();
    }
  }

  SimOrganism _organismForActiveLesson() {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) {
      throw StateError('lessonLocalId ausente para abrir organismo SIM.');
    }
    final organism = simOrganismProvider.forLesson(id);
    _activeOrganism = organism;
    return organism;
  }

  LessonContent _devLessonContent() => const LessonContent(
    explanation:
        'Vamos estudar frações equivalentes com uma explicação curta antes do desafio.',
    question: 'Qual alternativa representa uma fração equivalente a 1/2?',
    options: {
      AnswerLetter.A: '1/3',
      AnswerLetter.B: '2/4',
      AnswerLetter.C: '3/5',
    },
    correctAnswer: AnswerLetter.B,
  );

  bool get _allowDevAulaHarness => !SimEnvironment.isProduction;

  LessonRuntimeSnapshot _devAulaSnapshot({
    ClassroomPhase phase = const ClassroomPhase.reading(),
  }) {
    final content = _devLessonContent();
    return LessonRuntimeSnapshot(
      authReady: authReady,
      authed: authed,
      hasCurriculum: true,
      isDone: false,
      viewModel: LessonMainViewModel(
        progress: 0,
        headerLabel: 'aula_item_of:1/1:aula_layer_1',
        options: [
          LessonOptionModel(
            letter: AnswerLetter.A,
            text: content.options[AnswerLetter.A] ?? '',
          ),
          LessonOptionModel(
            letter: AnswerLetter.B,
            text: content.options[AnswerLetter.B] ?? '',
          ),
          LessonOptionModel(
            letter: AnswerLetter.C,
            text: content.options[AnswerLetter.C] ?? '',
          ),
        ],
        locked:
            phase.type == ClassroomPhaseType.processando ||
            phase.type == ClassroomPhaseType.concluido,
        nextLabel: phase.type == ClassroomPhaseType.concluido
            ? 'aula_next'
            : '',
      ),
      phase: phase,
      history: const [],
      conteudo: content,
      imagem: null,
      itemMarker: 'M-1',
      itemText: 'Frações equivalentes',
    );
  }

  Future<void> openAulaRuntime() async {
    if (aulaRuntimeLoading) return;
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) {
      aulaSnapshot = null;
      aulaRuntimeError = null;
      navigationState.openRoute('/cyber/objeto');
      notifyListeners();
      return;
    }
    aulaRuntimeLoading = true;
    aulaRuntimeError = null;
    notifyListeners();
    try {
      if (prefs == null) {
        if (!_allowDevAulaHarness) {
          throw StateError('Aula de desenvolvimento bloqueada em production.');
        }
        aulaSnapshot = _devAulaSnapshot();
        return;
      }
      final organism = _organismForActiveLesson();
      aulaSnapshot = await organism.lessonRuntimeEngine.open(
        lessonLocalId: organism.lessonLocalId,
        authReady: authReady,
        authed: authed,
      );
      _bindActiveLessonMedia(organism);
      _syncImageStateFromSnapshot();
      if (aulaSnapshot?.hasCurriculum != true) {
        aulaRuntimeError = 'Aula sem curriculo no Estado do aluno.';
      }
    } catch (error) {
      aulaRuntimeError = error.toString();
    } finally {
      aulaRuntimeLoading = false;
      notifyListeners();
    }
  }

  void preparationDone() {
    lessonUiState.markPreparationDone();
    navigationState.openRoute('/cyber/placement');
    _persistActiveLessonToCloud();
  }

  PlacementRouteController? get activePlacementController {
    if (lessonLocalId == null || lessonLocalId!.trim().isEmpty) return null;
    try {
      return _organismForActiveLesson().placementController;
    } catch (_) {
      return null;
    }
  }

  Future<void> openAulaAfterPlacementIfReady() async {
    final controller = activePlacementController;
    if (controller?.destination != '/cyber/aula') return;
    _applyPlacementStartMarkerIfNeeded();
    navigationState.openRoute('/cyber/aula');
    await openAulaRuntime();
  }

  void _applyPlacementStartMarkerIfNeeded() {
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) return;

    final organism = _organismForActiveLesson();
    final startMarker = organism.placementService.readStartMarker()?.trim();
    if (startMarker == null || startMarker.isEmpty) return;

    final state = organism.stateService.read(id);
    final curriculum = state?.curriculum;
    if (state == null || curriculum == null || curriculum.items.isEmpty) {
      return;
    }

    final itemIndex = curriculum.items.indexWhere(
      (item) => item.marker == startMarker,
    );
    if (itemIndex < 0) return;
    if (state.current?.marker == startMarker &&
        state.current?.itemIdx == itemIndex) {
      return;
    }

    final totalItems = curriculum.items.length;
    final percent = totalItems == 0
        ? 0
        : ((itemIndex / totalItems) * 100).round().clamp(0, 100);

    organism.stateService.mutate(id, (currentState) {
      final progress = currentState.progress;
      return currentState.copyWith(
        current: LessonCurrent(
          itemIdx: itemIndex,
          marker: startMarker,
          layer: LessonLayer.l1,
          amparoLvl: 0,
        ),
        progress:
            progress?.copyWith(
              itemIdx: itemIndex,
              layer: LessonLayer.l1,
              amparoLvl: 0,
              mainAdvances: itemIndex > progress.mainAdvances
                  ? itemIndex
                  : progress.mainAdvances,
              totalItems: totalItems,
              pctAvanco: percent,
            ) ??
            LessonProgress(
              itemIdx: itemIndex,
              layer: LessonLayer.l1,
              erros: 0,
              amparoLvl: 0,
              historia: const [],
              mainAdvances: itemIndex,
              concluidos: const [],
              pendentesMarkers: const [],
              totalItems: totalItems,
              pctAvanco: percent,
            ),
        events: [
          ...currentState.events,
          StudentLearningEvent(
            type: 'PLACEMENT_START_APPLIED',
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: {
              'start_marker': startMarker,
              'item_idx': itemIndex,
              'total_items': totalItems,
            },
          ),
        ],
      );
    });
    _persistActiveLessonToCloud();
  }

  void skipPlacement() {
    final controller = activePlacementController;
    if (controller != null) {
      controller.skip();
      unawaited(openAulaAfterPlacementIfReady());
      notifyListeners();
      return;
    }
    lessonUiState.skipPlacement();
    navigationState.openRoute('/cyber/aula');
    unawaited(openAulaRuntime());
  }

  Future<void> startPlacementTest() async {
    final controller = activePlacementController;
    if (controller == null) {
      lessonUiState.startPlacement();
      notifyListeners();
      return;
    }
    controller.chooseStart();
    notifyListeners();
    await controller.startTest();
    notifyListeners();
  }

  void answerPlacement(String choiceId) {
    final controller = activePlacementController;
    if (controller == null) return;
    controller.answer(choiceId);
    notifyListeners();
  }

  void startPlacement() => lessonUiState.startPlacement();

  void finishPlacement() {
    final controller = activePlacementController;
    if (controller != null) {
      controller.continueToAula();
      unawaited(openAulaAfterPlacementIfReady());
      notifyListeners();
      return;
    }
    lessonUiState.finishPlacement();
    navigationState.openRoute('/cyber/aula');
    unawaited(openAulaRuntime());
  }

  void chooseAulaAnswer(String letter) {
    stopActiveAudio();
    final answer = AnswerLetter.values.firstWhere(
      (value) => value.name == letter,
      orElse: () => AnswerLetter.A,
    );
    if (prefs == null) {
      if (!_allowDevAulaHarness) {
        aulaRuntimeError = 'Aula de desenvolvimento bloqueada em production.';
        notifyListeners();
        return;
      }
      aulaSnapshot = _devAulaSnapshot(phase: ClassroomPhase.expanded(answer));
      notifyListeners();
      return;
    }
    final organism = _activeOrganism ?? _organismForActiveLesson();
    organism.lessonRuntimeEngine.select(answer);
    aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
    _bindActiveLessonMedia(organism);
    notifyListeners();
  }

  void submitAulaSignal(int value) {
    stopActiveAudio();
    final signal = switch (value) {
      1 => DecisionSignal.one,
      2 => DecisionSignal.two,
      3 => DecisionSignal.three,
      _ => DecisionSignal.one,
    };
    if (prefs == null) {
      if (!_allowDevAulaHarness) {
        aulaRuntimeError = 'Aula de desenvolvimento bloqueada em production.';
        notifyListeners();
        return;
      }
      aulaSnapshot = _devAulaSnapshot(
        phase: ClassroomPhase.completed(
          message: 'aula_fb_correct',
          wasCorrect: true,
          signal: signal,
        ),
      );
      notifyListeners();
      return;
    }
    final organism = _activeOrganism ?? _organismForActiveLesson();
    unawaited(_doSignal(organism, signal));
  }

  Future<void> _doSignal(SimOrganism organism, DecisionSignal signal) async {
    final previousSnapshot = aulaSnapshot;
    aulaRuntimeLoading = true;
    aulaRuntimeError = null;
    notifyListeners();
    try {
      await organism.lessonRuntimeEngine.signal(signal);
      aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
      _bindActiveLessonMedia(organism);
      _persistActiveLessonToCloud();
    } catch (error) {
      if (previousSnapshot != null) {
        final recovered = previousSnapshot.copyWith(
          phase: const ClassroomPhase.reading(),
        );
        organism.lessonRuntimeEngine.restoreTransientSnapshot(recovered);
        aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
      }
      aulaRuntimeError = error.toString();
    } finally {
      aulaRuntimeLoading = false;
      notifyListeners();
    }
  }

  void setDeleteConfirmation(String value) {
    lessonUiState.setDeleteConfirmation(value);
  }

  void requestAccountDeletion() {
    unawaited(_requestAccountDeletion());
  }

  Future<void> _requestAccountDeletion() async {
    if (lessonUiState.accountDeletionLoading) return;
    final confirmation = lessonUiState.deleteConfirmation.trim();
    if (confirmation != 'DELETAR') {
      lessonUiState.failAccountDeletionRequest(
        'Digite DELETAR para confirmar a solicitação.',
      );
      return;
    }
    final id = (authSession.userId ?? '').trim();
    if (!authed || id.isEmpty) {
      lessonUiState.failAccountDeletionRequest(
        'Entre na sua conta para solicitar exclusão.',
      );
      return;
    }
    lessonUiState.beginAccountDeletionRequest();
    try {
      final gateway =
          _accountDeletionGateway ??
          SimServerAccountDeletionGateway(config: _serverConfig());
      await gateway.requestAccountDeletion(
        AccountDeletionRequest(
          userId: id,
          confirmation: confirmation,
          emailSnapshot: authSession.userEmail,
        ),
      );
      lessonUiState.completeAccountDeletionRequest();
      await authSession.signOutReal();
      navigationState.openRoute('/');
    } catch (error) {
      lessonUiState.failAccountDeletionRequest(
        'Não foi possível concluir a exclusão agora: $error',
      );
    }
  }

  Future<void> advanceAula() async {
    final organism = _activeOrganism ?? _organismForActiveLesson();
    stopActiveAudio(notify: false);
    aulaRuntimeLoading = true;
    aulaRuntimeError = null;
    notifyListeners();
    try {
      await organism.lessonRuntimeEngine.advance();
      aulaSnapshot = organism.lessonRuntimeEngine.snapshot();
      _bindActiveLessonMedia(organism);
      _persistActiveLessonToCloud();
    } catch (error) {
      aulaRuntimeError = error.toString();
    } finally {
      aulaRuntimeLoading = false;
      notifyListeners();
    }
  }

  void stopActiveAudio({bool notify = true}) {
    _lessonAudioController?.pararAudio();
    _doubtAudio?.stopDoubtAudio();
    audioPlaying = false;
    audioLoading = false;
    if (notify) notifyListeners();
  }

  void toggleDoubt() => lessonUiState.toggleDoubt();

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
      audioError = 'Nao foi possivel preparar o audio agora.';
      notifyListeners();
    }
  }

  Future<void> submitDoubt(DoubtInputDraft input) async {
    if (lessonUiState.doubt.status == DoubtStatus.processing) return;
    final validation = input.validate();
    if (validation != null) {
      setDoubt(
        DoubtState(
          status: DoubtStatus.error,
          progress: 0,
          sheetOpen: true,
          error: validation,
        ),
      );
      return;
    }
    if (lessonUiState.doubtOpen) lessonUiState.toggleDoubt();
    final snapshot = aulaSnapshot;
    final content = snapshot?.conteudo;
    if (prefs == null) {
      setDoubt(const DoubtState(status: DoubtStatus.processing, progress: 15));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      setDoubt(
        const DoubtState(
          status: DoubtStatus.explaining,
          progress: 100,
          response: DoubtResponse(
            explanation:
                'A dúvida foi recebida. Observe que frações equivalentes mantêm a mesma proporção.',
          ),
        ),
      );
      return;
    }
    if (content == null) {
      setDoubt(
        const DoubtState(
          status: DoubtStatus.error,
          progress: 0,
          error: defaultDoubtError,
        ),
      );
      return;
    }
    final id = lessonLocalId;
    if (id == null || id.trim().isEmpty) {
      setDoubt(
        const DoubtState(
          status: DoubtStatus.error,
          progress: 0,
          error: defaultDoubtError,
        ),
      );
      return;
    }
    final state = _activeCanonicalState;
    final profile = state?.profile;
    final controller = LessonDoubtController(
      caller: DoubtT02Caller(
        client: SimServerT02Client(config: _serverConfig()),
      ),
    );
    setDoubt(const DoubtState(status: DoubtStatus.processing, progress: 15));
    await controller.submitDoubt(
      lessonLocalId: id,
      profile: AuxRoomProfile(
        stableLang: profile?.stableLang ?? stableLang ?? selectedLanguageCode,
        academicLevel:
            profile?.academicLevel ?? profile?.nivel ?? 'ensino_medio',
        preferredName: profile?.preferredName ?? preferredName,
        notes: studentProfileNotes.isNotEmpty ? studentProfileNotes : null,
        extra: profile?.extra ?? const {},
      ),
      itemText: snapshot?.itemText ?? content.question,
      currentContent: '${content.explanation}\n\n${content.question}'.trim(),
      layer: currentAulaLayer,
      itemIdx: (state?.current?.itemIdx ?? state?.progress?.itemIdx ?? 0),
      marker: snapshot?.itemMarker ?? state?.current?.marker,
      input: input,
    );
    setDoubt(controller.state);
    if (controller.state.status == DoubtStatus.explaining) {
      final response = controller.state.response?.explanation;
      if (response != null && response.trim().isNotEmpty) {
        unawaited(
          _doubtAudioFor().speakDoubt(
            response,
            lang: profile?.stableLang ?? stableLang ?? selectedLanguageCode,
            lessonKey: '$id:${snapshot?.itemMarker ?? 'item'}',
          ),
        );
      }
      _persistActiveLessonToCloud();
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
        audioError = 'Áudio ainda não está disponível.';
      }
    } catch (_) {
      audioError = 'Não foi possível preparar o áudio agora.';
      audioPlaying = false;
    } finally {
      audioLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    entryForm.removeListener(_notifyFromChild);
    authSession.removeListener(_notifyFromChild);
    navigationState.removeListener(_notifyFromChild);
    lessonUiState.removeListener(_notifyFromChild);
    _lessonImageUnsubscribe?.call();
    _lessonImageOfferUnsubscribe?.call();
    unawaited(_playBillingFunctions?.dispose());
    authSession.dispose();
    _lessonAudioController?.pararAudio();
    _doubtAudio?.stopDoubtAudio();
    super.dispose();
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
