import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/lesson/lesson_content_validator.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _fixturePath =
    '/root/sim-work/sim-api/docs/contracts/m1_pedagogical_slot_fixture.json';

void main() {
  test('App accepts the shared M1.3 pedagogical slot fixture', () {
    final fixtureFile = File(_fixturePath);
    expect(
      fixtureFile.existsSync(),
      isTrue,
      reason: 'M1.3 uses the server docs/contracts fixture as source.',
    );

    final decoded = jsonDecode(fixtureFile.readAsStringSync());
    expect(decoded, isA<Map<String, dynamic>>());
    final slot = Map<String, dynamic>.from(decoded as Map);

    _expectMinimumPedagogicalSlotContract(slot);

    final content = validatedLessonContentFromJson({
      'explanation': slot['explanation'],
      'question': slot['question'],
      'options': slot['options'],
      'correct_answer': slot['correctOption'],
      'why_correct': slot['feedback']['whyCorrect'],
      'why_wrong': slot['feedback']['whyWrong'],
    });

    expect(content.explanation, slot['explanation']);
    expect(content.question, slot['question']);
    expect(content.options[AnswerLetter.A], slot['options']['A']);
    expect(content.options[AnswerLetter.B], slot['options']['B']);
    expect(content.options[AnswerLetter.C], slot['options']['C']);
    expect(content.correctAnswer.name, slot['correctOption']);
    expect(content.whyCorrect, slot['feedback']['whyCorrect']);

    expect(_canRenderText(slot), isTrue);
    expect(slot['imageStatus'], 'failed');
    expect(slot['textCanRender'], isTrue);
    expect(
      slot['media']['image']['humanError'],
      'A aula continua sem a imagem por enquanto.',
    );
  });
}

void _expectMinimumPedagogicalSlotContract(Map<String, dynamic> slot) {
  expect(slot['contractName'], 'PedagogicalSlotContract');
  expect(slot['contractVersion'], 'sim.pedagogical_slot.v1');
  expect((slot['schemaVersion'] as num).toInt(), greaterThanOrEqualTo(1));
  _expectNonEmptyString(slot['slotKey'], 'slotKey');
  _expectNonEmptyString(slot['lessonLocalId'], 'lessonLocalId');
  _expectNonEmptyString(slot['marker'], 'marker');
  expect(slot['itemIdx'], isA<num>());
  expect((slot['layer'] as num).toInt(), greaterThanOrEqualTo(1));
  expect(slot['textStatus'], 'ready');
  expect(
    slot['imageStatus'],
    isIn(['not_needed', 'pending', 'ready', 'failed']),
  );
  expect(
    slot['audioStatus'],
    isIn(['not_needed', 'pending', 'ready', 'failed']),
  );
  _expectNonEmptyString(slot['updatedAt'], 'updatedAt');
  _expectNonEmptyString(slot['explanation'], 'explanation');
  _expectNonEmptyString(slot['question'], 'question');

  final options = Map<String, dynamic>.from(slot['options'] as Map);
  _expectNonEmptyString(options['A'], 'options.A');
  _expectNonEmptyString(options['B'], 'options.B');
  _expectNonEmptyString(options['C'], 'options.C');
  expect(slot['correctOption'], isIn(['A', 'B', 'C']));
  expect(slot['correctAnswer'], slot['correctOption']);

  final feedback = Map<String, dynamic>.from(slot['feedback'] as Map);
  _expectNonEmptyString(feedback['whyCorrect'], 'feedback.whyCorrect');
  final whyWrong = Map<String, dynamic>.from(feedback['whyWrong'] as Map);
  _expectNonEmptyString(whyWrong['A'], 'feedback.whyWrong.A');
  _expectNonEmptyString(whyWrong['B'], 'feedback.whyWrong.B');
  _expectNonEmptyString(whyWrong['C'], 'feedback.whyWrong.C');
}

bool _canRenderText(Map<String, dynamic> slot) {
  return slot['textStatus'] == 'ready' &&
      (slot['explanation'] as String).trim().isNotEmpty &&
      (slot['question'] as String).trim().isNotEmpty;
}

void _expectNonEmptyString(Object? value, String label) {
  expect(value, isA<String>(), reason: label);
  expect((value as String).trim(), isNotEmpty, reason: label);
}
