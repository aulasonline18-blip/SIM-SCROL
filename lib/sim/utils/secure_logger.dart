import 'package:flutter/foundation.dart';

class SecureLogger {
  const SecureLogger._();

  static void log(String tag, String message, [Object? data]) {
    if (!kDebugMode) return;
    final suffix = data == null ? '' : ': ${redact(data)}';
    debugPrint('[$tag] $message$suffix');
  }

  static Object? redact(Object? data) {
    if (data == null) return null;
    if (data is Map) {
      return data.map((key, value) {
        final cleanKey = key.toString();
        if (_isSensitiveKey(cleanKey)) return MapEntry(cleanKey, '[REDACTED]');
        return MapEntry(cleanKey, redact(value));
      });
    }
    if (data is Iterable) return data.map(redact).toList(growable: false);
    final text = data.toString();
    if (_looksSensitive(text)) return '[REDACTED]';
    if (text.length > 240) {
      return '${text.substring(0, 80)}...[redacted:${text.length} chars]';
    }
    return data;
  }

  static bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return lower.contains('authorization') ||
        lower.contains('token') ||
        lower.contains('secret') ||
        lower.contains('password') ||
        lower.contains('apikey') ||
        lower.contains('api_key') ||
        lower.contains('key') ||
        lower.contains('email') ||
        lower == 'userid' ||
        lower == 'user_id' ||
        lower.contains('profile') ||
        lower.contains('ficha') ||
        lower.contains('objective') ||
        lower.contains('objetivo') ||
        lower.contains('curriculum') ||
        lower.contains('curriculo') ||
        lower.contains('answer') ||
        lower.contains('resposta') ||
        lower.contains('prompt') ||
        lower.contains('payload') ||
        lower.contains('base64') ||
        lower.contains('dataurl') ||
        lower.contains('data_url');
  }

  static bool _looksSensitive(String text) {
    final lower = text.toLowerCase();
    if (lower.startsWith('bearer ')) return true;
    if (lower.startsWith('data:')) return true;
    if (RegExp(r'^[A-Za-z0-9+/]{120,}={0,2}$').hasMatch(text)) return true;
    if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) return true;
    final googleApiKeyPrefix = '${'AI'}za';
    if (RegExp('$googleApiKeyPrefix[0-9A-Za-z_-]{20,}').hasMatch(text)) {
      return true;
    }
    if (RegExp(r'sk_(live|test)_[A-Za-z0-9_]+').hasMatch(text)) return true;
    return false;
  }
}
