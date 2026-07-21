import 'dart:async';
import 'dart:convert';

import '../media/audio_core.dart';
import '../media/lesson_audio_api_contract.dart';
import '../media/lesson_visual_trigger.dart';
import '../lesson/lesson_content_validator.dart';
import '../localization/sim_locale_contract.dart';
import '../modules/pedagogical_module_contracts.dart';
import '../experience/bootstrap_payload.dart';
import '../state/student_learning_state.dart';
import 'sim_ai_server_config.dart';
import 'sim_http_transport.dart';

const String simT00BootstrapPath = '/api/bootstrap-t00';
const String simLessonAudioPath = '/api/generate-lesson-audio';
const Duration simT02LessonRequestTimeout = Duration(seconds: 140);

class SimServerT00Client implements T00BootstrapClient {
  SimServerT00Client({
    required this.config,
    SimHttpTransport? transport,
    this.timeout = const Duration(seconds: 140),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final Duration timeout;

  @override
  Stream<T00BootstrapChunk> runBootstrap(T00BootstrapRequest request) async* {
    final locale = _localeFields(
      interfaceLocale: request.interfaceLocale,
      learningLocale: request.learningLocale,
      explanationLanguage: request.explanationLanguage ?? request.lang,
      targetLanguage: request.targetLanguage,
    );
    final ficha = {
      ...request.onboarding,
      ...locale,
      'lessonLocalId': request.lessonLocalId,
      'language': locale['learningLocale'],
      'stableLang': locale['explanationLanguage'],
      'academic_level': request.academic,
      if (request.onboarding['free_text'] == null)
        'free_text': request.onboarding['objetivo'] ?? '',
    };
    final body = buildT00Phase1Body(
      data: ficha,
      lang: request.lang,
      academic: request.academic,
    );
    await for (final line in transport.postEventStream(
      config.uri(simT00BootstrapPath),
      headers: await config.jsonHeaders(),
      body: body,
      timeout: timeout,
    )) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith(':')) continue;
      if (!trimmed.startsWith('data:')) continue;
      final raw = trimmed.substring(5).trim();
      if (raw.isEmpty || raw == '[DONE]') continue;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      yield T00BootstrapChunk(
        type: decoded['type']?.toString() ?? 'message',
        payload: JsonMap.from(decoded),
      );
    }
  }
}

class SimServerGeneratedAudioClient implements GeneratedAudioClient {
  SimServerGeneratedAudioClient({
    required this.config,
    SimHttpTransport? transport,
    this.timeout = const Duration(seconds: 95),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final Duration timeout;

  @override
  Future<String?> generateAudio({
    required String text,
    required String lang,
    required String voice,
    required String lessonKey,
  }) async {
    final locale = _localeFields(
      learningLocale: lang,
      explanationLanguage: simLanguageNameForLocale(lang),
    );
    final request = GenerateLessonAudioRequest(
      text: text,
      lang: lang,
      lessonKey: lessonKey,
      voice: voice,
    ).normalized();
    final requestId = _mediaRequestId(
      'aud',
      '${request.lessonKey}|${request.lang}|${request.voice}|${request.text}',
    );
    final headers = await config.jsonHeaders();
    headers['x-request-id'] = requestId;
    final response = await _postJsonWithTimeout(
      transport,
      config.uri(simLessonAudioPath),
      headers: headers,
      body: {
        'text': request.text,
        'lang': request.lang,
        ...locale,
        'lessonKey': request.lessonKey,
        'voice': request.voice,
      },
      timeout: timeout,
      requestId: requestId,
    );
    if (!response.ok) {
      throw _mediaHttpException(response, fallbackRequestId: requestId);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    final parsed = GenerateLessonAudioResponse(
      dataUrl: decoded['dataUrl']?.toString() ?? '',
      voice: decoded['voice']?.toString() ?? voiceByLang(request.lang),
      model: decoded['model']?.toString() ?? geminiTtsModel,
    );
    return parsed.dataUrl;
  }
}

Future<SimHttpResponse> _postJsonWithTimeout(
  SimHttpTransport transport,
  Uri uri, {
  required Map<String, String> headers,
  required Object? body,
  required Duration timeout,
  required String requestId,
}) async {
  try {
    return await transport.postJson(
      uri,
      headers: headers,
      body: body,
      timeout: timeout,
    );
  } on TimeoutException {
    throw simSafeTimeoutException(code: 'MEDIA_TIMEOUT', requestId: requestId);
  }
}

SimExternalAiException _mediaHttpException(
  SimHttpResponse response, {
  required String fallbackRequestId,
}) {
  return simSafeHttpException(response, fallbackRequestId: fallbackRequestId);
}

String _mediaRequestId(String prefix, String basis) {
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return 'sim-$prefix-$stamp-${_stableHash(basis)}';
}

String _stableHash(String input) {
  var hash = 5381;
  for (final unit in input.codeUnits) {
    hash = ((hash << 5) + hash) ^ unit;
  }
  return (hash & 0xffffffff).toRadixString(36);
}

Map<String, Object?> _localeFieldsForT02(T02LessonRequest request) {
  return _localeFieldsFromMap(request.profile, {
    'interfaceLocale': request.interfaceLocale,
    'learningLocale': request.learningLocale ?? request.lang,
    'explanationLanguage': request.explanationLanguage ?? request.lang,
    'targetLanguage': request.targetLanguage,
  });
}

Map<String, Object?> _localeFieldsFromMap(
  Map<String, dynamic>? primary, [
  Map<String, dynamic>? secondary,
]) {
  Object? pick(String key) => primary?[key] ?? secondary?[key];
  return _localeFields(
    interfaceLocale: pick('interfaceLocale')?.toString(),
    learningLocale: pick('learningLocale')?.toString(),
    explanationLanguage: pick('explanationLanguage')?.toString(),
    targetLanguage: pick('targetLanguage')?.toString(),
  );
}

Map<String, Object?> _localeFields({
  String? interfaceLocale,
  String? learningLocale,
  String? explanationLanguage,
  String? targetLanguage,
}) {
  final learning = normalizeSimLocaleTag(learningLocale ?? explanationLanguage);
  final iface = normalizeSimLocaleTag(interfaceLocale);
  final explanation = (explanationLanguage ?? '').trim().isEmpty
      ? simLanguageNameForLocale(learning)
      : explanationLanguage!.trim();
  return {
    'interfaceLocale': iface,
    'learningLocale': learning,
    'explanationLanguage': explanation,
    if (targetLanguage != null && targetLanguage.trim().isNotEmpty)
      'targetLanguage': targetLanguage.trim(),
  };
}

class SimServerT02Client implements T02LessonClient {
  SimServerT02Client({
    required this.config,
    SimHttpTransport? transport,
    this.timeout = simT02LessonRequestTimeout,
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final Duration timeout;

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) {
    return _call(request, mode: 'auxiliary');
  }

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) {
    return _call(request, mode: 'lesson');
  }

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) {
    return _call(request, mode: 'doubt');
  }

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) {
    return _call(request, mode: 'placement');
  }

  Future<T02LessonMaterial> _call(
    T02LessonRequest request, {
    required String mode,
  }) async {
    final locale = _localeFieldsForT02(request);
    final path = config.t02Path;
    final unavailableCode = mode == 'doubt'
        ? 'DOUBT_UNAVAILABLE'
        : 'T02_BRIDGE_UNAVAILABLE';
    final invalidCode = mode == 'doubt'
        ? 'DOUBT_UNAVAILABLE'
        : 'T02_CONTRACT_INVALID';
    if (path == null || path.trim().isEmpty) {
      throw SimExternalAiException(
        unavailableCode,
        statusCode: 503,
        code: unavailableCode,
        retryable: false,
      );
    }
    final idempotencyKey = _t02IdempotencyKey(request, mode);
    final SimHttpResponse response;
    try {
      response = await transport.postJson(
        config.uri(path),
        headers: await config.jsonHeaders(),
        body: {
          'idempotencyKey': idempotencyKey,
          'mode': mode,
          'lessonLocalId': request.lessonLocalId,
          'item': request.item,
          ...locale,
          if (request.topic != null) 'topic': request.topic,
          if (request.itemIdx != null) 'itemIdx': request.itemIdx,
          'stable_lang': locale['explanationLanguage'] ?? request.lang,
          'academic_level': request.academic,
          'layer': request.layer.value,
          'err_count': request.errCount,
          'lesson_mode': request.mode,
          'history': request.history,
          if (request.marker != null) 'marker': request.marker,
          if (request.addendum != null) 'addendum': request.addendum,
          if (request.amparoLvl != null) 'amparo_level': request.amparoLvl,
          if (request.curriculumItems.isNotEmpty)
            'curriculumItems': request.curriculumItems,
          ...request.profile,
        },
        timeout: timeout,
      );
    } on TimeoutException {
      throw simSafeTimeoutException(code: 'T02_TIMEOUT');
    }
    if (!response.ok) {
      throw simSafeHttpException(response);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw SimExternalAiException(
        invalidCode,
        statusCode: 502,
        code: invalidCode,
        retryable: false,
      );
    }
    try {
      final payload = JsonMap.from(decoded);
      return mode == 'doubt'
          ? _parseDoubtT02Material(payload)
          : _parseT02Material(payload);
    } on LessonContentValidationException {
      throw SimExternalAiException(
        invalidCode,
        statusCode: 502,
        code: invalidCode,
        retryable: false,
      );
    }
  }

  T02LessonMaterial _parseDoubtT02Material(JsonMap json) {
    final source = json['conteudo'] is Map
        ? JsonMap.from(json['conteudo'])
        : json;
    Object? pick(String key, [String? alt]) =>
        source[key] ??
        json[key] ??
        (alt == null ? null : source[alt] ?? json[alt]);
    final explanation = _stringOrNull(
      pick('explanation') ?? pick('explicacao') ?? pick('answer'),
    );
    if (explanation == null) {
      throw const LessonContentValidationException(
        'Doubt response missing explanation.',
      );
    }
    final visualTrigger = LessonVisualTrigger.fromJson(
      pick('visual_trigger', 'visualTrigger'),
    )?.raw;
    return T02LessonMaterial(
      explanation: explanation,
      question: '',
      options: const {
        AnswerLetter.A: '',
        AnswerLetter.B: '',
        AnswerLetter.C: '',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: '',
      whyWrong: '',
      generatedAt: DateTime.now(),
      source: (source['source'] ?? 'sim-server-t02').toString(),
      visualTrigger: visualTrigger,
    );
  }

  T02LessonMaterial _parseT02Material(JsonMap json) {
    final source = json['conteudo'] is Map
        ? JsonMap.from(json['conteudo'])
        : json;
    final content = validatedLessonContentFromJson(source);
    Object? pick(String key, [String? alt]) =>
        source[key] ??
        json[key] ??
        (alt == null ? null : source[alt] ?? json[alt]);
    final imageData = _stringOrNull(
      pick('imageDataUrl', 'image_data_url') ??
          pick('dataUrl', 'data_url') ??
          pick('imagem'),
    );
    final visualTrigger = LessonVisualTrigger.fromJson(
      pick('visual_trigger', 'visualTrigger'),
    )?.raw;
    return T02LessonMaterial(
      explanation: content.explanation,
      question: content.question,
      options: content.options,
      correctAnswer: content.correctAnswer,
      whyCorrect: content.whyCorrect ?? '',
      whyWrong: content.whyWrong,
      generatedAt: DateTime.now(),
      source: (source['source'] ?? 'sim-server-t02').toString(),
      imageDataUrl: imageData,
      imageId: _stringOrNull(pick('imageId', 'image_id') ?? pick('requestId')),
      imageStatus: _stringOrNull(
        pick('imageStatus', 'image_status') ?? pick('status'),
      ),
      imageError: _stringOrNull(
        pick('imageError', 'image_error') ?? pick('error'),
      ),
      visualTrigger: visualTrigger,
      mimeType: _stringOrNull(pick('mimeType', 'mime_type')),
      rasterized: pick('rasterized') is bool
          ? pick('rasterized') as bool
          : null,
      n2Reason: _stringOrNull(pick('n2Reason', 'n2_reason')),
      n3Reason: _stringOrNull(pick('n3Reason', 'n3_reason')),
    );
  }
}

String _t02IdempotencyKey(T02LessonRequest request, String mode) {
  return [
    't02',
    mode,
    request.lessonLocalId,
    request.marker ?? 'marker',
    request.itemIdx?.toString() ?? 'idx',
    request.layer.value.toString(),
    _stableHash('${request.item}|${request.topic ?? ''}|${request.mode}'),
  ].join(':');
}

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
