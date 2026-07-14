import '../state/student_learning_state.dart';
import 'aux_room_models.dart';
import 'server_review_contract.dart';
import 'student_aux_room_service.dart';

class ReviewRoomService {
  const ReviewRoomService(this.service, {this.serverReviewClient});

  final StudentAuxRoomService service;
  final ServerReviewClient? serverReviewClient;

  ReviewRoomView createReviewChoiceView() => const ReviewRoomView(
    status: ReviewRoomStatus.choose,
    count: 5,
    queue: [],
    idx: 0,
  );

  Future<ReviewRoomView> startReviewRoom(
    ReviewRoomContext context,
    int count,
  ) async {
    final boundedCount = count == 10 ? 10 : 5;
    final server = serverReviewClient;
    if (server != null) {
      try {
        final item = await server.next(
          lessonLocalId: context.lessonLocalId,
          idempotencyKey: '${context.lessonLocalId}:review:open',
        );
        if (item == null) {
          return ReviewRoomView(
            status: ReviewRoomStatus.failed,
            count: boundedCount,
            queue: const [],
            idx: 0,
            errMsg: 'Sem revisao pendente agora.',
          );
        }
        return ReviewRoomView(
          status: item.ready ? ReviewRoomStatus.ready : ReviewRoomStatus.failed,
          count: boundedCount,
          queue: [item.marker],
          idx: 0,
          conteudo: _contentFromServer(item),
          errMsg: item.humanError?['message']?.toString(),
          serverReviewId: item.reviewId,
          serverMarker: item.marker,
        );
      } catch (_) {
        return ReviewRoomView(
          status: ReviewRoomStatus.failed,
          count: boundedCount,
          queue: const [],
          idx: 0,
          errMsg:
              'Nao consegui abrir a revisao agora. Sua aula foi preservada.',
        );
      }
    }
    final queue = service.buildReviewQueueForLesson(
      lessonLocalId: context.lessonLocalId,
      topic: context.topic,
      items: context.items,
      count: boundedCount,
      fallbackStartIdx: context.fallbackStartIdx,
    );
    if (queue.isEmpty) {
      return ReviewRoomView(
        status: ReviewRoomStatus.failed,
        count: boundedCount,
        queue: const [],
        idx: 0,
        errMsg: 'Sem itens para revisar.',
      );
    }
    return prepareReviewRoomQuestion(
      context: context,
      queue: queue,
      idx: 0,
      count: boundedCount,
    );
  }

  Future<ReviewRoomView> prepareReviewRoomQuestion({
    required ReviewRoomContext context,
    required List<String> queue,
    required int idx,
    required int count,
  }) async {
    final prepared = await service.prepareAuxRoomQuestion(
      lessonLocalId: context.lessonLocalId,
      mode: AuxRoomMode.review,
      profile: context.profile,
      items: context.items,
      marker: idx < queue.length ? queue[idx] : null,
      signal: DecisionSignal.two,
    );
    if (!prepared.ok) {
      return ReviewRoomView(
        status: ReviewRoomStatus.failed,
        count: count,
        queue: queue,
        idx: idx,
        errMsg: prepared.error,
      );
    }
    return ReviewRoomView(
      status: ReviewRoomStatus.ready,
      count: count,
      queue: queue,
      idx: idx,
      conteudo: prepared.conteudo,
    );
  }

  ReviewRoomView selectLetter(ReviewRoomView view, AnswerLetter letra) {
    return view.copyWith(status: ReviewRoomStatus.answering, letra: letra);
  }

  ReviewRoomView answerReviewRoom(
    ReviewRoomContext context,
    ReviewRoomView view,
    DecisionSignal sinal,
  ) {
    final conteudo = view.conteudo;
    final letra = view.letra;
    final marker = view.idx < view.queue.length ? view.queue[view.idx] : null;
    if (conteudo == null || letra == null || marker == null) {
      return view.copyWith(
        status: ReviewRoomStatus.failed,
        errMsg: 'review answer missing data',
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
      source: 'review:${view.idx}',
    );
    return view.copyWith(
      status: ReviewRoomStatus.result,
      sinal: sinal,
      resultCorrect: letra == conteudo.correctAnswer,
    );
  }

  Future<ReviewRoomView> answerServerReviewRoom(
    ReviewRoomContext context,
    ReviewRoomView view,
    DecisionSignal sinal,
  ) async {
    final server = serverReviewClient;
    final conteudo = view.conteudo;
    final letra = view.letra;
    if (server == null) return answerReviewRoom(context, view, sinal);
    if (conteudo == null || letra == null || view.queue.isEmpty) {
      return view.copyWith(
        status: ReviewRoomStatus.failed,
        errMsg: 'Resposta de revisao incompleta.',
      );
    }
    try {
      final result = await server.answer(
        ServerReviewAnswerRequest(
          lessonLocalId: context.lessonLocalId,
          reviewId: view.serverReviewId ?? view.queue.first,
          marker: view.serverMarker ?? view.queue.first,
          selectedOption: letra,
          signal: sinal,
          idempotencyKey:
              '${context.lessonLocalId}:${view.serverReviewId ?? view.queue.first}:review:${letra.name}:${sinal.value}',
          timestamp: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      return view.copyWith(
        status: result.accepted
            ? ReviewRoomStatus.result
            : ReviewRoomStatus.failed,
        sinal: sinal,
        resultCorrect: result.correct,
        errMsg: result.humanError?['message']?.toString(),
      );
    } catch (_) {
      return view.copyWith(
        status: ReviewRoomStatus.failed,
        errMsg: 'Nao consegui enviar a revisao agora. Sua aula foi preservada.',
      );
    }
  }

  Future<ReviewRoomView> nextReviewRoom(
    ReviewRoomContext context,
    ReviewRoomView view,
  ) async {
    if (serverReviewClient != null) {
      if (view.idx + 1 >= view.count) {
        service.completeReviewSession(context.lessonLocalId);
        return view.copyWith(status: ReviewRoomStatus.done, idx: view.idx + 1);
      }
      final next = await startReviewRoom(context, view.count);
      if (next.status == ReviewRoomStatus.failed &&
          next.queue.isEmpty &&
          (next.errMsg ?? '').contains('Sem revisao pendente')) {
        service.completeReviewSession(context.lessonLocalId);
        return view.copyWith(status: ReviewRoomStatus.done, idx: view.idx + 1);
      }
      return next.copyWith(idx: view.idx + 1, count: view.count);
    }
    final nextIdx = view.idx + 1;
    if (nextIdx >= view.queue.length || nextIdx >= view.count) {
      service.completeReviewSession(context.lessonLocalId);
      return view.copyWith(status: ReviewRoomStatus.done, idx: nextIdx);
    }
    return prepareReviewRoomQuestion(
      context: context,
      queue: view.queue,
      idx: nextIdx,
      count: view.count,
    );
  }

  AuxRoomContent _contentFromServer(ServerReviewItem item) {
    return AuxRoomContent(
      question: item.question,
      options: item.options,
      correctAnswer: item.correctOption,
      explanation: item.explanation,
    );
  }
}
