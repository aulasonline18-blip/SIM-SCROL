import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/navigation/sim_deep_link_policy.dart';

void main() {
  const policy = SimDeepLinkPolicy();

  test('valid public URL opens directly', () {
    final decision = policy.resolve(
      const SimDeepLinkContext(
        rawLink: 'https://gemini-aid-pal.lovable.app/privacidade',
      ),
    );

    expect(decision.action, SimDeepLinkAction.open);
    expect(decision.routePath, '/privacidade');
    expect(decision.backStack, ['/privacidade']);
  });

  test(
    'protected route without auth redirects to login with safe returnTo',
    () {
      final decision = policy.resolve(
        const SimDeepLinkContext(
          rawLink:
              'https://gemini-aid-pal.lovable.app/creditos'
              '?returnTo=/cyber/aula',
        ),
      );

      expect(decision.action, SimDeepLinkAction.redirectToLogin);
      expect(decision.routePath, '/login');
      expect(decision.returnTo, '/creditos?returnTo=%2Fcyber%2Faula');
      expect(decision.backStack, ['/', '/login']);
    },
  );

  test('protected route with auth opens', () {
    final decision = policy.resolve(
      const SimDeepLinkContext(
        rawLink: 'https://gemini-aid-pal.lovable.app/creditos',
        authenticated: true,
      ),
    );

    expect(decision.action, SimDeepLinkAction.open);
    expect(decision.routePath, '/creditos');
    expect(decision.backStack, ['/', '/creditos']);
  });

  test('unknown route falls back safely without crashing', () {
    final decision = policy.resolve(
      const SimDeepLinkContext(
        rawLink: 'https://gemini-aid-pal.lovable.app/rota-inexistente',
        authenticated: true,
      ),
    );

    expect(decision.action, SimDeepLinkAction.fallback);
    expect(decision.routePath, '/');
    expect(decision.backStack, ['/']);
  });

  test('missing required parameter rejects route', () {
    final decision = policy.resolve(
      const SimDeepLinkContext(
        rawLink: 'https://gemini-aid-pal.lovable.app/checkout/return',
        authenticated: true,
      ),
    );

    expect(decision.action, SimDeepLinkAction.reject);
    expect(decision.reason, contains('session_id'));
  });

  test('present required parameter accepts checkout return', () {
    final decision = policy.resolve(
      const SimDeepLinkContext(
        rawLink:
            'https://gemini-aid-pal.lovable.app/checkout/return?session_id=cs_test_123',
        authenticated: true,
      ),
    );

    expect(decision.action, SimDeepLinkAction.open);
    expect(decision.routePath, '/checkout/return');
    expect(decision.parameters['session_id'], 'cs_test_123');
    expect(decision.backStack, [
      '/creditos',
      '/checkout/return?session_id=cs_test_123',
    ]);
  });

  test('unexpected sensitive parameter is rejected', () {
    final decision = policy.resolve(
      const SimDeepLinkContext(
        rawLink:
            'https://gemini-aid-pal.lovable.app/privacidade'
            '?access_token=secret',
      ),
    );

    expect(decision.action, SimDeepLinkAction.reject);
    expect(decision.reason, contains('sensitive parameter access_token'));
  });

  test('overlay cannot be a primary deep link destination', () {
    final decision = policy.resolve(
      const SimDeepLinkContext(
        rawLink: 'https://gemini-aid-pal.lovable.app/cyber/aula#doubt',
        authenticated: true,
        hasActiveLesson: true,
      ),
    );

    expect(decision.action, SimDeepLinkAction.reject);
    expect(decision.routePath, '/cyber/aula#doubt');
  });

  test('server and external routes do not become internal destinations', () {
    final server = policy.resolve(
      const SimDeepLinkContext(
        rawLink: 'https://gemini-aid-pal.lovable.app/api/bootstrap-t00',
        authenticated: true,
      ),
    );
    final external = policy.resolve(
      const SimDeepLinkContext(
        rawLink: 'https://checkout.stripe.com/',
        authenticated: true,
      ),
    );

    expect(server.action, SimDeepLinkAction.reject);
    expect(server.routePath, '/api/bootstrap-t00');
    expect(external.action, SimDeepLinkAction.external);
    expect(external.routePath, 'https://checkout.stripe.com/');
  });

  test('closed app builds a safe minimal back stack', () {
    final decision = policy.resolve(
      const SimDeepLinkContext(
        rawLink: 'https://gemini-aid-pal.lovable.app/creditos',
        authenticated: true,
        appAlreadyOpen: false,
      ),
    );

    expect(decision.action, SimDeepLinkAction.open);
    expect(decision.backStack, ['/', '/creditos']);
  });

  test('open app avoids duplicating the current route', () {
    final decision = policy.resolve(
      const SimDeepLinkContext(
        rawLink: '/creditos',
        source: SimLinkSource.internalLink,
        authenticated: true,
        appAlreadyOpen: true,
        currentPath: '/creditos',
      ),
    );

    expect(decision.action, SimDeepLinkAction.noop);
    expect(decision.routePath, '/creditos');
  });

  test('pending placement blocks internal classroom link', () {
    final decision = policy.resolve(
      const SimDeepLinkContext(
        rawLink: '/cyber/aula?lessonLocalId=lesson-1',
        source: SimLinkSource.internalLink,
        authenticated: true,
        hasActiveLesson: true,
        placementPending: true,
      ),
    );

    expect(decision.action, SimDeepLinkAction.requirePlacement);
    expect(decision.routePath, '/cyber/placement');
    expect(decision.backStack, ['/', '/cyber/placement']);
  });

  test('checkout return validates session_id format', () {
    final decision = policy.resolve(
      const SimDeepLinkContext(
        rawLink:
            'https://gemini-aid-pal.lovable.app/checkout/return?session_id=bad',
        authenticated: true,
      ),
    );

    expect(decision.action, SimDeepLinkAction.reject);
    expect(decision.reason, contains('session_id'));
  });

  test('malformed URL is rejected without crashing', () {
    final decision = policy.resolve(
      const SimDeepLinkContext(rawLink: 'http://[::1'),
    );

    expect(decision.action, SimDeepLinkAction.reject);
  });

  test('external deep link cannot open non-deep-linkable classroom route', () {
    final decision = policy.resolve(
      const SimDeepLinkContext(
        rawLink:
            'https://gemini-aid-pal.lovable.app/cyber/aula?lessonLocalId=lesson-1',
        authenticated: true,
        hasActiveLesson: true,
      ),
    );

    expect(decision.action, SimDeepLinkAction.reject);
    expect(decision.reason, contains('not declared'));
  });

  test('internal link may open contract screen with required parameters', () {
    final decision = policy.resolve(
      const SimDeepLinkContext(
        rawLink: '/cyber/aula?lessonLocalId=lesson-1',
        source: SimLinkSource.internalLink,
        authenticated: true,
        hasActiveLesson: true,
      ),
    );

    expect(decision.action, SimDeepLinkAction.open);
    expect(decision.routePath, '/cyber/aula');
    expect(decision.parameters['lessonLocalId'], 'lesson-1');
  });
}
