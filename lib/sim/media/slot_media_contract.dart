import '../state/student_learning_state.dart';
import '../localization/sim_locale_contract.dart';

enum SlotMediaType { image, audio }

class SlotMediaContract {
  const SlotMediaContract({
    required this.lessonLocalId,
    required this.marker,
    required this.itemIdx,
    required this.layer,
    required this.mediaType,
    required this.status,
    required this.source,
    required this.createdAt,
    required this.cacheKey,
    this.localeContract,
    this.mediaTextLanguage,
    this.audioLanguage,
    this.targetLanguage,
    this.explanationLanguage,
    this.voice,
    this.speed,
    this.sourceVersion = 'slot-media.v2',
    this.legacyLocale = false,
    this.error,
  });

  final String lessonLocalId;
  final String marker;
  final int itemIdx;
  final LessonLayer layer;
  final SlotMediaType mediaType;
  final String status;
  final String source;
  final String createdAt;
  final String cacheKey;
  final SimLocaleContract? localeContract;
  final String? mediaTextLanguage;
  final String? audioLanguage;
  final String? targetLanguage;
  final String? explanationLanguage;
  final String? voice;
  final double? speed;
  final String sourceVersion;
  final bool legacyLocale;
  final JsonMap? error;

  bool matchesSlot({
    required String lessonLocalId,
    required String marker,
    required int itemIdx,
    required LessonLayer layer,
    required SlotMediaType mediaType,
  }) {
    return this.lessonLocalId == lessonLocalId &&
        this.marker == marker &&
        this.itemIdx == itemIdx &&
        this.layer == layer &&
        this.mediaType == mediaType;
  }

  bool get isReady => status == 'ready';

  bool get hasHumanError {
    final value = error?['human'] ?? error?['humanError'];
    return value != null && value.toString().trim().isNotEmpty;
  }

  JsonMap toJson() => {
    'lessonLocalId': lessonLocalId,
    'marker': marker,
    'itemIdx': itemIdx,
    'layer': layer.value,
    'mediaType': mediaType.name,
    'status': status,
    'source': source,
    'createdAt': createdAt,
    'cacheKey': cacheKey,
    if (localeContract != null) 'localeContract': localeContract!.toJson(),
    if (mediaTextLanguage != null) 'mediaTextLanguage': mediaTextLanguage,
    if (audioLanguage != null) 'audioLanguage': audioLanguage,
    if (targetLanguage != null) 'targetLanguage': targetLanguage,
    if (explanationLanguage != null) 'explanationLanguage': explanationLanguage,
    if (voice != null) 'voice': voice,
    if (speed != null) 'speed': speed,
    'sourceVersion': sourceVersion,
    if (legacyLocale) 'legacyLocale': true,
    if (error != null) 'error': error,
  };

  static SlotMediaContract fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('slot media ausente');
    }
    final json = raw.map((key, value) => MapEntry(key.toString(), value));
    final mediaType = switch (_text(json['mediaType'] ?? json['media_type'])) {
      'audio' => SlotMediaType.audio,
      'image' => SlotMediaType.image,
      _ => throw const FormatException('mediaType invalido'),
    };
    final layerValue = _requiredInt(json['layer'], 'layer');
    if (layerValue < 1 || layerValue > 3) {
      throw const FormatException('layer invalido');
    }
    final locale = json['localeContract'] is Map
        ? SimLocaleContract.fromJson(
            Map<String, dynamic>.from(json['localeContract'] as Map),
          )
        : null;
    final hasLocaleFields =
        locale != null ||
        _text(json['mediaTextLanguage']).isNotEmpty ||
        _text(json['audioLanguage']).isNotEmpty ||
        _text(json['targetLanguage']).isNotEmpty ||
        _text(json['explanationLanguage']).isNotEmpty;
    final slot = SlotMediaContract(
      lessonLocalId: _requiredText(json['lessonLocalId'], 'lessonLocalId'),
      marker: _requiredText(json['marker'], 'marker'),
      itemIdx: _requiredInt(json['itemIdx'], 'itemIdx'),
      layer: LessonLayerValue.fromValue(layerValue),
      mediaType: mediaType,
      status: _requiredText(json['status'], 'status'),
      source: _requiredText(json['source'], 'source'),
      createdAt: _requiredText(json['createdAt'], 'createdAt'),
      cacheKey: _requiredText(json['cacheKey'], 'cacheKey'),
      localeContract: locale,
      mediaTextLanguage: _optionalText(json['mediaTextLanguage']),
      audioLanguage: _optionalText(json['audioLanguage']),
      targetLanguage: _optionalText(json['targetLanguage']),
      explanationLanguage: _optionalText(json['explanationLanguage']),
      voice: _optionalText(json['voice']),
      speed: _optionalDouble(json['speed']),
      sourceVersion: _optionalText(json['sourceVersion']) ?? 'slot-media.v1',
      legacyLocale: json['legacyLocale'] == true || !hasLocaleFields,
      error: json['error'] is Map ? JsonMap.from(json['error'] as Map) : null,
    );
    if (slot.layer.value < 1) {
      throw const FormatException('layer invalido');
    }
    return slot;
  }
}

String slotMediaCacheKey({
  required String lessonLocalId,
  required String marker,
  required int itemIdx,
  required LessonLayer layer,
  required SlotMediaType mediaType,
  SimLocaleContract? localeContract,
  String? mediaTextLanguage,
  String? audioLanguage,
  String? targetLanguage,
  String? explanationLanguage,
  String? voice,
  double? speed,
  String? textHash,
  String? visualTextPolicy,
  String sourceVersion = 'slot-media.v2',
}) => [
  'slot-media',
  lessonLocalId,
  marker,
  'I$itemIdx',
  'L${layer.value}',
  mediaType.name,
  localeContract?.mediaIdentity(
        mediaTextLanguage: mediaTextLanguage,
        audioLanguage: audioLanguage,
        voice: voice,
        speed: speed,
        textHash: textHash,
        visualTextPolicy: visualTextPolicy,
        sourceVersion: sourceVersion,
      ) ??
      [
        'media-locale',
        'legacy',
        mediaTextLanguage ?? '-',
        audioLanguage ?? '-',
        targetLanguage ?? '-',
        explanationLanguage ?? '-',
        voice ?? '-',
        speed == null ? '-' : speed.toStringAsFixed(2),
        textHash ?? '-',
        visualTextPolicy ?? '-',
        sourceVersion,
      ].join(':'),
].join(':');

String mediaHumanError(SlotMediaType type) => type == SlotMediaType.audio
    ? 'Não foi possível carregar o áudio desta aula agora.'
    : 'Não foi possível carregar a imagem desta aula agora.';

String _text(Object? value) => (value ?? '').toString().trim();

String? _optionalText(Object? value) {
  final out = _text(value);
  return out.isEmpty ? null : out;
}

double? _optionalDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_text(value));
}

String _requiredText(Object? value, String field) {
  final out = _text(value);
  if (out.isEmpty) throw FormatException('$field obrigatorio');
  return out;
}

int _requiredInt(Object? value, String field) {
  final parsed = value is num ? value.toInt() : int.tryParse(_text(value));
  if (parsed == null || parsed < 0) throw FormatException('$field invalido');
  return parsed;
}
