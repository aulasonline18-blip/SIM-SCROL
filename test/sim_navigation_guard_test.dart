import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/navigation/sim_navigation_guard_policy.dart';

void main() {
  const policy = SimNavigationGuardPolicy();

  test('public route without auth is allowed', () {
    final decision = policy.resolve(
      const SimNavigationGuardContext(desiredRoute: '/privacidade'),
    );

    expect(decision.action, SimNavigationGuardAction.allow);
    expect(decision.targetRoute, '/privacidade');
    expect(decision.blocker, SimNavigationGuardBlocker.none);
  });

  test('protected route without auth redirects to login with returnTo', () {
    final decision = policy.resolve(
      const SimNavigationGuardContext(desiredRoute: '/creditos'),
    );

    expect(decision.action, SimNavigationGuardAction.redirect);
    expect(decision.targetRoute, '/login');
    expect(decision.returnTo, '/creditos');
    expect(decision.blocker, SimNavigationGuardBlocker.authRequired);
    expect(decision.humanReason, isNotEmpty);
  });

  test('expired session redirects to login', () {
    final decision = policy.resolve(
      const SimNavigationGuardContext(
        desiredRoute: '/creditos',
        authenticated: true,
        sessionExpired: true,
      ),
    );

    expect(decision.action, SimNavigationGuardAction.redirect);
    expect(decision.targetRoute, '/login');
    expect(decision.blocker, SimNavigationGuardBlocker.sessionExpired);
  });

  test('incomplete onboarding redirects to next required step', () {
    final missingLanguage = policy.resolve(
      const SimNavigationGuardContext(
        desiredRoute: '/cyber/objeto',
        authenticated: true,
      ),
    );
    final missingObjective = policy.resolve(
      const SimNavigationGuardContext(
        desiredRoute: '/cyber/curriculo',
        parameters: {'lessonLocalId': 'lesson-1'},
        authenticated: true,
        languageSelected: true,
      ),
    );

    expect(missingLanguage.targetRoute, '/cyber/idioma');
    expect(
      missingLanguage.blocker,
      SimNavigationGuardBlocker.onboardingIncomplete,
    );
    expect(missingObjective.targetRoute, '/cyber/objeto');
  });

  test('pending placement blocks classroom and redirects to placement', () {
    final decision = policy.resolve(
      const SimNavigationGuardContext(
        desiredRoute: '/cyber/aula',
        parameters: {'lessonLocalId': 'lesson-1'},
        authenticated: true,
        languageSelected: true,
        objectiveReady: true,
        placementPending: true,
        placementRequired: true,
        hasActiveLesson: true,
        lessonMaterialReady: true,
      ),
    );

    expect(decision.action, SimNavigationGuardAction.redirect);
    expect(decision.targetRoute, '/cyber/placement');
    expect(decision.blocker, SimNavigationGuardBlocker.placementPending);
  });

  test(
    'completed placement allows classroom when lesson material is ready',
    () {
      final decision = policy.resolve(
        const SimNavigationGuardContext(
          desiredRoute: '/cyber/aula',
          parameters: {'lessonLocalId': 'lesson-1'},
          authenticated: true,
          languageSelected: true,
          objectiveReady: true,
          placementDone: true,
          hasActiveLesson: true,
          lessonMaterialReady: true,
        ),
      );

      expect(decision.action, SimNavigationGuardAction.allow);
      expect(decision.targetRoute, '/cyber/aula?lessonLocalId=lesson-1');
    },
  );

  test('classroom without active lesson does not open fake room', () {
    final decision = policy.resolve(
      const SimNavigationGuardContext(
        desiredRoute: '/cyber/aula',
        parameters: {'lessonLocalId': 'lesson-1'},
        authenticated: true,
        languageSelected: true,
        objectiveReady: true,
        placementDone: true,
      ),
    );

    expect(decision.action, SimNavigationGuardAction.redirect);
    expect(decision.targetRoute, '/cyber/curriculo');
    expect(decision.blocker, SimNavigationGuardBlocker.lessonMissing);
  });

  test('classroom without minimum material redirects safely', () {
    final decision = policy.resolve(
      const SimNavigationGuardContext(
        desiredRoute: '/cyber/aula',
        parameters: {'lessonLocalId': 'lesson-1'},
        authenticated: true,
        languageSelected: true,
        objectiveReady: true,
        placementDone: true,
        hasActiveLesson: true,
      ),
    );

    expect(decision.action, SimNavigationGuardAction.redirect);
    expect(decision.targetRoute, '/cyber/curriculo');
    expect(decision.blocker, SimNavigationGuardBlocker.lessonMaterialMissing);
  });

  test('credit requirement without credit redirects to credits', () {
    final decision = policy.resolve(
      const SimNavigationGuardContext(
        desiredRoute: '/cyber/objeto',
        authenticated: true,
        languageSelected: true,
        requiresCredit: true,
        hasUsableCredit: false,
      ),
    );

    expect(decision.action, SimNavigationGuardAction.redirect);
    expect(decision.targetRoute, '/creditos');
    expect(decision.returnTo, '/cyber/objeto');
    expect(decision.blocker, SimNavigationGuardBlocker.creditRequired);
  });

  test('unauthorized route falls back safely', () {
    final decision = policy.resolve(
      const SimNavigationGuardContext(
        desiredRoute: '/pai',
        authenticated: true,
      ),
    );

    expect(decision.action, SimNavigationGuardAction.fallback);
    expect(decision.targetRoute, '/');
    expect(decision.blocker, SimNavigationGuardBlocker.unauthorizedRoute);
    expect(decision.humanReason, contains('Acesso'));
  });

  test('deep link protected route respects guards', () {
    final decision = policy.resolve(
      const SimNavigationGuardContext(
        desiredRoute: '/creditos',
        origin: SimNavigationGuardOrigin.deepLink,
      ),
    );

    expect(decision.action, SimNavigationGuardAction.redirect);
    expect(decision.targetRoute, '/login');
    expect(decision.returnTo, '/creditos');
  });

  test('restore protected route respects guards', () {
    final decision = policy.resolve(
      const SimNavigationGuardContext(
        desiredRoute: '/cyber/aula',
        origin: SimNavigationGuardOrigin.restore,
        parameters: {'lessonLocalId': 'lesson-1'},
        authenticated: true,
        languageSelected: true,
        objectiveReady: true,
        placementRequired: true,
        hasActiveLesson: true,
        lessonMaterialReady: true,
      ),
    );

    expect(decision.action, SimNavigationGuardAction.redirect);
    expect(decision.targetRoute, '/cyber/placement');
  });

  test('all denied decisions include human reason', () {
    final decisions = [
      policy.resolve(const SimNavigationGuardContext(desiredRoute: '/missing')),
      policy.resolve(
        const SimNavigationGuardContext(desiredRoute: '/creditos'),
      ),
      policy.resolve(
        const SimNavigationGuardContext(
          desiredRoute: '/cyber/aula',
          parameters: {'lessonLocalId': 'lesson-1'},
          authenticated: true,
          languageSelected: true,
          objectiveReady: true,
        ),
      ),
    ];

    for (final decision in decisions) {
      expect(decision.denied, isTrue);
      expect(decision.humanReason.trim(), isNotEmpty);
    }
  });

  test('unsafe returnTo is rejected', () {
    final decision = policy.resolve(
      const SimNavigationGuardContext(
        desiredRoute: '/creditos',
        returnTo: 'https://evil.example/phish',
      ),
    );

    expect(decision.action, SimNavigationGuardAction.redirect);
    expect(decision.targetRoute, '/login');
    expect(decision.returnTo, isNull);
  });

  test('missing required parameter blocks route with fallback', () {
    final decision = policy.resolve(
      const SimNavigationGuardContext(
        desiredRoute: '/cyber/curriculo',
        authenticated: true,
        languageSelected: true,
        objectiveReady: true,
      ),
    );

    expect(decision.action, SimNavigationGuardAction.block);
    expect(decision.targetRoute, '/cyber/objeto');
    expect(decision.blocker, SimNavigationGuardBlocker.missingParameter);
  });

  test('invalid checkout return goes back to credits', () {
    final decision = policy.resolve(
      const SimNavigationGuardContext(
        desiredRoute: '/checkout/return',
        parameters: {'session_id': 'cs_test_123'},
        authenticated: true,
      ),
    );

    expect(decision.action, SimNavigationGuardAction.redirect);
    expect(decision.targetRoute, '/creditos');
    expect(decision.blocker, SimNavigationGuardBlocker.paymentInvalid);
  });
}
