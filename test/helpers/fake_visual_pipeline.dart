import 'package:sim_mobile/sim/media/lesson_visual_pipeline.dart';

class FakeNoopImageClient implements LessonImageClient {
  const FakeNoopImageClient({this.imageDataUrl, this.onGenerate});

  final String? imageDataUrl;
  final void Function()? onGenerate;

  @override
  Future<String?> generateLessonImage({
    required String prompt,
    required String lessonKey,
    String aspectRatio = '1:1',
    String? acceptedOfferId,
    String? idempotencyKey,
    Map<String, dynamic>? visualTrigger,
    Map<String, dynamic>? lessonContext,
  }) async {
    onGenerate?.call();
    return imageDataUrl;
  }
}

class FakeVisualRouterClient implements LessonVisualRouterClient {
  const FakeVisualRouterClient({this.displayDataUrl});

  final String? displayDataUrl;

  @override
  Future<ServerVisualRouteResult> routeVisual({
    String? stableLang,
    required Map<String, dynamic> visualTrigger,
  }) async {
    if (displayDataUrl != null) {
      return ServerVisualRouteResult(
        verdict: ServerVisualRouteVerdict.image,
        reason: 'TEST_SERVER_IMAGE',
        readyImageDataUrl: displayDataUrl,
      );
    }
    return const ServerVisualRouteResult(
      verdict: ServerVisualRouteVerdict.missingRaster,
      reason: 'TEST_SERVER_MISSING_RASTER',
    );
  }
}

LessonVisualPipeline fakeVisualPipeline({
  String? svgDataUrl,
  String? displayDataUrl,
  String? paidImageDataUrl,
  void Function()? onPaidImageGenerate,
}) {
  return LessonVisualPipeline(
    imageClient: FakeNoopImageClient(
      imageDataUrl: paidImageDataUrl,
      onGenerate: onPaidImageGenerate,
    ),
    visualRouterClient: FakeVisualRouterClient(displayDataUrl: displayDataUrl),
  );
}
