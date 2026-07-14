import 'dart:convert';

import '../external_ai/sim_ai_server_config.dart';
import '../external_ai/sim_http_transport.dart';
import '../state/student_learning_state.dart';
import 'account_deletion.dart';
import 'credits_functions.dart';
import 'payments_functions.dart';
import 'play_billing_functions.dart';
import 'sim_pricing.dart';

class SimServerPaymentsClient implements PaymentsFunctions {
  SimServerPaymentsClient({
    required this.config,
    SimHttpTransport? transport,
    this.hostedPath = '/api/payments/create-credits-checkout-hosted',
    this.embeddedPath = '/api/payments/create-credits-checkout',
    this.statusPath = '/api/payments/checkout-status',
    this.timeout = const Duration(seconds: 45),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final String hostedPath;
  final String embeddedPath;
  final String statusPath;
  final Duration timeout;

  @override
  Future<HostedCheckoutResult> createCreditsCheckoutHosted(
    CreateCreditsCheckoutHostedInput input,
  ) async {
    final data = await _post(hostedPath, {
      'packId': input.validate().packId,
      'successUrl': input.successUrl,
      'cancelUrl': input.cancelUrl,
      'environment': input.environment.wire,
    });
    if (data['error'] != null) {
      return HostedCheckoutResult.failure(data['error'].toString());
    }
    return HostedCheckoutResult.success(
      url: (data['url'] ?? '').toString(),
      sessionId: (data['sessionId'] ?? '').toString(),
    );
  }

  @override
  Future<EmbeddedCheckoutResult> createCreditsCheckoutEmbedded(
    CreateCreditsCheckoutEmbeddedInput input,
  ) async {
    final data = await _post(embeddedPath, {
      'packId': input.validate().packId,
      'returnUrl': input.returnUrl,
      'environment': input.environment.wire,
    });
    if (data['error'] != null) {
      return EmbeddedCheckoutResult.failure(data['error'].toString());
    }
    return EmbeddedCheckoutResult.success(
      (data['clientSecret'] ?? '').toString(),
    );
  }

  @override
  Future<CheckoutStatus> getCheckoutStatus({
    required String sessionId,
    required StripeEnvironment environment,
  }) async {
    if (!isValidStripeSessionId(sessionId)) {
      return const CheckoutStatus.failure('Invalid sessionId');
    }
    final data = await _post(statusPath, {
      'sessionId': sessionId,
      'environment': environment.wire,
    });
    if (data['error'] != null) {
      return CheckoutStatus.failure(data['error'].toString());
    }
    return switch (data['status']?.toString()) {
      'complete' => CheckoutStatus.complete(
        credits: (data['credits'] as num?)?.toInt() ?? 0,
        balance: (data['balance'] as num?)?.toInt() ?? 0,
      ),
      'expired' => const CheckoutStatus.expired(),
      _ => const CheckoutStatus.pending(),
    };
  }

  Future<JsonMap> _post(String path, Object body) async {
    final response = await transport.postJson(
      config.uri(path),
      headers: await config.jsonHeaders(),
      body: body,
      timeout: timeout,
    );
    if (!response.ok) {
      throw _safeBillingException(response);
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map ? JsonMap.from(decoded) : <String, dynamic>{};
  }
}

class SimServerCreditsClient implements CreditsFunctions {
  SimServerCreditsClient({
    required this.config,
    SimHttpTransport? transport,
    this.snapshotPath = '/api/credits/me',
    this.reservePath = '/api/credits/reserve',
    this.capturePath = '/api/credits/capture',
    this.timeout = const Duration(seconds: 30),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final String snapshotPath;
  final String reservePath;
  final String capturePath;
  final Duration timeout;

  @override
  Future<CreditsSnapshot> getMyCredits() async {
    final data = await _post(snapshotPath, const {});
    return CreditsSnapshot(
      balance: (data['balance'] as num?)?.toInt() ?? 0,
      lifetimeEarned: (data['lifetimeEarned'] as num?)?.toInt() ?? 0,
      lifetimeSpent: (data['lifetimeSpent'] as num?)?.toInt() ?? 0,
      email: data['email']?.toString(),
      displayName: data['displayName']?.toString(),
      testCreditMode: data['testCreditMode'] == true,
    );
  }

  @override
  Future<int> chargeLessonGeneration(ChargeLessonGenerationInput input) async {
    final normalized = input.normalized();
    final operationId = [
      'lesson-generation',
      normalized.lessonLocalId,
      ...normalized.legacyLessonLocalIds,
    ].join(':');
    final reserve = await _post(reservePath, {
      'cost': simPricing.lessonCostCredits,
      'reason': 'lesson',
      'operationId': operationId,
    });
    final reservationId = reserve['reservationId']?.toString();
    if (reservationId != null && reservationId.isNotEmpty) {
      await _post(capturePath, {'reservationId': reservationId});
    }
    return (reserve['balance'] as num?)?.toInt() ?? 0;
  }

  Future<JsonMap> _post(String path, Object body) async {
    final response = await transport.postJson(
      config.uri(path),
      headers: await config.jsonHeaders(),
      body: body,
      timeout: timeout,
    );
    if (!response.ok) {
      throw _safeBillingException(response);
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map ? JsonMap.from(decoded) : <String, dynamic>{};
  }
}

class SimServerPlayBillingGrantClient implements PlayBillingGrantGateway {
  SimServerPlayBillingGrantClient({
    required this.config,
    SimHttpTransport? transport,
    this.grantPath = '/api/play-billing/consume-credit-pack',
    this.timeout = const Duration(seconds: 45),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final String grantPath;
  final Duration timeout;

  @override
  Future<PlayBillingGrantResult> grantCreditPack(
    PlayBillingGrantRequest request,
  ) async {
    final response = await transport.postJson(
      config.uri(grantPath),
      headers: await config.jsonHeaders(),
      body: {
        'packId': request.packId,
        'productId': request.productId,
        'purchaseToken': request.purchaseToken,
        'verificationSource': request.verificationSource,
        'localVerificationData': request.localVerificationData,
        if ((request.purchaseId ?? '').isNotEmpty)
          'purchaseId': request.purchaseId,
      },
      timeout: timeout,
    );
    if (!response.ok) {
      throw _safeBillingException(response);
    }
    final decoded = jsonDecode(response.body);
    final data = decoded is Map ? JsonMap.from(decoded) : <String, dynamic>{};
    if (data['error'] != null) {
      throw SimExternalAiException(data['error'].toString());
    }
    return PlayBillingGrantResult(
      credits: (data['credits'] as num?)?.toInt() ?? 0,
      balance: (data['balance'] as num?)?.toInt() ?? 0,
    );
  }
}

class SimServerAccountDeletionGateway implements AccountDeletionGateway {
  SimServerAccountDeletionGateway({
    required this.config,
    SimHttpTransport? transport,
    this.path = '/api/account/request-deletion',
    this.timeout = const Duration(seconds: 30),
  }) : transport = transport ?? DartIoSimHttpTransport();

  final SimAiServerConfig config;
  final SimHttpTransport transport;
  final String path;
  final Duration timeout;

  @override
  Future<void> requestAccountDeletion(AccountDeletionRequest request) async {
    final response = await transport.postJson(
      config.uri(path),
      headers: await config.jsonHeaders(),
      body: {
        'userId': request.userId,
        'confirmation': request.confirmation,
        if (request.emailSnapshot != null) 'email': request.emailSnapshot,
        'reason': request.reason,
      },
      timeout: timeout,
    );
    if (!response.ok) {
      throw _safeBillingException(response);
    }
  }
}

SimExternalAiException _safeBillingException(SimHttpResponse response) {
  var code = 'SERVER_ERROR';
  String? requestId;
  var retryable = response.statusCode >= 500 || response.statusCode == 429;
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map) {
      code = (decoded['code'] ?? decoded['error'] ?? code).toString();
      requestId = decoded['requestId']?.toString();
      if (decoded['retryable'] is bool) {
        retryable = decoded['retryable'] as bool;
      }
    }
  } catch (_) {
    // Corpo invalido fica oculto para a UI.
  }
  return SimExternalAiException(
    _humanBillingError(response.statusCode),
    statusCode: response.statusCode,
    requestId: requestId,
    code: _safePublicCode(code),
    retryable: retryable,
  );
}

String _safePublicCode(String code) {
  final raw = code.trim();
  if (!RegExp(r'^[A-Z0-9_]{3,80}$').hasMatch(raw)) return 'SERVER_ERROR';
  return raw;
}

String _humanBillingError(int statusCode) {
  if (statusCode == 401) {
    return 'Sua sessão expirou. Entre novamente para continuar.';
  }
  if (statusCode == 403) {
    return 'Não foi possível confirmar sua autorização para esta ação.';
  }
  if (statusCode == 409) {
    return 'Não foi possível concluir esta ação agora. Tente novamente.';
  }
  if (statusCode == 429) {
    return 'Muitas tentativas em pouco tempo. Aguarde um instante e tente novamente.';
  }
  return 'Não conseguimos concluir esta operação agora. Tente novamente.';
}
