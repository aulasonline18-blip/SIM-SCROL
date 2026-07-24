import 'pedagogical_card.dart';
import 'pedagogical_card_integrity_verifier.dart';

class MicrodeckContractException implements Exception {
  const MicrodeckContractException(this.message);

  final String message;

  @override
  String toString() => 'MicrodeckContractException: $message';
}

class Microdeck {
  Microdeck({
    required this.microdeckId,
    required List<PedagogicalCard> cards,
    required int currentIndex,
  }) : cards = List<PedagogicalCard>.unmodifiable(cards) {
    _currentIndex = currentIndex;
    validate();
  }

  static const maxCards = 3;

  final String microdeckId;
  final List<PedagogicalCard> cards;
  late int _currentIndex;

  int get currentIndex => _currentIndex;

  PedagogicalCard get currentCard {
    if (!hasCurrent) {
      throw const MicrodeckContractException('currentCard_unavailable');
    }
    return cards[_currentIndex];
  }

  PedagogicalCard? get nextCard => hasNext ? cards[_currentIndex + 1] : null;

  List<PedagogicalCard> get reserveCards {
    final start = _currentIndex + 2;
    if (start >= cards.length) {
      return const [];
    }
    return List<PedagogicalCard>.unmodifiable(cards.sublist(start));
  }

  bool get hasCurrent => _currentIndex >= 0 && _currentIndex < cards.length;

  bool get hasNext => _currentIndex + 1 < cards.length;

  bool get isEmpty => cards.isEmpty;

  bool get isExhausted => cards.isNotEmpty && _currentIndex == cards.length - 1;

  int get length => cards.length;

  int get remainingCount => cards.length - _currentIndex;

  bool advance() {
    validate();
    if (!hasNext) {
      return false;
    }
    _currentIndex += 1;
    return true;
  }

  void reset() {
    validate();
    _currentIndex = 0;
  }

  PedagogicalCard cardAt(int index) {
    if (index < 0 || index >= cards.length) {
      throw const MicrodeckContractException('cardAt_index_out_of_range');
    }
    return cards[index];
  }

  void validate() {
    _requiredString(microdeckId, 'microdeckId_required');
    if (cards.isEmpty) {
      throw const MicrodeckContractException('cards_required');
    }
    if (cards.length > maxCards) {
      throw const MicrodeckContractException(
        'microdeck_must_have_at_most_3_cards',
      );
    }

    final cardIds = <String>{};
    final deckId = cards.first.deckId;
    final lessonLocalId = cards.first.lessonLocalId;

    for (final card in cards) {
      PedagogicalCardIntegrityVerifier.verifyForRuntime(card);
      if (!cardIds.add(card.cardId)) {
        throw const MicrodeckContractException('cardId_duplicated');
      }
      if (card.deckId != deckId) {
        throw const MicrodeckContractException('deckId_must_match');
      }
      if (card.lessonLocalId != lessonLocalId) {
        throw const MicrodeckContractException('lessonLocalId_must_match');
      }
    }

    if (_currentIndex < 0) {
      throw const MicrodeckContractException(
        'currentIndex_must_be_nonnegative',
      );
    }
    if (_currentIndex >= cards.length) {
      throw const MicrodeckContractException('currentIndex_out_of_range');
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'microdeckId': microdeckId,
      'cards': cards.map((card) => card.toJson()).toList(),
      'currentIndex': _currentIndex,
    };
  }

  static Microdeck fromJson(Object? value) {
    if (value is! Map) {
      throw const MicrodeckContractException('microdeck_must_be_object');
    }
    return Microdeck(
      microdeckId: _requiredString(
        value['microdeckId'],
        'microdeckId_required',
      ),
      cards: _parseCards(value['cards']),
      currentIndex: _requiredInt(value['currentIndex']),
    );
  }
}

String _requiredString(Object? value, String message) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    throw MicrodeckContractException(message);
  }
  return text;
}

int _requiredInt(Object? value) {
  if (value is int) {
    return value;
  }
  throw const MicrodeckContractException('currentIndex_required');
}

List<PedagogicalCard> _parseCards(Object? value) {
  if (value is! List) {
    throw const MicrodeckContractException('cards_required');
  }
  return value.map(PedagogicalCard.fromJson).toList();
}
