import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/onboarding/onboarding_screens.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/session/entry_form_state.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_attachment_client.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_design_system.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('caminho guiado salva entrada e pode passar por nivelamento', () async {
    final session = LabSession()
      ..authed = true
      ..authReady = true;
    final before = StudentLearningState.empty(lessonLocalId: 'before');

    session
      ..freeText = 'Quero aprender equações do primeiro grau'
      ..setPedagogicalEntryField('entry_path', 'guided_path')
      ..setPedagogicalEntryField('academic_level', 'Ensino fundamental')
      ..setPedagogicalEntryField('traversal_goal', 'Prova')
      ..setPedagogicalEntryField('deadline', 'Esta semana')
      ..setPedagogicalEntryField('expected_result', 'Resolver problemas')
      ..setPedagogicalEntryField('difficulties', 'Travando em letras')
      ..setPedagogicalEntryField('learning_preference', 'Passo a passo');

    expect(session.saveObjectiveEntry(), isTrue);

    final id = session.lessonLocalId as String;
    final state = session.canonicalStore!.readState(id);
    expect(session.route, '/cyber/placement');
    expect(state.placement, isNull);
    expect(
      state.events.map((event) => event.type),
      contains('ONBOARDING_OBJECTIVE_SAVED_IMMEDIATE'),
    );
    expect(state.profile.extra['entry_path'], 'guided_path');
    expect(state.profile.extra['pedagogical_entry_ficha'], isA<Map>());
    expect(state.current, before.current);
    expect(state.progress, before.progress);
    expect(state.attempts, isEmpty);
    expect(state.truth.toJson(), before.truth.toJson());
  });

  test(
    'caminho com material pula nivelamento e preserva texto extraido',
    () async {
      final session = LabSession()
        ..authed = true
        ..authReady = true;
      session.entryForm.attachments = [
        AttachmentDraft(
          id: 'att-1',
          name: 'lista.pdf',
          type: 'application/pdf',
          size: 1200,
          status: 'ready',
          method: 'pdf-text',
          extractedText: 'Questao 1: resolva 2x + 4 = 10 mostrando os passos.',
        ),
      ];
      session
        ..freeText = 'Explique essa lista e monte uma aula pelo exercicio'
        ..setPedagogicalEntryField('entry_path', 'material_help')
        ..setPedagogicalEntryField('material_type', 'PDF')
        ..setPedagogicalEntryField('traversal_goal', 'Lista');

      expect(session.saveObjectiveEntry(), isTrue);

      final id = session.lessonLocalId as String;
      final state = session.canonicalStore!.readState(id);
      expect(session.route, '/cyber/curriculo');
      expect(state.placement?['status'], 'skipped');
      expect(state.placement?['choice'], 'material_based');
      expect(
        state.events.map((event) => event.type),
        contains('ONBOARDING_OBJECTIVE_SAVED_IMMEDIATE'),
      );
      expect(state.profile.extra['material_based'], isTrue);
      expect(state.profile.extra['attachments_text'], contains('Questao 1'));
      expect(
        state.profile.extra['student_profile_notes'],
        contains('Explique essa lista'),
      );
      expect(
        state.profile.extra['student_profile_notes'],
        contains('Questao 1'),
      );
      expect(jsonEncode(state.toJson()), isNot(contains('data:')));
    },
  );

  test(
    'anexos processam arquivo, foto, imagem e texto sem blob no estado',
    () async {
      final form = EntryFormState(
        attachmentClient: SimServerAttachmentClient(
          config: const SimAiServerConfig(baseUrl: 'https://sim.test'),
          transport: _AttachmentTransport(),
        ),
      );

      for (final file in const [
        SimAttachmentFile(
          name: 'a.pdf',
          contentType: 'application/pdf',
          bytes: [1, 2, 3],
        ),
        SimAttachmentFile(
          name: 'foto.jpg',
          contentType: 'image/jpeg',
          bytes: [4, 5, 6],
        ),
        SimAttachmentFile(
          name: 'imagem.png',
          contentType: 'image/png',
          bytes: [7, 8, 9],
        ),
      ]) {
        form.addLabAttachmentFile(file);
      }
      await _waitAttachments(form);

      expect(form.attachments, hasLength(3));
      expect(form.attachments.every((a) => a.status == 'ready'), isTrue);
      expect(form.buildAttachmentsText(), contains('Texto extraido de a.pdf'));
      expect(
        jsonEncode(form.attachments.map((a) => a.name).toList()),
        isNot(contains('base64')),
      );

      final textForm = EntryFormState(
        attachmentClient: SimServerAttachmentClient(
          config: const SimAiServerConfig(baseUrl: 'https://sim.test'),
          transport: _AttachmentTransport(),
        ),
      );
      textForm.addLabAttachmentFile(
        const SimAttachmentFile(
          name: 'notas.txt',
          contentType: 'text/plain',
          bytes: [65, 66, 67],
        ),
      );
      await _waitAttachments(textForm);
      expect(
        textForm.buildAttachmentsText(),
        contains('Texto extraido de notas.txt'),
      );
    },
  );

  test('anexos respeitam limite, tamanho e bloqueiam audio/video', () {
    final form = EntryFormState();
    form.addLabAttachmentFile(
      const SimAttachmentFile(
        name: 'audio.mp3',
        contentType: 'audio/mpeg',
        bytes: [1],
      ),
    );
    expect(form.attachments, isEmpty);
    expect(form.attachmentError, entryFormAudioNotSupportedMessage);

    form.addLabAttachmentFile(
      const SimAttachmentFile(
        name: 'video.mp4',
        contentType: 'video/mp4',
        bytes: [1],
      ),
    );
    expect(form.attachments, isEmpty);
    expect(form.attachmentError, entryFormVideoNotSupportedMessage);

    form.addLabAttachmentFile(
      SimAttachmentFile(
        name: 'grande.pdf',
        contentType: 'application/pdf',
        bytes: List<int>.filled(entryFormMaxAttachmentBytes + 1, 1),
      ),
    );
    expect(form.attachments, isEmpty);
    expect(form.attachmentError, contains('10 MB'));

    form.attachments = [
      for (var i = 0; i < 3; i++)
        AttachmentDraft(
          id: 'a$i',
          name: 'a$i.txt',
          type: 'text/plain',
          size: 10,
          status: 'ready',
          extractedText: 'texto suficiente para o anexo $i',
        ),
    ];
    form.addLabAttachmentFile(
      const SimAttachmentFile(
        name: 'extra.txt',
        contentType: 'text/plain',
        bytes: [1],
      ),
    );
    expect(form.attachments, hasLength(3));
    expect(form.attachmentError, contains('3 anexos'));
  });

  test(
    'anexo processando bloqueia, anexo ilegivel permite texto suficiente',
    () {
      final session = LabSession()
        ..authed = true
        ..authReady = true;
      session
        ..freeText = 'Explique este exercicio pelo texto que descrevi'
        ..setPedagogicalEntryField('entry_path', 'material_help')
        ..setPedagogicalEntryField('material_type', 'Foto do caderno')
        ..setPedagogicalEntryField('traversal_goal', 'Tarefa');

      session.entryForm.attachments = [
        AttachmentDraft(
          id: 'p',
          name: 'foto.jpg',
          type: 'image/jpeg',
          size: 10,
          status: 'processing',
        ),
      ];
      expect(session.saveObjectiveEntry(), isFalse);

      session.entryForm.attachments = [
        AttachmentDraft(
          id: 'e',
          name: 'foto.jpg',
          type: 'image/jpeg',
          size: 10,
          status: 'error',
          error: 'Não consegui ler bem. Você pode descrever com texto.',
        ),
      ];
      session.setPedagogicalEntryField('material_description_only', 'true');
      expect(session.saveObjectiveEntry(), isTrue);
    },
  );

  testWidgets('timeline progressiva tem erro claro, scroll e layout mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = LabSession()
      ..authed = true
      ..authReady = true;

    await tester.pumpWidget(MaterialApp(home: ObjetoScreen(session: session)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('O que você quer estudar?'), findsOneWidget);
    expect(find.byKey(const Key('reception-objective-input')), findsOneWidget);
    expect(find.byKey(const Key('reception-guided-path')), findsOneWidget);
    expect(find.byKey(const Key('reception-material-path')), findsOneWidget);
    expect(find.text('Algum cuidado para adaptar a aula?'), findsNothing);
    expect(find.text('Foi isso que eu entendi.'), findsNothing);

    await _tapVisible(tester, find.text('Salvar e continuar').first);
    expect(find.text('Qual nível ou contexto devo considerar?'), findsNothing);

    await tester.enterText(
      find.byType(TextField).first,
      'Quero aprender porcentagem',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(const Key('objective-primary-continue')),
    );
    expect(find.text('Qual nível ou contexto devo considerar?'), findsWidgets);
    expect(
      find.byKey(const Key('reception-answer-objective'), skipOffstage: false),
      findsOneWidget,
    );
    final list = tester.widget<ListView>(
      find.byKey(const Key('pedagogical-reception-scroll')),
    );
    expect(list.controller?.hasClients, isTrue);

    await _tapVisible(
      tester,
      find.byKey(const Key('reception-edit-answer'), skipOffstage: false).last,
    );
    expect(find.byKey(const Key('reception-active-objective')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resumo final confirma entendimento e edicao preserva dados', (
    tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true;

    await tester.pumpWidget(MaterialApp(home: ObjetoScreen(session: session)));
    await tester.pumpAndSettle();

    await _finishGuidedReception(tester);

    expect(find.byKey(const Key('reception-final-summary')), findsOneWidget);
    expect(
      find.textContaining('Vou montar um caminho e encontrar o ponto certo'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Objetivo: Quero aprender porcentagem para prova'),
      findsOneWidget,
    );
    expect(find.textContaining('Contexto: Ensino médio'), findsOneWidget);
    expect(find.textContaining('Uso: Prova'), findsOneWidget);
    expect(find.text('Preparar minha aula'), findsOneWidget);

    final editButton = tester.widget<SimTextAction>(
      find.byKey(const Key('reception-edit-answer'), skipOffstage: false).first,
    );
    editButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reception-final-summary')), findsNothing);
    expect(find.text('Preparar minha aula'), findsNothing);
    expect(session.academicLevel, 'Ensino médio');
    expect(session.traversalGoal, 'Prova');
    expect(session.freeText, 'Quero aprender porcentagem para prova');
  });

  testWidgets('material aparece como item da conversa e pula nivelamento', (
    tester,
  ) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true;
    session.entryForm.attachments = [
      AttachmentDraft(
        id: 'att-ui',
        name: 'lista.pdf',
        type: 'application/pdf',
        size: 1200,
        status: 'ready',
        method: 'pdf-text',
        extractedText: 'Questao 1: resolva 2x + 4 = 10 mostrando os passos.',
      ),
    ];

    await tester.pumpWidget(MaterialApp(home: ObjetoScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'Explique esta lista e monte uma aula curta pelo material.',
    );
    await _tapVisible(tester, find.byKey(const Key('reception-material-path')));
    await _tapVisible(tester, find.text('Salvar e continuar').first);
    expect(find.text('Que tipo de material você trouxe?'), findsWidgets);
    await _tapVisible(tester, find.text('PDF'));
    await _tapVisible(tester, find.text('Salvar e continuar').first);

    expect(find.text('Material de apoio'), findsOneWidget);
    expect(find.text('lista.pdf'), findsOneWidget);
    expect(find.text('Conteúdo aproveitável.'), findsWidgets);
    expect(find.text('ready'), findsNothing);

    session
      ..freeText = 'Explique esta lista e monte uma aula curta pelo material.'
      ..setPedagogicalEntryField('traversal_goal', 'Lista');
    expect(session.saveObjectiveEntry(), isTrue);
    expect(session.route, '/cyber/curriculo');
    final state = session.canonicalStore!.readState(session.lessonLocalId!);
    expect(state.placement?['choice'], 'material_based');
    expect(state.profile.extra['attachments_text'], contains('Questao 1'));
    expect(jsonEncode(state.toJson()), isNot(contains('base64')));
  });

  testWidgets('recepcao nao mostra termos tecnicos ao aluno', (tester) async {
    final session = LabSession()
      ..authed = true
      ..authReady = true;

    await tester.pumpWidget(MaterialApp(home: ObjetoScreen(session: session)));
    await tester.pumpAndSettle();
    for (final term in const [
      'T00',
      'T02',
      'JSON',
      'placement',
      'API',
      'state',
      'attempts',
      'payload',
    ]) {
      expect(find.textContaining(term), findsNothing, reason: term);
    }
  });

  test('UI de recepcao nao chama T00/T02 ou rotas legadas diretamente', () {
    final text = File(
      'lib/features/onboarding/onboarding_screens.dart',
    ).readAsStringSync();

    expect(text, isNot(contains('T00')));
    expect(text, isNot(contains('T02')));
    expect(text, isNot(contains('/api/placement')));
    expect(text, isNot(contains('/api/recovery')));
  });
}

class _AttachmentTransport implements SimHttpTransport {
  @override
  Future<SimHttpResponse> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    throw UnimplementedError();
  }

  @override
  Stream<String> postEventStream(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 90),
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SimHttpResponse> postMultipart(
    Uri uri, {
    required Map<String, String> headers,
    required String fieldName,
    required String filename,
    required String contentType,
    required List<int> bytes,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    return SimHttpResponse(
      statusCode: 200,
      body: jsonEncode({
        'extractedText':
            'Texto extraido de $filename com conteudo pedagogico suficiente.',
        'method': contentType == 'application/pdf' ? 'pdf-text' : 'vision',
        'charsExtracted': 64,
      }),
    );
  }
}

Future<void> _waitAttachments(EntryFormState form) async {
  for (var i = 0; i < 20; i++) {
    if (form.attachments.every((a) => a.status != 'processing')) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _finishGuidedReception(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextField).first,
    'Quero aprender porcentagem para prova',
  );
  await _tapVisible(tester, find.text('Salvar e continuar').first);

  await _tapVisible(tester, find.text('Ensino médio'));
  await _tapVisible(tester, find.text('Salvar e continuar').first);

  await _tapVisible(tester, find.text('Prova'));
  await _tapVisible(tester, find.text('Salvar e continuar').first);

  await _tapVisible(tester, find.text('Sem prazo'));
  await _tapVisible(tester, find.text('Continuar sem informar').last);

  await tester.enterText(
    find.byType(TextField).first,
    'Resolver questões sem depender de fórmula decorada',
  );
  await _tapVisible(tester, find.text('Continuar sem informar').last);

  await tester.enterText(find.byType(TextField).first, 'Regra de três');
  await _tapVisible(tester, find.text('Continuar sem informar').last);

  await _tapVisible(tester, find.text('Com exemplos'));
  await _tapVisible(tester, find.text('Continuar sem informar').last);

  await _tapVisible(tester, find.text('Continuar sem informar').last);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  tester.testTextInput.hide();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
