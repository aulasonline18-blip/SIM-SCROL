import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'architecture inventory covers every live Dart file and Plant shape',
    () {
      final inventoryFile = File('tool/sim_nv_app_architecture_inventory.json');
      expect(inventoryFile.existsSync(), isTrue);
      final inventory =
          jsonDecode(inventoryFile.readAsStringSync()) as Map<String, dynamic>;

      final libFiles =
          Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))
              .map((file) => file.path.replaceAll('\\', '/'))
              .toList()
            ..sort();
      final classified =
          (inventory['files'] as List)
              .cast<Map<String, dynamic>>()
              .map((entry) => entry['path'] as String)
              .toList()
            ..sort();

      expect(classified, libFiles);
      expect(inventory['layers'], hasLength(6));
      expect(inventory['pedagogicalEngines'], hasLength(5));
      expect(inventory['contentEngines'], hasLength(6));
      expect(inventory['formalContracts'], hasLength(11));
      expect(inventory['contractAreas'], hasLength(15));
      expect(inventory['stateMachines'], hasLength(13));
      expect(inventory['officialPaths'], hasLength(9));

      for (final entry
          in (inventory['files'] as List).cast<Map<String, dynamic>>()) {
        expect(entry['layer'], isNotEmpty, reason: entry['path'] as String);
        expect(entry['category'], isNotEmpty, reason: entry['path'] as String);
        expect(
          entry['logicalOwner'],
          isNotEmpty,
          reason: entry['path'] as String,
        );
        expect(entry['inputs'], isNotEmpty, reason: entry['path'] as String);
        expect(entry['outputs'], isNotEmpty, reason: entry['path'] as String);
        expect(entry['tests'], isNotEmpty, reason: entry['path'] as String);
        expect(entry['decision'], isNotEmpty, reason: entry['path'] as String);
      }
    },
  );

  test('runtime routes are explicit and old server paths are absent', () {
    final allowedExact = {
      '/api/bootstrap-t00',
      '/api/complete-lesson',
      '/api/visual-route',
      '/api/generate-lesson-image',
      '/api/generate-lesson-audio',
      '/api/process-attachment',
      '/api/health',
    };
    final allowedPrefixes = [
      '/api/student-state/',
      '/api/credits/',
      '/api/payments/',
      '/api/play-billing/',
      '/api/account/',
    ];
    final forbidden = [
      '/api/warmup',
      '/api/doubt',
      '/api/review',
      '/api/recovery',
      '/api/advance-gate',
      '/api/server-classroom',
      '/api/public/payments/webhook',
    ];

    final runtime = _runtimeSources();
    for (final route in forbidden) {
      expect(runtime, isNot(contains(route)), reason: route);
    }

    final routes = RegExp(
      r"""['"](/api/[A-Za-z0-9_./*-]+)['"]""",
    ).allMatches(runtime).map((match) => match.group(1)!).toSet();
    final disallowed =
        routes
            .where(
              (route) =>
                  !allowedExact.contains(route) &&
                  !allowedPrefixes.any(route.startsWith),
            )
            .toList()
          ..sort();
    expect(disallowed, isEmpty);
  });

  test('UI does not import forbidden infrastructure directly', () {
    final uiFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) {
          final path = file.path.replaceAll('\\', '/');
          return path.startsWith('lib/features/classroom/') ||
              path.startsWith('lib/features/onboarding/') ||
              path.startsWith('lib/features/portal/') ||
              path.startsWith('lib/features/auth/') ||
              path.startsWith('lib/features/billing/') ||
              path.startsWith('lib/shared/widgets/') ||
              path.startsWith('lib/sim/ui/');
        });
    final forbiddenImports = RegExp(
      r"""import ['"](?:package:shared_preferences|package:supabase_flutter|../../sim/external_ai/sim_ai_server_config|../../sim/external_ai/sim_http_transport|../../sim/external_ai/sim_server_ai_clients|../../sim/external_ai/sim_server_attachment_client|../../sim/cloud/|../../sim/billing/sim_server_|../sim/external_ai/|../sim/cloud/)""",
    );
    final offenders = <String>[];
    for (final file in uiFiles) {
      if (forbiddenImports.hasMatch(file.readAsStringSync())) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('session facade stays thin and entry flow stays isolated', () {
    final labSessionLines = File(
      'lib/features/session/lab_session.dart',
    ).readAsLinesSync().length;
    final baseFlowLines = File(
      'lib/features/session/lab_session_flows.dart',
    ).readAsLinesSync().length;
    final auxFlow = File('lib/features/session/lab_session_aux_flows.dart');
    expect(auxFlow.existsSync(), isTrue);
    final auxFlowLines = auxFlow.readAsLinesSync().length;
    final entryFlow = File('lib/features/session/lab_session_entry_flows.dart');
    expect(entryFlow.existsSync(), isTrue);
    final entryFlowLines = entryFlow.readAsLinesSync().length;

    expect(labSessionLines, lessThanOrEqualTo(1200));
    expect(baseFlowLines, lessThanOrEqualTo(1450));
    expect(auxFlowLines, lessThanOrEqualTo(320));
    expect(entryFlowLines, lessThanOrEqualTo(350));
  });

  test('large organs stay within phase 7 ownership budgets', () {
    final budgets = <String, int>{
      'lib/features/session/lab_session_flows.dart': 1450,
      'lib/sim/state/student_learning_state.dart': 1550,
      'lib/sim/state/student_state_store.dart': 850,
      'lib/sim/lesson/student_lesson_material_service.dart': 900,
      'lib/sim/ui/sim_i18n.dart': 220,
    };
    final offenders = <String>[];
    for (final entry in budgets.entries) {
      final lines = File(entry.key).readAsLinesSync().length;
      if (lines > entry.value) offenders.add('${entry.key}:$lines');
    }
    expect(offenders, isEmpty);
  });

  test('cache and auxiliary rooms cannot become main lesson authority', () {
    final materialService = File(
      'lib/sim/lesson/student_lesson_material_service.dart',
    ).readAsStringSync();
    expect(
      materialService,
      isNot(
        contains(
          RegExp(
            r'LearningDecisionEngine|MasteryTruthEngine|StudentLessonExecutor|DecisionActionType',
          ),
        ),
      ),
    );
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

    final answerController = File(
      'lib/sim/classroom/lesson_answer_progress_controller.dart',
    ).readAsStringSync();
    expect(answerController, contains('!position.isReviewAtivo'));
  });

  test('official paths have executable proof references', () {
    final inventory =
        jsonDecode(
              File(
                'tool/sim_nv_app_architecture_inventory.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final paths = (inventory['officialPaths'] as List).cast<String>();
    final files = (inventory['files'] as List).cast<Map<String, dynamic>>();
    final missing = <String>[];
    for (final officialPath in paths) {
      final proofs = files
          .where(
            (entry) => ((entry['officialPaths'] as List?) ?? const []).contains(
              officialPath,
            ),
          )
          .expand((entry) => (entry['tests'] as List).cast<String>())
          .where((testPath) => File(testPath).existsSync())
          .toSet();
      if (proofs.isEmpty) missing.add(officialPath);
    }
    expect(missing, isEmpty);
  });
}

String _runtimeSources() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  return files.map((file) => file.readAsStringSync()).join('\n');
}
