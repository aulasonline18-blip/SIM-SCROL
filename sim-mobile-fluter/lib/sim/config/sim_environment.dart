class SimEnvironment {
  const SimEnvironment._();

  static const appMode = String.fromEnvironment(
    'FLUTTER_APP_MODE',
    defaultValue: 'development',
  );

  static const configuredApiBaseUrl = String.fromEnvironment(
    'SIM_SERVER_URL',
    defaultValue: 'https://gemini-aid-pal.lovable.app',
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
    throw StateError(
      'SIM_SERVER_URL precisa ser definido. Use HTTPS em production; use SIM_DEV_SERVER_URL apenas em desenvolvimento.',
    );
  }

  static const checkoutReturnOrigin = String.fromEnvironment(
    'SIM_CHECKOUT_RETURN_ORIGIN',
    defaultValue: 'https://gemini-aid-pal.lovable.app',
  );

  static const stripeEnvironment = String.fromEnvironment(
    'SIM_STRIPE_ENVIRONMENT',
    defaultValue: 'sandbox',
  );

  static const allowHttpInProduction = bool.fromEnvironment(
    'SIM_ALLOW_HTTP_IN_PRODUCTION',
    defaultValue: false,
  );

  static bool get isProduction => appMode == 'production';

  static void assertProductionSafe() {
    final url = apiBaseUrl;
    if (isProduction && !url.startsWith('https://') && !allowHttpInProduction) {
      throw StateError('SIM_SERVER_URL precisa usar HTTPS em production.');
    }
  }

  static const t00Path = '/api/bootstrap-t00';
  static const t02Path = '/api/complete-lesson';
  static const imagePath = '/api/generate-lesson-image';
  static const audioPath = '/api/generate-lesson-audio';
}
