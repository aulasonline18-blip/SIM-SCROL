class LessonImageGenerationMetadata {
  const LessonImageGenerationMetadata({
    this.cacheKey,
    this.requestId,
    this.mimeType,
    this.provider,
    this.model,
    this.charged,
    this.cacheHit,
    this.retryable,
    this.lessonLocalId,
    this.marker,
    this.itemIdx,
    this.layer,
    this.mediaType,
    this.status,
    this.source,
    this.createdAt,
    this.n2Reason,
    this.n3Reason,
  });

  final String? cacheKey;
  final String? requestId;
  final String? mimeType;
  final String? provider;
  final String? model;
  final bool? charged;
  final bool? cacheHit;
  final bool? retryable;
  final String? lessonLocalId;
  final String? marker;
  final int? itemIdx;
  final int? layer;
  final String? mediaType;
  final String? status;
  final String? source;
  final String? createdAt;
  final String? n2Reason;
  final String? n3Reason;

  bool get isEmpty =>
      cacheKey == null &&
      requestId == null &&
      mimeType == null &&
      provider == null &&
      model == null &&
      charged == null &&
      cacheHit == null &&
      retryable == null &&
      lessonLocalId == null &&
      marker == null &&
      itemIdx == null &&
      layer == null &&
      mediaType == null &&
      status == null &&
      source == null &&
      createdAt == null &&
      n2Reason == null &&
      n3Reason == null;

  Map<String, Object?> toJson() => {
    'cacheKey': cacheKey,
    'requestId': requestId,
    'mimeType': mimeType,
    'provider': provider,
    'model': model,
    'charged': charged,
    'cacheHit': cacheHit,
    'retryable': retryable,
    'lessonLocalId': lessonLocalId,
    'marker': marker,
    'itemIdx': itemIdx,
    'layer': layer,
    'mediaType': mediaType,
    'status': status,
    'source': source,
    'createdAt': createdAt,
    'n2Reason': n2Reason,
    'n3Reason': n3Reason,
  };

  LessonImageGenerationMetadata withSlot({
    required String lessonLocalId,
    required String marker,
    required int itemIdx,
    required int layer,
    required String cacheKey,
    String status = 'ready',
    String mediaType = 'image',
    String? source,
    String? createdAt,
  }) {
    return LessonImageGenerationMetadata(
      cacheKey: cacheKey,
      requestId: requestId,
      mimeType: mimeType,
      provider: provider,
      model: model,
      charged: charged,
      cacheHit: cacheHit,
      retryable: retryable,
      lessonLocalId: lessonLocalId,
      marker: marker,
      itemIdx: itemIdx,
      layer: layer,
      mediaType: mediaType,
      status: status,
      source: source ?? this.source ?? provider,
      createdAt: createdAt ?? this.createdAt,
      n2Reason: n2Reason,
      n3Reason: n3Reason,
    );
  }

  static LessonImageGenerationMetadata? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final metadata = LessonImageGenerationMetadata(
      cacheKey: raw['cacheKey']?.toString(),
      requestId: raw['requestId']?.toString(),
      mimeType: raw['mimeType']?.toString(),
      provider: raw['provider']?.toString(),
      model: raw['model']?.toString(),
      charged: raw['charged'] is bool ? raw['charged'] as bool : null,
      cacheHit: raw['cacheHit'] is bool ? raw['cacheHit'] as bool : null,
      retryable: raw['retryable'] is bool ? raw['retryable'] as bool : null,
      lessonLocalId: raw['lessonLocalId']?.toString(),
      marker: raw['marker']?.toString(),
      itemIdx: raw['itemIdx'] is num ? (raw['itemIdx'] as num).toInt() : null,
      layer: raw['layer'] is num ? (raw['layer'] as num).toInt() : null,
      mediaType: raw['mediaType']?.toString(),
      status: raw['status']?.toString(),
      source: raw['source']?.toString(),
      createdAt: raw['createdAt']?.toString(),
      n2Reason: raw['n2Reason']?.toString(),
      n3Reason: raw['n3Reason']?.toString(),
    );
    return metadata.isEmpty ? null : metadata;
  }
}
