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
  const FakeVisualRouterClient({this.svgDataUrl, this.displayDataUrl});

  final String? svgDataUrl;
  final String? displayDataUrl;

  @override
  Future<VisualN3Result> routeVisual({
    required VisualN2Result n2,
    String? topic,
    String? visualType,
    String? imagePrompt,
    List<String> keyElements = const [],
    String? pedagogicalNeed,
    String? highlightFocus,
    String? complexity,
    String? stableLang,
    String? svgPayload,
    Object? mathTemplate,
    Map<String, dynamic>? visualTrigger,
  }) async {
    if (svgDataUrl != null || displayDataUrl != null) {
      return VisualN3Result(
        verdict: VisualVerdict.svg,
        reason: 'TEST_N3_SVG',
        svgDataUrl: svgDataUrl,
        displayDataUrl: displayDataUrl,
      );
    }
    return const VisualN3Result(
      verdict: VisualVerdict.ai,
      reason: 'TEST_N3_AI',
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
    visualRouterClient: FakeVisualRouterClient(
      svgDataUrl: svgDataUrl,
      displayDataUrl: displayDataUrl,
    ),
  );
}
