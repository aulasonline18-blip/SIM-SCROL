import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/navigation/sim_navigation_restore_policy.dart';
import 'package:sim_mobile/sim/navigation/sim_route_state.dart';
import 'package:sim_mobile/sim/navigation/sim_route_state_store.dart';

void main() {
  const policy = SimNavigationRestorePolicy();

  test('valid restorable last route is restored', () {
    final decision = policy.resolve(
      const SimNavigationRestoreContext(
        lastKnownRoute: '/privacidade',
        authenticated: false,
      ),
    );

    expect(decision.action, SimNavigationRestoreAction.restore);
    expect(decision.routePath, '/privacidade');
    expect(decision.clearSnapshot, isFalse);
  });

  test('valid active lesson restores classroom', () {
    final decision = policy.resolve(
      const SimNavigationRestoreContext(
        lastKnownRoute: '/cyber/aula',
        authenticated: true,
        hasActiveLesson: true,
      ),
    );

    expect(decision.action, SimNavigationRestoreAction.restore);
    expect(decision.routePath, '/cyber/aula');
    expect(decision.showRecoverableError, isFalse);
  });

  test('incomplete active lesson falls back with recoverable error', () {
    final decision = policy.resolve(
      const SimNavigationRestoreContext(
        lastKnownRoute: '/cyber/aula',
        authenticated: true,
        hasActiveLesson: true,
        activeLessonIncomplete: true,
      ),
    );

    expect(decision.action, SimNavigationRestoreAction.fallback);
    expect(decision.routePath, '/cyber/curriculo');
    expect(decision.showRecoverableError, isTrue);
  });

  test('overlay sheet and drawer are not restored as primary route', () {
    final drawer = policy.resolve(
      const SimNavigationRestoreContext(
        lastKnownRoute: '/cyber/aula#drawer',
        authenticated: true,
        hasActiveLesson: true,
      ),
    );
    final sheet = policy.resolve(
      const SimNavigationRestoreContext(
        lastKnownRoute: '/cyber/aula#doubt',
        authenticated: true,
        hasActiveLesson: true,
      ),
    );

    expect(drawer.action, SimNavigationRestoreAction.fallback);
    expect(drawer.routePath, '/cyber/aula');
    expect(drawer.clearSnapshot, isTrue);
    expect(sheet.routePath, '/cyber/aula');
  });

  test('unknown route falls back safely without crashing', () {
    final authed = policy.resolve(
      const SimNavigationRestoreContext(
        lastKnownRoute: '/missing',
        authenticated: true,
      ),
    );
    final expired = policy.resolve(
      const SimNavigationRestoreContext(lastKnownRoute: '/missing'),
    );

    expect(authed.action, SimNavigationRestoreAction.fallback);
    expect(authed.routePath, '/');
    expect(expired.action, SimNavigationRestoreAction.requireLogin);
    expect(expired.routePath, '/login');
  });

  test('expired session redirects protected route to login with returnTo', () {
    final decision = policy.resolve(
      const SimNavigationRestoreContext(lastKnownRoute: '/cyber/aula'),
    );

    expect(decision.action, SimNavigationRestoreAction.requireLogin);
    expect(decision.routePath, '/login');
    expect(decision.returnTo, '/cyber/aula');
    expect(decision.clearSnapshot, isFalse);
  });

  test('protected route without auth does not restore directly', () {
    final decision = policy.resolve(
      const SimNavigationRestoreContext(lastKnownRoute: '/creditos'),
    );

    expect(decision.action, SimNavigationRestoreAction.requireLogin);
    expect(decision.routePath, '/login');
    expect(decision.returnTo, '/creditos');
  });

  test('expired snapshot falls back and asks caller to clear it', () {
    final createdAt = DateTime.utc(2026, 1, 1);
    final decision = policy.resolve(
      SimNavigationRestoreContext(
        lastKnownRoute: '/login',
        snapshot: SimRouteStateSnapshot(
          routeName: 'login',
          sessionKey: 'default',
          version: simRouteStateSnapshotVersion,
          createdAt: createdAt,
          values: const {'returnTo': '/cyber/aula'},
        ),
        now: createdAt.add(const Duration(hours: 1)),
      ),
    );

    expect(decision.action, SimNavigationRestoreAction.clearInvalidSnapshot);
    expect(decision.routePath, '/');
    expect(decision.clearSnapshot, isTrue);
  });

  test('incompatible snapshot version is invalidated', () {
    final decision = policy.resolve(
      const SimNavigationRestoreContext(
        lastKnownRoute: '/privacidade',
        snapshot: SimRouteStateSnapshot(
          routeName: 'privacy',
          sessionKey: 'default',
          version: simRouteStateSnapshotVersion - 1,
          values: {'scrollOffset': 10},
        ),
      ),
    );

    expect(decision.action, SimNavigationRestoreAction.clearInvalidSnapshot);
    expect(decision.clearSnapshot, isTrue);
  });

  test('snapshot from another route is invalidated', () {
    final decision = policy.resolve(
      const SimNavigationRestoreContext(
        lastKnownRoute: '/privacidade',
        snapshot: SimRouteStateSnapshot(
          routeName: 'terms',
          sessionKey: 'default',
          version: simRouteStateSnapshotVersion,
          values: {'scrollOffset': 10},
        ),
      ),
    );

    expect(decision.action, SimNavigationRestoreAction.clearInvalidSnapshot);
    expect(decision.clearSnapshot, isTrue);
  });

  test('recoverable error is surfaced without crashing restoration', () {
    final decision = policy.resolve(
      const SimNavigationRestoreContext(
        lastKnownRoute: '/creditos',
        authenticated: true,
        hasRecoverableError: true,
      ),
    );

    expect(decision.action, SimNavigationRestoreAction.restore);
    expect(decision.routePath, '/creditos');
    expect(decision.showRecoverableError, isTrue);
  });

  test('server and external routes never restore as app screens', () {
    final server = policy.resolve(
      const SimNavigationRestoreContext(
        lastKnownRoute: '/api/bootstrap-t00',
        authenticated: true,
      ),
    );
    final external = policy.resolve(
      const SimNavigationRestoreContext(
        lastKnownRoute: 'https://checkout.stripe.com/',
        authenticated: true,
      ),
    );

    expect(server.action, SimNavigationRestoreAction.fallback);
    expect(server.routePath, '/');
    expect(server.clearSnapshot, isTrue);
    expect(external.routePath, '/');
    expect(external.clearSnapshot, isTrue);
  });

  test('pending placement restores placement instead of skipping to class', () {
    final decision = policy.resolve(
      const SimNavigationRestoreContext(
        lastKnownRoute: '/cyber/placement',
        authenticated: true,
        placementPending: true,
        placementRequired: true,
        hasActiveLesson: true,
      ),
    );

    expect(decision.action, SimNavigationRestoreAction.requirePlacement);
    expect(decision.routePath, '/cyber/placement');
  });

  test('completed placement falls back to preparation', () {
    final decision = policy.resolve(
      const SimNavigationRestoreContext(
        lastKnownRoute: '/cyber/placement',
        authenticated: true,
      ),
    );

    expect(decision.action, SimNavigationRestoreAction.fallback);
    expect(decision.routePath, '/cyber/curriculo');
  });

  test('non-restorable destructive route falls back without restoring', () {
    final decision = policy.resolve(
      const SimNavigationRestoreContext(
        lastKnownRoute: '/conta/deletar',
        authenticated: true,
      ),
    );

    expect(decision.action, SimNavigationRestoreAction.fallback);
    expect(decision.routePath, '/login');
    expect(decision.clearSnapshot, isTrue);
  });
}
