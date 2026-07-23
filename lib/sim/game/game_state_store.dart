import '../state/student_learning_state.dart';
import 'local_game_runtime.dart';
import 'microdeck.dart';
import 'pedagogical_card.dart';
import 'pedagogical_event.dart';
import 'pedagogical_event_log.dart';

final class GameStateStore {
  Microdeck? _microdeck;
  LocalGameRuntime? _runtime;
  PedagogicalEventLog _eventLog = PedagogicalEventLog();
  bool _needsMicrodeck = true;
  int _nextSequence = 0;

  PedagogicalEventLog get eventLog => PedagogicalEventLog(_eventLog.events);
  PedagogicalCard? get currentCard =>
      _needsMicrodeck || _runtime == null ? null : _runtime!.card;
  String? get currentCardId => currentCard?.cardId;
  int? get currentIndex => _needsMicrodeck ? null : _microdeck?.currentIndex;
  AnswerLetter? get selectedAnswer => _runtime?.selectedAnswer;
  DecisionSignal? get selectedQualifier => _runtime?.selectedQualifier;
  String? get feedbackText => _runtime?.feedbackText;
  bool get hasPlayableCard => currentCard != null;
  bool get needsMicrodeck => _needsMicrodeck;
  bool get canSelectAnswer => hasPlayableCard && !_runtime!.completed;
  bool get canSelectQualifier => hasPlayableCard && _runtime!.canShowQualifiers;
  bool get canShowFeedback => hasPlayableCard && _runtime!.canShowFeedback;

  void loadMicrodeck(Microdeck microdeck, {required int clientTimestampMs}) {
    if (hasPlayableCard && !_needsMicrodeck) {
      throw StateError('active_game_must_not_be_replaced');
    }
    microdeck.validate();
    final card = microdeck.currentCard;
    final sequence = _nextSequence;
    final candidateLog = PedagogicalEventLog(_eventLog.events)
      ..append(
        PedagogicalEvent(
          eventId: 'game-state:$sequence:cardSeen:${card.cardId}',
          lessonLocalId: card.lessonLocalId,
          deckId: card.deckId,
          cardId: card.cardId,
          contentHash: card.contentHash,
          type: PedagogicalEventType.cardSeen,
          sequence: sequence,
          clientTimestampMs: clientTimestampMs,
        ),
      );
    final candidateDeck = Microdeck.fromJson(microdeck.toJson());
    final candidateRuntime = LocalGameRuntime(candidateDeck.currentCard);
    _microdeck = candidateDeck;
    _runtime = candidateRuntime;
    _needsMicrodeck = false;
    _eventLog = candidateLog;
    _nextSequence = sequence + 1;
  }

  void selectAnswer(AnswerLetter answer, {required int clientTimestampMs}) {
    if (!hasPlayableCard) {
      throw StateError('playable_card_required');
    }
    final candidateRuntime = _copyRuntime(_runtime!);
    candidateRuntime.selectAnswer(answer);
    final card = candidateRuntime.card;
    final sequence = _nextSequence;
    final candidateLog = PedagogicalEventLog(_eventLog.events)
      ..append(
        PedagogicalEvent(
          eventId: 'game-state:$sequence:answerSelected:${card.cardId}',
          lessonLocalId: card.lessonLocalId,
          deckId: card.deckId,
          cardId: card.cardId,
          contentHash: card.contentHash,
          type: PedagogicalEventType.answerSelected,
          sequence: sequence,
          clientTimestampMs: clientTimestampMs,
          answer: answer,
        ),
      );
    _runtime = candidateRuntime;
    _eventLog = candidateLog;
    _nextSequence = sequence + 1;
  }

  void selectQualifier(
    DecisionSignal signal, {
    required int clientTimestampMs,
  }) {
    if (!hasPlayableCard) {
      throw StateError('playable_card_required');
    }
    if (_runtime!.selectedAnswer == null) {
      throw StateError('answer_required_before_qualifier');
    }
    final candidateRuntime = _copyRuntime(_runtime!);
    candidateRuntime.selectQualifier(signal);
    final answer = candidateRuntime.selectedAnswer;
    if (answer == null) {
      throw StateError('answer_required_before_qualifier');
    }
    final card = candidateRuntime.card;
    var sequence = _nextSequence;
    final candidateLog = PedagogicalEventLog(_eventLog.events)
      ..append(
        PedagogicalEvent(
          eventId: 'game-state:$sequence:qualifierSelected:${card.cardId}',
          lessonLocalId: card.lessonLocalId,
          deckId: card.deckId,
          cardId: card.cardId,
          contentHash: card.contentHash,
          type: PedagogicalEventType.qualifierSelected,
          sequence: sequence,
          clientTimestampMs: clientTimestampMs,
          answer: answer,
          qualifier: signal,
        ),
      );
    sequence += 1;
    candidateLog.append(
      PedagogicalEvent(
        eventId: 'game-state:$sequence:feedbackShown:${card.cardId}',
        lessonLocalId: card.lessonLocalId,
        deckId: card.deckId,
        cardId: card.cardId,
        contentHash: card.contentHash,
        type: PedagogicalEventType.feedbackShown,
        sequence: sequence,
        clientTimestampMs: clientTimestampMs,
        answer: answer,
        qualifier: signal,
      ),
    );
    _runtime = candidateRuntime;
    _eventLog = candidateLog;
    _nextSequence = sequence + 1;
  }

  void advanceToNextCard({required int clientTimestampMs}) {
    if (!hasPlayableCard) {
      throw StateError('playable_card_required');
    }
    final activeDeck = _microdeck;
    if (activeDeck == null) {
      throw StateError('microdeck_required');
    }
    if (!activeDeck.hasNext) {
      _runtime = null;
      _needsMicrodeck = true;
      return;
    }
    final candidateDeck = Microdeck.fromJson(activeDeck.toJson());
    final oldCard = candidateDeck.currentCard;
    var sequence = _nextSequence;
    final candidateLog = PedagogicalEventLog(_eventLog.events)
      ..append(
        PedagogicalEvent(
          eventId: 'game-state:$sequence:cardAdvanced:${oldCard.cardId}',
          lessonLocalId: oldCard.lessonLocalId,
          deckId: oldCard.deckId,
          cardId: oldCard.cardId,
          contentHash: oldCard.contentHash,
          type: PedagogicalEventType.cardAdvanced,
          sequence: sequence,
          clientTimestampMs: clientTimestampMs,
        ),
      );
    sequence += 1;
    candidateDeck.advance();
    final card = candidateDeck.currentCard;
    candidateLog.append(
      PedagogicalEvent(
        eventId: 'game-state:$sequence:cardSeen:${card.cardId}',
        lessonLocalId: card.lessonLocalId,
        deckId: card.deckId,
        cardId: card.cardId,
        contentHash: card.contentHash,
        type: PedagogicalEventType.cardSeen,
        sequence: sequence,
        clientTimestampMs: clientTimestampMs,
      ),
    );
    _microdeck = candidateDeck;
    _runtime = LocalGameRuntime(card);
    _needsMicrodeck = false;
    _eventLog = candidateLog;
    _nextSequence = sequence + 1;
  }

  void clear() {
    _microdeck = null;
    _runtime = null;
    _eventLog = PedagogicalEventLog();
    _needsMicrodeck = true;
    _nextSequence = 0;
  }

  void validate() {
    _eventLog.validate();
    if (_nextSequence < 0) {
      throw StateError('nextSequence_must_be_nonnegative');
    }
    for (final event in _eventLog.events) {
      if (event.sequence >= _nextSequence) {
        throw StateError('nextSequence_must_follow_events');
      }
    }
    if (_microdeck == null) {
      if (_runtime != null || !_needsMicrodeck) {
        throw StateError('empty_store_must_need_microdeck');
      }
      return;
    }
    _microdeck!.validate();
    if (_needsMicrodeck) {
      if (_runtime != null) {
        throw StateError('runtime_must_be_empty_when_microdeck_needed');
      }
      return;
    }
    if (_runtime == null) {
      throw StateError('runtime_required_for_playable_microdeck');
    }
    if (_runtime!.card.cardId != _microdeck!.currentCard.cardId) {
      throw StateError('runtime_card_must_match_microdeck_current');
    }
  }

  Map<String, Object?> toJson() {
    validate();
    return {
      'microdeck': _microdeck?.toJson(),
      'eventLog': _eventLog.toJson(),
      'needsMicrodeck': _needsMicrodeck,
      'nextSequence': _nextSequence,
    };
  }

  static GameStateStore fromJson(Object? value) {
    if (value is! Map) {
      throw StateError('game_state_store_must_be_object');
    }
    for (final key in value.keys) {
      if (!const {
        'microdeck',
        'eventLog',
        'needsMicrodeck',
        'nextSequence',
      }.contains(key)) {
        throw StateError('game_state_store_has_unknown_key');
      }
    }
    final store = GameStateStore();
    final rawMicrodeck = value['microdeck'];
    final rawNeedsMicrodeck = value['needsMicrodeck'];
    final rawNextSequence = value['nextSequence'];
    if (rawNeedsMicrodeck is! bool) {
      throw StateError('needsMicrodeck_required');
    }
    if (rawNextSequence is! int) {
      throw StateError('nextSequence_required');
    }
    store._microdeck = rawMicrodeck == null
        ? null
        : Microdeck.fromJson(rawMicrodeck);
    store._eventLog = PedagogicalEventLog.fromJson(value['eventLog']);
    store._needsMicrodeck = rawNeedsMicrodeck;
    store._nextSequence = rawNextSequence;
    if (store._microdeck != null && !store._needsMicrodeck) {
      store._runtime = LocalGameRuntime(store._microdeck!.currentCard);
    }
    store.validate();
    return store;
  }
}

LocalGameRuntime _copyRuntime(LocalGameRuntime runtime) {
  final copy = LocalGameRuntime(runtime.card);
  final answer = runtime.selectedAnswer;
  if (answer != null) {
    copy.selectAnswer(answer);
  }
  final qualifier = runtime.selectedQualifier;
  if (qualifier != null) {
    copy.selectQualifier(qualifier);
  }
  return copy;
}
