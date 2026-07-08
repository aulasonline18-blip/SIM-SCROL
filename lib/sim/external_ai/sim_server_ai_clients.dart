import 'dart:async';
import 'dart:convert';

import '../media/audio_core.dart';
import '../media/lesson_audio_api_contract.dart';
import '../media/lesson_image_api_contract.dart';
import '../media/lesson_visual_models.dart';
import '../media/lesson_visual_pipeline.dart';
import '../lesson/lesson_content_validator.dart';
import '../localization/sim_locale_contract.dart';
import '../modules/pedagogical_module_contracts.dart';
import '../experience/bootstrap_payload.dart';
import '../state/student_learning_state.dart';
import 'sim_ai_server_config.dart';
import 'sim_http_transport.dart';

const String simT00BootstrapPath = '/api/bootstrap-t00';
const String simServerClassroomSlotPath = '/api/server-classroom/slot';
const String simWarmupPath = '/api/warmup';
const String simLessonImagePath = '/api/generate-lesson-image';
const String simLessonAudioPath = '/api/generate-lesson-audio';
const String simVisualRoutePath = '/api/visual-route';
const String simDoubtPath = '/api/doubt';

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

class SimWarmupLesson {
  const SimWarmupLesson({
    required this.explanation,
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.whyCorrect,
    this.whyWrong = const {},
  });

  final String explanation;
  final String question;
  final Map<String, String> options;
  final String correctAnswer;
  final String? whyCorrect;
  final Map<String, String> whyWrong;

  Map<String, Object?> toJson() => {
    'explanation': explanation,
    'question': question,
    'options': options,
    'correctAnswer': correctAnswer,
    'whyCorrect': whyCorrect,
    'whyWrong': whyWrong,
    'type': 'warmup',
    'officialCurriculum': false,
    'countsForMastery': false,
  };

  static SimWarmupLesson? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final source = raw['warmup'] is Map ? raw['warmup'] as Map : raw;
    final optionsRaw = source['options'];
    if (optionsRaw is! Map) return null;
    final options = <String, String>{
      for (final letter in const ['A', 'B', 'C'])
        letter: (optionsRaw[letter] ?? optionsRaw[letter.toLowerCase()] ?? '')
            .toString()
            .trim(),
    };
    final explanation = (source['explanation'] ?? source['explicacao'] ?? '')
        .toString()
        .trim();
    final question = (source['question'] ?? source['pergunta'] ?? '')
        .toString()
        .trim();
    final correct = (source['correct_answer'] ?? source['correctAnswer'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    if (explanation.isEmpty ||
        question.isEmpty ||
        options.values.any((value) => value.isEmpty) ||
        !options.containsKey(correct)) {
      return null;
    }
    final whyWrongRaw = source['why_wrong'] ?? source['whyWrong'];
    final whyWrong = <String, String>{
      if (whyWrongRaw is Map)
        for (final letter in const ['A', 'B', 'C'])
          if ((whyWrongRaw[letter] ?? whyWrongRaw[letter.toLowerCase()]) !=
              null)
            letter: (whyWrongRaw[letter] ?? whyWrongRaw[letter.toLowerCase()])
                .toString(),
    };
    return SimWarmupLesson(
      explanation: explanation,
      question: question,
      options: options,
      correctAnswer: correct,
      whyCorrect: (source['why_correct'] ?? source['whyCorrect'])?.toString(),
      whyWrong: whyWrong,
    );
  }
}

class SimServerWarmupClient {
  SimServerWarmupClient({
    required this.config,
    SimHttpTransport? transport,
    this.timeout = const Duration(seconds: 12),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final Duration timeout;

  Future<SimWarmupLesson?> generate({
    required String lessonLocalId,
    required String objective,
    required Map<String, dynamic> ficha,
    required SimLocaleContract locale,
    String? academic,
  }) async {
    final response = await transport.postJson(
      config.uri(simWarmupPath),
      headers: await config.jsonHeaders(),
      body: {
        'lessonLocalId': lessonLocalId,
        'objective': objective,
        'ficha': {
          ...ficha,
          ...locale.toJson(),
          'lessonLocalId': lessonLocalId,
          'academic_level': ?academic,
        },
        ...locale.toJson(),
        'academic_level': ?academic,
      },
      timeout: timeout,
    );
    if (!response.ok) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    return SimWarmupLesson.fromJson(decoded);
  }
}

class SimServerLessonImageClient
    implements LessonImageClient, LessonImageResponseClient {
  SimServerLessonImageClient({
    required this.config,
    SimHttpTransport? transport,
    this.timeout = const Duration(seconds: 125),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final Duration timeout;

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
    final response = await generateLessonImageResponse(
      prompt: prompt,
      lessonKey: lessonKey,
      aspectRatio: aspectRatio,
      acceptedOfferId: acceptedOfferId,
      idempotencyKey: idempotencyKey,
      visualTrigger: visualTrigger,
      lessonContext: lessonContext,
    );
    return response?.dataUrl;
  }

  @override
  Future<GenerateLessonImageResponse?> generateLessonImageResponse({
    required String prompt,
    required String lessonKey,
    String aspectRatio = '1:1',
    String? acceptedOfferId,
    String? idempotencyKey,
    Map<String, dynamic>? visualTrigger,
    Map<String, dynamic>? lessonContext,
  }) async {
    final locale = _localeFieldsFromMap(lessonContext, visualTrigger);
    final request = GenerateLessonImageRequest(
      prompt: prompt,
      lessonKey: lessonKey,
      aspectRatio: aspectRatio,
    ).normalized();
    final body = <String, Object?>{
      'prompt': request.prompt,
      'lessonKey': request.lessonKey,
      'aspectRatio': request.aspectRatio,
      ...locale,
    };
    if (acceptedOfferId != null) body['acceptedOfferId'] = acceptedOfferId;
    if (idempotencyKey != null) body['idempotencyKey'] = idempotencyKey;
    if (visualTrigger != null && visualTrigger.isNotEmpty) {
      body['visual_trigger'] = visualTrigger;
    }
    if (lessonContext != null && lessonContext.isNotEmpty) {
      body['lessonContext'] = lessonContext;
    }
    body['source'] = 'sim_app_flutter';
    body['contractVersion'] = 'lesson_image_paid_v1';
    final requestId = _mediaRequestId(
      'img',
      '${request.lessonKey}|${request.prompt}',
    );
    final headers = await config.jsonHeaders();
    headers['x-request-id'] = requestId;
    final response = await _postJsonWithTimeout(
      transport,
      config.uri(simLessonImagePath),
      headers: headers,
      body: body,
      timeout: timeout,
      requestId: requestId,
    );
    if (!response.ok) {
      throw _mediaHttpException(response, fallbackRequestId: requestId);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    final dataUrl = decoded['dataUrl']?.toString() ?? '';
    if (dataUrl.trim().isEmpty) return null;
    return GenerateLessonImageResponse(
      dataUrl: dataUrl,
      cacheKey: decoded['cacheKey']?.toString(),
      requestId: decoded['requestId']?.toString() ?? requestId,
      mimeType:
          decoded['mime_type']?.toString() ?? decoded['mimeType']?.toString(),
      provider: decoded['provider']?.toString(),
      model: decoded['model']?.toString(),
      charged: decoded['charged'] is bool ? decoded['charged'] as bool : null,
      cacheHit: decoded['cache_hit'] is bool
          ? decoded['cache_hit'] as bool
          : decoded['cacheHit'] is bool
          ? decoded['cacheHit'] as bool
          : null,
      retryable: decoded['retryable'] is bool
          ? decoded['retryable'] as bool
          : null,
    );
  }
}

class SimServerVisualRouterClient implements LessonVisualRouterClient {
  SimServerVisualRouterClient({
    required this.config,
    SimHttpTransport? transport,
    this.timeout = const Duration(seconds: 100),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final Duration timeout;

  bool get prefersServerSideVisuals => true;

  @override
  Future<ServerVisualRouteResult> routeVisual({
    String? stableLang,
    required Map<String, dynamic> visualTrigger,
  }) async {
    final locale = _localeFieldsFromMap(visualTrigger, {
      'explanationLanguage': ?stableLang,
    });
    final topic = visualTrigger['topic']?.toString();
    final visualType = visualTrigger['visual_type']?.toString();
    final imagePrompt =
        visualTrigger['image_prompt']?.toString() ??
        visualTrigger['teacher_prompt']?.toString() ??
        visualTrigger['teacherPrompt']?.toString() ??
        visualTrigger['prompt']?.toString();
    final requestId = _mediaRequestId(
      'vis',
      '${topic ?? ''}|${visualType ?? ''}|${imagePrompt ?? ''}',
    );
    final headers = await config.jsonHeaders();
    headers['x-request-id'] = requestId;
    final visualTriggerPayload = <String, Object?>{...visualTrigger}
      ..addAll(locale)
      ..removeWhere((_, value) => value == null);
    final keyElements = visualTriggerPayload['key_elements'];
    final body = <String, Object?>{
      'contractVersion': 'server_ready_image_v1',
      'topic': topic ?? '',
      'visualType': visualType ?? '',
      'imagePrompt': imagePrompt ?? '',
      ...locale,
      'outputContract': {
        'format': 'ready_raster_image',
        'acceptedDataUrls': ['png', 'jpeg', 'jpg', 'webp'],
        'preferredFields': ['displayDataUrl', 'dataUrl', 'image_data_url'],
      },
      if (keyElements is List && keyElements.isNotEmpty)
        'keyElements': keyElements,
      if (visualTriggerPayload.isNotEmpty)
        'visual_trigger': visualTriggerPayload,
    };
    final svgPayload = visualTriggerPayload['svg_payload']?.toString();
    if (svgPayload != null && svgPayload.trim().isNotEmpty) {
      body['svgPayload'] = svgPayload;
    }
    final mathTemplate = visualTriggerPayload['math_template'];
    if (mathTemplate != null) {
      body['mathTemplate'] = mathTemplate;
    }
    if (visualTriggerPayload['pedagogical_need'] != null) {
      body['pedagogicalNeed'] = visualTriggerPayload['pedagogical_need'];
    }
    if (visualTriggerPayload['highlight_focus'] != null) {
      body['highlightFocus'] = visualTriggerPayload['highlight_focus'];
    }
    if (visualTriggerPayload['complexity'] != null) {
      body['complexity'] = visualTriggerPayload['complexity'];
    }
    if (stableLang != null) body['stableLang'] = stableLang;
    final response = await _postJsonWithTimeout(
      transport,
      config.uri(simVisualRoutePath),
      headers: headers,
      body: body,
      timeout: timeout,
      requestId: requestId,
    );
    if (!response.ok) {
      throw _mediaHttpException(response, fallbackRequestId: requestId);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      return const ServerVisualRouteResult(
        verdict: ServerVisualRouteVerdict.missingRaster,
        reason: 'VISUAL_ROUTE_INVALID_RESPONSE',
      );
    }
    final reason = decoded['reason']?.toString() ?? 'VISUAL_ROUTE_RESPONSE';
    final verdictRaw = decoded['verdict']?.toString();
    final noImage = verdictRaw == 'no_image';
    final displayDataUrl = _firstUsableRasterDataUrl(
      decoded['displayDataUrl'],
      decoded['dataUrl'],
      decoded['image_data_url'],
    );
    return ServerVisualRouteResult(
      verdict: noImage
          ? ServerVisualRouteVerdict.noImage
          : displayDataUrl != null
          ? ServerVisualRouteVerdict.image
          : ServerVisualRouteVerdict.missingRaster,
      reason: reason,
      readyImageDataUrl: displayDataUrl,
      requestId: decoded['requestId']?.toString() ?? requestId,
    );
  }
}

String? _firstUsableRasterDataUrl(
  Object? first,
  Object? second,
  Object? third,
) {
  for (final value in [first, second, third]) {
    if (isUsableRasterImageDataUrl(value)) return (value! as String).trim();
  }
  return null;
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
    throw SimExternalAiException(
      'Tempo esgotado ao preparar mídia.',
      statusCode: 408,
      requestId: requestId,
      code: 'MEDIA_TIMEOUT',
      retryable: true,
    );
  }
}

SimExternalAiException _mediaHttpException(
  SimHttpResponse response, {
  required String fallbackRequestId,
}) {
  String message = response.body;
  String? requestId = response.headers['x-request-id'] ?? fallbackRequestId;
  String? code;
  bool? retryable;
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      final error = decoded['error'];
      if (error is Map) {
        message = (error['message'] ?? error['reason'] ?? message).toString();
        code = (error['code'] ?? error['reason'])?.toString();
        retryable = error['retryable'] is bool
            ? error['retryable'] as bool
            : null;
      } else if (error != null) {
        message = error.toString();
      }
      requestId = (decoded['requestId'] ?? decoded['request_id'] ?? requestId)
          ?.toString();
      code ??= decoded['code']?.toString();
      retryable ??= decoded['retryable'] is bool
          ? decoded['retryable'] as bool
          : null;
    }
  } catch (_) {
    message = response.body.length > 400
        ? '${response.body.substring(0, 400)}...'
        : response.body;
  }
  return SimExternalAiException(
    message,
    statusCode: response.statusCode,
    requestId: requestId,
    code: code,
    retryable: retryable,
  );
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
    this.timeout = const Duration(seconds: 45),
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
    return _callServerClassroomSlot(request);
  }

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) {
    return _callDoubt(request);
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
    if (path == null || path.trim().isEmpty) {
      throw const SimExternalAiException(
        'T02 no SIM atual roda por server function interna. Configure a ponte HTTP do servidor antes de chamar T02 pelo APK.',
      );
    }
    final response = await transport.postJson(
      config.uri(path),
      headers: await config.jsonHeaders(),
      body: {
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
        ...request.profile,
      },
      timeout: timeout,
    );
    if (!response.ok) {
      throw SimExternalAiException(
        response.body,
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const SimExternalAiException('T02 retornou resposta invalida.');
    }
    try {
      return _parseT02Material(JsonMap.from(decoded));
    } on LessonContentValidationException catch (error) {
      throw SimExternalAiException(
        'T02 retornou contrato invalido: ${error.message}',
        statusCode: 502,
      );
    }
  }

  Future<T02LessonMaterial> _callDoubt(T02LessonRequest request) async {
    final locale = _localeFieldsForT02(request);
    final response = await transport.postJson(
      config.uri(simDoubtPath),
      headers: await config.jsonHeaders(),
      body: {
        'lessonLocalId': request.lessonLocalId,
        'marker': request.marker,
        'itemIdx': request.itemIdx ?? 0,
        'layer': request.layer.value,
        'currentQuestion': request.item,
        'currentOptions':
            request.profile['currentOptions'] ??
            request.profile['options'] ??
            {},
        'selectedOption':
            request.profile['selectedOption'] ??
            request.profile['student_answer'],
        'signal':
            request.profile['signal'] ?? request.profile['student_signal'],
        'currentFeedback': request.profile['currentFeedback'] ?? {},
        'studentQuestion':
            request.profile['student_doubt'] ??
            (request.history.isEmpty ? '' : request.history.last),
        'attachment': request.profile['doubt_image'],
        ...locale,
        'language': locale['learningLocale'] ?? request.lang,
        'idempotencyKey':
            request.profile['idempotencyKey'] ??
            'doubt:${request.lessonLocalId}:${request.marker ?? request.item}:${request.layer.value}:${request.history.length}',
        'currentState': request.profile['currentState'] ?? {},
        'history': request.history,
      },
      timeout: timeout,
    );
    if (!response.ok) {
      throw SimExternalAiException(
        response.body,
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const SimExternalAiException('doubt retornou resposta invalida.');
    }
    return _parseDoubtResponse(JsonMap.from(decoded));
  }

  Future<T02LessonMaterial> _callServerClassroomSlot(
    T02LessonRequest request,
  ) async {
    final locale = _localeFieldsForT02(request);
    final response = await transport.postJson(
      config.uri(simServerClassroomSlotPath),
      headers: await config.jsonHeaders(),
      body: {
        'lessonLocalId': request.lessonLocalId,
        'item': request.item,
        ...locale,
        'stable_lang': locale['explanationLanguage'] ?? request.lang,
        'academic_level': request.academic,
        'layer': request.layer.value,
        'err_count': request.errCount,
        'lesson_mode': request.mode,
        'history': request.history,
        if (request.topic != null) 'topic': request.topic,
        if (request.itemIdx != null) 'itemIdx': request.itemIdx,
        if (request.marker != null) 'marker': request.marker,
        if (request.amparoLvl != null) 'amparo_level': request.amparoLvl,
        if (request.curriculumItems.isNotEmpty)
          'adopt': {
            'topic': request.topic ?? request.profile['target_topic'],
            'profile': {...request.profile, ...locale},
            'curriculumItems': request.curriculumItems,
          },
        ...request.profile,
      },
      timeout: timeout,
    );
    if (!response.ok) {
      throw SimExternalAiException(
        response.body,
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const SimExternalAiException(
        'server classroom retornou resposta invalida.',
      );
    }
    final slot = decoded['slot'];
    if (slot is! Map) {
      throw const SimExternalAiException(
        'server classroom retornou slot ausente.',
      );
    }
    try {
      return _parseServerClassroomSlot(JsonMap.from(slot));
    } on LessonContentValidationException catch (error) {
      throw SimExternalAiException(
        'T02 retornou contrato invalido: ${error.message}',
        statusCode: 502,
      );
    }
  }

  T02LessonMaterial _parseT02Material(JsonMap json) {
    final source = json['conteudo'] is Map
        ? JsonMap.from(json['conteudo'])
        : json;
    final content = validatedLessonContentFromJson(source);
    return T02LessonMaterial(
      explanation: content.explanation,
      question: content.question,
      options: content.options,
      correctAnswer: content.correctAnswer,
      whyCorrect: content.whyCorrect ?? '',
      whyWrong: content.whyWrong,
      generatedAt: DateTime.now(),
      source: (source['source'] ?? 'sim-server-t02').toString(),
      visualTrigger: content.visualTrigger,
    );
  }

  T02LessonMaterial _parseServerClassroomSlot(JsonMap slot) {
    final material = slot['material'];
    if (material is! Map) {
      throw const SimExternalAiException(
        'server classroom retornou material ausente.',
        statusCode: 502,
      );
    }
    final parsed = _parseT02Material(JsonMap.from(material));
    final image = slot['image'];
    final imageMap = image is Map ? JsonMap.from(image) : const {};
    final imageDataUrl = imageMap['dataUrl']?.toString();
    final imageId =
        imageMap['imageId']?.toString() ?? slot['imageId']?.toString();
    return T02LessonMaterial(
      explanation: parsed.explanation,
      question: parsed.question,
      options: parsed.options,
      correctAnswer: parsed.correctAnswer,
      whyCorrect: parsed.whyCorrect,
      whyWrong: parsed.whyWrong,
      generatedAt: parsed.generatedAt,
      source: 'server-classroom',
      visualTrigger: parsed.visualTrigger,
      imageDataUrl: imageDataUrl == null || imageDataUrl.trim().isEmpty
          ? null
          : imageDataUrl.trim(),
      imageId: imageId == null || imageId.trim().isEmpty
          ? null
          : imageId.trim(),
    );
  }

  T02LessonMaterial _parseDoubtResponse(JsonMap json) {
    final answer = (json['answerText'] ?? json['answer'] ?? '')
        .toString()
        .trim();
    if (json['ok'] != true || answer.isEmpty) {
      final human = json['humanError'];
      final message = human is Map
          ? (human['message'] ?? 'Nao conseguimos responder essa duvida agora.')
                .toString()
          : 'Nao conseguimos responder essa duvida agora.';
      throw SimExternalAiException(message, statusCode: 502);
    }
    return T02LessonMaterial(
      explanation: answer,
      question: '',
      options: const {
        AnswerLetter.A: '',
        AnswerLetter.B: '',
        AnswerLetter.C: '',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: '',
      whyWrong: const {},
      generatedAt: DateTime.now(),
      source: (json['source'] ?? 'server-doubt-room').toString(),
    );
  }
}
