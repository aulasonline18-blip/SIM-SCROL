import '../state/student_learning_state.dart';
import 'pedagogical_card.dart';
import 'pedagogical_card_integrity_verifier.dart';

class LocalGameRuntimeContractException implements Exception {
  const LocalGameRuntimeContractException(this.message);

  final String message;

  @override
  String toString() => 'LocalGameRuntimeContractException: $message';
}

enum _LocalGameRuntimePhase { ready, answerSelected, completed }

class LocalGameRuntime {
  LocalGameRuntime(PedagogicalCard card) : _card = card {
    PedagogicalCardIntegrityVerifier.verifyForRuntime(_card);
  }

  PedagogicalCard _card;
  AnswerLetter? _selectedAnswer;
  DecisionSignal? _selectedQualifier;
  bool? _wasCorrect;
  String? _feedbackText;
  bool _feedbackVisible = false;
  bool _completed = false;
  _LocalGameRuntimePhase _phase = _LocalGameRuntimePhase.ready;

  PedagogicalCard get card => _card;
  AnswerLetter? get selectedAnswer => _selectedAnswer;
  DecisionSignal? get selectedQualifier => _selectedQualifier;
  bool? get wasCorrect => _wasCorrect;
  String? get feedbackText => _feedbackText;
  bool get feedbackVisible => _feedbackVisible;
  bool get completed => _completed;
  bool get isReady => _phase == _LocalGameRuntimePhase.ready;
  bool get hasSelectedAnswer => _selectedAnswer != null;
  bool get canShowQualifiers =>
      _selectedAnswer != null && !_feedbackVisible && !_completed;
  bool get canShowFeedback => _feedbackVisible;

  void selectAnswer(AnswerLetter answer) {
    if (_feedbackVisible || _completed) {
      throw const LocalGameRuntimeContractException(
        'answer_locked_after_feedback',
      );
    }
    if (!_card.options.containsKey(answer)) {
      throw const LocalGameRuntimeContractException('answer_must_be_A_B_or_C');
    }

    _selectedAnswer = answer;
    _selectedQualifier = null;
    _wasCorrect = null;
    _feedbackText = null;
    _feedbackVisible = false;
    _completed = false;
    _phase = _LocalGameRuntimePhase.answerSelected;
  }

  void selectQualifier(DecisionSignal signal) {
    if (_selectedAnswer == null) {
      throw const LocalGameRuntimeContractException(
        'answer_required_before_qualifier',
      );
    }

    if (!_card.qualifiers.containsKey(signal)) {
      throw const LocalGameRuntimeContractException(
        'qualifier_must_be_1_2_or_3',
      );
    }

    final feedback = _card.feedback[_selectedAnswer];
    if (feedback == null || feedback.trim().isEmpty) {
      throw const LocalGameRuntimeContractException('feedback_missing');
    }

    _selectedQualifier = signal;
    _wasCorrect = _selectedAnswer == _card.correctAnswer;
    _feedbackText = feedback;
    _feedbackVisible = true;
    _completed = true;
    _phase = _LocalGameRuntimePhase.completed;
  }

  void resetWithCard(PedagogicalCard card) {
    PedagogicalCardIntegrityVerifier.verifyForRuntime(card);
    _card = card;
    _selectedAnswer = null;
    _selectedQualifier = null;
    _wasCorrect = null;
    _feedbackText = null;
    _feedbackVisible = false;
    _completed = false;
    _phase = _LocalGameRuntimePhase.ready;
  }
}
