import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/state/drift_student_state_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/sim/state/shared_prefs_state_storage.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

void main() {
  test(
    'StudentStateStore restores state through SharedPreferences storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final firstStore = StudentStateStore(
        local: SharedPrefsStudentStateLocalStorage(prefs),
      );
      firstStore.writeState(
        StudentLearningState.empty(
          lessonLocalId: 'lesson-fase-1',
          userId: 'student-1',
          now: 100,
        ).copyWith(
          updatedAt: 200,
          profile: const StudentProfile(
            preferredName: 'Ana',
            stableLang: 'Portuguese',
          ),
          extra: const {'route': '/cyber/aula'},
        ),
      );

      final reopenedStore = StudentStateStore(
        local: SharedPrefsStudentStateLocalStorage(prefs),
      );
      final restored = reopenedStore.readState('lesson-fase-1');

      expect(restored.userId, 'student-1');
      expect(restored.profile.preferredName, 'Ana');
      expect(restored.profile.stableLang, 'Portuguese');
      expect(restored.extra['route'], '/cyber/aula');
      expect(restored.updatedAt, greaterThanOrEqualTo(200));
    },
  );

  test(
    'StudentStateStore migrates legacy SharedPreferences into Drift storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final legacy = SharedPrefsStudentStateLocalStorage(prefs);
      final legacyStore = StudentStateStore(local: legacy);
      legacyStore.writeState(
        StudentLearningState.empty(
          lessonLocalId: 'lesson-drift-migration',
          userId: 'student-2',
          now: 300,
        ).copyWith(
          profile: const StudentProfile(
            preferredName: 'Bia',
            stableLang: 'Portuguese',
          ),
        ),
      );

      final drift = await DriftStudentStateLocalStorage.memory(legacy: legacy);
      final store = StudentStateStore(local: drift);
      final restored = store.readState('lesson-drift-migration');

      expect(restored.userId, 'student-2');
      expect(restored.profile.preferredName, 'Bia');
      expect(drift.listStateIds(), contains('lesson-drift-migration'));
    },
  );
}
