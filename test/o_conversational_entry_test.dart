import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/onboarding/onboarding_screens.dart';
import 'package:sim_mobile/main.dart';
import 'package:sim_mobile/sim/experience/student_experience_types.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';
import 'package:sim_mobile/sim/ui/sim_theme.dart';

Future<void> _pumpEntry(
  WidgetTester tester,
  LabSession session, {
  Size size = const Size(430, 1100),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(SimMobileApp(initialSession: session));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final fontBytes = File(
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ).readAsBytesSync();
    final loader = FontLoader('Inter')
      ..addFont(
        Future.value(ByteData.view(Uint8List.fromList(fontBytes).buffer)),
      );
    await loader.load();
    final monoLoader = FontLoader('JetBrains Mono')
      ..addFont(
        Future.value(ByteData.view(Uint8List.fromList(fontBytes).buffer)),
      );
    await monoLoader.load();
    final iconBytes = File(
      '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(ByteData.view(Uint8List.fromList(iconBytes).buffer)),
      );
    await iconLoader.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setSimActiveLanguage('pt-BR');
  });

  testWidgets('O.3 abre lista rolavel de idioma e atualiza locale', (
    tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/idioma';

    await _pumpEntry(tester, session);

    expect(find.byType(ConversationalEntryScreen), findsOneWidget);
    expect(find.textContaining('Português'), findsWidgets);

    await tester.tap(find.byKey(const Key('sim-entry-language-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sim-entry-language-list')), findsOneWidget);
    expect(find.text('Seguir dispositivo'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('sim-entry-language-list')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(find.text('Italiano'), findsOneWidget);

    await tester.tap(find.text('Italiano'));
    await tester.pumpAndSettle();

    expect(session.interfaceLocaleTag, 'it');
    expect(session.learningLocaleTag, 'it');
    expect(session.explanationLanguage, 'Italian');
    expect(find.textContaining('Italiano'), findsWidgets);
  });

  testWidgets('O.2/O.11 ficha pedagogica chega completa ao payload T00', (
    tester,
  ) async {
    Map<String, dynamic>? capturedOnboarding;
    final session =
        LabSession(
            experiencePreparerOverride: (args) async {
              capturedOnboarding = args.onboarding;
              args.onStage?.call(StudentExperienceRouteStage.ready);
              return const StudentExperienceResult(
                destination: '/cyber/aula',
                curriculum: StudentCurriculum(
                  topic: 'Frações',
                  totalItems: 1,
                  generatedAt: null,
                  provisional: false,
                  items: [CurriculumItem(marker: 'M1', text: 'Frações')],
                ),
                startMarker: 'M1',
                startItemIndex: 0,
              );
            },
          )
          ..authed = true
          ..authReady = true
          ..credits = 999999
          ..route = '/cyber/idioma';
    await session.setInterfaceLanguage(followDevice: false, localeTag: 'pt-BR');
    await session.setLearningLanguage(localeTag: 'pt-BR');

    await _pumpEntry(tester, session);

    await tester.enterText(
      find.byKey(const Key('sim-entry-name-input')),
      'Lucas',
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Criança'));
    await _tapVisible(tester, find.text('Quero que o SIM monte'));
    await _tapVisible(tester, find.text('Matemática'));
    await tester.enterText(
      find.byKey(const Key('sim-entry-topic-input')),
      'Frações equivalentes',
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Fundamental'));
    await _tapVisible(tester, find.text('Brasil'));
    await tester.enterText(
      find.byKey(const Key('sim-entry-objective-input')),
      'Quero passar na prova da escola esta semana.',
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Esta semana'));
    await _tapVisible(tester, find.text('Falta de base'));
    await _tapVisible(tester, find.text('Com imagem'));

    await _tapVisible(
      tester,
      find.byKey(const Key('sim-entry-prepare-button')),
    );
    await tester.pump(const Duration(milliseconds: 500));
    if (capturedOnboarding == null) {
      await session.launchExperience();
    }

    final ficha =
        capturedOnboarding?['pedagogical_entry_ficha'] as Map<String, dynamic>?;
    expect(ficha, isNotNull);
    expect(ficha?['preferred_name'], 'Lucas');
    expect(ficha?['age_range'], 'Criança');
    expect(ficha?['entry_path'], 'sim_monta');
    expect(ficha?['subject'], 'Matemática');
    expect(ficha?['topic'], 'Frações equivalentes');
    expect(ficha?['academic_level'], 'Fundamental');
    expect(ficha?['country_curriculum'], 'Brasil');
    expect(ficha?['objective'], contains('prova da escola'));
    expect(ficha?['deadline'], 'Esta semana');
    expect(ficha?['difficulties'], 'Falta de base');
    expect(ficha?['learning_preference'], 'Com imagem');
    expect(ficha?['interfaceLocale'], 'pt-BR');
    expect(ficha?['learningLocale'], 'pt-BR');
    expect(ficha?['explanationLanguage'], 'Portuguese');
    expect(capturedOnboarding?['pedagogical_entry_ficha'], ficha);
  });

  testWidgets('O.4-O.10 timeline preserva historico e bifurcacao forte', (
    tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/idioma';

    await _pumpEntry(tester, session);

    expect(
      find.text('SIM: Em que idioma você quer usar o SIM?'),
      findsOneWidget,
    );
    expect(find.text('SIM: Como posso chamar você?'), findsOneWidget);
    expect(find.text('SIM: Quem vai estudar?'), findsOneWidget);
    expect(find.text('Tenho material'), findsOneWidget);
    expect(find.text('Quero que o SIM monte'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('sim-entry-name-input')),
      'Lucas',
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Adolescente'));
    await _tapVisible(tester, find.text('Tenho material'));
    await _tapVisible(tester, find.text('Lista de exercícios'));

    expect(find.text('Lucas'), findsWidgets);
    expect(find.text('Adolescente'), findsWidgets);
    expect(find.text('Caminho A:'), findsOneWidget);
    expect(find.text('Foto do caderno'), findsOneWidget);
    expect(find.text('Livro/PDF'), findsOneWidget);
    expect(find.text('Dúvida específica'), findsOneWidget);
    expect(find.text('Resumo da ficha'), findsOneWidget);
    expect(find.text('Preparar minha aula'), findsOneWidget);
    expect(session.entryPath, 'tenho_material');
    expect(session.materialType, 'Lista de exercícios');
  });

  testWidgets('O.15 prova visual da timeline conversacional', (tester) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/idioma';

    await _pumpEntry(tester, session, size: const Size(430, 3400));
    await tester.enterText(
      find.byKey(const Key('sim-entry-name-input')),
      'Lucas',
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Criança'));
    await _tapVisible(tester, find.text('Quero que o SIM monte'));
    await _tapVisible(tester, find.text('Matemática'));
    await tester.enterText(
      find.byKey(const Key('sim-entry-topic-input')),
      'Frações',
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Fundamental'));
    await _tapVisible(tester, find.text('Brasil'));
    await tester.enterText(
      find.byKey(const Key('sim-entry-objective-input')),
      'Prova da escola esta semana.',
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Esta semana'));
    await _tapVisible(tester, find.text('Falta de base'));
    await _tapVisible(tester, find.text('Com imagem'));

    await tester.pumpWidget(
      SimThemeScope(
        darkMode: false,
        onToggleDarkMode: () {},
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, fontFamily: 'Inter'),
          home: ConversationalEntryScreen(session: session),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('sim-entry-language-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sim-entry-language-button')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ConversationalEntryScreen),
      matchesGoldenFile('goldens/o_conversational_entry.png'),
    );
  });
}
