import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/session/navigation_state.dart';
import 'package:sim_mobile/sim/organism/sim_organism.dart';

void main() {
  test('LabSession route setter delegates to validated navigation', () {
    final session = LabSession();
    addTearDown(session.dispose);
    var notifications = 0;
    session.addListener(() => notifications++);

    session.route = '/cyber/idioma';
    expect(session.route, '/cyber/idioma');

    session.route = '/rota-inexistente';
    expect(session.route, '/');
    expect(session.rejectedRoute, '/rota-inexistente');
    expect(notifications, 2);
  });

  test('LabSession returnTo setter delegates to sanitized navigation', () {
    final session = LabSession();
    addTearDown(session.dispose);
    var notifications = 0;
    session.addListener(() => notifications++);

    session.returnTo = '/cyber/aula';
    expect(session.returnTo, '/cyber/aula');

    session.returnTo = '//evil';
    expect(session.returnTo, '/');
    expect(notifications, 2);
  });

  test('route decision is applied transactionally through session', () {
    final session = LabSession()
      ..authReady = true
      ..authed = false
      ..route = '/cyber/aula';
    addTearDown(session.dispose);

    final decision = const SimOrganismRouter().resolve(
      path: '/cyber/aula',
      authed: false,
      hasLanguage: true,
      hasObjective: true,
    );

    session.applyRouteDecision(decision);

    expect(session.route, '/login');
    expect(session.returnTo, '/cyber/aula');
  });

  test('login returnTo cannot store an invalid target', () {
    final nav = NavigationState();

    nav.goLogin(target: '/rota-inexistente');

    expect(nav.route, '/login');
    expect(nav.returnTo, '/');
  });
}
