import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'runtime app shape blocks legacy routes, broad assets and build artifacts',
    () {
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
                dir.path.replaceAll('\\', '/') ==
                'lib/sim/media/math_templates',
          )
          .length;
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
      const productLiveIntegrationAllowance = 160;

      expect(lineCount, lessThanOrEqualTo(34000));
      expect(
        lineCount - visualPhaseLines - productLiveLines,
        lessThanOrEqualTo(32650 + productLiveIntegrationAllowance),
      );
      expect(visualPhaseLines, lessThanOrEqualTo(520));
      expect(productLiveLines, lessThanOrEqualTo(760));
      expect(
        dartFiles.length - visualPhaseFiles.length - productLiveFiles.length,
        lessThanOrEqualTo(126),
      );
      expect(visualPhaseFiles.length, lessThanOrEqualTo(6));
      expect(productLiveFiles.length, lessThanOrEqualTo(8));
      expect(dirCount - visualPhaseDirs, lessThanOrEqualTo(32));
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

      final runtime = dartFiles
          .map((file) => file.readAsStringSync())
          .join('\n');
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
    },
  );
}
