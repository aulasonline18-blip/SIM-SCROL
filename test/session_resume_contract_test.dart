import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/classroom/chat_aula_screen.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  testWidgets(
    'pause and resume keep route and restore only matching snapshot',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = LabSession(prefs: prefs)
        ..authReady = true
        ..authed = true
        ..lessonLocalId = 'resume-lesson'
        ..route = '/cyber/aula'
        ..aulaSnapshot = _snapshot(question: 'Pergunta antes do pause?');

      await tester.pumpWidget(
        MaterialApp(home: ChatAulaScreen(session: session)),
      );
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 500));

      expect(session.route, '/cyber/aula');
      expect(find.text('Explicacao persistida.'), findsAtLeastNWidgets(1));

      final key = prefs.getKeys().singleWhere(
        (key) => key.startsWith('sim.chat_aula.conversation.v1.'),
      );
      await prefs.setString(
        key,
        '{"version":1,"lessonKey":"other-lesson","archiveSeq":1,"messages":[]}',
      );

      final staleSession = LabSession(prefs: prefs)
        ..authReady = true
        ..authed = true
        ..lessonLocalId = 'resume-lesson'
        ..route = '/cyber/aula'
        ..aulaSnapshot = _snapshot(
          question: 'Pergunta correta depois do resume?',
        );

      await tester.pumpWidget(
        MaterialApp(home: ChatAulaScreen(session: staleSession)),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Explicacao persistida.'), findsAtLeastNWidgets(1));
      expect(find.text('Pergunta antes do pause?'), findsNothing);
    },
  );
}

LessonRuntimeSnapshot _snapshot({required String question}) {
  return LessonRuntimeSnapshot(
    authReady: true,
    authed: true,
    hasCurriculum: true,
    isDone: false,
    viewModel: const LessonMainViewModel(
      progress: 10,
      headerLabel: 'aula_item_of:1/1:aula_layer_1',
      options: [],
      locked: false,
      nextLabel: '',
    ),
    phase: const ClassroomPhase.reading(),
    history: const [],
    conteudo: LessonContent(
      explanation: 'Explicacao persistida.',
      question: question,
      options: const {
        AnswerLetter.A: 'Alternativa A',
        AnswerLetter.B: 'Alternativa B',
        AnswerLetter.C: 'Alternativa C',
      },
      correctAnswer: AnswerLetter.A,
    ),
    imagem: null,
    itemMarker: 'M1',
    itemText: 'Item 1',
  );
}
