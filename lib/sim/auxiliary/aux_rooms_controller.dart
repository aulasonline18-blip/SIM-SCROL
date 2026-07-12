import '../state/student_learning_state.dart';
import 'aux_room_models.dart';
import 'recovery_room_service.dart';
import 'review_room_service.dart';

class AuxRoomsController {
  AuxRoomsController({
    required this.reviewRoomService,
    required this.recoveryRoomService,
  }) : review = reviewRoomService.createReviewChoiceView();

  final ReviewRoomService reviewRoomService;
  final RecoveryRoomService recoveryRoomService;
  ReviewRoomView review;
  RecoveryRoomView? recovery;

  void openReviewChoice() {
    review = reviewRoomService.createReviewChoiceView();
  }

  Future<void> startReview(ReviewRoomContext context, int count) async {
    review = const ReviewRoomView(
      status: ReviewRoomStatus.preparing,
      count: 5,
      queue: [],
      idx: 0,
    );
    review = await reviewRoomService.startReviewRoom(context, count);
  }

  void reviewSelecionar(AnswerLetter letter) {
    review = reviewRoomService.selectLetter(review, letter);
  }

  Future<void> reviewEnviarSinal(
    ReviewRoomContext context,
    DecisionSignal signal,
  ) async {
    if (reviewRoomService.serverReviewClient == null) {
      review = reviewRoomService.answerReviewRoom(context, review, signal);
      return;
    }
    review = await reviewRoomService.answerServerReviewRoom(
      context,
      review,
      signal,
    );
  }

  Future<void> reviewNext(ReviewRoomContext context) async {
    review = await reviewRoomService.nextReviewRoom(context, review);
  }

  void closeReview() {
    review = reviewRoomService.createReviewChoiceView();
  }

  Future<void> startRecovery(RecoveryRoomContext context) async {
    recovery = const RecoveryRoomView(
      status: RecoveryRoomStatus.preparing,
      queue: [],
      idx: 0,
    );
    recovery = await recoveryRoomService.startRecoveryRoom(context);
  }

  void continueRecovery() {
    final current = recovery;
    if (current != null) {
      recovery = recoveryRoomService.continueRecovery(current);
    }
  }

  void recoverySelecionar(AnswerLetter letter) {
    final current = recovery;
    if (current != null) {
      recovery = recoveryRoomService.selectLetter(current, letter);
    }
  }

  Future<void> recoveryEnviarSinal(
    RecoveryRoomContext context,
    DecisionSignal signal,
  ) async {
    final current = recovery;
    if (current != null) {
      if (recoveryRoomService.serverRecoveryClient == null) {
        recovery = recoveryRoomService.answerRecoveryRoom(
          context,
          current,
          signal,
        );
        return;
      }
      recovery = await recoveryRoomService.answerServerRecoveryRoom(
        context,
        current,
        signal,
      );
    }
  }

  Future<void> recoveryNext(RecoveryRoomContext context) async {
    final current = recovery;
    if (current != null) {
      recovery = await recoveryRoomService.nextRecoveryRoom(context, current);
    }
  }

  void finishRecovery(String lessonLocalId) {
    final current = recovery;
    if (current != null) {
      recovery = recoveryRoomService.finishRecoveryRoom(lessonLocalId, current);
    }
  }
}
