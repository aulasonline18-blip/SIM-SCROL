import 'sim_route_contract.dart';

enum SimLinkSource { externalDeepLink, internalLink }

enum SimDeepLinkAction {
  open,
  redirectToLogin,
  requirePlacement,
  reject,
  fallback,
  external,
  noop,
}

class SimDeepLinkContext {
  const SimDeepLinkContext({
    required this.rawLink,
    this.source = SimLinkSource.externalDeepLink,
    this.authReady = true,
    this.authenticated = false,
    this.appAlreadyOpen = false,
    this.currentPath,
    this.hasActiveLesson = false,
    this.placementPending = false,
    this.placementRequired = false,
    this.allowedHosts = const {'gemini-aid-pal.lovable.app'},
    this.allowedCustomSchemes = const {'sim-mobile'},
  });

  final Object rawLink;
  final SimLinkSource source;
  final bool authReady;
  final bool authenticated;
  final bool appAlreadyOpen;
  final String? currentPath;
  final bool hasActiveLesson;
  final bool placementPending;
  final bool placementRequired;
  final Set<String> allowedHosts;
  final Set<String> allowedCustomSchemes;
}

class SimDeepLinkDecision {
  const SimDeepLinkDecision({
    required this.action,
    required this.reason,
    this.routePath,
    this.routeName,
    this.parameters = const {},
    this.returnTo,
    this.backStack = const [],
  });

  final SimDeepLinkAction action;
  final String reason;
  final String? routePath;
  final String? routeName;
  final Map<String, String> parameters;
  final String? returnTo;
  final List<String> backStack;
}

class SimDeepLinkParseResult {
  const SimDeepLinkParseResult({
    required this.uri,
    required this.normalizedPath,
    required this.parameters,
    required this.isInternalCandidate,
  });

  final Uri uri;
  final String normalizedPath;
  final Map<String, String> parameters;
  final bool isInternalCandidate;
}

class SimDeepLinkPolicy {
  const SimDeepLinkPolicy();

  SimDeepLinkDecision resolve(SimDeepLinkContext context) {
    final parsed = parse(context.rawLink, context);
    if (parsed == null) {
      return const SimDeepLinkDecision(
        action: SimDeepLinkAction.reject,
        reason: 'link is malformed or empty',
      );
    }

    if (!parsed.isInternalCandidate) {
      final externalRoute = simRouteByPath(parsed.uri.toString());
      return SimDeepLinkDecision(
        action: externalRoute?.access == SimRouteAccess.external
            ? SimDeepLinkAction.external
            : SimDeepLinkAction.reject,
        routePath: externalRoute?.path,
        routeName: externalRoute?.name,
        reason: externalRoute == null
            ? 'host or scheme is not allowed for SIM navigation'
            : 'external route remains outside the internal navigation stack',
      );
    }

    final route = simRouteByPath(parsed.normalizedPath);
    if (route == null) {
      return const SimDeepLinkDecision(
        action: SimDeepLinkAction.fallback,
        routePath: '/',
        routeName: 'portal',
        backStack: ['/'],
        reason: 'link route is not in the route contract',
      );
    }

    final parameterError = _validateParameters(route, parsed.parameters);
    if (parameterError != null) {
      return SimDeepLinkDecision(
        action: SimDeepLinkAction.reject,
        routePath: route.path,
        routeName: route.name,
        parameters: parsed.parameters,
        reason: parameterError,
      );
    }

    if (route.access == SimRouteAccess.server) {
      return SimDeepLinkDecision(
        action: SimDeepLinkAction.reject,
        routePath: route.path,
        routeName: route.name,
        reason: 'server routes are not valid app navigation destinations',
      );
    }

    if (route.access == SimRouteAccess.external) {
      return SimDeepLinkDecision(
        action: SimDeepLinkAction.external,
        routePath: route.path,
        routeName: route.name,
        reason: 'external routes are opened outside the app stack',
      );
    }

    if (route.isOverlay || route.access == SimRouteAccess.internal) {
      return SimDeepLinkDecision(
        action: SimDeepLinkAction.reject,
        routePath: route.path,
        routeName: route.name,
        reason: 'overlays are not valid primary deep link destinations',
      );
    }

    if (context.source == SimLinkSource.externalDeepLink &&
        !route.canDeepLink) {
      return SimDeepLinkDecision(
        action: SimDeepLinkAction.reject,
        routePath: route.path,
        routeName: route.name,
        reason: 'route is not declared as external deep-linkable',
      );
    }

    if (route.path == '/cyber/aula' &&
        (context.placementPending || context.placementRequired)) {
      return const SimDeepLinkDecision(
        action: SimDeepLinkAction.requirePlacement,
        routePath: '/cyber/placement',
        routeName: 'placement',
        backStack: ['/', '/cyber/placement'],
        reason: 'pending placement cannot be bypassed by link navigation',
      );
    }

    if (route.path == '/cyber/aula' && !context.hasActiveLesson) {
      return const SimDeepLinkDecision(
        action: SimDeepLinkAction.fallback,
        routePath: '/cyber/objeto',
        routeName: 'objective',
        backStack: ['/', '/cyber/objeto'],
        reason: 'classroom link requires a valid active lesson',
      );
    }

    if (route.isProtected && (!context.authReady || !context.authenticated)) {
      final returnTo = _safeReturnTo(route, parsed.parameters);
      return SimDeepLinkDecision(
        action: SimDeepLinkAction.redirectToLogin,
        routePath: '/login',
        routeName: 'login',
        parameters: parsed.parameters,
        returnTo: returnTo,
        backStack: const ['/', '/login'],
        reason: 'protected link requires authentication before navigation',
      );
    }

    final target = _targetWithQuery(route.path, parsed.parameters);
    final current = context.currentPath == null
        ? null
        : _normalizePath(Uri.tryParse(context.currentPath!) ?? Uri());
    if (context.appAlreadyOpen && current == target) {
      return SimDeepLinkDecision(
        action: SimDeepLinkAction.noop,
        routePath: route.path,
        routeName: route.name,
        parameters: parsed.parameters,
        backStack: [target],
        reason: 'app is already showing the requested route',
      );
    }

    return SimDeepLinkDecision(
      action: SimDeepLinkAction.open,
      routePath: route.path,
      routeName: route.name,
      parameters: parsed.parameters,
      backStack: _backStackFor(route, target, context.appAlreadyOpen),
      reason: 'link is valid for the current navigation context',
    );
  }

  SimDeepLinkParseResult? parse(Object rawLink, SimDeepLinkContext context) {
    final uri = _coerceUri(rawLink);
    if (uri == null) return null;

    final duplicateParam = uri.queryParametersAll.entries.any(
      (entry) => entry.value.length > 1,
    );
    if (duplicateParam) return null;

    final isRelative = !uri.hasScheme;
    if (isRelative) {
      if (!uri.path.startsWith('/')) return null;
      return SimDeepLinkParseResult(
        uri: uri,
        normalizedPath: _normalizePath(uri),
        parameters: Map.unmodifiable(uri.queryParameters),
        isInternalCandidate: true,
      );
    }

    if (uri.scheme == 'http' || uri.scheme == 'https') {
      final hostAllowed = context.allowedHosts.contains(uri.host);
      if (!hostAllowed) {
        return SimDeepLinkParseResult(
          uri: uri,
          normalizedPath: _normalizePath(uri),
          parameters: Map.unmodifiable(uri.queryParameters),
          isInternalCandidate: false,
        );
      }
      return SimDeepLinkParseResult(
        uri: uri,
        normalizedPath: _normalizePath(uri),
        parameters: Map.unmodifiable(uri.queryParameters),
        isInternalCandidate: true,
      );
    }

    if (context.allowedCustomSchemes.contains(uri.scheme)) {
      if (uri.host == 'login-callback') {
        return SimDeepLinkParseResult(
          uri: uri,
          normalizedPath: _normalizePath(uri),
          parameters: Map.unmodifiable(uri.queryParameters),
          isInternalCandidate: false,
        );
      }
      return SimDeepLinkParseResult(
        uri: uri,
        normalizedPath: _normalizePath(uri),
        parameters: Map.unmodifiable(uri.queryParameters),
        isInternalCandidate: true,
      );
    }

    return SimDeepLinkParseResult(
      uri: uri,
      normalizedPath: _normalizePath(uri),
      parameters: Map.unmodifiable(uri.queryParameters),
      isInternalCandidate: false,
    );
  }
}

Uri? _coerceUri(Object rawLink) {
  if (rawLink is Uri) return rawLink;
  if (rawLink is! String) return null;
  final trimmed = rawLink.trim();
  if (trimmed.isEmpty || trimmed.contains('\u0000')) return null;
  return Uri.tryParse(trimmed);
}

String _normalizePath(Uri uri) {
  final path = uri.path.isEmpty ? '/' : uri.path;
  return uri.fragment.isEmpty ? path : '$path#${uri.fragment}';
}

String? _validateParameters(
  SimRouteContractEntry route,
  Map<String, String> parameters,
) {
  final allowed = {...route.requiredParams, ...route.optionalParams};

  for (final required in route.requiredParams) {
    final value = parameters[required]?.trim();
    if (value == null || value.isEmpty) {
      return 'required parameter $required is missing';
    }
  }

  for (final key in parameters.keys) {
    if (!allowed.contains(key)) {
      return _sensitiveParameterNames.contains(key)
          ? 'sensitive parameter $key is not accepted for this route'
          : 'unexpected parameter $key is not declared by the route contract';
    }
  }

  final returnTo = parameters['returnTo'];
  if (returnTo != null && _safePathOnly(returnTo) == null) {
    return 'returnTo must point to a safe internal screen route';
  }

  final sessionId = parameters['session_id'];
  if (sessionId != null && !_isValidCheckoutSessionId(sessionId)) {
    return 'session_id has an invalid format';
  }

  return null;
}

List<String> _backStackFor(
  SimRouteContractEntry route,
  String target,
  bool appAlreadyOpen,
) {
  if (appAlreadyOpen) return [target];
  if (route.path == '/') return ['/'];
  if (route.path == '/checkout/return') return ['/creditos', target];
  if (route.isProtected) return ['/', target];
  return [target];
}

String _targetWithQuery(String path, Map<String, String> parameters) {
  if (parameters.isEmpty) return path;
  final query = Uri(queryParameters: parameters).query;
  return '$path?$query';
}

String? _safeReturnTo(
  SimRouteContractEntry route,
  Map<String, String> parameters,
) {
  if (route.access == SimRouteAccess.server ||
      route.access == SimRouteAccess.external ||
      route.access == SimRouteAccess.internal ||
      route.isOverlay) {
    return null;
  }
  return _targetWithQuery(route.path, parameters);
}

String? _safePathOnly(String rawPath) {
  final uri = Uri.tryParse(rawPath.trim());
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty) return null;
  final normalized = _normalizePath(uri);
  final route = simRouteByPath(normalized);
  if (route == null || route.isOverlay) return null;
  if (route.access == SimRouteAccess.server ||
      route.access == SimRouteAccess.external ||
      route.access == SimRouteAccess.internal) {
    return null;
  }
  return normalized;
}

bool _isValidCheckoutSessionId(String value) {
  final trimmed = value.trim();
  if (trimmed.length < 6 || trimmed.length > 180) return false;
  return RegExp(
    r'^(cs_(test|live)_[A-Za-z0-9_]+|cs_[A-Za-z0-9_]+)$',
  ).hasMatch(trimmed);
}

const _sensitiveParameterNames = {
  'access_token',
  'authToken',
  'id_token',
  'password',
  'refresh_token',
  'session_id',
  'token',
};
