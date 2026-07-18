import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M12 keeps offline/cache/sync runtime without old remote routes', () {
    final runtime = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(runtime, contains('StudentStateStore'));
    expect(runtime, contains('CloudQueue'));
    expect(runtime, contains('LessonMaterialCache'));
    for (final route in const [
      '/api/warmup',
      '/api/doubt',
      '/api/review',
      '/api/recovery',
      '/api/advance-gate',
    ]) {
      expect(runtime, isNot(contains(route)), reason: route);
    }
  });
}
