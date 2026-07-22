import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/sim/cache/secure_lesson_cache_store.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';

void main() {
  test(
    'cache ausente, json invalido e schema invalido têm motivos distintos',
    () async {
      SharedPreferences.setMockInitialValues({});
      final empty = LessonMaterialCache(store: MemoryLessonCacheStore());
      expect((await empty.hydrate()).code, 'CACHE_EMPTY');

      final invalidJson = LessonMaterialCache(
        store: MemoryLessonCacheStore()..value = '{bad-json',
      );
      expect((await invalidJson.hydrate()).code, 'CACHE_CORRUPTED_JSON');

      final invalidSchema = LessonMaterialCache(
        store: MemoryLessonCacheStore()..value = jsonEncode([]),
      );
      expect((await invalidSchema.hydrate()).code, 'CACHE_CORRUPTED_SHAPE');
    },
  );

  test('cache com entrada inutilizavel registra rejeicao auditavel', () {
    final cache = LessonMaterialCache(store: MemoryLessonCacheStore());

    final audit = cache.hydrateFromJson(
      jsonEncode({
        'version': 2,
        'warm': {
          'lesson-key': {
            'savedAt': DateTime.now().millisecondsSinceEpoch,
            'lastAccessedAt': DateTime.now().millisecondsSinceEpoch,
            'lesson': {
              'conteudo': {
                'explanation': '',
                'question': '',
                'options': {'A': '', 'B': '', 'C': ''},
                'correct_answer': 'A',
              },
            },
          },
        },
      }),
    );

    expect(audit.ok, isTrue);
    expect(audit.details['rejectedContent'], 1);
    expect(cache.warmEntryCount, 0);
  });

  test('erro do store criptografado sobe como codigo de cache', () async {
    final cache = LessonMaterialCache(
      store: _ThrowingLessonCacheStore(
        const LessonCacheStoreException('LESSON_CACHE_SCHEMA_INVALID'),
      ),
    );

    final audit = await cache.hydrate();

    expect(audit.ok, isFalse);
    expect(audit.code, 'LESSON_CACHE_SCHEMA_INVALID');
  });
}

class _ThrowingLessonCacheStore implements LessonCacheStore {
  const _ThrowingLessonCacheStore(this.error);

  final Object error;

  @override
  Future<String?> read() async => throw error;

  @override
  Future<void> write(String content) async {}

  @override
  Future<void> delete() async {}
}
