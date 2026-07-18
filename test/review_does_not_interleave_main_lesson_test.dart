import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_t02_caller.dart';
import 'package:sim_mobile/sim/auxiliary/review_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_rooms.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  test('review finishes without interleaving the main lesson queue', () async {
    const lessonId = 'lesson-review-isolated';
    final states = <String, StudentLearningState>{lessonId: _mainLessonState()};
    final review = ReviewRoomService(
      StudentAuxRoomService(
        readState: (id) => states[id]!,
        writeState: (state) => states[state.lessonLocalId] = state,
        t02Caller: AuxRoomT02Caller(client: _ReviewT02Client()),
      ),
    );
    final before = states[lessonId]!;
    final context = _reviewContext(lessonId);

    var view = await review.startReviewRoom(context, 5);
    expect(view.status, ReviewRoomStatus.ready);
    expect(view.queue.first, 'M1');

    view = review.selectLetter(view, AnswerLetter.A);
    view = review.answerReviewRoom(context, view, DecisionSignal.one);
    expect(view.status, ReviewRoomStatus.result);
    view = await review.nextReviewRoom(context, view);
    expect(view.status, ReviewRoomStatus.done);

    final after = states[lessonId]!;
    expect(after.current?.marker, before.current?.marker);
    expect(after.current?.itemIdx, before.current?.itemIdx);
    expect(after.current?.layer, before.current?.layer);
    expect(after.progress?.itemIdx, before.progress?.itemIdx);
    expect(after.progress?.layer, before.progress?.layer);
    expect(after.progress?.mainAdvances, before.progress?.mainAdvances);
    expect(after.readyLessonMaterials.keys, contains('I2::M3::L1::l1'));
    expect(after.readyLessonMaterials, before.readyLessonMaterials);

    final reviewRoom = ensureAuxRooms(after)['review'] as Map;
    expect(reviewRoom['sourceLessonLocalId'], lessonId);
    expect(reviewRoom['currentQueue'], isNot(contains('M2')));
    expect(
      after.events.map((event) => event.type),
      containsAll([
        'REVIEW_QUEUE_PREPARED',
        'REVIEW_ANSWER_RECORDED',
        'REVIEW_CURSOR_UPDATED',
      ]),
    );
    expect(
      after.events
          .lastWhere((event) => event.type == 'REVIEW_ANSWER_RECORDED')
          .payload['authoritative'],
      isFalse,
    );
  });
}

StudentLearningState _mainLessonState() {
  final material = {
    'marker': 'M3',
    'itemIdx': 2,
    'layer': 1,
    'text_status': 'ready',
    'conteudo': const LessonContent(
      explanation: 'Proxima aula principal.',
      question: 'Pergunta principal M3?',
      options: {AnswerLetter.A: 'A', AnswerLetter.B: 'B', AnswerLetter.C: 'C'},
      correctAnswer: AnswerLetter.A,
    ).toJson(),
  };
  final weakAttempt = LessonAttempt(
    marker: 'M1',
    layer: LessonLayer.l1,
    letra: AnswerLetter.A,
    sinal: DecisionSignal.three,
    correct: true,
    ts: 1,
  );
  return registerPendingFromAttempt(
    StudentLearningState.empty(
      lessonLocalId: 'lesson-review-isolated',
    ).copyWith(
      profile: const StudentProfile(
        objetivo: 'Matematica',
        stableLang: 'pt-BR',
      ),
      curriculum: const StudentCurriculum(
        topic: 'Matematica',
        totalItems: 3,
        generatedAt: 1,
        provisional: false,
        items: [
          CurriculumItem(marker: 'M1', text: 'Revisar base'),
          CurriculumItem(marker: 'M2', text: 'Aula principal atual'),
          CurriculumItem(marker: 'M3', text: 'Proxima aula principal'),
        ],
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
        historia: ['M2:L1:A:1'],
        mainAdvances: 1,
        concluidos: ['M1'],
        pendentesMarkers: [],
        totalItems: 3,
        pctAvanco: 33,
      ),
      attempts: [weakAttempt],
      readyLessonMaterials: {'I2::M3::L1::l1': material},
    ),
    weakAttempt,
  );
}

ReviewRoomContext _reviewContext(String lessonId) => ReviewRoomContext(
  lessonLocalId: lessonId,
  topic: 'Matematica',
  fallbackStartIdx: 1,
  layer: LessonLayer.l2,
  profile: const AuxRoomProfile(stableLang: 'pt-BR', academicLevel: 'base'),
  items: const [
    AuxRoomItem(marker: 'M1', text: 'Revisar base'),
    AuxRoomItem(marker: 'M2', text: 'Aula principal atual'),
    AuxRoomItem(marker: 'M3', text: 'Proxima aula principal'),
  ],
);

class _ReviewT02Client implements T02LessonClient {
  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) async =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async =>
      T02LessonMaterial(
        explanation: 'Revisao controlada de ${request.marker}.',
        question: 'Qual alternativa revisa ${request.marker}?',
        options: const {
          AnswerLetter.A: 'Revisar com evidencia.',
          AnswerLetter.B: 'Pular.',
          AnswerLetter.C: 'Trocar a aula.',
        },
        correctAnswer: AnswerLetter.A,
        whyCorrect: 'Mantem a revisao auxiliar.',
        whyWrong: const {},
        generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
        source: 'test-review',
      );

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) =>
      completeLesson(request);
}
