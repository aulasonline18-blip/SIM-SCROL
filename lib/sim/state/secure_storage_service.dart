import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  const SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> writeSecure(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  Future<String?> readSecure(String key) {
    return _storage.read(key: key);
  }

  Future<void> deleteSecure(String key) {
    return _storage.delete(key: key);
  }

  Future<void> deleteAllSecure() {
    return _storage.deleteAll();
  }
}
