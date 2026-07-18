import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/billing/account_deletion.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/billing/checkout_return_controller.dart';
import 'package:sim_mobile/sim/billing/credits_functions.dart';
import 'package:sim_mobile/sim/billing/credits_route_controller.dart';
import 'package:sim_mobile/sim/billing/payment_return_store.dart';
import 'package:sim_mobile/sim/billing/payment_webhook_contract.dart';
import 'package:sim_mobile/sim/billing/payments_functions.dart';
import 'package:sim_mobile/sim/billing/play_billing_functions.dart';
import 'package:sim_mobile/sim/billing/sim_pricing.dart';

import 'support/memory_test_stores.dart';

class FakeCreditsFunctions implements CreditsFunctions {
  @override
  Future<int> chargeLessonGeneration(ChargeLessonGenerationInput input) async {
    return 7;
  }

  @override
  Future<CreditsSnapshot> getMyCredits() async {
    return const CreditsSnapshot(
      balance: 12,
      lifetimeEarned: 20,
      lifetimeSpent: 8,
    );
  }
}

class FakePaymentsFunctions implements PaymentsFunctions {
  HostedCheckoutResult hostedResult = const HostedCheckoutResult.success(
    url: 'https://checkout.stripe.com/c/pay/cs_test_123',
    sessionId: 'cs_test_123',
  );
  CheckoutStatus checkoutStatus = const CheckoutStatus.complete(
    credits: 100,
    balance: 112,
  );

  @override
  Future<EmbeddedCheckoutResult> createCreditsCheckoutEmbedded(
    CreateCreditsCheckoutEmbeddedInput input,
  ) async {
    return const EmbeddedCheckoutResult.success('secret');
  }

  @override
  Future<HostedCheckoutResult> createCreditsCheckoutHosted(
    CreateCreditsCheckoutHostedInput input,
  ) async {
    return hostedResult;
  }

  @override
  Future<CheckoutStatus> getCheckoutStatus({
    required String sessionId,
    required StripeEnvironment environment,
  }) async {
    return checkoutStatus;
  }
}

class FakeDeletionGateway implements AccountDeletionGateway {
  AccountDeletionRequest? request;
  Object? failure;

  @override
  Future<void> requestAccountDeletion(AccountDeletionRequest request) async {
    this.request = request;
    final error = failure;
    if (error != null) throw error;
  }
}

class FakePlayBillingFunctions implements PlayBillingFunctions {
  PlayBillingPurchaseOutcome outcome =
      const PlayBillingPurchaseOutcome.completed(credits: 100, balance: 112);
  CreditPackId? purchasedPack;
  bool disposed = false;

  @override
  Future<PlayBillingPurchaseOutcome> purchaseCreditPack(
    CreditPackId packId,
  ) async {
    purchasedPack = packId;
    return outcome;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  test('official pricing preserves live packs and costs', () {
    expect(simPricing.currency, 'brl');
    expect(simPricing.lessonCostCredits, 3);
    expect(simPricing.imageCostCredits, 10);
    expect(simPricing.signupBonusCredits, 9);
    expect(simPricing.getPackOrThrow('credits_100').amountCents, 790);
    expect(simPricing.getPackOrThrow('credits_200').credits, 200);
    expect(simPricing.getPackOrThrow('credits_500').amountCents, 3950);
  });

  test('Google Play product ids are stable for Play Console products', () {
    expect(CreditPackId.credits100.googlePlayProductId, 'sim_credits_100');
    expect(CreditPackId.credits200.googlePlayProductId, 'sim_credits_200');
    expect(CreditPackId.credits500.googlePlayProductId, 'sim_credits_500');
    expect(
      creditPackIdFromGooglePlayProduct('sim_credits_200'),
      CreditPackId.credits200,
    );
    expect(creditPackIdFromGooglePlayProduct('stripe_credits_200'), isNull);
  });

  test('payment return store accepts only safe internal paths', () {
    final store = PaymentReturnStore(storage: MemoryPaymentReturnStorage());

    store.saveReturnTo('/cyber/aula');
    expect(store.readReturnTo(), '/cyber/aula');
    store.saveReturnTo('//evil.com');
    expect(store.readReturnTo(), '/cyber/aula');
    store.saveReturnTo('/creditos');
    expect(store.readReturnTo(), '/cyber/aula');
    store.clearReturnTo();
    expect(store.readReturnTo(), isNull);
  });

  test(
    'credits route opens hosted Stripe checkout from pack id only',
    () async {
      final controller = CreditsRouteController(
        creditsFunctions: FakeCreditsFunctions(),
        paymentsFunctions: FakePaymentsFunctions(),
        returnStore: PaymentReturnStore(storage: MemoryPaymentReturnStorage()),
      );

      controller.preserveReturnTo('/cyber/aula');
      await controller.loadCredits();
      await controller.handlePackClick(
        packId: CreditPackId.credits100,
        origin: 'https://gemini-aid-pal.lovable.app',
      );

      expect(controller.state.balance, 12);
      expect(
        controller.state.redirectUrl,
        startsWith('https://checkout.stripe.com/'),
      );
    },
  );

  test('credits route preserves embedded rollback mode', () async {
    final controller = CreditsRouteController(
      creditsFunctions: FakeCreditsFunctions(),
      paymentsFunctions: FakePaymentsFunctions(),
      returnStore: PaymentReturnStore(storage: MemoryPaymentReturnStorage()),
      checkoutMode: CheckoutMode.embedded,
    );

    await controller.handlePackClick(
      packId: CreditPackId.credits200,
      origin: 'https://app.test',
    );

    expect(controller.state.checkoutPack, CreditPackId.credits200);
  });

  test(
    'checkout return validates session and restores saved return target',
    () async {
      final store = PaymentReturnStore(storage: MemoryPaymentReturnStorage())
        ..saveReturnTo('/cyber/aula');
      final controller = CheckoutReturnController(
        paymentsFunctions: FakePaymentsFunctions(),
        returnStore: store,
      );

      final state = await controller.confirm('cs_test_123');
      expect(state.status, CheckoutStatusKind.complete);
      expect(state.credits, 100);
      expect(controller.continueTarget(), '/cyber/aula');
      expect(store.readReturnTo(), isNull);
    },
  );

  test('checkout return invalid session uses human message', () async {
    final store = PaymentReturnStore(storage: MemoryPaymentReturnStorage())
      ..saveReturnTo('/cyber/aula');
    final controller = CheckoutReturnController(
      paymentsFunctions: FakePaymentsFunctions(),
      returnStore: store,
    );

    final state = await controller.confirm('invalid session id');

    expect(state.status, CheckoutStatusKind.error);
    expect(state.error, 'Não foi possível confirmar esse pagamento agora.');
    expect(state.error, isNot(contains('Invalid sessionId')));
  });

  test(
    'webhook grant uses official pack credits and ignores unpaid sessions',
    () {
      final grant = grantFromCheckoutCompleted(
        const StripeWebhookSession(
          id: 'cs_1',
          paymentStatus: 'paid',
          metadata: {'userId': 'u1', 'packId': 'credits_500', 'credits': '999'},
        ),
      );

      expect(grant?.credits, 500);
      expect(parseWebhookEnvironment('live'), StripeEnvironment.live);
      expect(
        grantFromCheckoutCompleted(
          const StripeWebhookSession(
            id: 'cs_2',
            paymentStatus: 'unpaid',
            metadata: {'userId': 'u1', 'packId': 'credits_100'},
          ),
        ),
        isNull,
      );
    },
  );

  test('account deletion requires DELETAR and records request', () async {
    final gateway = FakeDeletionGateway();
    final controller = AccountDeletionController(gateway: gateway);

    await controller.submit(
      confirm: 'deletar',
      userId: 'u1',
      email: 'a@test.com',
    );
    expect(gateway.request, isNull);
    await controller.submit(
      confirm: 'DELETAR',
      userId: 'u1',
      email: 'a@test.com',
    );
    expect(controller.done, true);
    expect(gateway.request?.confirmation, 'DELETAR');
    expect(gateway.request?.reason, 'user_requested_account_deletion');
    expect(
      const DeleteAccountTexts().submitLabel,
      'Solicitar exclusao da conta',
    );
  });

  test('account deletion controller hides raw thrown errors from UI', () async {
    final gateway = FakeDeletionGateway()
      ..failure = StateError('raw server body token secret');
    final controller = AccountDeletionController(gateway: gateway);

    await controller.submit(confirm: 'DELETAR', userId: 'u1');

    expect(controller.done, false);
    expect(controller.error, 'Não foi possível registrar a solicitação.');
    expect(controller.error, isNot(contains('raw server body')));
    expect(controller.error, isNot(contains('token secret')));
  });

  test(
    'lab session sends authenticated account deletion to server gateway',
    () async {
      final gateway = FakeDeletionGateway();
      final session = LabSession(accountDeletionGateway: gateway)
        ..authed = true
        ..authReady = true;
      session.authSession.userId = 'u-session';
      session.authSession.userEmail = 'session@test.com';

      session.setDeleteConfirmation('DELETAR');
      session.requestAccountDeletion();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(gateway.request?.userId, 'u-session');
      expect(gateway.request?.confirmation, 'DELETAR');
      expect(gateway.request?.emailSnapshot, 'session@test.com');
    },
  );

  test(
    'lab session production billing uses Google Play flow instead of Stripe',
    () async {
      final play = FakePlayBillingFunctions();
      final session =
          LabSession(
              playBillingFunctions: play,
              creditsFunctions: FakeCreditsFunctions(),
            )
            ..authed = true
            ..authReady = true;
      session.authSession.userId = 'u-billing';

      final error = await session.startCreditsCheckout('credits_100');

      expect(error, isNull);
      expect(play.purchasedPack, CreditPackId.credits100);
      expect(session.credits, 112);
    },
  );

  test('lab session does not start billing when auth is missing', () async {
    final play = FakePlayBillingFunctions();
    final session = LabSession(
      playBillingFunctions: play,
      creditsFunctions: FakeCreditsFunctions(),
    );

    final error = await session.startCreditsCheckout('credits_100');

    expect(error, 'login_required');
    expect(play.purchasedPack, isNull);
  });

  test(
    'lab session surfaces Google Play pending and canceled states',
    () async {
      final play = FakePlayBillingFunctions();
      final session =
          LabSession(
              playBillingFunctions: play,
              creditsFunctions: FakeCreditsFunctions(),
            )
            ..authed = true
            ..authReady = true;
      session.authSession.userId = 'u-billing';

      play.outcome = const PlayBillingPurchaseOutcome.pending();
      expect(
        await session.startCreditsCheckout('credits_200'),
        'Compra pendente no Google Play.',
      );

      play.outcome = const PlayBillingPurchaseOutcome.canceled();
      expect(
        await session.startCreditsCheckout('credits_200'),
        'Compra cancelada.',
      );
    },
  );

  test('charge lesson input normalizes ids like server validator', () {
    final input = ChargeLessonGenerationInput(
      lessonLocalId: 'x' * 200,
      legacyLessonLocalIds: [' ', 'a', 'b' * 200],
    ).normalized();

    expect(input.lessonLocalId.length, 160);
    expect(input.legacyLessonLocalIds.length, 2);
    expect(input.legacyLessonLocalIds.last.length, 160);
  });
}
