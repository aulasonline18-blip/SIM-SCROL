import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../media/lesson_image_api_contract.dart';
import '../state/student_learning_state.dart';
import 'lesson_content_validator.dart';
import 'lesson_models.dart';

const String _kCacheKey = 'sim-lesson-text-cache-v1';
const int _kMaxWarmLessons = 15;
const int _kLessonTtlMs = 86400000; // 24h

class _CacheEntry {
  const _CacheEntry({required this.lesson, required this.savedAt});

  final CompleteLesson lesson;
  final int savedAt;
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
    this.hadMaterial = true,
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
      hadMaterial: json['hadMaterial'] != false,
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
    );
  }
}

class LessonMaterialCache {
  LessonMaterialCache({int? maxLessons, int? ttlMs})
    : maxLessons = maxLessons ?? _kMaxWarmLessons,
      ttlMs = ttlMs ?? _kLessonTtlMs;

  final int maxLessons;
  final int ttlMs;
  final Map<String, _CacheEntry> _memory = {};
  final Map<String, LessonColdCacheEntry> _cold = {};
  final Set<String> _protectedKeys = {};

  int get warmEntryCount => _memory.length;

  int get coldEntryCount => _cold.length;

  bool contains(String key) => peek(key) != null;

  List<String> get warmKeys => List.unmodifiable(_memory.keys);

  List<String> get coldKeys => List.unmodifiable(_cold.keys);

  LessonColdCacheEntry? coldEntry(String key) => _cold[key];

  // Deve ser chamado no boot antes de usar o cache.
  // Lê sim-lesson-text-cache-v1, descarta entradas expiradas, popula _memory.
  Future<void> hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hydrateFromPreferences(prefs);
    } catch (_) {}
  }

  void hydrateFromPreferences(SharedPreferences prefs) {
    final raw = prefs.getString(_kCacheKey);
    if (raw == null || raw.trim().isEmpty) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final root = JsonMap.from(decoded);
    final warmRaw = root['warm'] is Map ? root['warm'] as Map : root;
    final coldRaw = root['cold'] is Map ? root['cold'] as Map : const {};
    for (final entry in coldRaw.entries) {
      final key = entry.key.toString();
      final cold = LessonColdCacheEntry.fromJson(entry.value);
      if (cold != null && cold.hasValidatedLargeCurriculumPart) {
        _cold[key] = cold;
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in warmRaw.entries) {
      final key = entry.key as String;
      if (key == 'version' || key == 'warm' || key == 'cold') continue;
      final value = entry.value;
      if (value is! Map) continue;
      final savedAt = (value['savedAt'] as num?)?.toInt() ?? 0;
      final lessonRaw = value['lesson'];
      if (now - savedAt > ttlMs) {
        _rememberColdFromJson(key, value, savedAt);
        continue;
      }
      if (lessonRaw is! Map) continue;
      final lesson = _lessonFromJson(Map<String, dynamic>.from(lessonRaw));
      if (lesson == null) continue;
      _memory[key] = _CacheEntry(lesson: lesson, savedAt: savedAt);
      _rememberColdFromJson(key, value, savedAt);
    }
    _enforceWarmLimit(persist: false);
  }

  // Peek sem promover LRU — não altera ordem de evicção.
  CompleteLesson? peek(String key) {
    final entry = _memory[key];
    if (entry == null) return null;
    if (_isExpired(entry)) {
      _memory.remove(key);
      return null;
    }
    return entry.lesson;
  }

  CompleteLesson? peekCachedLesson(String key) => peek(key);

  // get promove LRU (remove e reinserida no final).
  CompleteLesson? get(String key) {
    final entry = _memory.remove(key);
    if (entry == null) return null;
    if (_isExpired(entry)) return null;
    _memory[key] = entry;
    return entry.lesson;
  }

  Future<CompleteLesson?> getCachedLesson(String key) async => get(key);

  void put(String key, CompleteLesson lesson) {
    _put(key, lesson);
  }

  bool putForParams(CompleteLessonParams params, CompleteLesson lesson) {
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
    _put(key, lesson, savedAt: savedAt);
    return true;
  }

  void _put(String key, CompleteLesson lesson, {int? savedAt}) {
    _memory.removeWhere((_, entry) => _isExpired(entry));
    _memory.remove(key);
    _memory[key] = _CacheEntry(
      lesson: lesson,
      savedAt: savedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    _enforceWarmLimit();
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
      Future(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final warm = <String, dynamic>{};
          for (final entry in _memory.entries) {
            warm[entry.key] = {
              'savedAt': entry.value.savedAt,
              'lesson': _lessonToJsonForCache(entry.value.lesson),
              if (_cold[entry.key] != null) 'cold': _cold[entry.key]!.toJson(),
            };
          }
          final payload = <String, dynamic>{
            'version': 2,
            'warm': warm,
            'cold': {
              for (final entry in _cold.entries)
                entry.key: entry.value.toJson(),
            },
          };
          await prefs.setString(_kCacheKey, jsonEncode(payload));
        } catch (_) {}
      }),
    );
  }

  bool _isExpired(_CacheEntry entry) {
    return DateTime.now().millisecondsSinceEpoch - entry.savedAt > ttlMs;
  }

  static Map<String, dynamic> _lessonToJsonForCache(CompleteLesson lesson) {
    return {
      'conteudo': lesson.conteudo.toJson(),
      'audioText': lesson.audioText,
      if (lesson.imagem != null && lesson.imagem!.trim().isNotEmpty)
        'imagem': lesson.imagem,
      if (lesson.imageMetadata != null && !lesson.imageMetadata!.isEmpty)
        'imageMetadata': lesson.imageMetadata!.toJson(),
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

  void _rememberColdFromJson(String key, Map value, int savedAt) {
    final cold = LessonColdCacheEntry.fromJson(value['cold']);
    if (cold != null && cold.hasValidatedLargeCurriculumPart) {
      _cold[key] = cold;
      return;
    }
    _cold.putIfAbsent(
      key,
      () => LessonColdCacheEntry(
        lessonKey: key,
        status: 'cold-index',
        savedAt: savedAt,
        hadMaterial: true,
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
