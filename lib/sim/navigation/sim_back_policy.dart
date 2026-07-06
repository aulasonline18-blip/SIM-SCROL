import 'sim_route_contract.dart';

enum SimBackSource { androidBack, visualBack }

enum SimBackOverlay { none, modal, sheet, drawer, dialog }

enum SimBackAction {
  allowSystemExit,
  closeOverlay,
  navigate,
  block,
  requireConfirmation,
}

class SimBackContext {
  const SimBackContext({
    required this.currentPath,
    this.source = SimBackSource.androidBack,
    this.openOverlay = SimBackOverlay.none,
    this.previousPath,
    this.returnTo,
    this.hasActiveLesson = false,
    this.placementRequired = false,
    this.hasUnsavedCriticalState = false,
  });

  final String currentPath;
  final SimBackSource source;
  final SimBackOverlay openOverlay;
  final String? previousPath;
  final String? returnTo;
  final bool hasActiveLesson;
  final bool placementRequired;
  final bool hasUnsavedCriticalState;

  SimBackContext copyWith({
    String? currentPath,
    SimBackSource? source,
    SimBackOverlay? openOverlay,
    String? previousPath,
    String? returnTo,
    bool? hasActiveLesson,
    bool? placementRequired,
    bool? hasUnsavedCriticalState,
  }) {
    return SimBackContext(
      currentPath: currentPath ?? this.currentPath,
      source: source ?? this.source,
      openOverlay: openOverlay ?? this.openOverlay,
      previousPath: previousPath ?? this.previousPath,
      returnTo: returnTo ?? this.returnTo,
      hasActiveLesson: hasActiveLesson ?? this.hasActiveLesson,
      placementRequired: placementRequired ?? this.placementRequired,
      hasUnsavedCriticalState:
          hasUnsavedCriticalState ?? this.hasUnsavedCriticalState,
    );
  }
}

class SimBackDecision {
  const SimBackDecision({
    required this.action,
    required this.preserveState,
    required this.reason,
    this.destinationPath,
  });

  final SimBackAction action;
  final String? destinationPath;
  final bool preserveState;
  final String reason;

  bool get handlesBack => action != SimBackAction.allowSystemExit;

  bool equivalentTo(SimBackDecision other) {
    return action == other.action &&
        destinationPath == other.destinationPath &&
        preserveState == other.preserveState;
  }
}

class SimBackPolicy {
  const SimBackPolicy();

  SimBackDecision resolve(SimBackContext context) {
    if (context.openOverlay != SimBackOverlay.none) {
      return SimBackDecision(
        action: SimBackAction.closeOverlay,
        preserveState: true,
        reason: 'close open overlay before changing the underlying route',
      );
    }

    final currentPath = _pathOnly(context.currentPath);
    final currentRoute = simRouteByPath(context.currentPath);
    if (currentRoute == null) {
      return const SimBackDecision(
        action: SimBackAction.navigate,
        destinationPath: '/',
        preserveState: true,
        reason: 'unknown route falls back to portal',
      );
    }

    if (currentRoute.path == '/') {
      return const SimBackDecision(
        action: SimBackAction.allowSystemExit,
        preserveState: true,
        reason: 'portal is the root route',
      );
    }

    if (context.hasUnsavedCriticalState) {
      return const SimBackDecision(
        action: SimBackAction.requireConfirmation,
        preserveState: true,
        reason: 'critical state should not be discarded without confirmation',
      );
    }

    if (currentPath == '/cyber/aula') {
      if (!context.hasActiveLesson) {
        return const SimBackDecision(
          action: SimBackAction.navigate,
          destinationPath: '/cyber/objeto',
          preserveState: true,
          reason: 'classroom without active lesson returns to objective',
        );
      }
      return const SimBackDecision(
        action: SimBackAction.navigate,
        destinationPath: '/',
        preserveState: true,
        reason: 'active lesson returns to portal without clearing lesson state',
      );
    }

    if (currentPath == '/cyber/placement') {
      if (context.placementRequired) {
        return const SimBackDecision(
          action: SimBackAction.block,
          preserveState: true,
          reason: 'required placement cannot be bypassed with back',
        );
      }
      return const SimBackDecision(
        action: SimBackAction.navigate,
        destinationPath: '/cyber/curriculo',
        preserveState: true,
        reason: 'optional placement returns to preparation',
      );
    }

    if (currentPath == '/creditos') {
      final destination = _safeBackTarget(context.returnTo);
      return SimBackDecision(
        action: SimBackAction.navigate,
        destinationPath: destination ?? '/',
        preserveState: true,
        reason: destination == null
            ? 'credits without safe return target returns to portal'
            : 'credits returns to safe returnTo target',
      );
    }

    if (currentPath == '/checkout/return') {
      final destination = _safeBackTarget(context.returnTo);
      return SimBackDecision(
        action: SimBackAction.navigate,
        destinationPath: destination ?? '/creditos',
        preserveState: true,
        reason: destination == null
            ? 'checkout return falls back to credits'
            : 'checkout return respects safe returnTo target',
      );
    }

    if (currentPath == '/login') {
      return const SimBackDecision(
        action: SimBackAction.navigate,
        destinationPath: '/',
        preserveState: true,
        reason: 'login back returns to portal instead of exiting',
      );
    }

    final previous = _safeBackTarget(context.previousPath);
    if (previous != null && previous != currentPath) {
      return SimBackDecision(
        action: SimBackAction.navigate,
        destinationPath: previous,
        preserveState: true,
        reason: 'safe previous route is available',
      );
    }

    final fallback = _safeBackTarget(currentRoute.fallbackPath);
    if (fallback != null && fallback != currentPath) {
      return SimBackDecision(
        action: SimBackAction.navigate,
        destinationPath: fallback,
        preserveState: true,
        reason: 'contract fallback route is available',
      );
    }

    return const SimBackDecision(
      action: SimBackAction.navigate,
      destinationPath: '/',
      preserveState: true,
      reason: 'default safe fallback is portal',
    );
  }

  bool equivalentForAndroidAndVisualBack(SimBackContext context) {
    final android = resolve(
      context.copyWith(source: SimBackSource.androidBack),
    );
    final visual = resolve(context.copyWith(source: SimBackSource.visualBack));
    return android.equivalentTo(visual);
  }
}

String _pathOnly(String rawPath) {
  final uri = Uri.tryParse(rawPath);
  if (uri == null) return rawPath;
  if (uri.path.isEmpty && rawPath == '/') return '/';
  return uri.path.isEmpty ? rawPath : uri.path;
}

String? _safeBackTarget(String? rawPath) {
  if (rawPath == null || rawPath.trim().isEmpty) return null;
  final path = _pathOnly(rawPath.trim());
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
