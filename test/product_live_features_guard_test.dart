import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_widgets.dart';
import 'package:sim_mobile/features/onboarding/onboarding_screens.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_accessibility.dart';
import 'package:sim_mobile/sim/ui/sim_theme.dart';
import 'package:sim_mobile/sim/ui/widgets/doubt_progress_bar.dart';
import 'package:sim_mobile/sim/ui/widgets/fixed_bubble.dart';
import 'package:sim_mobile/sim/ui/widgets/lesson_audio_controls.dart';
import 'package:sim_mobile/sim/ui/widgets/lesson_avatar.dart';
import 'package:sim_mobile/sim/ui/widgets/sim_typewriter.dart';

void main() {
  test('night view is a live persisted product feature', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final portal = File(
      'lib/features/portal/portal_flow.dart',
    ).readAsStringSync();
    final theme = File('lib/sim/ui/sim_theme.dart').readAsStringSync();

    expect(theme, contains('SimPalette.darkMode'));
    expect(
      mainSource,
      contains("static const _darkModePrefsKey = 'sim.ui.dark_mode'"),
    );
    expect(mainSource, contains('ThemeMode.dark'));
    expect(mainSource, contains('prefs.setBool(_darkModePrefsKey, next)'));
    expect(portal, contains('Icons.dark_mode_outlined'));
    expect(portal, contains('theme.onToggleDarkMode'));
    expect(
      SimContrast.meets(
        SimPalette.darkMode.text,
        SimPalette.darkMode.background,
      ),
      isTrue,
    );
  });

  testWidgets('language screen keeps presets and other language path alive', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = LabSession(prefs: prefs)..route = '/cyber/idioma';
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(home: ConversationalEntryScreen(session: session)),
    );
    await tester.pump();

    expect(find.byKey(const Key('language-screen')), findsOneWidget);
    expect(find.textContaining('Portugu'), findsOneWidget);
    expect(find.byKey(const Key('language-other-input')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('language-other-input')),
      'Italian',
    );
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pump();

    expect(session.selectedLanguageCode, 'other');
    expect(session.stableLang, 'Italian');
    expect(session.route, '/cyber/objeto');
  });

  test('language contract reaches T00 T02 audio and visual payloads', () {
    final aiClient = File(
      'lib/sim/external_ai/sim_server_ai_clients.dart',
    ).readAsStringSync();
    final t00Adapter = File(
      'lib/sim/experience/student_experience_t00_adapter.dart',
    ).readAsStringSync();
    final t02Adapter = File(
      'lib/sim/experience/student_experience_t02_adapter.dart',
    ).readAsStringSync();
    final audio = File(
      'lib/sim/media/student_lesson_media_service.dart',
    ).readAsStringSync();
    final visual = File(
      'lib/sim/media/lesson_visual_pipeline.dart',
    ).readAsStringSync();

    for (final field in const [
      'interfaceLocale',
      'learningLocale',
      'explanationLanguage',
      'targetLanguage',
    ]) {
      expect(aiClient, contains(field), reason: field);
      expect(t00Adapter, contains(field), reason: field);
      expect(t02Adapter, contains(field), reason: field);
    }
    expect(audio, contains("payload['language'] = language"));
    expect(visual, contains("'idioma': idioma"));
  });

  test('screen inventory keeps the live product surfaces present', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final classroom = File(
      'lib/features/classroom/chat_aula_screen.dart',
    ).readAsStringSync();
    final aux = File(
      'lib/features/classroom/aux_room_screens.dart',
    ).readAsStringSync();
    final onboarding = File(
      'lib/features/onboarding/preparation_and_placement.dart',
    ).readAsStringSync();
    final portal = File(
      'lib/features/portal/portal_flow.dart',
    ).readAsStringSync();
    final login = File(
      'lib/features/auth/login_screen.dart',
    ).readAsStringSync();
    final billing = File(
      'lib/features/billing/billing_and_simple_pages.dart',
    ).readAsStringSync();
    final drawer = File(
      'lib/shared/widgets/shared_widgets.dart',
    ).readAsStringSync();

    for (final route in const [
      '/login',
      '/creditos',
      '/cyber/idioma',
      '/cyber/objeto',
      '/cyber/curriculo',
      '/cyber/placement',
      '/cyber/aula',
    ]) {
      expect(mainSource, contains(route), reason: route);
    }
    expect(portal, contains('class PortalScreen'));
    expect(login, contains('class LoginScreen'));
    expect(billing, contains('class CreditsLabScreen'));
    expect(onboarding, contains('class PlacementLabScreen'));
    expect(classroom, contains('class ChatAulaScreen'));
    expect(classroom, contains('DoubtInputSheet'));
    expect(aux, contains('class ReviewRoomScreen'));
    expect(aux, contains('class RecoveryRoomScreen'));
    expect(drawer, contains('void showAulaMenu'));
  });

  testWidgets(
    'feedback doubt progress typewriter image and audio widgets stay alive',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Scaffold(
                body: ChatAulaTimeline(
                  messages: const [
                    ChatLessonMessage(
                      id: 'exp',
                      role: ChatLessonMessageRole.sim,
                      kind: ChatLessonMessageKind.explanation,
                      text: 'Explicacao viva',
                    ),
                    ChatLessonMessage(
                      id: 'doubt-processing',
                      role: ChatLessonMessageRole.system,
                      kind: ChatLessonMessageKind.loading,
                      text: 'Respondendo sua duvida',
                      progress: 45,
                      deliveryStatus: ChatLessonDeliveryStatus.processing,
                    ),
                    ChatLessonMessage(
                      id: 'feedback',
                      role: ChatLessonMessageRole.sim,
                      kind: ChatLessonMessageKind.feedback,
                      text: 'Feedback local vivo',
                    ),
                  ],
                  onChooseAnswer: (AnswerLetter _) {},
                  onSignal: (_) {},
                  onRetry: () {},
                  onNext: () {},
                  onOpenDoubt: () {},
                ),
              ),
              FixedBubble(audioEnabled: true, speaking: true, onTap: () {}),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SimTypewriter), findsOneWidget);
      expect(find.byType(DoubtProgressBar), findsOneWidget);
      expect(find.text('Feedback local vivo'), findsOneWidget);
      expect(find.byType(FixedBubble), findsOneWidget);
      expect(find.byType(LessonAvatar), findsNothing);
      expect(find.byType(LessonAudioControlButton), findsNothing);
    },
  );

  test(
    'accessibility and reusable UI files cannot be removed without proof',
    () {
      final requiredFiles = [
        'lib/sim/ui/sim_accessibility.dart',
        'lib/sim/ui/sim_components.dart',
        'lib/sim/ui/widgets/fixed_bubble.dart',
        'lib/sim/ui/widgets/sim_typewriter.dart',
        'lib/sim/ui/widgets/lesson_audio_controls.dart',
        'lib/sim/ui/widgets/lesson_avatar.dart',
        'lib/sim/auxiliary/doubt_progress_bar.dart',
        'lib/sim/ui/widgets/doubt_progress_bar.dart',
        'docs/fase8_recuperacao_produto_vivo.md',
      ];
      for (final path in requiredFiles) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }

      final tokens = SimAccessibility.criticalStateTokens(SimPalette.light);
      expect(tokens, hasLength(SimVisualState.values.length));
      expect(tokens.every((token) => token.includesNonColorCue), isTrue);
    },
  );

  test('Phase 6 visual and audio remain non blocking and clean', () {
    final mediaRuntime = Directory('lib/sim/media')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    final classroom = Directory('lib/features/classroom')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    for (final required in const [
      'class LessonVisualTrigger',
      'class S12VisualPipeline',
      'class VisualRouterN2',
      'class VisualRouterN3Client',
      'math_templates',
      '/api/visual-route',
      'SvgPicture.string',
      'Image.memory',
      'Image.network',
      'class LessonAudioController',
    ]) {
      expect('$mediaRuntime\n$classroom', contains(required), reason: required);
    }
    for (final forbidden in const [
      'WebView',
      '/api/warmup',
      '/api/doubt',
      '/api/review',
      '/api/recovery',
      '/api/advance-gate',
      'paidImage',
      'imagemPaga',
    ]) {
      expect(
        '$mediaRuntime\n$classroom',
        isNot(contains(forbidden)),
        reason: forbidden,
      );
    }
  });
}
