import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/session/navigation_state.dart';
import 'package:sim_mobile/sim/organism/sim_organism.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test('openRoute accepts only known SIM screen routes', () {
    final nav = NavigationState();
    var notifications = 0;
    nav.addListener(() => notifications++);

    nav.openRoute('/cyber/aula');
    expect(nav.route, '/cyber/aula');
    expect(nav.rejectedRoute, isNull);

    nav.openRoute('/rota-inexistente');
    expect(nav.route, '/');
    expect(nav.rejectedRoute, '/rota-inexistente');
    expect(nav.routeFallbackReason, 'invalid_route');
    expect(notifications, 2);
  });

  test('safe returnTo validates real internal destination', () {
    expect(safeNavigationReturnTo('/cyber/aula'), '/cyber/aula');
    expect(safeNavigationReturnTo('/rota-inexistente'), '/');
    expect(safeNavigationReturnTo('//evil'), '/');
    expect(safeNavigationReturnTo('https://evil.test/cyber/aula'), '/');
  });

  test('router catalog remains the source for valid app screens', () {
    expect(SimOrganismRouter.isKnownScreenRoute('/cyber/aula'), isTrue);
    expect(SimOrganismRouter.isKnownScreenRoute('/rota-inexistente'), isFalse);
  });

  test('external door waits for launch success and failure', () async {
    final opened = <Uri>[];
    final success = NavigationState(
      launcher: (uri, mode) async {
        expect(mode, LaunchMode.externalApplication);
        opened.add(uri);
        return true;
      },
    );

    expect(await success.openExternalDoor('https://example.com'), isTrue);
    expect(success.externalDoorPending, isNull);
    expect(success.externalDoorOpened, 'https://example.com');
    expect(success.externalDoorError, isNull);
    expect(opened.single.toString(), 'https://example.com');

    final failure = NavigationState(launcher: (_, _) async => false);
    expect(await failure.openExternalDoor('https://example.com/fail'), isFalse);
    expect(failure.externalDoorPending, isNull);
    expect(failure.externalDoorOpened, isNull);
    expect(failure.externalDoorError, 'external_door_open_failed');
  });
}
