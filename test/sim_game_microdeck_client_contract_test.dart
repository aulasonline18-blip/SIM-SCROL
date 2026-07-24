import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/game_microdeck_client.dart';

const _sourcePath = 'lib/sim/game/game_microdeck_client.dart';

String source() => File(_sourcePath).readAsStringSync();

String token(List<String> parts) => parts.join();

GameMicrodeckRequest validRequest() => GameMicrodeckRequest(
  lessonLocalId: 'lesson-t02-microdeck-1',
  marker: 'M1',
  itemIdx: 0,
  layer: 1,
  sessionId: 'session-1',
  idempotencyKey: 'idem-1',
  targetTopic: 'equacao',
);

GameMicrodeckRequest fullIdentityRequest() => GameMicrodeckRequest(
  lessonLocalId: 'lesson-1',
  marker: 'M1',
  itemIdx: 0,
  layer: 1,
  sessionId: 'session-1',
  idempotencyKey: 'idem-1',
  item: 'equacao',
  targetTopic: 'equacao',
  mode: 'microdeck',
);

GameMicrodeckRequest requestWith({
  String? item,
  String? targetTopic,
  String? mode,
  String? learningLocale,
  String? interfaceLocale,
}) => GameMicrodeckRequest(
  lessonLocalId: 'lesson-t02-microdeck-1',
  marker: 'M1',
  itemIdx: 0,
  layer: 1,
  sessionId: 'session-1',
  idempotencyKey: 'idem-1',
  item: item,
  targetTopic: targetTopic,
  mode: mode,
  learningLocale: learningLocale,
  interfaceLocale: interfaceLocale,
);

GameMicrodeckTransportResponse response(Map<String, Object?> body) =>
    GameMicrodeckTransportResponse(body: jsonEncode(body));

Future<GameMicrodeckClientResult> fetchWith(
  Map<String, Object?> body, {
  Map<String, String>? headers,
  void Function(GameMicrodeckRequest request)? onRequest,
  void Function(GameMicrodeckAckRequest request)? onAck,
}) {
  final client = GameMicrodeckClient(
    transport: (request) async {
      onRequest?.call(request);
      return GameMicrodeckTransportResponse(
        body: jsonEncode(body),
        headers: headers,
      );
    },
    ackTransport: onAck == null
        ? null
        : (request) async {
            onAck(request);
          },
  );
  return client.requestMicrodeck(validRequest());
}

Map<String, Object?> readyBody({Map<String, Object?>? microdeck}) => {
  'status': 'ready',
  'microdeck': microdeck ?? validMicrodeckJson(),
  'operationKey': 'op-1',
  'contentHash': 'microdeck-content-hash',
  'resultHash': 'microdeck-result-hash',
  'serverSignature': 'hmac-server-signature',
  'contractVersion': 1,
  'deliveryAckRequired': true,
};

Map<String, Object?> validMicrodeckJson() => {
  'microdeckId': 'microdeck:lesson-t02-microdeck-1:M1:0:1',
  'currentIndex': 0,
  'cards': [validCardJson()],
};

Map<String, Object?> validCardJson() => {
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
  'contentHash':
      '912f27d0fed2369f60edbc7c5814786787aceaf43f1170f4440cbaf9803b1e9b',
  'contractVersion': 1,
  'serverSignature':
      '3ee9600397085f80eb812fa8cf136a95039e4905742fcbdfd717362fa98cb37e',
};

Matcher throwsClientCode(String code) => throwsA(
  isA<GameMicrodeckClientException>().having(
    (error) => error.message,
    'message',
    code,
  ),
);

void expectRequestForbidden(GameMicrodeckRequest Function() build) {
  expect(build, throwsClientCode('request_forbidden_field'));
}

Map<String, Object?> readyWithCardPatch(Map<String, Object?> patch) {
  final card = validCardJson()..addAll(patch);
  return readyBody(
    microdeck: {
      'microdeckId': 'microdeck:lesson-t02-microdeck-1:M1:0:1',
      'currentIndex': 0,
      'cards': [card],
    },
  );
}

void main() {
  test('GameMicrodeckClient e final class', () {
    expect(source(), contains('final class GameMicrodeckClient'));
  });

  test('imports produtivos sao minimos e permitidos', () {
    final imports = source()
        .split('\n')
        .where((line) => line.startsWith('import '))
        .toList();

    expect(imports, [
      "import 'dart:convert';",
      "import 'microdeck.dart';",
      "import 'pedagogical_card.dart';",
      "import 'pedagogical_card_integrity_verifier.dart';",
    ]);
  });

  test('Request monta somente campos permitidos', () {
    final body = validRequest().toJson();

    expect(body.keys, {
      'lessonLocalId',
      'marker',
      'itemIdx',
      'layer',
      'sessionId',
      'idempotencyKey',
      'contractVersion',
      'target_topic',
    });
    expect(body['lessonLocalId'], 'lesson-t02-microdeck-1');
    expect(body['target_topic'], 'equacao');
  });

  test('Request nao aceita campos perigosos nem payload livre', () {
    final text = source();

    for (final forbidden in [
      token(['pro', 'mpt']),
      token(['raw', 'Pro', 'mpt']),
      token(['system', 'Instruction']),
      token(['developer', 'Instruction']),
      token(['ad', 'endo']),
      token(['T', '00']),
      token(['T', '02']),
      token(['N', '3']),
      token(['Gem', 'ini']),
      token(['mod', 'el']),
      token(['led', 'ger']),
      token(['bill', 'ing']),
      'userId',
      'cards;',
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(validRequest().toJson().containsKey(token(['cre', 'dit'])), isFalse);
  });

  test('Request usa item String, nao payload livre', () {
    expect(source(), contains('final String? item;'));
    expect(source(), isNot(contains('final Object? item;')));
  });

  test('Request rejeita item perigoso em comportamento real', () {
    for (final value in [
      '{"prompt":"x"}',
      'T02',
      'N3',
      'Gemini',
      'model: pro',
      'credit',
      'ledger',
      'cards',
      'microdeck',
      'payload',
      '"model"',
      'model=pro',
      '{model',
      '"cost"',
      'cost:',
      'cost=',
      '"cards"',
      'cards:',
      'cards=',
      '"prompt"',
      'prompt:',
      'prompt=',
      'openai',
      'ai_model',
      'aiProvider',
      'artificial intelligence',
      'credit:',
      'ledger:',
      'billing:',
      'payload:',
      'body:',
      'providerResponse',
      'rawProviderResponse',
    ]) {
      expectRequestForbidden(() => requestWith(item: value));
    }
  });

  test('Request nao bloqueia palavras pedagogicas normais', () {
    expect(() => requestWith(item: 'mais raiz sinais'), returnsNormally);
    expect(() => requestWith(targetTopic: 'pais e sinais'), returnsNormally);
    expect(() => requestWith(item: 'baixar'), returnsNormally);
    expect(() => requestWith(item: 'mais'), returnsNormally);
    expect(() => requestWith(item: 'raiz'), returnsNormally);
    expect(() => requestWith(item: 'sinais'), returnsNormally);
    expect(() => requestWith(item: 'pais'), returnsNormally);
    expect(() => requestWith(item: 'modelo matematico'), returnsNormally);
    expect(() => requestWith(item: 'modelo atomico'), returnsNormally);
    expect(() => requestWith(item: 'custo de oportunidade'), returnsNormally);
    expect(() => requestWith(item: 'costa brasileira'), returnsNormally);
    expect(() => requestWith(item: 'cardiologia'), returnsNormally);
    expect(() => requestWith(item: 'cartas de baralho'), returnsNormally);
  });

  test('Request bloqueia tokens de IA especificos sem substring ai bruta', () {
    for (final value in [
      'openai',
      'ai_model',
      'aiProvider',
      'artificial intelligence',
      'prompt',
      'T02',
      'N3',
      'model',
      'credit',
      'ledger',
    ]) {
      expectRequestForbidden(() => requestWith(item: value));
    }
  });

  test('Request rejeita strings opcionais perigosas', () {
    expectRequestForbidden(() => requestWith(targetTopic: 'prompt'));
    expectRequestForbidden(() => requestWith(mode: 'T02'));
    expectRequestForbidden(() => requestWith(learningLocale: 'Gemini'));
    expectRequestForbidden(() => requestWith(interfaceLocale: 'ledger'));
  });

  test('Request rejeita strings opcionais grandes', () {
    expect(
      () => requestWith(item: 'x' * 1025),
      throwsClientCode('item_too_large'),
    );
    expect(
      () => requestWith(targetTopic: 'x' * 257),
      throwsClientCode('targetTopic_too_large'),
    );
    expect(
      () => requestWith(mode: 'x' * 65),
      throwsClientCode('mode_too_large'),
    );
    expect(
      () => requestWith(learningLocale: 'x' * 33),
      throwsClientCode('learningLocale_too_large'),
    );
    expect(
      () => requestWith(interfaceLocale: 'x' * 33),
      throwsClientCode('interfaceLocale_too_large'),
    );
  });

  test('Request rejeita strings opcionais blank', () {
    expect(
      () => requestWith(item: ' '),
      throwsClientCode('item_must_not_be_blank'),
    );
    expect(
      () => requestWith(targetTopic: ' '),
      throwsClientCode('targetTopic_must_not_be_blank'),
    );
    expect(
      () => requestWith(mode: ' '),
      throwsClientCode('mode_must_not_be_blank'),
    );
    expect(
      () => requestWith(learningLocale: ' '),
      throwsClientCode('learningLocale_must_not_be_blank'),
    );
    expect(
      () => requestWith(interfaceLocale: ' '),
      throwsClientCode('interfaceLocale_must_not_be_blank'),
    );
  });

  test('Request valido com strings opcionais passa', () {
    final request = requestWith(
      item: 'equacao simples',
      targetTopic: 'equacao',
      mode: 'microdeck',
      learningLocale: 'pt-BR',
      interfaceLocale: 'pt-BR',
    );

    expect(request.toJson(), {
      'lessonLocalId': 'lesson-t02-microdeck-1',
      'marker': 'M1',
      'itemIdx': 0,
      'layer': 1,
      'sessionId': 'session-1',
      'idempotencyKey': 'idem-1',
      'contractVersion': 1,
      'item': 'equacao simples',
      'target_topic': 'equacao',
      'mode': 'microdeck',
      'learningLocale': 'pt-BR',
      'interfaceLocale': 'pt-BR',
    });
  });

  test('mode usa allowlist estrita', () {
    expect(() => requestWith(mode: 'microdeck'), returnsNormally);
    expect(
      () => requestWith(mode: 'microdeck-v2'),
      throwsClientCode('mode_unsupported'),
    );
    expectRequestForbidden(() => requestWith(mode: 'microdeck payload'));
    expectRequestForbidden(() => requestWith(mode: 'T02'));
    expectRequestForbidden(() => requestWith(mode: 'prompt'));
    expectRequestForbidden(() => requestWith(mode: 'Gemini'));
    expectRequestForbidden(() => requestWith(mode: 'openai'));
    expectRequestForbidden(() => requestWith(mode: 'ai_model'));
  });

  test('ACK JSON bate com contrato real do servidor', () {
    final ack = GameMicrodeckAckRequest(
      operationKey: 'op-1',
      request: fullIdentityRequest(),
      organ: 'T02',
      route: '/api/sim-game/microdeck',
    );

    expect(ack.toJson(), {
      'organ': 'T02',
      'route': '/api/sim-game/microdeck',
      'sessionId': 'session-1',
      'idempotencyKey': 'idem-1',
      'lessonLocalId': 'lesson-1',
      'marker': 'M1',
      'itemIdx': 0,
      'layer': 1,
      'mode': 'microdeck',
      'item': 'equacao',
      'target_topic': 'equacao',
    });
    expect(ack.toJson().containsKey('operationKey'), isFalse);
    expect(ack.toJson().containsKey('contractVersion'), isFalse);
  });

  test('ACK com mode ausente usa default microdeck confirmado no servidor', () {
    final ack = GameMicrodeckAckRequest(
      operationKey: 'op-1',
      request: validRequest(),
      organ: 'T02',
      route: '/api/sim-game/microdeck',
    ).toJson();

    expect(ack['mode'], 'microdeck');
    expect(ack['item'], 'equacao');
    expect(ack['target_topic'], 'equacao');
  });

  test('ACK exige identidade minima', () {
    expect(
      () => GameMicrodeckAckRequest(
        operationKey: 'op-1',
        request: validRequest(),
        organ: ' ',
        route: '/api/sim-game/microdeck',
      ),
      throwsClientCode('organ_required'),
    );
    expect(
      () => GameMicrodeckAckRequest(
        operationKey: 'op-1',
        request: validRequest(),
        organ: 'T02',
        route: ' ',
      ),
      throwsClientCode('route_required'),
    );
    expect(
      () => GameMicrodeckRequest(
        lessonLocalId: 'lesson-t02-microdeck-1',
        marker: 'M1',
        itemIdx: 0,
        layer: 1,
        sessionId: ' ',
        idempotencyKey: 'idem-1',
      ),
      throwsClientCode('sessionId_required'),
    );
    expect(
      () => GameMicrodeckRequest(
        lessonLocalId: 'lesson-t02-microdeck-1',
        marker: 'M1',
        itemIdx: 0,
        layer: 1,
        sessionId: 'session-1',
        idempotencyKey: ' ',
      ),
      throwsClientCode('idempotencyKey_required'),
    );
  });

  test('ACK nao contem campos proibidos do endpoint real', () {
    final ack = GameMicrodeckAckRequest(
      operationKey: 'op-1',
      request: validRequest(),
      organ: 'T02',
      route: '/api/sim-game/microdeck',
    ).toJson();

    for (final forbidden in [
      'operationKey',
      'contractVersion',
      'prompt',
      'T00',
      'N3',
      'model',
      'credit',
      'ledger',
      'cost',
      'microdeck',
      'cards',
      'payload',
      'body',
    ]) {
      expect(ack.containsKey(forbidden), isFalse, reason: forbidden);
    }
  });

  test(
    'ready estrutural com HMAC falha por assinatura nao verificavel',
    () async {
      var ackCount = 0;

      await expectLater(
        fetchWith(readyBody(), onAck: (_) => ackCount++),
        throwsClientCode('signatureVerificationUnavailable'),
      );
      expect(ackCount, 0);
    },
  );

  test(
    'ready nao retorna Microdeck jogavel quando assinatura nao passa',
    () async {
      final client = GameMicrodeckClient(
        transport: (_) async => response(readyBody()),
        ackTransport: (_) async => fail('ACK nao deve ocorrer'),
      );

      await expectLater(
        client.requestMicrodeck(validRequest()),
        throwsClientCode('signatureVerificationUnavailable'),
      );
    },
  );

  test('ready sem microdeck falha', () async {
    await expectLater(
      fetchWith({...readyBody()}..remove('microdeck')),
      throwsClientCode('response_status_conflict'),
    );
  });

  test('response ready rejeita campo perigoso dentro de card', () async {
    for (final patch in [
      {'prompt': 'x'},
      {'model': 'x'},
      {'credit': 1},
      {'ledger': true},
      {'providerResponse': 'raw'},
    ]) {
      await expectLater(
        fetchWith(readyWithCardPatch(patch)),
        throwsClientCode('response_forbidden_field'),
      );
    }
  });

  test('response ready rejeita campo perigoso dentro de media', () async {
    final card = validCardJson();
    card['media'] = {'imageKey': 'image/balance.png', 'privateKey': 'secret'};

    await expectLater(
      fetchWith(
        readyBody(
          microdeck: {
            'microdeckId': 'microdeck:lesson-t02-microdeck-1:M1:0:1',
            'currentIndex': 0,
            'cards': [card],
          },
        ),
      ),
      throwsClientCode('response_forbidden_field'),
    );
  });

  test('ready sem serverSignature falha e nao envia ACK', () async {
    var ackCount = 0;

    await expectLater(
      fetchWith(
        {...readyBody()}..remove('serverSignature'),
        onAck: (_) => ackCount++,
      ),
      throwsClientCode('response_status_conflict'),
    );
    expect(ackCount, 0);
  });

  test('ready com serverSignature vazio falha', () async {
    await expectLater(
      fetchWith({...readyBody(), 'serverSignature': ' '}),
      throwsClientCode('serverSignature_required'),
    );
  });

  test('ready sem contractVersion falha e nao envia ACK', () async {
    var ackCount = 0;

    await expectLater(
      fetchWith(
        {...readyBody()}..remove('contractVersion'),
        onAck: (_) => ackCount++,
      ),
      throwsClientCode('response_status_conflict'),
    );
    expect(ackCount, 0);
  });

  test('ready com contractVersion diferente de 1 falha', () async {
    await expectLater(
      fetchWith({...readyBody(), 'contractVersion': 2}),
      throwsClientCode('contractVersion_unsupported'),
    );
  });

  test('ready com carta invalida falha e nao envia ACK', () async {
    var ackCount = 0;
    final card = validCardJson()..remove('question');

    await expectLater(
      fetchWith(
        readyBody(
          microdeck: {
            'microdeckId': 'microdeck:lesson-t02-microdeck-1:M1:0:1',
            'currentIndex': 0,
            'cards': [card],
          },
        ),
        onAck: (_) => ackCount++,
      ),
      throwsClientCode('question_required'),
    );
    expect(ackCount, 0);
  });

  test('ready com hash invalido falha e nao envia ACK', () async {
    var ackCount = 0;
    final card = validCardJson()..['contentHash'] = 'hash-invalido';

    await expectLater(
      fetchWith(
        readyBody(
          microdeck: {
            'microdeckId': 'microdeck:lesson-t02-microdeck-1:M1:0:1',
            'currentIndex': 0,
            'cards': [card],
          },
        ),
        onAck: (_) => ackCount++,
      ),
      throwsClientCode('contentHash_mismatch'),
    );
    expect(ackCount, 0);
  });

  test('ready com assinatura nao verificavel nao envia ACK', () async {
    var ackCount = 0;

    await expectLater(
      fetchWith(readyBody(), onAck: (_) => ackCount++),
      throwsClientCode('signatureVerificationUnavailable'),
    );
    expect(ackCount, 0);
  });

  test('ACK fica depois da validacao total no fonte', () {
    final text = source();
    final parseIndex = text.indexOf('final microdeck = _parseMicrodeck');
    final ackIndex = text.indexOf('await _ackTransport');

    expect(parseIndex, greaterThanOrEqualTo(0));
    expect(ackIndex, greaterThan(parseIndex));
  });

  test('running retorna preparo honesto sem microdeck', () async {
    final result = await fetchWith({'status': 'running', 'retryAfter': 7});

    expect(result.status, GameMicrodeckStatus.running);
    expect(result.isPreparing, isTrue);
    expect(result.microdeck, isNull);
    expect(result.retryAfterSeconds, 7);
  });

  test('queued retorna preparo honesto sem microdeck', () async {
    final result = await fetchWith({'status': 'queued'});

    expect(result.status, GameMicrodeckStatus.queued);
    expect(result.isPreparing, isTrue);
    expect(result.microdeck, isNull);
  });

  test('schema por status rejeita respostas contraditorias', () async {
    for (final body in [
      {'status': 'running', 'microdeck': validMicrodeckJson()},
      {'status': 'running', 'contentHash': 'hash'},
      {'status': 'queued', 'microdeck': validMicrodeckJson()},
      {'status': 'rate_limited', 'microdeck': validMicrodeckJson()},
      {'status': 'failed_retryable'},
      {'status': 'no_credit', 'microdeck': validMicrodeckJson()},
      {'status': 'failed_permanent', 'retryAfter': 3},
      {...readyBody(), 'error': 'x'},
      {...readyBody(), 'message': 'x'},
      {...readyBody(), 'retryAfter': 3},
      {...readyBody()}..remove('serverSignature'),
      {...readyBody()}..remove('contractVersion'),
    ]) {
      await expectLater(
        fetchWith(body),
        throwsClientCode('response_status_conflict'),
        reason: body.toString(),
      );
    }
  });

  test('rate_limited e failed_retryable exigem Retry-After', () async {
    await expectLater(
      fetchWith({'status': 'rate_limited'}),
      throwsClientCode('response_status_conflict'),
    );
    await expectLater(
      fetchWith({'status': 'failed_retryable'}),
      throwsClientCode('response_status_conflict'),
    );
  });

  test('rate_limited preserva Retry-After do header', () async {
    final result = await fetchWith(
      {'status': 'rate_limited'},
      headers: {'Retry-After': '11'},
    );

    expect(result.status, GameMicrodeckStatus.rateLimited);
    expect(result.microdeck, isNull);
    expect(result.retryAfterSeconds, 11);
  });

  test('failed_retryable preserva Retry-After e nao tenta de novo', () async {
    var calls = 0;
    final result = await fetchWith({
      'status': 'failed_retryable',
      'retryAfter': 13,
    }, onRequest: (_) => calls++);

    expect(result.status, GameMicrodeckStatus.failedRetryable);
    expect(result.retryAfterSeconds, 13);
    expect(result.microdeck, isNull);
    expect(calls, 1);
  });

  test('failed_permanent nao tenta de novo', () async {
    var calls = 0;
    final result = await fetchWith({
      'status': 'failed_permanent',
    }, onRequest: (_) => calls++);

    expect(result.status, GameMicrodeckStatus.failedPermanent);
    expect(result.microdeck, isNull);
    expect(calls, 1);
  });

  test('no_credit nao faz fallback', () async {
    var calls = 0;
    final result = await fetchWith({
      'status': 'no_credit',
    }, onRequest: (_) => calls++);

    expect(result.status, GameMicrodeckStatus.noCredit);
    expect(result.microdeck, isNull);
    expect(calls, 1);
  });

  test('payload desconhecido falha', () async {
    await expectLater(
      fetchWith({'status': 'running', 'unexpected': true}),
      throwsClientCode('response_unknown_field'),
    );
  });

  test('response nao rejeita texto pedagogico normal por substring', () async {
    final card = validCardJson()
      ..['explanation'] =
          'modelo matematico, custo de oportunidade e cardiologia.';

    await expectLater(
      fetchWith(
        readyBody(
          microdeck: {
            'microdeckId': 'microdeck:lesson-t02-microdeck-1:M1:0:1',
            'currentIndex': 0,
            'cards': [card],
          },
        ),
      ),
      throwsClientCode('contentHash_mismatch'),
    );
  });

  test('status desconhecido falha', () async {
    await expectLater(
      fetchWith({'status': 'cached_pedagogical'}),
      throwsClientCode('status_unknown'),
    );
  });

  test('JSON invalido falha controlado', () async {
    final client = GameMicrodeckClient(
      transport: (_) async => GameMicrodeckTransportResponse(body: '{'),
    );

    await expectLater(
      client.requestMicrodeck(validRequest()),
      throwsClientCode('invalid_json'),
    );
  });

  test('nenhum teste depende de rede real', () {
    final text = source();

    expect(text, isNot(contains('http')));
    expect(text, isNot(contains('Dio')));
    expect(text, contains('GameMicrodeckTransport'));
  });

  test('Client nao importa UI ou fluxo antigo', () {
    final text = source();

    for (final forbidden in [
      'flutter',
      'Widget',
      'BuildContext',
      'LabSession',
      'LessonRuntimeEngine',
      'ChatAulaScreen',
      'Timeline',
      'GameCardView',
      'GameClassroomScreen',
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('Client nao usa storage, banco local ou retry automatico', () {
    final text = source();

    for (final forbidden in [
      'SharedPreferences',
      'Hive',
      'Drift',
      'SQLite',
      'sqflite',
      'File(',
      'Timer',
      'Future.delayed',
      'while (true)',
      'cache',
      'worker',
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('Client nao chama IA nem cria banco ou reuso', () {
    final text = source();

    for (final forbidden in [
      token(['Open', 'AI']),
      token(['Gem', 'ini']),
      token(['card', 'Store']),
      token(['question', 'Bank']),
      token(['reuse', 'Policy']),
      token(['embedding']),
      token(['semantic']),
      token(['vector']),
      token(['ac', 'ervo']),
      token(['bypass']),
      token(['skip', 'Signature']),
      token(['allow', 'Unsigned']),
      token(['allow', 'Hash', 'Only']),
      token(['test', 'Mode']),
      token(['debug', 'Integrity']),
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
