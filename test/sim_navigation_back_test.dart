import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/navigation/sim_back_policy.dart';
import 'package:sim_mobile/sim/navigation/sim_route_contract.dart';

void main() {
  const policy = SimBackPolicy();

  test(
    'active classroom back returns to safe destination without clearing state',
    () {
      final decision = policy.resolve(
        const SimBackContext(currentPath: '/cyber/aula', hasActiveLesson: true),
      );

      expect(decision.action, SimBackAction.navigate);
      expect(decision.destinationPath, '/');
      expect(decision.preserveState, isTrue);
      expect(decision.handlesBack, isTrue);
    },
  );

  test('classroom without active lesson returns to objective fallback', () {
    final decision = policy.resolve(
      const SimBackContext(currentPath: '/cyber/aula'),
    );

    expect(decision.action, SimBackAction.navigate);
    expect(decision.destinationPath, '/cyber/objeto');
    expect(decision.preserveState, isTrue);
  });

  test('required placement cannot be bypassed with back', () {
    final decision = policy.resolve(
      const SimBackContext(
        currentPath: '/cyber/placement',
        placementRequired: true,
      ),
    );

    expect(decision.action, SimBackAction.block);
    expect(decision.destinationPath, isNull);
    expect(decision.preserveState, isTrue);
  });

  test('optional placement returns to preparation safely', () {
    final decision = policy.resolve(
      const SimBackContext(currentPath: '/cyber/placement'),
    );

    expect(decision.action, SimBackAction.navigate);
    expect(decision.destinationPath, '/cyber/curriculo');
    expect(decision.preserveState, isTrue);
  });

  test('open overlay is closed before route changes', () {
    for (final overlay in SimBackOverlay.values.where(
      (value) => value != SimBackOverlay.none,
    )) {
      final decision = policy.resolve(
        SimBackContext(
          currentPath: '/cyber/aula',
          openOverlay: overlay,
          hasActiveLesson: true,
        ),
      );

      expect(decision.action, SimBackAction.closeOverlay, reason: overlay.name);
      expect(decision.destinationPath, isNull, reason: overlay.name);
      expect(decision.preserveState, isTrue, reason: overlay.name);
    }
  });

  test('portal root allows system exit', () {
    final decision = policy.resolve(const SimBackContext(currentPath: '/'));

    expect(decision.action, SimBackAction.allowSystemExit);
    expect(decision.handlesBack, isFalse);
    expect(decision.preserveState, isTrue);
  });

  test('login back returns to portal instead of exiting', () {
    final decision = policy.resolve(
      const SimBackContext(currentPath: '/login'),
    );

    expect(decision.action, SimBackAction.navigate);
    expect(decision.destinationPath, '/');
    expect(decision.preserveState, isTrue);
  });

  test('credits respects safe returnTo and rejects unsafe returnTo', () {
    final safeDecision = policy.resolve(
      const SimBackContext(
        currentPath: '/creditos',
        returnTo: '/cyber/aula',
        hasActiveLesson: true,
      ),
    );
    final unsafeDecision = policy.resolve(
      const SimBackContext(
        currentPath: '/creditos',
        returnTo: 'https://evil.example',
      ),
    );

    expect(safeDecision.action, SimBackAction.navigate);
    expect(safeDecision.destinationPath, '/cyber/aula');
    expect(safeDecision.preserveState, isTrue);
    expect(unsafeDecision.action, SimBackAction.navigate);
    expect(unsafeDecision.destinationPath, '/');
  });

  test('checkout return respects safe returnTo or falls back to credits', () {
    final safeDecision = policy.resolve(
      const SimBackContext(
        currentPath: '/checkout/return?session_id=cs_test',
        returnTo: '/cyber/aula',
      ),
    );
    final fallbackDecision = policy.resolve(
      const SimBackContext(currentPath: '/checkout/return?session_id=cs_test'),
    );

    expect(safeDecision.destinationPath, '/cyber/aula');
    expect(fallbackDecision.destinationPath, '/creditos');
  });

  test('unknown route falls back to portal safely', () {
    final decision = policy.resolve(
      const SimBackContext(currentPath: '/unknown-route'),
    );

    expect(decision.action, SimBackAction.navigate);
    expect(decision.destinationPath, '/');
    expect(decision.preserveState, isTrue);
  });

  test('android back and visual back use equivalent policy', () {
    final contexts = [
      const SimBackContext(currentPath: '/', source: SimBackSource.androidBack),
      const SimBackContext(currentPath: '/login'),
      const SimBackContext(currentPath: '/cyber/aula', hasActiveLesson: true),
      const SimBackContext(
        currentPath: '/cyber/aula',
        openOverlay: SimBackOverlay.sheet,
        hasActiveLesson: true,
      ),
      const SimBackContext(
        currentPath: '/cyber/placement',
        placementRequired: true,
      ),
      const SimBackContext(currentPath: '/creditos', returnTo: '/cyber/aula'),
    ];

    for (final context in contexts) {
      expect(
        policy.equivalentForAndroidAndVisualBack(context),
        isTrue,
        reason: context.currentPath,
      );
    }
  });

  test('back policy does not mutate route contract', () {
    final before = simRouteContract.map((route) => route.path).toList();

    policy.resolve(
      const SimBackContext(
        currentPath: '/cyber/aula',
        openOverlay: SimBackOverlay.drawer,
        hasActiveLesson: true,
      ),
    );
    policy.resolve(const SimBackContext(currentPath: '/unknown'));

    expect(simRouteContract.map((route) => route.path), before);
  });

  test('critical state requires confirmation rather than accidental exit', () {
    final decision = policy.resolve(
      const SimBackContext(
        currentPath: '/cyber/objeto',
        hasUnsavedCriticalState: true,
      ),
    );

    expect(decision.action, SimBackAction.requireConfirmation);
    expect(decision.preserveState, isTrue);
  });
}
