import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'sim_http_transport.dart';

typedef SimAccessTokenProvider = Future<String?> Function();

class SimAiServerConfig {
  const SimAiServerConfig({
    required this.baseUrl,
    this.accessTokenProvider,
    this.t00Path,
    this.t02Path,
  });

  final String baseUrl;
  final SimAccessTokenProvider? accessTokenProvider;
  final String? t00Path;
  final String? t02Path;

  Uri uri(String path) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$cleanBase$cleanPath');
  }

  Future<Map<String, String>> jsonHeaders() async {
    final token = await accessTokenProvider?.call();
    final trimmed = (token ?? '').trim();
    debugPrint('[SIM_CFG] jsonHeaders prepared');
    return {
      'content-type': 'application/json',
      'accept': 'application/json',
      if (trimmed.isNotEmpty) 'authorization': 'Bearer $trimmed',
    };
  }

  Future<Map<String, String>> streamHeaders() async {
    final token = await accessTokenProvider?.call();
    final trimmed = (token ?? '').trim();
    debugPrint('[SIM_CFG] streamHeaders prepared');
    return {
      'content-type': 'application/json',
      'accept': 'text/event-stream',
      if (trimmed.isNotEmpty) 'authorization': 'Bearer $trimmed',
    };
  }
}

class SimExternalAiException implements Exception {
  const SimExternalAiException(
    this.message, {
    this.statusCode,
    this.requestId,
    this.code,
    this.retryable,
  });

  final String message;
  final int? statusCode;
  final String? requestId;
  final String? code;
  final bool? retryable;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' HTTP $statusCode';
    final request = requestId == null ? '' : ' requestId=$requestId';
    final safeCode = code == null ? '' : ' code=$code';
    final retry = retryable == null ? '' : ' retryable=$retryable';
    return 'SimExternalAiException$status$request$safeCode$retry: $message';
  }
}

SimExternalAiException simSafeHttpException(
  SimHttpResponse response, {
  String? fallbackRequestId,
}) {
  final parsed = _parseSafeHttpBody(response.body);
  final code = _safeCodeForStatus(response.statusCode);
  return SimExternalAiException(
    code,
    statusCode: response.statusCode,
    requestId:
        _safeToken(response.headers['x-request-id']) ??
        _safeToken(parsed.requestId) ??
        _safeToken(fallbackRequestId),
    code: code,
    retryable: _retryableForStatus(response.statusCode),
  );
}

SimExternalAiException simSafeTimeoutException({
  required String code,
  String? requestId,
}) {
  return SimExternalAiException(
    code,
    statusCode: 408,
    requestId: _safeToken(requestId),
    code: code,
    retryable: true,
  );
}

class _ParsedSafeHttpBody {
  const _ParsedSafeHttpBody({this.requestId});

  final String? requestId;
}

_ParsedSafeHttpBody _parseSafeHttpBody(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return const _ParsedSafeHttpBody();
    return _ParsedSafeHttpBody(
      requestId: (decoded['requestId'] ?? decoded['request_id'])?.toString(),
    );
  } catch (_) {
    return const _ParsedSafeHttpBody();
  }
}

String _safeCodeForStatus(int statusCode) {
  if (statusCode == 401 || statusCode == 403) return 'AUTH_REQUIRED';
  if (statusCode == 402) return 'CREDIT_REQUIRED';
  if (statusCode == 408 || statusCode == 504) return 'AI_TIMEOUT';
  if (statusCode == 409) return 'AI_CONFLICT';
  if (statusCode == 429) return 'AI_RATE_LIMIT';
  if (statusCode >= 500) return 'AI_SERVER_UNAVAILABLE';
  return 'AI_REQUEST_FAILED';
}

bool _retryableForStatus(int statusCode) {
  return statusCode == 408 ||
      statusCode == 429 ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504;
}

String? _safeToken(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty || value.length > 96) return null;
  final allowed = RegExp(r'^[A-Za-z0-9._:-]+$');
  return allowed.hasMatch(value) ? value : null;
}
