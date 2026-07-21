import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/config/sim_api_routes.dart';
import 'package:sim_mobile/sim/config/sim_environment.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_ai_clients.dart';
import 'package:sim_mobile/sim/external_ai/sim_server_attachment_client.dart';
import 'package:sim_mobile/sim/media/lesson_visual_pipeline.dart';

void main() {
  test('app route constants are generated from the server contract', () {
    final definitionFile = File(
      '/root/sim-work/sim-api/src/routes/route-definitions.json',
    );
    expect(definitionFile.existsSync(), isTrue);

    final definitions =
        jsonDecode(definitionFile.readAsStringSync()) as Map<String, dynamic>;
    expect(SimApiRoutes.version, definitions['version']);

    final routeConstants = <String, String>{
      't00Bootstrap': SimApiRoutes.t00Bootstrap,
      't02CompleteLesson': SimApiRoutes.t02CompleteLesson,
      'visualRoute': SimApiRoutes.visualRoute,
      'generateLessonAudio': SimApiRoutes.generateLessonAudio,
      'processAttachment': SimApiRoutes.processAttachment,
      'studentStatePersist': SimApiRoutes.studentStatePersist,
      'studentStateGet': SimApiRoutes.studentStateGet,
      'studentStateDelete': SimApiRoutes.studentStateDelete,
      'creditsMe': SimApiRoutes.creditsMe,
      'creditsReserve': SimApiRoutes.creditsReserve,
      'creditsCapture': SimApiRoutes.creditsCapture,
      'paymentsCreateCreditsCheckoutHosted':
          SimApiRoutes.paymentsCreateCreditsCheckoutHosted,
      'paymentsCreateCreditsCheckout':
          SimApiRoutes.paymentsCreateCreditsCheckout,
      'paymentsCheckoutStatus': SimApiRoutes.paymentsCheckoutStatus,
      'playBillingConsumeCreditPack': SimApiRoutes.playBillingConsumeCreditPack,
      'accountRequestDeletion': SimApiRoutes.accountRequestDeletion,
    };

    final contractRoutes = <String, String>{};
    void collect(Object? node) {
      if (node is! Map) return;
      if (node['dartName'] is String && node['path'] is String) {
        contractRoutes[node['dartName'] as String] =
            '${definitions['basePath']}${node['path']}';
        return;
      }
      for (final value in node.values) {
        collect(value);
      }
    }

    collect(definitions['routes']);
    for (final entry in routeConstants.entries) {
      expect(entry.value, contractRoutes[entry.key], reason: entry.key);
    }

    expect(SimEnvironment.t00Path, SimApiRoutes.t00Bootstrap);
    expect(SimEnvironment.t02Path, SimApiRoutes.t02CompleteLesson);
    expect(SimEnvironment.audioPath, SimApiRoutes.generateLessonAudio);
    expect(simT00BootstrapPath, SimApiRoutes.t00Bootstrap);
    expect(simLessonAudioPath, SimApiRoutes.generateLessonAudio);
    expect(simVisualRoutePath, SimApiRoutes.visualRoute);
    expect(simProcessAttachmentPath, SimApiRoutes.processAttachment);
  });
}
