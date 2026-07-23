import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/pedagogical_card.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _sourcePath = 'lib/sim/game/pedagogical_card.dart';

PedagogicalCard validCard({PedagogicalCardMedia? media}) => PedagogicalCard(
  cardId: 'card-1',
  deckId: 'deck-1',
  lessonLocalId: 'lesson-1',
  marker: 'm1',
  itemIdx: 0,
  layer: LessonLayer.l1,
  explanation: 'Explicacao curta.',
  question: 'Qual alternativa representa a ideia?',
  options: const {
    AnswerLetter.A: 'Alternativa A',
    AnswerLetter.B: 'Alternativa B',
    AnswerLetter.C: 'Alternativa C',
  },
  correctAnswer: AnswerLetter.A,
  feedback: const {
    AnswerLetter.A: 'A preserva a ideia principal.',
    AnswerLetter.B: 'B troca o conceito.',
    AnswerLetter.C: 'C falta uma parte essencial.',
  },
  qualifiers: const {
    DecisionSignal.one: 'Tenho certeza.',
    DecisionSignal.two: 'Acho que sim.',
    DecisionSignal.three: 'Estou inseguro.',
  },
  advancePolicy: const {
    DecisionSignal.one: 'seguir_com_evidencia',
    DecisionSignal.two: 'seguir_com_cuidado',
    DecisionSignal.three: 'nao_consolidar',
  },
  contentHash: 'hash-123',
  contractVersion: PedagogicalCard.supportedContractVersion,
  serverSignature: 'sig-123',
  media: media,
);

Map<String, dynamic> validJson({PedagogicalCardMedia? media}) =>
    validCard(media: media).toJson();

void expectContractFailure(void Function() run, String reason) {
  expect(run, throwsA(isA<PedagogicalCardContractException>()), reason: reason);
}

String importLines(String source) => source
    .split('\n')
    .where((line) => line.trimLeft().startsWith('import '))
    .join('\n');

String sourceWithoutLineComments(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

String token(List<String> parts) => parts.join();

void main() {
  test('carta valida passa', () {
    final card = validCard(
      media: const PedagogicalCardMedia(
        imageKey: 'image/card-1.png',
        audioKey: 'audio/card-1.wav',
      ),
    );

    expect(card.isValid, isTrue);
    expect(card.correctAnswer, AnswerLetter.A);
    expect(card.layer, LessonLayer.l1);
    expect(card.qualifiers.keys, containsAll(DecisionSignal.values));
  });

  test('usa tipo oficial de alternativa', () {
    final source = File(_sourcePath).readAsStringSync();

    expect(validCard().correctAnswer, isA<AnswerLetter>());
    expect(source, contains('AnswerLetter'));
    expect(source, isNot(contains(token(['Pedagogical', 'Answer']))));
  });

  test('usa tipo oficial de camada', () {
    final source = File(_sourcePath).readAsStringSync();

    expect(validCard().layer, isA<LessonLayer>());
    expect(source, contains('LessonLayer'));
    expect(source, isNot(contains(token(['Pedagogical', 'Layer']))));
  });

  test('sem contentHash falha', () {
    final json = validJson()..remove('contentHash');

    expectContractFailure(
      () => PedagogicalCard.fromJson(json),
      'hash do conteudo e obrigatorio',
    );
  });

  test('sem serverSignature falha', () {
    final json = validJson()..remove('serverSignature');

    expectContractFailure(
      () => PedagogicalCard.fromJson(json),
      'assinatura do servidor e obrigatoria',
    );
  });

  test('sem feedback A/B/C falha', () {
    final json = validJson()..['feedback'] = {'A': 'A ok', 'B': 'B ok'};

    expectContractFailure(
      () => PedagogicalCard.fromJson(json),
      'feedback precisa cobrir A/B/C',
    );
  });

  test('feedback vazio falha', () {
    final json = validJson()
      ..['feedback'] = {'A': 'A ok', 'B': '', 'C': 'C ok'};

    expectContractFailure(
      () => PedagogicalCard.fromJson(json),
      'feedback nao pode estar vazio',
    );
  });

  test('sem qualifier 1/2/3 falha', () {
    final json = validJson()..['qualifiers'] = {'1': 'um', '2': 'dois'};

    expectContractFailure(
      () => PedagogicalCard.fromJson(json),
      'qualificadores precisam cobrir 1/2/3',
    );
  });

  test('qualifier vazio falha', () {
    final json = validJson()
      ..['qualifiers'] = {'1': 'um', '2': '', '3': 'tres'};

    expectContractFailure(
      () => PedagogicalCard.fromJson(json),
      'qualificador nao pode estar vazio',
    );
  });

  test('sem advancePolicy 1/2/3 falha', () {
    final json = validJson()..['advancePolicy'] = {'1': 'um', '3': 'tres'};

    expectContractFailure(
      () => PedagogicalCard.fromJson(json),
      'politica estrutural precisa cobrir 1/2/3',
    );
  });

  test('advancePolicy vazio falha', () {
    final json = validJson()
      ..['advancePolicy'] = {'1': 'um', '2': '', '3': 'tres'};

    expectContractFailure(
      () => PedagogicalCard.fromJson(json),
      'politica estrutural nao pode estar vazia',
    );
  });

  test('midia data URI falha', () {
    final json = validJson()
      ..['media'] = {'imageKey': 'data:image/png;base64,abcd'};

    expectContractFailure(
      () => PedagogicalCard.fromJson(json),
      'midia precisa ser chave leve',
    );
  });

  test('midia base64 longa falha', () {
    final json = validJson()..['media'] = {'audioKey': 'a' * 513};

    expectContractFailure(
      () => PedagogicalCard.fromJson(json),
      'chave de midia nao pode ser payload',
    );
  });

  test('midia SVG XML inline falha', () {
    final jsonSvg = validJson()
      ..['media'] = {'imageKey': '<svg viewBox="0 0 1 1"></svg>'};
    final jsonXml = validJson()
      ..['media'] = {'imageKey': '<?xml version="1.0"?><xml></xml>'};

    expectContractFailure(
      () => PedagogicalCard.fromJson(jsonSvg),
      'svg inline nao e chave leve',
    );
    expectContractFailure(
      () => PedagogicalCard.fromJson(jsonXml),
      'xml inline nao e chave leve',
    );
  });

  test('toJson fromJson preserva tudo', () {
    final card = validCard(
      media: const PedagogicalCardMedia(
        imageKey: 'image/card-1.png',
        audioKey: 'audio/card-1.wav',
      ),
    );
    final decoded =
        jsonDecode(jsonEncode(card.toJson())) as Map<String, dynamic>;
    final roundtrip = PedagogicalCard.fromJson(decoded);

    expect(roundtrip.toJson(), card.toJson());
    expect(roundtrip.feedback[AnswerLetter.C], card.feedback[AnswerLetter.C]);
    expect(roundtrip.advancePolicy[DecisionSignal.three], 'nao_consolidar');
    expect(roundtrip.media?.imageKey, 'image/card-1.png');
  });

  test('modelo nao importa camada de rede', () {
    final source = File(_sourcePath).readAsStringSync();
    final imports = importLines(source);

    expect(imports, isNot(contains(token(['ht', 'tp']))));
    expect(imports, isNot(contains(token(['di', 'o']))));
    expect(imports, isNot(contains(token(['Cli', 'ent']))));
  });

  test('modelo nao referencia provedores ou custo', () {
    final source = sourceWithoutLineComments(
      File(_sourcePath).readAsStringSync(),
    );

    for (final forbidden in [
      token(['T', '00']),
      token(['T', '02']),
      token(['N', '3']),
      token(['AiCost', 'Protection', 'Gate']),
      token(['cre', 'dit']),
      token(['cre', 'dito']),
      token(['led', 'ger']),
      token(['Gem', 'ini']),
      token(['Open', 'AI']),
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('modelo nao importa UI sessao ou runtime de aula', () {
    final source = File(_sourcePath).readAsStringSync();
    final imports = importLines(source);

    for (final forbidden in [
      token(['flutter']),
      token(['Widget']),
      token(['Build', 'Context']),
      token(['Lab', 'Session']),
      token(['Lesson', 'Runtime', 'Engine']),
      token(['Shared', 'Preferences']),
      token(['Dr', 'ift']),
      token(['Ti', 'mer']),
    ]) {
      expect(imports, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
