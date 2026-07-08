class GenerateLessonImageRequest {
  const GenerateLessonImageRequest({
    required this.prompt,
    required this.lessonKey,
    this.aspectRatio = '1:1',
  });

  final String prompt;
  final String lessonKey;
  final String aspectRatio;

  String get normalizedAspectRatio {
    const allowed = {'1:1', '16:9', '9:16', '4:3', '3:4'};
    return allowed.contains(aspectRatio) ? aspectRatio : '1:1';
  }

  GenerateLessonImageRequest normalized() => GenerateLessonImageRequest(
    prompt: prompt.trim().length > 4000
        ? prompt.trim().substring(0, 4000)
        : prompt.trim(),
    lessonKey: lessonKey.trim().length > 160
        ? lessonKey.trim().substring(0, 160)
        : lessonKey.trim(),
    aspectRatio: normalizedAspectRatio,
  );
}

class GenerateLessonImageResponse {
  const GenerateLessonImageResponse({
    required this.dataUrl,
    this.cacheKey,
    this.requestId,
    this.mimeType,
    this.provider,
    this.model,
    this.charged,
    this.cacheHit,
    this.retryable,
  });

  final String dataUrl;
  final String? cacheKey;
  final String? requestId;
  final String? mimeType;
  final String? provider;
  final String? model;
  final bool? charged;
  final bool? cacheHit;
  final bool? retryable;

  LessonImageGenerationMetadata toMetadata() {
    return LessonImageGenerationMetadata(
      cacheKey: cacheKey,
      requestId: requestId,
      mimeType: mimeType,
      provider: provider,
      model: model,
      charged: charged,
      cacheHit: cacheHit,
      retryable: retryable,
    );
  }
}

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
      createdAt == null;

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
    );
    return metadata.isEmpty ? null : metadata;
  }
}

const String lessonImageModelPath = 'google/nano-banana-pro';
const int lessonImageRequestTimeoutMs = 125000;
const int lessonImageRateLimitWindowMs = 60000;
const int lessonImageRateLimitMaxPerWindow = 10;
const int lessonImageCircuitFailThreshold = 5;
const int lessonImageCircuitOpenMs = 60000;
