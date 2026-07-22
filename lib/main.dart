import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/utils/sim_constants.dart';
import 'features/auth/login_screen.dart';
import 'features/billing/billing_and_simple_pages.dart';
import 'features/classroom/aux_room_screens.dart';
import 'features/classroom/chat_aula_screen.dart';
import 'features/onboarding/onboarding_screens.dart';
import 'features/onboarding/preparation_and_placement.dart';
import 'features/portal/portal_flow.dart';
import 'features/session/lab_session.dart';
import 'sim/cloud/sim_server_cloud_functions.dart';
import 'sim/cloud/cloud_queue.dart';
import 'sim/cloud/drift_cloud_queue_storage.dart';
import 'sim/cloud/shared_prefs_cloud_queue_storage.dart';
import 'sim/cloud/supabase_flutter_session_provider.dart';
import 'sim/cloud/supabase_student_state_cloud_storage.dart';
import 'sim/config/sim_environment.dart';
import 'sim/external_ai/sim_ai_server_config.dart';
import 'sim/localization/sim_locale_contract.dart';
import 'sim/organism/sim_organism.dart';
import 'sim/state/drift_student_state_storage.dart';
import 'sim/state/shared_prefs_state_storage.dart';
import 'sim/state/student_state_store.dart';
import 'sim/ui/sim_design_system.dart';
import 'sim/ui/sim_i18n.dart';
import 'sim/ui/sim_theme.dart';

export 'features/session/lab_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'sim runtime',
        context: ErrorDescription('unhandled platform error'),
      ),
    );
    return true;
  };
  ErrorWidget.builder = (details) =>
      SimRuntimeFailureView(message: details.exceptionAsString());
  try {
    SimEnvironment.assertProductionSafe();
    await Supabase.initialize(
      url: simSupabaseUrl,
      publishableKey: simSupabaseAnonKey,
    );
    final prefs = await SharedPreferences.getInstance();
    final stateStorage = SharedPrefsStudentStateLocalStorage(prefs);
    const sessionProvider = SupabaseFlutterSessionProvider();
    final cloudStorage = SupabaseStudentStateCloudStorage(
      cloudFunctions: SimServerCloudFunctions(
        config: SimAiServerConfig(baseUrl: simApiBaseUrl),
      ),
      sessionProvider: sessionProvider,
    );
    final driftStateStorage = await DriftStudentStateLocalStorage.open(
      'sim_student_state',
      legacy: stateStorage,
    );
    final cloudQueueStorage = await DriftCloudQueueStorage.open(
      'sim_student_state',
      legacy: SharedPrefsCloudQueueStorage(prefs),
    );
    final canonicalStore = StudentStateStore(
      local: driftStateStorage,
      cloud: cloudStorage,
    );
    runApp(
      SimApp(
        canonicalStore: canonicalStore,
        cloudQueueStorage: cloudQueueStorage,
        prefs: prefs,
      ),
    );
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'sim boot',
        context: ErrorDescription('initializing SIM Mobile'),
      ),
    );
    runApp(SimBootFailureApp(error: error));
  }
}

class SimBootFailureApp extends StatelessWidget {
  const SimBootFailureApp({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SIM',
      home: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('boot_failure_title'),
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t('boot_failure_body'),
                      style: TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      error.toString(),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SimRuntimeFailureView extends StatelessWidget {
  const SimRuntimeFailureView({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9FAFB),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('runtime_failure_title'),
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t('runtime_failure_body'),
                  style: TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SimApp extends StatefulWidget {
  const SimApp({
    super.key,
    this.canonicalStore,
    this.initialSession,
    this.cloudQueueStorage,
    this.prefs,
  });

  final StudentStateStore? canonicalStore;
  final LabSession? initialSession;
  final CloudQueueStorage? cloudQueueStorage;
  final SharedPreferences? prefs;

  @override
  State<SimApp> createState() => _SimAppState();
}

typedef SimMobileApp = SimApp;

class _SimAppState extends State<SimApp> {
  static const _darkModePrefsKey = 'sim.ui.dark_mode';

  late final LabSession session =
      widget.initialSession ??
      LabSession(
        canonicalStore: widget.canonicalStore,
        cloudQueueStorage: widget.cloudQueueStorage,
        prefs: widget.prefs,
      );
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _darkMode = widget.prefs?.getBool(_darkModePrefsKey) ?? false;
    session.addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        session.bindRealAuth();
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'sim boot',
            context: ErrorDescription('binding real auth session'),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    session.removeListener(_onSessionChanged);
    session.dispose();
    super.dispose();
  }

  void _onSessionChanged() => setState(() {});

  Future<void> _toggleDarkMode() async {
    final next = !_darkMode;
    setState(() => _darkMode = next);
    final prefs = widget.prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(_darkModePrefsKey, next);
  }

  @override
  Widget build(BuildContext context) {
    final interfaceLocale = session.resolveInterfaceLocale(
      PlatformDispatcher.instance.locale,
    );
    setSimActiveLanguage(simUiCodeForLocaleTag(interfaceLocale));
    Widget screen;
    final requestedRoute = Uri.tryParse(session.route)?.path ?? session.route;
    final hasActiveLesson = (session.lessonLocalId ?? '').trim().isNotEmpty;
    final hasResolvedLanguage =
        (session.selectedLanguageCode ?? session.stableLang ?? '')
            .trim()
            .isNotEmpty ||
        hasActiveLesson;
    final routeDecision = const SimOrganismRouter().resolve(
      path: requestedRoute,
      authed: session.authed,
      hasLanguage: hasResolvedLanguage,
      hasObjective: hasActiveLesson,
    );
    final routePath = routeDecision.destination;
    switch (routePath) {
      case '/login':
        screen = LoginScreen(session: session);
      case '/cyber/idioma':
        screen = ConversationalEntryScreen(session: session);
      case '/cyber/objeto':
        screen = ConversationalEntryScreen(session: session);
      case '/cyber/curriculo':
        screen = PhaseBoundaryScreen(session: session);
      case '/cyber/placement':
        screen = PlacementLabScreen(session: session);
      case '/cyber/warmup':
        screen = WarmupBridgeScreen(session: session);
      case '/cyber/amparo':
        screen = _guardActiveLesson(
          session,
          child: AmparoRoomScreen(session: session),
        );
      case '/cyber/aula':
        screen = _guardActiveLesson(
          session,
          child: ChatAulaScreen(session: session),
        );
      case '/creditos':
        screen = _guardAuthenticated(
          session,
          target: '/creditos',
          child: CreditsLabScreen(session: session),
        );
      case '/checkout/return':
        screen = _guardAuthenticated(
          session,
          target: '/checkout/return',
          child: CheckoutReturnScreen(session: session),
        );
      case '/pai':
        screen = _guardParentPanel(
          session,
          child: FatherLabScreen(session: session),
        );
      case '/privacidade':
        screen = LegalLabScreen(session: session, title: t('privacy'));
      case '/termos':
        screen = LegalLabScreen(session: session, title: t('terms'));
      case '/conta/deletar':
        screen = _guardAuthenticated(
          session,
          target: '/conta/deletar',
          child: DeleteAccountLabScreen(session: session),
        );
      default:
        screen = PortalScreen(session: session);
    }

    final lightTheme = _buildSimTheme(SimPalette.light, Brightness.light);
    final darkTheme = _buildSimTheme(SimPalette.darkMode, Brightness.dark);
    return SimThemeScope(
      darkMode: _darkMode,
      onToggleDarkMode: () => unawaited(_toggleDarkMode()),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SIM',
        locale: simActiveLocale,
        supportedLocales: const [
          Locale('pt', 'BR'),
          Locale('en'),
          Locale('es'),
          Locale('fr'),
          Locale('de'),
          Locale('it'),
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
        theme: lightTheme,
        darkTheme: darkTheme,
        home: SimFrame(child: screen),
      ),
    );
  }
}

Widget _guardActiveLesson(LabSession session, {required Widget child}) {
  final guarded = _guardAuthenticated(
    session,
    target: '/cyber/aula',
    child: child,
  );
  if (guarded != child) return guarded;
  final id = session.lessonLocalId;
  if (id == null || id.trim().isEmpty) {
    return ConversationalEntryScreen(session: session);
  }
  return child;
}

Widget _guardAuthenticated(
  LabSession session, {
  required String target,
  required Widget child,
}) {
  if (!session.authReady) {
    return _RouteGuardScreen(
      title: t('guard_checking_title'),
      body: t('guard_checking_body'),
    );
  }
  if (!session.authed) {
    return _RouteGuardScreen(
      title: t('guard_login_title'),
      body: t('guard_login_body'),
      primary: t('guard_login_primary'),
      onPrimary: () => session.goLogin(target: target),
      secondary: t('guard_back'),
      onSecondary: session.goPortal,
    );
  }
  return child;
}

Widget _guardParentPanel(LabSession session, {required Widget child}) {
  final guarded = _guardAuthenticated(session, target: '/pai', child: child);
  if (guarded != child) return guarded;
  final allowed = session.authSession.hasAnyRole(const [
    'parent',
    'guardian',
    'pai',
    'responsavel',
    'admin',
  ]);
  if (!allowed) {
    return _RouteGuardScreen(
      title: t('guard_restricted_title'),
      body: t('guard_restricted_body'),
      primary: t('guard_back'),
      onPrimary: session.goPortal,
    );
  }
  return child;
}

class _RouteGuardScreen extends StatelessWidget {
  const _RouteGuardScreen({
    required this.title,
    required this.body,
    this.primary,
    this.onPrimary,
    this.secondary,
    this.onSecondary,
  });

  final String title;
  final String body;
  final String? primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: const TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  if (primary != null && onPrimary != null) ...[
                    const SizedBox(height: 18),
                    FilledButton(onPressed: onPrimary, child: Text(primary!)),
                  ],
                  if (secondary != null && onSecondary != null) ...[
                    const SizedBox(height: 8),
                    TextButton(onPressed: onSecondary, child: Text(secondary!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

ThemeData _buildSimTheme(SimPalette palette, Brightness brightness) {
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: palette.primary,
    onPrimary: palette.onPrimary,
    secondary: palette.warning,
    onSecondary: brightness == Brightness.dark
        ? const Color(0xFF1F1603)
        : Colors.white,
    error: palette.danger,
    onError: palette.onPrimary,
    surface: palette.surface,
    onSurface: palette.text,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
  );
  final textTheme = GoogleFonts.interTextTheme(
    base.textTheme,
  ).apply(bodyColor: palette.text, displayColor: palette.text);
  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    cardColor: palette.surface,
    dividerColor: palette.border,
    focusColor: palette.focus.withValues(alpha: 0.18),
    highlightColor: palette.primary.withValues(alpha: 0.08),
    splashColor: palette.primary.withValues(alpha: 0.10),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.all(SimSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SimRadius.xl),
        side: BorderSide(color: palette.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SimRadius.xl),
      ),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: palette.text,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: palette.muted),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      modalBackgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SimRadius.xl)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceSoft,
      hintStyle: TextStyle(color: palette.muted),
      labelStyle: TextStyle(color: palette.muted),
      helperStyle: TextStyle(color: palette.muted),
      errorStyle: TextStyle(color: palette.danger, fontWeight: FontWeight.w600),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SimSpacing.md,
        vertical: SimSpacing.md,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SimRadius.lg),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SimRadius.lg),
        borderSide: BorderSide(color: palette.focus, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SimRadius.lg),
        borderSide: BorderSide(color: palette.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SimRadius.lg),
        borderSide: BorderSide(color: palette.danger, width: 1.6),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.primary,
        minimumSize: const Size(SimTouch.min, SimTouch.min),
        padding: const EdgeInsets.symmetric(
          horizontal: SimSpacing.sm,
          vertical: SimSpacing.xs,
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SimRadius.md),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        disabledBackgroundColor: palette.surfaceSoft,
        disabledForegroundColor: palette.muted,
        minimumSize: const Size(SimTouch.min, SimTouch.min),
        padding: const EdgeInsets.symmetric(
          horizontal: SimSpacing.md,
          vertical: SimSpacing.sm,
        ),
        textStyle: SimTypography.action,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SimRadius.lg),
        ),
        shadowColor: palette.shadow,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.text,
        backgroundColor: palette.surface,
        disabledForegroundColor: palette.muted,
        side: BorderSide(color: palette.border),
        minimumSize: const Size(SimTouch.min, SimTouch.min),
        padding: const EdgeInsets.symmetric(
          horizontal: SimSpacing.md,
          vertical: SimSpacing.sm,
        ),
        textStyle: SimTypography.action,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SimRadius.lg),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: palette.text,
        disabledForegroundColor: palette.disabled,
        minimumSize: const Size(SimTouch.icon, SimTouch.icon),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SimRadius.md),
        ),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.primary,
      linearTrackColor: palette.surfaceSoft,
      circularTrackColor: palette.surfaceSoft,
    ),
    dividerTheme: DividerThemeData(
      color: palette.border,
      thickness: 1,
      space: SimSpacing.lg,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: palette.muted,
      textColor: palette.text,
      tileColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SimRadius.lg),
      ),
    ),
  );
}
