import 'package:flutter/foundation.dart';

import 'sim_api_routes.dart';

class SimEnvironment {
  const SimEnvironment._();

  static const appMode = String.fromEnvironment(
    'FLUTTER_APP_MODE',
    defaultValue: 'development',
  );

  static const configuredApiBaseUrl = String.fromEnvironment(
    'SIM_SERVER_URL',
    defaultValue: '',
  );

  static const devApiBaseUrl = String.fromEnvironment(
    'SIM_DEV_SERVER_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    final configured = configuredApiBaseUrl.trim();
    if (configured.isNotEmpty) return configured;
    final dev = devApiBaseUrl.trim();
    if (!isProduction && dev.isNotEmpty) return dev;
    if (!isProduction) return 'http://127.0.0.1:3000';
    throw StateError(
      'SIM_SERVER_URL precisa ser definido. Use HTTPS em production; use SIM_DEV_SERVER_URL apenas em desenvolvimento.',
    );
  }

  static const checkoutReturnOrigin = String.fromEnvironment(
    'SIM_CHECKOUT_RETURN_ORIGIN',
    defaultValue: '',
  );

  static const stripeEnvironment = String.fromEnvironment(
    'SIM_STRIPE_ENVIRONMENT',
    defaultValue: 'sandbox',
  );

  static const billingProvider = String.fromEnvironment(
    'SIM_BILLING_PROVIDER',
    defaultValue: 'google_play',
  );

  static bool get useGooglePlayBilling => billingProvider == 'google_play';

  static bool get allowHttpInDevelopment {
    if (kReleaseMode) return false;
    return const bool.fromEnvironment(
      'SIM_ALLOW_HTTP_IN_DEVELOPMENT',
      defaultValue: false,
    );
  }

  static bool get isProduction => appMode == 'production';

  static void assertProductionSafe() {
    validateServerUrl(apiBaseUrl);
    if (isProduction && !useGooglePlayBilling) {
      throw StateError(
        'Build Google Play production deve usar SIM_BILLING_PROVIDER=google_play.',
      );
    }
  }

  static String validateServerUrl(String url) {
    final clean = url.trim();
    final uri = Uri.tryParse(clean);
    final isLocalDevelopmentHost =
        uri != null && (uri.host == '127.0.0.1' || uri.host == 'localhost');
    if (clean.startsWith('http://') &&
        (kReleaseMode ||
            isProduction ||
            (!allowHttpInDevelopment && !isLocalDevelopmentHost))) {
      throw StateError('SIM_SERVER_URL precisa usar HTTPS em production.');
    }
    return clean;
  }

  static const t00Path = SimApiRoutes.t00Bootstrap;
  static const t02Path = SimApiRoutes.t02CompleteLesson;
  static const audioPath = SimApiRoutes.generateLessonAudio;
}
