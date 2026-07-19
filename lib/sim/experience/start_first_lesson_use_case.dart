import '../state/live_entry_state.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'student_experience_store.dart';
import 'student_experience_types.dart';

class StartFirstLessonUseCase {
  const StartFirstLessonUseCase({required this.service});

  final StudentLearningStateService service;

  void openShell({
    required StudentExperienceArgs args,
    required FirstCurriculumItem first,
  }) {
    _writeInitialPosition(args.lessonLocalId, first);
    args.onStage?.call(StudentExperienceRouteStage.ready);
    writeStudentExperienceSnapshot(
      service,
      lessonLocalId: args.lessonLocalId,
      state: StudentExperienceState.salaAberta,
      destination: '/cyber/aula',
      startMarker: first.marker,
      startItemIndex: first.itemIndex,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    publishStudentExperienceEvent(
      service,
      args.lessonLocalId,
      StudentExperienceEventType.firstLessonShellOpened,
      {'at': now, 'marker': first.marker, 'itemIdx': first.itemIndex},
    );
    publishStudentExperienceEvent(
      service,
      args.lessonLocalId,
      StudentExperienceEventType.timeToClassroom,
      {'at': now, 'marker': first.marker, 'itemIdx': first.itemIndex},
    );
  }

  void markMinimumLessonReady({
    required StudentExperienceArgs args,
    required FirstCurriculumItem first,
    required String source,
    required int waitedMs,
  }) {
    _writeInitialPosition(args.lessonLocalId, first);
    writeStudentExperienceSnapshot(
      service,
      lessonLocalId: args.lessonLocalId,
      state: StudentExperienceState.primeiraAulaMinimaPronta,
      destination: '/cyber/aula',
      startMarker: first.marker,
      startItemIndex: first.itemIndex,
    );
    publishStudentExperienceEvent(
      service,
      args.lessonLocalId,
      StudentExperienceEventType.t02FirstMinimumLessonReady,
      {
        'marker': first.marker,
        'itemIdx': first.itemIndex,
        'materialKey': entryLessonMaterialKey(first.itemIndex, first.marker),
        'source': source,
        'waitedMs': waitedMs,
      },
    );
    publishStudentExperienceEvent(
      service,
      args.lessonLocalId,
      StudentExperienceEventType.timeToFirstQuestion,
      {
        'marker': first.marker,
        'itemIdx': first.itemIndex,
        'waitedMs': waitedMs,
      },
    );
  }

  void _writeInitialPosition(String lessonLocalId, FirstCurriculumItem first) {
    service.mutate(lessonLocalId, (state) {
      return state.copyWith(
        current: LessonCurrent(
          itemIdx: first.itemIndex,
          marker: first.marker,
          layer: LessonLayer.l1,
          amparoLvl: 0,
        ),
        progress: LessonProgress(
          itemIdx: first.itemIndex,
          layer: LessonLayer.l1,
          erros: 0,
          amparoLvl: 0,
          historia: const [],
          mainAdvances: first.itemIndex,
          concluidos: const [],
          pendentesMarkers: const [],
          totalItems: first.curriculum.items.length,
          pctAvanco: first.curriculum.items.isEmpty
              ? 0
              : ((first.itemIndex / first.curriculum.items.length) * 100)
                    .round(),
        ),
      );
    });
  }
}
