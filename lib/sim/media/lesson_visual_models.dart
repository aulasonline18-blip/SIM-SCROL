class FixedBubbleModel {
  const FixedBubbleModel({
    this.visible = true,
    this.size = 40,
    this.bottom = 24,
    this.pulsing = true,
  });

  final bool visible;
  final double size;
  final double bottom;
  final bool pulsing;
}

class LessonAvatarModel {
  const LessonAvatarModel({required this.speaking});

  final bool speaking;
  double get width => 96;
  double get height => 116;
  double get circleSize => 80;
  double get barProgress => speaking ? 1 : 0.28;
}

bool isUsableRasterImageDataUrl(Object? value) {
  if (value is! String) return false;
  return RegExp(
    r'^data:image/(png|jpeg|jpg|webp);base64,',
    caseSensitive: false,
  ).hasMatch(value.trim());
}

enum ServerVisualRouteVerdict { image, noImage, missingRaster }

class ServerVisualRouteResult {
  const ServerVisualRouteResult({
    required this.verdict,
    required this.reason,
    this.readyImageDataUrl,
    this.transportFailed = false,
    this.statusCode,
    this.requestId,
    this.retryable = false,
    this.errorCode,
  });

  final ServerVisualRouteVerdict verdict;
  final String reason;
  final String? readyImageDataUrl;
  final bool transportFailed;
  final int? statusCode;
  final String? requestId;
  final bool retryable;
  final String? errorCode;
}

abstract interface class LessonVisualRouterClient {
  Future<ServerVisualRouteResult> routeVisual({
    String? stableLang,
    required Map<String, dynamic> visualTrigger,
  });
}
