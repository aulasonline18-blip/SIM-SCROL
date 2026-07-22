import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/aula_widgets.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_timeline_builder.dart';
import 'package:sim_mobile/features/classroom/chat_aula_widgets.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  setUp(() => setSimActiveLanguage('pt-BR'));

  testWidgets('LessonVisualBoard renderiza imagem 3:4 e abre zoom/pan', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonVisualBoard(
            data: _tinyPngDataUrl,
            caption: 'Diagrama curto da aula',
          ),
        ),
      ),
    );
    await tester.pump();

    final aspect = tester.widget<AspectRatio>(find.byType(AspectRatio).first);
    expect(aspect.aspectRatio, lessonImageStudyAspectRatio);
    expect(find.byTooltip(t('aula_image_expand')), findsOneWidget);

    await tester.tap(find.byTooltip(t('aula_image_expand')));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byTooltip(t('aula_image_close')));
    await tester.pumpAndSettle();
  });

  testWidgets('comparison e table renderizam com destaque tocavel', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonVisualBoard(
            data:
                '<svg viewBox="0 0 600 800"><text>Comparacao entre ideias versus exemplos</text></svg>',
            caption: 'Comparação visual da aula',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Quadro de comparação'), findsOneWidget);
    await tester.tap(find.byType(LessonVisualBoard));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonVisualBoard(
            data:
                '<svg viewBox="0 0 600 800"><text>Tabela linha coluna termo exemplo</text></svg>',
            caption: 'Tabela da aula',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Quadro em tabela'), findsOneWidget);
    await tester.tap(find.byType(LessonVisualBoard));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('step_by_step permite avancar e recuar passos localmente', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonVisualBoard(
            data:
                '<svg viewBox="0 0 600 800"><text>Passo 1 passo 2 passo 3 passo 4</text></svg>',
            caption: 'Sequência visual da aula',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Quadro passo a passo'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'concept_map simples renderiza nos legiveis e descricao acessivel',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LessonVisualBoard(
              data:
                  '<svg viewBox="0 0 600 800"><text>Mapa conceitual energia seres vivos ambiente</text></svg>',
              caption: 'Mapa conceitual da aula',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Mapa de ideias'), findsOneWidget);
      expect(find.byTooltip('Descrição do quadro visual'), findsOneWidget);
      await tester.tap(find.byTooltip('Descrição do quadro visual'));
      await tester.pump();
      expect(find.text('Mapa conceitual da aula'), findsOneWidget);
    },
  );

  test('no_visual nao ocupa espaco morto no timeline', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshotWithContent(imagem: null),
        showImagePanel: false,
        imageStatus: 'idle',
      ),
    );

    expect(
      messages.where((message) => message.kind == ChatLessonMessageKind.image),
      isEmpty,
    );
  });

  testWidgets('erro visual nao bloqueia aula com conteudo valido', (
    tester,
  ) async {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshotWithContent(imagem: null),
        imageStatus: 'failed',
        imageError: 'Imagem indisponível',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: messages,
            onChooseAnswer: (_) {},
            onSignal: (_) {},
            onRetry: () {},
            onNext: () {},
            onOpenDoubt: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Explicação pronta'), findsOneWidget);
    expect(find.text('Imagem indisponível'), findsOneWidget);
    await _scrollOptionsIntoView(tester);
    expect(find.text('Pergunta pronta?'), findsOneWidget);
    expect(find.byKey(const Key('chat-answer-card-A')), findsOneWidget);
  });

  test(
    'visual board nao altera estado oficial nem usa WebView ou BoxFit.cover',
    () {
      final source = File(
        'lib/features/classroom/aula_widgets.dart',
      ).readAsStringSync();
      final board = RegExp(
        r'class LessonVisualBoard[\s\S]*?class LessonImageStudySurface',
      ).firstMatch(source)?.group(0);

      expect(board, isNotNull);
      for (final forbidden in const [
        'StudentStateStore',
        'LessonAnswerProgressController',
        'WebView',
        'BoxFit.cover',
      ]) {
        expect(board, isNot(contains(forbidden)), reason: forbidden);
      }
      for (final forbidden in const [
        'current',
        'progress',
        'attempts',
        'truth',
        'mastery',
      ]) {
        expect(
          board,
          isNot(contains(RegExp('\\b$forbidden\\b'))),
          reason: forbidden,
        );
      }
    },
  );
}

LessonRuntimeSnapshot _snapshotWithContent({String? imagem}) {
  return LessonRuntimeSnapshot(
    authReady: true,
    authed: true,
    hasCurriculum: true,
    isDone: false,
    viewModel: null,
    phase: const ClassroomPhase.reading(),
    history: const [],
    conteudo: const LessonContent(
      explanation: 'Explicação pronta',
      question: 'Pergunta pronta?',
      options: {
        AnswerLetter.A: 'Alternativa A',
        AnswerLetter.B: 'Alternativa B',
        AnswerLetter.C: 'Alternativa C',
      },
      correctAnswer: AnswerLetter.A,
    ),
    imagem: imagem,
    itemMarker: 'M1',
    itemText: 'Item atual',
  );
}

Future<void> _scrollOptionsIntoView(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('chat-aula-timeline')),
    const Offset(0, -260),
  );
  await tester.pump();
}

const _tinyPngDataUrl =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lK3QMgAAAABJRU5ErkJggg==';
