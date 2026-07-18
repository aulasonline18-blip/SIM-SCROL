import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'normal lesson runtime keeps local answer, signal and continuation organs',
    () {
      final files = [
        'lib/features/classroom/chat_aula_screen.dart',
        'lib/features/classroom/chat_aula_timeline_builder.dart',
        'lib/features/classroom/chat_aula_widgets.dart',
        'lib/sim/classroom/lesson_answer_progress_controller.dart',
        'lib/sim/classroom/lesson_runtime_engine.dart',
        'lib/sim/lesson/student_lesson_material_service.dart',
        'lib/sim/state/student_state_store.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');

      expect(files, contains('submitAulaSignal'));
      expect(files, contains('buildChatLessonMessages'));
      expect(files, contains('LessonAnswerProgressController'));
      expect(files, contains('StudentLessonMaterialService'));
      expect(files, contains('StudentStateStore'));
      expect(files, isNot(contains('/api/advance-gate')));
    },
  );
}
