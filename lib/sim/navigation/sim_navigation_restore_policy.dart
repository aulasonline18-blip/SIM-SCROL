import 'sim_route_contract.dart';
import 'sim_route_state.dart';
import 'sim_route_state_store.dart';

enum SimNavigationRestoreAction {
  restore,
  fallback,
  requireLogin,
  requirePlacement,
  clearInvalidSnapshot,
}

class SimNavigationRestoreContext {
  const SimNavigationRestoreContext({
    this.lastKnownRoute,
    this.snapshot,
    this.authReady = true,
    this.authenticated = false,
    this.hasActiveLesson = false,
    this.activeLessonIncomplete = false,
    this.placementPending = false,
    this.placementRequired = false,
    this.hasRecoverableError = false,
    this.now,
  });

  final String? lastKnownRoute;
  final SimRouteStateSnapshot? snapshot;
  final bool authReady;
  final bool authenticated;
  final bool hasActiveLesson;
  final bool activeLessonIncomplete;
  final bool placementPending;
  final bool placementRequired;
  final bool hasRecoverableError;
  final DateTime? now;
}

class SimNavigationRestoreDecision {
  const SimNavigationRestoreDecision({
    required this.action,
    required this.routePath,
    required this.reason,
    this.returnTo,
    this.showRecoverableError = false,
    this.clearSnapshot = false,
  });

  final SimNavigationRestoreAction action;
  final String routePath;
  final String reason;
  final String? returnTo;
  final bool showRecoverableError;
  final bool clearSnapshot;
}

class SimNavigationRestorePolicy {
  const SimNavigationRestorePolicy();

  SimNavigationRestoreDecision resolve(SimNavigationRestoreContext context) {
    final rawRoute = context.lastKnownRoute?.trim();
    if (rawRoute == null || rawRoute.isEmpty) {
      return _safeRootFallback(context, reason: 'missing last route');
    }

    final route = simRouteByPath(rawRoute);
    if (route == null) {
      return _safeRootFallback(context, reason: 'unknown last route');
    }

    if (route.isOverlay) {
      final fallback = _safeFallbackForOverlay(route, context);
      return SimNavigationRestoreDecision(
        action: SimNavigationRestoreAction.fallback,
        routePath: fallback,
        reason: 'overlays are not restored as primary routes',
        showRecoverableError: context.hasRecoverableError,
        clearSnapshot: true,
      );
    }

    if (route.access == SimRouteAccess.server ||
        route.access == SimRouteAccess.external) {
      return _safeRootFallback(
        context,
        reason: 'server and external routes are not restorable app screens',
        clearSnapshot: true,
      );
    }

    if (!route.restorable) {
      return _fallbackForNonRestorable(route, context);
    }

    if (route.isProtected && (!context.authReady || !context.authenticated)) {
      return SimNavigationRestoreDecision(
        action: SimNavigationRestoreAction.requireLogin,
        routePath: '/login',
        returnTo: _safeReturnTo(route.path),
        reason: 'protected route cannot restore without a valid session',
        showRecoverableError: context.hasRecoverableError,
        clearSnapshot: false,
      );
    }

    if (route.path == '/cyber/aula') {
      if (context.hasActiveLesson && !context.activeLessonIncomplete) {
        return SimNavigationRestoreDecision(
          action: SimNavigationRestoreAction.restore,
          routePath: '/cyber/aula',
          reason: 'valid active lesson restores classroom',
          showRecoverableError: context.hasRecoverableError,
          clearSnapshot: _snapshotInvalidFor(route, context),
        );
      }
      return SimNavigationRestoreDecision(
        action: SimNavigationRestoreAction.fallback,
        routePath: '/cyber/curriculo',
        reason: 'classroom route had no complete active lesson to restore',
        showRecoverableError: true,
        clearSnapshot: _snapshotInvalidFor(route, context),
      );
    }

    if (route.path == '/cyber/placement') {
      if (context.placementPending || context.placementRequired) {
        return SimNavigationRestoreDecision(
          action: SimNavigationRestoreAction.requirePlacement,
          routePath: '/cyber/placement',
          reason: 'pending placement restores placement without skipping it',
          showRecoverableError: context.hasRecoverableError,
          clearSnapshot: _snapshotInvalidFor(route, context),
        );
      }
      return SimNavigationRestoreDecision(
        action: SimNavigationRestoreAction.fallback,
        routePath: '/cyber/curriculo',
        reason: 'placement is not pending anymore',
        showRecoverableError: context.hasRecoverableError,
        clearSnapshot: _snapshotInvalidFor(route, context),
      );
    }

    if (_snapshotInvalidFor(route, context)) {
      return SimNavigationRestoreDecision(
        action: SimNavigationRestoreAction.clearInvalidSnapshot,
        routePath: route.fallbackPath ?? '/',
        reason: 'snapshot is expired, incompatible or belongs to another route',
        showRecoverableError: context.hasRecoverableError,
        clearSnapshot: true,
      );
    }

    return SimNavigationRestoreDecision(
      action: SimNavigationRestoreAction.restore,
      routePath: route.path,
      reason: 'last route is valid and restorable',
      showRecoverableError: context.hasRecoverableError,
      clearSnapshot: false,
    );
  }

  SimNavigationRestoreDecision _fallbackForNonRestorable(
    SimRouteContractEntry route,
    SimNavigationRestoreContext context,
  ) {
    final fallback = route.fallbackPath ?? '/';
    if (route.isProtected && (!context.authReady || !context.authenticated)) {
      return SimNavigationRestoreDecision(
        action: SimNavigationRestoreAction.requireLogin,
        routePath: '/login',
        returnTo: _safeReturnTo(fallback),
        reason: 'non-restorable protected route requires login',
        showRecoverableError: context.hasRecoverableError,
        clearSnapshot: true,
      );
    }
    return SimNavigationRestoreDecision(
      action: SimNavigationRestoreAction.fallback,
      routePath: fallback,
      reason: 'last route is not restorable',
      showRecoverableError: context.hasRecoverableError,
      clearSnapshot: true,
    );
  }

  SimNavigationRestoreDecision _safeRootFallback(
    SimNavigationRestoreContext context, {
    required String reason,
    bool clearSnapshot = false,
  }) {
    if (!context.authReady || !context.authenticated) {
      return SimNavigationRestoreDecision(
        action: SimNavigationRestoreAction.requireLogin,
        routePath: '/login',
        reason: reason,
        showRecoverableError: context.hasRecoverableError,
        clearSnapshot: clearSnapshot,
      );
    }
    return SimNavigationRestoreDecision(
      action: SimNavigationRestoreAction.fallback,
      routePath: '/',
      reason: reason,
      showRecoverableError: context.hasRecoverableError,
      clearSnapshot: clearSnapshot,
    );
  }

  String _safeFallbackForOverlay(
    SimRouteContractEntry route,
    SimNavigationRestoreContext context,
  ) {
    final fallback = route.fallbackPath;
    if (fallback != null &&
        simRouteByPath(fallback)?.surface == SimRouteSurface.screen) {
      if (fallback == '/cyber/aula' &&
          (!context.hasActiveLesson || context.activeLessonIncomplete)) {
        return '/cyber/curriculo';
      }
      return fallback;
    }
    return context.authenticated ? '/' : '/login';
  }

  bool _snapshotInvalidFor(
    SimRouteContractEntry route,
    SimNavigationRestoreContext context,
  ) {
    final snapshot = context.snapshot;
    if (snapshot == null) return false;
    if (snapshot.version != simRouteStateSnapshotVersion) return true;
    if (snapshot.routeName != route.name) return true;
    final stateContract = simRouteStateByName(route.name);
    if (stateContract == null) return true;
    final ttl = stateContract.ttl;
    final createdAt = snapshot.createdAt;
    if (ttl != null && createdAt != null) {
      final now = context.now ?? DateTime.now();
      if (now.difference(createdAt) > ttl) return true;
    }
    return false;
  }
}

String? _safeReturnTo(String path) {
  if (!path.startsWith('/') || path.startsWith('//')) return null;
  final route = simRouteByPath(path);
  if (route == null) return null;
  if (route.access == SimRouteAccess.server ||
      route.access == SimRouteAccess.external ||
      route.access == SimRouteAccess.internal) {
    return null;
  }
  return path;
}
