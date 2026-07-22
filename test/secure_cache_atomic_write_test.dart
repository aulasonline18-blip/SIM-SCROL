import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/cache/secure_lesson_cache_store.dart';

void main() {
  test(
    'falha antes da substituicao preserva cache criptografado anterior',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'sim-secure-cache-test-',
      );
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final key = SecretKey(List<int>.filled(32, 7));
      Future<SecretKey> keyProvider() async => key;
      final store = EncryptedFileLessonCacheStore.forTesting(
        baseDirectory: dir,
        keyProvider: keyProvider,
      );
      await store.write('old-cache');

      final failing = EncryptedFileLessonCacheStore.forTesting(
        baseDirectory: dir,
        keyProvider: keyProvider,
        failBeforeReplace: true,
      );
      await expectLater(
        failing.write('new-cache'),
        throwsA(isA<LessonCacheStoreException>()),
      );

      expect(await store.read(), 'old-cache');
    },
  );

  test('cache criptografado malformado retorna codigo auditavel', () async {
    final dir = await Directory.systemTemp.createTemp('sim-secure-cache-bad-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final file = File(
      '${dir.path}/sim_secure_cache/lesson_material_cache_v1.aesgcm',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString('{"version":1}');
    final store = EncryptedFileLessonCacheStore.forTesting(
      baseDirectory: dir,
      keyProvider: () async => SecretKey(List<int>.filled(32, 7)),
    );

    await expectLater(
      store.read(),
      throwsA(
        isA<LessonCacheStoreException>().having(
          (error) => error.code,
          'code',
          'LESSON_CACHE_SCHEMA_INVALID',
        ),
      ),
    );
  });
}
