import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/game_runtime_controller.dart';
import 'package:sim_mobile/sim/game/microdeck.dart';
import 'package:sim_mobile/sim/game/pedagogical_card_integrity_verifier.dart';
import 'package:sim_mobile/sim/game/ui/game_card_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameCardView contract', () {
    test('GameCardView is a final class', () {
      expect(
        _source(),
        contains('final class GameCardView extends StatelessWidget'),
      );
    });

    testWidgets('empty controller renders honest preparing state only', (
      tester,
    ) async {
      final controller = GameRuntimeController();

      await tester.pumpHarness(controller);

      expect(find.byKey(const Key('sim_game_card_empty')), findsOneWidget);
      expect(find.byKey(const Key('sim_game_needs_microdeck')), findsOneWidget);
      expect(find.byKey(const Key('sim_game_answer_A')), findsNothing);
      expect(find.byKey(const Key('sim_game_answer_B')), findsNothing);
      expect(find.byKey(const Key('sim_game_answer_C')), findsNothing);
      expect(find.byKey(const Key('sim_game_qualifier_1')), findsNothing);
      expect(find.byKey(const Key('sim_game_qualifier_2')), findsNothing);
      expect(find.byKey(const Key('sim_game_qualifier_3')), findsNothing);
      expect(find.byKey(const Key('sim_game_feedback')), findsNothing);
      expect(find.byKey(const Key('sim_game_continue_button')), findsNothing);
    });

    testWidgets('carta bloqueada por assinatura nao mostra A/B/C', (
      tester,
    ) async {
      final controller = GameRuntimeController();

      expect(
        () => controller.loadMicrodeck(
          const TestFixtureMicrodeck(),
          clientTimestampMs: 10,
        ),
        throwsA(isA<PedagogicalCardIntegrityException>()),
      );

      await tester.pumpHarness(controller);

      expect(controller.currentCard, isNull);
      expect(controller.hasPlayableCard, isFalse);
      expect(find.byKey(const Key('sim_game_card_empty')), findsOneWidget);
      expect(find.byKey(const Key('sim_game_answer_A')), findsNothing);
      expect(find.byKey(const Key('sim_game_answer_B')), findsNothing);
      expect(find.byKey(const Key('sim_game_answer_C')), findsNothing);
    });

    testWidgets('onNeedMicrodeck ocorre apenas por acao explicita', (
      tester,
    ) async {
      final controller = GameRuntimeController();
      var needs = 0;

      await tester.pumpHarness(controller, onNeedMicrodeck: () => needs += 1);

      expect(needs, 0);
      await tester.tap(find.byKey(const Key('sim_game_need_microdeck_action')));
      await tester.pump();
      expect(needs, 1);
    });

    testWidgets('small viewport empty state has no render exception', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpHarness(GameRuntimeController());

      expect(tester.takeException(), isNull);
    });

    test('product imports are exactly the allowed imports', () {
      final imports = RegExp(
        r"^import .+;$",
        multiLine: true,
      ).allMatches(_source()).map((match) => match.group(0)).toList();

      expect(imports, [
        "import 'package:flutter/material.dart';",
        "import '../../state/student_learning_state.dart';",
        "import '../game_runtime_controller.dart';",
        "import '../pedagogical_card.dart';",
      ]);
    });

    test(
      'product file avoids forbidden architecture, media, and weak modes',
      () {
        final source = _source();
        const forbidden = [
          'skipSignature',
          'allowUnsigned',
          'allowHashOnly',
          'testMode',
          'LabSession',
          'LessonRuntimeEngine',
          'ChatAulaScreen',
          'Timeline',
          'chat_aula',
          'lab_session',
          'http',
          'Supabase',
          'SharedPreferences',
          'Drift',
          'GameSyncClient',
          'PedagogicalEvent',
          'PedagogicalEventLog',
          'Future',
          'async',
          'Timer',
          'Stream',
          'DateTime.now',
          'unawaited',
          'Image.memory',
          'Image.network',
          'base64Decode',
          'SvgPicture.string',
          'Map<String, dynamic>',
          'String answer',
          'int signal',
          'T00',
          'T02',
          'N3',
          'prompt',
          'adendo',
          'credit',
          'credito',
          'ledger',
          'billing',
          'cost',
          'AiCostProtectionGate',
        ];

        for (final token in forbidden) {
          expect(source, isNot(contains(token)), reason: token);
        }
        expect(
          source,
          isNot(
            contains(
              'by'
              'pass',
            ),
          ),
        );
        expect(source, isNot(contains(RegExp(r'\bDio\b|package:dio|dio\.'))));
      },
    );
  });
}

extension on WidgetTester {
  Future<void> pumpHarness(
    GameRuntimeController controller, {
    VoidCallback? onNeedMicrodeck,
  }) {
    return pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameCardView(
            controller: controller,
            nowMs: () => 10,
            onNeedMicrodeck: onNeedMicrodeck,
          ),
        ),
      ),
    );
  }
}

final class TestFixtureMicrodeck implements Microdeck {
  const TestFixtureMicrodeck();

  @override
  void validate() {
    throw const PedagogicalCardIntegrityException(
      'signatureVerificationUnavailable',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _source() {
  return File('lib/sim/game/ui/game_card_view.dart').readAsStringSync();
}
