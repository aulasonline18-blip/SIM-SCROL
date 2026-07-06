import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/navigation/sim_route_contract.dart';
import 'package:sim_mobile/sim/school/sim_school_routes.dart';

void main() {
  test('all route names and paths are unique and non-empty', () {
    final names = <String>{};
    final paths = <String>{};

    for (final route in simRouteContract) {
      expect(route.name.trim(), isNotEmpty);
      expect(route.path.trim(), isNotEmpty);
      expect(
        names.add(route.name),
        isTrue,
        reason: 'Duplicate name ${route.name}',
      );
      expect(
        paths.add(route.path),
        isTrue,
        reason: 'Duplicate path ${route.path}',
      );
    }
  });

  test('protected routes declare guard preconditions and fallback', () {
    final protectedRoutes = simRouteContract.where(
      (route) => route.isProtected,
    );

    for (final route in protectedRoutes) {
      expect(
        route.preconditions,
        contains(SimRoutePrecondition.authenticated),
        reason: '${route.name} must declare authentication',
      );
      expect(
        route.preconditions,
        contains(SimRoutePrecondition.authReady),
        reason: '${route.name} must declare auth readiness',
      );
      expect(route.fallbackPath, isNotNull, reason: route.name);
    }
  });

  test(
    'routes with implicit state dependencies declare required parameters',
    () {
      expect(
        simRouteByName('preparation')!.requiredParams,
        contains('lessonLocalId'),
      );
      expect(
        simRouteByName('placement')!.requiredParams,
        contains('lessonLocalId'),
      );
      expect(
        simRouteByName('classroom')!.requiredParams,
        contains('lessonLocalId'),
      );
      expect(
        simRouteByName('checkoutReturn')!.requiredParams,
        contains('session_id'),
      );
    },
  );

  test('deep-linkable routes declare public or protected access', () {
    final deepLinks = simRouteContract.where((route) => route.canDeepLink);

    for (final route in deepLinks) {
      expect(
        route.access,
        isIn([SimRouteAccess.public, SimRouteAccess.protected]),
        reason: '${route.name} is deep-linkable with invalid access',
      );
      expect(route.surface, SimRouteSurface.screen, reason: route.name);
    }
  });

  test('lookup by name and normalized path works', () {
    expect(simRouteByName('portal')?.path, '/');
    expect(simRouteByName('classroom')?.path, '/cyber/aula');
    expect(simRouteByPath('/creditos?returnTo=/cyber/aula')?.name, 'credits');
    expect(
      simRouteByPath('/checkout/return?session_id=cs_test')?.name,
      'checkoutReturn',
    );
    expect(simRouteByPath('/cyber/aula#drawer')?.name, 'classroomDrawer');
    expect(
      simRouteByPath('https://checkout.stripe.com/')?.name,
      'externalStripeCheckout',
    );
    expect(simRouteByPath('/rota-inexistente'), isNull);
  });

  test('contract includes all live screen api and external routes', () {
    final contractPaths = simRouteContract.map((route) => route.path).toSet();

    for (final liveRoute in simLiveRoutes) {
      expect(
        contractPaths,
        contains(liveRoute.path),
        reason: 'Missing ${liveRoute.path}',
      );
    }
  });

  test('contract includes the main app destinations', () {
    const mainRoutes = {
      '/',
      '/login',
      '/cyber/idioma',
      '/cyber/objeto',
      '/cyber/curriculo',
      '/cyber/placement',
      '/cyber/aula',
      '/creditos',
      '/checkout/return',
      '/pai',
      '/privacidade',
      '/termos',
      '/conta/deletar',
    };
    final contractPaths = simScreenRoutes.map((route) => route.path).toSet();

    expect(contractPaths, containsAll(mainRoutes));
  });

  test('modals drawers and dialogs are internal and not deep-linkable', () {
    expect(simOverlayRoutes, isNotEmpty);

    for (final route in simOverlayRoutes) {
      expect(route.access, SimRouteAccess.internal, reason: route.name);
      expect(route.canDeepLink, isFalse, reason: route.name);
      expect(route.restorable, isFalse, reason: route.name);
    }
  });

  test('server and external routes are not restorable app screens', () {
    final nonScreens = simRouteContract.where(
      (route) =>
          route.access == SimRouteAccess.server ||
          route.access == SimRouteAccess.external,
    );

    for (final route in nonScreens) {
      expect(route.canDeepLink, isFalse, reason: route.name);
      expect(route.restorable, isFalse, reason: route.name);
      expect(
        route.preconditions,
        isNotEmpty,
        reason: '${route.name} should declare server/external precondition',
      );
    }
  });
}
