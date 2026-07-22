import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../state/secure_storage_service.dart';

abstract interface class LessonCacheStore {
  Future<String?> read();
  Future<void> write(String content);
  Future<void> delete();
}

class EncryptedFileLessonCacheStore implements LessonCacheStore {
  factory EncryptedFileLessonCacheStore({int maxBytes = 2 * 1024 * 1024}) {
    return EncryptedFileLessonCacheStore._(maxBytes: maxBytes);
  }

  factory EncryptedFileLessonCacheStore.forTesting({
    Directory? baseDirectory,
    Future<SecretKey> Function()? keyProvider,
    int maxBytes = 2 * 1024 * 1024,
  }) {
    return EncryptedFileLessonCacheStore._(
      baseDirectory: baseDirectory,
      keyProvider: keyProvider,
      maxBytes: maxBytes,
    );
  }

  EncryptedFileLessonCacheStore._({
    this._baseDirectory,
    this._keyProvider,
    this.maxBytes = 2 * 1024 * 1024,
  });

  static const _keyName = 'sim.lessonCache.aesGcmKey.v1';
  static const _fileName = 'lesson_material_cache_v1.aesgcm';

  final SecureStorageService _secureStorage = const SecureStorageService();
  final Directory? _baseDirectory;
  final Future<SecretKey> Function()? _keyProvider;
  final int maxBytes;
  final AesGcm _cipher = AesGcm.with256bits();

  @override
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final nonce = _bytes(decoded['nonce']);
    final mac = _bytes(decoded['mac']);
    final cipherText = _bytes(decoded['cipherText']);
    if (nonce == null || mac == null || cipherText == null) return null;
    final clear = await _cipher.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: await _key(),
    );
    return utf8.decode(clear);
  }

  @override
  Future<void> write(String content) async {
    final clear = utf8.encode(content);
    if (clear.length > maxBytes) {
      throw const LessonCacheStoreException('LESSON_CACHE_PAYLOAD_TOO_LARGE');
    }
    final nonce = _randomBytes(12);
    final box = await _cipher.encrypt(
      clear,
      secretKey: await _key(),
      nonce: nonce,
    );
    final encoded = jsonEncode({
      'version': 1,
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'cipherText': base64Encode(box.cipherText),
    });
    final file = await _file();
    await file.parent.create(recursive: true);
    final tmp = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.${_randomBytes(4).join()}.tmp',
    );
    await tmp.writeAsString(encoded, flush: true);
    if (await file.exists()) await file.delete();
    await tmp.rename(file.path);
  }

  @override
  Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }

  Future<File> _file() async {
    final base =
        _baseDirectory ??
        Directory((await getApplicationSupportDirectory()).path);
    return File(p.join(base.path, 'sim_secure_cache', _fileName));
  }

  Future<SecretKey> _key() async {
    final provided = _keyProvider;
    if (provided != null) return provided();
    final existing = await _secureStorage.readSecure(_keyName);
    if (existing != null && existing.trim().isNotEmpty) {
      return SecretKey(base64Decode(existing));
    }
    final keyBytes = _randomBytes(32);
    await _secureStorage.writeSecure(_keyName, base64Encode(keyBytes));
    return SecretKey(keyBytes);
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static List<int>? _bytes(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }
}

class MemoryLessonCacheStore implements LessonCacheStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String content) async {
    value = content;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class LessonCacheStoreException implements Exception {
  const LessonCacheStoreException(this.code);

  final String code;

  @override
  String toString() => code;
}
