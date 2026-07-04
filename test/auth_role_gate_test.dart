import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/session/auth_session.dart';
import 'package:sim_mobile/session/navigation_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('AuthSession extracts parent roles from Supabase metadata', () {
    final auth = AuthSession(navigation: NavigationState());
    final user = User(
      id: 'u1',
      appMetadata: const {
        'roles': ['student', 'parent'],
      },
      userMetadata: const {'full_name': 'Responsavel'},
      aud: 'authenticated',
      createdAt: '2026-07-04T00:00:00Z',
    );

    auth.applySupabaseSession(
      Session(accessToken: 'token', tokenType: 'bearer', user: user),
    );

    expect(auth.authed, isTrue);
    expect(auth.hasAnyRole(const ['parent']), isTrue);
    expect(auth.hasAnyRole(const ['admin']), isFalse);
  });
}
