import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/sim/cache/secure_lesson_cache_store.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/utils/secure_logger.dart';

void main() {
  test('release contract removes HTTP escape hatch from app and Gradle', () {
    final env = File('lib/sim/config/sim_environment.dart').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(env, isNot(contains('SIM_ALLOW_HTTP_IN_PRODUCTION')));
    expect(env, contains('kReleaseMode'));
    expect(env, contains('SIM_ALLOW_HTTP_IN_DEVELOPMENT'));
    expect(env, contains('SIM_ALLOW_HTTP_IN_OPERATIONAL_RELEASE'));
    expect(env, contains('validateServerUrl'));
    expect(
      gradle,
      contains('SIM_SERVER_URL must use HTTPS for release builds'),
    );
    expect(
      gradle,
      contains('SIM_ANDROID_OPERATIONAL_RELEASE_ALLOW_CLEARTEXT'),
    );
    expect(gradle, isNot(contains('SIM_ANDROID_ALLOW_CLEARTEXT')));
    expect(gradle, isNot(contains('SIM_ALLOW_HTTP_IN_PRODUCTION')));
  });

  test('release cleartext traffic is blocked by manifest contract', () {
    final mainManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final profileManifest = File(
      'android/app/src/profile/AndroidManifest.xml',
    ).readAsStringSync();
    final debugManifest = File(
      'android/app/src/debug/AndroidManifest.xml',
    ).readAsStringSync();
    final networkConfig = File(
      'android/app/src/main/res/xml/network_security_config.xml',
    ).readAsStringSync();

    expect(
      mainManifest,
      contains(r'android:usesCleartextTraffic="${simUsesCleartextTraffic}"'),
    );
    expect(profileManifest, contains('android:usesCleartextTraffic="false"'));
    expect(debugManifest, contains('android:usesCleartextTraffic="true"'));
    expect(networkConfig, contains('cleartextTrafficPermitted="false"'));
    expect(
      File(
        'android/app/src/main/res/xml/network_security_config_operational_release.xml',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        'android/app/src/main/res/xml/network_security_config_cleartext.xml',
      ).existsSync(),
      isFalse,
    );
  });

  test(
    'lesson cache persists encrypted content outside SharedPreferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final temp = await Directory.systemTemp.createTemp('sim-secure-cache-');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final key = SecretKey(List<int>.generate(32, (index) => index + 1));
      final store = EncryptedFileLessonCacheStore.forTesting(
        baseDirectory: temp,
        keyProvider: () async => key,
      );
      final cache = LessonMaterialCache(store: store);
      const params = CompleteLessonParams(
        lessonLocalId: 'lesson-secure',
        item: 'Item seguro',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
        itemIdx: 0,
      );

      final stored = cache.putForParams(
        params,
        CompleteLesson(
          conteudo: const LessonContent(
            explanation: 'Perfil sensivel do aluno teste@example.com',
            question: 'Qual resposta sensivel?',
            options: {
              AnswerLetter.A: 'A',
              AnswerLetter.B: 'B',
              AnswerLetter.C: 'C',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: null,
          audioText: 'Perfil sensivel do aluno teste@example.com',
          localeContract: params.effectiveLocaleContract,
        ),
      );
      expect(stored, isTrue);
      await cache.persistNow();

      final files = temp.listSync(recursive: true).whereType<File>().toList();
      expect(files, isNotEmpty);
      final raws = files.map((file) => file.readAsStringSync()).toList();
      final raw = raws.singleWhere((content) => content.contains('cipherText'));
      expect(raw, contains('cipherText'));
      for (final content in raws) {
        expect(content, isNot(contains('teste@example.com')));
        expect(content, isNot(contains('Qual resposta sensivel?')));
      }
      expect(prefs.getString('sim-lesson-text-cache-v1'), isNull);

      final hydrated = LessonMaterialCache(store: store);
      await hydrated.hydrate();
      expect(
        hydrated.peek(lessonKeyFor(params))?.conteudo.question,
        'Qual resposta sensivel?',
      );
    },
  );

  test('secure logger redacts sensitive identifiers and payloads', () {
    final redacted = SecureLogger.redact({
      'Authorization': 'Bearer abc123',
      'token': 'abc123',
      'email': 'aluno@example.com',
      'userId': 'user-1',
      'objective': 'passar no exame',
      'payload': {'prompt': 'texto interno'},
      'image': 'data:image/png;base64,AAAA',
      'safeStatus': 200,
    });

    expect(redacted, isA<Map>());
    final map = redacted! as Map;
    expect(map['Authorization'], '[REDACTED]');
    expect(map['token'], '[REDACTED]');
    expect(map['email'], '[REDACTED]');
    expect(map['userId'], '[REDACTED]');
    expect(map['objective'], '[REDACTED]');
    expect(map['payload'], '[REDACTED]');
    expect(map['image'], '[REDACTED]');
    expect(map['safeStatus'], 200);
  });

  test('app source contains no hardcoded operational secrets', () {
    final roots = [
      Directory('lib'),
      Directory('android'),
      Directory('assets'),
      Directory('test/fixtures'),
    ].where((dir) => dir.existsSync());
    final suspicious = <String>[];
    final secretPatterns = [
      RegExp(r'AIza[0-9A-Za-z_-]{20,}'),
      RegExp(r'sk_(live|test)_[A-Za-z0-9_]{20,}'),
      RegExp(r'-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'),
      RegExp(
        r'''(?i:(api[_-]?key|secret|password|token))\s*=\s*["'][^"']{12,}["']''',
      ),
    ];

    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (entity.path.contains('/build/') ||
            entity.path.contains('/.gradle/')) {
          continue;
        }
        final isText =
            entity.path.endsWith('.dart') ||
            entity.path.endsWith('.kt') ||
            entity.path.endsWith('.kts') ||
            entity.path.endsWith('.xml') ||
            entity.path.endsWith('.json') ||
            entity.path.endsWith('.properties') ||
            entity.path.endsWith('.yaml') ||
            entity.path.endsWith('.yml') ||
            entity.path.endsWith('.md');
        if (!isText) continue;
        final content = entity.readAsStringSync();
        for (final pattern in secretPatterns) {
          if (pattern.hasMatch(content)) suspicious.add(entity.path);
        }
      }
    }

    expect(suspicious, isEmpty);
  });
}
