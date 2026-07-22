import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_ai_clients.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

class _RecordingTransport implements SimHttpTransport {
  Object? lastBody;

  @override
  Future<SimHttpResponse> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    lastBody = body;
    return const SimHttpResponse(
      statusCode: 200,
      body:
          '{"conteudo":{"explanation":"Explain","question":"Question?","options":{"A":"one","B":"two","C":"three"},"correct_answer":"A","why_correct":"ok","why_wrong":{"B":"no","C":"no"}}}',
    );
  }

  @override
  Stream<String> postEventStream(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 140),
  }) async* {}

  @override
  Future<SimHttpResponse> postMultipart(
    Uri uri, {
    required Map<String, String> headers,
    required String fieldName,
    required String filename,
    required String contentType,
    required List<int> bytes,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  test('T02 payload preserva localeContract e separa idiomas', () async {
    const locale = SimLocaleContract(
      interfaceLocale: 'pt-BR',
      learningLocale: 'en',
      explanationLanguage: 'Portuguese',
      targetLanguage: 'English',
      mediaTextLanguage: 'Portuguese',
      source: SimLocaleSource.userSelected,
    );
    final transport = _RecordingTransport();
    final client = SimServerT02Client(
      config: SimAiServerConfig(
        baseUrl: 'https://example.test',
        accessTokenProvider: () async => 'token',
        t02Path: '/api/sim/t02',
      ),
      transport: transport,
    );

    await client.completeLesson(
      T02LessonRequest(
        lessonLocalId: 'lesson-l3',
        item: 'Present perfect',
        lang: 'Portuguese',
        academic: 'adult',
        layer: LessonLayer.l1,
        mode: 'session',
        errCount: 0,
        history: const [],
        interfaceLocale: locale.interfaceLocale,
        learningLocale: locale.learningLocale,
        explanationLanguage: locale.explanationLanguage,
        targetLanguage: locale.targetLanguage,
        localeContract: locale,
        profile: {
          'language': 'pt-BR',
          'stableLang': 'Portuguese',
          'localeContract': locale.toJson(),
          'pedagogical_entry': {
            'localeContract': locale.toJson(),
            'student_goal': {'objective': 'aprender ingles'},
          },
          'human_summary': 'Objective: aprender ingles',
          'human_summary_locale': 'Portuguese',
        },
      ),
    );

    final body = transport.lastBody as Map;
    expect(body['localeContract'], locale.toJson());
    expect(body['interfaceLocale'], 'pt-BR');
    expect(body['learningLocale'], 'en');
    expect(body['explanationLanguage'], 'Portuguese');
    expect(body['targetLanguage'], 'English');
    expect(body['mediaTextLanguage'], 'Portuguese');
    expect(body['language'], 'en');
    expect(body['language_semantics'], 'learningLocale');
    expect(body['stable_lang'], 'Portuguese');
    expect(body['stable_lang_semantics'], 'explanationLanguage');
    expect(body['pedagogical_entry'], isA<Map>());
  });
}
