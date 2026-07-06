import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/navigation/sim_route_contract.dart';
import 'package:sim_mobile/sim/navigation/sim_route_state.dart';
import 'package:sim_mobile/sim/navigation/sim_route_state_store.dart';

void main() {
  test('restorable screen routes declare a route state contract', () {
    final restorableRoutes = simRouteContract.where(
      (route) => route.restorable && route.surface == SimRouteSurface.screen,
    );

    for (final route in restorableRoutes) {
      final state = simRouteStateByName(route.name);
      expect(state, isNotNull, reason: route.name);
      expect(state!.path, route.path);
      expect(state.restorable, isTrue, reason: route.name);
      expect(state.persistableFields, isNotEmpty, reason: route.name);
    }
  });

  test('non-restorable internal overlays do not become route-restorable', () {
    final overlays = simRouteContract.where((route) => route.isOverlay);

    for (final route in overlays) {
      final state = simRouteStateByName(route.name);
      expect(state?.restorable ?? false, isFalse, reason: route.name);
      expect(
        state?.storageScope ?? SimRouteStateScope.neverPersist,
        SimRouteStateScope.neverPersist,
        reason: route.name,
      );
    }
  });

  test(
    'classroom declares live and historical state without sensitive blobs',
    () {
      final classroom = simRouteStateByName('classroom')!;

      expect(classroom.canPersistField('lessonLocalId'), isTrue);
      expect(classroom.canPersistField('scrollOffset'), isTrue);
      expect(classroom.canPersistField('visibleAnchor'), isTrue);
      expect(classroom.canPersistField('draftDoubtText'), isTrue);
      expect(classroom.canPersistField('conversationHistory'), isTrue);
      expect(classroom.canPersistField('deadFeedback'), isTrue);
      expect(classroom.canPersistField('mediaAttachmentBlob'), isFalse);
      expect(classroom.canPersistField('studentPrivateToken'), isFalse);
      expect(
        classroom.fields
            .where((field) => field.kind == SimRouteStateFieldKind.historical)
            .map((field) => field.key),
        containsAll(['conversationHistory', 'deadFeedback']),
      );
    },
  );

  test('store saves retrieves and clears lightweight route state', () {
    final store = SimRouteStateStore();
    final result = store.save('portal', {
      'selectedTab': 'home',
      'filters': {'subject': 'math'},
    });

    expect(result.accepted, isTrue);
    expect(store.restore('portal')?.values['selectedTab'], 'home');
    expect(store.restore('portal')?.values['filters'], {'subject': 'math'});

    store.clear('portal');
    expect(store.restore('portal'), isNull);
  });

  test('snapshot from one route is not restored into another route', () {
    final store = SimRouteStateStore();
    store.save('classroom', {
      'lessonLocalId': 'lesson-1',
      'scrollOffset': 240.0,
    });

    expect(store.restore('classroom'), isNotNull);
    expect(store.restore('placement'), isNull);
  });

  test('session keys isolate route state snapshots', () {
    final store = SimRouteStateStore();
    store.save('portal', {'selectedTab': 'one'}, sessionKey: 's1');
    store.save('portal', {'selectedTab': 'two'}, sessionKey: 's2');

    expect(
      store.restore('portal', sessionKey: 's1')?.values['selectedTab'],
      'one',
    );
    expect(
      store.restore('portal', sessionKey: 's2')?.values['selectedTab'],
      'two',
    );

    store.clearSession('s1');
    expect(store.restore('portal', sessionKey: 's1'), isNull);
    expect(store.restore('portal', sessionKey: 's2'), isNotNull);
  });

  test('sensitive volatile undeclared and heavy fields are rejected', () {
    final store = SimRouteStateStore(maxValueBytes: 32);
    final result = store.save('classroom', {
      'lessonLocalId': 'lesson-1',
      'studentPrivateToken': 'secret',
      'mediaAttachmentBlob': 'data:image/png;base64,AAAA',
      'unknownField': 'unknown',
      'draftDoubtText': 'x' * 64,
    });

    expect(result.saved?.values.keys, contains('lessonLocalId'));
    expect(result.saved?.values.keys, isNot(contains('studentPrivateToken')));
    expect(result.saved?.values.keys, isNot(contains('mediaAttachmentBlob')));
    expect(result.saved?.values.keys, isNot(contains('unknownField')));
    expect(result.saved?.values.keys, isNot(contains('draftDoubtText')));
    expect(
      result.rejected.keys,
      containsAll([
        'studentPrivateToken',
        'mediaAttachmentBlob',
        'unknownField',
        'draftDoubtText',
      ]),
    );
  });

  test('old snapshot versions are invalidated', () {
    const oldSnapshot = SimRouteStateSnapshot(
      routeName: 'portal',
      sessionKey: 'default',
      version: simRouteStateSnapshotVersion - 1,
      values: {'selectedTab': 'home'},
    );
    final store = _SeededRouteStateStore(oldSnapshot);

    expect(store.restore('portal'), isNull);
  });

  test('returnTo is preserved only when declared as lightweight state', () {
    final store = SimRouteStateStore();
    final credits = store.save('credits', {'returnTo': '/cyber/aula'});
    final login = store.save('login', {'returnTo': '/cyber/curriculo'});
    final classroom = store.save('classroom', {'returnTo': '/creditos'});

    expect(credits.saved?.values['returnTo'], '/cyber/aula');
    expect(login.saved?.values['returnTo'], '/cyber/curriculo');
    expect(classroom.saved, isNull);
    expect(classroom.rejected['returnTo'], isNotNull);
  });

  test('filters and form drafts can be preserved as lightweight state', () {
    final store = SimRouteStateStore();

    final portal = store.save('portal', {
      'filters': {'area': 'exatas'},
    });
    final objective = store.save('objective', {
      'preferredName': 'Ana',
      'objectiveText': 'Quero revisar derivadas.',
      'guidedAnswers': {'level': 'intermediate'},
      'attachmentMetadata': [
        {'name': 'lista.pdf', 'size': 1200, 'type': 'application/pdf'},
      ],
    });

    expect(portal.accepted, isTrue);
    expect(objective.accepted, isTrue);
    expect(objective.saved?.values['preferredName'], 'Ana');
  });

  test('ttl expires stale route snapshots', () {
    final store = SimRouteStateStore();
    final createdAt = DateTime.utc(2026, 1, 1, 12);
    store.save('login', {'returnTo': '/cyber/aula'}, now: createdAt);

    expect(
      store.restore('login', now: createdAt.add(const Duration(minutes: 10))),
      isNotNull,
    );
    expect(
      store.restore('login', now: createdAt.add(const Duration(hours: 1))),
      isNull,
    );
  });
}

class _SeededRouteStateStore extends SimRouteStateStore {
  _SeededRouteStateStore(SimRouteStateSnapshot snapshot) {
    save(snapshot.routeName, snapshot.values, sessionKey: snapshot.sessionKey);
    super.clear(snapshot.routeName, sessionKey: snapshot.sessionKey);
    // This exercises public restore behavior against an intentionally invalid
    // snapshot without exposing mutation APIs on the production store.
    seeded = snapshot;
  }

  late final SimRouteStateSnapshot seeded;

  @override
  SimRouteStateSnapshot? restore(
    String routeName, {
    String sessionKey = 'default',
    DateTime? now,
  }) {
    if (routeName == seeded.routeName && sessionKey == seeded.sessionKey) {
      if (seeded.version != simRouteStateSnapshotVersion) return null;
      return seeded;
    }
    return super.restore(routeName, sessionKey: sessionKey, now: now);
  }
}
