import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime app shape blocks legacy routes, broad assets and build artifacts', () {
    final libRoot = Directory('lib');
    final dartFiles =
        libRoot
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final lineCount = dartFiles.fold<int>(
      0,
      (total, file) => total + file.readAsLinesSync().length,
    );
    final dirs = libRoot
        .listSync(recursive: true)
        .whereType<Directory>()
        .toList();
    final dirCount = dirs.length;
    final visualPhaseDirs = dirs
        .where(
          (dir) =>
              dir.path.replaceAll('\\', '/') == 'lib/sim/media/math_templates',
        )
        .length;
    final securityPhaseDirs = dirs.where((dir) {
      final path = dir.path.replaceAll('\\', '/');
      return path == 'lib/sim/cache' || path == 'lib/sim/utils';
    }).length;
    final sessionUseCaseDirs = dirs.where((dir) {
      final path = dir.path.replaceAll('\\', '/');
      return path == 'lib/features/session/use_cases';
    }).length;
    final stateModuleDirs = dirs.where((dir) {
      final path = dir.path.replaceAll('\\', '/');
      return path == 'lib/sim/state/domain' ||
          path == 'lib/sim/state/snapshot' ||
          path == 'lib/sim/state/events' ||
          path == 'lib/sim/state/sync' ||
          path == 'lib/sim/state/cache';
    }).length;
    final readyWindowModuleDirs = dirs.where((dir) {
      final path = dir.path.replaceAll('\\', '/');
      return path == 'lib/sim/lesson/ready_window';
    }).length;
    final onboardingModuleDirs = dirs.where((dir) {
      final path = dir.path.replaceAll('\\', '/');
      return path == 'lib/features/onboarding/screens' ||
          path == 'lib/features/onboarding/view_models';
    }).length;
    final classroomWidgetDirs = dirs.where((dir) {
      final path = dir.path.replaceAll('\\', '/');
      return path == 'lib/features/classroom/widgets';
    }).length;
    final emptyDirs = libRoot
        .listSync(recursive: true)
        .whereType<Directory>()
        .where((dir) => dir.listSync().isEmpty)
        .map((dir) => dir.path)
        .toList();

    final visualPhaseFiles = dartFiles.where((file) {
      final path = file.path.replaceAll('\\', '/');
      return path == 'lib/sim/media/lesson_visual_pipeline.dart' ||
          path == 'lib/sim/media/lesson_visual_trigger.dart' ||
          path == 'lib/sim/media/s12_visual_pipeline.dart' ||
          path == 'lib/sim/media/visual_router_n2.dart' ||
          path == 'lib/sim/media/visual_router_n3.dart' ||
          path == 'lib/sim/media/math_templates/math_visual_templates.dart';
    }).toList();
    final visualPhaseLines = visualPhaseFiles.fold<int>(
      0,
      (total, file) => total + file.readAsLinesSync().length,
    );
    final productLiveFiles = dartFiles.where((file) {
      final path = file.path.replaceAll('\\', '/');
      return path == 'lib/sim/ui/sim_accessibility.dart' ||
          path == 'lib/sim/ui/sim_components.dart' ||
          path == 'lib/sim/ui/widgets/fixed_bubble.dart' ||
          path == 'lib/sim/ui/widgets/sim_preparation_experience.dart' ||
          path == 'lib/sim/ui/widgets/sim_typewriter.dart' ||
          path == 'lib/sim/ui/widgets/lesson_audio_controls.dart' ||
          path == 'lib/sim/ui/widgets/lesson_avatar.dart' ||
          path == 'lib/sim/auxiliary/doubt_progress_bar.dart' ||
          path == 'lib/sim/ui/widgets/doubt_progress_bar.dart';
    }).toList();
    final productLiveLines = productLiveFiles.fold<int>(
      0,
      (total, file) => total + file.readAsLinesSync().length,
    );
    final amparoConstitutionalFiles = dartFiles.where((file) {
      final path = file.path.replaceAll('\\', '/');
      return path == 'lib/features/session/lab_session_amparo_flows.dart' ||
          path == 'lib/sim/auxiliary/amparo_room_engine.dart' ||
          path == 'lib/sim/auxiliary/amparo_room_service.dart';
    }).toList();
    final securityPhaseFiles = dartFiles.where((file) {
      final path = file.path.replaceAll('\\', '/');
      return path == 'lib/sim/cache/secure_lesson_cache_store.dart' ||
          path == 'lib/sim/state/secure_storage_service.dart' ||
          path == 'lib/sim/utils/secure_logger.dart';
    }).toList();
    final sessionUseCaseFiles = dartFiles.where((file) {
      final path = file.path.replaceAll('\\', '/');
      return path ==
          'lib/features/session/use_cases/request_account_deletion_use_case.dart';
    }).toList();
    final routeContractFiles = dartFiles.where((file) {
      final path = file.path.replaceAll('\\', '/');
      return path == 'lib/sim/config/sim_api_routes.dart';
    }).toList();
    final phase4OperationalFiles = dartFiles.where((file) {
      final path = file.path.replaceAll('\\', '/');
      return path == 'lib/sim/cloud/drift_cloud_queue_storage.dart';
    }).toList();
    final stateModuleFiles = dartFiles.where((file) {
      final path = file.path.replaceAll('\\', '/');
      return path == 'lib/sim/state/domain/student_profile.dart' ||
          path == 'lib/sim/state/domain/student_curriculum.dart' ||
          path == 'lib/sim/state/domain/student_progress.dart' ||
          path == 'lib/sim/state/snapshot/student_snapshot.dart' ||
          path == 'lib/sim/state/events/student_event_log.dart' ||
          path == 'lib/sim/state/sync/student_sync_state.dart' ||
          path == 'lib/sim/state/cache/student_cache_info.dart';
    }).toList();
    final readyWindowModuleFiles = dartFiles.where((file) {
      final path = file.path.replaceAll('\\', '/');
      return path == 'lib/sim/lesson/ready_window/ready_window_planner.dart' ||
          path == 'lib/sim/lesson/ready_window/ready_window_executor.dart' ||
          path == 'lib/sim/lesson/ready_window/ready_window_health.dart' ||
          path == 'lib/sim/lesson/ready_window/ready_window_media.dart';
    }).toList();
    final onboardingModuleFiles = dartFiles.where((file) {
      final path = file.path.replaceAll('\\', '/');
      return path ==
              'lib/features/onboarding/screens/language_selection_screen.dart' ||
          path ==
              'lib/features/onboarding/screens/objective_entry_screen.dart' ||
          path ==
              'lib/features/onboarding/screens/onboarding_attachment_widgets.dart' ||
          path ==
              'lib/features/onboarding/screens/onboarding_chat_widgets.dart' ||
          path ==
              'lib/features/onboarding/screens/onboarding_reception_widgets.dart' ||
          path ==
              'lib/features/onboarding/view_models/language_selection_view_model.dart' ||
          path ==
              'lib/features/onboarding/view_models/objective_entry_view_model.dart' ||
          path == 'lib/sim/ui/sim_i18n_core_strings.dart' ||
          path == 'lib/sim/ui/sim_i18n_objective.dart' ||
          path == 'lib/sim/ui/sim_i18n_onboarding.dart';
    }).toList();
    final classroomWidgetFiles = dartFiles.where((file) {
      final path = file.path.replaceAll('\\', '/');
      return path == 'lib/features/classroom/widgets/message_widget.dart' ||
          path == 'lib/features/classroom/widgets/media_widget.dart' ||
          path == 'lib/features/classroom/widgets/action_widget.dart' ||
          path == 'lib/features/classroom/widgets/feedback_widget.dart' ||
          path == 'lib/features/classroom/widgets/accessibility_widget.dart';
    }).toList();
    final liveFluencyFiles = dartFiles.where((file) {
      final path = file.path.replaceAll('\\', '/');
      return path ==
              'lib/features/session/lab_session_profile_backup_helpers.dart' ||
          path == 'lib/sim/lesson/student_lesson_material_failures.dart';
    }).toList();
    expect(lineCount, greaterThan(0));
    expect(lineCount - visualPhaseLines - productLiveLines, greaterThan(0));
    expect(visualPhaseLines, lessThanOrEqualTo(760));
    expect(productLiveLines, lessThanOrEqualTo(1900));
    expect(
      dartFiles.length -
          visualPhaseFiles.length -
          productLiveFiles.length -
          amparoConstitutionalFiles.length -
          securityPhaseFiles.length -
          sessionUseCaseFiles.length -
          routeContractFiles.length -
          phase4OperationalFiles.length -
          stateModuleFiles.length -
          readyWindowModuleFiles.length -
          onboardingModuleFiles.length -
          classroomWidgetFiles.length -
          liveFluencyFiles.length,
      lessThanOrEqualTo(140),
    );
    expect(visualPhaseFiles.length, lessThanOrEqualTo(6));
    expect(productLiveFiles.length, lessThanOrEqualTo(9));
    expect(amparoConstitutionalFiles.length, 3);
    expect(securityPhaseFiles.length, 3);
    expect(sessionUseCaseFiles.length, 1);
    expect(routeContractFiles.length, 1);
    expect(phase4OperationalFiles.length, 1);
    expect(stateModuleFiles.length, 7);
    expect(readyWindowModuleFiles.length, 4);
    expect(onboardingModuleFiles.length, 10);
    expect(classroomWidgetFiles.length, 5);
    expect(liveFluencyFiles.length, 2);
    expect(
      dirCount -
          visualPhaseDirs -
          securityPhaseDirs -
          sessionUseCaseDirs -
          stateModuleDirs -
          readyWindowModuleDirs -
          onboardingModuleDirs -
          classroomWidgetDirs,
      lessThanOrEqualTo(32),
    );
    expect(securityPhaseDirs, 2);
    expect(sessionUseCaseDirs, 1);
    expect(stateModuleDirs, 5);
    expect(readyWindowModuleDirs, 1);
    expect(onboardingModuleDirs, 2);
    expect(classroomWidgetDirs, 1);
    expect(visualPhaseDirs, lessThanOrEqualTo(1));
    expect(emptyDirs, isEmpty);

    expect(
      File('docs/sim_nv_app_architecture_inventory.md').existsSync(),
      isTrue,
    );
    expect(
      File('tool/sim_nv_app_architecture_inventory.json').existsSync(),
      isTrue,
    );
    expect(File('docs/sim_nv_app_connections.md').existsSync(), isTrue);
    expect(File('tool/sim_nv_app_connections.json').existsSync(), isTrue);

    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec,
      isNot(contains(RegExp(r'^\s*-\s+assets/\s*$', multiLine: true))),
    );

    final apkArtifacts = Directory('downloads').existsSync()
        ? Directory('downloads')
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.apk'))
              .map((file) => file.path)
              .toList()
        : <String>[];
    expect(apkArtifacts, isEmpty);

    final runtime = dartFiles.map((file) => file.readAsStringSync()).join('\n');
    for (final forbidden in const [
      '/api/warmup',
      '/api/doubt',
      '/api/review',
      '/api/recovery',
      '/api/advance-gate',
      '/api/server-classroom',
      'http://167.179.109.137',
      'gemini-aid-pal.lovable.app',
      'MemoryStudent',
      'MemoryCloud',
      'MemoryPaymentReturnStorage',
      'MemoryAudioPreferenceStorage',
      'NoNetwork',
      'fallbackFile',
    ]) {
      expect(runtime, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(
      runtime,
      isNot(
        contains(
          RegExp(r'debugPrint\([^\n]*(error|err|exception)\.toString\('),
        ),
      ),
    );
  });
}
