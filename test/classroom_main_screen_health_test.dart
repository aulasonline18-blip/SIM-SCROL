import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/chat_aula_screen.dart';
import 'package:sim_mobile/features/classroom/chat_aula_timeline_builder.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  setUp(() => setSimActiveLanguage('pt-BR'));

  testWidgets('chat aula renderiza texto e opções do snapshot atual', (
    tester,
  ) async {
    final session = _snapshotSession();

    await tester.pumpWidget(
      MaterialApp(home: ChatAulaScreen(session: session)),
    );
    await tester.pump();

    await _pumpGuidedRoundIntro(tester);
    expect(find.textContaining('Observe o desenho'), findsOneWidget);
    await _openGuidedQuestion(tester);
    await _scrollGuidedOptionsIntoView(tester);
    expect(find.text('Linha reta'), findsOneWidget);
    expect(find.text('Curva'), findsOneWidget);
    expect(find.text('Ponto isolado'), findsOneWidget);
  });

  testWidgets('preparo efemero some quando o conteudo preparado renderiza', (
    tester,
  ) async {
    final session = _snapshotSession()
      ..aulaRuntimeLoading = true
      ..aulaSnapshot = _snapshot(
        phase: const ClassroomPhase.advancePending(
          message: 'aula_advance_pending',
        ),
        content: null,
      );

    await tester.pumpWidget(
      MaterialApp(home: ChatAulaScreen(session: session)),
    );
    await tester.pump();

    expect(find.text(t('aula_advance_pending')), findsOneWidget);

    session
      ..aulaRuntimeLoading = false
      ..aulaSnapshot = _snapshot(
        phase: const ClassroomPhase.reading(),
        content: const LessonContent(
          explanation: 'Aula preparada apareceu.',
          question: 'Qual alternativa continua?',
          options: {
            AnswerLetter.A: 'Primeira',
            AnswerLetter.B: 'Segunda',
            AnswerLetter.C: 'Terceira',
          },
          correctAnswer: AnswerLetter.A,
        ),
      );

    await tester.pumpWidget(
      MaterialApp(home: ChatAulaScreen(session: session)),
    );
    await tester.pump();

    expect(find.text(t('aula_advance_pending')), findsNothing);
    await _pumpGuidedRoundIntro(tester);
    expect(find.text('Aula preparada apareceu.'), findsOneWidget);
    await _openGuidedQuestion(tester);
    await _scrollGuidedOptionsIntoView(tester);
    expect(find.text('Primeira'), findsOneWidget);
  });

  testWidgets('conteudo pronto vence loading antigo de aula e imagem', (
    tester,
  ) async {
    final session = _snapshotSession()
      ..aulaRuntimeLoading = true
      ..imageStatus = 'loading'
      ..aulaSnapshot = _snapshot(
        phase: const ClassroomPhase.loading(),
        content: const LessonContent(
          explanation: 'Texto ja renderizavel.',
          question: 'Qual texto continua visivel?',
          options: {
            AnswerLetter.A: 'Opcao A',
            AnswerLetter.B: 'Opcao B',
            AnswerLetter.C: 'Opcao C',
          },
          correctAnswer: AnswerLetter.A,
        ),
      );

    await tester.pumpWidget(
      MaterialApp(home: ChatAulaScreen(session: session)),
    );
    await tester.pump();

    await _pumpGuidedRoundIntro(tester);
    expect(find.text('Texto ja renderizavel.'), findsOneWidget);
    await _openGuidedQuestion(tester);
    await _scrollGuidedOptionsIntoView(tester);
    expect(find.text('Opcao A'), findsOneWidget);
    expect(find.text(t('aula_advance_pending')), findsNothing);
    expect(find.text(t('aula_image_loading')), findsNothing);
    expect(find.text(t('loading')), findsNothing);
  });

  testWidgets('aula do menu sem cache mostra espera viva com retry', (
    tester,
  ) async {
    final session = _snapshotSession()
      ..aulaRuntimeLoading = true
      ..aulaMenuLessonWaiting = true
      ..aulaSnapshot = _snapshot(
        phase: const ClassroomPhase.advancePending(
          message: 'aula_menu_lesson_arriving',
        ),
        content: null,
      );

    await tester.pumpWidget(
      MaterialApp(home: ChatAulaScreen(session: session)),
    );
    await tester.pump();

    expect(find.text(t('aula_menu_lesson_arriving')), findsOneWidget);
    expect(find.text('Localizando este ponto.'), findsOneWidget);
    expect(find.text(t('aula_advance_preparing')), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(find.text(t('aula_try_again_2')), findsOneWidget);
  });

  test('advance pending vira preparo, não retry manual', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(
          phase: const ClassroomPhase.advancePending(
            message: 'aula_advance_pending',
            letter: AnswerLetter.B,
            signal: DecisionSignal.two,
          ),
        ),
        runtimeLoading: true,
      ),
    );

    expect(messages.where((message) => message.actionKey == 'retry'), isEmpty);
    expect(messages.where((message) => message.kind.name == 'error'), isEmpty);
  });

  test('erro técnico do runtime é mensagem humana controlada', () {
    final messages = buildChatLessonMessages(
      const ChatLessonTimelineInput(
        snapshot: null,
        runtimeError: 'HTTP 500: {"error":"complete lesson failed"}',
      ),
    );

    expect(messages.single.text, t('aula_gen_fail'));
    expect(messages.single.text, isNot(contains('HTTP')));
    expect(messages.single.text, isNot(contains('{')));
  });
}

Future<void> _pumpGuidedRoundIntro(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 140));
  await tester.pump(const Duration(milliseconds: 140));
  await tester.pump(const Duration(milliseconds: 160));
}

Future<void> _openGuidedQuestion(WidgetTester tester) async {
  final button = find.text(t('aula_practice_foundation'));
  if (button.evaluate().isEmpty) {
    await tester.drag(
      find.byKey(const Key('chat-aula-timeline')),
      const Offset(0, -280),
    );
    await tester.pump();
  }
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 220));
  await tester.pump();
}

Future<void> _scrollGuidedOptionsIntoView(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('chat-aula-timeline')),
    const Offset(0, -260),
  );
  await tester.pump();
}

LabSession _snapshotSession() => LabSession()
  ..authed = true
  ..authReady = true
  ..selectedLanguageCode = 'pt'
  ..stableLang = 'Portuguese'
  ..route = '/cyber/aula'
  ..lessonLocalId = 'lesson-health'
  ..aulaSnapshot = _snapshot();

LessonRuntimeSnapshot _snapshot({
  ClassroomPhase phase = const ClassroomPhase.reading(),
  LessonContent? content = const LessonContent(
    explanation: 'Observe o desenho da curva antes de responder.',
    question: 'Qual curva representa o crescimento?',
    options: {
      AnswerLetter.A: 'Linha reta',
      AnswerLetter.B: 'Curva',
      AnswerLetter.C: 'Ponto isolado',
    },
    correctAnswer: AnswerLetter.B,
  ),
}) => LessonRuntimeSnapshot(
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
  phase: phase,
  history: const [],
  conteudo: content,
  imagem: null,
  itemMarker: 'M1',
  itemText: 'Funções',
);
