import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/utils/sim_constants.dart';
import 'features/auth/login_screen.dart';
import 'features/billing/billing_and_simple_pages.dart';
import 'features/classroom/aula_screen.dart';
import 'features/onboarding/onboarding_screens.dart';
import 'features/onboarding/preparation_and_placement.dart';
import 'features/portal/portal_flow.dart';
import 'features/session/lab_session.dart';
import 'sim/cloud/sim_server_cloud_functions.dart';
import 'sim/cloud/supabase_flutter_session_provider.dart';
import 'sim/cloud/supabase_student_state_cloud_storage.dart';
import 'sim/config/sim_environment.dart';
import 'sim/external_ai/sim_ai_server_config.dart';
import 'sim/state/shared_prefs_state_storage.dart';
import 'sim/state/student_state_store.dart';
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
  ErrorWidget.builder = (details) => SimRuntimeFailureView(
    message: details.exceptionAsString(),
  );
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
    final canonicalStore = StudentStateStore(
      local: stateStorage,
      cloud: cloudStorage,
    );
    runApp(SimApp(canonicalStore: canonicalStore, prefs: prefs));
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
                    const Text(
                      'SIM nao iniciou',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'A configuracao de producao precisa ser corrigida para abrir o app.',
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
                const Text(
                  'SIM encontrou um erro',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'O app abriu, mas uma parte da tela falhou. Tente novamente.',
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
    this.prefs,
  });

  final StudentStateStore? canonicalStore;
  final LabSession? initialSession;
  final SharedPreferences? prefs;

  @override
  State<SimApp> createState() => _SimAppState();
}

typedef SimMobileApp = SimApp;

class _SimAppState extends State<SimApp> {
  static const _darkModePrefsKey = 'sim.ui.dark_mode';

  late final LabSession session =
      widget.initialSession ??
      LabSession(canonicalStore: widget.canonicalStore, prefs: widget.prefs);
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
    Widget screen;
    final routePath = Uri.tryParse(session.route)?.path ?? session.route;
    switch (routePath) {
      case '/login':
        screen = LoginScreen(session: session);
      case '/cyber/idioma':
        screen = IdiomaScreen(session: session);
      case '/cyber/objeto':
        screen = ObjetoScreen(session: session);
      case '/cyber/curriculo':
        screen = PhaseBoundaryScreen(session: session);
      case '/cyber/placement':
        screen = PlacementLabScreen(session: session);
      case '/cyber/aula':
        screen = AulaLabScreen(session: session);
      case '/creditos':
        screen = CreditsLabScreen(session: session);
      case '/checkout/return':
        screen = CheckoutReturnScreen(session: session);
      case '/pai':
        screen = FatherLabScreen(session: session);
      case '/privacidade':
        screen = LegalLabScreen(session: session, title: 'Privacidade');
      case '/termos':
        screen = LegalLabScreen(session: session, title: 'Termos');
      case '/conta/deletar':
        screen = DeleteAccountLabScreen(session: session);
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
        themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
        theme: lightTheme,
        darkTheme: darkTheme,
        home: SimFrame(child: screen),
      ),
    );
  }
}

ThemeData _buildSimTheme(SimPalette palette, Brightness brightness) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      surface: palette.surface,
    ),
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
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
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
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceSoft,
      hintStyle: TextStyle(color: palette.muted),
      labelStyle: TextStyle(color: palette.muted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.primary),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: palette.text),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        disabledBackgroundColor: palette.surfaceSoft,
        disabledForegroundColor: palette.muted,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.text,
        side: BorderSide(color: palette.border),
      ),
    ),
  );
}
