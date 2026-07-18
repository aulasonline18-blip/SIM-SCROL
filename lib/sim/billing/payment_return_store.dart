import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PaymentReturnStorage {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
}

class SharedPrefsPaymentReturnStorage implements PaymentReturnStorage {
  SharedPrefsPaymentReturnStorage(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? read(String key) => _prefs.getString(key);

  @override
  void remove(String key) {
    _prefs.remove(key);
  }

  @override
  void write(String key, String value) {
    _prefs.setString(key, value);
  }
}

class _ExplicitPaymentReturnStorageRequired implements PaymentReturnStorage {
  const _ExplicitPaymentReturnStorageRequired();

  Never _missing() {
    throw StateError('PAYMENT_RETURN_STORAGE_REQUIRED');
  }

  @override
  String? read(String key) => _missing();

  @override
  void remove(String key) {
    _missing();
  }

  @override
  void write(String key, String value) {
    _missing();
  }
}

class PaymentReturnStore {
  PaymentReturnStore({PaymentReturnStorage? storage})
    : storage = storage ?? const _ExplicitPaymentReturnStorageRequired();

  static const key = 'sim-payment-returnto-v0';

  final PaymentReturnStorage storage;

  bool isSafeInternalPath(String? path) {
    if (path == null || path.isEmpty) return false;
    if (!path.startsWith('/')) return false;
    if (path.startsWith('//')) return false;
    if (path.startsWith('/creditos')) return false;
    if (path.startsWith('/checkout')) return false;
    return true;
  }

  void saveReturnTo(String? path) {
    if (isSafeInternalPath(path)) storage.write(key, path!);
  }

  String? readReturnTo() {
    final value = storage.read(key);
    return isSafeInternalPath(value) ? value : null;
  }

  void clearReturnTo() {
    storage.remove(key);
  }
}
