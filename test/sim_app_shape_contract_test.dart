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
      final dirCount = libRoot
          .listSync(recursive: true)
          .whereType<Directory>()
          .length;
      final emptyDirs = libRoot
          .listSync(recursive: true)
          .whereType<Directory>()
          .where((dir) => dir.listSync().isEmpty)
          .map((dir) => dir.path)
          .toList();

      expect(lineCount, lessThanOrEqualTo(35000));
      expect(dartFiles.length, lessThanOrEqualTo(130));
      expect(dirCount, lessThanOrEqualTo(32));
      expect(emptyDirs, isEmpty);

      expect(
        File('docs/sim_nv_app_architecture_inventory.md').existsSync(),
        isTrue,
      );
      expect(
        File('tool/sim_nv_app_architecture_inventory.json').existsSync(),
        isTrue,
      );

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
