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
  String interfaceLocale = 'pt-BR',
}) async {
  await session.setInterfaceLanguage(
    followDevice: false,
    localeTag: interfaceLocale,
  );
  await session.setLearningLanguage(localeTag: interfaceLocale);
  expect(session.interfaceLocaleTag, interfaceLocale);
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

Future<void> _scrollUntilText(WidgetTester tester, String label) async {
  final target = find.text(label);
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
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

Future<void> _completeSimBuildPathWithG3(
  WidgetTester tester, {
  required LabSession session,
  String topic = 'Frações equivalentes',
  String level = 'Ensino médio, internacional',
  String goal = 'Prova ou teste',
  String deadline = 'Esta semana',
  String expectedResult = 'Resolver exercícios',
}) async {
  await _tapVisible(tester, find.text('Quero que o SIM monte minhas aulas'));
  await tester.enterText(find.byKey(const Key('sim-entry-topic-input')), topic);
  await tester.pumpAndSettle();
  await _tapVisible(tester, find.byKey(const Key('sim-entry-topic-submit')));
  await tester.enterText(find.byKey(const Key('sim-entry-level-input')), level);
  await tester.pumpAndSettle();
  session.localeSettings = session.localeSettings.copyWith(
    followDeviceInterface: false,
    manualInterfaceLocale: 'pt-BR',
    learningLocale: 'pt-BR',
  );
  setSimActiveLanguage('pt-BR');
  await _tapVisible(tester, find.byKey(const Key('sim-entry-level-submit')));
  await _scrollUntilText(tester, goal);
  await _tapVisible(tester, find.text(goal));
  await _tapVisible(tester, find.byKey(const Key('sim-entry-g3-goal-submit')));
  await _scrollUntilText(tester, deadline);
  await _tapVisible(tester, find.text(deadline));
  await _tapVisible(
    tester,
    find.byKey(const Key('sim-entry-g3-deadline-submit')),
  );
  await _scrollUntilText(tester, expectedResult);
  await _tapVisible(tester, find.text(expectedResult));
  await _tapVisible(
    tester,
    find.byKey(const Key('sim-entry-g3-result-submit')),
  );
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

    await tester.drag(
      find.byKey(const Key('sim-entry-language-list')),
      const Offset(0, 180),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Português'));
    await tester.pumpAndSettle();

    expect(session.interfaceLocaleTag, 'pt-BR');
    expect(session.learningLocaleTag, 'pt-BR');
    expect(session.explanationLanguage, 'Portuguese');
    expect(find.textContaining('Português'), findsWidgets);
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

    await _pumpEntry(tester, session, interfaceLocale: 'en');

    await _completeProfileGroup(tester);
    await _completeSimBuildPathWithG3(tester, session: session);

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
    expect(ficha?['topic'], 'Frações equivalentes');
    expect(ficha?['academic_level'], 'Ensino médio, internacional');
    expect(ficha?['objective'], contains('Frações equivalentes'));
    expect(ficha?['learning_goal'], 'Frações equivalentes');
    expect(ficha?['traversal_goal'], 'Prova ou teste');
    expect(ficha?['exam_goal'], 'Prova ou teste');
    expect(ficha?['deadline'], 'Esta semana');
    expect(ficha?['session_goal'], 'Esta semana');
    expect(ficha?['expected_result'], 'Resolver exercícios');
    expect(ficha?['goal_summary'], contains('Objetivo real: Prova ou teste'));
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
    expect(find.text('Quero que o SIM monte minhas aulas'), findsNothing);
    expect(find.text('Quero mostrar meu material ao SIM'), findsNothing);

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
    expect(find.text('Quero mostrar meu material ao SIM'), findsNothing);
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
    expect(find.text('Quero que o SIM monte minhas aulas'), findsOneWidget);
    expect(find.text('Quero mostrar meu material ao SIM'), findsOneWidget);
    await _tapVisible(tester, find.text('Quero mostrar meu material ao SIM'));
    await _tapVisible(tester, find.text('Lista'));

    expect(find.text('Lucas'), findsWidgets);
    expect(find.text('13'), findsWidgets);
    expect(
      find.text('SIM: Envie ou descreva o material que você quer estudar.'),
      findsOneWidget,
    );
    expect(find.text('Foto do caderno'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('Questão'), findsOneWidget);
    expect(find.text('Resumo da ficha'), findsOneWidget);
    expect(find.text('Preparar minha aula'), findsOneWidget);
    expect(session.entryPath, 'tenho_material');
    expect(session.materialType, 'Lista');
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
    expect(find.text('Quero mostrar meu material ao SIM'), findsOneWidget);
  });

  testWidgets('G2.3-G3.8 Fluxo 1 usa dois cards minimos e Grupo 3 universal', (
    tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/idioma';

    await _pumpEntry(tester, session, size: const Size(760, 1200));
    await _completeProfileGroup(tester);

    final firstButton = find.text('Quero que o SIM monte minhas aulas');
    final secondButton = find.text('Quero mostrar meu material ao SIM');
    expect(firstButton, findsOneWidget);
    expect(secondButton, findsOneWidget);
    expect(
      tester.getCenter(firstButton).dx,
      lessThan(tester.getCenter(secondButton).dx),
    );
    expect(
      find.text(
        'Conte o que você precisa aprender. O SIM organiza o plano, cria microaulas e exercícios para te conduzir do ponto certo até o objetivo.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Você diz o objetivo. O SIM monta o caminho.'),
      findsOneWidget,
    );

    await _tapVisible(tester, firstButton);
    expect(find.text('SIM: O que você quer aprender?'), findsOneWidget);
    expect(find.text('SIM: Qual nível devo considerar?'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('sim-entry-topic-input')),
      'Sistema digestivo',
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('sim-entry-topic-submit')));
    final topicField = tester.widget<TextField>(
      find.byKey(const Key('sim-entry-topic-input')),
    );
    expect(topicField.enabled, isFalse);
    expect(find.text('SIM: Qual nível devo considerar?'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('sim-entry-level-input')),
      'Ensino médio, currículo local',
    );
    await tester.pumpAndSettle();
    setSimActiveLanguage('pt-BR');
    await _tapVisible(tester, find.byKey(const Key('sim-entry-level-submit')));
    expect(session.entryPath, 'sim_monta');
    expect(session.topic, 'Sistema digestivo');
    expect(session.academicLevel, 'Ensino médio, currículo local');
    expect(session.simLearningLevelSubmitted, isTrue);
    await _scrollUntilText(tester, 'SIM: Para que você está estudando isso?');
    expect(
      find.text('SIM: Para que você está estudando isso?'),
      findsOneWidget,
    );
    expect(find.text('Prova ou teste'), findsOneWidget);
    expect(find.text('Exame de entrada ou vestibular'), findsOneWidget);
    expect(find.text('ENEM'), findsNothing);
    expect(find.text('Resumo da ficha'), findsNothing);
    await _tapVisible(tester, find.text('Uso no trabalho'));
    await _tapVisible(
      tester,
      find.byKey(const Key('sim-entry-g3-goal-submit')),
    );
    await _scrollUntilText(tester, 'SIM: Você tem prazo?');
    expect(find.text('SIM: Você tem prazo?'), findsOneWidget);
    await _tapVisible(tester, find.text('Quero escrever uma data'));
    await tester.enterText(
      find.byKey(const Key('sim-entry-g3-deadline-custom')),
      '15 de agosto',
    );
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('sim-entry-g3-deadline-submit')),
    );
    await _scrollUntilText(
      tester,
      'SIM: O que você quer conseguir fazer no final?',
    );
    expect(
      find.text('SIM: O que você quer conseguir fazer no final?'),
      findsOneWidget,
    );
    await _tapVisible(tester, find.text('Aplicar na prática'));
    await _tapVisible(
      tester,
      find.byKey(const Key('sim-entry-g3-result-submit')),
    );
    expect(find.text('Resumo da ficha'), findsOneWidget);
    final ficha = session.buildPedagogicalFicha();
    expect(ficha['entry_path'], 'sim_monta');
    expect(ficha['learning_goal'], 'Sistema digestivo');
    expect(ficha['real_use_goal'], 'Uso no trabalho');
    expect(ficha['deadline_custom'], '15 de agosto');
    expect(ficha['session_goal'], '15 de agosto');
    expect(ficha['expected_result'], 'Aplicar na prática');
  });

  testWidgets('G2.4-G2.10 Fluxo 2 material e final sem Grupo 3 obrigatorio', (
    tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/idioma';

    await _pumpEntry(tester, session);
    await _completeProfileGroup(tester);

    expect(
      find.text(
        'Envie foto, lista, livro, caderno, prova, PDF, questão ou resposta que tentou fazer. O SIM olha seu material e te ensina a resolver aquilo.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Você mostra o material. O SIM te ajuda com ele.'),
      findsOneWidget,
    );
    await _tapVisible(tester, find.text('Quero mostrar meu material ao SIM'));
    expect(
      find.text('SIM: Envie ou descreva o material que você quer estudar.'),
      findsOneWidget,
    );
    await _tapVisible(tester, find.text('Questão'));
    await tester.enterText(
      find.byKey(const Key('sim-entry-material-notes')),
      'Tenho esta questão da lista e quero entender como resolver.',
    );
    await tester.pumpAndSettle();

    expect(find.text('SIM: O que você quer aprender?'), findsNothing);
    expect(find.text('SIM: Qual nível devo considerar?'), findsNothing);
    expect(find.text('SIM: Para que você está estudando isso?'), findsNothing);
    expect(find.text('SIM: Você tem prazo?'), findsNothing);
    expect(find.text('Resumo da ficha'), findsOneWidget);
    final ficha = session.buildPedagogicalFicha();
    expect(ficha['entry_path'], 'tenho_material');
    expect(ficha['material_type'], 'Questão');
    expect(ficha['objective'], contains('questão da lista'));
    expect(
      (ficha['material_received'] as Map)['freeText'],
      contains('questão'),
    );
  });

  testWidgets('G3.9 Grupo 3 usa textos localizaveis em ingles', (tester) async {
    setSimActiveLanguage('en');
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/idioma';

    await _pumpEntry(tester, session);
    await _completeProfileGroup(tester);
    await _tapVisible(tester, find.text('Quero que o SIM monte minhas aulas'));
    await tester.enterText(
      find.byKey(const Key('sim-entry-topic-input')),
      'Digestive system',
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('sim-entry-topic-submit')));
    await tester.enterText(
      find.byKey(const Key('sim-entry-level-input')),
      'Beginner',
    );
    await tester.pumpAndSettle();
    session.localeSettings = session.localeSettings.copyWith(
      followDeviceInterface: false,
      manualInterfaceLocale: 'en',
      learningLocale: 'en',
    );
    setSimActiveLanguage('en');
    await _tapVisible(tester, find.byKey(const Key('sim-entry-level-submit')));

    await _scrollUntilText(tester, 'SIM: What are you studying this for?');
    expect(find.text('SIM: What are you studying this for?'), findsOneWidget);
    expect(find.text('Para que você está estudando isso?'), findsNothing);
    expect(find.text('Entrance or admission exam'), findsOneWidget);
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
    await _completeSimBuildPathWithG3(
      tester,
      session: session,
      topic: 'Frações',
      level: '5º ano, currículo local',
      expectedResult: 'Resolver exercícios',
    );

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

  testWidgets('G2.15 prova visual do Fluxo 2 material proprio', (tester) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/idioma';

    await _pumpEntry(tester, session, size: const Size(430, 2500));
    await _completeProfileGroup(tester);
    await _tapVisible(tester, find.text('Quero mostrar meu material ao SIM'));
    await _tapVisible(tester, find.text('Questão'));
    await tester.enterText(
      find.byKey(const Key('sim-entry-material-notes')),
      'Tenho esta questão e quero entender a resolução.',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Anexar material'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ConversationalEntryScreen),
      matchesGoldenFile('goldens/g2_material_path.png'),
    );
  });
}
