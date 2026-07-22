import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_timeline_builder.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  final session = File(
    'lib/features/session/lab_session.dart',
  ).readAsStringSync();
  final flows = File(
    'lib/features/session/lab_session_flows.dart',
  ).readAsStringSync();
  final screen = File(
    'lib/features/classroom/chat_aula_screen.dart',
  ).readAsStringSync();
  final timeline = File(
    'lib/features/classroom/chat_aula_timeline_builder.dart',
  ).readAsStringSync();
  final runtime = File(
    'lib/sim/classroom/lesson_runtime_engine.dart',
  ).readAsStringSync();
  final materialController = File(
    'lib/sim/classroom/lesson_material_controller.dart',
  ).readAsStringSync();
  final materialService = File(
    'lib/sim/lesson/student_lesson_material_service.dart',
  ).readAsStringSync();
  final materialFailures = File(
    'lib/sim/lesson/student_lesson_material_failures.dart',
  ).readAsStringSync();

  test('1. menu local does not erase the old renderable snapshot', () {
    final prepareStart = flows.indexOf('void _prepareDrawerLessonOpen');
    final prepareEnd = flows.indexOf('Future<bool> deleteDrawerLocalLesson');
    final prepareDrawerOpen = flows.substring(prepareStart, prepareEnd);

    expect(session, contains('class AulaOpeningTransition'));
    expect(prepareDrawerOpen, contains('previousSnapshot: aulaSnapshot'));
    expect(
      prepareDrawerOpen,
      contains('_resetActiveLessonMedia(clearSnapshot: false'),
    );
    expect(prepareDrawerOpen, isNot(contains('clearSnapshot: true')));
  });

  test('2. two fast lesson opens are versioned and old result cannot win', () {
    expect(session, isNot(contains('_SingleFlightOperation')));
    expect(flows, isNot(contains('_aulaRuntimeOpen.run')));
    expect(
      flows,
      contains('final runtimeGeneration = ++_aulaRuntimeGeneration'),
    );
    expect(
      flows,
      contains('if (!_isCurrentAulaRuntime(id, runtimeGeneration))'),
    );
  });

  test('3. retry during open is a new visible intent', () {
    expect(session, contains('enum AulaOpenOperationKind { open, retry }'));
    expect(screen, contains('operationKind: AulaOpenOperationKind.retry'));
    expect(flows, contains('status: AulaOpeningStatus.retrying'));
    expect(flows, contains('aulaOpeningTransition = AulaOpeningTransition'));
  });

  test('4. background material resolves directly into the active screen', () {
    expect(runtime, contains('onBackgroundResolved'));
    expect(materialController, contains('_applyMaterial(position, result)'));
    expect(flows, contains('_applyBackgroundResolvedLessonMaterial'));
    expect(
      flows,
      contains('aulaSnapshot = organism.lessonRuntimeEngine.snapshot()'),
    );
    expect(flows, contains('_notifyFromChild()'));
  });

  test('5. listener reacts outside advancePending', () {
    expect(flows, isNot(contains("state?.extra['advancePending'] is! Map")));
    expect(flows, contains('_scheduleAdvancePendingReevaluation(active)'));
    expect(runtime, contains('reavaliarMaterialAtualSePronto'));
  });

  test('6. auto-advance is kept as a pending intent while loading', () {
    expect(session, contains('_pendingAutoAdvanceAfterFeedback'));
    expect(flows, contains('_tryConsumePendingAutoAdvance'));
    expect(flows, isNot(contains('const Duration(milliseconds: 1000)')));
    expect(flows, contains('_drainPendingAulaIntents'));
  });

  test('7. advance during loading is not silently discarded', () {
    expect(session, contains('_pendingManualAdvance'));
    expect(flows, isNot(contains('if (aulaRuntimeLoading) return;')));
    expect(flows, contains('_pendingManualAdvance = true'));
    expect(flows, contains('_notifyFromChild()'));
  });

  test('8. valid content keeps answer and signal buttons active', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(
          phase: const ClassroomPhase.expanded(AnswerLetter.A),
        ),
        runtimeLoading: true,
      ),
    );

    final options = messages.singleWhere(
      (message) => message.kind == ChatLessonMessageKind.options,
    );
    expect(options.options.every((option) => option.enabled), isTrue);
    expect(options.signals.every((signal) => signal.enabled), isTrue);
    expect(timeline, contains('phase?.type == ClassroomPhaseType.processando'));
  });

  test('9. qualifier feedback is notified before auxiliary effects', () {
    expect(
      flows.indexOf('await organism.lessonRuntimeEngine.signal(signal)'),
      greaterThan(-1),
    );
    expect(
      flows.indexOf(
        '_notifyFromChild();\n      _enqueueActiveLessonForRemoteVaultSync',
      ),
      greaterThan(-1),
    );
    expect(
      flows.indexOf(
        '_notifyFromChild();\n      _enqueueActiveLessonForRemoteVaultSync',
      ),
      lessThan(flows.indexOf('prefetchAuxRoomsAfterMainEvidence')),
    );
  });

  test('10. background failure becomes recoverable and retryable state', () {
    expect(materialService, isNot(contains('.catchError((_) => null)')));
    expect(materialFailures, contains('LESSON_BACKGROUND_MATERIAL_FAILED'));
    expect(materialFailures, contains("'recoverable': true"));
    expect(materialFailures, contains("'retryAvailable': true"));
  });
}

LessonRuntimeSnapshot _snapshot({required ClassroomPhase phase}) {
  return LessonRuntimeSnapshot(
    authReady: true,
    authed: true,
    hasCurriculum: true,
    isDone: false,
    viewModel: LessonMainViewModel(
      progress: 20,
      headerLabel: 'aula_item_of:1/5:aula_layer_1',
      options: const [],
      locked: phase.type == ClassroomPhaseType.processando,
      nextLabel: '',
    ),
    phase: phase,
    history: const [],
    conteudo: const LessonContent(
      explanation: 'Explicacao pronta.',
      question: 'Qual alternativa confirma a leitura?',
      options: {AnswerLetter.A: 'A', AnswerLetter.B: 'B', AnswerLetter.C: 'C'},
      correctAnswer: AnswerLetter.A,
    ),
    imagem: null,
    itemMarker: 'M1',
    itemText: 'Item 1',
  );
}
