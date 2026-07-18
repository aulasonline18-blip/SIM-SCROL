import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('official connection map is complete and points to live proof', () {
    final map = _loadConnections();
    final paths = (map['paths'] as List).cast<Map<String, dynamic>>();
    final edges = (map['edges'] as List).cast<Map<String, dynamic>>();
    final proofTests = (map['proofTests'] as List).cast<String>();

    expect(paths, hasLength(9));
    expect(edges, hasLength(greaterThanOrEqualTo(16)));
    expect(proofTests, hasLength(greaterThanOrEqualTo(18)));

    final ids = paths.map((path) => path['id'] as String).toSet();
    expect(ids, {
      'objetivo-t00',
      'curriculo',
      'aula-pergunta',
      'resposta-aluno',
      'proxima-camada-item',
      'auxiliares',
      'audio',
      'imagem',
      'curriculo-grande',
    });

    for (final path in paths) {
      final tests = (path['proofTests'] as List).cast<String>();
      expect(tests, isNotEmpty, reason: path['id'] as String);
      for (final testPath in tests) {
        expect(File(testPath).existsSync(), isTrue, reason: testPath);
      }
    }

    for (final edge in edges) {
      expect(edge['allowed'], isTrue, reason: edge['id'] as String);
      expect(edge['contract'], isNotEmpty, reason: edge['id'] as String);
      for (final filePath in (edge['files'] as List).cast<String>()) {
        expect(
          filePath.startsWith('lib/') || filePath.startsWith('test/'),
          isTrue,
          reason: filePath,
        );
        expect(File(filePath).existsSync(), isTrue, reason: filePath);
      }
      for (final testPath in (edge['proofTests'] as List).cast<String>()) {
        expect(File(testPath).existsSync(), isTrue, reason: testPath);
      }
    }
  });

  test('server routes used by official connections are whitelisted only', () {
    final map = _loadConnections();
    final allowed = (map['allowedServerRoutes'] as List).cast<String>();
    final exactAllowed = allowed
        .where((route) => !route.endsWith('/*'))
        .toSet();
    final prefixAllowed = allowed
        .where((route) => route.endsWith('/*'))
        .map((route) => route.substring(0, route.length - 1))
        .toList();

    final usedRoutes = <String>{};
    for (final path in (map['paths'] as List).cast<Map<String, dynamic>>()) {
      usedRoutes.addAll(((path['serverRoutes'] as List?) ?? const []).cast());
    }

    final disallowed =
        usedRoutes
            .where(
              (route) =>
                  !exactAllowed.contains(route) &&
                  !prefixAllowed.any(route.startsWith),
            )
            .toList()
          ..sort();
    expect(disallowed, isEmpty);
  });

  test('runtime contains no forbidden routes or forbidden connections', () {
    final map = _loadConnections();
    final runtime = _runtimeSources();

    for (final forbidden
        in (map['forbiddenServerRoutes'] as List).cast<String>()) {
      expect(runtime, isNot(contains(forbidden)), reason: forbidden);
    }

    final classroomUi = _readDartFiles('lib/features/classroom');
    expect(
      classroomUi,
      isNot(contains(RegExp(r'sim/external_ai|sim/cloud|SimServer'))),
    );
    expect(
      classroomUi,
      isNot(
        contains(
          RegExp(
            r'LearningDecisionEngine|MasteryTruthEngine|StudentLessonExecutor',
          ),
        ),
      ),
    );

    final onboardingUi = _readDartFiles('lib/features/onboarding');
    expect(onboardingUi, isNot(contains(RegExp(r'sim/external_ai|SimServer'))));

    final materialService = File(
      'lib/sim/lesson/student_lesson_material_service.dart',
    ).readAsStringSync();
    expect(
      materialService,
      isNot(contains(RegExp(r'copyWith\([^)]*\bcurrent\s*:'))),
    );
    expect(
      materialService,
      isNot(contains(RegExp(r'copyWith\([^)]*\bprogress\s*:'))),
    );

    final auxService = File(
      'lib/sim/auxiliary/student_aux_room_service.dart',
    ).readAsStringSync();
    expect(auxService, contains("'authoritative': false"));
    expect(auxService, contains("'writesTruth': false"));
    expect(auxService, isNot(contains("'authoritative': true")));
    expect(auxService, isNot(contains("'writesTruth': true")));

    final auxRuntime = _readDartFiles('lib/sim/auxiliary');
    expect(auxRuntime, isNot(contains('readyLessonMaterials')));
    expect(auxRuntime, isNot(contains('advancePending')));
    expect(auxRuntime, isNot(contains('LOCAL_ADVANCE_DECIDED')));

    final mediaRuntime = _readDartFiles('lib/sim/media');
    expect(mediaRuntime, isNot(contains('LessonProgress(')));
    expect(mediaRuntime, isNot(contains('LessonCurrent(')));
  });
}

Map<String, dynamic> _loadConnections() {
  final file = File('tool/sim_nv_app_connections.json');
  expect(file.existsSync(), isTrue);
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

String _runtimeSources() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.readAsStringSync())
      .join('\n');
}

String _readDartFiles(String root) {
  return Directory(root)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.readAsStringSync())
      .join('\n');
}
