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

    expect(find.textContaining('Observe o desenho'), findsOneWidget);
    expect(find.text('Linha reta'), findsOneWidget);
    expect(find.text('Curva'), findsOneWidget);
    expect(find.text('Ponto isolado'), findsOneWidget);
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
  conteudo: const LessonContent(
    explanation: 'Observe o desenho da curva antes de responder.',
    question: 'Qual curva representa o crescimento?',
    options: {
      AnswerLetter.A: 'Linha reta',
      AnswerLetter.B: 'Curva',
      AnswerLetter.C: 'Ponto isolado',
    },
    correctAnswer: AnswerLetter.B,
  ),
  imagem: null,
  itemMarker: 'M1',
  itemText: 'Funções',
);
