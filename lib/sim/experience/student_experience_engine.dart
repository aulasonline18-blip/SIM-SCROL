import 'dart:async';

import '../placement/placement_state.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'student_experience_placement_adapter.dart';
import 'student_experience_store.dart';
import 'student_experience_t00_adapter.dart';
import 'student_experience_t02_adapter.dart';
import 'student_experience_types.dart';

String _humanExperienceErrorMessage(Object? error) {
  final raw = error?.toString() ?? '';
  final lower = raw.toLowerCase();
  if (lower.contains('timeout')) {
    return 'A conexao demorou demais. Tente novamente em instantes.';
  }
  if (lower.contains('socket') || lower.contains('network')) {
    return 'A conexao parece instavel. Salvamos seu ponto e vamos tentar novamente.';
  }
  if (raw.contains('{') || raw.contains('}') || lower.contains('exception')) {
    return 'Nao consegui concluir isso agora. Tente novamente em instantes.';
  }
  return raw.trim().isEmpty
      ? 'Nao consegui concluir isso agora. Tente novamente em instantes.'
      : raw.trim();
}

StudentExperienceErrorInfo classifyStudentExperienceError(Object error) {
  final message = error.toString();
  final lower = message.toLowerCase();
  if (message.contains('HTTP 402') ||
      lower.contains('credit') ||
      lower.contains('credito') ||
      lower.contains('saldo') ||
      lower.contains('insufficient_credits')) {
    return const StudentExperienceErrorInfo(
      kind: StudentExperienceErrorKind.credits,
      message:
          'Seus creditos acabaram. Compre creditos para continuar estudando.',
    );
  }
  if (lower.contains('http 401') ||
      lower.contains('http 403') ||
      lower.contains('missing bearer') ||
      lower.contains('invalid token') ||
      lower.contains('auth') ||
      lower.contains('unauthorized') ||
      lower.contains('forbidden')) {
    return const StudentExperienceErrorInfo(
      kind: StudentExperienceErrorKind.auth,
      message:
          'Sua sessao precisa ser renovada. Entre novamente para continuar.',
    );
  }
  if (error is TimeoutException ||
      lower.contains('timeout') ||
      lower.contains('timeoutexception') ||
      lower.contains('tempo') ||
      lower.contains('abort') ||
      lower.contains('t02 nao devolveu') ||
      lower.contains('aula minima')) {
    return const StudentExperienceErrorInfo(
      kind: StudentExperienceErrorKind.timeout,
      message: 'A preparacao demorou demais. Toque para tentar novamente.',
    );
  }
  if (lower.contains('socketexception') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('network is unreachable') ||
      lower.contains('failed host lookup') ||
      lower.contains('os error') ||
      lower.contains('cleartext') ||
      lower.contains('http 5')) {
    return StudentExperienceErrorInfo(
      kind: StudentExperienceErrorKind.generic,
      message: _humanExperienceErrorMessage(error),
    );
  }
  return const StudentExperienceErrorInfo(
    kind: StudentExperienceErrorKind.generic,
    message:
        'Nao consegui preparar a entrada da aula agora. Toque para tentar novamente.',
  );
}

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

      final placementIsSettled = placement.settled;
      if (!placementIsSettled) {
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
        publishStudentExperienceEvent(
          service,
          args.lessonLocalId,
          StudentExperienceEventType.placementScreenReleasedAfterSlotA,
          {'at': DateTime.now().millisecondsSinceEpoch, 'marker': first.marker},
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
      }

      if (firstLessonPreparer != null &&
          (selected.marker != first.marker ||
              selected.itemIndex != first.itemIndex)) {
        await firstLessonPreparer.prepareFirstMinimumLesson(
          args: args,
          first: selected,
        );
      }
      _openFirstLessonShell(args, selected);
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

  void _openFirstLessonShell(
    StudentExperienceArgs args,
    FirstCurriculumItem first,
  ) {
    service.mutate(args.lessonLocalId, (state) {
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
}
