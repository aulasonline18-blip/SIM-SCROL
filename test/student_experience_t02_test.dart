import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'adaptador T02 transporta ficha pedagogica estruturada e localeContract',
    () {
      final source = File(
        'lib/sim/experience/student_experience_t02_adapter.dart',
      ).readAsStringSync();

      expect(source, contains("'localeContract'"));
      expect(source, contains("'pedagogical_entry'"));
      expect(source, contains("'pedagogical_entry_ficha'"));
      expect(source, contains("'language_semantics'"));
      expect(source, contains("'stable_lang_semantics'"));
    },
  );
}
