import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sim_mobile/features/classroom/aula_widgets.dart';
import 'package:sim_mobile/features/classroom/visual_webview_renderer.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_attachment_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/main.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/support/sim_finish_contract.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';
import 'package:sim_mobile/sim/ui/widgets/sim_typewriter.dart';

class FakeAttachmentTransport implements SimHttpTransport {
  int calls = 0;
  String? lastFilename;
  String? lastContentType;
  List<int>? lastBytes;

  @override
  Future<SimHttpResponse> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 45),
  }) async => const SimHttpResponse(statusCode: 200, body: '{}');

  @override
  Stream<String> postEventStream(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 140),
  }) async* {}

  @override
  Future<SimHttpResponse> postMultipart(
    Uri uri, {
    required Map<String, String> headers,
    required String fieldName,
    required String filename,
    required String contentType,
    required List<int> bytes,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    calls += 1;
    lastFilename = filename;
    lastContentType = contentType;
    lastBytes = bytes;
    return const SimHttpResponse(
      statusCode: 200,
      body:
          '{"extractedText":"texto real extraido pelo servidor","method":"vision","charsExtracted":32}',
    );
  }
}

void main() {
  setUp(() {
    debugUseVisualWebViewPlaceholder = false;
  });

  tearDown(() {
    debugUseVisualWebViewPlaceholder = false;
  });

  test('acabamento cobre todos os itens mandatarios', () {
    expect(simFinishIsComplete(), true);
    expect(simFinishRequirements.length, SimFinishArea.values.length);
    expect(
      simFinishRequirements.map((r) => r.label).join('\n'),
      contains('Audio com estado visivel'),
    );
    expect(
      simFinishRequirements.map((r) => r.label).join('\n'),
      contains('Imagem com estado visivel'),
    );
  });

  testWidgets('objetivo processa anexo pelo client real sem texto fixo', (
    WidgetTester tester,
  ) async {
    final transport = FakeAttachmentTransport();
    final session =
        LabSession(
            attachmentClient: SimServerAttachmentClient(
              config: const SimAiServerConfig(baseUrl: 'https://sim.test'),
              transport: transport,
            ),
          )
          ..authed = true
          ..authReady = true
          ..credits = 3
          ..route = '/cyber/objeto';

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    session.addLabAttachment('gallery');
    expect(session.attachments.single.status, 'processing');
    await tester.pumpAndSettle();

    expect(transport.calls, 1);
    expect(session.attachments.single.status, 'ready');
    expect(
      session.attachments.single.extractedText,
      'texto real extraido pelo servidor',
    );
    expect(session.attachments.single.extractedText, isNot(contains('MOCK')));
  });

  testWidgets('objetivo envia bytes reais de anexo selecionado', (
    WidgetTester tester,
  ) async {
    final transport = FakeAttachmentTransport();
    final session =
        LabSession(
            attachmentClient: SimServerAttachmentClient(
              config: const SimAiServerConfig(baseUrl: 'https://sim.test'),
              transport: transport,
            ),
          )
          ..authed = true
          ..authReady = true
          ..credits = 3
          ..route = '/cyber/objeto';

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    session.entryForm.addLabAttachmentFile(
      const SimAttachmentFile(
        name: 'prova.pdf',
        contentType: 'application/pdf',
        bytes: [37, 80, 68, 70, 45, 49, 46, 52],
      ),
    );
    await tester.pumpAndSettle();

    expect(transport.calls, 1);
    expect(transport.lastFilename, 'prova.pdf');
    expect(transport.lastContentType, 'application/pdf');
    expect(transport.lastBytes, [37, 80, 68, 70, 45, 49, 46, 52]);
    expect(session.attachments.single.size, 8);
  });

  testWidgets('texto typewriter da teoria obedece ao zoom da aula', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SimTypewriter(
              text: 'Teoria escalada',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    expect(richText.textScaler.scale(16), closeTo(28.8, 0.01));
  });

  testWidgets('typewriter usa velocidade configuravel mais rapida', (
    WidgetTester tester,
  ) async {
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: SimTypewriter(
            text: 'abcdef',
            style: const TextStyle(fontSize: 16),
            charactersPerTick: 3,
            tickDuration: const Duration(milliseconds: 20),
            onDone: () => done++,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 21));
    var richText = tester.widget<RichText>(find.byType(RichText));
    expect(richText.text.toPlainText(includePlaceholders: false), 'abc');

    await tester.pump(const Duration(milliseconds: 21));
    richText = tester.widget<RichText>(find.byType(RichText));
    expect(richText.text.toPlainText(includePlaceholders: false), 'abcdef');
    expect(done, 1);
  });

  testWidgets('aula mostra imagem audio feedback loading e erro visual', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..credits = 3
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'Portuguese'
      ..freeText = 'Fracoes equivalentes explicadas com exemplos simples.';
    expect(session.saveObjectiveEntry(), isTrue);
    session.route = '/cyber/aula';
    await session.launchExperience();
    await session.openAulaRuntime();

    await tester.pumpWidget(SimMobileApp(initialSession: session));
    expect(find.text('Imagem da aula'), findsNothing);
    expect(find.text('Audio da aula ligado'), findsNothing);
    expect(find.text('Gerar imagem'), findsNothing);

    await tester.tap(find.bySemanticsLabel(t('aula_audio_play')));
    await tester.pump();
    expect(find.text('Audio da aula ligado'), findsNothing);
    await tester.pumpAndSettle();

    final optionB = find.text('B');
    await tester.ensureVisible(optionB);
    await tester.tap(optionB);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('painel nao inventa oferta paga sem oferta real', (tester) async {
    final session = LabSession()
      ..aulaSnapshot = const LessonRuntimeSnapshot(
        authReady: true,
        authed: true,
        hasCurriculum: true,
        isDone: false,
        viewModel: LessonMainViewModel(
          progress: 0,
          headerLabel: 'aula_item_of:1/1:aula_layer_1',
          options: [],
          locked: false,
          nextLabel: '',
        ),
        phase: ClassroomPhase.reading(),
        history: [],
        conteudo: LessonContent(
          explanation: 'Explicacao',
          question: 'Pergunta?',
          options: {
            AnswerLetter.A: 'A',
            AnswerLetter.B: 'B',
            AnswerLetter.C: 'C',
          },
          correctAnswer: AnswerLetter.A,
        ),
        imagem: null,
        itemMarker: 'M1',
        itemText: 'Sistema circulatório',
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LessonImagePanel(session: session)),
      ),
    );

    expect(
      find.text(
        'Esta parte da aula tem uma imagem criada por inteligência artificial.',
      ),
      findsNothing,
    );
    expect(
      find.text('Custa 10 créditos. Seu saldo: 0 créditos.'),
      findsNothing,
    );
    expect(find.text('Comprar créditos'), findsNothing);
    expect(find.text('Continuar sem imagem'), findsNothing);

    session.credits = 10;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LessonImagePanel(session: session)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pular'), findsNothing);
    expect(find.text('Ver imagem (10 créditos)'), findsNothing);
  });

  testWidgets('painel de imagem pronta fica compacto e notifica scroll', (
    tester,
  ) async {
    var settled = 0;
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lK3QMgAAAABJRU5ErkJggg==';
    final session = LabSession()
      ..aulaSnapshot = LessonRuntimeSnapshot(
        authReady: true,
        authed: true,
        hasCurriculum: true,
        isDone: false,
        viewModel: const LessonMainViewModel(
          progress: 0,
          headerLabel: 'aula_item_of:1/1:aula_layer_1',
          options: [],
          locked: false,
          nextLabel: '',
        ),
        phase: ClassroomPhase.reading(),
        history: const [],
        conteudo: const LessonContent(
          explanation: 'Explicacao',
          question: 'Pergunta?',
          options: {
            AnswerLetter.A: 'A',
            AnswerLetter.B: 'B',
            AnswerLetter.C: 'C',
          },
          correctAnswer: AnswerLetter.A,
        ),
        imagem: 'data:image/png;base64,$png',
        itemMarker: 'M1',
        itemText: 'Sistema circulatório',
      );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 260,
            child: LessonImagePanel(
              session: session,
              onImageSettled: () => settled++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Imagem da aula pronta'), findsNothing);
    expect(find.byType(LessonImageStudySurface), findsOneWidget);
    expect(find.text('Apoio visual da aula'), findsOneWidget);
    expect(find.byTooltip(t('aula_image_expand')), findsOneWidget);
    expect(settled, 1);
  });

  testWidgets('imagem pronta abre inspeção com zoom e fecha', (tester) async {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lK3QMgAAAABJRU5ErkJggg==';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonImageStudySurface(
            data: 'data:image/png;base64,$png',
            width: 320,
            height: 180,
            caption: 'parábola com eixo e intercepto',
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip(t('aula_image_expand')));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text(t('aula_image_alt')), findsOneWidget);
    expect(find.text('parábola com eixo e intercepto'), findsWidgets);

    await tester.tap(find.byTooltip(t('aula_image_close')));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsNothing);
  });

  test('LessonImageStudySurface does not use BoxFit.cover as fake fix', () {
    final source = File(
      'lib/features/classroom/aula_widgets.dart',
    ).readAsStringSync();
    final lessonImageSurface = RegExp(
      r'class LessonImageStudySurface[\s\S]*?class LessonMediaImageView',
    ).firstMatch(source)?.group(0);
    final mediaImageView = RegExp(
      r'class LessonMediaImageView[\s\S]*?class ',
    ).firstMatch(source)?.group(0);

    expect(lessonImageSurface, isNotNull);
    expect(mediaImageView, isNotNull);
    expect(lessonImageSurface, isNot(contains('BoxFit.cover')));
    expect(mediaImageView, isNot(contains('BoxFit.cover')));
    expect(source, contains('fit: BoxFit.contain'));
  });

  testWidgets('imagem inválida mostra erro compacto sem quebrar a aula', (
    tester,
  ) async {
    var settled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonMediaImageView(
            data: 'data:image/png;bad',
            onImageSettled: () => settled++,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(t('aula_image_unavailable_short')), findsOneWidget);
    expect(settled, 1);
  });

  testWidgets('SVG seguro usa renderizador WebView no apoio visual', (
    tester,
  ) async {
    debugUseVisualWebViewPlaceholder = true;
    var settled = 0;
    final svg = Uri.encodeComponent(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 1200"><title>Apoio visual</title><desc>Diagrama seguro</desc><rect x="80" y="80" width="740" height="1040" fill="#fff"/><text x="450" y="180" text-anchor="middle">Diagrama</text></svg>',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 320,
            child: LessonMediaImageView(
              data: 'data:image/svg+xml;utf8,$svg',
              onImageSettled: () => settled++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(VisualWebViewRenderer), findsOneWidget);
    expect(find.byKey(const Key('visual-webview-placeholder')), findsOneWidget);
    expect(find.text(t('aula_image_unavailable_short')), findsNothing);
    expect(settled, 1);
  });

  testWidgets('SVG inseguro e bloqueado antes da WebView', (tester) async {
    debugUseVisualWebViewPlaceholder = true;
    var settled = 0;
    final svg = Uri.encodeComponent(
      '<svg xmlns="http://www.w3.org/2000/svg" onload="alert(1)"><script>alert(1)</script><rect width="10" height="10"/></svg>',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonMediaImageView(
            data: 'data:image/svg+xml;utf8,$svg',
            onImageSettled: () => settled++,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(VisualWebViewRenderer), findsNothing);
    expect(find.text(t('aula_image_unavailable_short')), findsOneWidget);
    expect(settled, 1);
  });

  testWidgets('renderizador de imagem aceita dataUrl bitmap no histórico', (
    tester,
  ) async {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lK3QMgAAAABJRU5ErkJggg==';
    var settled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 80,
            child: LessonMediaImageView(
              data: 'data:image/png;base64,$png',
              compact: true,
              onImageSettled: () => settled++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('renderizador exibe raster bitmap do servidor em viewport móvel', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 820));
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lK3QMgAAAABJRU5ErkJggg==';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 330,
              child: LessonImageStudySurface(
                data: 'data:image/png;base64,$png',
                width: 320,
                height: 220,
                caption: 'Imagem rasterizada pelo servidor',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.byType(LessonImageStudySurface), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    expect(provider, isA<MemoryImage>());
    expect((provider as MemoryImage).bytes, base64Decode(png));
    expect(find.text('Imagem rasterizada pelo servidor'), findsOneWidget);
    expect(find.text(t('aula_image_unavailable_short')), findsNothing);
  });
}
