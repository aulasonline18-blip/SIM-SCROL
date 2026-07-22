import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String readRequired(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path must exist');
  return file.readAsStringSync();
}

void main() {
  test('README do app e operacional e nao template Flutter', () {
    final readme = readRequired('README.md');
    expect(readme, contains('SIM-SCROL'));
    expect(readme, contains('flutter analyze'));
    expect(readme, contains('flutter test'));
    expect(readme, contains('scripts/build-sim-scroll-production-apk.sh'));
    expect(readme, contains('SIM_ALLOW_HTTP_IN_DEVELOPMENT=true'));
    expect(readme, isNot(contains('A new Flutter project.')));
    expect(readme, isNot(contains('This project is a starting point')));
  });

  test('governanca documental do app existe', () {
    for (final path in [
      'docs/INDEX.md',
      'scripts/coverage.sh',
      'scripts/create-release-manifest.sh',
      'scripts/verify-provenance.sh',
      'scripts/run-integration-tests.sh',
      'manifest/workspace-manifest.json',
      'integration_test/smoke_test.dart',
      'docs/ci-templates/app-ci.yml',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: '$path must exist');
    }
  });

  test('workspace manifest aponta para app e servidor reais', () {
    final manifest =
        jsonDecode(readRequired('manifest/workspace-manifest.json'))
            as Map<String, dynamic>;
    expect((manifest['app'] as Map)['path'], '/root/SIM-SCROL');
    expect((manifest['server'] as Map)['path'], '/root/sim-work/sim-api');
    expect((manifest['scripts'] as Map)['appTest'], 'flutter test');
    expect(
      (manifest['scripts'] as Map)['serverGuardAudit'],
      'npm run check:guardas-antigasto',
    );
  });

  test('OpenAPI do servidor nao inventa rotas antigas de IA', () {
    final openapiFile = File('/root/sim-work/sim-api/docs/openapi.yaml');
    if (!openapiFile.existsSync()) {
      final manifest = readRequired('manifest/workspace-manifest.json');
      expect(manifest, contains('/root/sim-work/sim-api'));
      return;
    }

    final openapi = openapiFile.readAsStringSync();
    expect(openapi, contains('/api/bootstrap-t00:'));
    expect(openapi, contains('/api/complete-lesson:'));
    expect(openapi, isNot(contains('/api/ai/t00')));
    expect(openapi, isNot(contains('/api/ai/t02')));
  });

  test('fase de governanca nao lista N3 visual como arquivo alteravel', () {
    final index = readRequired('docs/INDEX.md');
    expect(index, contains('Guardas antigasto'));
    final protected = File('lib/sim/media/visual_router_n3.dart');
    expect(protected.existsSync(), isTrue);
  });
}
