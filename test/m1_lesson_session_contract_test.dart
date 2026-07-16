import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _fixturePath =
    '/root/sim-work/sim-api/docs/contracts/m1_lesson_session_fixture.json';

void main() {
  test('App accepts the shared M1.2 lesson session fixture', () {
    final fixtureFile = File(_fixturePath);
    expect(
      fixtureFile.existsSync(),
      isTrue,
      reason: 'M1.2 uses the server docs/contracts fixture as source.',
    );

    final fixture = jsonDecode(fixtureFile.readAsStringSync());
    expect(fixture, isA<Map<String, dynamic>>());
    final json = Map<String, dynamic>.from(fixture as Map);

    _expectMinimumLessonSessionContract(json);

    final state = StudentLearningState.fromJson(
      Map<String, dynamic>.from(json['state'] as Map),
    );
    expect(state.lessonLocalId, json['lessonLocalId']);
    expect(state.userId, json['userId']);
    expect(state.lessonCloudId, json['sessionId']);
    expect(state.stateVersion, json['schemaVersion']);
    expect(state.profile.objetivo, json['objetivo']);

    final idioma = Map<String, dynamic>.from(json['idioma'] as Map);
    expect(state.profile.language, idioma['learningLocale']);
    expect(state.profile.stableLang, idioma['explanationLanguage']);

    final current = Map<String, dynamic>.from(json['current'] as Map);
    expect(state.current?.itemIdx, current['itemIdx']);
    expect(state.current?.marker, current['marker']);
    expect(state.current?.layer.value, current['layer']);
    expect(state.progress?.itemIdx, current['itemIdx']);
    expect(state.progress?.layer.value, current['layer']);

    expect(state.curriculum?.items, isNotEmpty);
    expect(state.currentLessonMaterial, isNull);
    expect(state.readyLessonMaterials, isEmpty);
    expect(
      state.syncStatus?.highWaterMark,
      json['restorable']['highWaterMark'],
    );
  });
}

void _expectMinimumLessonSessionContract(Map<String, dynamic> json) {
  expect(json['contractName'], 'LessonSessionContract');
  expect(json['contractVersion'], 'sim.lesson_session.v1');
  _expectNonEmptyString(json['lessonLocalId'], 'lessonLocalId');
  expect(
    (json['userId'] as String?)?.trim().isNotEmpty == true ||
        (json['sessionId'] as String?)?.trim().isNotEmpty == true,
    isTrue,
    reason: 'M1.2 requires userId or sessionId.',
  );
  _expectNonEmptyString(json['objetivo'], 'objetivo');
  expect(
    json['status'],
    isIn([
      'initializing',
      'active',
      'paused',
      'blocked',
      'completed',
      'recoverable_error',
    ]),
  );
  expect((json['schemaVersion'] as num).toInt(), greaterThanOrEqualTo(1));

  final idioma = Map<String, dynamic>.from(json['idioma'] as Map);
  _expectNonEmptyString(idioma['interfaceLocale'], 'interfaceLocale');
  _expectNonEmptyString(idioma['learningLocale'], 'learningLocale');
  _expectNonEmptyString(idioma['explanationLanguage'], 'explanationLanguage');

  final current = Map<String, dynamic>.from(json['current'] as Map);
  expect(current['itemIdx'], isA<num>());
  _expectNonEmptyString(current['marker'], 'current.marker');
  expect((current['layer'] as num).toInt(), greaterThanOrEqualTo(1));

  final restorable = Map<String, dynamic>.from(json['restorable'] as Map);
  expect((restorable['highWaterMark'] as num).toInt(), greaterThanOrEqualTo(1));
  _expectNonEmptyString(restorable['updatedAt'], 'restorable.updatedAt');
  expect(
    restorable['fields'],
    containsAll([
      'profile',
      'objective',
      'curriculum',
      'current',
      'progress',
      'attempts',
      'events',
      'pending',
    ]),
  );
}

void _expectNonEmptyString(Object? value, String label) {
  expect(value, isA<String>(), reason: label);
  expect((value as String).trim(), isNotEmpty, reason: label);
}
