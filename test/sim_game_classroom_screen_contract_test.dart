import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/game_runtime_controller.dart';
import 'package:sim_mobile/sim/game/microdeck.dart';
import 'package:sim_mobile/sim/game/pedagogical_card.dart';
import 'package:sim_mobile/sim/game/ui/game_classroom_screen.dart';
import 'package:sim_mobile/sim/game/ui/game_card_view.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameClassroomScreen contract', () {
    test('GameClassroomScreen is a final class', () {
      expect(
        _source(),
        contains('final class GameClassroomScreen extends StatefulWidget'),
      );
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

    test('product state contains only local error', () {
      final source = _source();

      expect(source, contains('Object? _localError;'));
      expect(source, isNot(contains('Object? _selectedAnswer')));
      expect(source, isNot(contains('Object? _selectedQualifier')));
      expect(source, isNot(contains('String? _feedbackText')));
      expect(source, isNot(contains('GameStateStore')));
      expect(source, isNot(contains('LocalGameRuntime')));
    });

    test('product does not know internal game objects or old app UI', () {
      final source = _source();

      const forbidden = [
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
        'GoRouter',
        'AutoRoute',
      ];

      for (final token in forbidden) {
        expect(source, isNot(contains(token)), reason: token);
      }
      expect(source, isNot(contains(RegExp(r'\bDio\b|package:dio|dio\.'))));
      expect(source, isNot(contains(RegExp(r'\bdio\b'))));
      expect(source, isNot(contains(RegExp(r'\bMicrodeck\b'))));
    });

    test('product does not call controller actions directly', () {
      final source = _source();

      expect(source, isNot(contains('loadMicrodeck')));
      expect(source, isNot(contains('selectAnswer')));
      expect(source, isNot(contains('selectQualifier')));
      expect(source, isNot(contains('advanceToNextCard')));
    });

    test('product does not call callbacks or mutate state in build body', () {
      final buildBody = _methodBody(_source(), 'Widget build');

      expect(buildBody, isNot(contains('setState(')));
      expect(buildBody, isNot(contains('.call(')));
      expect(buildBody, isNot(contains('loadMicrodeck')));
      expect(buildBody, isNot(contains('selectAnswer')));
      expect(buildBody, isNot(contains('selectQualifier')));
      expect(buildBody, isNot(contains('advanceToNextCard')));
    });

    test('required keys exist in product', () {
      final source = _source();

      for (final keyName in const [
        'sim_game_classroom_screen',
        'sim_game_classroom_header',
        'sim_game_classroom_status',
        'sim_game_classroom_card_host',
        'sim_game_classroom_error',
      ]) {
        expect(source, contains(keyName), reason: keyName);
      }
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

    testWidgets(
      'loaded controller shows GameCardView content and ready status',
      (tester) async {
        final controller = _loadedController(cardCount: 2);

        await tester.pumpScreen(controller);

        expect(_cardHostWithGameCardView(), findsOneWidget);
        expect(find.text('Carta pronta'), findsOneWidget);
        expect(find.text('Explicacao da carta 1'), findsOneWidget);
        expect(find.text('Pergunta da carta 1?'), findsOneWidget);
        expect(find.textContaining('card-1'), findsOneWidget);
        expect(find.textContaining('indice 1'), findsOneWidget);
      },
    );

    testWidgets('A/B/C tap rebuilds status and shows qualifiers', (
      tester,
    ) async {
      final controller = _loadedController();

      await tester.pumpScreen(controller);
      await tester.tap(find.byKey(const Key('sim_game_answer_A')));
      await tester.pump();

      expect(find.text('Escolha seu sinal'), findsOneWidget);
      expect(find.byKey(const Key('sim_game_qualifier_1')), findsOneWidget);
      expect(find.byKey(const Key('sim_game_qualifier_2')), findsOneWidget);
      expect(find.byKey(const Key('sim_game_qualifier_3')), findsOneWidget);
      expect(find.byKey(const Key('sim_game_feedback')), findsNothing);
    });

    testWidgets('1/2/3 tap rebuilds status and shows feedback', (tester) async {
      final controller = _loadedController();

      await tester.pumpScreen(controller);
      await tester.tap(find.byKey(const Key('sim_game_answer_A')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sim_game_qualifier_1')));
      await tester.pump();

      expect(find.text('Feedback'), findsOneWidget);
      expect(find.byKey(const Key('sim_game_feedback')), findsOneWidget);
      expect(find.text('Feedback da alternativa A'), findsOneWidget);
    });

    testWidgets('continue advances to next prepared card', (tester) async {
      final controller = _loadedController(cardCount: 2);

      await tester.pumpScreen(controller);
      await tester.tap(find.byKey(const Key('sim_game_answer_A')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sim_game_qualifier_1')));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('sim_game_continue_button')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('sim_game_continue_button')));
      await tester.pump();

      expect(controller.currentCardId, 'card-2');
      expect(find.text('Carta pronta'), findsOneWidget);
      expect(find.text('Explicacao da carta 2'), findsOneWidget);
      expect(find.byKey(const Key('sim_game_feedback')), findsNothing);
    });

    testWidgets(
      'continue without next card shows preparing without fake button',
      (tester) async {
        final controller = _loadedController(cardCount: 1);
        final order = <String>[];

        await tester.pumpScreen(
          controller,
          onNeedMicrodeck: () => order.add('need'),
        );
        await tester.tap(find.byKey(const Key('sim_game_answer_A')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('sim_game_qualifier_1')));
        await tester.pump();
        await tester.ensureVisible(
          find.byKey(const Key('sim_game_continue_button')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('sim_game_continue_button')));
        order.add('after-tap');
        await tester.pump();
        order.add('after-pump');

        expect(controller.needsMicrodeck, isTrue);
        expect(find.text('Preparando carta'), findsWidgets);
        expect(find.byKey(const Key('sim_game_answer_A')), findsNothing);
        expect(find.byKey(const Key('sim_game_continue_button')), findsNothing);
        expect(order, ['after-tap', 'need', 'after-pump']);
      },
    );

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

    testWidgets('error is visible and calls external onError', (tester) async {
      final controller = _loadedController();
      final errors = <Object>[];

      await tester.pumpScreen(controller, nowMs: () => 0, onError: errors.add);
      await tester.tap(find.byKey(const Key('sim_game_answer_A')));
      await tester.pump();

      expect(errors, hasLength(1));
      expect(find.byKey(const Key('sim_game_classroom_error')), findsOneWidget);
      expect(find.text('Erro local. Tente novamente.'), findsOneWidget);
      expect(controller.selectedAnswer, isNull);
    });

    testWidgets('error is cleared after next valid card change', (
      tester,
    ) async {
      final controller = _loadedController();
      var stamp = 0;

      await tester.pumpScreen(controller, nowMs: () => stamp);
      await tester.tap(find.byKey(const Key('sim_game_answer_A')));
      await tester.pump();
      expect(find.byKey(const Key('sim_game_classroom_error')), findsOneWidget);

      stamp = 1;
      await tester.tap(find.byKey(const Key('sim_game_answer_A')));
      await tester.pump();

      expect(find.byKey(const Key('sim_game_classroom_error')), findsNothing);
      expect(find.text('Escolha seu sinal'), findsOneWidget);
    });

    testWidgets('doubt and audio callbacks are only repassed', (tester) async {
      final controller = _loadedController(withMedia: true);
      var doubt = 0;
      var audio = 0;

      await tester.pumpScreen(
        controller,
        onOpenDoubt: () => doubt += 1,
        onToggleAudio: () => audio += 1,
      );

      await tester.tap(find.byKey(const Key('sim_game_doubt_button')));
      await tester.tap(find.byKey(const Key('sim_game_audio_button')));
      await tester.pump();

      expect(doubt, 1);
      expect(audio, 1);
    });

    testWidgets('media does not block question', (tester) async {
      final controller = _loadedController(withMedia: true);

      await tester.pumpScreen(controller, mediaEnabled: false);

      expect(find.byKey(const Key('sim_game_image_placeholder')), findsNothing);
      expect(find.byKey(const Key('sim_game_question')), findsOneWidget);
      expect(find.byKey(const Key('sim_game_answer_A')), findsOneWidget);
    });

    testWidgets('small viewport has no exception', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      final controller = _loadedController(withMedia: true);

      await tester.pumpScreen(controller);
      await tester.tap(find.byKey(const Key('sim_game_answer_A')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sim_game_qualifier_1')));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}

extension on WidgetTester {
  Future<void> pumpScreen(
    GameRuntimeController controller, {
    int Function()? nowMs,
    bool mediaEnabled = true,
    bool audioEnabled = true,
    VoidCallback? onNeedMicrodeck,
    VoidCallback? onOpenDoubt,
    VoidCallback? onToggleAudio,
    void Function(Object error)? onError,
  }) {
    return pumpWidget(
      MaterialApp(
        home: GameClassroomScreen(
          controller: controller,
          nowMs: nowMs ?? _clock(),
          mediaEnabled: mediaEnabled,
          audioEnabled: audioEnabled,
          onNeedMicrodeck: onNeedMicrodeck,
          onOpenDoubt: onOpenDoubt,
          onToggleAudio: onToggleAudio,
          onError: onError,
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

GameRuntimeController _loadedController({
  int cardCount = 1,
  bool withMedia = false,
}) {
  final controller = GameRuntimeController();
  controller.loadMicrodeck(
    _microdeck(cardCount: cardCount, withMedia: withMedia),
    clientTimestampMs: 1,
  );
  return controller;
}

Microdeck _microdeck({required int cardCount, required bool withMedia}) {
  return Microdeck(
    microdeckId: 'microdeck-1',
    cards: [
      for (var index = 1; index <= cardCount; index += 1)
        _card(index, withMedia: withMedia && index == 1),
    ],
    currentIndex: 0,
  );
}

PedagogicalCard _card(int index, {required bool withMedia}) {
  return PedagogicalCard(
    cardId: 'card-$index',
    deckId: 'deck-1',
    lessonLocalId: 'lesson-1',
    marker: 'M-$index',
    itemIdx: index - 1,
    layer: LessonLayer.l1,
    explanation: 'Explicacao da carta $index',
    question: 'Pergunta da carta $index?',
    options: const {
      AnswerLetter.A: 'Opcao A',
      AnswerLetter.B: 'Opcao B',
      AnswerLetter.C: 'Opcao C',
    },
    correctAnswer: AnswerLetter.A,
    feedback: const {
      AnswerLetter.A: 'Feedback da alternativa A',
      AnswerLetter.B: 'Feedback da alternativa B',
      AnswerLetter.C: 'Feedback da alternativa C',
    },
    qualifiers: const {
      DecisionSignal.one: 'Tenho certeza',
      DecisionSignal.two: 'Quero revisar',
      DecisionSignal.three: 'Nao sei',
    },
    advancePolicy: const {
      DecisionSignal.one: 'avance',
      DecisionSignal.two: 'revise',
      DecisionSignal.three: 'recupere',
    },
    contentHash: 'hash-$index',
    contractVersion: PedagogicalCard.supportedContractVersion,
    serverSignature: 'signature-$index',
    media: withMedia
        ? PedagogicalCardMedia(
            imageKey: 'image-key-$index',
            audioKey: 'audio-key-$index',
          )
        : null,
  );
}

int Function() _clock() {
  var value = 1;
  return () => value++;
}

String _source() {
  return File('lib/sim/game/ui/game_classroom_screen.dart').readAsStringSync();
}

String _methodBody(String source, String signature) {
  final start = source.indexOf(signature);
  expect(start, isNonNegative);
  final open = source.indexOf('{', start);
  expect(open, isNonNegative);
  var depth = 0;
  for (var index = open; index < source.length; index += 1) {
    final char = source[index];
    if (char == '{') depth += 1;
    if (char == '}') depth -= 1;
    if (depth == 0) return source.substring(open, index + 1);
  }
  fail('method body not closed');
}
