import 'package:flutter/foundation.dart';

import 'visual_router_n2.dart';

class VisualN3Result {
  const VisualN3Result({
    required this.verdict,
    required this.reason,
    this.svgDataUrl,
    this.displayDataUrl,
    this.confidence,
    this.pedagogicalRole,
    this.paidOfferPrompt,
    this.requestId,
    this.transportFailed = false,
    this.statusCode,
  });

  final VisualVerdict verdict;
  final String reason;
  final String? svgDataUrl;
  final String? displayDataUrl;
  final double? confidence;
  final String? pedagogicalRole;
  final String? paidOfferPrompt;
  final String? requestId;
  final bool transportFailed;
  final int? statusCode;
}

abstract interface class LessonVisualRouterClient {
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
  });
}

Future<VisualN3Result> routeVisualCheapN3({
  required LessonVisualRouterClient client,
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
}) async {
  if (n2.verdict == VisualVerdict.ai) {
    return VisualN3Result(verdict: VisualVerdict.ai, reason: n2.reason);
  }
  try {
    return await client.routeVisual(
      n2: n2,
      topic: topic,
      visualType: visualType,
      imagePrompt: imagePrompt,
      keyElements: keyElements,
      pedagogicalNeed: pedagogicalNeed,
      highlightFocus: highlightFocus,
      complexity: complexity,
      stableLang: stableLang,
      svgPayload: svgPayload,
    );
  } catch (error, stackTrace) {
    final shortError = _shortVisualN3Error(error);
    final statusCode = _statusCodeFromVisualN3Error(error);
    final requestId = _requestIdFromVisualN3Error(error);
    if (kDebugMode) {
      debugPrint(
        '[VISUAL_N3_FAIL] status=${statusCode ?? "unknown"} '
        'requestId=${requestId ?? "unknown"} $shortError',
      );
      debugPrintStack(stackTrace: stackTrace, label: 'VISUAL_N3_FAIL');
    }
    return VisualN3Result(
      verdict: VisualVerdict.ambiguous,
      reason: statusCode == null
          ? 'N3_TRANSPORT_FAILED: $shortError'
          : 'N3_TRANSPORT_FAILED_$statusCode: $shortError',
      transportFailed: true,
      statusCode: statusCode,
      requestId: requestId,
    );
  }
}

String _shortVisualN3Error(Object error) {
  final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= 200) return text;
  return text.substring(0, 200);
}

int? _statusCodeFromVisualN3Error(Object error) {
  try {
    final value = (error as dynamic).statusCode;
    if (value is int) return value;
  } catch (_) {
    // Ignore dynamic lookup failures.
  }
  final match = RegExp(
    r'\bHTTP\s+([1-5][0-9][0-9])\b',
  ).firstMatch(error.toString());
  return match == null ? null : int.tryParse(match.group(1)!);
}

String? _requestIdFromVisualN3Error(Object error) {
  try {
    final value = (error as dynamic).requestId;
    if (value is String && value.trim().isNotEmpty) return value.trim();
  } catch (_) {
    // Ignore dynamic lookup failures.
  }
  final match = RegExp(
    r'\brequestId[=:]\s*([A-Za-z0-9._:-]+)',
  ).firstMatch(error.toString());
  return match?.group(1);
}
