import 'package:flutter/foundation.dart';

import '../utils/secure_logger.dart';

class SimRuntimeAuditEvent {
  const SimRuntimeAuditEvent({
    required this.code,
    required this.source,
    required this.ts,
    required this.details,
  });

  final String code;
  final String source;
  final int ts;
  final Map<String, Object?> details;
}

class SimRuntimeAudit {
  const SimRuntimeAudit._();

  @visibleForTesting
  static final List<SimRuntimeAuditEvent> events = <SimRuntimeAuditEvent>[];

  static void report({
    required String code,
    required String source,
    Map<String, Object?> details = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final sanitized = <String, Object?>{
      for (final entry in details.entries)
        entry.key: SecureLogger.redact(entry.value),
      if (error != null) 'errorType': error.runtimeType.toString(),
    };
    final event = SimRuntimeAuditEvent(
      code: code,
      source: source,
      ts: DateTime.now().millisecondsSinceEpoch,
      details: sanitized,
    );
    events.add(event);
    if (error == null) return;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError(code),
        stack: stackTrace,
        library: 'sim_runtime_audit',
        context: ErrorDescription('$source:$code'),
        informationCollector: () sync* {
          yield DiagnosticsProperty<Map<String, Object?>>('details', sanitized);
        },
      ),
    );
  }

  @visibleForTesting
  static void clearForTesting() {
    events.clear();
  }
}
