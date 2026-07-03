import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import '../placement/placement_state.dart';
import 'student_experience_placement_adapter.dart';
import 'student_experience_guards.dart';
import 'student_experience_store.dart';
import 'student_experience_t00_adapter.dart';
import 'student_experience_t02_adapter.dart';
import 'student_experience_types.dart';

abstract interface class PlacementDecisionReader {
  bool get settled;
  PlacementDecision readPlacementDecision();
  StartPosition resolveStartPosition(
    StudentCurriculum curriculum,
    PlacementDecision decision,
  );
}

class SettledPlacementReader implements PlacementDecisionReader {
  const SettledPlacementReader({this.settled = false});

  @override
  final bool settled;

  @override
  PlacementDecision readPlacementDecision() => PlacementDecision(
    enabled: false,
    placement: PlacementState.empty(),
    settled: settled,
  );

  @override
  StartPosition resolveStartPosition(
    StudentCurriculum curriculum,
    PlacementDecision decision,
  ) {
    final item = curriculum.items.isEmpty ? null : curriculum.items.first;
    return StartPosition(itemIndex: 0, marker: item?.marker, item: item);
  }
}

class StudentExperienceEngine {
  StudentExperienceEngine({
    required this.service,
    required this.t00,
    required this.placement,
    this.t02,
  });

  final StudentLearningStateService service;
  final StudentExperienceT00Adapter t00;
  final StudentExperienceT02Adapter? t02;
  final PlacementDecisionReader placement;

  Future<StudentExperienceResult> prepareStudentExperienceEntry(
    StudentExperienceArgs args,
  ) async {
    final topic = (args.onboarding['objetivo'] ?? '').toString().trim();
    if (topic.isEmpty) {
      throw const StudentExperienceEngineException(
        StudentExperienceErrorInfo(
          kind: StudentExperienceErrorKind.generic,
          message: 'Conte o que voce quer estudar antes de entrar na aula.',
        ),
      );
    }

    service.ensure(lessonLocalId: args.lessonLocalId);
    writeStudentExperienceSnapshot(
      service,
      lessonLocalId: args.lessonLocalId,
      state: StudentExperienceState.fichaRecebida,
    );
    publishStudentExperienceEvent(
      service,
      args.lessonLocalId,
      StudentExperienceEventType.studentFormSubmitted,
      {'topic': topic},
    );

    try {
      final first = await t00.startT00UntilFirstItem(args);
      service.appendEvent(
        args.lessonLocalId,
        StudentLearningEvent(
          type: 'CURRICULUM_GENERATED',
          ts: DateTime.now().millisecondsSinceEpoch,
          payload: {
            'lessonLocalId': args.lessonLocalId,
            'topic': first.curriculum.topic,
            'totalItems': first.curriculum.items.length,
            'firstMarker': first.marker,
            'firstItemIndex': first.itemIndex,
            'source': 'StudentExperienceEngine',
          },
        ),
      );
      publishStudentExperienceEvent(
        service,
        args.lessonLocalId,
        StudentExperienceEventType.firstItemFastPathStarted,
        {
          'at': DateTime.now().millisecondsSinceEpoch,
          'marker': first.marker,
          'itemIdx': first.itemIndex,
        },
      );

      final firstLessonPreparer = t02;
      if (firstLessonPreparer != null) {
        await firstLessonPreparer.prepareFirstMinimumLesson(
          args: args,
          first: first,
        );
      }

      if (!placement.settled) {
        args.onStage?.call(StudentExperienceRouteStage.placement);
        writeStudentExperienceSnapshot(
          service,
          lessonLocalId: args.lessonLocalId,
          state: StudentExperienceState.nivelamentoNecessario,
          destination: '/cyber/placement',
          startMarker: first.marker,
          startItemIndex: first.itemIndex,
        );
        publishStudentExperienceEvent(
          service,
          args.lessonLocalId,
          StudentExperienceEventType.placementRequired,
          {'marker': first.marker},
        );
        return StudentExperienceResult(
          destination: '/cyber/placement',
          curriculum: first.curriculum,
          startMarker: null,
          startItemIndex: 0,
        );
      }

      final decision = placement.readPlacementDecision();
      final target = placement.resolveStartPosition(first.curriculum, decision);
      if (target.item == null) {
        throw Exception('Nao encontrei o primeiro item da aula.');
      }
      final selected = FirstCurriculumItem(
        curriculum: first.curriculum,
        item: target.item!,
        itemIndex: target.itemIndex,
        marker: target.marker,
      );
      if (selected.marker != first.marker ||
          selected.itemIndex != first.itemIndex) {
        if (firstLessonPreparer == null) {
          throw Exception('T02 obrigatorio para abrir a primeira aula.');
        }
        publishStudentExperienceEvent(
          service,
          args.lessonLocalId,
          StudentExperienceEventType.placementContinueToAula,
          {
            'startMarker': selected.marker,
            'itemIdx': selected.itemIndex,
            'source': 'placement_result',
          },
        );
        await firstLessonPreparer.prepareFirstMinimumLesson(
          args: args,
          first: selected,
        );
      }
      if (firstLessonPreparer == null) {
        throw Exception('T02 obrigatorio para abrir a primeira aula.');
      }

      args.onStage?.call(StudentExperienceRouteStage.ready);
      writeStudentExperienceSnapshot(
        service,
        lessonLocalId: args.lessonLocalId,
        state: StudentExperienceState.salaAberta,
        destination: '/cyber/aula',
        startMarker: selected.marker,
        startItemIndex: selected.itemIndex,
      );
      return StudentExperienceResult(
        destination: '/cyber/aula',
        curriculum: selected.curriculum,
        startMarker: selected.marker,
        startItemIndex: selected.itemIndex,
      );
    } catch (error) {
      final info = classifyStudentExperienceError(error);
      writeStudentExperienceSnapshot(
        service,
        lessonLocalId: args.lessonLocalId,
        state: info.kind == StudentExperienceErrorKind.timeout
            ? StudentExperienceState.erroRecuperavel
            : StudentExperienceState.erroBloqueante,
        error: info,
      );
      publishStudentExperienceEvent(
        service,
        args.lessonLocalId,
        info.kind == StudentExperienceErrorKind.timeout
            ? StudentExperienceEventType.recoverableError
            : StudentExperienceEventType.blockingError,
        {'error': info.message},
      );
      throw StudentExperienceEngineException(info);
    }
  }
}
