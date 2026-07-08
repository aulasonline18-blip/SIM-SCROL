import '../state/student_learning_state.dart';

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
}) => [
  'slot-media',
  lessonLocalId,
  marker,
  'I$itemIdx',
  'L${layer.value}',
  mediaType.name,
].join(':');

String mediaHumanError(SlotMediaType type) => type == SlotMediaType.audio
    ? 'Não foi possível carregar o áudio desta aula agora.'
    : 'Não foi possível carregar a imagem desta aula agora.';

String _text(Object? value) => (value ?? '').toString().trim();

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
