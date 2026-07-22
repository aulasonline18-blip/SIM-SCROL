import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/onboarding/onboarding_screens.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/session/entry_form_state.dart';
import 'package:sim_mobile/shared/widgets/shared_widgets.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_attachment_client.dart';
import 'package:sim_mobile/sim/reception/pedagogical_reception_controller.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setSimActiveLanguage('pt-BR');
  });

  testWidgets('primeira acao da tela e objetivo com material auxiliar', (
    tester,
  ) async {
    final session = _session();
    await _pumpObjective(tester, session);

    expect(find.text('O que você quer estudar?'), findsOneWidget);
    expect(find.byKey(const Key('reception-objective-input')), findsOneWidget);
    expect(find.byKey(const Key('reception-material-path')), findsOneWidget);
    expect(find.text('Como vamos começar?'), findsNothing);
    expect(find.text('Etapa 1 de 9'), findsOneWidget);

    final button = tester.widget<PrimaryWideButton>(
      find.byKey(const Key('objective-primary-continue')),
    );
    expect(button.onPressed, isNull);
  });

  test('ficha salva objetivo, materia, topico e learning_goal coerentes', () {
    final session = _session()
      ..freeText = 'Quero aprender frações equivalentes com exemplos'
      ..setPedagogicalEntryField('subject', 'Matemática')
      ..setPedagogicalEntryField('topic', 'Frações equivalentes')
      ..setPedagogicalEntryField('academic_level', 'Ensino fundamental')
      ..setPedagogicalEntryField('traversal_goal', 'Prova');

    expect(session.saveObjectiveEntry(), isTrue);
    final state = session.canonicalStore!.readState(session.lessonLocalId!);
    final ficha = state.profile.extra['pedagogical_entry_ficha'] as Map;

    expect(ficha['objective'], contains('frações'));
    expect(ficha['subject'], 'Matemática');
    expect(ficha['topic'], 'Frações equivalentes');
    expect(ficha['subject_status'], 'informed');
    expect(ficha['topic_status'], 'informed');
    expect(ficha['learning_goal'], 'Frações equivalentes');
  });

  test('learning_goal usa objetivo real quando topico nao foi informado', () {
    final session = _session()
      ..freeText = 'Quero aprender inglês para viagem com situações reais'
      ..setPedagogicalEntryField('academic_level', 'Trabalho')
      ..setPedagogicalEntryField('traversal_goal', 'Aprender sozinho');

    expect(session.saveObjectiveEntry(), isTrue);
    final state = session.canonicalStore!.readState(session.lessonLocalId!);
    final ficha = state.profile.extra['pedagogical_entry_ficha'] as Map;

    expect(ficha['subject_status'], 'not_informed');
    expect(ficha['topic_status'], 'not_informed');
    expect(ficha['learning_goal'], session.freeText);
  });

  testWidgets('locale altera textos visiveis do fluxo objetivo', (
    tester,
  ) async {
    setSimActiveLanguage('en');
    await _pumpObjective(tester, _session());

    expect(find.text('What do you want to study?'), findsOneWidget);
    expect(find.text('Goal, school subject, or topic'), findsOneWidget);
    expect(find.text('I have material'), findsOneWidget);
    expect(find.text('O que você quer estudar?'), findsNothing);
  });

  testWidgets('progresso atualiza no inicio, meio e final', (tester) async {
    final session = _session();
    await _pumpObjective(tester, session);
    expect(find.text('Etapa 1 de 9'), findsOneWidget);

    await _enterObjective(tester, 'Quero aprender porcentagem para prova');
    await _tap(tester, find.text('Salvar e continuar').first);
    expect(find.text('Etapa 2 de 9', skipOffstage: false), findsOneWidget);

    final controller = PedagogicalReceptionController(form: EntryFormState());
    controller.activeIndex = controller.steps.length - 1;
    expect(controller.activeStepNumber, controller.totalStepCount);
    expect(controller.totalStepCount, 9);
  });

  testWidgets('validacao invalida nao avanca e erro fica junto ao campo', (
    tester,
  ) async {
    final session = _session();
    await _pumpObjective(tester, session);
    session.freeText = 'curto';
    await tester.pumpAndSettle();

    final button = tester.widget<PrimaryWideButton>(
      find.byKey(const Key('objective-primary-continue')),
    );
    expect(button.onPressed, isNull);

    final reception = PedagogicalReceptionController(form: session.entryForm);
    expect(reception.validateStep('objective'), t('objective_error_min'));
    expect(reception.errorFor('objective'), t('objective_error_min'));
  });

  testWidgets(
    'teclado move foco e preserva cursor durante notificacao externa',
    (tester) async {
      final session = _session();
      await _pumpObjective(tester, session);
      await _enterObjective(tester, 'Quero aprender porcentagem para prova');

      final subjectField = _textFieldInside(
        const Key('reception-subject-input'),
      );
      await tester.enterText(subjectField, 'Matemática');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      final topicTextField = tester.widget<TextField>(
        _textFieldInside(const Key('reception-topic-input')),
      );
      expect(topicTextField.focusNode!.hasFocus, isTrue);

      final objectiveField = _textFieldInside(
        const Key('reception-objective-input'),
      );
      await tester.tap(objectiveField);
      await tester.pump();
      final editable = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      editable.controller.selection = const TextSelection.collapsed(offset: 8);
      session.setFreeText('Texto externo que nao deve sobrescrever foco');
      await tester.pump();
      expect(editable.controller.selection.baseOffset, 8);
    },
  );

  testWidgets(
    'limite de caracteres e visivel e nao corta texto silenciosamente',
    (tester) async {
      final session = _session();
      await _pumpObjective(tester, session);
      final long = 'a' * (entryFormMaxFreeText + 5);
      await _enterObjective(tester, long);

      expect(session.freeText.length, entryFormMaxFreeText + 5);
      expect(find.text('1505/1500 caracteres'), findsOneWidget);
      expect(find.text(t('objective_error_max')), findsWidgets);
      expect(session.saveObjectiveEntry(), isFalse);
    },
  );

  test(
    'anexos distinguem vazio, curto, suficiente, erro e erro individual',
    () async {
      final form = EntryFormState(
        attachmentClient: SimServerAttachmentClient(
          config: const SimAiServerConfig(baseUrl: 'https://sim.test'),
          transport: _AttachmentTransport({
            'vazio.txt': '',
            'curto.txt': 'curto',
            'ok.txt': 'conteudo pedagogico suficiente para aproveitamento',
            'erro.txt': 'ERROR',
          }),
        ),
      );

      form.addLabAttachmentFile(
        const SimAttachmentFile(
          name: 'vazio.txt',
          contentType: 'text/plain',
          bytes: [1],
        ),
      );
      form.addLabAttachmentFile(
        const SimAttachmentFile(
          name: 'curto.txt',
          contentType: 'text/plain',
          bytes: [1],
        ),
      );
      form.addLabAttachmentFile(
        const SimAttachmentFile(
          name: 'ok.txt',
          contentType: 'text/plain',
          bytes: [1],
        ),
      );
      await _waitAttachments(form);

      expect(form.attachments.map((a) => a.status), [
        'insufficient',
        'insufficient',
        'ready',
      ]);
      expect(form.attachmentError, t('objective_attachment_insufficient'));
      expect(form.buildAttachmentsText(), contains('ok.txt'));
      expect(form.buildAttachmentsText(), isNot(contains('curto.txt')));

      form.removeAttachment(0);
      expect(form.attachmentError, t('objective_attachment_insufficient'));
      form.removeAttachment(0);
      expect(form.attachmentError, isNull);
    },
  );

  test('caminho material exige anexo valido ou descricao explicita', () {
    final session = _session()
      ..freeText = 'Explique a lista de exercícios pelo material enviado'
      ..setPedagogicalEntryField('entry_path', 'material_help')
      ..setPedagogicalEntryField('material_type', 'PDF')
      ..setPedagogicalEntryField('traversal_goal', 'Lista');

    final reception = PedagogicalReceptionController(form: session.entryForm);
    expect(
      reception.validateStep('attachments'),
      t('objective_error_attachment_required'),
    );

    session.setPedagogicalEntryField('material_description_only', 'true');
    expect(reception.validateStep('attachments'), isNull);
    expect(session.saveObjectiveEntry(), isTrue);
  });

  testWidgets('chips oficiais selecionam, trocam selecao e tem semantica', (
    tester,
  ) async {
    final session = _session();
    await _pumpObjective(tester, session);
    await _enterObjective(tester, 'Quero aprender química básica');
    await _tap(tester, find.text('Salvar e continuar').first);

    expect(find.byType(SimChatChoiceChip), findsWidgets);
    await _tap(tester, find.text('Ensino médio'));
    expect(session.academicLevel, 'Ensino médio');
    await _tap(tester, find.text('Faculdade'));
    expect(session.academicLevel, 'Faculdade');
  });

  testWidgets('semantica anuncia progresso, proposito e erro', (tester) async {
    final handle = tester.ensureSemantics();
    final session = _session();
    await _pumpObjective(tester, session);

    expect(find.bySemanticsLabel('O que você quer estudar?'), findsWidgets);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('objective-progress-label')))
          .data,
      'Etapa 1 de 9',
    );

    final reception = PedagogicalReceptionController(form: session.entryForm);
    reception.validateStep('objective');
    await tester.pumpWidget(
      MaterialApp(
        home: Semantics(
          liveRegion: true,
          child: SimChatError(text: reception.errorFor('objective')),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(SimChatError)).label,
      contains('Escreva um pouco mais'),
    );
    handle.dispose();
  });

  testWidgets(
    'campo de idade e numerico opcional e exclusivo com nao declarar',
    (tester) async {
      final session = _session();
      await _pumpObjective(tester, session);
      await _enterObjective(tester, 'Quero aprender biologia celular');
      await _completeGuidedUntilProfile(tester);

      final ageField = _textFieldInside(const Key('objective-age-input'));
      final textField = tester.widget<TextField>(ageField);
      expect(textField.keyboardType, TextInputType.number);
      expect(
        textField.inputFormatters!.whereType<FilteringTextInputFormatter>(),
        isNotEmpty,
      );

      await tester.enterText(ageField, 'abc12');
      expect(session.studentAge, '12');
      await tester.enterText(ageField, '2');
      await _tap(tester, find.text('Continuar sem informar').last);
      expect(find.text(t('objective_error_age_invalid')), findsOneWidget);

      await tester.enterText(ageField, '17');
      await _tap(tester, find.byKey(const Key('objective-age-not-declared')));
      expect(session.ageNotDeclared, isTrue);
      expect(session.studentAge, isEmpty);
      await tester.enterText(ageField, '18');
      expect(session.ageNotDeclared, isFalse);
      expect(session.studentAge, '18');
    },
  );
}

LabSession _session() => LabSession()
  ..authed = true
  ..authReady = true;

Future<void> _pumpObjective(WidgetTester tester, LabSession session) async {
  await tester.pumpWidget(MaterialApp(home: ObjetoScreen(session: session)));
  await tester.pumpAndSettle();
}

Future<void> _enterObjective(WidgetTester tester, String text) async {
  await tester.enterText(
    _textFieldInside(const Key('reception-objective-input')),
    text,
  );
  await tester.pumpAndSettle();
}

Finder _textFieldInside(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(TextField));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _completeGuidedUntilProfile(WidgetTester tester) async {
  await _tap(tester, find.text('Salvar e continuar').first);
  await _tap(tester, find.text('Ensino médio'));
  await _tap(tester, find.text('Salvar e continuar').first);
  await _tap(tester, find.text('Prova'));
  await _tap(tester, find.text('Salvar e continuar').first);
  await _tap(tester, find.text('Sem prazo'));
  await _tap(tester, find.text('Continuar sem informar').last);
  await _tap(tester, find.text('Continuar sem informar').last);
  await _tap(tester, find.text('Continuar sem informar').last);
  await _tap(tester, find.text('Com exemplos'));
  await _tap(tester, find.text('Continuar sem informar').last);
}

Future<void> _waitAttachments(EntryFormState form) async {
  for (var i = 0; i < 20; i++) {
    if (form.attachments.every((a) => a.status != 'processing')) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _AttachmentTransport implements SimHttpTransport {
  _AttachmentTransport(this.textByName);

  final Map<String, String> textByName;

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
    final text = textByName[filename] ?? '';
    return SimHttpResponse(
      statusCode: 200,
      body: jsonEncode({
        'extractedText': text == 'ERROR' ? '' : text,
        'method': 'test',
        'charsExtracted': text == 'ERROR' ? 0 : text.length,
        if (text == 'ERROR') 'error': 'Falha de leitura',
      }),
    );
  }
}
