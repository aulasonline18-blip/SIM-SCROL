import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/billing/account_deletion.dart';
import 'package:sim_mobile/sim/billing/play_billing_functions.dart';
import 'package:sim_mobile/sim/billing/sim_server_billing_clients.dart';
import 'package:sim_mobile/sim/cloud/cloud_functions.dart';
import 'package:sim_mobile/sim/cloud/sim_server_cloud_functions.dart';
import 'package:sim_mobile/sim/cloud/supabase_client_contract.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  test('M13 app production sources do not contain server secrets', () {
    final files = <File>[
      ...Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
      ...Directory('android')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                _isTextProjectFile(file.path) &&
                !file.path.contains('/.gradle/') &&
                !file.path.contains('/build/') &&
                !file.path.contains('/gradle/wrapper/'),
          ),
    ];
    final source = files.map((file) => file.readAsStringSync()).join('\n');

    for (final forbidden in <Object>[
      'OPENAI_API_KEY',
      'GEMINI_API_KEY',
      'DEEPSEEK_API_KEY',
      'STRIPE_SECRET_KEY',
      'SUPABASE_SERVICE_ROLE',
      'SERVICE_ROLE_KEY',
      RegExp(r'sk-live-[A-Za-z0-9_]{12,}'),
      RegExp(r'sk-proj-[A-Za-z0-9_]{12,}'),
      RegExp(r'AIza[0-9A-Za-z_-]{20,}'),
    ]) {
      if (forbidden is String) {
        expect(source, isNot(contains(forbidden)));
      } else if (forbidden is RegExp) {
        expect(forbidden.hasMatch(source), isFalse);
      }
    }
  });

  test('P1 app does not call AI providers or SIM Web directly', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    final source = files.map((file) => file.readAsStringSync()).join('\n');

    for (final forbidden in <String>[
      'api.openai.com',
      'generativelanguage.googleapis.com',
      'api.anthropic.com',
      '/root/sim-work/sim-web',
      'sim-work/sim-web',
    ]) {
      expect(source, isNot(contains(forbidden)));
    }
  });

  test(
    'M13 billing clients expose human errors without raw JSON or secrets',
    () async {
      final transport = _FakeTransport(
        statusCode: 500,
        body: jsonEncode({
          'error': 'provider failed with token secret-token',
          'stack': 'StackTrace(secret-token)',
          'requestId': 'req-m13',
          'code': 'INTERNAL_PROVIDER_ERROR',
        }),
      );
      final client = SimServerCreditsClient(
        config: _config(),
        transport: transport,
      );

      Object? thrown;
      try {
        await client.getMyCredits();
      } catch (error) {
        thrown = error;
      }

      expect(thrown, isA<SimExternalAiException>());
      final text = thrown.toString();
      expect(text, contains('Não conseguimos concluir esta operação agora'));
      expect(text, contains('requestId=req-m13'));
      expect(text, isNot(contains('secret-token')));
      expect(text, isNot(contains('StackTrace')));
      expect(text, isNot(contains('"error"')));
      expect(text, isNot(contains('{')));
    },
  );

  test(
    'M13 account deletion gateway hides raw server payload from UI',
    () async {
      final gateway = SimServerAccountDeletionGateway(
        config: _config(),
        transport: _FakeTransport(
          statusCode: 403,
          body: '{"error":"forbidden_user","authorization":"Bearer secret"}',
        ),
      );

      Object? thrown;
      try {
        await gateway.requestAccountDeletion(
          const AccountDeletionRequest(
            userId: 'u1',
            confirmation: 'DELETAR',
            emailSnapshot: 'student@example.com',
          ),
        );
      } catch (error) {
        thrown = error;
      }

      expect(thrown, isA<SimExternalAiException>());
      final text = thrown.toString();
      expect(text, contains('Não foi possível confirmar sua autorização'));
      expect(text, isNot(contains('Bearer secret')));
      expect(text, isNot(contains('forbidden_user')));
    },
  );

  test(
    'M13 play billing grant sends token to server but never grants locally',
    () async {
      final transport = _FakeTransport(
        statusCode: 409,
        body: '{"error":"invalid_purchase_token","requestId":"req-play"}',
      );
      final client = SimServerPlayBillingGrantClient(
        config: _config(),
        transport: transport,
      );

      Object? thrown;
      try {
        await client.grantCreditPack(
          const PlayBillingGrantRequest(
            packId: 'credits_100',
            productId: 'sim_credits_100',
            purchaseToken: 'purchase-token-secret',
            verificationSource: 'google_play',
            localVerificationData: '{"orderId":"GPA.fake"}',
            purchaseId: 'GPA.fake',
          ),
        );
      } catch (error) {
        thrown = error;
      }

      expect(transport.lastBody?['purchaseToken'], 'purchase-token-secret');
      expect(thrown, isA<SimExternalAiException>());
      expect(thrown.toString(), isNot(contains('purchase-token-secret')));
    },
  );

  test(
    'M13 student-state 409 regression returns remoteState contract',
    () async {
      final remote = StudentLearningState.empty(
        lessonLocalId: 'lesson-409',
      ).copyWith(updatedAt: 10);
      final transport = _FakeTransport(
        statusCode: 409,
        body: jsonEncode({
          'rejected': true,
          'reason': 'STATE_EVENTS_REGRESSION',
          'remoteState': remote.toJson(),
          'remoteHighWaterMark': 77,
        }),
      );
      final client = SimServerCloudFunctions(
        config: _config(),
        transport: transport,
      );

      final result = await client.persistStudentState(
        PersistStudentStateInput(
          lessonLocalId: 'lesson-409',
          state: StudentLearningState.empty(lessonLocalId: 'lesson-409'),
          clientUpdatedAt: 1,
          clientScore: 1,
        ),
        const SupabaseSession(accessToken: 'token', userId: 'u1'),
      );

      expect(result.rejected, isTrue);
      expect(result.remoteState?.lessonLocalId, 'lesson-409');
      expect(result.remoteHighWaterMark, 77);
    },
  );
}

bool _isTextProjectFile(String path) {
  return path.endsWith('.dart') ||
      path.endsWith('.kt') ||
      path.endsWith('.kts') ||
      path.endsWith('.xml') ||
      path.endsWith('.properties') ||
      path.endsWith('.gradle') ||
      path.endsWith('.yaml') ||
      path.endsWith('.json') ||
      path.endsWith('.md') ||
      path.endsWith('.txt');
}

SimAiServerConfig _config() => SimAiServerConfig(
  baseUrl: 'https://sim.test',
  accessTokenProvider: () async => 'access-token',
);

class _FakeTransport implements SimHttpTransport {
  _FakeTransport({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
  Map<String, dynamic>? lastBody;

  @override
  Future<SimHttpResponse> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (body is Map) lastBody = Map<String, dynamic>.from(body);
    return SimHttpResponse(statusCode: statusCode, body: this.body);
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
    return SimHttpResponse(statusCode: statusCode, body: body);
  }
}
