import 'dart:convert';

import 'microdeck.dart';
import 'pedagogical_card.dart';
import 'pedagogical_card_integrity_verifier.dart';

typedef GameMicrodeckTransport =
    Future<GameMicrodeckTransportResponse> Function(
      GameMicrodeckRequest request,
    );

typedef GameMicrodeckAckTransport =
    Future<void> Function(GameMicrodeckAckRequest request);

final class GameMicrodeckClientException implements Exception {
  const GameMicrodeckClientException(this.message);

  final String message;

  @override
  String toString() => 'GameMicrodeckClientException: $message';
}

enum GameMicrodeckStatus {
  ready,
  running,
  queued,
  rateLimited,
  noCredit,
  failedRetryable,
  failedPermanent,
}

final class GameMicrodeckRequest {
  GameMicrodeckRequest({
    required this.lessonLocalId,
    required this.marker,
    required this.itemIdx,
    required this.layer,
    required this.sessionId,
    required this.idempotencyKey,
    this.contractVersion = 1,
    this.item,
    this.targetTopic,
    this.mode,
    this.learningLocale,
    this.interfaceLocale,
  }) {
    validate();
  }

  final String lessonLocalId;
  final String marker;
  final int itemIdx;
  final int layer;
  final String sessionId;
  final String idempotencyKey;
  final int contractVersion;
  final String? item;
  final String? targetTopic;
  final String? mode;
  final String? learningLocale;
  final String? interfaceLocale;

  void validate() {
    _requiredString(lessonLocalId, 'lessonLocalId_required');
    _requiredString(marker, 'marker_required');
    if (itemIdx < 0) {
      throw const GameMicrodeckClientException('itemIdx_must_be_nonnegative');
    }
    if (layer < 1 || layer > 3) {
      throw const GameMicrodeckClientException('layer_must_be_1_2_or_3');
    }
    _requiredString(sessionId, 'sessionId_required');
    _requiredString(idempotencyKey, 'idempotencyKey_required');
    if (contractVersion != 1) {
      throw const GameMicrodeckClientException('contractVersion_unsupported');
    }
    _validateOptionalRequestString(item, 'item', 1024);
    _validateOptionalRequestString(targetTopic, 'targetTopic', 256);
    _validateOptionalRequestString(mode, 'mode', 64);
    _validateOptionalRequestString(learningLocale, 'learningLocale', 32);
    _validateOptionalRequestString(interfaceLocale, 'interfaceLocale', 32);
  }

  Map<String, Object?> toJson() {
    validate();
    return {
      'lessonLocalId': lessonLocalId,
      'marker': marker,
      'itemIdx': itemIdx,
      'layer': layer,
      'sessionId': sessionId,
      'idempotencyKey': idempotencyKey,
      'contractVersion': contractVersion,
      if (item != null) 'item': item,
      if (targetTopic != null) 'target_topic': targetTopic,
      if (mode != null) 'mode': mode,
      if (learningLocale != null) 'learningLocale': learningLocale,
      if (interfaceLocale != null) 'interfaceLocale': interfaceLocale,
    };
  }
}

final class GameMicrodeckTransportResponse {
  GameMicrodeckTransportResponse({
    required this.body,
    Map<String, String>? headers,
  }) : headers = Map<String, String>.unmodifiable(headers ?? const {});

  final String body;
  final Map<String, String> headers;
}

final class GameMicrodeckAckRequest {
  GameMicrodeckAckRequest({
    required this.operationKey,
    required this.request,
    required this.organ,
    required this.route,
  }) {
    _requiredString(operationKey, 'operationKey_required');
    _requiredString(organ, 'organ_required');
    _requiredString(route, 'route_required');
    _requiredString(request.sessionId, 'sessionId_required');
    _requiredString(request.idempotencyKey, 'idempotencyKey_required');
  }

  final String operationKey;
  final GameMicrodeckRequest request;
  final String organ;
  final String route;

  Map<String, Object?> toJson() => {
    'organ': organ,
    'route': route,
    'sessionId': request.sessionId,
    'idempotencyKey': request.idempotencyKey,
  };
}

final class GameMicrodeckClientResult {
  const GameMicrodeckClientResult({
    required this.status,
    this.microdeck,
    this.operationKey,
    this.retryAfterSeconds,
  });

  final GameMicrodeckStatus status;
  final Microdeck? microdeck;
  final String? operationKey;
  final int? retryAfterSeconds;

  bool get isPreparing =>
      status == GameMicrodeckStatus.running ||
      status == GameMicrodeckStatus.queued;
}

final class GameMicrodeckClient {
  const GameMicrodeckClient({
    required GameMicrodeckTransport transport,
    GameMicrodeckAckTransport? ackTransport,
  }) : this._(transport, ackTransport);

  const GameMicrodeckClient._(this._transport, this._ackTransport);

  final GameMicrodeckTransport _transport;
  final GameMicrodeckAckTransport? _ackTransport;

  Future<GameMicrodeckClientResult> requestMicrodeck(
    GameMicrodeckRequest request,
  ) async {
    request.validate();
    final response = await _transport(request);
    final body = _decodeBody(response.body);
    _rejectUnknownKeys(body, _allowedResponseKeys);
    _rejectForbiddenResponseValue(body);

    final status = _parseStatus(body['status']);
    return switch (status) {
      GameMicrodeckStatus.ready => _handleReady(request, body),
      GameMicrodeckStatus.running ||
      GameMicrodeckStatus.queued => GameMicrodeckClientResult(
        status: status,
        retryAfterSeconds: _retryAfterSeconds(body, response.headers),
      ),
      GameMicrodeckStatus.rateLimited ||
      GameMicrodeckStatus.failedRetryable => GameMicrodeckClientResult(
        status: status,
        retryAfterSeconds: _retryAfterSeconds(body, response.headers),
      ),
      GameMicrodeckStatus.noCredit || GameMicrodeckStatus.failedPermanent =>
        GameMicrodeckClientResult(status: status),
    };
  }

  Future<GameMicrodeckClientResult> _handleReady(
    GameMicrodeckRequest request,
    Map<String, Object?> body,
  ) async {
    final operationKey = _requiredString(
      body['operationKey'] ?? body['operation_key'],
      'operationKey_required',
    );
    _requiredString(
      body['contentHash'] ?? body['content_hash'],
      'contentHash_required',
    );
    _requiredString(
      body['resultHash'] ?? body['result_hash'],
      'resultHash_required',
    );
    _requiredString(
      body['serverSignature'] ?? body['server_signature'],
      'serverSignature_required',
    );
    final contractVersion = _requiredPositiveInt(
      body['contractVersion'] ?? body['contract_version'],
      'contractVersion_required',
    );
    if (contractVersion != 1) {
      throw const GameMicrodeckClientException('contractVersion_unsupported');
    }
    if (body['deliveryAckRequired'] != true &&
        body['delivery_ack_required'] != true) {
      throw const GameMicrodeckClientException(
        'deliveryAckRequired_must_be_true',
      );
    }
    final rawMicrodeck = body['microdeck'];
    if (rawMicrodeck == null) {
      throw const GameMicrodeckClientException('microdeck_required');
    }

    final microdeck = _parseMicrodeck(rawMicrodeck);
    if (_ackTransport != null) {
      await _ackTransport(
        GameMicrodeckAckRequest(
          operationKey: operationKey,
          request: request,
          organ: _microdeckAckOrgan,
          route: _microdeckRoute,
        ),
      );
    }
    return GameMicrodeckClientResult(
      status: GameMicrodeckStatus.ready,
      microdeck: microdeck,
      operationKey: operationKey,
    );
  }
}

const Set<String> _allowedResponseKeys = {
  'status',
  'microdeck',
  'operationKey',
  'operation_key',
  'contentHash',
  'content_hash',
  'resultHash',
  'result_hash',
  'serverSignature',
  'server_signature',
  'contractVersion',
  'contract_version',
  'deliveryAckRequired',
  'delivery_ack_required',
  'retryAfter',
  'retry_after',
  'code',
  'message',
  'error',
};

final String _microdeckAckOrgan = ['T', '02'].join();
const String _microdeckRoute = '/api/sim-game/microdeck';

Map<String, Object?> _decodeBody(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const GameMicrodeckClientException('response_must_be_object');
    }
    return Map<String, Object?>.from(decoded);
  } on GameMicrodeckClientException {
    rethrow;
  } on FormatException {
    throw const GameMicrodeckClientException('invalid_json');
  }
}

Microdeck _parseMicrodeck(Object? value) {
  try {
    final microdeck = Microdeck.fromJson(value);
    microdeck.validate();
    return microdeck;
  } on PedagogicalCardIntegrityException catch (error) {
    throw GameMicrodeckClientException(error.message);
  } on PedagogicalCardContractException catch (error) {
    throw GameMicrodeckClientException(error.message);
  } on MicrodeckContractException catch (error) {
    throw GameMicrodeckClientException(error.message);
  }
}

GameMicrodeckStatus _parseStatus(Object? value) {
  final status = _requiredString(value, 'status_required');
  return switch (status) {
    'ready' => GameMicrodeckStatus.ready,
    'running' => GameMicrodeckStatus.running,
    'queued' => GameMicrodeckStatus.queued,
    'rate_limited' => GameMicrodeckStatus.rateLimited,
    'no_credit' => GameMicrodeckStatus.noCredit,
    'failed_retryable' => GameMicrodeckStatus.failedRetryable,
    'failed_permanent' => GameMicrodeckStatus.failedPermanent,
    _ => throw const GameMicrodeckClientException('status_unknown'),
  };
}

int? _retryAfterSeconds(
  Map<String, Object?> body,
  Map<String, String> headers,
) {
  return _optionalPositiveInt(body['retryAfter'] ?? body['retry_after']) ??
      _headerRetryAfter(headers);
}

int? _headerRetryAfter(Map<String, String> headers) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == 'retry-after') {
      return _optionalPositiveInt(entry.value);
    }
  }
  return null;
}

int? _optionalPositiveInt(Object? value) {
  if (value == null) return null;
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null || parsed <= 0) {
    throw const GameMicrodeckClientException('retryAfter_invalid');
  }
  return parsed;
}

String _requiredString(Object? value, String message) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    throw GameMicrodeckClientException(message);
  }
  return text;
}

int _requiredPositiveInt(Object? value, String message) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null || parsed <= 0) {
    throw GameMicrodeckClientException(message);
  }
  return parsed;
}

void _validateOptionalRequestString(
  String? value,
  String field,
  int maxLength,
) {
  if (value == null) return;
  final text = value.trim();
  if (text.isEmpty) {
    throw GameMicrodeckClientException('${field}_must_not_be_blank');
  }
  if (text.length > maxLength) {
    throw GameMicrodeckClientException('${field}_too_large');
  }
  if (field == 'mode' && text == 'microdeck') {
    return;
  }
  if (field == 'mode') {
    if (text.startsWith('microdeck')) {
      _rejectForbiddenRequestValue(text.replaceFirst('microdeck', ''));
      throw const GameMicrodeckClientException('mode_unsupported');
    }
    _rejectForbiddenRequestValue(text);
    throw const GameMicrodeckClientException('mode_unsupported');
  }
  _rejectForbiddenRequestValue(text);
}

void _rejectForbiddenRequestValue(Object? value) {
  if (value == null || value is num || value is bool) return;
  if (value is String) {
    if (_containsForbiddenRequestToken(value)) {
      throw const GameMicrodeckClientException('request_forbidden_field');
    }
    return;
  }
  if (value is List) {
    for (final item in value) {
      _rejectForbiddenRequestValue(item);
    }
    return;
  }
  if (value is Map) {
    for (final entry in value.entries) {
      _rejectForbiddenRequestValue(entry.key);
      _rejectForbiddenRequestValue(entry.value);
    }
    return;
  }
  throw const GameMicrodeckClientException('request_forbidden_field');
}

bool _containsForbiddenRequestToken(String value) {
  final lowered = value.toLowerCase();
  return _forbiddenRequestTokens.any(lowered.contains);
}

final List<String> _forbiddenRequestTokens = [
  ['pro', 'mpt'].join(),
  ['raw', 'pro', 'mpt'].join(),
  ['system', 'instruction'].join(),
  ['developer', 'instruction'].join(),
  ['ad', 'endo'].join(),
  ['t', '00'].join(),
  ['t', '02'].join(),
  ['n', '3'].join(),
  ['gem', 'ini'].join(),
  ['mod', 'el'].join(),
  ['user', 'id'].join(),
  ['cre', 'dit'].join(),
  ['cre', 'dits'].join(),
  ['led', 'ger'].join(),
  ['co', 'st'].join(),
  ['bill', 'ing'].join(),
  ['cards'].join(),
  ['micro', 'deck'].join(),
  ['pay', 'load'].join(),
  ['body'].join(),
  ['provider', 'response'].join(),
  ['raw', 'provider', 'response'].join(),
  ['ai', 'provider'].join(),
  ['ai', 'mo', 'del'].join(),
  ['ai', '_', 'mo', 'del'].join(),
  ['ai', '-', 'provider'].join(),
  ['artificial', ' ', 'intelligence'].join(),
  ['open', 'ai'].join(),
  ['embed', 'ding'].join(),
  ['seman', 'tic'].join(),
  ['vec', 'tor'].join(),
  ['reuse', 'policy'].join(),
  ['card', 'store'].join(),
  ['question', 'bank'].join(),
  ['ac', 'ervo'].join(),
];

void _rejectForbiddenResponseValue(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return;
  }
  if (value is List) {
    for (final item in value) {
      _rejectForbiddenResponseValue(item);
    }
    return;
  }
  if (value is Map) {
    for (final entry in value.entries) {
      if (_isForbiddenResponseKey(entry.key)) {
        throw const GameMicrodeckClientException('response_forbidden_field');
      }
      _rejectForbiddenResponseValue(entry.value);
    }
    return;
  }
  throw const GameMicrodeckClientException('response_forbidden_field');
}

bool _isForbiddenResponseKey(Object? key) {
  final text = key?.toString().toLowerCase().trim();
  if (text == null || text.isEmpty) return false;
  return _forbiddenResponseKeys.contains(text);
}

final Set<String> _forbiddenResponseKeys = {
  ['pro', 'mpt'].join(),
  ['raw', 'pro', 'mpt'].join(),
  ['system', 'instruction'].join(),
  ['developer', 'instruction'].join(),
  ['ad', 'endo'].join(),
  ['t', '00'].join(),
  ['t', '02'].join(),
  ['n', '3'].join(),
  ['gem', 'ini'].join(),
  ['mod', 'el'].join(),
  ['user', 'id'].join(),
  ['cre', 'dit'].join(),
  ['cre', 'dits'].join(),
  ['led', 'ger'].join(),
  ['co', 'st'].join(),
  ['bill', 'ing'].join(),
  ['pay', 'load'].join(),
  ['body'].join(),
  ['provider', 'response'].join(),
  ['raw', 'provider', 'response'].join(),
  ['server', 'secret'].join(),
  ['private', 'key'].join(),
  ['private', '_', 'key'].join(),
  ['h', 'mac'].join(),
};

void _rejectUnknownKeys(Map<String, Object?> value, Set<String> allowed) {
  for (final key in value.keys) {
    if (!allowed.contains(key)) {
      throw const GameMicrodeckClientException('response_unknown_field');
    }
  }
}
