import '../state/student_learning_state.dart';
import 'game_state_store.dart';
import 'microdeck.dart';
import 'pedagogical_card.dart';
import 'pedagogical_event_log.dart';

final class GameRuntimeController {
  GameStateStore _store = GameStateStore();

  PedagogicalCard? get currentCard => _store.currentCard;

  String? get currentCardId => _store.currentCardId;

  int? get currentIndex => _store.currentIndex;

  AnswerLetter? get selectedAnswer => _store.selectedAnswer;

  DecisionSignal? get selectedQualifier => _store.selectedQualifier;

  String? get feedbackText => _store.feedbackText;

  bool get hasPlayableCard => _store.hasPlayableCard;

  bool get needsMicrodeck => _store.needsMicrodeck;

  bool get canSelectAnswer => _store.canSelectAnswer;

  bool get canSelectQualifier => _store.canSelectQualifier;

  bool get canShowFeedback => _store.canShowFeedback;

  PedagogicalEventLog get eventLog => _store.eventLog;

  void loadMicrodeck(Microdeck microdeck, {required int clientTimestampMs}) {
    _store.loadMicrodeck(microdeck, clientTimestampMs: clientTimestampMs);
  }

  void selectAnswer(AnswerLetter answer, {required int clientTimestampMs}) {
    _store.selectAnswer(answer, clientTimestampMs: clientTimestampMs);
  }

  void selectQualifier(
    DecisionSignal signal, {
    required int clientTimestampMs,
  }) {
    _store.selectQualifier(signal, clientTimestampMs: clientTimestampMs);
  }

  void advanceToNextCard({required int clientTimestampMs}) {
    _store.advanceToNextCard(clientTimestampMs: clientTimestampMs);
  }

  void clear() {
    _store.clear();
  }

  void validate() {
    _store.validate();
  }

  Map<String, Object?> toJson() {
    validate();
    return _store.toJson();
  }

  static GameRuntimeController fromJson(Object? value) {
    final controller = GameRuntimeController();
    controller._store = GameStateStore.fromJson(value);
    controller.validate();
    return controller;
  }
}
