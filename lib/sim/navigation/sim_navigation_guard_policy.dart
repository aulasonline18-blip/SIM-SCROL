import 'sim_route_contract.dart';

enum SimNavigationGuardOrigin { userAction, deepLink, restore, back, internal }

enum SimNavigationGuardAction { allow, redirect, block, fallback }

enum SimNavigationGuardBlocker {
  none,
  invalidRoute,
  unauthorizedRoute,
  authRequired,
  sessionExpired,
  onboardingIncomplete,
  placementPending,
  lessonMissing,
  lessonMaterialMissing,
  creditRequired,
  missingParameter,
  paymentInvalid,
}

class SimNavigationGuardContext {
  const SimNavigationGuardContext({
    required this.desiredRoute,
    this.origin = SimNavigationGuardOrigin.userAction,
    this.parameters = const {},
    this.returnTo,
    this.authReady = true,
    this.authenticated = false,
    this.sessionExpired = false,
    this.languageSelected = false,
    this.objectiveReady = false,
    this.placementPending = false,
    this.placementRequired = false,
    this.placementDone = false,
    this.placementSkipped = false,
    this.hasActiveLesson = false,
    this.lessonMaterialReady = false,
    this.requiresCredit = false,
    this.hasUsableCredit = true,
    this.parentAuthorized = false,
    this.paymentReturnValid = false,
  });

  final String desiredRoute;
  final SimNavigationGuardOrigin origin;
  final Map<String, String> parameters;
  final String? returnTo;
  final bool authReady;
  final bool authenticated;
  final bool sessionExpired;
  final bool languageSelected;
  final bool objectiveReady;
  final bool placementPending;
  final bool placementRequired;
  final bool placementDone;
  final bool placementSkipped;
  final bool hasActiveLesson;
  final bool lessonMaterialReady;
  final bool requiresCredit;
  final bool hasUsableCredit;
  final bool parentAuthorized;
  final bool paymentReturnValid;
}

class SimNavigationGuardDecision {
  const SimNavigationGuardDecision({
    required this.action,
    required this.targetRoute,
    required this.humanReason,
    required this.blocker,
    this.returnTo,
    this.preserveState = true,
  });

  final SimNavigationGuardAction action;
  final String targetRoute;
  final String humanReason;
  final SimNavigationGuardBlocker blocker;
  final String? returnTo;
  final bool preserveState;

  bool get allowed => action == SimNavigationGuardAction.allow;
  bool get denied => !allowed;
}

class SimNavigationGuardPolicy {
  const SimNavigationGuardPolicy();

  SimNavigationGuardDecision resolve(SimNavigationGuardContext context) {
    final route = simRouteByPath(context.desiredRoute);
    if (route == null) {
      return const SimNavigationGuardDecision(
        action: SimNavigationGuardAction.fallback,
        targetRoute: '/',
        humanReason: 'Rota invalida. Voltamos para um destino seguro.',
        blocker: SimNavigationGuardBlocker.invalidRoute,
      );
    }

    if (route.access == SimRouteAccess.server ||
        route.access == SimRouteAccess.external ||
        route.access == SimRouteAccess.internal ||
        route.isOverlay) {
      return SimNavigationGuardDecision(
        action: SimNavigationGuardAction.fallback,
        targetRoute: route.fallbackPath ?? '/',
        humanReason:
            'Este destino nao pode ser aberto como tela principal do app.',
        blocker: SimNavigationGuardBlocker.unauthorizedRoute,
      );
    }

    final parameterDecision = _validateRequiredParameters(route, context);
    if (parameterDecision != null) return parameterDecision;

    if (route.isProtected) {
      if (context.sessionExpired) {
        return SimNavigationGuardDecision(
          action: SimNavigationGuardAction.redirect,
          targetRoute: '/login',
          returnTo: _safeReturnTo(context, route),
          humanReason:
              'Sua sessao expirou. Entre novamente para continuar com seguranca.',
          blocker: SimNavigationGuardBlocker.sessionExpired,
        );
      }

      if (!context.authReady || !context.authenticated) {
        return SimNavigationGuardDecision(
          action: SimNavigationGuardAction.redirect,
          targetRoute: '/login',
          returnTo: _safeReturnTo(context, route),
          humanReason:
              'Login necessario para abrir este destino com seguranca.',
          blocker: SimNavigationGuardBlocker.authRequired,
        );
      }
    }

    final preconditionDecision = _validateRoutePreconditions(route, context);
    if (preconditionDecision != null) return preconditionDecision;

    if (context.requiresCredit &&
        !context.hasUsableCredit &&
        route.path != '/creditos') {
      return SimNavigationGuardDecision(
        action: SimNavigationGuardAction.redirect,
        targetRoute: '/creditos',
        returnTo: _safeReturnTo(context, route),
        humanReason:
            'Creditos necessarios para continuar. Abra creditos para regularizar.',
        blocker: SimNavigationGuardBlocker.creditRequired,
      );
    }

    return SimNavigationGuardDecision(
      action: SimNavigationGuardAction.allow,
      targetRoute: _targetWithQuery(route.path, context.parameters),
      humanReason: 'Destino permitido.',
      blocker: SimNavigationGuardBlocker.none,
    );
  }

  SimNavigationGuardDecision? _validateRequiredParameters(
    SimRouteContractEntry route,
    SimNavigationGuardContext context,
  ) {
    for (final required in route.requiredParams) {
      final value = context.parameters[required]?.trim();
      if (value == null || value.isEmpty) {
        return SimNavigationGuardDecision(
          action: SimNavigationGuardAction.block,
          targetRoute: route.fallbackPath ?? '/',
          humanReason:
              'Falta uma informacao obrigatoria para abrir este destino.',
          blocker: SimNavigationGuardBlocker.missingParameter,
        );
      }
    }
    return null;
  }

  SimNavigationGuardDecision? _validateRoutePreconditions(
    SimRouteContractEntry route,
    SimNavigationGuardContext context,
  ) {
    for (final precondition in route.preconditions) {
      switch (precondition) {
        case SimRoutePrecondition.authReady:
        case SimRoutePrecondition.authenticated:
          break;
        case SimRoutePrecondition.languageSelected:
          if (!context.languageSelected) {
            return const SimNavigationGuardDecision(
              action: SimNavigationGuardAction.redirect,
              targetRoute: '/cyber/idioma',
              humanReason:
                  'Escolha o idioma antes de continuar para esta etapa.',
              blocker: SimNavigationGuardBlocker.onboardingIncomplete,
            );
          }
        case SimRoutePrecondition.objectiveReady:
          if (!context.objectiveReady) {
            return const SimNavigationGuardDecision(
              action: SimNavigationGuardAction.redirect,
              targetRoute: '/cyber/objeto',
              humanReason:
                  'Defina seu objetivo antes de continuar para esta etapa.',
              blocker: SimNavigationGuardBlocker.onboardingIncomplete,
            );
          }
        case SimRoutePrecondition.activeLesson:
          if (context.placementPending ||
              (context.placementRequired &&
                  !context.placementDone &&
                  !context.placementSkipped)) {
            return const SimNavigationGuardDecision(
              action: SimNavigationGuardAction.redirect,
              targetRoute: '/cyber/placement',
              humanReason:
                  'Placement pendente. Conclua essa etapa antes da aula.',
              blocker: SimNavigationGuardBlocker.placementPending,
            );
          }
          if (!context.hasActiveLesson) {
            return const SimNavigationGuardDecision(
              action: SimNavigationGuardAction.redirect,
              targetRoute: '/cyber/curriculo',
              humanReason: 'Ainda nao ha aula ativa para abrir com seguranca.',
              blocker: SimNavigationGuardBlocker.lessonMissing,
            );
          }
          if (!context.lessonMaterialReady) {
            return const SimNavigationGuardDecision(
              action: SimNavigationGuardAction.redirect,
              targetRoute: '/cyber/curriculo',
              humanReason:
                  'A aula ainda nao tem material minimo pronto para abrir.',
              blocker: SimNavigationGuardBlocker.lessonMaterialMissing,
            );
          }
        case SimRoutePrecondition.parentRole:
          if (!context.parentAuthorized) {
            return const SimNavigationGuardDecision(
              action: SimNavigationGuardAction.fallback,
              targetRoute: '/',
              humanReason: 'Acesso nao autorizado para este painel.',
              blocker: SimNavigationGuardBlocker.unauthorizedRoute,
            );
          }
        case SimRoutePrecondition.paymentReturn:
          if (!context.paymentReturnValid) {
            return const SimNavigationGuardDecision(
              action: SimNavigationGuardAction.redirect,
              targetRoute: '/creditos',
              humanReason:
                  'Retorno de pagamento invalido ou incompleto. Voltamos para creditos.',
              blocker: SimNavigationGuardBlocker.paymentInvalid,
            );
          }
        case SimRoutePrecondition.serverOnly:
        case SimRoutePrecondition.externalApp:
          return SimNavigationGuardDecision(
            action: SimNavigationGuardAction.fallback,
            targetRoute: route.fallbackPath ?? '/',
            humanReason:
                'Este destino nao e autorizado como navegacao interna.',
            blocker: SimNavigationGuardBlocker.unauthorizedRoute,
          );
      }
    }
    return null;
  }
}

String? _safeReturnTo(
  SimNavigationGuardContext context,
  SimRouteContractEntry route,
) {
  final requested = context.returnTo?.trim();
  if (requested != null && requested.isNotEmpty) {
    final safe = _safePathOnly(requested);
    if (safe != null) return safe;
    return null;
  }

  if (route.access != SimRouteAccess.public &&
      route.access != SimRouteAccess.protected) {
    return null;
  }
  if (route.isOverlay) return null;
  return _targetWithQuery(route.path, context.parameters);
}

String? _safePathOnly(String rawPath) {
  if (!rawPath.startsWith('/') || rawPath.startsWith('//')) return null;
  final uri = Uri.tryParse(rawPath);
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty) return null;
  final path = uri.path.isEmpty ? '/' : uri.path;
  final normalized = uri.fragment.isEmpty ? path : '$path#${uri.fragment}';
  final route = simRouteByPath(normalized);
  if (route == null || route.isOverlay) return null;
  if (route.access == SimRouteAccess.server ||
      route.access == SimRouteAccess.external ||
      route.access == SimRouteAccess.internal) {
    return null;
  }
  return normalized;
}

String _targetWithQuery(String path, Map<String, String> parameters) {
  if (parameters.isEmpty) return path;
  final query = Uri(queryParameters: parameters).query;
  return '$path?$query';
}
