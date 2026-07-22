import 'dart:convert';

import '../localization/sim_locale_contract.dart';
import 'student_learning_state.dart';
import 'student_state_contract.dart';
import 'student_state_integrity.dart';

export 'student_state_integrity.dart';

part 'student_state_store_cyber_backup.dart';

enum StateConflictResolution { local, cloud, equal }

class CanonicalLearningEvent {
  const CanonicalLearningEvent({
    required this.eventId,
    required this.type,
    required this.lessonLocalId,
    required this.payload,
    required this.createdAt,
    required this.source,
    required this.schemaVersion,
    this.userId,
    this.stateVersionBefore,
    this.stateVersionAfter,
  });

  final String eventId;
  final String type;
  final String lessonLocalId;
  final String? userId;
  final JsonMap payload;
  final int createdAt;
  final String source;
  final int schemaVersion;
  final int? stateVersionBefore;
  final int? stateVersionAfter;

  StudentLearningEvent toLegacyEvent() => StudentLearningEvent(
    type: type,
    ts: createdAt,
    payload: {
      ...payload,
      'event_id': eventId,
      'lesson_local_id': lessonLocalId,
      'user_id': userId,
      'source': source,
      'schema_version': schemaVersion,
      'state_version_before': stateVersionBefore,
      'state_version_after': stateVersionAfter,
    },
  );

  JsonMap toJson() => {
    'event_id': eventId,
    'type': type,
    'lesson_local_id': lessonLocalId,
    'user_id': userId,
    'payload': payload,
    'created_at': createdAt,
    'source': source,
    'schema_version': schemaVersion,
    'state_version_before': stateVersionBefore,
    'state_version_after': stateVersionAfter,
  };

  factory CanonicalLearningEvent.fromJson(JsonMap json) {
    return CanonicalLearningEvent(
      eventId: (json['event_id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      lessonLocalId: (json['lesson_local_id'] ?? '').toString(),
      userId: json['user_id'] as String?,
      payload: json['payload'] is Map
          ? JsonMap.from(json['payload'] as Map)
          : const {},
      createdAt:
          (json['created_at'] as num?)?.toInt() ??
          (json['ts'] as num?)?.toInt() ??
          0,
      source: (json['source'] ?? 'unknown').toString(),
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      stateVersionBefore: (json['state_version_before'] as num?)?.toInt(),
      stateVersionAfter: (json['state_version_after'] as num?)?.toInt(),
    );
  }
}

abstract interface class StudentStateLocalStorage {
  String? readState(String lessonLocalId);
  void writeState(String lessonLocalId, String encoded);
  String? readEvents(String lessonLocalId);
  void writeEvents(String lessonLocalId, String encoded);
  void deleteState(String lessonLocalId);
  void deleteEvents(String lessonLocalId);
  List<String> listStateIds();
}

class StudentStateStorageException implements Exception {
  const StudentStateStorageException(this.code);

  final String code;

  @override
  String toString() => code;
}

abstract interface class DurableStudentStateLocalStorage
    implements StudentStateLocalStorage {
  Future<void> verifyLastStateWrite();
  Future<void> verifyLastEventsWrite();
  Future<void> verifyLastDelete();
}

abstract interface class StudentStateCloudStorage {
  Future<StudentLearningState?> loadCloud(String lessonLocalId);
}

abstract interface class StudentStateRepository {
  StudentLearningState readState(String lessonLocalId);
  StudentLearningState writeState(
    StudentLearningState state, {
    bool acceptServerAuthority,
    bool allowLocalHousekeeping,
  });
  StudentLearningState patchState(
    String lessonLocalId,
    StudentLearningState Function(StudentLearningState state) patch, {
    bool allowLocalHousekeeping,
  });
  List<StudentLearningState> listLocalStates({bool includeDeleted});
  Future<StudentLearningState> hydrateFromCloud(String lessonLocalId);
}

class StudentStateStore implements StudentStateRepository {
  StudentStateStore({
    required this.local,
    this.cloud,
    int Function()? now,
    String Function()? idFactory,
  }) : now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
       idFactory = idFactory ?? _defaultId;

  final StudentStateLocalStorage local;
  final StudentStateCloudStorage? cloud;
  final int Function() now;
  final String Function() idFactory;
  final Map<String, StudentLearningState> _memory = {};
  final Map<String, List<CanonicalLearningEvent>> _eventLog = {};
  final List<StudentStateIntegrityIssue> _integrityIssues = [];
  StudentStatePersistenceAudit _lastPersistenceAudit =
      const StudentStatePersistenceAudit(
        status: StudentStatePersistenceStatus.idle,
        operation: 'idle',
        lessonLocalId: '',
      );

  List<StudentStateIntegrityIssue> get integrityIssues =>
      List.unmodifiable(_integrityIssues);

  StudentStatePersistenceAudit get lastPersistenceAudit =>
      _lastPersistenceAudit;

  @override
  StudentLearningState readState(String lessonLocalId) {
    final cached = _memory[lessonLocalId];
    if (cached != null) return cached;
    final encoded = local.readState(lessonLocalId);
    if (encoded != null && encoded.trim().isNotEmpty) {
      final state = _decodeStateOrQuarantine(lessonLocalId, encoded);
      if (state != null) {
        _memory[lessonLocalId] = state;
        _eventLog[lessonLocalId] = _readEvents(lessonLocalId);
        return state;
      }
      return StudentLearningState.empty(
        lessonLocalId: lessonLocalId,
        now: now(),
      ).copyWith(
        extra: {
          'stateIntegrity': {
            'status': 'corrupted',
            'code': 'STATE_LOCAL_CORRUPTED',
            'recoverable': true,
          },
        },
      );
    }
    final state = StudentLearningState.empty(
      lessonLocalId: lessonLocalId,
      now: now(),
    );
    writeState(state);
    return state;
  }

  @override
  StudentLearningState writeState(
    StudentLearningState state, {
    bool acceptServerAuthority = false,
    bool allowLocalHousekeeping = false,
  }) {
    final existing =
        _memory[state.lessonLocalId] ?? _readStateIfExists(state.lessonLocalId);
    final protected =
        !acceptServerAuthority &&
            !allowLocalHousekeeping &&
            existing != null &&
            StudentStateContract().isRegression(
              existing: existing,
              incoming: state,
            )
        ? mergeStudentLearningStateFromCloud(existing, state)
        : state;
    final next = protected.copyWith(updatedAt: now());
    _memory[next.lessonLocalId] = next;
    local.writeState(next.lessonLocalId, jsonEncode(next.toJson()));
    _verifyDurableOperation(next.lessonLocalId, 'write_state');
    return next;
  }

  @override
  StudentLearningState patchState(
    String lessonLocalId,
    StudentLearningState Function(StudentLearningState state) patch, {
    bool allowLocalHousekeeping = false,
  }) {
    return writeState(
      patch(readState(lessonLocalId)),
      allowLocalHousekeeping: allowLocalHousekeeping,
    );
  }

  CanonicalLearningEvent mutateWithEvent({
    required String lessonLocalId,
    required String type,
    required JsonMap payload,
    required String source,
    required StudentLearningState Function(
      StudentLearningState state,
      CanonicalLearningEvent event,
    )
    mutate,
    String? userId,
  }) {
    final before = readState(lessonLocalId);
    final beforeRevision = _foundationRevision(before);
    final event = CanonicalLearningEvent(
      eventId: idFactory(),
      type: type,
      lessonLocalId: lessonLocalId,
      userId: userId ?? before.userId,
      payload: {
        ...payload,
        'foundation_revision_before': beforeRevision,
        'foundation_revision_after': beforeRevision + 1,
      },
      createdAt: now(),
      source: source,
      schemaVersion: studentLearningStateSchemaVersion,
      stateVersionBefore: before.stateVersion,
      stateVersionAfter: before.stateVersion,
    );
    final mutated = mutate(before, event);
    final next = _stampFoundationRevision(
      mutated.copyWith(events: [...mutated.events, event.toLegacyEvent()]),
      event,
      beforeRevision + 1,
    );
    _writeCanonicalEvent(event);
    writeState(next);
    return event;
  }

  CanonicalLearningEvent appendEvent({
    required String lessonLocalId,
    required String type,
    required JsonMap payload,
    required String source,
    String? userId,
  }) {
    return mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: type,
      payload: payload,
      source: source,
      userId: userId,
      mutate: (state, _) => state,
    );
  }

  List<CanonicalLearningEvent> getEventLog(String lessonLocalId) {
    return List.unmodifiable(
      _eventLog[lessonLocalId] ?? _readEvents(lessonLocalId),
    );
  }

  void removeLocalLessonData(String lessonLocalId) {
    _memory.remove(lessonLocalId);
    _eventLog.remove(lessonLocalId);
    local.deleteState(lessonLocalId);
    local.deleteEvents(lessonLocalId);
    _verifyDurableOperation(lessonLocalId, 'delete');
  }

  @override
  List<StudentLearningState> listLocalStates({bool includeDeleted = false}) {
    final ids = {...local.listStateIds(), ..._memory.keys};
    final states = ids.map(readState).where((state) {
      if (includeDeleted) return true;
      return state.extra['deletedAt'] == null &&
          (state.extra['syncInfo'] is! Map ||
              (state.extra['syncInfo'] as Map)['deletedAt'] == null);
    }).toList();
    states.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return states;
  }

  StudentLearningState renameLesson(String lessonLocalId, String name) {
    final clean = name.trim();
    final state = readState(lessonLocalId);
    if (clean.isEmpty) return state;
    return writeState(
      state.copyWith(
        profile: state.profile.copyWith(
          objetivo: clean,
          targetTopic: clean,
          sessionGoal: clean,
        ),
        extra: {...state.extra, 'renamedAt': now()},
      ),
    );
  }

  StudentLearningState tombstoneLesson(String lessonLocalId) {
    final ts = now();
    final state = readState(lessonLocalId);
    return writeState(
      state.copyWith(
        extra: {
          ...state.extra,
          'deletedAt': ts,
          'syncInfo': {
            if (state.extra['syncInfo'] is Map)
              ...JsonMap.from(state.extra['syncInfo'] as Map),
            'deletedAt': ts,
            'operation': 'tombstone',
          },
        },
      ),
    );
  }

  StudentLearningState replayEvents({
    required StudentLearningState seed,
    required Iterable<CanonicalLearningEvent> events,
  }) {
    var state = seed;
    final seen = <String>{};
    var revision = _foundationRevision(seed);
    for (final event in events) {
      if (!seen.add(event.eventId)) continue;
      state = _applyKnownEvent(state, event);
      revision += 1;
      state = _stampFoundationRevision(state, event, revision);
    }
    return state.copyWith(
      events: events.map((event) => event.toLegacyEvent()).toList(),
    );
  }

  @override
  Future<StudentLearningState> hydrateFromCloud(String lessonLocalId) async {
    final localState = readState(lessonLocalId);
    final remote = await cloud?.loadCloud(lessonLocalId);
    final resolved = syncState(localState, remote);
    writeState(resolved);
    return resolved;
  }

  StudentLearningState syncState(
    StudentLearningState localState,
    StudentLearningState? cloudState,
  ) {
    if (cloudState == null) return localState;
    return mergeStudentLearningStateFromCloud(localState, cloudState);
  }

  StateConflictResolution resolveConflict(
    StudentLearningState localState,
    StudentLearningState cloudState,
  ) {
    final localScore = highWaterMark(localState);
    final cloudScore = highWaterMark(cloudState);
    if (cloudScore > localScore) return StateConflictResolution.cloud;
    if (localScore > cloudScore) return StateConflictResolution.local;
    return StateConflictResolution.equal;
  }

  JsonMap exportBackup(String lessonLocalId) {
    final state = readState(lessonLocalId);
    return {
      'kind': 'sim-student-learning-backup',
      'schema_version': studentLearningStateSchemaVersion,
      'exported_at': now(),
      'state': state.toJson(),
      'events': getEventLog(lessonLocalId).map((e) => e.toJson()).toList(),
    };
  }

  JsonMap parseBackupText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) throw const FormatException('backup vazio');
    const begin = 'SIM_CYBER_V1_BEGIN';
    const end = 'SIM_CYBER_V1_END';
    final beginAt = text.indexOf(begin);
    final endAt = text.indexOf(end);
    if (beginAt >= 0 && endAt > beginAt) {
      final encoded = text
          .substring(beginAt + begin.length, endAt)
          .replaceAll(RegExp(r'\s+'), '');
      final decoded = utf8.decode(base64.decode(encoded));
      final parsed = jsonDecode(decoded);
      if (parsed is Map) return JsonMap.from(parsed);
      throw const FormatException('backup invalido');
    }
    final parsed = text.startsWith('{')
        ? jsonDecode(text)
        : jsonDecode(
            utf8.decode(base64.decode(text.replaceAll(RegExp(r'\s+'), ''))),
          );
    if (parsed is Map) return JsonMap.from(parsed);
    throw const FormatException('backup invalido');
  }

  StudentLearningState importBackup(JsonMap backup) {
    if (backup['magic'] == 'SIM_CYBER_BACKUP_V1') {
      return _importCyberBackup(this, backup);
    }
    final rawState = backup['state'];
    if (rawState is! Map) {
      throw ArgumentError('Backup sem state valido.');
    }
    final state = StudentLearningState.fromJson(JsonMap.from(rawState));
    final rawEvents = backup['events'];
    final events = rawEvents is List
        ? rawEvents
              .whereType<Map>()
              .map(
                (event) => CanonicalLearningEvent.fromJson(JsonMap.from(event)),
              )
              .toList()
        : <CanonicalLearningEvent>[];
    final dedupedEvents = _dedupeEvents(events);
    final existing =
        _memory[state.lessonLocalId] ?? _readStateIfExists(state.lessonLocalId);
    final protectedState = existing == null
        ? state
        : mergeValidatedRemoteState(state, existing);
    _eventLog[state.lessonLocalId] = dedupedEvents;
    local.writeEvents(
      state.lessonLocalId,
      jsonEncode(dedupedEvents.map((e) => e.toJson()).toList()),
    );
    _verifyDurableOperation(state.lessonLocalId, 'write_events');
    return writeState(protectedState);
  }

  StudentLearningState? _readStateIfExists(String lessonLocalId) {
    final encoded = local.readState(lessonLocalId);
    if (encoded == null || encoded.trim().isEmpty) return null;
    return _decodeStateOrQuarantine(lessonLocalId, encoded);
  }

  StudentLearningState? _decodeStateOrQuarantine(
    String lessonLocalId,
    String encoded,
  ) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        return StudentLearningState.fromJson(JsonMap.from(decoded));
      }
      _recordIntegrityIssue(
        kind: StudentStateIntegrityKind.state,
        lessonLocalId: lessonLocalId,
        payload: encoded,
        code: 'STATE_LOCAL_SCHEMA_INVALID',
      );
      return null;
    } catch (_) {
      _recordIntegrityIssue(
        kind: StudentStateIntegrityKind.state,
        lessonLocalId: lessonLocalId,
        payload: encoded,
        code: 'STATE_LOCAL_CORRUPTED',
      );
      return null;
    }
  }

  int highWaterMark(StudentLearningState state) {
    final progress = state.progress;
    final current = state.current;
    final itemIdx = progress?.itemIdx ?? current?.itemIdx ?? 0;
    final layer = progress?.layer ?? current?.layer ?? LessonLayer.l1;
    final mainAdvances = progress?.mainAdvances ?? 0;
    return mainAdvances * 100000 +
        itemIdx * 1000 +
        layer.value * 100 +
        state.attempts.length;
  }

  List<CanonicalLearningEvent> _readEvents(String lessonLocalId) {
    final encoded = local.readEvents(lessonLocalId);
    if (encoded == null || encoded.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) {
        _recordIntegrityIssue(
          kind: StudentStateIntegrityKind.events,
          lessonLocalId: lessonLocalId,
          payload: encoded,
          code: 'STATE_EVENTS_SCHEMA_INVALID',
        );
        return const [];
      }
      return _dedupeEvents(
        decoded.whereType<Map>().map(
          (event) => CanonicalLearningEvent.fromJson(JsonMap.from(event)),
        ),
      );
    } catch (_) {
      _recordIntegrityIssue(
        kind: StudentStateIntegrityKind.events,
        lessonLocalId: lessonLocalId,
        payload: encoded,
        code: 'STATE_EVENTS_CORRUPTED',
      );
      return const [];
    }
  }

  List<CanonicalLearningEvent> _dedupeEvents(
    Iterable<CanonicalLearningEvent> events,
  ) {
    final byId = <String, CanonicalLearningEvent>{};
    for (final event in events) {
      if (event.eventId.trim().isEmpty) continue;
      byId.putIfAbsent(event.eventId, () => event);
    }
    final sorted = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  void _writeCanonicalEvent(CanonicalLearningEvent event) {
    final lessonLocalId = event.lessonLocalId;
    final events = [
      ...(_eventLog[lessonLocalId] ?? _readEvents(lessonLocalId)),
      event,
    ];
    final dedupedEvents = _dedupeEvents(events);
    _eventLog[lessonLocalId] = dedupedEvents;
    local.writeEvents(
      lessonLocalId,
      jsonEncode(dedupedEvents.map((e) => e.toJson()).toList()),
    );
    _verifyDurableOperation(lessonLocalId, 'write_events');
  }

  void _recordIntegrityIssue({
    required StudentStateIntegrityKind kind,
    required String lessonLocalId,
    required String payload,
    required String code,
  }) {
    final issue = StudentStateIntegrityIssue(
      kind: kind,
      lessonLocalId: lessonLocalId,
      code: code,
      payload: payload,
    );
    _integrityIssues.add(issue);
    final quarantine = local;
    if (quarantine is StudentStateQuarantineStorage) {
      (quarantine as StudentStateQuarantineStorage).quarantinePayload(
        kind: kind,
        lessonLocalId: lessonLocalId,
        payload: payload,
        code: code,
      );
    }
  }

  void _verifyDurableOperation(String lessonLocalId, String operation) {
    final durable = local;
    if (durable is! DurableStudentStateLocalStorage) {
      _lastPersistenceAudit = StudentStatePersistenceAudit(
        status: StudentStatePersistenceStatus.confirmed,
        operation: operation,
        lessonLocalId: lessonLocalId,
      );
      return;
    }
    _lastPersistenceAudit = StudentStatePersistenceAudit(
      status: StudentStatePersistenceStatus.pending,
      operation: operation,
      lessonLocalId: lessonLocalId,
    );
    final Future<void> verification = switch (operation) {
      'write_state' => durable.verifyLastStateWrite(),
      'write_events' => durable.verifyLastEventsWrite(),
      'delete' => durable.verifyLastDelete(),
      _ => Future<void>.value(),
    };
    verification
        .then((_) {
          _lastPersistenceAudit = StudentStatePersistenceAudit(
            status: StudentStatePersistenceStatus.confirmed,
            operation: operation,
            lessonLocalId: lessonLocalId,
          );
        })
        .catchError((Object error) {
          _lastPersistenceAudit = StudentStatePersistenceAudit(
            status: StudentStatePersistenceStatus.failed,
            operation: operation,
            lessonLocalId: lessonLocalId,
            code: error is StudentStateStorageException
                ? error.code
                : 'STATE_LOCAL_PERSIST_FAILED',
          );
        });
  }

  int _foundationRevision(StudentLearningState state) {
    final foundation = state.extra['foundation'] is Map
        ? JsonMap.from(state.extra['foundation'] as Map)
        : const <String, dynamic>{};
    return (foundation['revision'] as num?)?.toInt() ?? state.events.length;
  }

  StudentLearningState _stampFoundationRevision(
    StudentLearningState state,
    CanonicalLearningEvent event,
    int revision,
  ) {
    final foundation = state.extra['foundation'] is Map
        ? JsonMap.from(state.extra['foundation'] as Map)
        : <String, dynamic>{};
    return state.copyWith(
      extra: {
        ...state.extra,
        'foundation': {
          ...foundation,
          'revision': revision,
          'last_event_id': event.eventId,
          'last_event_type': event.type,
          'last_event_at': event.createdAt,
        },
      },
    );
  }

  StudentLearningState _applyKnownEvent(
    StudentLearningState state,
    CanonicalLearningEvent event,
  ) {
    if (event.type == 'IDENTITY_BOUND') {
      return state.copyWith(
        userId: event.userId ?? event.payload['user_id']?.toString(),
        extra: {
          ...state.extra,
          'identity': {
            ...event.payload,
            'bound_at': event.createdAt,
            'event_id': event.eventId,
          },
        },
      );
    }
    if (event.type == 'IDENTITY_DETACHED') {
      final identity = state.extra['identity'] is Map
          ? JsonMap.from(state.extra['identity'] as Map)
          : <String, dynamic>{};
      return state.copyWith(
        extra: {
          ...state.extra,
          'identity': {
            ...identity,
            'status': 'detached',
            'detached_at': event.createdAt,
            'detach_reason': event.payload['reason']?.toString(),
            'event_id': event.eventId,
          },
        },
      );
    }
    if (event.type == 'OBJECTIVE_SUBMITTED') {
      final objetivo = event.payload['objetivo']?.toString();
      final locale = SimLocaleContract.fromLegacyState(event.payload);
      return state.copyWith(
        localeContract: locale,
        profile: state.profile.copyWith(
          objetivo: objetivo,
          language: locale.learningLocale,
          stableLang: locale.explanationLanguage,
          extra: {...state.profile.extra, ...locale.toJson()},
        ),
      );
    }
    if (event.type == 'ANSWER_SUBMITTED') {
      final attempt = event.payload['attempt'];
      if (attempt is Map) {
        return state.copyWith(
          attempts: [
            ...state.attempts,
            LessonAttempt.fromJson(JsonMap.from(attempt)),
          ],
        );
      }
    }
    if (event.type == 'MASTERY_EVALUATED' ||
        event.type == 'MASTERY_EVIDENCE_EVALUATED') {
      final marker = event.payload['marker_id']?.toString();
      final status = event.payload['status']?.toString();
      if (marker == null || marker.isEmpty || status == null) return state;
      final truth = JsonMap.from(
        state.extra['truth'] is Map ? state.extra['truth'] as Map : const {},
      );
      final consolidation = JsonMap.from(
        truth['item_consolidation_status'] is Map
            ? truth['item_consolidation_status'] as Map
            : const {},
      );
      consolidation[marker] = status;
      final evidence = event.payload.containsKey('marker_id')
          ? [JsonMap.from(event.payload)]
          : state.truth.masteryEvidence;
      return state.copyWith(
        truth: state.truth.copyWith(
          masteryEvidence: evidence,
          itemConsolidationStatus: consolidation.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        ),
        extra: {
          ...state.extra,
          'truth': {
            ...truth,
            'mastery_evidence': evidence,
            'item_consolidation_status': consolidation,
          },
        },
      );
    }
    if (event.type == 'SYNC_STARTED' ||
        event.type == 'SYNC_COMPLETED' ||
        event.type == 'SYNC_FAILED') {
      final sync = state.extra['sync'] is Map
          ? JsonMap.from(state.extra['sync'] as Map)
          : <String, dynamic>{};
      final status =
          event.payload['status']?.toString() ??
          switch (event.type) {
            'SYNC_STARTED' => 'pending',
            'SYNC_COMPLETED' => 'synced',
            _ => 'failed',
          };
      return state.copyWith(
        extra: {
          ...state.extra,
          'sync': {
            ...sync,
            'status': status,
            'updated_at': event.createdAt,
            'event_id': event.eventId,
            if (event.payload['direction'] != null)
              'direction': event.payload['direction'],
            if (event.payload['error'] != null) 'error': event.payload['error'],
          },
        },
      );
    }
    return state;
  }

  static String _defaultId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'evt-$now';
  }
}
