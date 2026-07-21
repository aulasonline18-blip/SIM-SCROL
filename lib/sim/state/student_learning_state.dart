// ignore_for_file: prefer_initializing_formals

part 'domain/student_profile.dart';
part 'domain/student_curriculum.dart';
part 'domain/student_progress.dart';
part 'cache/student_cache_info.dart';
part 'events/student_event_log.dart';
part 'snapshot/student_snapshot.dart';
part 'sync/student_sync_state.dart';

typedef JsonMap = Map<String, dynamic>;

int? _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) {
    final match = RegExp(r'\d+').firstMatch(value);
    return match == null ? null : int.tryParse(match.group(0)!);
  }
  return null;
}

String? _stringValue(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

const int studentLearningStateSchemaVersion = 1;
const String studentLearningStateKey = 'sim-student-learning-state-v1';

enum AnswerLetter { A, B, C }

enum DecisionSignal { one, two, three }

extension DecisionSignalValue on DecisionSignal {
  int get value => switch (this) {
    DecisionSignal.one => 1,
    DecisionSignal.two => 2,
    DecisionSignal.three => 3,
  };

  static DecisionSignal fromValue(Object? value) {
    return switch (value) {
      2 => DecisionSignal.two,
      3 => DecisionSignal.three,
      _ => DecisionSignal.one,
    };
  }
}

enum LessonLayer { l1, l2, l3 }

extension LessonLayerValue on LessonLayer {
  int get value => switch (this) {
    LessonLayer.l1 => 1,
    LessonLayer.l2 => 2,
    LessonLayer.l3 => 3,
  };

  static LessonLayer fromValue(Object? value) {
    return switch (value) {
      2 => LessonLayer.l2,
      3 => LessonLayer.l3,
      _ => LessonLayer.l1,
    };
  }
}

enum CurriculumStatusValue {
  empty,
  initialLoading,
  initialReady,
  streaming,
  partialReady,
  expanding,
  expanded,
  failed,
}

enum LiveEntryStatus {
  idle,
  pedidoRecebido,
  t00Running,
  firstItemReady,
  t02FirstLessonRunning,
  firstLessonReady,
  showingFirstLesson,
  failedT00,
  failedT02,
  blockedCredits,
}

class LiveEntry {
  const LiveEntry({
    required this.status,
    required this.error,
    required this.firstItemMarker,
    required this.firstLessonMaterialKey,
    required this.firstLessonStartedAt,
    required this.firstLessonReadyAt,
    required this.updatedAt,
  });

  final LiveEntryStatus status;
  final String? error;
  final String? firstItemMarker;
  final String? firstLessonMaterialKey;
  final int? firstLessonStartedAt;
  final int? firstLessonReadyAt;
  final int updatedAt;

  factory LiveEntry.empty([int now = 0]) => LiveEntry(
    status: LiveEntryStatus.idle,
    error: null,
    firstItemMarker: null,
    firstLessonMaterialKey: null,
    firstLessonStartedAt: null,
    firstLessonReadyAt: null,
    updatedAt: now,
  );

  LiveEntry copyWith({
    LiveEntryStatus? status,
    String? error,
    String? firstItemMarker,
    String? firstLessonMaterialKey,
    int? firstLessonStartedAt,
    int? firstLessonReadyAt,
    int? updatedAt,
  }) {
    return LiveEntry(
      status: status ?? this.status,
      error: error ?? this.error,
      firstItemMarker: firstItemMarker ?? this.firstItemMarker,
      firstLessonMaterialKey:
          firstLessonMaterialKey ?? this.firstLessonMaterialKey,
      firstLessonStartedAt: firstLessonStartedAt ?? this.firstLessonStartedAt,
      firstLessonReadyAt: firstLessonReadyAt ?? this.firstLessonReadyAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  JsonMap toJson() => {
    'status': status.name,
    'error': error,
    'first_item_marker': firstItemMarker,
    'first_lesson_material_key': firstLessonMaterialKey,
    'first_lesson_started_at': firstLessonStartedAt,
    'first_lesson_ready_at': firstLessonReadyAt,
    'updated_at': updatedAt,
  };

  factory LiveEntry.fromJson(JsonMap json) => LiveEntry(
    status: LiveEntryStatus.values.firstWhere(
      (status) => status.name == json['status'],
      orElse: () => LiveEntryStatus.idle,
    ),
    error: json['error'] as String?,
    firstItemMarker: json['first_item_marker'] as String?,
    firstLessonMaterialKey: json['first_lesson_material_key'] as String?,
    firstLessonStartedAt: (json['first_lesson_started_at'] as num?)?.toInt(),
    firstLessonReadyAt: (json['first_lesson_ready_at'] as num?)?.toInt(),
    updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  );
}

class StudentMasteryTruth {
  const StudentMasteryTruth({
    this.masteryEvidence = const [],
    this.weaknessRecords = const [],
    this.conquestRecords = const [],
    this.falseMasteryFlags = const [],
    this.needsRetestFlags = const [],
    this.itemConsolidationStatus = const {},
  });

  final List<JsonMap> masteryEvidence;
  final List<JsonMap> weaknessRecords;
  final List<JsonMap> conquestRecords;
  final List<String> falseMasteryFlags;
  final List<String> needsRetestFlags;
  final Map<String, String> itemConsolidationStatus;

  const StudentMasteryTruth.empty() : this();

  JsonMap toJson() => {
    'mastery_evidence': masteryEvidence,
    'weakness_records': weaknessRecords,
    'conquest_records': conquestRecords,
    'false_mastery_flags': falseMasteryFlags,
    'needs_retest_flags': needsRetestFlags,
    'item_consolidation_status': itemConsolidationStatus,
  };

  factory StudentMasteryTruth.fromJson(JsonMap json) {
    return StudentMasteryTruth(
      masteryEvidence: (json['mastery_evidence'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => JsonMap.from(entry))
          .toList(),
      weaknessRecords: (json['weakness_records'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => JsonMap.from(entry))
          .toList(),
      conquestRecords: (json['conquest_records'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => JsonMap.from(entry))
          .toList(),
      falseMasteryFlags: _stringList(json['false_mastery_flags']),
      needsRetestFlags: _stringList(json['needs_retest_flags']),
      itemConsolidationStatus:
          (json['item_consolidation_status'] as Map? ?? const {}).map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
    );
  }

  factory StudentMasteryTruth.fromLegacy(Object? legacy) {
    if (legacy is Map) {
      return StudentMasteryTruth.fromJson(JsonMap.from(legacy));
    }
    return const StudentMasteryTruth.empty();
  }

  StudentMasteryTruth copyWith({
    List<JsonMap>? masteryEvidence,
    List<JsonMap>? weaknessRecords,
    List<JsonMap>? conquestRecords,
    List<String>? falseMasteryFlags,
    List<String>? needsRetestFlags,
    Map<String, String>? itemConsolidationStatus,
  }) {
    return StudentMasteryTruth(
      masteryEvidence: masteryEvidence ?? this.masteryEvidence,
      weaknessRecords: weaknessRecords ?? this.weaknessRecords,
      conquestRecords: conquestRecords ?? this.conquestRecords,
      falseMasteryFlags: falseMasteryFlags ?? this.falseMasteryFlags,
      needsRetestFlags: needsRetestFlags ?? this.needsRetestFlags,
      itemConsolidationStatus:
          itemConsolidationStatus ?? this.itemConsolidationStatus,
    );
  }

  static List<String> _stringList(Object? value) {
    return (value is List ? value : const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
}

class StudentAudioState {
  const StudentAudioState({
    required this.status,
    required this.enabled,
    required this.playing,
    required this.updatedAt,
    this.lessonKey,
    this.language,
    this.voice,
    this.cacheKey,
    this.audioUrlHead,
    this.error,
  });

  final String status;
  final bool enabled;
  final bool playing;
  final int updatedAt;
  final String? lessonKey;
  final String? language;
  final String? voice;
  final String? cacheKey;
  final String? audioUrlHead;
  final String? error;

  factory StudentAudioState.empty([int now = 0]) => StudentAudioState(
    status: 'idle',
    enabled: true,
    playing: false,
    updatedAt: now,
  );

  JsonMap toJson() => {
    'status': status,
    'enabled': enabled,
    'playing': playing,
    'updated_at': updatedAt,
    if (lessonKey != null) 'lesson_key': lessonKey,
    if (language != null) 'language': language,
    if (voice != null) 'voice': voice,
    if (cacheKey != null) 'cache_key': cacheKey,
    if (audioUrlHead != null) 'audio_url_head': audioUrlHead,
    if (error != null) 'error': error,
  };

  factory StudentAudioState.fromJson(JsonMap json) => StudentAudioState(
    status: (json['status'] ?? 'idle').toString(),
    enabled: json['enabled'] != false,
    playing: json['playing'] == true,
    updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
    lessonKey: json['lesson_key'] as String?,
    language: json['language'] as String?,
    voice: json['voice'] as String?,
    cacheKey: json['cache_key'] as String?,
    audioUrlHead: json['audio_url_head'] as String?,
    error: json['error'] as String?,
  );

  StudentAudioState copyWith({
    String? status,
    bool? enabled,
    bool? playing,
    int? updatedAt,
    String? lessonKey,
    String? language,
    String? voice,
    String? cacheKey,
    String? audioUrlHead,
    String? error,
  }) {
    return StudentAudioState(
      status: status ?? this.status,
      enabled: enabled ?? this.enabled,
      playing: playing ?? this.playing,
      updatedAt: updatedAt ?? this.updatedAt,
      lessonKey: lessonKey ?? this.lessonKey,
      language: language ?? this.language,
      voice: voice ?? this.voice,
      cacheKey: cacheKey ?? this.cacheKey,
      audioUrlHead: audioUrlHead ?? this.audioUrlHead,
      error: error ?? this.error,
    );
  }

  StudentAudioState copyForRemoteVault() {
    return StudentAudioState(
      status: status,
      enabled: enabled,
      playing: false,
      updatedAt: updatedAt,
      lessonKey: lessonKey,
      language: language,
      voice: voice,
      cacheKey: cacheKey,
      audioUrlHead: null,
      error: error,
    );
  }
}

const Set<String> _remoteVaultLessonContentKeys = {
  'currentLessonMaterial',
  'current_lesson_material',
  'readyLessonMaterials',
  'ready_lesson_materials',
  'explanation',
  'explicacao',
  'conteudo',
  'question',
  'pergunta',
  'options',
  'alternatives',
  'alternativas',
  'answer',
  'correctAnswer',
  'correct_answer',
  'feedback',
  'whyCorrect',
  'whyWrong',
  'image',
  'imagem',
  'imageData',
  'dataUrl',
  'audio',
  'audioData',
  'audioText',
  'audioUrl',
  'speakableText',
};

StudentLearningEvent _sanitizeRemoteVaultEvent(StudentLearningEvent event) {
  final lessonPayload = _remoteVaultEventMayCarryLessonContent(event.type);
  return StudentLearningEvent(
    type: event.type,
    ts: event.ts,
    payload: _sanitizeRemoteVaultMap(
      event.payload,
      removeTextContentKey: lessonPayload,
    ),
  );
}

bool _remoteVaultEventMayCarryLessonContent(String type) {
  final normalized = type.toUpperCase();
  return normalized.contains('LESSON') ||
      normalized.contains('MATERIAL') ||
      normalized.contains('IMAGE') ||
      normalized.contains('AUDIO') ||
      normalized.contains('VISUAL') ||
      normalized.contains('T02');
}

JsonMap _sanitizeRemoteVaultMap(
  JsonMap input, {
  bool removeTextContentKey = false,
}) {
  final output = <String, dynamic>{};
  for (final entry in input.entries) {
    if (_remoteVaultLessonContentKeys.contains(entry.key)) continue;
    if (removeTextContentKey && entry.key == 'text') continue;
    output[entry.key] = _sanitizeRemoteVaultValue(
      entry.value,
      removeTextContentKey: removeTextContentKey,
    );
  }
  return output;
}

Object? _sanitizeRemoteVaultValue(
  Object? value, {
  bool removeTextContentKey = false,
}) {
  if (value is Map) {
    return _sanitizeRemoteVaultMap(
      JsonMap.from(value),
      removeTextContentKey: removeTextContentKey,
    );
  }
  if (value is List) {
    return value
        .map(
          (item) => _sanitizeRemoteVaultValue(
            item,
            removeTextContentKey: removeTextContentKey,
          ),
        )
        .toList(growable: false);
  }
  return value;
}

class StudentLearningState {
  static const Object _unset = Object();

  const StudentLearningState({
    required this.stateVersion,
    required this.lessonLocalId,
    required this.lessonCloudId,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.profile,
    required this.curriculum,
    this.curriculumStatus,
    required this.current,
    required this.progress,
    required this.attempts,
    required this.events,
    required this.entry,
    this.placement,
    this.auxRooms,
    this.currentLessonMaterial,
    this.readyLessonMaterials = const {},
    this.queuedActions = const [],
    this.inflightJobs = const [],
    this.truth = const StudentMasteryTruth.empty(),
    this.audio = const StudentAudioState(
      status: 'idle',
      enabled: true,
      playing: false,
      updatedAt: 0,
    ),
    this.syncStatus,
    this.extra = const {},
  });

  final int stateVersion;
  final String lessonLocalId;
  final String? lessonCloudId;
  final String? userId;
  final int createdAt;
  final int updatedAt;
  final StudentProfile profile;
  final StudentCurriculum? curriculum;
  final StudentCurriculumStatus? curriculumStatus;
  final LessonCurrent? current;
  final LessonProgress? progress;
  final List<LessonAttempt> attempts;
  final List<StudentLearningEvent> events;
  final LiveEntry? entry;
  final JsonMap? placement;
  final JsonMap? auxRooms;
  final JsonMap? currentLessonMaterial;
  final Map<String, JsonMap> readyLessonMaterials;
  final List<JsonMap> queuedActions;
  final List<JsonMap> inflightJobs;
  final StudentMasteryTruth truth;
  final StudentAudioState audio;
  final StudentSyncStatus? syncStatus;
  final JsonMap extra;

  bool get hasCurriculum => curriculum?.items.isNotEmpty == true;

  StudentEventLog get eventLog => StudentEventLog(events: events);

  StudentSyncState get syncState => StudentSyncState.fromStatus(syncStatus);

  StudentCacheInfo get cacheInfo => StudentCacheInfo(
    currentLessonMaterial: currentLessonMaterial,
    readyLessonMaterials: readyLessonMaterials,
    queuedActions: queuedActions,
    inflightJobs: inflightJobs,
  );

  StudentSnapshot get snapshot => StudentSnapshot(
    stateVersion: stateVersion,
    lessonLocalId: lessonLocalId,
    lessonCloudId: lessonCloudId,
    userId: userId,
    createdAt: createdAt,
    updatedAt: updatedAt,
    profile: profile,
    curriculum: curriculum,
    curriculumStatus: curriculumStatus,
    current: current,
    progress: progress,
  );

  StudentLearningState copyWith({
    int? stateVersion,
    String? lessonLocalId,
    String? lessonCloudId,
    String? userId,
    int? createdAt,
    int? updatedAt,
    StudentProfile? profile,
    StudentCurriculum? curriculum,
    StudentCurriculumStatus? curriculumStatus,
    LessonCurrent? current,
    LessonProgress? progress,
    List<LessonAttempt>? attempts,
    List<StudentLearningEvent>? events,
    LiveEntry? entry,
    JsonMap? placement,
    JsonMap? auxRooms,
    Object? currentLessonMaterial = _unset,
    Map<String, JsonMap>? readyLessonMaterials,
    List<JsonMap>? queuedActions,
    List<JsonMap>? inflightJobs,
    StudentMasteryTruth? truth,
    StudentAudioState? audio,
    StudentSyncStatus? syncStatus,
    JsonMap? extra,
  }) {
    return StudentLearningState(
      stateVersion: stateVersion ?? this.stateVersion,
      lessonLocalId: lessonLocalId ?? this.lessonLocalId,
      lessonCloudId: lessonCloudId ?? this.lessonCloudId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profile: profile ?? this.profile,
      curriculum: curriculum ?? this.curriculum,
      curriculumStatus: curriculumStatus ?? this.curriculumStatus,
      current: current ?? this.current,
      progress: progress ?? this.progress,
      attempts: attempts ?? this.attempts,
      events: events ?? this.events,
      entry: entry ?? this.entry,
      placement: placement ?? this.placement,
      auxRooms: auxRooms ?? this.auxRooms,
      currentLessonMaterial: identical(currentLessonMaterial, _unset)
          ? this.currentLessonMaterial
          : currentLessonMaterial as JsonMap?,
      readyLessonMaterials: readyLessonMaterials ?? this.readyLessonMaterials,
      queuedActions: queuedActions ?? this.queuedActions,
      inflightJobs: inflightJobs ?? this.inflightJobs,
      truth: truth ?? this.truth,
      audio: audio ?? this.audio,
      syncStatus: syncStatus ?? this.syncStatus,
      extra: extra ?? this.extra,
    );
  }

  factory StudentLearningState.empty({
    required String lessonLocalId,
    String? userId,
    int? now,
  }) {
    final ts = now ?? DateTime.now().millisecondsSinceEpoch;
    return StudentLearningState(
      stateVersion: studentLearningStateSchemaVersion,
      lessonLocalId: lessonLocalId,
      lessonCloudId: null,
      userId: userId,
      createdAt: ts,
      updatedAt: ts,
      profile: const StudentProfile(),
      curriculum: null,
      curriculumStatus: null,
      current: null,
      progress: null,
      attempts: const [],
      events: const [],
      entry: LiveEntry.empty(ts),
      placement: null,
      auxRooms: null,
      truth: const StudentMasteryTruth.empty(),
      audio: StudentAudioState.empty(ts),
      syncStatus: StudentSyncStatus.empty(ts),
    );
  }

  factory StudentLearningState.fromLegacy(JsonMap json) {
    return StudentLearningState.fromJson(json);
  }

  JsonMap toJson() => {
    ...extra,
    'stateVersion': stateVersion,
    'lessonLocalId': lessonLocalId,
    'lessonCloudId': lessonCloudId,
    'userId': userId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'profile': profile.toJson(),
    'curriculum': curriculum?.toJson(),
    'curriculumStatus': curriculumStatus?.toJson(),
    'current': current?.toJson(),
    'progress': progress?.toJson(),
    'attempts': attempts.map((attempt) => attempt.toJson()).toList(),
    'events': events.map((event) => event.toJson()).toList(),
    'entry': entry?.toJson(),
    'placement': placement,
    'auxRooms': auxRooms,
    'currentLessonMaterial': currentLessonMaterial,
    'readyLessonMaterials': readyLessonMaterials,
    'queuedActions': queuedActions,
    'inflightJobs': inflightJobs,
    'truth_typed': truth.toJson(),
    'audio_typed': audio.toJson(),
    'sync_status_typed': syncStatus?.toJson(),
  };

  StudentLearningState toRemoteVaultState() => copyWith(
    events: events.map(_sanitizeRemoteVaultEvent).toList(growable: false),
    placement: placement == null ? null : _sanitizeRemoteVaultMap(placement!),
    auxRooms: auxRooms == null ? null : _sanitizeRemoteVaultMap(auxRooms!),
    currentLessonMaterial: null,
    readyLessonMaterials: const {},
    queuedActions: queuedActions
        .map(_sanitizeRemoteVaultMap)
        .toList(growable: false),
    inflightJobs: inflightJobs
        .map(_sanitizeRemoteVaultMap)
        .toList(growable: false),
    audio: audio.copyForRemoteVault(),
    extra: _sanitizeRemoteVaultMap(extra),
  );

  JsonMap toRemoteVaultJson() {
    final json = toRemoteVaultState().toJson()
      ..['remote_state_contract'] = 'StudentLearningStateV1'
      ..remove('audio_typed')
      ..remove('currentLessonMaterial')
      ..remove('readyLessonMaterials')
      ..remove('current_lesson_material')
      ..remove('ready_lesson_materials');
    return _sanitizeRemoteVaultMap(json);
  }

  factory StudentLearningState.fromJson(JsonMap json) {
    final extra = JsonMap.of(json)
      ..removeWhere(
        (key, _) => {
          'stateVersion',
          'lessonLocalId',
          'lessonCloudId',
          'userId',
          'createdAt',
          'updatedAt',
          'profile',
          'curriculum',
          'curriculumStatus',
          'current',
          'progress',
          'attempts',
          'events',
          'entry',
          'placement',
          'auxRooms',
          'currentLessonMaterial',
          'readyLessonMaterials',
          'queuedActions',
          'inflightJobs',
          'truth_typed',
          'audio_typed',
          'sync_status_typed',
        }.contains(key),
      );
    final ready =
        ((json['readyLessonMaterials'] ?? json['ready_lesson_materials'])
                    as Map? ??
                const {})
            .map(
              (key, value) =>
                  MapEntry(key.toString(), JsonMap.from(value as Map)),
            );
    return StudentLearningState(
      stateVersion:
          (json['stateVersion'] as num?)?.toInt() ??
          studentLearningStateSchemaVersion,
      lessonLocalId: (json['lessonLocalId'] ?? '').toString(),
      lessonCloudId: json['lessonCloudId'] as String?,
      userId: json['userId'] as String?,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      profile: json['profile'] is Map
          ? StudentProfile.fromJson(JsonMap.from(json['profile'] as Map))
          : const StudentProfile(),
      curriculum: json['curriculum'] is Map
          ? StudentCurriculum.fromJson(JsonMap.from(json['curriculum'] as Map))
          : null,
      curriculumStatus: json['curriculumStatus'] is Map
          ? StudentCurriculumStatus.fromJson(
              JsonMap.from(json['curriculumStatus'] as Map),
            )
          : null,
      current: json['current'] is Map
          ? LessonCurrent.fromJson(JsonMap.from(json['current'] as Map))
          : null,
      progress: json['progress'] is Map
          ? LessonProgress.fromJson(JsonMap.from(json['progress'] as Map))
          : null,
      attempts: (json['attempts'] as List? ?? const [])
          .whereType<Map>()
          .map((attempt) => LessonAttempt.fromJson(JsonMap.from(attempt)))
          .toList(),
      events: (json['events'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (event) => StudentLearningEvent(
              type: (event['type'] ?? '').toString(),
              ts: (event['ts'] as num?)?.toInt() ?? 0,
              payload: event['payload'] is Map
                  ? JsonMap.from(event['payload'] as Map)
                  : const {},
            ),
          )
          .toList(),
      entry: json['entry'] is Map
          ? LiveEntry.fromJson(JsonMap.from(json['entry'] as Map))
          : null,
      placement: json['placement'] is Map
          ? JsonMap.from(json['placement'] as Map)
          : null,
      auxRooms: json['auxRooms'] is Map
          ? JsonMap.from(json['auxRooms'] as Map)
          : null,
      currentLessonMaterial:
          (json['currentLessonMaterial'] ?? json['current_lesson_material'])
              is Map
          ? JsonMap.from(
              (json['currentLessonMaterial'] ?? json['current_lesson_material'])
                  as Map,
            )
          : null,
      readyLessonMaterials: ready,
      queuedActions:
          ((json['queuedActions'] ?? json['queued_actions']) as List? ??
                  const [])
              .whereType<Map>()
              .map((entry) => JsonMap.from(entry))
              .toList(),
      inflightJobs:
          ((json['inflightJobs'] ?? json['inflight_jobs']) as List? ?? const [])
              .whereType<Map>()
              .map((entry) => JsonMap.from(entry))
              .toList(),
      truth: json['truth_typed'] is Map
          ? StudentMasteryTruth.fromJson(
              JsonMap.from(json['truth_typed'] as Map),
            )
          : StudentMasteryTruth.fromLegacy(json['truth']),
      audio: json['audio_typed'] is Map
          ? StudentAudioState.fromJson(JsonMap.from(json['audio_typed'] as Map))
          : StudentAudioState.empty((json['updatedAt'] as num?)?.toInt() ?? 0),
      syncStatus: json['sync_status_typed'] is Map
          ? StudentSyncStatus.fromJson(
              JsonMap.from(json['sync_status_typed'] as Map),
            )
          : null,
      extra: extra,
    );
  }
}

String _attemptMergeKey(LessonAttempt a) =>
    '${a.marker}|${a.layer.value}|${a.letra.name}|${a.sinal.value}|${a.correct}|${a.ts}';

List<LessonAttempt> mergeAttempts(
  List<LessonAttempt> existing,
  List<LessonAttempt> incoming,
) {
  final byKey = <String, LessonAttempt>{};
  for (final attempt in [...existing, ...incoming]) {
    byKey.putIfAbsent(_attemptMergeKey(attempt), () => attempt);
  }
  return byKey.values.toList()..sort((a, b) => a.ts.compareTo(b.ts));
}

List<StudentLearningEvent> mergeEvents(
  List<StudentLearningEvent> a,
  List<StudentLearningEvent> b,
) {
  final byKey = <String, StudentLearningEvent>{};
  for (final event in [...a, ...b]) {
    final key = _eventMergeKey(event);
    byKey.putIfAbsent(key, () => event);
  }
  return byKey.values.toList()..sort((x, y) => x.ts.compareTo(y.ts));
}

String _eventMergeKey(StudentLearningEvent event) {
  final id =
      event.payload['id'] ??
      event.payload['event_id'] ??
      event.payload['eventId'] ??
      event.payload['idempotencyKey'];
  if (id != null && id.toString().isNotEmpty) return id.toString();
  return '${event.type}:${event.ts}:${event.payload}';
}

List<String> mergeConcluidos(List<String> a, List<String> b) {
  final seen = <String>{};
  return [...a, ...b].where(seen.add).toList();
}

int _progressRank(LessonProgress? p) {
  if (p == null) return 0;
  return p.mainAdvances * 100000 + p.itemIdx * 1000 + p.layer.value * 100;
}

StudentLearningState mergeStudentLearningStateFromCloud(
  StudentLearningState local,
  StudentLearningState remote,
) {
  if (_stateMarkedDeleted(local)) return local;
  if (_stateMarkedDeleted(remote) && _hasActiveLearningState(local)) {
    return local;
  }
  final mergedAttempts = mergeAttempts(local.attempts, remote.attempts);
  final mergedEvents = mergeEvents(local.events, remote.events);
  final lp = local.progress;
  final rp = remote.progress;
  LessonProgress? mergedProgress;
  if (lp != null && rp != null) {
    final mergedConcluidos = mergeConcluidos(lp.concluidos, rp.concluidos);
    final greaterMainAdvances = lp.mainAdvances > rp.mainAdvances
        ? lp.mainAdvances
        : rp.mainAdvances;
    final baseProgress = _progressRank(lp) >= _progressRank(rp) ? lp : rp;
    mergedProgress = baseProgress.copyWith(
      concluidos: mergedConcluidos,
      mainAdvances: greaterMainAdvances,
    );
  } else {
    mergedProgress = lp ?? rp;
  }
  final localItems = local.curriculum?.items.length ?? 0;
  final remoteItems = remote.curriculum?.items.length ?? 0;
  final curriculum = remoteItems >= localItems
      ? remote.curriculum ?? local.curriculum
      : local.curriculum ?? remote.curriculum;
  final base = _progressRank(lp) >= _progressRank(rp) ? local : remote;
  final localCurrentRank = _progressRank(local.progress);
  final remoteCurrentRank = _progressRank(remote.progress);
  final current = localCurrentRank >= remoteCurrentRank
      ? local.current ?? remote.current
      : remote.current ?? local.current;
  final materialBase = _progressRank(lp) >= _progressRank(rp) ? local : remote;
  final readyLessonMaterials = identical(materialBase, local)
      ? {...remote.readyLessonMaterials, ...local.readyLessonMaterials}
      : {...local.readyLessonMaterials, ...remote.readyLessonMaterials};
  return base.copyWith(
    curriculum: curriculum,
    current: current,
    progress: mergedProgress,
    attempts: mergedAttempts,
    events: mergedEvents,
    currentLessonMaterial:
        materialBase.currentLessonMaterial ??
        local.currentLessonMaterial ??
        remote.currentLessonMaterial,
    readyLessonMaterials: readyLessonMaterials,
    auxRooms: base.auxRooms ?? local.auxRooms ?? remote.auxRooms,
    truth: _hasServerMasteryTruth(remote.truth)
        ? remote.truth
        : _hasServerMasteryTruth(base.truth)
        ? base.truth
        : _hasServerMasteryTruth(local.truth)
        ? local.truth
        : remote.truth,
    audio: base.audio.status != 'idle'
        ? base.audio
        : local.audio.status != 'idle'
        ? local.audio
        : remote.audio,
    updatedAt: local.updatedAt > remote.updatedAt
        ? local.updatedAt
        : remote.updatedAt,
  );
}

bool _stateMarkedDeleted(StudentLearningState state) {
  return state.extra['deletedAt'] != null ||
      (state.extra['syncInfo'] is Map &&
          (state.extra['syncInfo'] as Map)['deletedAt'] != null);
}

bool _hasActiveLearningState(StudentLearningState state) {
  return (state.profile.objetivo ?? '').trim().isNotEmpty ||
      state.curriculum?.items.isNotEmpty == true ||
      state.current != null ||
      state.progress != null ||
      state.currentLessonMaterial != null ||
      state.readyLessonMaterials.isNotEmpty;
}

bool _hasServerMasteryTruth(StudentMasteryTruth truth) =>
    truth.masteryEvidence.isNotEmpty ||
    truth.weaknessRecords.isNotEmpty ||
    truth.conquestRecords.isNotEmpty ||
    truth.itemConsolidationStatus.isNotEmpty;

StudentLearningState mergeValidatedRemoteState(
  StudentLearningState localCandidate,
  StudentLearningState validatedRemote,
) {
  final materialBase =
      _progressRank(localCandidate.progress) >=
          _progressRank(validatedRemote.progress)
      ? localCandidate
      : validatedRemote;
  return validatedRemote.copyWith(
    attempts: mergeAttempts(validatedRemote.attempts, localCandidate.attempts),
    events: mergeEvents(validatedRemote.events, localCandidate.events),
    readyLessonMaterials: identical(materialBase, localCandidate)
        ? {
            ...validatedRemote.readyLessonMaterials,
            ...localCandidate.readyLessonMaterials,
          }
        : {
            ...localCandidate.readyLessonMaterials,
            ...validatedRemote.readyLessonMaterials,
          },
    currentLessonMaterial:
        materialBase.currentLessonMaterial ??
        localCandidate.currentLessonMaterial ??
        validatedRemote.currentLessonMaterial,
    queuedActions: _mergeJsonListByStableKey(
      validatedRemote.queuedActions,
      localCandidate.queuedActions,
    ),
    inflightJobs: _mergeJsonListByStableKey(
      validatedRemote.inflightJobs,
      localCandidate.inflightJobs,
    ),
    updatedAt: validatedRemote.updatedAt > localCandidate.updatedAt
        ? validatedRemote.updatedAt
        : localCandidate.updatedAt,
  );
}

List<JsonMap> _mergeJsonListByStableKey(List<JsonMap> a, List<JsonMap> b) {
  final byKey = <String, JsonMap>{};
  for (final entry in [...a, ...b]) {
    final key =
        (entry['id'] ??
                entry['eventId'] ??
                entry['idempotencyKey'] ??
                entry['type'] ??
                entry.toString())
            .toString();
    byKey.putIfAbsent(key, () => entry);
  }
  return byKey.values.toList(growable: false);
}
