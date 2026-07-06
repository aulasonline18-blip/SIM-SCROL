import 'sim_route_state.dart';

class SimRouteStateSnapshot {
  const SimRouteStateSnapshot({
    required this.routeName,
    required this.sessionKey,
    required this.version,
    required this.values,
    this.createdAt,
  });

  final String routeName;
  final String sessionKey;
  final int version;
  final Map<String, Object?> values;
  final DateTime? createdAt;
}

class SimRouteStateSaveResult {
  const SimRouteStateSaveResult({
    required this.saved,
    this.rejected = const {},
  });

  final SimRouteStateSnapshot? saved;
  final Map<String, String> rejected;

  bool get accepted => saved != null && rejected.isEmpty;
}

class SimRouteStateStore {
  SimRouteStateStore({this.maxValueBytes = 8192});

  final int maxValueBytes;
  final Map<String, SimRouteStateSnapshot> _snapshots = {};

  SimRouteStateSaveResult save(
    String routeName,
    Map<String, Object?> values, {
    String sessionKey = 'default',
    DateTime? now,
  }) {
    final contract = simRouteStateByName(routeName);
    if (contract == null) {
      return const SimRouteStateSaveResult(
        saved: null,
        rejected: {'route': 'unknown route'},
      );
    }
    if (!contract.restorable ||
        contract.storageScope == SimRouteStateScope.neverPersist) {
      return SimRouteStateSaveResult(
        saved: null,
        rejected: {routeName: 'route is not restorable'},
      );
    }

    final accepted = <String, Object?>{};
    final rejected = <String, String>{};
    for (final entry in values.entries) {
      final fieldKey = entry.key;
      final value = entry.value;
      if (!contract.allowsField(fieldKey)) {
        rejected[fieldKey] = 'field is not declared for this route';
        continue;
      }
      if (!contract.canPersistField(fieldKey)) {
        rejected[fieldKey] = 'field is volatile or sensitive';
        continue;
      }
      if (!_isLightweightValue(value)) {
        rejected[fieldKey] = 'value is not a lightweight route state value';
        continue;
      }
      if (_roughValueBytes(value) > maxValueBytes) {
        rejected[fieldKey] = 'value exceeds lightweight snapshot limit';
        continue;
      }
      accepted[fieldKey] = value;
    }

    if (accepted.isEmpty) {
      return SimRouteStateSaveResult(saved: null, rejected: rejected);
    }

    final snapshot = SimRouteStateSnapshot(
      routeName: routeName,
      sessionKey: sessionKey,
      version: simRouteStateSnapshotVersion,
      values: Map.unmodifiable(accepted),
      createdAt: now ?? DateTime.now(),
    );
    _snapshots[_storeKey(routeName, sessionKey)] = snapshot;
    return SimRouteStateSaveResult(
      saved: snapshot,
      rejected: Map.unmodifiable(rejected),
    );
  }

  SimRouteStateSnapshot? restore(
    String routeName, {
    String sessionKey = 'default',
    DateTime? now,
  }) {
    final contract = simRouteStateByName(routeName);
    if (contract == null || !contract.restorable) return null;

    final snapshot = _snapshots[_storeKey(routeName, sessionKey)];
    if (snapshot == null) return null;
    if (snapshot.version != simRouteStateSnapshotVersion) return null;
    if (snapshot.routeName != routeName || snapshot.sessionKey != sessionKey) {
      return null;
    }
    final ttl = contract.ttl;
    final createdAt = snapshot.createdAt;
    if (ttl != null && createdAt != null) {
      final current = now ?? DateTime.now();
      if (current.difference(createdAt) > ttl) {
        clear(routeName, sessionKey: sessionKey);
        return null;
      }
    }
    return snapshot;
  }

  void clear(String routeName, {String sessionKey = 'default'}) {
    _snapshots.remove(_storeKey(routeName, sessionKey));
  }

  void clearSession(String sessionKey) {
    _snapshots.removeWhere(
      (key, snapshot) => snapshot.sessionKey == sessionKey,
    );
  }

  void clearAll() {
    _snapshots.clear();
  }

  int get length => _snapshots.length;
}

String _storeKey(String routeName, String sessionKey) {
  return '$sessionKey::$routeName';
}

bool _isLightweightValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return true;
  }
  if (value is List) {
    return value.every(_isLightweightValue);
  }
  if (value is Map) {
    return value.keys.every((key) => key is String) &&
        value.values.every(_isLightweightValue);
  }
  return false;
}

int _roughValueBytes(Object? value) {
  if (value == null) return 0;
  if (value is String) return value.length;
  if (value is num || value is bool) return value.toString().length;
  if (value is List) {
    return value.fold<int>(0, (total, item) => total + _roughValueBytes(item));
  }
  if (value is Map) {
    return value.entries.fold<int>(
      0,
      (total, entry) =>
          total + entry.key.toString().length + _roughValueBytes(entry.value),
    );
  }
  return maxSafeInteger;
}

const maxSafeInteger = 9007199254740991;
