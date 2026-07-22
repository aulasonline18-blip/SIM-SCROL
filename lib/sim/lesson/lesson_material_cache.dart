import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../cache/secure_lesson_cache_store.dart';
import '../localization/sim_locale_contract.dart';
import '../media/lesson_image_api_contract.dart';
import '../state/student_learning_state.dart';
import 'lesson_content_validator.dart';
import 'lesson_models.dart';

const String _kCacheKey = 'sim-lesson-text-cache-v1';
const int _kMaxWarmLessons = 15;
const int _kLessonTtlMs = 604800000; // 7 dias

class _CacheEntry {
  const _CacheEntry({
    required this.lesson,
    required this.savedAt,
    required this.lastAccessedAt,
  });

  final CompleteLesson lesson;
  final int savedAt;
  final int lastAccessedAt;
}

class LessonMaterialCacheAudit {
  const LessonMaterialCacheAudit({
    required this.ok,
    required this.code,
    this.details = const {},
  });

  final bool ok;
  final String code;
  final JsonMap details;
}

class LessonMaterialCacheException implements Exception {
  const LessonMaterialCacheException(this.code);

  final String code;

  @override
  String toString() => code;
}

class LessonColdCacheEntry {
  const LessonColdCacheEntry({
    required this.lessonKey,
    this.lessonLocalId,
    this.itemIdx,
    this.marker,
    this.layer,
    this.rootLessonLocalId,
    this.partLessonLocalId,
    this.partNumber,
    this.globalItemNumber,
    this.localItemIndex,
    this.status = 'cold-index',
    required this.savedAt,
    this.hadMaterial = false,
  });

  final String lessonKey;
  final String? lessonLocalId;
  final int? itemIdx;
  final String? marker;
  final LessonLayer? layer;
  final String? rootLessonLocalId;
  final String? partLessonLocalId;
  final int? partNumber;
  final int? globalItemNumber;
  final int? localItemIndex;
  final String status;
  final int savedAt;
  final bool hadMaterial;

  bool get hasValidatedLargeCurriculumPart {
    if ((partNumber ?? 1) <= 1) return true;
    return rootLessonLocalId != null &&
        partLessonLocalId != null &&
        globalItemNumber != null &&
        localItemIndex != null;
  }

  JsonMap toJson() => {
    'lessonKey': lessonKey,
    if (lessonLocalId != null) 'lessonLocalId': lessonLocalId,
    if (itemIdx != null) 'itemIdx': itemIdx,
    if (marker != null) 'marker': marker,
    if (layer != null) 'layer': layer!.value,
    if (rootLessonLocalId != null) 'rootLessonLocalId': rootLessonLocalId,
    if (partLessonLocalId != null) 'partLessonLocalId': partLessonLocalId,
    if (partNumber != null) 'partNumber': partNumber,
    if (globalItemNumber != null) 'globalItemNumber': globalItemNumber,
    if (localItemIndex != null) 'localItemIndex': localItemIndex,
    'status': status,
    'savedAt': savedAt,
    'hadMaterial': hadMaterial,
  };

  static LessonColdCacheEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = JsonMap.from(raw);
    final lessonKey = _stringOrNull(json['lessonKey']);
    if (lessonKey == null) return null;
    return LessonColdCacheEntry(
      lessonKey: lessonKey,
      lessonLocalId: _stringOrNull(json['lessonLocalId']),
      itemIdx: _intOrNull(json['itemIdx']),
      marker: _stringOrNull(json['marker']),
      layer: _layerOrNull(json['layer']),
      rootLessonLocalId: _stringOrNull(json['rootLessonLocalId']),
      partLessonLocalId: _stringOrNull(json['partLessonLocalId']),
      partNumber: _intOrNull(json['partNumber']),
      globalItemNumber: _intOrNull(json['globalItemNumber']),
      localItemIndex: _intOrNull(json['localItemIndex']),
      status: _stringOrNull(json['status']) ?? 'cold-index',
      savedAt: _intOrNull(json['savedAt']) ?? 0,
      hadMaterial: json['hadMaterial'] == true,
    );
  }

  static LessonColdCacheEntry fromParams({
    required String lessonKey,
    required CompleteLessonParams params,
    required int savedAt,
    String status = 'warm-index',
  }) {
    final item = _curriculumItemFor(params);
    return LessonColdCacheEntry(
      lessonKey: lessonKey,
      lessonLocalId: params.lessonLocalId,
      itemIdx: params.itemIdx,
      marker: params.marker ?? _stringOrNull(item?['marker']),
      layer: params.layer,
      rootLessonLocalId: _firstString([
        item?['rootLessonLocalId'],
        item?['root_lesson_local_id'],
        params.pedagogicalEnvelope['rootLessonLocalId'],
        params.pedagogicalEnvelope['root_lesson_local_id'],
      ]),
      partLessonLocalId: _firstString([
        item?['partLessonLocalId'],
        item?['part_lesson_local_id'],
        params.pedagogicalEnvelope['partLessonLocalId'],
        params.pedagogicalEnvelope['part_lesson_local_id'],
      ]),
      partNumber: _firstInt([
        item?['partNumber'],
        item?['part_number'],
        params.pedagogicalEnvelope['partNumber'],
        params.pedagogicalEnvelope['part_number'],
      ]),
      globalItemNumber: _firstInt([
        item?['globalItemNumber'],
        item?['global_item_number'],
        params.pedagogicalEnvelope['globalItemNumber'],
        params.pedagogicalEnvelope['global_item_number'],
      ]),
      localItemIndex: _firstInt([
        item?['localItemIndex'],
        item?['local_item_index'],
        params.pedagogicalEnvelope['localItemIndex'],
        params.pedagogicalEnvelope['local_item_index'],
      ]),
      status: status,
      savedAt: savedAt,
      hadMaterial: true,
    );
  }
}

class LessonMaterialCache {
  LessonMaterialCache({int? maxLessons, int? ttlMs, LessonCacheStore? store})
    : maxLessons = maxLessons ?? _kMaxWarmLessons,
      ttlMs = ttlMs ?? _kLessonTtlMs,
      _store = store ?? EncryptedFileLessonCacheStore();

  final int maxLessons;
  final int ttlMs;
  final LessonCacheStore _store;
  final Map<String, _CacheEntry> _memory = {};
  final Map<String, LessonColdCacheEntry> _cold = {};
  final Set<String> _protectedKeys = {};
  LessonMaterialCacheAudit _lastAudit = const LessonMaterialCacheAudit(
    ok: true,
    code: 'CACHE_IDLE',
  );

  LessonMaterialCacheAudit get lastAudit => _lastAudit;

  int get warmEntryCount => _memory.length;

  int get coldEntryCount => _cold.length;

  bool contains(String key) => peek(key) != null;

  List<String> get warmKeys => List.unmodifiable(_memory.keys);

  List<String> get coldKeys => List.unmodifiable(_cold.keys);

  LessonColdCacheEntry? coldEntry(String key) => _cold[key];

  // Deve ser chamado no boot antes de usar o cache.
  // Le o arquivo criptografado vigente; SharedPreferences e apenas migracao legado.
  Future<LessonMaterialCacheAudit> hydrate() async {
    try {
      final raw = await _store.read();
      if (raw == null || raw.trim().isEmpty) {
        final legacyPrefs = await SharedPreferences.getInstance();
        final legacyAudit = hydrateFromPreferences(legacyPrefs);
        if (legacyAudit.ok && _memory.isNotEmpty) {
          await persistNow();
          await legacyPrefs.remove(_kCacheKey);
          return _audit(true, 'CACHE_MIGRATED_TO_ENCRYPTED_STORE');
        }
        return legacyAudit;
      }
      return hydrateFromJson(raw);
    } on LessonCacheStoreException catch (error) {
      return _audit(false, error.code);
    } catch (_) {
      return _audit(false, 'CACHE_HYDRATE_FAILED');
    }
  }

  LessonMaterialCacheAudit hydrateFromPreferences(SharedPreferences prefs) {
    final raw = prefs.getString(_kCacheKey);
    if (raw == null || raw.trim().isEmpty) {
      return _audit(true, 'CACHE_EMPTY');
    }
    return hydrateFromJson(raw);
  }

  LessonMaterialCacheAudit hydrateFromJson(String raw) {
    if (raw.trim().isEmpty) {
      return _audit(true, 'CACHE_EMPTY');
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return _audit(false, 'CACHE_CORRUPTED_JSON');
    }
    if (decoded is! Map) return _audit(false, 'CACHE_CORRUPTED_SHAPE');
    final root = JsonMap.from(decoded);
    final warmRaw = root['warm'] is Map ? root['warm'] as Map : root;
    final coldRaw = root['cold'] is Map ? root['cold'] as Map : const {};
    final now = DateTime.now().millisecondsSinceEpoch;
    var rejectedSchema = 0;
    var rejectedExpired = 0;
    var rejectedContent = 0;
    for (final entry in coldRaw.entries) {
      final key = entry.key.toString();
      final cold = LessonColdCacheEntry.fromJson(entry.value);
      if (cold != null &&
          cold.hasValidatedLargeCurriculumPart &&
          now - cold.savedAt <= ttlMs) {
        _cold[key] = cold;
      } else if (cold == null) {
        rejectedSchema += 1;
      } else if (!cold.hasValidatedLargeCurriculumPart) {
        rejectedSchema += 1;
      } else {
        rejectedExpired += 1;
      }
    }
    for (final entry in warmRaw.entries) {
      final key = entry.key as String;
      if (key == 'version' || key == 'warm' || key == 'cold') continue;
      final value = entry.value;
      if (value is! Map) {
        rejectedSchema += 1;
        continue;
      }
      final savedAt = (value['savedAt'] as num?)?.toInt() ?? 0;
      final lastAccessedAt =
          (value['lastAccessedAt'] as num?)?.toInt() ?? savedAt;
      final lessonRaw = value['lesson'];
      if (now - lastAccessedAt > ttlMs) {
        _rememberColdFromJson(key, value, savedAt, status: 'cold-index');
        rejectedExpired += 1;
        continue;
      }
      if (lessonRaw is! Map) {
        rejectedSchema += 1;
        continue;
      }
      final lesson = _lessonFromJson(Map<String, dynamic>.from(lessonRaw));
      if (lesson == null) {
        if (lessonRaw['conteudo'] is Map) {
          rejectedContent += 1;
        } else {
          rejectedSchema += 1;
        }
        continue;
      }
      if (!_hasUsableLessonMaterial(lesson)) {
        rejectedContent += 1;
        continue;
      }
      _memory[key] = _CacheEntry(
        lesson: lesson,
        savedAt: savedAt,
        lastAccessedAt: lastAccessedAt,
      );
      _rememberColdFromJson(key, value, savedAt);
    }
    _enforceWarmLimit(persist: false);
    return _audit(
      true,
      'CACHE_HYDRATED',
      details: {
        'warmEntries': _memory.length,
        'coldEntries': _cold.length,
        'rejectedSchema': rejectedSchema,
        'rejectedExpired': rejectedExpired,
        'rejectedContent': rejectedContent,
      },
    );
  }

  // Peek sem promover LRU — não altera ordem de evicção.
  CompleteLesson? peek(String key) {
    final entry = _memory[key];
    if (entry == null) {
      _removeWarmOnlyColdIndex(key);
      return null;
    }
    if (_isExpired(entry)) {
      _demoteWarmEntry(key, entry);
      _memory.remove(key);
      _persist();
      return null;
    }
    return entry.lesson;
  }

  CompleteLesson? peekCachedLesson(String key) => peek(key);

  // get promove LRU (remove e reinserida no final).
  CompleteLesson? get(String key) {
    final entry = _memory.remove(key);
    if (entry == null) {
      _removeWarmOnlyColdIndex(key);
      return null;
    }
    if (_isExpired(entry)) {
      _demoteWarmEntry(key, entry);
      _persist();
      return null;
    }
    _memory[key] = _CacheEntry(
      lesson: entry.lesson,
      savedAt: entry.savedAt,
      lastAccessedAt: DateTime.now().millisecondsSinceEpoch,
    );
    return entry.lesson;
  }

  Future<CompleteLesson?> getCachedLesson(String key) async => get(key);

  void touch(String key) {
    final entry = _memory[key];
    if (entry == null || _isExpired(entry)) return;
    _memory[key] = _CacheEntry(
      lesson: entry.lesson,
      savedAt: entry.savedAt,
      lastAccessedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _persist();
  }

  void put(String key, CompleteLesson lesson) {
    _put(key, lesson);
  }

  bool putForParams(CompleteLessonParams params, CompleteLesson lesson) {
    if (!_hasUsableLessonMaterial(lesson)) return false;
    final lessonWithLocale = lesson.localeContract == null
        ? lesson.copyWith(localeContract: params.effectiveLocaleContract)
        : lesson;
    final key = lessonKeyFor(params);
    final savedAt = DateTime.now().millisecondsSinceEpoch;
    final cold = LessonColdCacheEntry.fromParams(
      lessonKey: key,
      params: params,
      savedAt: savedAt,
      status: 'warm-index',
    );
    if (!cold.hasValidatedLargeCurriculumPart) return false;
    _cold[key] = cold;
    _put(key, lessonWithLocale, savedAt: savedAt);
    return true;
  }

  void _put(String key, CompleteLesson lesson, {int? savedAt}) {
    if (!_hasUsableLessonMaterial(lesson)) return;
    for (final entry in List<MapEntry<String, _CacheEntry>>.from(
      _memory.entries,
    )) {
      if (_isExpired(entry.value)) {
        _demoteWarmEntry(entry.key, entry.value);
        _memory.remove(entry.key);
      }
    }
    _memory.remove(key);
    final timestamp = savedAt ?? DateTime.now().millisecondsSinceEpoch;
    _memory[key] = _CacheEntry(
      lesson: lesson,
      savedAt: timestamp,
      lastAccessedAt: timestamp,
    );
    _enforceWarmLimit();
  }

  void removeForLesson(String lessonLocalId) {
    _memory.removeWhere(
      (key, _) =>
          key.split(':').contains(lessonLocalId) ||
          _cold[key]?.lessonLocalId == lessonLocalId,
    );
    _cold.removeWhere(
      (key, entry) =>
          key.split(':').contains(lessonLocalId) ||
          entry.lessonLocalId == lessonLocalId,
    );
    _persist();
  }

  void protectWarmKeys(Iterable<String> keys) {
    _protectedKeys
      ..clear()
      ..addAll(keys.where((key) => key.trim().isNotEmpty));
    _enforceWarmLimit();
  }

  void trimWarmCache({
    Iterable<String> protectedKeys = const [],
    int? maxWarmLessons,
  }) {
    _protectedKeys
      ..clear()
      ..addAll(protectedKeys.where((key) => key.trim().isNotEmpty));
    _enforceWarmLimit(maxWarmLessons: maxWarmLessons);
  }

  void _enforceWarmLimit({int? maxWarmLessons, bool persist = true}) {
    final limit = maxWarmLessons ?? maxLessons;
    for (final entry in List<MapEntry<String, _CacheEntry>>.from(
      _memory.entries,
    )) {
      if (_isExpired(entry.value) && !_protectedKeys.contains(entry.key)) {
        _demoteWarmEntry(entry.key, entry.value);
        _memory.remove(entry.key);
      }
    }

    if (_memory.length > limit) {
      for (final key in List<String>.from(_memory.keys)) {
        if (_memory.length <= limit) break;
        if (_protectedKeys.contains(key)) continue;
        final entry = _memory[key];
        if (entry == null || entry.lesson.imagem == null) continue;
        _demoteWarmEntry(key, entry);
        _memory[key] = _CacheEntry(
          lesson: entry.lesson.copyWith(imagem: null),
          savedAt: entry.savedAt,
          lastAccessedAt: entry.lastAccessedAt,
        );
      }
    }

    while (_memory.length > limit) {
      final removable = _memory.keys.firstWhere(
        (key) => !_protectedKeys.contains(key),
        orElse: () => _memory.keys.first,
      );
      final entry = _memory[removable];
      if (entry != null) _demoteWarmEntry(removable, entry);
      _memory.remove(removable);
    }
    if (persist) {
      _persist();
    }
  }

  // O cache persiste texto validado e metadados; mídia pesada pode ser removida pela autolimpeza.
  void _persist() {
    unawaited(
      persistNow().catchError((_) => _audit(false, 'CACHE_PERSIST_FAILED')),
    );
  }

  Future<LessonMaterialCacheAudit> persistNow() async {
    try {
      final payload = _cachePayload();
      final encoded = jsonEncode(payload);
      await _store.write(encoded);
      return _audit(true, 'CACHE_PERSISTED');
    } catch (_) {
      return _audit(false, 'CACHE_PERSIST_FAILED');
    }
  }

  JsonMap _cachePayload() {
    final warm = <String, dynamic>{};
    for (final entry in _memory.entries) {
      warm[entry.key] = {
        'savedAt': entry.value.savedAt,
        'lastAccessedAt': entry.value.lastAccessedAt,
        'lesson': _lessonToJsonForCache(entry.value.lesson),
        if (_cold[entry.key] != null) 'cold': _cold[entry.key]!.toJson(),
      };
    }
    return {
      'version': 2,
      'warm': warm,
      'cold': {
        for (final entry in _cold.entries) entry.key: entry.value.toJson(),
      },
    };
  }

  LessonMaterialCacheAudit _audit(
    bool ok,
    String code, {
    JsonMap details = const {},
  }) {
    return _lastAudit = LessonMaterialCacheAudit(
      ok: ok,
      code: code,
      details: details,
    );
  }

  bool _isExpired(_CacheEntry entry) {
    return DateTime.now().millisecondsSinceEpoch - entry.lastAccessedAt > ttlMs;
  }

  void _removeWarmOnlyColdIndex(String key) {
    final cold = _cold[key];
    if (cold == null) return;
    if (cold.status == 'warm-index') {
      _cold.remove(key);
      _persist();
    }
  }

  static bool _hasUsableLessonMaterial(CompleteLesson lesson) {
    final content = lesson.conteudo;
    return content.explanation.trim().isNotEmpty &&
        content.question.trim().isNotEmpty &&
        content.options[AnswerLetter.A]?.trim().isNotEmpty == true &&
        content.options[AnswerLetter.B]?.trim().isNotEmpty == true &&
        content.options[AnswerLetter.C]?.trim().isNotEmpty == true;
  }

  static Map<String, dynamic> _lessonToJsonForCache(CompleteLesson lesson) {
    return {
      'conteudo': lesson.conteudo.toJson(),
      'audioText': lesson.audioText,
      if (lesson.imagem != null && lesson.imagem!.trim().isNotEmpty)
        'imagem': lesson.imagem,
      if (lesson.imageMetadata != null && !lesson.imageMetadata!.isEmpty)
        'imageMetadata': lesson.imageMetadata!.toJson(),
      if (lesson.localeContract != null)
        'localeContract': lesson.localeContract!.toJson(),
    };
  }

  static CompleteLesson? _lessonFromJson(Map<String, dynamic> json) {
    try {
      final conteudoRaw = json['conteudo'];
      if (conteudoRaw is! Map) return null;
      final conteudo = _lessonContentFromJson(
        Map<String, dynamic>.from(conteudoRaw),
      );
      if (conteudo == null) return null;
      return CompleteLesson(
        conteudo: conteudo,
        imagem: _stringOrNull(json['imagem']),
        audioText: json['audioText'] as String? ?? conteudo.audioText,
        imageMetadata: LessonImageGenerationMetadata.fromJson(
          json['imageMetadata'],
        ),
        localeContract: json['localeContract'] is Map
            ? SimLocaleContract.fromJson(
                Map<String, dynamic>.from(json['localeContract'] as Map),
              )
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  static LessonContent? _lessonContentFromJson(Map<String, dynamic> json) {
    try {
      return validatedLessonContentFromJson(json);
    } catch (_) {
      return null;
    }
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString();
    return text == null || text.trim().isEmpty ? null : text;
  }

  void _demoteWarmEntry(String key, _CacheEntry entry) {
    final existing = _cold[key];
    _cold[key] = existing?.toJson().isNotEmpty == true
        ? LessonColdCacheEntry(
            lessonKey: existing!.lessonKey,
            lessonLocalId: existing.lessonLocalId,
            itemIdx: existing.itemIdx,
            marker: existing.marker,
            layer: existing.layer,
            rootLessonLocalId: existing.rootLessonLocalId,
            partLessonLocalId: existing.partLessonLocalId,
            partNumber: existing.partNumber,
            globalItemNumber: existing.globalItemNumber,
            localItemIndex: existing.localItemIndex,
            status: 'cold-index',
            savedAt: entry.savedAt,
            hadMaterial: true,
          )
        : LessonColdCacheEntry(
            lessonKey: key,
            status: 'cold-index',
            savedAt: entry.savedAt,
            hadMaterial: true,
          );
  }

  void _rememberColdFromJson(
    String key,
    Map value,
    int savedAt, {
    String status = 'cold-index',
  }) {
    final cold = LessonColdCacheEntry.fromJson(value['cold']);
    if (cold != null && cold.hasValidatedLargeCurriculumPart) {
      _cold[key] = LessonColdCacheEntry(
        lessonKey: cold.lessonKey,
        lessonLocalId: cold.lessonLocalId,
        itemIdx: cold.itemIdx,
        marker: cold.marker,
        layer: cold.layer,
        rootLessonLocalId: cold.rootLessonLocalId,
        partLessonLocalId: cold.partLessonLocalId,
        partNumber: cold.partNumber,
        globalItemNumber: cold.globalItemNumber,
        localItemIndex: cold.localItemIndex,
        status: status,
        savedAt: cold.savedAt,
        hadMaterial: cold.hadMaterial,
      );
      return;
    }
    _cold.putIfAbsent(
      key,
      () => LessonColdCacheEntry(
        lessonKey: key,
        status: status,
        savedAt: savedAt,
        hadMaterial: false,
      ),
    );
  }
}

JsonMap? _curriculumItemFor(CompleteLessonParams params) {
  final idx = params.itemIdx;
  if (idx == null || idx < 0 || idx >= params.curriculumItems.length) {
    return null;
  }
  return params.curriculumItems[idx];
}

String? _firstString(List<Object?> values) {
  for (final value in values) {
    final text = _stringOrNull(value);
    if (text != null) return text;
  }
  return null;
}

int? _firstInt(List<Object?> values) {
  for (final value in values) {
    final parsed = _intOrNull(value);
    if (parsed != null) return parsed;
  }
  return null;
}

int? _intOrNull(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

LessonLayer? _layerOrNull(Object? value) {
  final parsed = _intOrNull(value);
  if (parsed == null || parsed < 1 || parsed > 3) return null;
  return LessonLayerValue.fromValue(parsed);
}

String? _stringOrNull(Object? value) {
  final text = value?.toString();
  return text == null || text.trim().isEmpty ? null : text.trim();
}
