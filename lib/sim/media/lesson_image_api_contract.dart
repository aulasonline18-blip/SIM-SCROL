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
  });

  final String? cacheKey;
  final String? requestId;
  final String? mimeType;
  final String? provider;
  final String? model;
  final bool? charged;
  final bool? cacheHit;
  final bool? retryable;

  bool get isEmpty =>
      cacheKey == null &&
      requestId == null &&
      mimeType == null &&
      provider == null &&
      model == null &&
      charged == null &&
      cacheHit == null &&
      retryable == null;

  Map<String, Object?> toJson() => {
    'cacheKey': cacheKey,
    'requestId': requestId,
    'mimeType': mimeType,
    'provider': provider,
    'model': model,
    'charged': charged,
    'cacheHit': cacheHit,
    'retryable': retryable,
  };

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
