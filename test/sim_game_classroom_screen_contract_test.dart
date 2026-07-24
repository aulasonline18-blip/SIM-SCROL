import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/game_runtime_controller.dart';
import 'package:sim_mobile/sim/game/microdeck.dart';
import 'package:sim_mobile/sim/game/pedagogical_card_integrity_verifier.dart';
import 'package:sim_mobile/sim/game/ui/game_card_view.dart';
import 'package:sim_mobile/sim/game/ui/game_classroom_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameClassroomScreen contract', () {
    test('GameClassroomScreen is a final class', () {
      expect(
        _source(),
        contains('final class GameClassroomScreen extends StatefulWidget'),
      );
    });

    testWidgets('starts preparing when controller is empty', (tester) async {
      final controller = GameRuntimeController();
      var needs = 0;

      await tester.pumpScreen(controller, onNeedMicrodeck: () => needs += 1);

      expect(
        find.byKey(const Key('sim_game_classroom_screen')),
        findsOneWidget,
      );
      expect(find.text('Preparando carta'), findsWidgets);
      expect(find.byKey(const Key('sim_game_card_empty')), findsOneWidget);
      expect(find.byKey(const Key('sim_game_answer_A')), findsNothing);
      expect(find.byKey(const Key('sim_game_answer_B')), findsNothing);
      expect(find.byKey(const Key('sim_game_answer_C')), findsNothing);
      expect(needs, 0);
    });

    testWidgets('carta bloqueada por assinatura nao vira carta jogavel', (
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

      await tester.pumpScreen(controller);

      expect(controller.currentCard, isNull);
      expect(find.text('Preparando carta'), findsWidgets);
      expect(_cardHostWithGameCardView(), findsOneWidget);
      expect(find.byKey(const Key('sim_game_answer_A')), findsNothing);
      expect(find.byKey(const Key('sim_game_answer_B')), findsNothing);
      expect(find.byKey(const Key('sim_game_answer_C')), findsNothing);
    });

    testWidgets('needMicrodeck callback runs only by explicit card action', (
      tester,
    ) async {
      final controller = GameRuntimeController();
      var needs = 0;

      await tester.pumpScreen(controller, onNeedMicrodeck: () => needs += 1);
      await tester.pump();
      expect(needs, 0);

      await tester.tap(find.byKey(const Key('sim_game_need_microdeck_action')));
      await tester.pump();

      expect(needs, 1);
    });

    testWidgets('small viewport empty screen has no exception', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpScreen(GameRuntimeController());

      expect(tester.takeException(), isNull);
    });

    test('product imports are exactly the allowed imports', () {
      final imports = RegExp(
        r"^import .+;$",
        multiLine: true,
      ).allMatches(_source()).map((match) => match.group(0)).toList();

      expect(imports, [
        "import 'package:flutter/material.dart';",
        "import '../game_runtime_controller.dart';",
        "import 'game_card_view.dart';",
      ]);
    });

    test('product does not call controller actions directly', () {
      final source = _source();

      expect(source, isNot(contains('loadMicrodeck')));
      expect(source, isNot(contains('selectAnswer')));
      expect(source, isNot(contains('selectQualifier')));
      expect(source, isNot(contains('advanceToNextCard')));
    });

    test('product does not know internal game objects or old app UI', () {
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
        'PedagogicalCard',
        'LocalGameRuntime',
        'GameStateStore',
        'PedagogicalEvent',
        'PedagogicalEventLog',
        'AnswerLetter',
        'DecisionSignal',
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
        'Navigator',
        'pushNamed',
        'routes',
        'MaterialApp',
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
    });
  });
}

extension on WidgetTester {
  Future<void> pumpScreen(
    GameRuntimeController controller, {
    VoidCallback? onNeedMicrodeck,
  }) {
    return pumpWidget(
      MaterialApp(
        home: GameClassroomScreen(
          controller: controller,
          nowMs: () => 10,
          onNeedMicrodeck: onNeedMicrodeck,
        ),
      ),
    );
  }
}

Finder _cardHostWithGameCardView() {
  return find.descendant(
    of: find.byKey(const Key('sim_game_classroom_card_host')),
    matching: find.byType(GameCardView),
  );
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
  return File('lib/sim/game/ui/game_classroom_screen.dart').readAsStringSync();
}
