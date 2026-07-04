import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'sim_pricing.dart';

enum PlayBillingPurchaseStatus { completed, pending, canceled, failed }

class PlayBillingPurchaseOutcome {
  const PlayBillingPurchaseOutcome.completed({
    required this.credits,
    required this.balance,
  }) : status = PlayBillingPurchaseStatus.completed,
       error = null;

  const PlayBillingPurchaseOutcome.pending()
    : status = PlayBillingPurchaseStatus.pending,
      credits = 0,
      balance = 0,
      error = null;

  const PlayBillingPurchaseOutcome.canceled()
    : status = PlayBillingPurchaseStatus.canceled,
      credits = 0,
      balance = 0,
      error = null;

  const PlayBillingPurchaseOutcome.failed(this.error)
    : status = PlayBillingPurchaseStatus.failed,
      credits = 0,
      balance = 0;

  final PlayBillingPurchaseStatus status;
  final int credits;
  final int balance;
  final String? error;
}

class PlayBillingGrantRequest {
  const PlayBillingGrantRequest({
    required this.packId,
    required this.productId,
    required this.purchaseToken,
    required this.verificationSource,
    required this.localVerificationData,
    this.purchaseId,
  });

  final String packId;
  final String productId;
  final String purchaseToken;
  final String verificationSource;
  final String localVerificationData;
  final String? purchaseId;
}

class PlayBillingGrantResult {
  const PlayBillingGrantResult({required this.credits, required this.balance});

  final int credits;
  final int balance;
}

abstract interface class PlayBillingGrantGateway {
  Future<PlayBillingGrantResult> grantCreditPack(
    PlayBillingGrantRequest request,
  );
}

abstract interface class PlayBillingFunctions {
  Future<PlayBillingPurchaseOutcome> purchaseCreditPack(CreditPackId packId);

  Future<void> dispose();
}

extension CreditPackGooglePlayProduct on CreditPackId {
  String get googlePlayProductId => switch (this) {
    CreditPackId.credits100 => 'sim_credits_100',
    CreditPackId.credits200 => 'sim_credits_200',
    CreditPackId.credits500 => 'sim_credits_500',
  };
}

CreditPackId? creditPackIdFromGooglePlayProduct(String productId) {
  for (final id in CreditPackId.values) {
    if (id.googlePlayProductId == productId) return id;
  }
  return null;
}

class GooglePlayBillingFunctions implements PlayBillingFunctions {
  GooglePlayBillingFunctions({
    required this.grantGateway,
    InAppPurchase? store,
    this._purchaseTimeout = const Duration(minutes: 2),
  }) : _store = store ?? InAppPurchase.instance {
    _subscription = _store.purchaseStream.listen(_handlePurchaseUpdates);
  }

  final PlayBillingGrantGateway grantGateway;
  final InAppPurchase _store;
  final Duration _purchaseTimeout;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<PlayBillingPurchaseOutcome>? _activePurchase;
  CreditPackId? _activePackId;

  @override
  Future<PlayBillingPurchaseOutcome> purchaseCreditPack(
    CreditPackId packId,
  ) async {
    if (!Platform.isAndroid) {
      return const PlayBillingPurchaseOutcome.failed(
        'google_play_billing_android_only',
      );
    }
    if (_activePurchase != null) {
      return const PlayBillingPurchaseOutcome.failed('purchase_already_active');
    }
    final available = await _store.isAvailable();
    if (!available) {
      return const PlayBillingPurchaseOutcome.failed(
        'google_play_billing_unavailable',
      );
    }
    final productId = packId.googlePlayProductId;
    final products = await _store.queryProductDetails({productId});
    if (products.error != null) {
      return PlayBillingPurchaseOutcome.failed(
        products.error!.message.isEmpty
            ? products.error!.code
            : products.error!.message,
      );
    }
    if (products.notFoundIDs.contains(productId) ||
        products.productDetails.isEmpty) {
      return PlayBillingPurchaseOutcome.failed(
        'google_play_product_not_found:$productId',
      );
    }
    final completer = Completer<PlayBillingPurchaseOutcome>();
    _activePurchase = completer;
    _activePackId = packId;
    final sent = await _store.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: products.productDetails[0]),
      autoConsume: false,
    );
    if (!sent) {
      _clearActivePurchase();
      return const PlayBillingPurchaseOutcome.failed(
        'google_play_purchase_not_started',
      );
    }
    return completer.future.timeout(
      _purchaseTimeout,
      onTimeout: () {
        _clearActivePurchase();
        return const PlayBillingPurchaseOutcome.failed(
          'google_play_purchase_timeout',
        );
      },
    );
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (creditPackIdFromGooglePlayProduct(purchase.productID) == null) {
        continue;
      }
      await _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    final completer = _activePurchase;
    if (completer == null || completer.isCompleted) return;
    if (purchase.status == PurchaseStatus.pending) {
      completer.complete(const PlayBillingPurchaseOutcome.pending());
      _clearActivePurchase();
      return;
    }
    if (purchase.status == PurchaseStatus.canceled) {
      completer.complete(const PlayBillingPurchaseOutcome.canceled());
      _clearActivePurchase();
      return;
    }
    if (purchase.status == PurchaseStatus.error) {
      completer.complete(
        PlayBillingPurchaseOutcome.failed(
          purchase.error?.message ?? purchase.error?.code ?? 'purchase_error',
        ),
      );
      _clearActivePurchase();
      return;
    }
    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      return;
    }
    final packId =
        _activePackId ?? creditPackIdFromGooglePlayProduct(purchase.productID);
    if (packId == null) {
      completer.complete(
        PlayBillingPurchaseOutcome.failed(
          'unknown_google_play_product:${purchase.productID}',
        ),
      );
      _clearActivePurchase();
      return;
    }
    try {
      final grant = await grantGateway.grantCreditPack(
        PlayBillingGrantRequest(
          packId: packId.wire,
          productId: purchase.productID,
          purchaseToken: purchase.verificationData.serverVerificationData,
          verificationSource: purchase.verificationData.source,
          localVerificationData:
              purchase.verificationData.localVerificationData,
          purchaseId: purchase.purchaseID,
        ),
      );
      if (Platform.isAndroid) {
        final android = _store
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        await android.consumePurchase(purchase);
      }
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      completer.complete(
        PlayBillingPurchaseOutcome.completed(
          credits: grant.credits,
          balance: grant.balance,
        ),
      );
    } catch (error) {
      completer.complete(PlayBillingPurchaseOutcome.failed(error.toString()));
    } finally {
      _clearActivePurchase();
    }
  }

  void _clearActivePurchase() {
    _activePurchase = null;
    _activePackId = null;
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}

class DisabledPlayBillingFunctions implements PlayBillingFunctions {
  const DisabledPlayBillingFunctions();

  @override
  Future<PlayBillingPurchaseOutcome> purchaseCreditPack(CreditPackId packId) {
    return Future.value(
      const PlayBillingPurchaseOutcome.failed('play_billing_not_configured'),
    );
  }

  @override
  Future<void> dispose() async {}
}
