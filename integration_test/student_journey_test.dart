import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_timeline_builder.dart';
import 'package:sim_mobile/main.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'student journey renders lesson, A/B/C, feedback and advance state',
    (tester) async {
      final session = LabSession()
        ..authReady = true
        ..authed = true
        ..selectedLanguageCode = 'pt'
        ..stableLang = 'pt-BR'
        ..lessonLocalId = 'journey-lesson'
        ..route = '/cyber/aula'
        ..aulaSnapshot = _snapshot();

      await tester.pumpWidget(SimApp(initialSession: session));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(session.route, '/cyber/aula');
      expect(find.byKey(const Key('chat-aula-timeline')), findsOneWidget);
      expect(find.text('Qual alternativa confirma a leitura?'), findsOneWidget);
      expect(find.byKey(const Key('chat-answer-card-A')), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat-answer-card-A')));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(session.aulaSnapshot?.phase.type, ClassroomPhaseType.expandida);

      await session.submitAulaSignal(1);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      final messages = buildChatLessonMessages(
        ChatLessonTimelineInput(
          snapshot: session.aulaSnapshot,
          lessonLocalId: session.lessonLocalId,
        ),
      );
      expect(
        messages.any(
          (message) => message.kind == ChatLessonMessageKind.feedback,
        ),
        isTrue,
      );
      expect(session.aulaSnapshot?.phase.type, ClassroomPhaseType.concluido);
      expect(session.route.startsWith('/cyber/'), isTrue);
    },
  );
}

LessonRuntimeSnapshot _snapshot() {
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
    conteudo: const LessonContent(
      explanation: 'Explicacao pronta.',
      question: 'Qual alternativa confirma a leitura?',
      options: {
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
