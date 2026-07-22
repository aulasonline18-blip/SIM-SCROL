import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_timeline_builder.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/runtime/sim_runtime_audit.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  setUp(() {
    SimRuntimeAudit.clearForTesting();
    final previous = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = previous);
  });

  test(
    'valid content keeps A/B/C active while runtime has lateral loading',
    () {
      final messages = buildChatLessonMessages(
        ChatLessonTimelineInput(snapshot: _snapshot(), runtimeLoading: true),
      );

      final options = messages.singleWhere(
        (message) => message.kind == ChatLessonMessageKind.options,
      );

      expect(
        options.options.map((option) => option.enabled),
        everyElement(true),
      );
    },
  );

  test('valid content keeps A/B/C active while menu lesson is arriving', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(snapshot: _snapshot(), menuLessonWaiting: true),
    );

    final options = messages.singleWhere(
      (message) => message.kind == ChatLessonMessageKind.options,
    );

    expect(options.isActionable, isTrue);
    expect(options.options.map((option) => option.enabled), everyElement(true));
  });

  test('invalid answer letter is rejected and does not become A', () {
    final session = LabSession()
      ..aulaSnapshot = _snapshot()
      ..aulaRuntimeLoading = false;

    session.chooseAulaAnswer('Z');

    expect(session.aulaRuntimeError?.toLowerCase(), contains('alternativa'));
    expect(session.aulaSnapshot?.phase.type, ClassroomPhaseType.lendo);
    expect(
      SimRuntimeAudit.events.map((event) => event.code),
      contains('answer_rejected_invalid_letter'),
    );
  });

  test('abc tap during loading has visible disabled state', () {
    final session = LabSession()
      ..aulaSnapshot = _snapshot(content: null)
      ..aulaRuntimeLoading = true;

    session.chooseAulaAnswer('A');

    expect(session.aulaRuntimeError?.toLowerCase(), contains('preparando'));
    expect(
      SimRuntimeAudit.events.map((event) => event.code),
      contains('answer_blocked_by_loading'),
    );
  });

  test(
    'invalid qualifier signal is rejected and does not become signal one',
    () async {
      final session = LabSession()
        ..aulaSnapshot = _snapshot(
          phase: const ClassroomPhase.expanded(AnswerLetter.A),
        )
        ..aulaRuntimeLoading = false;

      await session.submitAulaSignal(99);

      expect(session.aulaRuntimeError?.toLowerCase(), contains('qualificador'));
      expect(session.aulaSnapshot?.phase.type, ClassroomPhaseType.expandida);
      expect(
        SimRuntimeAudit.events.map((event) => event.code),
        contains('signal_rejected_invalid_value'),
      );
    },
  );

  test('signal blocked by loading has visible state', () async {
    final session = LabSession()
      ..aulaSnapshot = _snapshot(content: null)
      ..aulaRuntimeLoading = true;

    await session.submitAulaSignal(1);

    expect(session.aulaRuntimeError?.toLowerCase(), contains('qualificar'));
    expect(
      SimRuntimeAudit.events.map((event) => event.code),
      contains('signal_blocked_by_loading'),
    );
  });

  test('qualifier pending state renders a visible processing message', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(
          phase: const ClassroomPhase.advancePending(
            message: 'aula_advance_preparing',
            letter: AnswerLetter.A,
            signal: DecisionSignal.one,
          ),
          content: null,
        ),
      ),
    );

    expect(
      messages.any(
        (message) => message.kind == ChatLessonMessageKind.processing,
      ),
      isTrue,
    );
  });
}

LessonRuntimeSnapshot _snapshot({
  ClassroomPhase phase = const ClassroomPhase.reading(),
  LessonContent? content = const LessonContent(
    explanation: 'Explicacao pronta.',
    question: 'Qual alternativa confirma a leitura?',
    options: {
      AnswerLetter.A: 'Alternativa A',
      AnswerLetter.B: 'Alternativa B',
      AnswerLetter.C: 'Alternativa C',
    },
    correctAnswer: AnswerLetter.A,
  ),
}) {
  return LessonRuntimeSnapshot(
    authReady: true,
    authed: true,
    hasCurriculum: true,
    isDone: false,
    viewModel: LessonMainViewModel(
      progress: 10,
      headerLabel: 'aula_item_of:1/1:aula_layer_1',
      options: const [],
      locked: phase.type == ClassroomPhaseType.processando,
      nextLabel: '',
    ),
    phase: phase,
    history: const [],
    conteudo: content,
    imagem: null,
    itemMarker: 'M1',
    itemText: 'Item 1',
  );
}
