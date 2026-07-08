import '../state/student_learning_state.dart';
import 'aux_room_models.dart';
import 'server_recovery_contract.dart';
import 'student_aux_room_service.dart';

class RecoveryRoomService {
  const RecoveryRoomService(this.service, {this.serverRecoveryClient});

  final StudentAuxRoomService service;
  final ServerRecoveryClient? serverRecoveryClient;

  bool shouldStartRecoveryRoom(String lessonLocalId) {
    return service.shouldLessonBlockFinalCompletion(lessonLocalId);
  }

  Future<RecoveryRoomView> startRecoveryRoom(
    RecoveryRoomContext context,
  ) async {
    final server = serverRecoveryClient;
    if (server != null) {
      try {
        final item = await server.next(
          lessonLocalId: context.lessonLocalId,
          idempotencyKey: '${context.lessonLocalId}:recovery:open',
        );
        if (item == null) {
          return const RecoveryRoomView(
            status: RecoveryRoomStatus.done,
            queue: [],
            idx: 0,
          );
        }
        return RecoveryRoomView(
          status: item.ready
              ? RecoveryRoomStatus.intro
              : RecoveryRoomStatus.failed,
          queue: [item.marker],
          idx: 0,
          conteudo: _contentFromServer(item),
          errMsg: item.humanError?['message']?.toString(),
          serverRecoveryId: item.recoveryId,
          serverMarker: item.marker,
        );
      } catch (_) {
        return const RecoveryRoomView(
          status: RecoveryRoomStatus.failed,
          queue: [],
          idx: 0,
          errMsg:
              'Nao consegui abrir a recuperacao agora. Sua aula foi preservada.',
        );
      }
    }
    final built = service.buildRecoveryQueueForLesson(
      lessonLocalId: context.lessonLocalId,
      topic: context.topic,
      items: context.items,
    );
    if (built.queue.isEmpty) {
      service.registerRecoveryCompleted(context.lessonLocalId);
      return const RecoveryRoomView(
        status: RecoveryRoomStatus.done,
        queue: [],
        idx: 0,
      );
    }
    service.registerRecoveryStarted(context.lessonLocalId, built.queue);
    final signal =
        built.signalByMarker[built.queue.first] ?? DecisionSignal.three;
    final prepared = await _prepare(
      context: context,
      queue: built.queue,
      idx: 0,
      signal: signal,
    );
    if (prepared.status == RecoveryRoomStatus.ready) {
      return prepared.copyWith(status: RecoveryRoomStatus.intro);
    }
    return prepared;
  }

  Future<RecoveryRoomView> _prepare({
    required RecoveryRoomContext context,
    required List<String> queue,
    required int idx,
    required DecisionSignal signal,
  }) async {
    final prepared = await service.prepareAuxRoomQuestion(
      lessonLocalId: context.lessonLocalId,
      mode: AuxRoomMode.recovery,
      profile: context.profile,
      items: context.items,
      marker: idx < queue.length ? queue[idx] : null,
      signal: signal,
    );
    if (!prepared.ok) {
      return RecoveryRoomView(
        status: RecoveryRoomStatus.failed,
        queue: queue,
        idx: idx,
        errMsg: prepared.error,
      );
    }
    return RecoveryRoomView(
      status: RecoveryRoomStatus.ready,
      queue: queue,
      idx: idx,
      conteudo: prepared.conteudo,
    );
  }

  RecoveryRoomView continueRecovery(RecoveryRoomView view) {
    return view.status == RecoveryRoomStatus.intro
        ? view.copyWith(status: RecoveryRoomStatus.ready)
        : view;
  }

  RecoveryRoomView selectLetter(RecoveryRoomView view, AnswerLetter letra) {
    return view.copyWith(status: RecoveryRoomStatus.answering, letra: letra);
  }

  RecoveryRoomView answerRecoveryRoom(
    RecoveryRoomContext context,
    RecoveryRoomView view,
    DecisionSignal sinal,
  ) {
    final conteudo = view.conteudo;
    final letra = view.letra;
    final marker = view.idx < view.queue.length ? view.queue[view.idx] : null;
    if (conteudo == null || letra == null || marker == null) {
      return view.copyWith(
        status: RecoveryRoomStatus.failed,
        errMsg: 'recovery answer missing data',
      );
    }
    service.recordAuxRoomAnswer(
      lessonLocalId: context.lessonLocalId,
      marker: marker,
      layer: context.layer,
      items: context.items,
      conteudo: conteudo,
      letra: letra,
      sinal: sinal,
      source: 'recovery:${view.idx}',
    );
    return view.copyWith(
      status: RecoveryRoomStatus.result,
      sinal: sinal,
      resultCorrect: letra == conteudo.correctAnswer,
    );
  }

  Future<RecoveryRoomView> answerServerRecoveryRoom(
    RecoveryRoomContext context,
    RecoveryRoomView view,
    DecisionSignal sinal,
  ) async {
    final server = serverRecoveryClient;
    final conteudo = view.conteudo;
    final letra = view.letra;
    if (server == null) return answerRecoveryRoom(context, view, sinal);
    if (conteudo == null || letra == null || view.queue.isEmpty) {
      return view.copyWith(
        status: RecoveryRoomStatus.failed,
        errMsg: 'Resposta de recuperacao incompleta.',
      );
    }
    try {
      final result = await server.answer(
        ServerRecoveryAnswerRequest(
          lessonLocalId: context.lessonLocalId,
          recoveryId: view.serverRecoveryId ?? view.queue.first,
          marker: view.serverMarker ?? view.queue.first,
          selectedOption: letra,
          signal: sinal,
          idempotencyKey:
              '${context.lessonLocalId}:${view.serverRecoveryId ?? view.queue.first}:recovery:${letra.name}:${sinal.value}',
          timestamp: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      return view.copyWith(
        status: result.accepted
            ? RecoveryRoomStatus.result
            : RecoveryRoomStatus.failed,
        sinal: sinal,
        resultCorrect: result.correct,
        restartRequired: result.blocksConclusion && !result.repaired,
        errMsg: result.humanError?['message']?.toString(),
      );
    } catch (_) {
      return view.copyWith(
        status: RecoveryRoomStatus.failed,
        errMsg:
            'Nao consegui enviar a recuperacao agora. Sua aula foi preservada.',
      );
    }
  }

  Future<RecoveryRoomView> nextRecoveryRoom(
    RecoveryRoomContext context,
    RecoveryRoomView view,
  ) async {
    final built = service.buildRecoveryQueueForLesson(
      lessonLocalId: context.lessonLocalId,
      topic: context.topic,
      items: context.items,
    );
    if (built.queue.isEmpty) {
      service.registerRecoveryCompleted(context.lessonLocalId);
      return view.copyWith(status: RecoveryRoomStatus.done);
    }
    final signal =
        built.signalByMarker[built.queue.first] ?? DecisionSignal.three;
    return _prepare(
      context: context,
      queue: built.queue,
      idx: 0,
      signal: signal,
    );
  }

  RecoveryRoomView finishRecoveryRoom(
    String lessonLocalId,
    RecoveryRoomView view,
  ) {
    if (service.shouldLessonBlockFinalCompletion(lessonLocalId)) {
      return view.copyWith(restartRequired: true);
    }
    service.registerFinalCompletionAllowed(lessonLocalId);
    return view.copyWith(status: RecoveryRoomStatus.done);
  }

  AuxRoomContent _contentFromServer(ServerRecoveryItem item) {
    return AuxRoomContent(
      question: item.question,
      options: item.options,
      correctAnswer: item.correctOption,
      explanation: item.explanation,
    );
  }
}
