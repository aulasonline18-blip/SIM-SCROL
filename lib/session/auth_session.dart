import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../sim/ui/sim_i18n.dart';
import 'navigation_state.dart';

class AuthSession extends ChangeNotifier {
  AuthSession({required this.navigation, this.onAuthenticated});

  final NavigationState navigation;
  final VoidCallback? onAuthenticated;

  bool authed = false;
  bool authReady = false;
  int credits = 0;
  bool isUnlimited = false;
  String? userId;
  String? userEmail;
  String? userName;
  Set<String> roles = const {};
  String? authError;
  StreamSubscription<AuthState>? _authSub;

  void bindRealAuth() {
    final client = _supabaseClientOrNull();
    if (client == null) {
      authReady = true;
      authError = t('auth_unavailable');
      notifyListeners();
      return;
    }
    _authSub ??= client.auth.onAuthStateChange.listen((data) {
      applySupabaseSession(data.session);
    });
    final current = client.auth.currentSession;
    if (current?.isExpired ?? false) {
      unawaited(_refreshExpiredSession(client));
      return;
    }
    applySupabaseSession(current);
  }

  Future<void> _refreshExpiredSession(SupabaseClient client) async {
    try {
      final refreshed = await client.auth.refreshSession();
      applySupabaseSession(refreshed.session ?? client.auth.currentSession);
    } catch (_) {
      applySupabaseSession(null);
    }
  }

  SupabaseClient? _supabaseClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void applySupabaseSession(Session? session) {
    final user = session?.user;
    authReady = true;
    authError = null;
    authed = user != null;
    userId = user?.id;
    userEmail = user?.email;
    userName =
        user?.userMetadata?['full_name']?.toString() ??
        user?.userMetadata?['name']?.toString();
    roles = _extractRoles(user);
    if (authed) {
      if (navigation.route == '/login') {
        navigation.route = safeNavigationReturnTo(navigation.returnTo);
      }
      onAuthenticated?.call();
    } else {
      credits = 0;
      isUnlimited = false;
      roles = const {};
    }
    notifyListeners();
    navigation.notifyListeners();
  }

  bool hasAnyRole(Iterable<String> allowedRoles) {
    final normalized = allowedRoles.map((role) => role.toLowerCase()).toSet();
    return roles.any(normalized.contains);
  }

  Set<String> _extractRoles(User? user) {
    final collected = <String>{};
    void addRole(Object? value) {
      if (value == null) return;
      if (value is Iterable) {
        for (final item in value) {
          addRole(item);
        }
        return;
      }
      final text = value.toString().trim().toLowerCase();
      if (text.isNotEmpty) collected.add(text);
    }

    final appMetadata = user?.appMetadata ?? const <String, dynamic>{};
    final userMetadata = user?.userMetadata ?? const <String, dynamic>{};
    for (final metadata in [appMetadata, userMetadata]) {
      addRole(metadata['role']);
      addRole(metadata['roles']);
      addRole(metadata['app_role']);
      addRole(metadata['user_role']);
    }
    return collected;
  }

  Future<void> signInWithGoogle() async {
    authError = null;
    notifyListeners();
    final client = _supabaseClientOrNull();
    if (client == null) {
      authError = t('supabase_not_initialized');
      notifyListeners();
      return;
    }
    try {
      final launched = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'sim-mobile://login-callback',
        queryParams: const {'prompt': 'select_account'},
      );
      if (!launched) {
        authError = t('google_login_open_failed');
      }
    } catch (_) {
      authError = t('google_login_open_failed');
    }
    notifyListeners();
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    authError = null;
    notifyListeners();
    final client = _supabaseClientOrNull();
    if (client == null) {
      authError = t('auth_unavailable');
      notifyListeners();
      return;
    }
    try {
      await client.auth.signInWithPassword(email: email, password: password);
    } on AuthException {
      authError = t('auth_login_failed');
    } catch (_) {
      authError = t('auth_login_failed');
    }
    notifyListeners();
  }

  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    authError = null;
    notifyListeners();
    final client = _supabaseClientOrNull();
    if (client == null) {
      authError = t('auth_unavailable');
      notifyListeners();
      return;
    }
    try {
      await client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'sim-mobile://login-callback',
        data: {
          'full_name': name.trim().isEmpty
              ? email.split('@').first
              : name.trim(),
        },
      );
    } on AuthException {
      authError = t('auth_signup_failed');
    } catch (_) {
      authError = t('auth_signup_failed');
    }
    notifyListeners();
  }

  Future<void> signOutReal() async {
    final client = _supabaseClientOrNull();
    await client?.auth.signOut();
    applySupabaseSession(null);
    navigation.goPortal();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
