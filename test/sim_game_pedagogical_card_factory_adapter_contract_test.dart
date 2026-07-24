import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/local_game_runtime.dart';
import 'package:sim_mobile/sim/game/microdeck.dart';
import 'package:sim_mobile/sim/game/pedagogical_card.dart';
import 'package:sim_mobile/sim/game/pedagogical_card_factory_adapter.dart';
import 'package:sim_mobile/sim/game/pedagogical_card_integrity_verifier.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _sourcePath = 'lib/sim/game/pedagogical_card_factory_adapter.dart';

String source() => File(_sourcePath).readAsStringSync();

String token(List<String> parts) => parts.join();

Map<String, Object?> completeJson({Object? media = _defaultMedia}) => {
  'lessonLocalId': 'lesson-1',
  'deckId': 'deck-1',
  'cardId': 'card-1',
  'marker': 'M1',
  'itemIdx': 0,
  'layer': 1,
  'explanation':
      'Para resolver uma equacao, isole a incognita mantendo igualdade.',
  'question': 'Qual operacao mantem a igualdade em x + 2 = 5?',
  'options': {
    'A': 'Subtrair 2 dos dois lados.',
    'B': 'Somar 5 dos dois lados.',
    'C': 'Trocar x por 2 sem calcular.',
  },
  'correctAnswer': 'A',
  'feedback': {
    'A': 'Sim. A igualdade e preservada nos dois lados.',
    'B': 'Nao. Somar 5 afasta x do isolamento.',
    'C': 'Nao. Substituir sem calcular nao preserva a igualdade.',
  },
  'qualifiers': {
    '1': 'Tenho certeza.',
    '2': 'Acho que sim, mas quero cuidado.',
    '3': 'Estou inseguro e preciso de ajuda.',
  },
  'advancePolicy': {
    '1': 'continue_with_review',
    '2': 'review_or_check',
    '3': 'support_or_new_question',
  },
  if (media != _omit)
    'media': media == _defaultMedia
        ? {'imageKey': 'image/balance.png', 'audioKey': 'audio/equation.wav'}
        : media,
  'contentHash': 'structural-hash',
  'serverSignature': 'hmac-signature',
  'generationOperationId': 'operation-1',
  'contractVersion': 1,
};

const String _omit = '__omit_media__';
const String _defaultMedia = '__default_media__';

PedagogicalCardSource completeSource({
  Map<AnswerLetter, String>? options,
  Map<AnswerLetter, String>? feedback,
  Map<DecisionSignal, String>? qualifiers,
  Map<DecisionSignal, String>? advancePolicy,
  PedagogicalCardMedia? media = const PedagogicalCardMedia(
    imageKey: 'image/balance.png',
    audioKey: 'audio/equation.wav',
  ),
  String lessonLocalId = 'lesson-1',
  String deckId = 'deck-1',
  String cardId = 'card-1',
  String marker = 'M1',
  int itemIdx = 0,
  LessonLayer layer = LessonLayer.l1,
  String explanation =
      'Para resolver uma equacao, isole a incognita mantendo igualdade.',
  String question = 'Qual operacao mantem a igualdade em x + 2 = 5?',
  AnswerLetter correctAnswer = AnswerLetter.A,
  String contentHash = 'structural-hash',
  String serverSignature = 'hmac-signature',
  String generationOperationId = 'operation-1',
  int contractVersion = 1,
}) {
  return PedagogicalCardSource(
    lessonLocalId: lessonLocalId,
    deckId: deckId,
    cardId: cardId,
    marker: marker,
    itemIdx: itemIdx,
    layer: layer,
    explanation: explanation,
    question: question,
    options:
        options ??
        {
          AnswerLetter.A: 'Subtrair 2 dos dois lados.',
          AnswerLetter.B: 'Somar 5 dos dois lados.',
          AnswerLetter.C: 'Trocar x por 2 sem calcular.',
        },
    correctAnswer: correctAnswer,
    feedback:
        feedback ??
        {
          AnswerLetter.A: 'Sim. A igualdade e preservada nos dois lados.',
          AnswerLetter.B: 'Nao. Somar 5 afasta x do isolamento.',
          AnswerLetter.C: 'Nao. Substituir sem calcular nao preserva.',
        },
    qualifiers:
        qualifiers ??
        {
          DecisionSignal.one: 'Tenho certeza.',
          DecisionSignal.two: 'Acho que sim, mas quero cuidado.',
          DecisionSignal.three: 'Estou inseguro e preciso de ajuda.',
        },
    advancePolicy:
        advancePolicy ??
        {
          DecisionSignal.one: 'continue_with_review',
          DecisionSignal.two: 'review_or_check',
          DecisionSignal.three: 'support_or_new_question',
        },
    media: media,
    contentHash: contentHash,
    serverSignature: serverSignature,
    generationOperationId: generationOperationId,
    contractVersion: contractVersion,
  );
}

PedagogicalCard structurallyAdaptedCard() {
  return const PedagogicalCardFactoryAdapter().adapt(completeSource());
}

PedagogicalCard runtimeBlockedCard() {
  final adapter = const PedagogicalCardFactoryAdapter();
  final first = adapter.adapt(completeSource());
  final hash = PedagogicalCardIntegrityVerifier.contentHashForCard(first);
  return adapter.adapt(completeSource(contentHash: hash));
}

Matcher throwsAdapterCode(String code) => throwsA(
  isA<PedagogicalCardFactoryAdapterException>().having(
    (error) => error.message,
    'message',
    code,
  ),
);

Matcher throwsLocalRuntimeCode(String code) => throwsA(
  isA<LocalGameRuntimeContractException>().having(
    (error) => error.message,
    'message',
    code,
  ),
);

Matcher throwsMicrodeckCode(String code) => throwsA(
  isA<MicrodeckContractException>().having(
    (error) => error.message,
    'message',
    code,
  ),
);

Matcher throwsIntegrityCode(String code) => throwsA(
  isA<PedagogicalCardIntegrityException>().having(
    (error) => error.message,
    'message',
    code,
  ),
);

void expectJsonPatchFails(
  void Function(Map<String, Object?> json) mutate,
  String code,
) {
  final json = completeJson();
  mutate(json);
  expect(() => PedagogicalCardSource.fromJson(json), throwsAdapterCode(code));
}

void main() {
  test('PedagogicalCardFactoryAdapter e final class', () {
    expect(source(), contains('final class PedagogicalCardFactoryAdapter'));
  });

  test('imports produtivos sao minimos', () {
    final imports = source()
        .split('\n')
        .where((line) => line.startsWith('import '))
        .toList();

    expect(imports, [
      "import '../state/student_learning_state.dart';",
      "import 'pedagogical_card.dart';",
    ]);
  });

  test('material completo vira PedagogicalCard estrutural', () {
    final card = structurallyAdaptedCard();

    expect(card, isA<PedagogicalCard>());
    expect(card.lessonLocalId, 'lesson-1');
    expect(card.options[AnswerLetter.A], isNotEmpty);
    expect(card.feedback[AnswerLetter.B], isNotEmpty);
    expect(card.qualifiers[DecisionSignal.three], isNotEmpty);
    expect(card.advancePolicy[DecisionSignal.one], isNotEmpty);
    expect(card.layer, LessonLayer.l1);
    expect(card.media?.imageKey, 'image/balance.png');
    expect(card.media?.audioKey, 'audio/equation.wav');
    expect(card.isValid, isTrue);
  });

  test('usa tipos oficiais de resposta sinal e camada', () {
    final text = source();

    expect(text, contains('AnswerLetter'));
    expect(text, contains('DecisionSignal'));
    expect(text, contains('LessonLayer'));
    expect(text, isNot(contains('GameAnswer')));
    expect(text, isNot(contains('AnswerSignal')));
    expect(text, isNot(contains('LayerValue')));
  });

  test('campos obrigatorios ausentes falham', () {
    expectJsonPatchFails(
      (json) => json['lessonLocalId'] = ' ',
      'lessonLocalId_required',
    );
    expectJsonPatchFails((json) => json['deckId'] = ' ', 'deckId_required');
    expectJsonPatchFails((json) => json['cardId'] = ' ', 'cardId_required');
    expectJsonPatchFails((json) => json['marker'] = ' ', 'marker_required');
    expectJsonPatchFails(
      (json) => json['itemIdx'] = -1,
      'itemIdx_must_be_nonnegative',
    );
    expectJsonPatchFails((json) => json['layer'] = 4, 'layer_must_be_1_2_or_3');
    expectJsonPatchFails(
      (json) => json['explanation'] = ' ',
      'explanation_required',
    );
    expectJsonPatchFails((json) => json['question'] = ' ', 'question_required');
    expectJsonPatchFails(
      (json) => json['contentHash'] = ' ',
      'contentHash_required',
    );
    expectJsonPatchFails(
      (json) => json['serverSignature'] = ' ',
      'serverSignature_required',
    );
    expectJsonPatchFails(
      (json) => json['generationOperationId'] = ' ',
      'generationOperationId_required',
    );
    expectJsonPatchFails(
      (json) => json['contractVersion'] = 2,
      'contractVersion_unsupported',
    );
  });

  test('options A B C sao obrigatorias e nao vazias', () {
    expectJsonPatchFails(
      (json) => (json['options']! as Map).remove('A'),
      'options_A_required',
    );
    expectJsonPatchFails(
      (json) => (json['options']! as Map).remove('B'),
      'options_B_required',
    );
    expectJsonPatchFails(
      (json) => (json['options']! as Map).remove('C'),
      'options_C_required',
    );
    expectJsonPatchFails(
      (json) => (json['options']! as Map)['A'] = ' ',
      'options_A_required',
    );
  });

  test('correctAnswer e A B ou C obrigatorio', () {
    expectJsonPatchFails(
      (json) => json.remove('correctAnswer'),
      'correctAnswer_must_be_A_B_or_C',
    );
    expectJsonPatchFails(
      (json) => json['correctAnswer'] = 'D',
      'correctAnswer_must_be_A_B_or_C',
    );
  });

  test('feedback A B C e obrigatorio e nao vazio', () {
    expectJsonPatchFails(
      (json) => (json['feedback']! as Map).remove('A'),
      'feedback_A_required',
    );
    expectJsonPatchFails(
      (json) => (json['feedback']! as Map).remove('B'),
      'feedback_B_required',
    );
    expectJsonPatchFails(
      (json) => (json['feedback']! as Map).remove('C'),
      'feedback_C_required',
    );
    expectJsonPatchFails(
      (json) => (json['feedback']! as Map)['A'] = ' ',
      'feedback_A_required',
    );
  });

  test('qualifiers 1 2 3 sao obrigatorios e nao vazios', () {
    expectJsonPatchFails(
      (json) => (json['qualifiers']! as Map).remove('1'),
      'qualifiers_1_required',
    );
    expectJsonPatchFails(
      (json) => (json['qualifiers']! as Map).remove('2'),
      'qualifiers_2_required',
    );
    expectJsonPatchFails(
      (json) => (json['qualifiers']! as Map).remove('3'),
      'qualifiers_3_required',
    );
    expectJsonPatchFails(
      (json) => (json['qualifiers']! as Map)['1'] = ' ',
      'qualifiers_1_required',
    );
  });

  test('advancePolicy 1 2 3 e obrigatorio e nao vazio', () {
    expectJsonPatchFails(
      (json) => (json['advancePolicy']! as Map).remove('1'),
      'advancePolicy_1_required',
    );
    expectJsonPatchFails(
      (json) => (json['advancePolicy']! as Map).remove('2'),
      'advancePolicy_2_required',
    );
    expectJsonPatchFails(
      (json) => (json['advancePolicy']! as Map).remove('3'),
      'advancePolicy_3_required',
    );
    expectJsonPatchFails(
      (json) => (json['advancePolicy']! as Map)['1'] = ' ',
      'advancePolicy_1_required',
    );
  });

  test('midia null e chaves leves passam', () {
    final withoutMedia = PedagogicalCardSource.fromJson(
      completeJson(media: null),
    );
    final omittedMedia = PedagogicalCardSource.fromJson(
      completeJson(media: _omit),
    );
    final withMedia = PedagogicalCardSource.fromJson(completeJson());

    expect(withoutMedia.media, isNull);
    expect(omittedMedia.media, isNull);
    expect(withMedia.media?.imageKey, 'image/balance.png');
    expect(withMedia.media?.audioKey, 'audio/equation.wav');
  });

  test('midia pesada ou inline falha', () {
    for (final value in [
      'data:image/png;base64,abc',
      'base64,abc',
      '<svg></svg>',
      '<xml></xml>',
      '<?xml version="1.0"?>',
      '<html></html>',
      'http://example.test/image.png',
      'https://example.test/image.png',
      'x' * 513,
    ]) {
      expectJsonPatchFails(
        (json) => json['media'] = {'imageKey': value},
        value.length > PedagogicalCardMedia.maxKeyLength
            ? 'imageKey_too_large'
            : 'imageKey_must_be_light_key',
      );
    }
  });

  test('campo extra no JSON falha', () {
    expectJsonPatchFails((json) => json['extra'] = true, 'unknown_field');
    expectJsonPatchFails(
      (json) => (json['options']! as Map)['D'] = 'x',
      'unknown_field',
    );
    expectJsonPatchFails(
      (json) => (json['media']! as Map)['inline'] = 'x',
      'unknown_field',
    );
  });

  test('adapter nao chama validacao de integridade jogavel', () {
    final card = structurallyAdaptedCard();

    expect(card.contentHash, 'structural-hash');
    expect(
      () => PedagogicalCardIntegrityVerifier.verifyContentHash(card),
      throwsIntegrityCode('contentHash_mismatch'),
    );
    expect(source(), isNot(contains('verifyForRuntime')));
  });

  test('carta criada ainda falha no runtime com assinatura HMAC atual', () {
    final card = runtimeBlockedCard();

    expect(
      () => LocalGameRuntime(card),
      throwsIntegrityCode('signatureVerificationUnavailable'),
    );
  });

  test('microdeck tambem rejeita carta adaptada nao verificavel', () {
    final card = runtimeBlockedCard();

    expect(
      () => Microdeck(microdeckId: 'deck-1', cards: [card], currentIndex: 0),
      throwsIntegrityCode('signatureVerificationUnavailable'),
    );
  });

  test(
    'arquivo produtivo nao importa app antigo UI rede storage ou servidor',
    () {
      final text = source();

      for (final forbidden in [
        'LabSession',
        'LessonRuntimeEngine',
        'ChatAulaScreen',
        'BuildContext',
        'Widget',
        'Dio',
        'fetch',
        'client.post',
        'SharedPreferences',
        'storage',
        'cache',
      ]) {
        expect(text, isNot(contains(forbidden)), reason: forbidden);
      }
      expect(text, isNot(contains(['ht', 'tp'].join())));
    },
  );

  test('arquivo produtivo nao contem IA custo prompt ou orgao novo', () {
    final text = source();

    for (final forbidden in [
      token(['Gem', 'ini']),
      token(['Open', 'AI']),
      token(['T', '00']),
      token(['T', '02']),
      token(['N', '3']),
      token(['pro', 'mpt']),
      token(['ad', 'endo']),
      token(['cre', 'dit']),
      token(['led', 'ger']),
      token(['co', 'st']),
      token(['bill', 'ing']),
      token(['fall', 'back']),
      token(['de', 'fault']),
      'Resposta correta',
      token(['rein', 'force']),
      token(['re', 'forço']),
      token(['re', 'forco']),
      token(['card', 'Store']),
      token(['question', 'Bank']),
      token(['reuse', 'Policy']),
      token(['embed', 'ding']),
      token(['seman', 'tic']),
      token(['vec', 'tor']),
      token(['ac', 'ervo']),
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
