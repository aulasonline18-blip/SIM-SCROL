import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_t02_caller.dart';
import 'package:sim_mobile/sim/auxiliary/recovery_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/review_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_rooms.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_lesson_executor.dart';

void main() {
  test('botao de avanco nao chama revisao ou recuperacao', () {
    final source = File(
      'lib/sim/classroom/lesson_answer_progress_controller.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('startReview')));
    expect(source, isNot(contains('ReviewRoom')));
    expect(source, isNot(contains('startRecovery')));
    expect(source, isNot(contains('RecoveryRoom')));
  });

  test('revisao manual prioriza sinal 3, depois sinal 2, erro e antigo', () {
    final state = _stateWithPendingAttempts();

    final queue = buildReviewQueue(state, 5);

    expect(queue, ['M3', 'M2', 'M4']);
    expect(queue, isNot(contains('M1')));
  });

  test('revisao manual preserva item e camada da aula principal', () async {
    const lessonId = 'manual-review-preserves-main';
    final states = <String, StudentLearningState>{
      lessonId: _stateWithPendingAttempts(lessonId: lessonId),
    };
    final service = StudentAuxRoomService(
      readState: (id) => states[id]!,
      writeState: (state) => states[state.lessonLocalId] = state,
      t02Caller: AuxRoomT02Caller(client: _AuxT02Client()),
    );
    final review = ReviewRoomService(service);
    final context = _reviewContext(lessonId);
    final before = states[lessonId]!;

    var view = await review.startReviewRoom(context, 5);
    expect(view.status, ReviewRoomStatus.ready);
    view = review.selectLetter(view, AnswerLetter.A);
    view = review.answerReviewRoom(context, view, DecisionSignal.one);
    view = await review.nextReviewRoom(context, view);

    final after = states[lessonId]!;
    expect(after.progress?.itemIdx, before.progress?.itemIdx);
    expect(after.progress?.layer, before.progress?.layer);
    expect(after.current?.itemIdx, before.current?.itemIdx);
    expect(after.current?.layer, before.current?.layer);
    expect(
      after.events
          .lastWhere((event) => event.type == 'REVIEW_ANSWER_RECORDED')
          .payload['authoritative'],
      isFalse,
    );
  });

  test('recuperacao nao bloqueia avanco principal automaticamente', () async {
    const lessonId = 'recovery-does-not-block-main';
    final states = <String, StudentLearningState>{
      lessonId: _stateWithPendingAttempts(lessonId: lessonId),
    };
    final service = StudentAuxRoomService(
      readState: (id) => states[id]!,
      writeState: (state) => states[state.lessonLocalId] = state,
      t02Caller: AuxRoomT02Caller(client: _AuxT02Client()),
    );
    final recovery = RecoveryRoomService(service);
    final before = states[lessonId]!;

    final afterAnswer = processAnswerWithEngine(
      before,
      const AnswerContext(
        letra: AnswerLetter.B,
        sinal: DecisionSignal.three,
        correctAnswer: AnswerLetter.A,
      ),
      now: 100,
    );

    expect(afterAnswer.progress?.layer, LessonLayer.l3);
    expect(
      afterAnswer.events.map((event) => event.type),
      isNot(contains('RECOVERY_QUEUE_PREPARED')),
    );

    final view = await recovery.startRecoveryRoom(_recoveryContext(lessonId));
    expect(view.status, RecoveryRoomStatus.intro);
    final afterManualOpen = states[lessonId]!;
    expect(afterManualOpen.progress?.itemIdx, before.progress?.itemIdx);
    expect(afterManualOpen.progress?.layer, before.progress?.layer);
  });
}

StudentLearningState _stateWithPendingAttempts({
  String lessonId = 'manual-review',
}) {
  const items = [
    CurriculumItem(marker: 'M1', text: 'Item 1'),
    CurriculumItem(marker: 'M2', text: 'Item 2'),
    CurriculumItem(marker: 'M3', text: 'Item 3'),
    CurriculumItem(marker: 'M4', text: 'Item 4'),
  ];
  var state = StudentLearningState.empty(lessonLocalId: lessonId).copyWith(
    curriculum: const StudentCurriculum(
      topic: 'Tema',
      totalItems: 4,
      generatedAt: 1,
      provisional: false,
      items: items,
    ),
    current: const LessonCurrent(
      itemIdx: 1,
      marker: 'M2',
      layer: LessonLayer.l2,
      amparoLvl: 0,
    ),
    progress: const LessonProgress(
      itemIdx: 1,
      layer: LessonLayer.l2,
      erros: 0,
      amparoLvl: 0,
      historia: [],
      mainAdvances: 1,
      concluidos: ['M1'],
      pendentesMarkers: [],
      totalItems: 4,
      pctAvanco: 25,
    ),
  );
  final attempts = [
    const LessonAttempt(
      marker: 'M1',
      layer: LessonLayer.l1,
      letra: AnswerLetter.A,
      sinal: DecisionSignal.one,
      correct: true,
      ts: 1,
    ),
    const LessonAttempt(
      marker: 'M2',
      layer: LessonLayer.l1,
      letra: AnswerLetter.A,
      sinal: DecisionSignal.two,
      correct: true,
      ts: 2,
    ),
    const LessonAttempt(
      marker: 'M4',
      layer: LessonLayer.l1,
      letra: AnswerLetter.B,
      sinal: DecisionSignal.one,
      correct: false,
      ts: 3,
    ),
    const LessonAttempt(
      marker: 'M3',
      layer: LessonLayer.l1,
      letra: AnswerLetter.A,
      sinal: DecisionSignal.three,
      correct: true,
      ts: 4,
    ),
  ];
  for (final attempt in attempts) {
    state = mirrorAttemptToAuxRooms(state, attempt);
  }
  return state.copyWith(attempts: attempts);
}

ReviewRoomContext _reviewContext(String lessonId) => ReviewRoomContext(
  lessonLocalId: lessonId,
  topic: 'Tema',
  fallbackStartIdx: 1,
  layer: LessonLayer.l2,
  profile: const AuxRoomProfile(stableLang: 'pt-BR', academicLevel: 'base'),
  items: _auxItems,
);

RecoveryRoomContext _recoveryContext(String lessonId) => RecoveryRoomContext(
  lessonLocalId: lessonId,
  topic: 'Tema',
  layer: LessonLayer.l2,
  profile: const AuxRoomProfile(stableLang: 'pt-BR', academicLevel: 'base'),
  items: _auxItems,
);

const _auxItems = [
  AuxRoomItem(marker: 'M1', text: 'Item 1'),
  AuxRoomItem(marker: 'M2', text: 'Item 2'),
  AuxRoomItem(marker: 'M3', text: 'Item 3'),
  AuxRoomItem(marker: 'M4', text: 'Item 4'),
];

class _AuxT02Client implements T02LessonClient {
  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) async =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async =>
      T02LessonMaterial(
        explanation: 'Auxiliar ${request.marker}.',
        question: 'Pergunta ${request.marker}?',
        options: const {
          AnswerLetter.A: 'A',
          AnswerLetter.B: 'B',
          AnswerLetter.C: 'C',
        },
        correctAnswer: AnswerLetter.A,
        whyCorrect: 'A preserva a sala auxiliar manual.',
        whyWrong: const {},
        generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
        source: 'test-aux',
      );

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) =>
      completeLesson(request);
}
