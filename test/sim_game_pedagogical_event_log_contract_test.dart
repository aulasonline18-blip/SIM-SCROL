import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/pedagogical_event.dart';
import 'package:sim_mobile/sim/game/pedagogical_event_log.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _eventSourcePath = 'lib/sim/game/pedagogical_event.dart';
const _logSourcePath = 'lib/sim/game/pedagogical_event_log.dart';

PedagogicalEvent validEvent({
  String eventId = 'event-1',
  String lessonLocalId = 'lesson-1',
  String deckId = 'deck-1',
  String cardId = 'card-1',
  String contentHash = 'hash-1',
  PedagogicalEventType type = PedagogicalEventType.cardSeen,
  int sequence = 0,
  int clientTimestampMs = 1,
  AnswerLetter? answer,
  DecisionSignal? qualifier,
}) {
  return PedagogicalEvent(
    eventId: eventId,
    lessonLocalId: lessonLocalId,
    deckId: deckId,
    cardId: cardId,
    contentHash: contentHash,
    type: type,
    sequence: sequence,
    clientTimestampMs: clientTimestampMs,
    answer: answer,
    qualifier: qualifier,
  )..validate();
}

PedagogicalEvent answerEvent({
  String eventId = 'event-answer',
  int sequence = 1,
  AnswerLetter answer = AnswerLetter.A,
}) => validEvent(
  eventId: eventId,
  type: PedagogicalEventType.answerSelected,
  sequence: sequence,
  answer: answer,
);

PedagogicalEvent qualifiedEvent({
  String eventId = 'event-qualified',
  PedagogicalEventType type = PedagogicalEventType.qualifierSelected,
  int sequence = 2,
}) => validEvent(
  eventId: eventId,
  type: type,
  sequence: sequence,
  answer: AnswerLetter.A,
  qualifier: DecisionSignal.one,
);

Map<String, Object?> validEventJson({
  String eventId = 'event-1',
  PedagogicalEventType type = PedagogicalEventType.cardSeen,
  int sequence = 0,
  AnswerLetter? answer,
  DecisionSignal? qualifier,
}) {
  return validEvent(
    eventId: eventId,
    type: type,
    sequence: sequence,
    answer: answer,
    qualifier: qualifier,
  ).toJson();
}

String eventSource() => File(_eventSourcePath).readAsStringSync();

String logSource() => File(_logSourcePath).readAsStringSync();

String productSource() => '${eventSource()}\n${logSource()}';

String token(List<String> parts) => parts.join();

void expectEventFailure(void Function() run, String reason) {
  expect(
    run,
    throwsA(isA<PedagogicalEventContractException>()),
    reason: reason,
  );
}

void expectLogFailure(void Function() run, String reason) {
  expect(
    run,
    throwsA(
      anyOf(
        isA<PedagogicalEventLogContractException>(),
        isA<PedagogicalEventContractException>(),
      ),
    ),
    reason: reason,
  );
}

void main() {
  test('evento valido e aceito', () {
    final event = validEvent();

    expect(() => event.validate(), returnsNormally);
    expect(event.type, PedagogicalEventType.cardSeen);
  });

  test('classes produtivas sao finais', () {
    expect(eventSource(), contains('final class PedagogicalEvent'));
    expect(logSource(), contains('final class PedagogicalEventLog'));
  });

  test('cada tipo de evento valido e aceito', () {
    final events = [
      validEvent(type: PedagogicalEventType.cardSeen),
      answerEvent(),
      qualifiedEvent(type: PedagogicalEventType.qualifierSelected),
      qualifiedEvent(
        eventId: 'event-feedback',
        type: PedagogicalEventType.feedbackShown,
      ),
      validEvent(
        eventId: 'event-advanced',
        type: PedagogicalEventType.cardAdvanced,
      ),
    ];

    expect(events.map((event) => event.type), PedagogicalEventType.values);
  });

  test('evento sem eventId falha', () {
    expectEventFailure(() => validEvent(eventId: ''), 'eventId e obrigatorio');
  });

  test('evento sem lessonLocalId falha', () {
    expectEventFailure(
      () => validEvent(lessonLocalId: ''),
      'lessonLocalId e obrigatorio',
    );
  });

  test('evento sem deckId falha', () {
    expectEventFailure(() => validEvent(deckId: ''), 'deckId e obrigatorio');
  });

  test('evento sem cardId falha', () {
    expectEventFailure(() => validEvent(cardId: ''), 'cardId e obrigatorio');
  });

  test('evento sem contentHash falha', () {
    expectEventFailure(
      () => validEvent(contentHash: ''),
      'contentHash e obrigatorio',
    );
  });

  test('lessonLocalId com separador falha', () {
    expectEventFailure(
      () => validEvent(lessonLocalId: 'lesson:1'),
      'lessonLocalId entra na chave idempotente',
    );
  });

  test('deckId com separador falha', () {
    expectEventFailure(
      () => validEvent(deckId: 'deck:1'),
      'deckId entra na chave idempotente',
    );
  });

  test('cardId com separador falha', () {
    expectEventFailure(
      () => validEvent(cardId: 'card:1'),
      'cardId entra na chave idempotente',
    );
  });

  test('contentHash com separador falha', () {
    expectEventFailure(
      () => validEvent(contentHash: 'hash:1'),
      'contentHash entra na chave idempotente',
    );
  });

  test('sequence negativo falha', () {
    expectEventFailure(
      () => validEvent(sequence: -1),
      'sequence nao pode ser negativo',
    );
  });

  test('clientTimestampMs invalido falha', () {
    expectEventFailure(
      () => validEvent(clientTimestampMs: 0),
      'timestamp precisa ser positivo',
    );
  });

  test('answerSelected exige AnswerLetter', () {
    PedagogicalEvent build(AnswerLetter answer) => answerEvent(answer: answer);

    expect(build(AnswerLetter.B).answer, AnswerLetter.B);
    expect(
      () => PedagogicalEvent.fromJson(
        validEventJson(type: PedagogicalEventType.answerSelected, sequence: 1),
      ),
      throwsA(isA<PedagogicalEventContractException>()),
    );
  });

  test('qualifierSelected exige DecisionSignal', () {
    PedagogicalEvent build(DecisionSignal qualifier) => validEvent(
      type: PedagogicalEventType.qualifierSelected,
      sequence: 2,
      answer: AnswerLetter.A,
      qualifier: qualifier,
    );

    expect(build(DecisionSignal.two).qualifier, DecisionSignal.two);
    expect(
      () => PedagogicalEvent.fromJson(
        validEventJson(
          type: PedagogicalEventType.qualifierSelected,
          sequence: 2,
          answer: AnswerLetter.A,
        ),
      ),
      throwsA(isA<PedagogicalEventContractException>()),
    );
  });

  test('cardSeen rejeita answer', () {
    expectEventFailure(
      () => validEvent(answer: AnswerLetter.A),
      'cardSeen nao deve carregar resposta',
    );
  });

  test('cardSeen rejeita qualifier', () {
    expectEventFailure(
      () => validEvent(qualifier: DecisionSignal.one),
      'cardSeen nao deve carregar qualificador',
    );
  });

  test('cardSeen nao aceita resposta ou qualificador indevido', () {
    expectEventFailure(
      () => validEvent(answer: AnswerLetter.A),
      'cardSeen sem resposta',
    );
    expectEventFailure(
      () => validEvent(qualifier: DecisionSignal.one),
      'cardSeen sem qualificador',
    );
  });

  test('answerSelected rejeita qualifier', () {
    expectEventFailure(
      () => validEvent(
        type: PedagogicalEventType.answerSelected,
        sequence: 1,
        answer: AnswerLetter.A,
        qualifier: DecisionSignal.one,
      ),
      'answerSelected carrega somente resposta',
    );
  });

  test('qualifierSelected exige answer', () {
    expectEventFailure(
      () => validEvent(
        type: PedagogicalEventType.qualifierSelected,
        sequence: 2,
        qualifier: DecisionSignal.one,
      ),
      'qualifierSelected precisa da resposta escolhida',
    );
  });

  test('qualifierSelected exige qualifier', () {
    expectEventFailure(
      () => validEvent(
        type: PedagogicalEventType.qualifierSelected,
        sequence: 2,
        answer: AnswerLetter.A,
      ),
      'qualifierSelected precisa do sinal oficial',
    );
  });

  test('feedbackShown exige answer', () {
    expectEventFailure(
      () => validEvent(
        type: PedagogicalEventType.feedbackShown,
        sequence: 3,
        qualifier: DecisionSignal.one,
      ),
      'feedbackShown precisa da resposta escolhida',
    );
  });

  test('feedbackShown exige qualifier', () {
    expectEventFailure(
      () => validEvent(
        type: PedagogicalEventType.feedbackShown,
        sequence: 3,
        answer: AnswerLetter.A,
      ),
      'feedbackShown precisa do sinal oficial',
    );
  });

  test('cardAdvanced rejeita answer', () {
    expectEventFailure(
      () => validEvent(
        type: PedagogicalEventType.cardAdvanced,
        sequence: 4,
        answer: AnswerLetter.A,
      ),
      'cardAdvanced nao e nova resposta',
    );
  });

  test('cardAdvanced rejeita qualifier', () {
    expectEventFailure(
      () => validEvent(
        type: PedagogicalEventType.cardAdvanced,
        sequence: 4,
        qualifier: DecisionSignal.one,
      ),
      'cardAdvanced nao e novo sinal',
    );
  });

  test('idempotencyKey e deterministica', () {
    final first = answerEvent();
    final second = answerEvent(eventId: 'event-answer-copy');

    expect(first.idempotencyKey, second.idempotencyKey);
    expect(
      first.idempotencyKey,
      'lesson-1:deck-1:card-1:hash-1:1:answerSelected',
    );
  });

  test('idempotencyKey nao contem timestamp', () {
    final first = answerEvent();
    final second = PedagogicalEvent(
      eventId: 'event-other',
      lessonLocalId: first.lessonLocalId,
      deckId: first.deckId,
      cardId: first.cardId,
      contentHash: first.contentHash,
      type: first.type,
      sequence: first.sequence,
      clientTimestampMs: 999,
      answer: first.answer,
    );

    expect(first.idempotencyKey, second.idempotencyKey);
    expect(first.idempotencyKey, isNot(contains('999')));
  });

  test('idempotencyKey nao muda apos JSON roundtrip', () {
    final event = qualifiedEvent();
    final roundtrip = PedagogicalEvent.fromJson(
      jsonDecode(jsonEncode(event.toJson())),
    );

    expect(roundtrip.idempotencyKey, event.idempotencyKey);
  });

  test('JSON nao aceita idempotencyKey externo como autoridade', () {
    final json = validEventJson()..['idempotencyKey'] = 'externa';

    expectEventFailure(
      () => PedagogicalEvent.fromJson(json),
      'idempotencyKey e calculada localmente',
    );
  });

  test('JSON com payload metadata ou extra e rejeitado', () {
    for (final key in ['payload', 'metadata', 'extra']) {
      final json = validEventJson()..[key] = {};

      expectEventFailure(
        () => PedagogicalEvent.fromJson(json),
        '$key nao e campo permitido',
      );
    }
  });

  test('log preserva ordem', () {
    final log = PedagogicalEventLog()
      ..append(validEvent(eventId: 'event-3', sequence: 3))
      ..append(validEvent(eventId: 'event-1', sequence: 1))
      ..append(validEvent(eventId: 'event-2', sequence: 2));

    expect(log.events.map((event) => event.eventId), [
      'event-3',
      'event-1',
      'event-2',
    ]);
  });

  test('log nao ordena por sequence', () {
    final log = PedagogicalEventLog()
      ..append(validEvent(eventId: 'event-high', sequence: 9))
      ..append(validEvent(eventId: 'event-low', sequence: 1));

    expect(log.events.map((event) => event.sequence), [9, 1]);
  });

  test('log rejeita eventId duplicado', () {
    final log = PedagogicalEventLog()..append(validEvent());

    expectLogFailure(
      () => log.append(validEvent()),
      'eventId duplicado precisa falhar',
    );
  });

  test('log rejeita idempotencyKey duplicada', () {
    final log = PedagogicalEventLog()..append(answerEvent(eventId: 'event-1'));

    expectLogFailure(
      () => log.append(answerEvent(eventId: 'event-2')),
      'idempotencyKey duplicada precisa falhar',
    );
  });

  test('evento invalido nao entra no log', () {
    final log = PedagogicalEventLog();

    expectLogFailure(
      () => log.append(validEvent(eventId: '')),
      'evento invalido precisa ser rejeitado',
    );
    expect(log.isEmpty, isTrue);
  });

  test('lista exposta e imutavel', () {
    final log = PedagogicalEventLog()..append(validEvent());

    expect(() => log.events.add(answerEvent()), throwsUnsupportedError);
  });

  test('events exposto e imutavel', () {
    final log = PedagogicalEventLog()..append(validEvent());
    final exposed = log.events;

    expect(() => exposed.clear(), throwsUnsupportedError);
    expect(log.length, 1);
  });

  test('toJson fromJson preserva ordem e dados', () {
    final log = PedagogicalEventLog()
      ..append(validEvent(eventId: 'event-seen', sequence: 0))
      ..append(answerEvent(eventId: 'event-answer', sequence: 1))
      ..append(qualifiedEvent(eventId: 'event-signal', sequence: 2));
    final decoded = jsonDecode(jsonEncode(log.toJson()));
    final roundtrip = PedagogicalEventLog.fromJson(decoded);

    expect(roundtrip.events.map((event) => event.eventId), [
      'event-seen',
      'event-answer',
      'event-signal',
    ]);
    expect(roundtrip.events[1].answer, AnswerLetter.A);
    expect(roundtrip.events[2].qualifier, DecisionSignal.one);
    expect(roundtrip.toJson(), log.toJson());
  });

  test('toJson chama validate', () {
    final sourceText = productSource();
    final firstToJson = sourceText.indexOf('Map<String, Object?> toJson()');
    final firstValidate = sourceText.indexOf('validate();', firstToJson);
    final firstReturn = sourceText.indexOf('return {', firstToJson);
    final secondToJson = sourceText.indexOf(
      'Map<String, Object?> toJson()',
      firstToJson + 1,
    );
    final secondValidate = sourceText.indexOf('validate();', secondToJson);
    final secondReturn = sourceText.indexOf('return {', secondToJson);

    expect(firstValidate, inInclusiveRange(firstToJson, firstReturn));
    expect(secondValidate, inInclusiveRange(secondToJson, secondReturn));
  });

  test('clear limpa somente memoria local', () {
    final log = PedagogicalEventLog()
      ..append(validEvent())
      ..append(answerEvent());

    log.clear();

    expect(log.isEmpty, isTrue);
    expect(log.length, 0);
    expect(log.toJson(), {'events': <Object?>[]});
  });

  test('fromJson valida tudo e rejeita duplicata', () {
    final json = {
      'events': [
        answerEvent(eventId: 'event-1').toJson(),
        answerEvent(eventId: 'event-2').toJson(),
      ],
    };

    expectLogFailure(
      () => PedagogicalEventLog.fromJson(json),
      'fromJson nao pode deduplicar silenciosamente',
    );
  });

  test('log nao ordena automaticamente apos JSON', () {
    final json = {
      'events': [
        validEvent(eventId: 'event-high', sequence: 9).toJson(),
        validEvent(eventId: 'event-low', sequence: 1).toJson(),
      ],
    };
    final log = PedagogicalEventLog.fromJson(json);

    expect(log.events.map((event) => event.sequence), [9, 1]);
  });

  test('JSON do log rejeita chave desconhecida', () {
    expectLogFailure(
      () => PedagogicalEventLog.fromJson({
        'events': [validEvent().toJson()],
        'unknown': true,
      }),
      'log nao aceita autoridade extra',
    );
  });

  test('arquivo produtivo nao importa runtime microdeck ou card', () {
    final sourceText = productSource();

    for (final forbidden in [
      token(['Local', 'Game', 'Runtime']),
      token(['Micro', 'deck']),
      token(['Pedagogical', 'Card']),
    ]) {
      expect(sourceText, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('arquivo produtivo contem somente imports permitidos', () {
    final eventImports = eventSource()
        .split('\n')
        .where((line) => line.trimLeft().startsWith('import '))
        .toList();
    final logImports = logSource()
        .split('\n')
        .where((line) => line.trimLeft().startsWith('import '))
        .toList();

    expect(eventImports, ["import '../state/student_learning_state.dart';"]);
    expect(logImports, ["import 'pedagogical_event.dart';"]);
  });

  test('arquivo produtivo nao contem HTTP IA custo storage UI', () {
    final sourceText = productSource();
    final forbidden = [
      token(['ht', 'tp']),
      token(['di', 'o']),
      token(['Cli', 'ent']),
      token(['ser', 'ver']),
      token(['T', '00']),
      token(['T', '02']),
      token(['N', '3']),
      token(['Ai', 'Cost', 'Protection', 'Gate']),
      token(['cred', 'it']),
      token(['cred', 'ito']),
      token(['led', 'ger']),
      token(['bill', 'ing']),
      token(['co', 'st']),
      token(['Gem', 'ini']),
      token(['Open', 'AI']),
      token(['Shared', 'Preferences']),
      token(['Dr', 'ift']),
      token(['Widget']),
      token(['Build', 'Context']),
      token(['Lab', 'Session']),
      token(['Lesson', 'Runtime', 'Engine']),
    ];

    for (final term in forbidden) {
      expect(sourceText, isNot(contains(term)), reason: term);
    }
  });

  test('arquivo produtivo nao contem Future Timer Stream async', () {
    final sourceText = productSource();
    final forbidden = [
      token(['Fut', 'ure']),
      token(['Tim', 'er']),
      token(['Str', 'eam']),
      token(['as', 'ync']),
    ];

    for (final term in forbidden) {
      expect(sourceText, isNot(contains(term)), reason: term);
    }
  });

  test('arquivo produtivo nao contem payload livre', () {
    final sourceText = productSource();

    expect(sourceText, isNot(contains('payload')));
    expect(sourceText, isNot(contains('metadata')));
    expect(sourceText, isNot(contains('extra')));
  });

  test('nao cria tipos paralelos de resposta ou sinal', () {
    final sourceText = productSource();

    expect(sourceText, contains('AnswerLetter'));
    expect(sourceText, contains('DecisionSignal'));
    expect(sourceText, isNot(contains('bool get isValid')));
    expect(sourceText, isNot(contains(token(['Pedagogical', 'Answer']))));
    expect(sourceText, isNot(contains(token(['Pedagogical', 'Signal']))));
    expect(sourceText, isNot(contains(token(['Game', 'Answer']))));
    expect(sourceText, isNot(contains(token(['Game', 'Signal']))));
  });
}
