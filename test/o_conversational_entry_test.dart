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

Future<void> _completeProfileGroup(
  WidgetTester tester, {
  String name = 'Lucas',
  String? age = '12',
  List<String> difficulties = const ['Falta de base', 'Concentração'],
  String? observation = 'Aprendo melhor com exemplos curtos.',
}) async {
  await tester.enterText(find.byKey(const Key('sim-entry-name-input')), name);
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.byKey(const Key('sim-entry-name-submit')));

  if (age == null) {
    await _tapVisible(tester, find.byKey(const Key('sim-entry-age-skip')));
  } else {
    await tester.enterText(find.byKey(const Key('sim-entry-age-input')), age);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('sim-entry-age-submit')));
  }

  for (final difficulty in difficulties) {
    await _tapVisible(tester, find.text(difficulty));
  }
  await _tapVisible(
    tester,
    find.byKey(const Key('sim-entry-difficulty-submit')),
  );

  if (observation == null) {
    await _tapVisible(
      tester,
      find.byKey(const Key('sim-entry-observation-skip')),
    );
  } else {
    await tester.enterText(
      find.byKey(const Key('sim-entry-observation-input')),
      observation,
    );
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('sim-entry-observation-submit')),
    );
  }
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

    await _completeProfileGroup(tester);
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
    await _tapVisible(tester, find.text('Falta de base').last);
    await _tapVisible(tester, find.text('Com imagem'));

    await _tapVisible(
      tester,
      find.byKey(const Key('sim-entry-prepare-button')),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final ficha =
        capturedOnboarding?['pedagogical_entry_ficha'] as Map<String, dynamic>?;
    expect(ficha, isNotNull);
    expect(ficha?['preferred_name'], 'Lucas');
    expect(ficha?['student_age'], '12');
    expect(ficha?['age_declared'], isTrue);
    expect(ficha?['profile_difficulties'], contains('Falta de base'));
    expect(ficha?['profile_difficulties'], contains('Concentração'));
    expect(
      ficha?['profile_observation'],
      'Aprendo melhor com exemplos curtos.',
    );
    expect(ficha?['profile_summary'], contains('Lucas'));
    expect(ficha?['initial_adaptation_guidance'], contains('Concentração'));
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
    expect(
      find.text('SIM: Quer me dizer sua idade? Pode pular.'),
      findsNothing,
    );
    expect(find.text('Tenho material'), findsNothing);
    expect(find.text('Quero que o SIM monte'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('sim-entry-name-input')),
      'Lucas',
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('sim-entry-name-submit')));
    expect(
      find.text('SIM: Quer me dizer sua idade? Pode pular.'),
      findsOneWidget,
    );
    expect(find.text('Tenho material'), findsNothing);
    final nameField = tester.widget<TextField>(
      find.byKey(const Key('sim-entry-name-input')),
    );
    expect(nameField.enabled, isFalse);

    await tester.enterText(find.byKey(const Key('sim-entry-age-input')), '13');
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('sim-entry-age-submit')));
    expect(
      find.text('SIM: Quando você estuda, o que mais atrapalha?'),
      findsOneWidget,
    );
    await _tapVisible(tester, find.text('Falta de base').last);
    await _tapVisible(tester, find.text('Travo em exercícios'));
    expect(session.profileDifficulties, contains('Falta de base'));
    expect(session.profileDifficulties, contains('Travo em exercícios'));
    await _tapVisible(
      tester,
      find.byKey(const Key('sim-entry-difficulty-submit')),
    );
    expect(
      find.text(
        'SIM: Quer me contar algo que ajude o SIM a te orientar melhor?',
      ),
      findsOneWidget,
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('sim-entry-observation-skip')),
    );
    expect(find.text('Tenho material'), findsOneWidget);
    expect(find.text('Quero que o SIM monte'), findsOneWidget);
    await _tapVisible(tester, find.text('Tenho material'));
    await _tapVisible(tester, find.text('Lista de exercícios'));

    expect(find.text('Lucas'), findsWidgets);
    expect(find.text('13'), findsWidgets);
    expect(find.text('Caminho A:'), findsOneWidget);
    expect(find.text('Foto do caderno'), findsOneWidget);
    expect(find.text('Livro/PDF'), findsOneWidget);
    expect(find.text('Dúvida específica'), findsOneWidget);
    expect(find.text('Resumo da ficha'), findsOneWidget);
    expect(find.text('Preparar minha aula'), findsOneWidget);
    expect(session.entryPath, 'tenho_material');
    expect(session.materialType, 'Lista de exercícios');
  });

  testWidgets('O.9 ficha nao inventa idade nem observacao puladas', (
    tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/idioma';

    await _pumpEntry(tester, session);
    await _completeProfileGroup(
      tester,
      age: null,
      difficulties: const ['Não sei dizer'],
      observation: null,
    );

    final ficha = session.buildPedagogicalFicha();
    expect(ficha['preferred_name'], 'Lucas');
    expect(ficha['age_declared'], isFalse);
    expect(ficha.containsKey('student_age'), isFalse);
    expect(ficha['profile_difficulties'], ['Não sei dizer']);
    expect(ficha.containsKey('profile_observation'), isFalse);
    expect(ficha['profile_summary'], isNot(contains('anos')));
    expect(find.text('Tenho material'), findsOneWidget);
  });

  testWidgets('O.12 Grupo 1 quebra opcoes sem overflow em celular e tablet', (
    tester,
  ) async {
    for (final size in [const Size(360, 900), const Size(920, 900)]) {
      final session = LabSession()
        ..authed = true
        ..authReady = true
        ..route = '/cyber/idioma';

      await _pumpEntry(tester, session, size: size);
      await tester.enterText(
        find.byKey(const Key('sim-entry-name-input')),
        'Lucas',
      );
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const Key('sim-entry-name-submit')));
      await tester.enterText(
        find.byKey(const Key('sim-entry-age-input')),
        '12',
      );
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const Key('sim-entry-age-submit')));

      expect(
        find.text('SIM: Quando você estuda, o que mais atrapalha?'),
        findsOneWidget,
      );
      expect(find.text('Não sei por onde começar'), findsOneWidget);
      expect(find.text('Fico nervoso em prova'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('O.15 prova visual da timeline conversacional', (tester) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/idioma';

    await _pumpEntry(tester, session, size: const Size(430, 3400));
    await _completeProfileGroup(tester);
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
    await _tapVisible(tester, find.text('Falta de base').last);
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
