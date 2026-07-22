import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/session/navigation_state.dart';
import 'package:sim_mobile/sim/organism/sim_organism.dart';

void main() {
  test('openRoute and returnTo reject unknown app routes', () {
    final navigation = NavigationState();
    var notifications = 0;
    navigation.addListener(() => notifications += 1);

    navigation.openRoute('/cyber/aula');
    expect(navigation.route, '/cyber/aula');

    navigation.openRoute('/rota/inexistente');
    expect(navigation.route, '/');
    expect(notifications, 2);

    navigation.goLogin(target: '/rota/inexistente');
    expect(navigation.returnTo, '/');
  });

  test('auth guarded route is corrected by the official router contract', () {
    const router = SimOrganismRouter();

    final unauthenticated = router.resolve(
      path: '/cyber/aula',
      authed: false,
      hasLanguage: true,
      hasObjective: true,
    );
    expect(unauthenticated.destination, '/login');

    final unknown = router.resolve(
      path: '/rota/inexistente',
      authed: true,
      hasLanguage: true,
      hasObjective: true,
    );
    expect(unknown.destination, '/');
    expect(unknown.guard, SimOrganismRouteGuard.unknown);
  });

  test('session route setter notifies UI through NavigationState', () {
    final session = LabSession();
    var notifications = 0;
    session.addListener(() => notifications += 1);

    session.route = '/cyber/idioma';

    expect(session.route, '/cyber/idioma');
    expect(notifications, 1);
  });
}
