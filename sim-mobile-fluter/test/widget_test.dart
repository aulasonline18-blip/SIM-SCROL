import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/classroom/chat_aula_screen.dart';
import 'package:sim_mobile/main.dart';
import 'package:sim_mobile/shared/widgets/shared_widgets.dart';
import 'package:sim_mobile/sim/cloud/cloud_functions.dart';
import 'package:sim_mobile/sim/cloud/supabase_client_contract.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_attachment_client.dart';
import 'package:sim_mobile/sim/experience/student_experience_types.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

Finder _textAny(List<String> labels) {
  for (final label in labels) {
    final finder = find.text(label);
    if (finder.evaluate().isNotEmpty) return finder;
  }
  return find.text(labels.first);
}

void main() {
  setUp(() => setSimActiveLanguage('en'));

  testWidgets('A rota de aula usa chat como default controlado', (
    WidgetTester tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/aula';

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    await tester.pumpAndSettle();

    expect(find.byType(ChatAulaScreen), findsOneWidget);
  });

  testWidgets('Portal shows SIM entry point', (WidgetTester tester) async {
    await tester.pumpWidget(const SimMobileApp());
    expect(find.text('SIM'), findsOneWidget);
    expect(find.text('Sign in to start'), findsOneWidget);
    expect(find.text('Smart Intelligence Mentor'), findsOneWidget);
  });

  testWidgets('selecionar idioma troca textos visiveis do fluxo inicial', (
    WidgetTester tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true;

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    expect(_textAny(['Start', 'Começar', 'Commencer']), findsOneWidget);

    await tester.tap(_textAny(['Start', 'Começar', 'Commencer']));
    await tester.pumpAndSettle();
    expect(
      _textAny([
        'Choose your language',
        'Escolha seu idioma',
        'Choisissez votre langue',
      ]),
      findsOneWidget,
    );

    await tester.tap(find.textContaining('Português'));
    await tester.pumpAndSettle();
    expect(find.text('Conte-nos sobre quem vai estudar'), findsOneWidget);
    expect(
      _textAny([
        'Escreva com suas palavras. SIM vai montar o currículo ideal.',
        'Write in your own words. SIM will build the ideal curriculum.',
      ]),
      findsOneWidget,
    );
    expect(session.selectedLanguageCode, 'pt');
    expect(session.stableLang, 'Portuguese');

    final french = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/idioma';
    await tester.pumpWidget(
      SimMobileApp(key: UniqueKey(), initialSession: french),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Français'));
    await tester.pumpAndSettle();
    expect(
      find.text('Parlez-nous de la personne qui va étudier'),
      findsOneWidget,
    );
    expect(
      _textAny([
        'Écrivez avec vos propres mots. SIM construira le programme idéal.',
        'Write in your own words. SIM will build the ideal curriculum.',
      ]),
      findsOneWidget,
    );
    expect(french.selectedLanguageCode, 'fr');
    expect(french.stableLang, 'French');
  });

  testWidgets('Portal alterna e persiste dark mode', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(SimMobileApp(prefs: prefs));

    expect(find.bySemanticsLabel('Turn on dark mode'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Turn on dark mode'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Turn on light mode'), findsOneWidget);
    expect(prefs.getBool('sim.ui.dark_mode'), isTrue);
  });

  testWidgets('Dark mode aplica fundo escuro no portal', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'sim.ui.dark_mode': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(SimMobileApp(prefs: prefs));
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFF05070D));
    expect(find.bySemanticsLabel('Turn on light mode'), findsOneWidget);
  });

  testWidgets('Dark mode aplica fundo escuro no onboarding', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'sim.ui.dark_mode': true});
    final prefs = await SharedPreferences.getInstance();
    final session = LabSession()
      ..route = '/cyber/idioma'
      ..authed = true
      ..authReady = true;

    await tester.pumpWidget(
      SimMobileApp(initialSession: session, prefs: prefs),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFF05070D));
    expect(find.text('Choose your language'), findsOneWidget);
  });

  testWidgets('Objetivo continua, prepara primeira aula e permite responder', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    var t00Called = false;
    var t02Called = false;
    final session =
        LabSession(
            attachmentFilePicker: (source) async => const SimAttachmentFile(
              name: 'lista-da-prova.pdf',
              contentType: 'application/pdf',
              bytes: [37, 80, 68, 70, 45, 49, 46, 52],
            ),
            experiencePreparerOverride: (args) async {
              t00Called = true;
              expect(args.onboarding['objetivo'], contains('matemática'));
              args.onStage?.call(StudentExperienceRouteStage.curriculum);
              await Future<void>.delayed(const Duration(milliseconds: 1));
              args.onStage?.call(StudentExperienceRouteStage.lesson);
              t02Called = true;
              await Future<void>.delayed(const Duration(milliseconds: 1));
              args.onStage?.call(StudentExperienceRouteStage.ready);
              return const StudentExperienceResult(
                destination: '/cyber/aula',
                curriculum: StudentCurriculum(
                  topic: 'Matemática',
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
          ..credits = 999999;
    await tester.pumpWidget(SimMobileApp(initialSession: session));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('English'));
    await tester.pumpAndSettle();
    expect(find.text('Tell us about who is going to study'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attach file'));
    await tester.pumpAndSettle();
    expect(find.textContaining('lista-da-prova.pdf'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'Quero estudar essa lista para a prova de matemática.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and continue'));
    await tester.pump(const Duration(milliseconds: 220));
    expect(t00Called, isTrue, reason: 'clicar continuar deve iniciar T00');
    await tester.pump(const Duration(seconds: 1));
    expect(t02Called, isTrue, reason: 'primeiro item deve iniciar T02');
    await tester.pumpAndSettle();
    expect(find.text('/cyber/curriculo'), findsNothing);
    expect(find.textContaining('entry.status: pedido_recebido'), findsNothing);
    expect(find.text('B'), findsOneWidget);
    expect(
      find.text('Qual alternativa representa uma fração equivalente a 1/2?'),
      findsOneWidget,
    );
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.text('Exato! Você domina este ponto.'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Preenchimento exposes credits checkout and support rooms', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..credits = 3;

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    session.openSupport('/creditos');
    await tester.pumpAndSettle();
    expect(find.text('Meus créditos'), findsOneWidget);
    expect(find.text('SALDO ATUAL'), findsOneWidget);
    await tester.tap(find.text('cerca de 33 aulas'));
    await tester.pumpAndSettle();
    expect(find.text('login_required'), findsOneWidget);
    expect(find.text('Retorno do pagamento'), findsNothing);
    expect(find.text('cerca de 166 aulas'), findsOneWidget);

    session.openSupport('/privacidade');
    await tester.pumpAndSettle();
    expect(session.route, '/privacidade');
    session.openSupport('/termos');
    await tester.pumpAndSettle();
    expect(session.route, '/termos');
    session.openSupport('/pai');
    await tester.pumpAndSettle();
    expect(find.text('Restricted access'), findsOneWidget);
    session.authSession.roles = const {'parent'};
    session.openSupport('/pai');
    await tester.pumpAndSettle();
    expect(_textAny(['Parent Panel', 'Painel do Pai']), findsOneWidget);
    session.openSupport('/conta/deletar');
    await tester.pumpAndSettle();
    final deleteAction = _textAny([
      'Request account deletion',
      'Solicitar exclusão da conta',
    ]);
    expect(deleteAction, findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'DELETAR');
    await tester.pumpAndSettle();
    await tester.tap(deleteAction.last);
    await tester.pumpAndSettle();
    expect(session.route, '/conta/deletar');

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('rotas sensiveis exigem login pelo roteador central', (
    WidgetTester tester,
  ) async {
    final session = LabSession()
      ..authReady = true
      ..authed = false
      ..route = '/creditos';

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to continue'), findsOneWidget);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(session.route, '/login');
    expect(session.returnTo, '/creditos');

    session
      ..route = '/conta/deletar'
      ..returnTo = '/';
    session.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue'), findsOneWidget);
  });

  testWidgets('Preenchimento shows doubt and qualifier flow in aula', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..credits = 3
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'Portuguese'
      ..freeText = 'Fracoes equivalentes explicadas com exemplos simples.';
    expect(session.saveObjectiveEntry(), isTrue);
    session.route = '/cyber/aula';
    await session.openAulaRuntime();
    await tester.pumpWidget(SimMobileApp(initialSession: session));

    expect(find.byIcon(Icons.help_outline), findsNothing);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.text('Dúvida'), findsOneWidget);
    await tester.tap(find.text('Dúvida'));
    await tester.pumpAndSettle();
    expect(find.text('Enviar dúvida'), findsWidgets);
    expect(
      find.text(
        'Escreva sua dúvida ou envie uma foto do exercício, resolução, fórmula, gráfico ou tabela.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsWidgets);
    await tester.tap(find.byIcon(Icons.attach_file).last);
    await tester.pumpAndSettle();
    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('Escolher imagem'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Nao entendi a conta.');
    await tester.tap(find.text('Enviar dúvida').last);
    await tester.pump(const Duration(milliseconds: 20));
    expect(session.doubt.status.name, 'explaining');
    expect(session.doubt.response?.explanation, contains('frações'));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('aula keeps signals and feedback visible after answer flow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 520));
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..credits = 3
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'Portuguese'
      ..freeText = 'Fracoes equivalentes com uma aula curta.';
    expect(session.saveObjectiveEntry(), isTrue);
    session.route = '/cyber/aula';

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    await session.openAulaRuntime();
    await tester.pumpAndSettle();

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    final signalRect = tester.getRect(find.text('2'));
    expect(signalRect.top, greaterThanOrEqualTo(0));
    expect(signalRect.bottom, lessThanOrEqualTo(520));

    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    final feedbackRect = tester.getRect(
      find.text('Exato! Você domina este ponto.'),
    );
    expect(feedbackRect.top, greaterThanOrEqualTo(0));
    expect(feedbackRect.bottom, lessThanOrEqualTo(520));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Aula sem curriculo mostra estado vazio equivalente ao Web', (
    WidgetTester tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..route = '/cyber/aula'
      ..aulaRuntimeError = 'Aula sem curriculo no Estado do aluno.';

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    await tester.pumpAndSettle();

    expect(find.text('Currículo não encontrado'), findsOneWidget);
    expect(find.text('Volte e monte um novo currículo.'), findsOneWidget);
    await tester.tap(find.text('Voltar ao currículo'));
    await tester.pumpAndSettle();
    expect(find.text('Tell us about who is going to study'), findsOneWidget);
  });

  testWidgets('Drawer lista, busca, renomeia e apaga aulas locais', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    final session = LabSession()
      ..authed = false
      ..authReady = true
      ..credits = 3;
    final store = session.canonicalStore!;
    store.writeState(_drawerState('lesson-a', 'Álgebra linear', 1));
    store.writeState(_drawerState('lesson-b', 'Biologia celular', 2));
    session.lessonLocalId = 'lesson-a';

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAulaMenu(context, session),
            child: const Text('open drawer'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open drawer'));
    await tester.pumpAndSettle();

    expect(find.text('Álgebra linear'), findsOneWidget);
    expect(find.text('Biologia celular'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Logout'), findsNothing);
    expect(find.text('Solicitar exclusão da conta'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'bio');
    await tester.pumpAndSettle();
    expect(find.text('Álgebra linear'), findsNothing);
    expect(find.text('Biologia celular'), findsOneWidget);

    await tester.tap(find.text('✎').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Citologia');
    await tester.tap(find.text('✓'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    expect(find.text('Citologia'), findsOneWidget);

    await tester.tap(find.text('🗑').first);
    await tester.pumpAndSettle();
    expect(find.text('Apagar esta aula?'), findsOneWidget);
    await tester.tap(find.text('🗑').last);
    await tester.pumpAndSettle();
    expect(find.text('Citologia'), findsNothing);
    expect(store.listLocalStates(), hasLength(1));
    expect(store.listLocalStates(includeDeleted: true), hasLength(2));
    await tester.pump(const Duration(milliseconds: 2300));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Drawer cloud lista, deduplica, abre, renomeia e apaga', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    final cloud = _FakeDrawerCloud()
      ..put(_drawerState('lesson-a', 'Duplicada na conta', 1))
      ..put(_drawerState('cloud-c', 'Geometria na conta', 1))
      ..put(_drawerState('cloud-d', 'Física na conta', 2))
      ..put(_drawerState('cloud-e', 'Química na conta', 1));
    final session =
        LabSession(
            drawerCloudFunctions: cloud,
            drawerSessionProvider: _FakeDrawerSessionProvider(),
          )
          ..authed = true
          ..authReady = true
          ..credits = 3;
    session.canonicalStore!.writeState(_drawerState('lesson-a', 'Local A', 1));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAulaMenu(context, session),
            child: const Text('open cloud drawer'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open cloud drawer'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Recarregar créditos'));
    await tester.pumpAndSettle();
    expect(session.route, '/creditos?returnTo=/cyber/aula');
    expect(session.returnTo, '/cyber/aula');
    session.route = '/cyber/aula';
    await tester.tap(find.text('open cloud drawer'));
    await tester.pumpAndSettle();

    expect(find.text('Duplicada na conta'), findsNothing);
    expect(find.text('Geometria na conta'), findsOneWidget);
    expect(find.text('Física na conta'), findsOneWidget);
    expect(find.text('Química na conta'), findsOneWidget);

    await tester.tap(find.text('Física na conta'));
    await tester.pumpAndSettle();
    expect(session.lessonLocalId, 'cloud-d');
    expect(session.route, '/cyber/aula');
    expect(session.canonicalStore!.listLocalStates(), hasLength(2));

    await tester.tap(find.text('open cloud drawer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('✎').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Geometria editada');
    await tester.tap(find.text('✓'));
    await tester.pumpAndSettle();
    expect(cloud.persistCalls, 1);
    expect(find.text('Geometria editada'), findsOneWidget);
    expect(find.text('Química na conta'), findsOneWidget);

    await tester.tap(find.text('🗑').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('🗑').last);
    await tester.pumpAndSettle();
    expect(cloud.deleteCalls, 1);
    expect(find.text('Química na conta'), findsNothing);
    expect(find.text('Geometria editada'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2300));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('drawer_new_lesson_and_local_delete_follow_web_contract', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    final cloud = _FakeDrawerCloud()
      ..put(_drawerState('lesson-delete', 'Apagar sincronizado', 1));
    final session =
        LabSession(
            drawerCloudFunctions: cloud,
            drawerSessionProvider: _FakeDrawerSessionProvider(),
          )
          ..authed = true
          ..authReady = true
          ..credits = 3;
    session.canonicalStore!.writeState(
      _drawerState('lesson-delete', 'Apagar sincronizado', 1),
    );
    session.lessonLocalId = 'lesson-delete';
    session.route = '/cyber/aula';

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAulaMenu(context, session),
            child: const Text('open contract drawer'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open contract drawer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nova aula'));
    await tester.pumpAndSettle();
    expect(session.route, '/cyber/aula');
    expect(session.lessonLocalId, isNull);

    session.lessonLocalId = 'lesson-delete';
    await tester.tap(find.text('open contract drawer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🗑').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('🗑').last);
    await tester.pumpAndSettle();
    expect(cloud.deleteCalls, 1);
    expect(
      session.canonicalStore!.listLocalStates(includeDeleted: true),
      hasLength(1),
    );
    expect(session.canonicalStore!.listLocalStates(), isEmpty);
    await tester.pump(const Duration(milliseconds: 2300));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('drawer_local_actions_test pagina aulas locais', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    final session = LabSession()
      ..authed = false
      ..authReady = true
      ..credits = 3;
    final store = session.canonicalStore!;
    for (var i = 1; i <= 31; i++) {
      store.writeState(_drawerState('lesson-$i', 'Aula $i', i % 3));
    }
    session.lessonLocalId = 'lesson-1';

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAulaMenu(context, session),
            child: const Text('open paged drawer'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open paged drawer'));
    await tester.pumpAndSettle();

    expect(find.text('30/31'), findsOneWidget);
    expect(find.text('Carregar mais'), findsOneWidget);
    await tester.ensureVisible(find.text('Carregar mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carregar mais'));
    await tester.pumpAndSettle();
    expect(find.text('31/31'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  test('drawer_backup_import_export_test exports and imports backup', () async {
    final cloud = _FakeDrawerCloud();
    final session =
        LabSession(
            drawerCloudFunctions: cloud,
            drawerSessionProvider: _FakeDrawerSessionProvider(),
          )
          ..authed = true
          ..authReady = true
          ..credits = 3;
    final store = session.canonicalStore!;
    store.writeState(_drawerState('lesson-export', 'Aula exportada', 1));
    session.lessonLocalId = 'lesson-export';
    final directBackup = session.buildDrawerBackupText();
    expect(directBackup, contains('SIM_CYBER_V1_BEGIN'));
    expect(directBackup, contains('SIM_CYBER_V1_END'));

    final exportedFile = await session.writeDrawerBackupFile(directBackup);
    expect(exportedFile.path, contains('sim-backup-'));
    expect(await exportedFile.readAsString(), directBackup);

    final imported = await session.importDrawerBackup(directBackup);

    expect(session.lessonLocalId, 'lesson-export');
    expect(imported.lessonLocalId, 'lesson-export');
    expect(store.listLocalStates(), hasLength(1));
    expect(cloud.persistCalls, 1);
  });

  testWidgets('drawer imports backup from txt file and keeps paste fallback', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    final source = LabSession()
      ..authed = false
      ..authReady = true
      ..credits = 3;
    source.canonicalStore!.writeState(
      _drawerState('lesson-file-import', 'Backup por arquivo', 2),
    );
    final backup = source.buildDrawerBackupText();
    var pickerCalls = 0;
    final session = LabSession(
      drawerBackupFileTextPicker: () async {
        pickerCalls += 1;
        return backup;
      },
    )..authReady = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAulaMenu(context, session),
            child: const Text('open import drawer'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open import drawer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('⤒ Importar'));
    await tester.pumpAndSettle();
    expect(
      _textAny([t('backup_select_file'), 'Selecionar arquivo .txt']),
      findsOneWidget,
    );
    expect(
      _textAny([t('backup_paste_manual'), 'Colar texto manualmente']),
      findsOneWidget,
    );

    await tester.tap(
      _textAny([t('backup_select_file'), 'Selecionar arquivo .txt']),
    );
    await tester.pumpAndSettle();
    expect(pickerCalls, 1);
    expect(session.lessonLocalId, 'lesson-file-import');
    expect(
      session.canonicalStore!.readState('lesson-file-import').profile.objetivo,
      'Backup por arquivo',
    );

    final pasteSource = LabSession()
      ..authed = false
      ..authReady = true
      ..credits = 3;
    pasteSource.canonicalStore!.writeState(
      _drawerState('lesson-paste-import', 'Backup por texto', 1),
    );
    final pasteBackup = pasteSource.buildDrawerBackupText();

    await tester.tap(find.text('⤒ Importar'));
    await tester.pumpAndSettle();
    await tester.tap(
      _textAny([t('backup_paste_manual'), 'Colar texto manualmente']),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, pasteBackup);
    await tester.tap(find.text('⤒ Importar').last);
    await tester.pumpAndSettle();
    expect(session.lessonLocalId, 'lesson-paste-import');
    expect(
      session.canonicalStore!.readState('lesson-paste-import').profile.objetivo,
      'Backup por texto',
    );

    await tester.pump(const Duration(milliseconds: 2200));
    await tester.binding.setSurfaceSize(null);
  });
}

class _FakeDrawerSessionProvider implements SupabaseSessionProvider {
  @override
  Future<SupabaseSession?> currentSession() async =>
      const SupabaseSession(accessToken: 'token', userId: 'u1');
}

class _FakeDrawerCloud implements StudentStateCloudFunctions {
  final Map<String, StudentLearningState> states = {};
  int persistCalls = 0;
  int deleteCalls = 0;

  void put(StudentLearningState state) {
    states[state.lessonLocalId] = state;
  }

  @override
  Future<void> deleteStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async {
    deleteCalls += 1;
    states.remove(lessonLocalId);
  }

  @override
  Future<StudentStateRow?> getStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async {
    final state = states[lessonLocalId];
    if (state == null) return null;
    return StudentStateRow(
      lessonLocalId: lessonLocalId,
      state: state,
      highWaterMark: scoreOfStudentLearningState(state),
      schemaVersion: studentLearningStateSchemaVersion,
    );
  }

  @override
  Future<List<StudentStateRow>> listStudentStates(
    SupabaseSession session,
  ) async {
    return [
      for (final state in states.values)
        StudentStateRow(
          lessonLocalId: state.lessonLocalId,
          state: state,
          highWaterMark: scoreOfStudentLearningState(state),
          schemaVersion: studentLearningStateSchemaVersion,
        ),
    ];
  }

  @override
  Future<List<StudentStateSummaryRow>> listStudentStateSummaries(
    SupabaseSession session,
  ) async {
    return [
      for (final row in await listStudentStates(session))
        if (summarizeStudentStateRow(row) != null)
          summarizeStudentStateRow(row)!,
    ];
  }

  @override
  Future<PersistStudentStateResult> persistStudentState(
    PersistStudentStateInput input,
    SupabaseSession session,
  ) async {
    persistCalls += 1;
    states[input.lessonLocalId] = input.state;
    return PersistStudentStateResult.accepted(
      lessonLocalId: input.lessonLocalId,
      highWaterMark: input.clientScore,
      schemaVersion: input.schemaVersion,
    );
  }
}

StudentLearningState _drawerState(String id, String title, int itemIdx) {
  final now = DateTime(2026, 6, 30).millisecondsSinceEpoch + itemIdx;
  return StudentLearningState.empty(lessonLocalId: id, now: now).copyWith(
    profile: StudentProfile(
      objetivo: title,
      stableLang: 'Portuguese',
      academicLevel: 'ensino_medio',
    ),
    curriculum: StudentCurriculum(
      topic: title,
      totalItems: 3,
      generatedAt: now,
      provisional: false,
      items: const [
        CurriculumItem(marker: 'M1', text: 'Item 1'),
        CurriculumItem(marker: 'M2', text: 'Item 2'),
        CurriculumItem(marker: 'M3', text: 'Item 3'),
      ],
    ),
    progress: LessonProgress(
      itemIdx: itemIdx,
      layer: LessonLayer.l1,
      erros: 0,
      amparoLvl: 0,
      historia: const [],
      mainAdvances: itemIdx,
      concluidos: const [],
      pendentesMarkers: const [],
      totalItems: 3,
      pctAvanco: ((itemIdx / 3) * 100).round(),
    ),
    current: LessonCurrent(
      itemIdx: itemIdx,
      marker: 'M$itemIdx',
      layer: LessonLayer.l1,
      amparoLvl: 0,
    ),
  );
}
