import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/aula_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/classroom/aula_screen.dart';
import 'package:sim_mobile/main.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/classroom_text_scale.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

LabSession _readyAulaSession() {
  final session = LabSession()
    ..authed = true
    ..authReady = true
    ..credits = 3
    ..selectedLanguageCode = 'pt'
    ..stableLang = 'Portuguese'
    ..freeText = 'Fracoes equivalentes com enunciado longo para testar tela.';
  expect(session.saveObjectiveEntry(), isTrue);
  session.route = '/cyber/aula';
  return session;
}

Future<LabSession> _pumpAula(WidgetTester tester) async {
  final session = _readyAulaSession();
  await tester.pumpWidget(SimMobileApp(initialSession: session));
  await session.openAulaRuntime();
  await tester.pumpAndSettle();
  return session;
}

void main() {
  testWidgets('aula font control has five levels and persists choice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 720));

    await _pumpAula(tester);

    expect(find.byKey(const Key('aula-font-scale-button')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('aula-font-scale-button')),
        matching: find.text('2/5'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('aula-font-scale-button')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('aula-font-scale-button')),
        matching: find.text('3/5'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('aula-font-scale-button')));
    await tester.tap(find.byKey(const Key('aula-font-scale-button')));
    await tester.tap(find.byKey(const Key('aula-font-scale-button')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 260));
    expect(
      find.descendant(
        of: find.byKey(const Key('aula-font-scale-button')),
        matching: find.text('1/5'),
      ),
      findsOneWidget,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(ClassroomTextScale.prefsKey), 1);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('aula exposes semantics for main classroom actions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(390, 720));

    await _pumpAula(tester);

    expect(find.bySemanticsLabel('Abrir menu da aula'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Tocar áudio da aula').evaluate().length +
          find.bySemanticsLabel('Preparando áudio da aula').evaluate().length +
          find.bySemanticsLabel('Parar áudio da aula').evaluate().length,
      1,
    );
    expect(find.bySemanticsLabel('Abrir revisão'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Tamanho da letra: nível 2 de 5'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Alternativa B'), findsOneWidget);

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Sinal 2: Revisar'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
    semantics.dispose();
  });

  testWidgets('aula renderiza enunciado antes de liberar alternativas', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final session = _readyAulaSession();
    await tester.pumpWidget(SimMobileApp(initialSession: session));
    await session.openAulaRuntime();
    await tester.pump();

    expect(find.bySemanticsLabel('Alternativa B'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Alternativa B'), findsOneWidget);
  });

  testWidgets('aula reserva lugar e mostra imagem pronta da lesson', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final svg = Uri.encodeComponent(
      '<svg viewBox="0 0 120 80"><rect width="120" height="80" fill="#eef2ff"/>'
      '<path d="M10 60 Q60 10 110 60" stroke="#111827" fill="none" stroke-width="4"/>'
      '</svg>',
    );
    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'Portuguese'
      ..route = '/cyber/aula'
      ..aulaSnapshot = LessonRuntimeSnapshot(
        authReady: true,
        authed: true,
        hasCurriculum: true,
        isDone: false,
        viewModel: const LessonMainViewModel(
          progress: 0.25,
          headerLabel: 'aula_item_of:1/1:aula_layer_1',
          options: [],
          locked: false,
          nextLabel: '',
        ),
        phase: const ClassroomPhase.reading(),
        history: const [],
        conteudo: const LessonContent(
          explanation: 'Observe o desenho da curva antes de responder.',
          question: 'Qual curva representa o crescimento?',
          options: {
            AnswerLetter.A: 'Linha reta',
            AnswerLetter.B: 'Curva',
            AnswerLetter.C: 'Ponto isolado',
          },
          correctAnswer: AnswerLetter.B,
          visualTrigger: {
            'needs_image': true,
            'render_strategy': 'software',
            'visual_type': 'graph',
            'topic': 'curva de crescimento',
            'highlight_focus': 'curva principal',
          },
        ),
        imagem: null,
        itemMarker: 'M1',
        itemText: 'Funções',
      );

    await tester.pumpWidget(MaterialApp(home: AulaLabScreen(session: session)));
    await tester.pumpAndSettle();

    expect(
      find.text('Observe o desenho da curva antes de responder.'),
      findsOneWidget,
    );

    session.aulaSnapshot = session.aulaSnapshot!.copyWith(
      imagem: 'data:image/svg+xml;utf8,$svg',
    );
    session.notifyListeners();
    await tester.pumpAndSettle();

    expect(find.byType(LessonImageStudySurface), findsOneWidget);
    expect(find.byTooltip('Ampliar imagem'), findsOneWidget);
    expect(find.text('curva principal'), findsOneWidget);
    final imageRect = tester.getRect(find.byType(LessonImageStudySurface));
    expect(imageRect.top, greaterThanOrEqualTo(0));
    expect(imageRect.bottom, lessThanOrEqualTo(720));
  });

  testWidgets(
    'bolha de áudio aparece só com audioPlaying real e tem semantics',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(390, 720));

      final session = await _pumpAula(tester);
      expect(find.bySemanticsLabel('Áudio da aula tocando'), findsNothing);

      session.audioEnabled = true;
      session.audioPlaying = true;
      session.notifyListeners();
      await tester.pump();

      expect(find.bySemanticsLabel('Áudio da aula tocando'), findsOneWidget);

      session.stopActiveAudio();
      await tester.pump();

      expect(find.bySemanticsLabel('Áudio da aula tocando'), findsNothing);

      await tester.binding.setSurfaceSize(null);
      semantics.dispose();
    },
  );

  testWidgets('sinais abrem como gaveta logo abaixo da alternativa ativa', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(390, 760));

    await _pumpAula(tester);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();

    final selectedRect = tester.getRect(find.bySemanticsLabel('Alternativa B'));
    final signalRect = tester.getRect(
      find.bySemanticsLabel('Sinal 2: Revisar'),
    );
    final nextOptionRect = tester.getRect(
      find.bySemanticsLabel('Alternativa C'),
    );

    expect(signalRect.top, greaterThanOrEqualTo(selectedRect.bottom - 1));
    expect(signalRect.bottom, lessThanOrEqualTo(nextOptionRect.top + 1));

    await tester.binding.setSurfaceSize(null);
    semantics.dispose();
  });

  testWidgets(
    'zoom alto mantém sinais feedback e avançar visíveis em tela pequena',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        ClassroomTextScale.prefsKey: ClassroomTextScale.maxLevel,
      });
      await tester.binding.setSurfaceSize(const Size(360, 560));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAula(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('aula-font-scale-button')),
          matching: find.text('5/5'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      final signalRect = tester.getRect(find.text('2'));
      expect(signalRect.top, greaterThanOrEqualTo(0));
      expect(signalRect.bottom, lessThanOrEqualTo(560));

      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      final feedbackRect = tester.getRect(
        find.text('Exato! Você domina este ponto.'),
      );
      expect(feedbackRect.top, greaterThanOrEqualTo(0));
      expect(feedbackRect.bottom, lessThanOrEqualTo(560));
      final nextRect = tester.getRect(find.textContaining('>>').last);
      expect(nextRect.top, greaterThanOrEqualTo(0));
      expect(nextRect.bottom, lessThanOrEqualTo(560));

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('usuario consegue rolar de volta para reler a teoria', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ClassroomTextScale.prefsKey: ClassroomTextScale.maxLevel,
    });
    await tester.binding.setSurfaceSize(const Size(360, 560));

    await _pumpAula(tester);
    final listView = tester.widget<ListView>(
      find.byKey(const Key('aula-scroll-view')),
    );
    final controller = listView.controller!;
    expect(controller.hasClients, isTrue);

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    final before = controller.offset;
    expect(before, greaterThan(0));

    await tester.drag(
      find.byKey(const Key('aula-scroll-view')),
      const Offset(0, 320),
    );
    await tester.pump();
    final afterDrag = controller.offset;
    expect(afterDrag, lessThan(before));

    await tester.pump(const Duration(milliseconds: 700));
    expect(controller.offset, closeTo(afterDrag, 1));

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'atualizacao passiva nao rouba scroll e oferece voltar ao ponto atual',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        ClassroomTextScale.prefsKey: ClassroomTextScale.maxLevel,
      });
      await tester.binding.setSurfaceSize(const Size(360, 560));

      final session = await _pumpAula(tester);
      final listView = tester.widget<ListView>(
        find.byKey(const Key('aula-scroll-view')),
      );
      final controller = listView.controller!;

      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('aula-scroll-view')),
        const Offset(0, 320),
      );
      await tester.pump();
      final afterManualRead = controller.offset;

      session.aulaSnapshot = session.aulaSnapshot!.copyWith(
        phase: const ClassroomPhase.completed(
          message: 'aula_fb_correct',
          wasCorrect: true,
          signal: DecisionSignal.two,
        ),
      );
      session.notifyListeners();
      await tester.pumpAndSettle();

      expect(controller.offset, closeTo(afterManualRead, 1));
      expect(
        find.byKey(const Key('aula-scroll-current-button')),
        findsOneWidget,
      );
      expect(find.text('Ver feedback'), findsOneWidget);

      await tester.tap(find.byKey(const Key('aula-scroll-current-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('aula-scroll-current-button')), findsNothing);
      expect(controller.offset, greaterThan(afterManualRead));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('tablet largo usa trilho lateral sem duplicar botão de fonte', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 820);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpAula(tester);

    expect(find.byKey(const Key('aula-study-rail')), findsOneWidget);
    expect(find.byKey(const Key('aula-font-scale-button')), findsOneWidget);

    tester.view.physicalSize = const Size(390, 720);
    await tester.pumpWidget(Container());
    SharedPreferences.setMockInitialValues({});
    await _pumpAula(tester);

    expect(find.byKey(const Key('aula-study-rail')), findsNothing);
    expect(find.byKey(const Key('aula-font-scale-button')), findsOneWidget);
  });
}
