import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/billing/play_billing_functions.dart';
import 'package:sim_mobile/sim/billing/sim_server_billing_clients.dart';
import 'package:sim_mobile/sim/billing/sim_pricing.dart';
import 'package:sim_mobile/sim/config/sim_environment.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';

void main() {
  test('M17 Android manifest keeps Play permissions minimal and justified', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.permission.CAMERA'));
    expect(manifest, contains('android.permission.READ_MEDIA_IMAGES'));
    expect(manifest, contains('android.permission.READ_EXTERNAL_STORAGE'));
    expect(manifest, contains('android:maxSdkVersion="32"'));
    expect(manifest, isNot(contains('android.permission.RECORD_AUDIO')));
    expect(manifest, isNot(contains('android.permission.ACCESS_FINE_LOCATION')));
    expect(manifest, isNot(contains('android.permission.READ_CONTACTS')));
    expect(manifest, isNot(contains('android.permission.SEND_SMS')));
    expect(manifest, isNot(contains('android.permission.QUERY_ALL_PACKAGES')));
    expect(manifest, isNot(contains('android:usesCleartextTraffic="true"')));
  });

  test('M17 Android release build identity and signing are configurable', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      gradle,
      contains(
        'val simApplicationId = stringProperty("SIM_ANDROID_APPLICATION_ID", "com.example.sim_mobile")',
      ),
    );
    expect(gradle, contains('applicationId = simApplicationId'));
    expect(gradle, contains('SIM_REQUIRE_RELEASE_SIGNING'));
    expect(gradle, contains('android/key.properties'));
    expect(gradle, contains('versionCode = flutter.versionCode'));
    expect(gradle, contains('versionName = flutter.versionName'));
    expect(pubspec, contains('version: 1.0.0+5'));
  });

  test('M17 production environment requires HTTPS and Google Play billing', () {
    expect(SimEnvironment.billingProvider, 'google_play');
    expect(SimEnvironment.useGooglePlayBilling, true);

    final source = File('lib/sim/config/sim_environment.dart').readAsStringSync();
    expect(source, contains("SIM_SERVER_URL precisa usar HTTPS em production."));
    expect(
      source,
      contains(
        'Build Google Play production deve usar SIM_BILLING_PROVIDER=google_play.',
      ),
    );
  });

  test('M17 app sends Play purchases to the server verifier route', () {
    final client = SimServerPlayBillingGrantClient(
      config: SimAiServerConfig(
        baseUrl: 'https://api.sim.test',
        accessTokenProvider: () async => 'token',
      ),
    );

    expect(client.grantPath, '/api/play-billing/consume-credit-pack');
    expect(CreditPackId.credits100.googlePlayProductId, 'sim_credits_100');
    expect(CreditPackId.credits200.googlePlayProductId, 'sim_credits_200');
    expect(CreditPackId.credits500.googlePlayProductId, 'sim_credits_500');
  });

  test('M17 network security disables cleartext traffic by default', () {
    final network = File(
      'android/app/src/main/res/xml/network_security_config.xml',
    ).readAsStringSync();

    expect(network, contains('cleartextTrafficPermitted="false"'));
  });

  test('M17 Google Play documents cover required store declarations', () {
    final requiredDocs = <String>[
      'docs/google-play/privacy-policy.md',
      'docs/google-play/account-deletion.md',
      'docs/google-play/data-safety.md',
      'docs/google-play/play-billing-implementation.md',
      'docs/google-play/release-readiness-checklist.md',
    ];

    for (final path in requiredDocs) {
      expect(File(path).existsSync(), true, reason: path);
    }

    final privacy = File('docs/google-play/privacy-policy.md').readAsStringSync();
    final deletion = File('docs/google-play/account-deletion.md').readAsStringSync();
    final dataSafety = File('docs/google-play/data-safety.md').readAsStringSync();
    final billing = File(
      'docs/google-play/play-billing-implementation.md',
    ).readAsStringSync();

    expect(privacy, contains('IA'));
    expect(privacy, contains('Google Play'));
    expect(deletion, contains('Conta -> Solicitar exclusao da conta'));
    expect(dataSafety, contains('App activity'));
    expect(dataSafety, contains('Progresso, respostas, eventos de aula'));
    expect(billing, contains('Google Play Billing'));
  });

  test('M17 app source does not contain committed production secrets', () {
    final files = <File>[
      ...Directory('lib').listSync(recursive: true).whereType<File>(),
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

    for (final pattern in <RegExp>[
      RegExp(r'sk-live-[A-Za-z0-9_]{12,}'),
      RegExp(r'sk-proj-[A-Za-z0-9_]{12,}'),
      RegExp(r'AIza[0-9A-Za-z_-]{20,}'),
      RegExp(r'STRIPE_SECRET_KEY\s*=\s*sk_(live|test)_[A-Za-z0-9_]+'),
      RegExp(r'SUPABASE_SERVICE_ROLE\s*=\s*[A-Za-z0-9._-]+'),
      RegExp(r'-----BEGIN PRIVATE KEY-----'),
    ]) {
      expect(pattern.hasMatch(source), isFalse, reason: pattern.pattern);
    }
  });
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
