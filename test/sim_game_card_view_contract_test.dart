import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/game/game_runtime_controller.dart';
import 'package:sim_mobile/sim/game/microdeck.dart';
import 'package:sim_mobile/sim/game/pedagogical_card.dart';
import 'package:sim_mobile/sim/game/ui/game_card_view.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameCardView contract', () {
    test('GameCardView is a final class', () {
      final source = _source();

      expect(
        source,
        contains('final class GameCardView extends StatelessWidget'),
      );
    });

    testWidgets('renders explanation, question, and A/B/C', (tester) async {
      final controller = _loadedController();

      await tester.pumpHarness(controller);

      expect(find.byKey(const Key('sim_game_explanation')), findsOneWidget);
      expect(find.text('Explicacao da carta 1'), findsOneWidget);
      expect(find.byKey(const Key('sim_game_question')), findsOneWidget);
      expect(find.text('Pergunta da carta 1?'), findsOneWidget);
      expect(find.byKey(const Key('sim_game_answer_A')), findsOneWidget);
      expect(find.byKey(const Key('sim_game_answer_B')), findsOneWidget);
      expect(find.byKey(const Key('sim_game_answer_C')), findsOneWidget);
    });

    testWidgets('A/B/C taps use AnswerLetter and rebuild through onChanged', (
      tester,
    ) async {
      for (final entry in const [
        MapEntry('sim_game_answer_A', AnswerLetter.A),
        MapEntry('sim_game_answer_B', AnswerLetter.B),
        MapEntry('sim_game_answer_C', AnswerLetter.C),
      ]) {
        final controller = _loadedController();
        var changed = 0;

        await tester.pumpHarness(controller, onChanged: () => changed += 1);

        expect(find.byKey(const Key('sim_game_qualifier_1')), findsNothing);
        await tester.tap(find.byKey(Key(entry.key)));
        await tester.pump();

        expect(controller.selectedAnswer, entry.value);
        expect(changed, 1);
        expect(find.byKey(const Key('sim_game_qualifier_1')), findsOneWidget);
        expect(find.byKey(const Key('sim_game_qualifier_2')), findsOneWidget);
        expect(find.byKey(const Key('sim_game_qualifier_3')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(Key(entry.key)),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('feedback is hidden until a DecisionSignal is selected', (
      tester,
    ) async {
      final controller = _loadedController();
      var changed = 0;

      await tester.pumpHarness(controller, onChanged: () => changed += 1);

      await tester.tap(find.byKey(const Key('sim_game_answer_A')));
      await tester.pump();

      expect(find.byKey(const Key('sim_game_feedback')), findsNothing);
      expect(controller.canSelectQualifier, isTrue);

      await tester.tap(find.byKey(const Key('sim_game_qualifier_1')));
      await tester.pump();

      expect(controller.selectedQualifier, DecisionSignal.one);
      expect(find.byKey(const Key('sim_game_feedback')), findsOneWidget);
      expect(find.text('Feedback da alternativa A'), findsOneWidget);
      expect(changed, 2);
    });

    testWidgets('1/2/3 taps use DecisionSignal', (tester) async {
      for (final entry in const [
        MapEntry('sim_game_qualifier_1', DecisionSignal.one),
        MapEntry('sim_game_qualifier_2', DecisionSignal.two),
        MapEntry('sim_game_qualifier_3', DecisionSignal.three),
      ]) {
        final controller = _loadedController();

        await tester.pumpHarness(controller);
        await tester.tap(find.byKey(const Key('sim_game_answer_A')));
        await tester.pump();
        await tester.tap(find.byKey(Key(entry.key)));
        await tester.pump();

        expect(controller.selectedQualifier, entry.value);
        expect(find.byKey(const Key('sim_game_feedback')), findsOneWidget);
      }
    });

    testWidgets(
      'empty state shows no answer, qualifier, feedback, or advance',
      (tester) async {
        final controller = GameRuntimeController();

        await tester.pumpHarness(controller);

        expect(find.byKey(const Key('sim_game_card_empty')), findsOneWidget);
        expect(
          find.byKey(const Key('sim_game_needs_microdeck')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('sim_game_answer_A')), findsNothing);
        expect(find.byKey(const Key('sim_game_answer_B')), findsNothing);
        expect(find.byKey(const Key('sim_game_answer_C')), findsNothing);
        expect(find.byKey(const Key('sim_game_qualifier_1')), findsNothing);
        expect(find.byKey(const Key('sim_game_qualifier_2')), findsNothing);
        expect(find.byKey(const Key('sim_game_qualifier_3')), findsNothing);
        expect(find.byKey(const Key('sim_game_feedback')), findsNothing);
        expect(find.byKey(const Key('sim_game_continue_button')), findsNothing);
      },
    );

    testWidgets('needsMicrodeck is explicit and never automatic in build', (
      tester,
    ) async {
      final controller = GameRuntimeController();
      var needs = 0;
      var changed = 0;
      var opened = 0;
      var audio = 0;

      await tester.pumpHarness(
        controller,
        onNeedMicrodeck: () => needs += 1,
        onChanged: () => changed += 1,
        onOpenDoubt: () => opened += 1,
        onToggleAudio: () => audio += 1,
      );

      expect(needs, 0);
      expect(changed, 0);
      expect(opened, 0);
      expect(audio, 0);

      await tester.tap(find.byKey(const Key('sim_game_need_microdeck_action')));
      await tester.pump();

      expect(needs, 1);
      expect(changed, 0);
    });

    testWidgets('without next card, continue marks needsMicrodeck only', (
      tester,
    ) async {
      final controller = _loadedController(cardCount: 1);
      var needs = 0;
      var changed = 0;

      await tester.pumpHarness(
        controller,
        onNeedMicrodeck: () => needs += 1,
        onChanged: () => changed += 1,
      );

      await tester.tap(find.byKey(const Key('sim_game_answer_A')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sim_game_qualifier_1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sim_game_continue_button')));
      await tester.pump();

      expect(needs, 1);
      expect(controller.needsMicrodeck, isTrue);
      expect(find.byKey(const Key('sim_game_needs_microdeck')), findsOneWidget);
      expect(find.byKey(const Key('sim_game_continue_button')), findsNothing);
      expect(find.byKey(const Key('sim_game_answer_A')), findsNothing);
      expect(changed, 3);
    });

    testWidgets('continue can advance to a prepared next card', (tester) async {
      final controller = _loadedController(cardCount: 2);

      await tester.pumpHarness(controller);
      await tester.tap(find.byKey(const Key('sim_game_answer_A')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sim_game_qualifier_1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sim_game_continue_button')));
      await tester.pump();

      expect(controller.currentCardId, 'card-2');
      expect(controller.needsMicrodeck, isFalse);
      expect(find.text('Explicacao da carta 2'), findsOneWidget);
      expect(find.byKey(const Key('sim_game_feedback')), findsNothing);
    });

    testWidgets('selection failure calls onError and does not call onChanged', (
      tester,
    ) async {
      final controller = _loadedController();
      final errors = <Object>[];
      var changed = 0;

      await tester.pumpHarness(
        controller,
        nowMs: () => 0,
        onError: errors.add,
        onChanged: () => changed += 1,
      );

      await tester.tap(find.byKey(const Key('sim_game_answer_A')));
      await tester.pump();

      expect(errors, hasLength(1));
      expect(changed, 0);
      expect(controller.selectedAnswer, isNull);
      expect(find.byKey(const Key('sim_game_qualifier_1')), findsNothing);
    });

    testWidgets('qualifier failure calls onError and preserves state', (
      tester,
    ) async {
      final controller = _loadedController();
      var stamp = 10;
      final errors = <Object>[];
      var changed = 0;

      await tester.pumpHarness(
        controller,
        nowMs: () {
          final value = stamp;
          stamp = 0;
          return value;
        },
        onError: errors.add,
        onChanged: () => changed += 1,
      );

      await tester.tap(find.byKey(const Key('sim_game_answer_A')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sim_game_qualifier_1')));
      await tester.pump();

      expect(errors, hasLength(1));
      expect(changed, 1);
      expect(controller.selectedAnswer, AnswerLetter.A);
      expect(controller.selectedQualifier, isNull);
      expect(find.byKey(const Key('sim_game_feedback')), findsNothing);
    });

    testWidgets('after feedback, A/B/C does not accept silent change', (
      tester,
    ) async {
      final controller = _loadedController();
      var changed = 0;

      await tester.pumpHarness(controller, onChanged: () => changed += 1);
      await tester.tap(find.byKey(const Key('sim_game_answer_A')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sim_game_qualifier_1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sim_game_answer_B')));
      await tester.pump();

      expect(controller.selectedAnswer, AnswerLetter.A);
      expect(changed, 2);
    });

    testWidgets('media is lightweight and optional', (tester) async {
      final controller = _loadedController(withMedia: true);
      var audio = 0;
      var doubt = 0;

      await tester.pumpHarness(
        controller,
        onToggleAudio: () => audio += 1,
        onOpenDoubt: () => doubt += 1,
      );

      expect(
        find.byKey(const Key('sim_game_image_placeholder')),
        findsOneWidget,
      );
      expect(find.textContaining('image-key-1'), findsOneWidget);
      expect(find.byKey(const Key('sim_game_audio_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sim_game_audio_button')));
      await tester.tap(find.byKey(const Key('sim_game_doubt_button')));
      await tester.pump();

      expect(audio, 1);
      expect(doubt, 1);
    });

    testWidgets('disabled media does not block question or A/B/C', (
      tester,
    ) async {
      final controller = _loadedController(withMedia: true);

      await tester.pumpHarness(
        controller,
        mediaEnabled: false,
        audioEnabled: false,
      );

      expect(find.byKey(const Key('sim_game_image_placeholder')), findsNothing);
      expect(find.byKey(const Key('sim_game_audio_button')), findsNothing);
      expect(find.byKey(const Key('sim_game_question')), findsOneWidget);
      expect(find.byKey(const Key('sim_game_answer_A')), findsOneWidget);
      expect(find.byKey(const Key('sim_game_answer_B')), findsOneWidget);
      expect(find.byKey(const Key('sim_game_answer_C')), findsOneWidget);
    });

    testWidgets('small viewport has no render exception', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;

      final controller = _loadedController(withMedia: true);

      await tester.pumpHarness(controller);
      await tester.tap(find.byKey(const Key('sim_game_answer_A')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sim_game_qualifier_1')));
      await tester.pump();

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

    test('product file avoids forbidden architecture and media tokens', () {
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
        'streak',
        'ranking',
        'leaderboard',
        'coin',
        'purchase',
        'comprar',
      ];

      for (final token in forbidden) {
        expect(source, isNot(contains(token)), reason: token);
      }
      expect(source, isNot(contains(RegExp(r'\bDio\b|package:dio|dio\.'))));
      expect(source, isNot(contains('String answer')));
      expect(source, isNot(contains('int signal')));
    });

    test('product file uses no automatic scroll helpers', () {
      final source = _source();

      expect(source, isNot(contains('ScrollController')));
      expect(source, isNot(contains('ensureVisible')));
      expect(source, isNot(contains('animateTo')));
      expect(source, isNot(contains('addPostFrameCallback')));
      expect(source, isNot(contains('initialScroll')));
    });
  });
}

extension on WidgetTester {
  Future<void> pumpHarness(
    GameRuntimeController controller, {
    int Function()? nowMs,
    bool mediaEnabled = true,
    bool audioEnabled = true,
    VoidCallback? onChanged,
    VoidCallback? onNeedMicrodeck,
    VoidCallback? onOpenDoubt,
    VoidCallback? onToggleAudio,
    void Function(Object error)? onError,
  }) {
    return pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _CardHarness(
            controller: controller,
            nowMs: nowMs ?? _clock(),
            mediaEnabled: mediaEnabled,
            audioEnabled: audioEnabled,
            onChanged: onChanged,
            onNeedMicrodeck: onNeedMicrodeck,
            onOpenDoubt: onOpenDoubt,
            onToggleAudio: onToggleAudio,
            onError: onError,
          ),
        ),
      ),
    );
  }
}

class _CardHarness extends StatefulWidget {
  const _CardHarness({
    required this.controller,
    required this.nowMs,
    required this.mediaEnabled,
    required this.audioEnabled,
    this.onChanged,
    this.onNeedMicrodeck,
    this.onOpenDoubt,
    this.onToggleAudio,
    this.onError,
  });

  final GameRuntimeController controller;
  final int Function() nowMs;
  final bool mediaEnabled;
  final bool audioEnabled;
  final VoidCallback? onChanged;
  final VoidCallback? onNeedMicrodeck;
  final VoidCallback? onOpenDoubt;
  final VoidCallback? onToggleAudio;
  final void Function(Object error)? onError;

  @override
  State<_CardHarness> createState() => _CardHarnessState();
}

class _CardHarnessState extends State<_CardHarness> {
  @override
  Widget build(BuildContext context) {
    return GameCardView(
      controller: widget.controller,
      nowMs: widget.nowMs,
      mediaEnabled: widget.mediaEnabled,
      audioEnabled: widget.audioEnabled,
      onChanged: () {
        widget.onChanged?.call();
        setState(() {});
      },
      onNeedMicrodeck: widget.onNeedMicrodeck,
      onOpenDoubt: widget.onOpenDoubt,
      onToggleAudio: widget.onToggleAudio,
      onError: widget.onError,
    );
  }
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
    marker: 'M$index',
    itemIdx: index - 1,
    layer: LessonLayer.l1,
    explanation: 'Explicacao da carta $index',
    question: 'Pergunta da carta $index?',
    options: const {
      AnswerLetter.A: 'Alternativa A',
      AnswerLetter.B: 'Alternativa B',
      AnswerLetter.C: 'Alternativa C',
    },
    correctAnswer: AnswerLetter.A,
    feedback: const {
      AnswerLetter.A: 'Feedback da alternativa A',
      AnswerLetter.B: 'Feedback da alternativa B',
      AnswerLetter.C: 'Feedback da alternativa C',
    },
    qualifiers: const {
      DecisionSignal.one: 'Entendi',
      DecisionSignal.two: 'Quase',
      DecisionSignal.three: 'Preciso revisar',
    },
    advancePolicy: const {
      DecisionSignal.one: 'Avancar',
      DecisionSignal.two: 'Reforcar',
      DecisionSignal.three: 'Retomar',
    },
    contentHash: 'hash-$index',
    contractVersion: PedagogicalCard.supportedContractVersion,
    serverSignature: 'signature-$index',
    media: withMedia
        ? const PedagogicalCardMedia(
            imageKey: 'image-key-1',
            audioKey: 'audio-key-1',
          )
        : null,
  );
}

int Function() _clock() {
  var stamp = 10;
  return () => stamp += 1;
}

String _source() {
  return File('lib/sim/game/ui/game_card_view.dart').readAsStringSync();
}
