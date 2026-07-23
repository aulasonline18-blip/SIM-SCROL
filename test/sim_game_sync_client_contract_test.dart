import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/game_sync_client.dart';
import 'package:sim_mobile/sim/game/pedagogical_event.dart';
import 'package:sim_mobile/sim/game/pedagogical_event_log.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _sourcePath = 'lib/sim/game/game_sync_client.dart';

String source() => File(_sourcePath).readAsStringSync();

String token(List<String> parts) => parts.join();

PedagogicalEvent validEvent({
  int index = 0,
  String? eventId,
  PedagogicalEventType type = PedagogicalEventType.cardSeen,
  AnswerLetter? answer,
  DecisionSignal? qualifier,
  int clientTimestampMs = 1,
}) {
  final id = eventId ?? 'event-$index';
  return PedagogicalEvent(
    eventId: id,
    lessonLocalId: 'lesson-1',
    deckId: 'deck-1',
    cardId: 'card-$index',
    contentHash: 'hash-$index',
    type: type,
    sequence: index,
    clientTimestampMs: clientTimestampMs,
    answer: answer,
    qualifier: qualifier,
  );
}

PedagogicalEvent answerEvent(int index) => validEvent(
  index: index,
  type: PedagogicalEventType.answerSelected,
  answer: AnswerLetter.A,
);

PedagogicalEvent qualifiedEvent(
  int index, {
  PedagogicalEventType type = PedagogicalEventType.qualifierSelected,
}) => validEvent(
  index: index,
  type: type,
  answer: AnswerLetter.A,
  qualifier: DecisionSignal.one,
);

PedagogicalEventLog eventLog(int count) => PedagogicalEventLog([
  for (var index = 0; index < count; index++) validEvent(index: index),
]);

List<String> eventIds(Iterable<PedagogicalEvent> events) =>
    events.map((event) => event.eventId).toList();

String eventKey(PedagogicalEvent event) => event.idempotencyKey;

Map<String, Object?> decoded(Object value) =>
    jsonDecode(jsonEncode(value)) as Map<String, Object?>;

void expectSyncFailure(void Function() run, String reason) {
  expect(
    run,
    throwsA(
      anyOf(
        isA<GameSyncContractException>(),
        isA<PedagogicalEventContractException>(),
        isA<PedagogicalEventLogContractException>(),
      ),
    ),
    reason: reason,
  );
}

void main() {
  test('GameSyncClient e final class', () {
    expect(source(), contains('final class GameSyncClient'));
  });

  test('GameSyncBatch e final class', () {
    expect(source(), contains('final class GameSyncBatch'));
  });

  test('GameSyncResult e final class', () {
    expect(source(), contains('final class GameSyncResult'));
  });

  test('GameSyncEnqueueResult e final class', () {
    expect(source(), contains('final class GameSyncEnqueueResult'));
  });

  test('arquivo produtivo possui exatamente os imports permitidos', () {
    final imports = source()
        .split('\n')
        .where((line) => line.startsWith('import '))
        .toList();

    expect(imports, [
      "import 'pedagogical_event.dart';",
      "import 'pedagogical_event_log.dart';",
    ]);
  });

  test('arquivo produtivo nao importa dependencias proibidas', () {
    final imports = source()
        .split('\n')
        .where((line) => line.startsWith('import '))
        .join('\n');

    for (final forbidden in [
      token(['game_', 'state_', 'store']),
      token(['game_', 'runtime_', 'controller']),
      token(['local_', 'game_', 'runtime']),
      token(['micro', 'deck']),
      token(['pedagogical_', 'card']),
      token(['flutter']),
    ]) {
      expect(imports, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('Batch vazio falha', () {
    expectSyncFailure(
      () => GameSyncBatch(batchId: 'batch-1', events: const [], createdAtMs: 1),
      'events obrigatorio',
    );
  });

  test('Batch com createdAtMs zero falha', () {
    expectSyncFailure(
      () => GameSyncBatch(
        batchId: 'batch-1',
        events: [validEvent()],
        createdAtMs: 0,
      ),
      'createdAtMs positivo',
    );
  });

  test('Batch com batchId vazio falha', () {
    expectSyncFailure(
      () => GameSyncBatch(batchId: ' ', events: [validEvent()], createdAtMs: 1),
      'batchId obrigatorio',
    );
  });

  test('Batch com mais de 50 eventos falha', () {
    expectSyncFailure(
      () => GameSyncBatch(
        batchId: 'batch-1',
        events: [
          for (var index = 0; index < 51; index++) validEvent(index: index),
        ],
        createdAtMs: 1,
      ),
      'limite maximo',
    );
  });

  test('Batch de 50 e valido e preserva ordem', () {
    final events = [
      for (var index = 0; index < 50; index++) validEvent(index: index),
    ];
    final batch = GameSyncBatch(
      batchId: 'batch-1',
      events: events,
      createdAtMs: 1,
    );

    expect(batch.events.length, 50);
    expect(eventIds(batch.events), eventIds(events));
  });

  test('Batch nao deduplica silenciosamente', () {
    final event = validEvent(index: 1);

    expectSyncFailure(
      () => GameSyncBatch(
        batchId: 'batch-1',
        events: [event, event],
        createdAtMs: 1,
      ),
      'duplicata deve falhar',
    );
  });

  test('Batch rejeita idempotencyKey duplicada', () {
    final first = validEvent(index: 1, eventId: 'event-a');
    final second = validEvent(index: 1, eventId: 'event-b');

    expectSyncFailure(
      () => GameSyncBatch(
        batchId: 'batch-1',
        events: [first, second],
        createdAtMs: 1,
      ),
      'idempotencyKey duplicada deve falhar',
    );
  });

  test('Batch rejeita evento invalido', () {
    expectSyncFailure(
      () => GameSyncBatch(
        batchId: 'batch-1',
        events: [validEvent(clientTimestampMs: 0)],
        createdAtMs: 1,
      ),
      'evento invalido',
    );
  });

  test('Eventos expostos no batch sao imutaveis', () {
    final batch = GameSyncBatch(
      batchId: 'batch-1',
      events: [validEvent()],
      createdAtMs: 1,
    );

    expect(
      () => batch.events.add(validEvent(index: 2)),
      throwsUnsupportedError,
    );
  });

  test('Client inicia sem pendentes', () {
    final client = GameSyncClient();

    expect(client.pendingCount, 0);
    expect(client.acceptedCount, 0);
    expect(client.pendingEvents, isEmpty);
    expect(client.acceptedEventIds, isEmpty);
    expect(client.isIdle, isTrue);
    expect(client.status, GameSyncStatus.idle);
  });

  test('enqueueFromLog adiciona eventos validos preservando ordem', () {
    final client = GameSyncClient();
    final log = PedagogicalEventLog([
      validEvent(index: 1),
      answerEvent(2),
      qualifiedEvent(3),
    ]);

    final result = client.enqueueFromLog(log);

    expect(eventIds(client.pendingEvents), ['event-1', 'event-2', 'event-3']);
    expect(result.addedEventIds, {'event-1', 'event-2', 'event-3'});
    expect(result.ignoredPendingEventIds, isEmpty);
    expect(client.status, GameSyncStatus.ready);
  });

  test('enqueueFromLog nao duplica evento ja pendente e relata', () {
    final client = GameSyncClient();
    final log = eventLog(2);

    client.enqueueFromLog(log);
    final result = client.enqueueFromLog(log);

    expect(client.pendingCount, 2);
    expect(eventIds(client.pendingEvents), ['event-0', 'event-1']);
    expect(result.addedEventIds, isEmpty);
    expect(result.ignoredPendingEventIds, {'event-0', 'event-1'});
  });

  test('enqueueFromLog nao re-enfileira evento aceito e relata', () {
    final client = GameSyncClient();
    final log = eventLog(1);
    client.enqueueFromLog(log);
    final batch = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);
    client.applyAck(batch, acceptedEventIds: {'event-0'});

    final result = client.enqueueFromLog(log);

    expect(client.pendingEvents, isEmpty);
    expect(client.acceptedEventIds, {'event-0'});
    expect(result.addedEventIds, isEmpty);
    expect(result.ignoredAcceptedEventIds, {'event-0'});
  });

  test('enqueueFromLog relata duplicata por idempotencyKey pendente', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(1));
    final duplicateKey = validEvent(index: 0, eventId: 'event-other');

    final result = client.enqueueFromLog(PedagogicalEventLog([duplicateKey]));

    expect(client.pendingCount, 1);
    expect(result.addedEventIds, isEmpty);
    expect(result.ignoredDuplicateIdempotencyKeys, {eventKey(duplicateKey)});
  });

  test('prepareBatch falha sem pendentes', () {
    expectSyncFailure(
      () => GameSyncClient().prepareBatch(batchId: 'batch-1', createdAtMs: 1),
      'sem pendentes',
    );
  });

  test('prepareBatch pega no maximo 50 eventos e nao remove pendentes', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(60));

    final batch = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);

    expect(batch.events.length, 50);
    expect(client.pendingCount, 60);
    expect(eventIds(client.pendingEvents.skip(50)), [
      for (var index = 50; index < 60; index++) 'event-$index',
    ]);
  });

  test('prepareBatch chamado duas vezes sem ACK retorna mesmos eventos', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(3));

    final first = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);
    final second = client.prepareBatch(batchId: 'batch-2', createdAtMs: 2);

    expect(eventIds(second.events), eventIds(first.events));
    expect(client.pendingCount, 3);
  });

  test('applyAck remove aceitos e mantem rejeitados pendentes', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(3));
    final batch = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);

    final result = client.applyAck(batch, acceptedEventIds: {'event-0'});

    expect(result.status, GameSyncStatus.partial);
    expect(client.acceptedEventIds, {'event-0'});
    expect(eventIds(client.pendingEvents), ['event-1', 'event-2']);
  });

  test('applyAck rejeita id que nao pertence ao batch sem alterar estado', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(2));
    final batch = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);
    final beforePending = eventIds(client.pendingEvents);
    final beforeAccepted = Set<String>.of(client.acceptedEventIds);

    expectSyncFailure(
      () => client.applyAck(batch, acceptedEventIds: {'unknown-event'}),
      'ack desconhecido',
    );

    expect(eventIds(client.pendingEvents), beforePending);
    expect(client.acceptedEventIds, beforeAccepted);
  });

  test('applyAck rejeita batch fabricado fora do client', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(1));
    final batch = GameSyncBatch(
      batchId: 'batch-1',
      events: [validEvent(index: 9)],
      createdAtMs: 1,
    );

    expectSyncFailure(
      () => client.applyAck(batch, acceptedEventIds: const {}),
      'batch fabricado',
    );

    expect(eventIds(client.pendingEvents), ['event-0']);
    expect(client.acceptedEventIds, isEmpty);
  });

  test('applyAck rejeita batch com eventId que nao esta pendente', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(1));
    final event = validEvent(index: 0, eventId: 'event-other');
    final batch = GameSyncBatch(
      batchId: 'batch-1',
      events: [event],
      createdAtMs: 1,
    );

    expectSyncFailure(
      () => client.applyAck(batch, acceptedEventIds: const {}),
      'eventId nao pendente',
    );

    expect(eventIds(client.pendingEvents), ['event-0']);
    expect(client.acceptedEventIds, isEmpty);
  });

  test('applyAck rejeita batch com idempotencyKey que nao esta pendente', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(1));
    final event = validEvent(index: 9, eventId: 'event-0');
    final batch = GameSyncBatch(
      batchId: 'batch-1',
      events: [event],
      createdAtMs: 1,
    );

    expectSyncFailure(
      () => client.applyAck(batch, acceptedEventIds: const {}),
      'idempotencyKey nao pendente',
    );

    expect(eventIds(client.pendingEvents), ['event-0']);
    expect(client.acceptedEventIds, isEmpty);
  });

  test('applyAck com batch invalido nao altera estado', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(1));
    final beforePending = eventIds(client.pendingEvents);

    expectSyncFailure(
      () => client.applyAck(
        GameSyncBatch.fromJson({
          'batchId': 'batch-1',
          'events': [validEvent().toJson()],
          'createdAtMs': 0,
        }),
        acceptedEventIds: const {},
      ),
      'batch invalido',
    );

    expect(eventIds(client.pendingEvents), beforePending);
    expect(client.acceptedEventIds, isEmpty);
  });

  test('applyAck com tudo aceito retorna acked', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(2));
    final batch = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);

    final result = client.applyAck(
      batch,
      acceptedEventIds: {'event-0', 'event-1'},
    );

    expect(result.status, GameSyncStatus.acked);
    expect(client.pendingEvents, isEmpty);
  });

  test('depois de ACK total status acked e isIdle falso', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(1));
    final batch = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);

    client.applyAck(batch, acceptedEventIds: {'event-0'});

    expect(client.status, GameSyncStatus.acked);
    expect(client.isIdle, isFalse);
  });

  test('applyAck com nada aceito retorna rejected', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(2));
    final batch = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);

    final result = client.applyAck(batch, acceptedEventIds: const {});

    expect(result.status, GameSyncStatus.rejected);
    expect(eventIds(client.pendingEvents), ['event-0', 'event-1']);
  });

  test('clearAccepted nao apaga pendentes', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(2));
    final batch = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);
    client.applyAck(batch, acceptedEventIds: {'event-0'});

    client.clearAccepted();

    expect(client.acceptedEventIds, isEmpty);
    expect(client.acceptedIdempotencyKeys, isEmpty);
    expect(eventIds(client.pendingEvents), ['event-1']);
  });

  test('depois de clearAccepted status volta para idle sem pendentes', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(1));
    final batch = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);
    client.applyAck(batch, acceptedEventIds: {'event-0'});

    client.clearAccepted();

    expect(client.status, GameSyncStatus.idle);
    expect(client.isIdle, isTrue);
  });

  test('clearAll limpa tudo', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(2));
    final batch = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);
    client.applyAck(batch, acceptedEventIds: {'event-0'});

    client.clearAll();

    expect(client.pendingEvents, isEmpty);
    expect(client.acceptedEventIds, isEmpty);
    expect(client.acceptedIdempotencyKeys, isEmpty);
    expect(client.isIdle, isTrue);
  });

  test('Client nao expoe pendingEvents vivo', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(1));
    final exposed = client.pendingEvents;

    expect(() => exposed.add(validEvent(index: 2)), throwsUnsupportedError);
    expect(client.pendingCount, 1);
  });

  test('Client nao expoe acceptedEventIds vivo', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(1));
    final batch = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);
    client.applyAck(batch, acceptedEventIds: {'event-0'});
    final exposed = client.acceptedEventIds;

    expect(() => exposed.add('event-x'), throwsUnsupportedError);
    expect(client.acceptedEventIds, {'event-0'});
  });

  test('Client nao expoe acceptedIdempotencyKeys vivo', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(1));
    final batch = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);
    client.applyAck(batch, acceptedEventIds: {'event-0'});
    final exposed = client.acceptedIdempotencyKeys;

    expect(() => exposed.add('x'), throwsUnsupportedError);
    expect(client.acceptedIdempotencyKeys, {eventKey(validEvent(index: 0))});
  });

  test('Result nao expoe sets vivos', () {
    final result = GameSyncResult(
      status: GameSyncStatus.partial,
      acceptedEventIds: {'event-1'},
      rejectedEventIds: {'event-2'},
      pendingEventIds: {'event-2'},
    );

    expect(() => result.acceptedEventIds.add('x'), throwsUnsupportedError);
    expect(() => result.rejectedEventIds.add('x'), throwsUnsupportedError);
    expect(() => result.pendingEventIds.add('x'), throwsUnsupportedError);
  });

  test('EnqueueResult nao expoe sets vivos', () {
    final result = GameSyncEnqueueResult(
      addedEventIds: {'event-1'},
      ignoredPendingEventIds: {'event-2'},
      ignoredAcceptedEventIds: {'event-3'},
      ignoredAcceptedIdempotencyKeys: {'key-1'},
      ignoredDuplicateIdempotencyKeys: {'key-2'},
    );

    expect(() => result.addedEventIds.add('x'), throwsUnsupportedError);
    expect(
      () => result.ignoredPendingEventIds.add('x'),
      throwsUnsupportedError,
    );
    expect(
      () => result.ignoredAcceptedEventIds.add('x'),
      throwsUnsupportedError,
    );
    expect(
      () => result.ignoredAcceptedIdempotencyKeys.add('x'),
      throwsUnsupportedError,
    );
    expect(
      () => result.ignoredDuplicateIdempotencyKeys.add('x'),
      throwsUnsupportedError,
    );
  });

  test('GameSyncResult status acked com rejeitado falha', () {
    expectSyncFailure(
      () => GameSyncResult(
        status: GameSyncStatus.acked,
        acceptedEventIds: {'event-1'},
        rejectedEventIds: {'event-2'},
        pendingEventIds: {'event-2'},
      ),
      'acked incoerente',
    );
  });

  test('GameSyncResult status rejected com aceito falha', () {
    expectSyncFailure(
      () => GameSyncResult(
        status: GameSyncStatus.rejected,
        acceptedEventIds: {'event-1'},
        rejectedEventIds: {'event-2'},
        pendingEventIds: {'event-2'},
      ),
      'rejected incoerente',
    );
  });

  test('GameSyncResult status partial sem aceitos falha', () {
    expectSyncFailure(
      () => GameSyncResult(
        status: GameSyncStatus.partial,
        acceptedEventIds: const {},
        rejectedEventIds: {'event-2'},
        pendingEventIds: {'event-2'},
      ),
      'partial sem aceitos',
    );
  });

  test('GameSyncResult status partial sem rejeitados falha', () {
    expectSyncFailure(
      () => GameSyncResult(
        status: GameSyncStatus.partial,
        acceptedEventIds: {'event-1'},
        rejectedEventIds: const {},
        pendingEventIds: const {},
      ),
      'partial sem rejeitados',
    );
  });

  test('GameSyncResult status idle falha', () {
    expectSyncFailure(
      () => GameSyncResult(
        status: GameSyncStatus.idle,
        acceptedEventIds: const {},
        rejectedEventIds: const {},
        pendingEventIds: const {},
      ),
      'idle nao e resultado',
    );
  });

  test('GameSyncResult status ready falha', () {
    expectSyncFailure(
      () => GameSyncResult(
        status: GameSyncStatus.ready,
        acceptedEventIds: const {},
        rejectedEventIds: const {},
        pendingEventIds: const {},
      ),
      'ready nao e resultado',
    );
  });

  test('GameSyncResult rejeita sobreposicao indevida', () {
    expectSyncFailure(
      () => GameSyncResult(
        status: GameSyncStatus.partial,
        acceptedEventIds: {'event-1'},
        rejectedEventIds: {'event-1', 'event-2'},
        pendingEventIds: {'event-2'},
      ),
      'accepted rejected overlap',
    );
    expectSyncFailure(
      () => GameSyncResult(
        status: GameSyncStatus.acked,
        acceptedEventIds: {'event-1'},
        rejectedEventIds: const {},
        pendingEventIds: {'event-1'},
      ),
      'accepted pending overlap',
    );
  });

  test('toJson fromJson preserva estado leve e ordem', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(3));
    final batch = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);
    client.applyAck(batch, acceptedEventIds: {'event-0'});

    final roundtrip = GameSyncClient.fromJson(decoded(client.toJson()));

    expect(eventIds(roundtrip.pendingEvents), ['event-1', 'event-2']);
    expect(roundtrip.acceptedEventIds, {'event-0'});
    expect(roundtrip.acceptedIdempotencyKeys, {eventKey(validEvent(index: 0))});
  });

  test('toJson fromJson preserva acceptedIdempotencyKeys', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(1));
    final batch = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);
    client.applyAck(batch, acceptedEventIds: {'event-0'});

    final roundtrip = GameSyncClient.fromJson(decoded(client.toJson()));

    expect(roundtrip.acceptedIdempotencyKeys, {eventKey(validEvent(index: 0))});
  });

  test('toJson chama validate', () {
    final text = source();
    final toJsonIndex = text.indexOf('Map<String, Object?> toJson()');
    final validateIndex = text.indexOf('validate();', toJsonIndex);
    final returnIndex = text.indexOf('return {', toJsonIndex);

    expect(toJsonIndex, isNonNegative);
    expect(validateIndex, inInclusiveRange(toJsonIndex, returnIndex));
  });

  test('fromJson rejeita chave desconhecida e payload livre', () {
    final json = GameSyncClient().toJson();

    expectSyncFailure(
      () => GameSyncClient.fromJson({...json, 'unknown': true}),
      'unknown',
    );
    for (final key in ['payload', 'metadata', 'extra']) {
      expectSyncFailure(() => GameSyncClient.fromJson({...json, key: {}}), key);
    }
  });

  test('Batch fromJson rejeita chave desconhecida', () {
    final batch = GameSyncBatch(
      batchId: 'batch-1',
      events: [validEvent()],
      createdAtMs: 1,
    ).toJson();

    expectSyncFailure(
      () => GameSyncBatch.fromJson({...batch, 'unknown': true}),
      'unknown',
    );
  });

  test('fromJson com evento invalido falha', () {
    expectSyncFailure(
      () => GameSyncClient.fromJson({
        'pendingEvents': [
          {
            'eventId': 'event-0',
            'lessonLocalId': 'lesson-1',
            'deckId': 'deck-1',
            'cardId': 'card-0',
            'contentHash': 'hash-0',
            'type': PedagogicalEventType.cardSeen.name,
            'sequence': 0,
            'clientTimestampMs': 0,
          },
        ],
        'acceptedEventIds': const [],
        'acceptedIdempotencyKeys': const [],
      }),
      'evento invalido',
    );
  });

  test('fromJson com duplicata falha', () {
    final event = validEvent().toJson();

    expectSyncFailure(
      () => GameSyncClient.fromJson({
        'pendingEvents': [event, event],
        'acceptedEventIds': const [],
        'acceptedIdempotencyKeys': const [],
      }),
      'duplicata',
    );
  });

  test('fromJson com aceito tambem pendente falha', () {
    expectSyncFailure(
      () => GameSyncClient.fromJson({
        'pendingEvents': [validEvent().toJson()],
        'acceptedEventIds': ['event-0'],
        'acceptedIdempotencyKeys': const [],
      }),
      'aceito nao pode estar pendente',
    );
  });

  test('acceptedEventIds duplicados no JSON falham', () {
    expectSyncFailure(
      () => GameSyncClient.fromJson({
        'pendingEvents': const [],
        'acceptedEventIds': ['event-1', 'event-1'],
        'acceptedIdempotencyKeys': const [],
      }),
      'duplicata aceita',
    );
  });

  test('acceptedIdempotencyKeys duplicadas ou vazias no JSON falham', () {
    expectSyncFailure(
      () => GameSyncClient.fromJson({
        'pendingEvents': const [],
        'acceptedEventIds': const [],
        'acceptedIdempotencyKeys': ['key-1', 'key-1'],
      }),
      'duplicata key',
    );
    expectSyncFailure(
      () => GameSyncClient.fromJson({
        'pendingEvents': const [],
        'acceptedEventIds': const [],
        'acceptedIdempotencyKeys': [' '],
      }),
      'key vazia',
    );
  });

  test('aceito por idempotencyKey nao e reenfileirado', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(1));
    final batch = client.prepareBatch(batchId: 'batch-1', createdAtMs: 1);
    final acceptedKey = eventKey(validEvent(index: 0));
    client.applyAck(batch, acceptedEventIds: {'event-0'});

    final result = client.enqueueFromLog(
      PedagogicalEventLog([validEvent(index: 0, eventId: 'event-other')]),
    );

    expect(client.pendingEvents, isEmpty);
    expect(result.ignoredAcceptedIdempotencyKeys, {acceptedKey});
  });

  test('enqueueFromLog com log invalido nao altera estado', () {
    final client = GameSyncClient()..enqueueFromLog(eventLog(1));

    expectSyncFailure(
      () => client.enqueueFromLog(
        PedagogicalEventLog([validEvent(index: 2, clientTimestampMs: 0)]),
      ),
      'log invalido',
    );

    expect(eventIds(client.pendingEvents), ['event-0']);
  });

  test('GameSyncClient nao cria nem altera PedagogicalEvent', () {
    final text = source();

    expect(text, isNot(contains('PedagogicalEvent(')));
    expect(text, isNot(contains('event.copy')));
  });

  test('enqueueFromLog nao mexe no log recebido', () {
    final log = eventLog(2);
    final before = log.toJson();
    final client = GameSyncClient();

    client.enqueueFromLog(log);

    expect(log.toJson(), before);
  });

  test('GameSyncStatus contem somente estados locais permitidos', () {
    expect(GameSyncStatus.values, [
      GameSyncStatus.idle,
      GameSyncStatus.ready,
      GameSyncStatus.acked,
      GameSyncStatus.partial,
      GameSyncStatus.rejected,
    ]);
    final text = source();
    for (final forbidden in [
      token(['paid']),
      token(['charged']),
      token(['billing']),
      token(['generated']),
      token(['ai', 'Called']),
      token(['server', 'Queued']),
      token(['synced', 'Remote']),
      token(['retrying']),
      token(['uploading']),
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('arquivo produtivo nao contem termos proibidos', () {
    final text = source();
    final allowedClientHits = RegExp(r'GameSyncClient');
    final allowedQueueHits = RegExp(r'GameSyncEnqueueResult|enqueueFromLog');
    final forbidden = [
      token(['h', 'ttp']),
      token(['d', 'io']),
      token(['Cli', 'ent']),
      token(['ser', 'ver']),
      token(['servidor']),
      token(['end', 'point']),
      token(['req', 'uest']),
      token(['res', 'ponse']),
      token(['re', 'mote']),
      token(['up', 'load']),
      token(['down', 'load']),
      token(['re', 'try']),
      token(['back', 'off']),
      token(['wor', 'ker']),
      token(['que', 'ue']),
      token(['fila']),
      token(['stor', 'age']),
      token(['Shared', 'Preferences']),
      token(['Dr', 'ift']),
      token(['Fi', 'le']),
      token(['Dir', 'ectory']),
      token(['Fut', 'ure']),
      token(['asy', 'nc']),
      token(['Ti', 'mer']),
      token(['Str', 'eam']),
      token(['Widget']),
      token(['Build', 'Context']),
      token(['Lab', 'Session']),
      token(['Lesson', 'Runtime', 'Engine']),
      token(['Chat', 'Aula', 'Screen']),
      token(['T', '00']),
      token(['T', '02']),
      token(['N', '3']),
      token(['pro', 'mpt']),
      token(['aden', 'do']),
      token(['Ai', 'Cost', 'Protection', 'Gate']),
      token(['cre', 'dit']),
      token(['cre', 'dito']),
      token(['led', 'ger']),
      token(['bill', 'ing']),
      token(['co', 'st']),
      token(['Gem', 'ini']),
      token(['Open', 'AI']),
      token(['Sup', 'abase']),
      token(['Date', 'Time', '.', 'now']),
      token(['uu', 'id']),
      token(['un', 'awaited']),
      token(['catch ', '(_)']),
      token(['Map<String, ', 'dynamic>']),
      token(['pay', 'load']),
      token(['meta', 'data']),
      token(['ex', 'tra']),
    ];

    for (final term in forbidden) {
      if (term == 'Client') {
        expect(
          text.replaceAll(allowedClientHits, ''),
          isNot(contains(term)),
          reason: term,
        );
      } else if (term == 'queue') {
        expect(
          text.replaceAll(allowedQueueHits, ''),
          isNot(contains(term)),
          reason: term,
        );
      } else {
        expect(text, isNot(contains(term)), reason: term);
      }
    }
  });

  test(
    'arquivo produtivo contem falsos positivos apenas em nomes permitidos',
    () {
      final matches = RegExp('Client').allMatches(source()).toList();
      final queueMatches = RegExp('queue').allMatches(source()).toList();

      expect(matches.length, 3);
      expect(queueMatches.length, 5);
      expect(source(), contains('final class GameSyncClient'));
      expect(source(), contains('final class GameSyncEnqueueResult'));
      expect(source(), contains('enqueueFromLog'));
    },
  );

  test('arquivo produtivo nao contem try catch ou geracao automatica', () {
    final text = source();

    expect(text, isNot(contains('try')));
    expect(text, isNot(contains('catch')));
    expect(text, isNot(contains(token(['Date', 'Time', '.', 'now']))));
    expect(text, isNot(contains(token(['uu', 'id']))));
  });

  test('limite 50 explicito e 15 nao aparece como limite produtivo', () {
    final text = source();

    expect(text, contains('static const maxEvents = 50'));
    expect(text, isNot(contains('15')));
  });

  test('nao cria tipos paralelos de resposta ou sinal', () {
    final text = source();

    for (final forbidden in [
      token(['Game', 'Answer']),
      token(['Game', 'Signal']),
      token(['Pedagogical', 'Answer']),
      token(['Pedagogical', 'Signal']),
      'String answer',
      'int signal',
    ]) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
