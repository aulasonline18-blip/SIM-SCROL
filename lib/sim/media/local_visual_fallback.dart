import 'software_render_catalog.dart';
import 'visual_router_n2.dart';
import 'blueprint_prompt.dart';

/// Last zero-cost renderer before paid image offer.
///
/// The public API stays small because LessonVisualPipeline only needs a data
/// URL. The richer routing now lives in SoftwareRenderCatalog, with named
/// renderers and pedagogical roles.
String? renderLocalVisualFallback({
  required VisualN2Result n2,
  String? topic,
  String? visualType,
  String? imagePrompt,
  List<BlueprintColorLegendItem> colorLegend = const [],
  List<String> keyElements = const [],
  String? highlightFocus,
  String? complexity,
  String? pedagogicalNeed,
  String? academicLevel,
  String? pedagogicalGoal,
}) {
  final result = const SoftwareRenderCatalog().render(
    SoftwareVisualRequest(
      n2: n2,
      topic: topic,
      visualType: visualType,
      imagePrompt: imagePrompt,
      colorLegend: colorLegend,
      keyElements: keyElements,
      highlightFocus: highlightFocus,
      complexity: complexity,
      pedagogicalNeed: pedagogicalNeed,
      academicLevel: academicLevel,
      pedagogicalGoal: pedagogicalGoal,
    ),
  );
  return result?.dataUrl;
}
