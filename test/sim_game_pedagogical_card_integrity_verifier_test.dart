import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/local_game_runtime.dart';
import 'package:sim_mobile/sim/game/microdeck.dart';
import 'package:sim_mobile/sim/game/pedagogical_card.dart';
import 'package:sim_mobile/sim/game/pedagogical_card_integrity_verifier.dart';

void main() {
  group('PedagogicalCardIntegrityVerifier', () {
    test('hash esperado do servidor bate com carta intacta', () {
      final card = _serverFixtureCard();

      expect(
        PedagogicalCardIntegrityVerifier.contentHashForCard(card),
        _serverFixtureHash,
      );
      expect(
        () => PedagogicalCardIntegrityVerifier.verifyContentHash(card),
        returnsNormally,
      );
      expect(
        () => PedagogicalCardIntegrityVerifier.verifyForRuntime(card),
        returnsNormally,
      );
    });

    test('carta sem contentHash falha', () {
      final json = _serverFixtureJson()..remove('contentHash');

      expect(
        () => PedagogicalCard.fromJson(json),
        throwsA(isA<PedagogicalCardContractException>()),
      );
    });

    test('carta sem serverSignature falha', () {
      final json = _serverFixtureJson()..remove('serverSignature');

      expect(
        () => PedagogicalCard.fromJson(json),
        throwsA(isA<PedagogicalCardContractException>()),
      );
    });

    test('pergunta alterada falha', () {
      _expectContentHashMismatch(
        _serverFixtureJson()..['question'] = 'Pergunta adulterada?',
      );
    });

    test('alternativa A alterada falha', () {
      _expectContentHashMismatch(
        _withNestedMap('options', {'A': 'Alternativa A adulterada.'}),
      );
    });

    test('alternativa B alterada falha', () {
      _expectContentHashMismatch(
        _withNestedMap('options', {'B': 'Alternativa B adulterada.'}),
      );
    });

    test('alternativa C alterada falha', () {
      _expectContentHashMismatch(
        _withNestedMap('options', {'C': 'Alternativa C adulterada.'}),
      );
    });

    test('correctAnswer alterado falha', () {
      _expectContentHashMismatch(_serverFixtureJson()..['correctAnswer'] = 'B');
    });

    test('feedback A alterado falha', () {
      _expectContentHashMismatch(
        _withNestedMap('feedback', {'A': 'Feedback A adulterado.'}),
      );
    });

    test('feedback B alterado falha', () {
      _expectContentHashMismatch(
        _withNestedMap('feedback', {'B': 'Feedback B adulterado.'}),
      );
    });

    test('feedback C alterado falha', () {
      _expectContentHashMismatch(
        _withNestedMap('feedback', {'C': 'Feedback C adulterado.'}),
      );
    });

    test('qualifier 1 alterado falha', () {
      _expectContentHashMismatch(
        _withNestedMap('qualifiers', {'1': 'Sinal 1 adulterado.'}),
      );
    });

    test('qualifier 2 alterado falha', () {
      _expectContentHashMismatch(
        _withNestedMap('qualifiers', {'2': 'Sinal 2 adulterado.'}),
      );
    });

    test('qualifier 3 alterado falha', () {
      _expectContentHashMismatch(
        _withNestedMap('qualifiers', {'3': 'Sinal 3 adulterado.'}),
      );
    });

    test('advancePolicy alterado falha', () {
      _expectContentHashMismatch(
        _withNestedMap('advancePolicy', {'2': 'advance_adulterado'}),
      );
    });

    test('imageKey alterado falha', () {
      _expectContentHashMismatch(
        _withNestedMap('media', {'imageKey': 'image/adulterada.png'}),
      );
    });

    test('audioKey alterado falha', () {
      _expectContentHashMismatch(
        _withNestedMap('media', {'audioKey': 'audio/adulterado.wav'}),
      );
    });

    test('ordem dos campos nao altera hash', () {
      final original = _serverFixtureJson();
      final reversed = Map<String, Object?>.fromEntries(
        original.entries.toList().reversed,
      );

      expect(
        PedagogicalCardIntegrityVerifier.contentHashForCard(
          PedagogicalCard.fromJson(original),
        ),
        PedagogicalCardIntegrityVerifier.contentHashForCard(
          PedagogicalCard.fromJson(reversed),
        ),
      );
      expect(
        PedagogicalCardIntegrityVerifier.stableStringifyForTest({
          'b': 2,
          'a': 1,
        }),
        PedagogicalCardIntegrityVerifier.stableStringifyForTest({
          'a': 1,
          'b': 2,
        }),
      );
    });

    test('campo ausente obrigatorio falha', () {
      final json = _serverFixtureJson()..remove('question');

      expect(
        () => PedagogicalCard.fromJson(json),
        throwsA(isA<PedagogicalCardContractException>()),
      );
    });

    test('campo extra nao vira autoridade do hash', () {
      final json = _serverFixtureJson()..['authorityPatch'] = 'ignore-me';
      final card = PedagogicalCard.fromJson(json);

      expect(
        PedagogicalCardIntegrityVerifier.contentHashForCard(card),
        _serverFixtureHash,
      );
    });

    test('assinatura real fica bloqueada sem chave publica verificavel', () {
      final card = _serverFixtureCard();

      expect(
        () => PedagogicalCardIntegrityVerifier.verifyServerSignature(card),
        throwsA(
          isA<PedagogicalCardIntegrityException>().having(
            (error) => error.message,
            'message',
            'signatureVerificationUnavailable',
          ),
        ),
      );
    });

    test('LocalGameRuntime rejeita carta corrompida', () {
      final card = PedagogicalCard.fromJson(
        _serverFixtureJson()..['question'] = 'Pergunta adulterada?',
      );

      expect(
        () => LocalGameRuntime(card),
        throwsA(isA<PedagogicalCardIntegrityException>()),
      );
    });

    test('Microdeck rejeita carta corrompida', () {
      final card = PedagogicalCard.fromJson(
        _serverFixtureJson()..['question'] = 'Pergunta adulterada?',
      );

      expect(
        () => Microdeck(
          microdeckId: 'microdeck:lesson-t02-microdeck-1:M1:0:1',
          cards: [card],
          currentIndex: 0,
        ),
        throwsA(isA<PedagogicalCardIntegrityException>()),
      );
    });

    test('verificador produtivo nao contem segredo nem validacao falsa', () {
      final source = File(
        'lib/sim/game/pedagogical_card_integrity_verifier.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('SIM_GAME_SERVER_SIGNATURE_SECRET')));
      expect(source, isNot(contains('privateKey')));
      expect(source, isNot(contains('private_key')));
      expect(source, isNot(contains('HMAC')));
      expect(source, isNot(contains('createHmac')));
      expect(source, isNot(contains('signature.length')));
      expect(source, contains('signatureVerificationUnavailable'));
    });

    test('verificador produtivo nao importa rede storage UI ou servidor', () {
      final source = File(
        'lib/sim/game/pedagogical_card_integrity_verifier.dart',
      ).readAsStringSync();
      final imports = source
          .split('\n')
          .where((line) => line.startsWith('import '))
          .toList();

      expect(imports, [
        "import 'dart:convert';",
        "import 'package:cryptography/dart.dart';",
        "import '../state/student_learning_state.dart';",
        "import 'pedagogical_card.dart';",
      ]);
      for (final forbidden in [
        'http',
        'Dio',
        'SharedPreferences',
        'LabSession',
        'LessonRuntimeEngine',
        'ChatAulaScreen',
        'ledger',
        'credit',
        'credito',
        'prompt',
        'T00',
        'T02',
        'N3',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}

const _serverFixtureHash =
    '912f27d0fed2369f60edbc7c5814786787aceaf43f1170f4440cbaf9803b1e9b';

Map<String, Object?> _serverFixtureJson() =>
    jsonDecode(jsonEncode(_serverFixtureSource())) as Map<String, Object?>;

Map<String, Object?> _serverFixtureSource() => {
  'cardId': 'microdeck:lesson-t02-microdeck-1:M1:0:1:card:0',
  'deckId': 'microdeck:lesson-t02-microdeck-1:M1:0:1',
  'lessonLocalId': 'lesson-t02-microdeck-1',
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
    'A': 'Feedback especifico da alternativa A.',
    'B': 'Feedback especifico da alternativa B.',
    'C': 'Feedback especifico da alternativa C.',
  },
  'qualifiers': {
    '1': 'Tenho certeza.',
    '2': 'Acho que sim / quero cuidado.',
    '3': 'Estou inseguro / preciso de ajuda.',
  },
  'advancePolicy': {
    '1': 'continue_with_review',
    '2': 'review_or_check',
    '3': 'support_or_new_question',
  },
  'media': {'imageKey': 'image/balance.png', 'audioKey': 'audio/equation.wav'},
  'contentHash': _serverFixtureHash,
  'contractVersion': PedagogicalCard.supportedContractVersion,
  'serverSignature':
      '3ee9600397085f80eb812fa8cf136a95039e4905742fcbdfd717362fa98cb37e',
};

PedagogicalCard _serverFixtureCard() =>
    PedagogicalCard.fromJson(_serverFixtureJson());

Map<String, Object?> _withNestedMap(
  String key,
  Map<String, Object?> replacement,
) {
  final json = _serverFixtureJson();
  final nested = Map<String, Object?>.from(json[key]! as Map);
  nested.addAll(replacement);
  json[key] = nested;
  return json;
}

void _expectContentHashMismatch(Map<String, Object?> json) {
  final card = PedagogicalCard.fromJson(json);

  expect(
    () => PedagogicalCardIntegrityVerifier.verifyContentHash(card),
    throwsA(
      isA<PedagogicalCardIntegrityException>().having(
        (error) => error.message,
        'message',
        'contentHash_mismatch',
      ),
    ),
  );
}
