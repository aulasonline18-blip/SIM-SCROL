import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/session/navigation_state.dart';

void main() {
  test('goLogin stores only a valid return target', () {
    final nav = NavigationState();

    nav.goLogin(target: '/cyber/aula');
    expect(nav.route, '/login');
    expect(nav.returnTo, '/cyber/aula');

    nav.goLogin(target: '//evil');
    expect(nav.route, '/login');
    expect(nav.returnTo, '/');

    nav.goLogin(target: '/rota-inexistente');
    expect(nav.route, '/login');
    expect(nav.returnTo, '/');
  });

  test('logout path returns to safe portal route', () {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'pt-BR'
      ..freeText = 'Estudar geografia'
      ..lessonLocalId = 'lesson-auth'
      ..route = '/cyber/aula';
    addTearDown(session.dispose);

    session.authSession.applySupabaseSession(null);
    session.goPortal();

    expect(session.authed, isFalse);
    expect(session.route, '/');
  });
}
