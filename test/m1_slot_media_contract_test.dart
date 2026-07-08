import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _fixturePath =
    '/root/sim-work/sim-api/docs/contracts/m1_slot_media_fixture.json';

void main() {
  test(
    'App accepts the shared M1.10 slot media fixture without blocking text',
    () {
      final file = File(_fixturePath);
      expect(file.existsSync(), isTrue);
      final fixture = Map<String, dynamic>.from(
        jsonDecode(file.readAsStringSync()) as Map,
      );

      expect(fixture['contractName'], 'SlotMediaContract');
      expect(fixture['contractVersion'], 'sim.slot_media.v1');
      _expectNonEmptyString(fixture['slotKey'], 'slotKey');
      _expectNonEmptyString(fixture['lessonLocalId'], 'lessonLocalId');
      _expectNonEmptyString(fixture['marker'], 'marker');
      expect(fixture['itemIdx'], isA<num>());
      expect(fixture['layer'], isA<num>());
      expect(fixture['textStatus'], 'ready');

      final text = Map<String, dynamic>.from(fixture['text'] as Map);
      _expectNonEmptyString(text['explanation'], 'text.explanation');
      _expectNonEmptyString(text['question'], 'text.question');

      final image = Map<String, dynamic>.from(fixture['image'] as Map);
      final audio = Map<String, dynamic>.from(fixture['audio'] as Map);
      expect(image['imageStatus'], 'failed');
      expect(audio['audioStatus'], 'failed');
      _expectNonEmptyString(image['humanError'], 'image.humanError');
      _expectNonEmptyString(audio['humanError'], 'audio.humanError');
      _expectNonEmptyString(
        (image['technical'] as Map)['code'],
        'image.technical.code',
      );
      _expectNonEmptyString(
        (audio['technical'] as Map)['code'],
        'audio.technical.code',
      );

      final expected = Map<String, dynamic>.from(fixture['expected'] as Map);
      expect(_canRenderText(fixture), isTrue);
      expect(expected['textCanRender'], isTrue);
      expect(expected['mediaFailureBlocksText'], isFalse);
    },
  );
}

bool _canRenderText(Map<String, dynamic> fixture) {
  final text = Map<String, dynamic>.from(fixture['text'] as Map);
  return fixture['textStatus'] == 'ready' &&
      (text['explanation'] as String).trim().isNotEmpty &&
      (text['question'] as String).trim().isNotEmpty;
}

void _expectNonEmptyString(Object? value, String label) {
  expect(value, isA<String>(), reason: label);
  expect((value as String).trim(), isNotEmpty, reason: label);
}
