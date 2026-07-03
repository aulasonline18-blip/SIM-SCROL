import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/chat_aula_screen.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_widgets.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  testWidgets('chat timeline renders messages and answer callbacks', (
    tester,
  ) async {
    AnswerLetter? chosen;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'm1',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.explanation,
                text: 'Explicacao',
              ),
              ChatLessonMessage(
                id: 'm2',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.options,
                options: [
                  ChatLessonOption(
                    letter: AnswerLetter.A,
                    text: 'Alternativa A',
                    selected: false,
                    enabled: true,
                  ),
                  ChatLessonOption(
                    letter: AnswerLetter.B,
                    text: 'Alternativa B',
                    selected: false,
                    enabled: true,
                  ),
                  ChatLessonOption(
                    letter: AnswerLetter.C,
                    text: 'Alternativa C',
                    selected: false,
                    enabled: true,
                  ),
                ],
              ),
            ],
            onChooseAnswer: (letter) => chosen = letter,
            onSignal: (_) {},
            onRetry: () {},
            onNext: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('chat-aula-timeline')), findsOneWidget);
    expect(find.text('Explicacao'), findsOneWidget);
    expect(find.text('Alternativa B'), findsOneWidget);

    await tester.tap(find.text('Alternativa B'));
    expect(chosen, AnswerLetter.B);
  });

  testWidgets('chat timeline renders signal callbacks and retry action', (
    tester,
  ) async {
    var signal = 0;
    var retries = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'signals',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.signals,
                signals: [
                  ChatLessonSignal(
                    value: 1,
                    labelKey: 'aula_sig_certeza',
                    enabled: true,
                  ),
                  ChatLessonSignal(
                    value: 2,
                    labelKey: 'aula_sig_revisar',
                    enabled: true,
                  ),
                  ChatLessonSignal(
                    value: 3,
                    labelKey: 'aula_sig_nao_sei',
                    enabled: true,
                  ),
                ],
              ),
              ChatLessonMessage(
                id: 'error',
                role: ChatLessonMessageRole.system,
                kind: ChatLessonMessageKind.error,
                text: 'Erro controlado',
                actionKey: 'retry',
              ),
            ],
            onChooseAnswer: (_) {},
            onSignal: (value) => signal = value,
            onRetry: () => retries++,
            onNext: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('2'));
    expect(signal, 2);

    await tester.tap(find.text('Tentar novamente'));
    expect(retries, 1);
  });

  testWidgets('chat timeline renders feedback advance action', (tester) async {
    var advances = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'feedback',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.feedback,
                text: 'Exato! Você domina este ponto.',
                isCorrect: true,
                actionKey: 'aula_next_item',
              ),
            ],
            onChooseAnswer: (_) {},
            onSignal: (_) {},
            onRetry: () {},
            onNext: () => advances++,
          ),
        ),
      ),
    );

    expect(find.text('Exato! Você domina este ponto.'), findsOneWidget);
    await tester.tap(find.text('Próximo tópico'));
    expect(advances, 1);
  });

  testWidgets('chat classroom covers normal flow through feedback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final session = LabSession()
      ..authed = true
      ..authReady = true
      ..selectedLanguageCode = 'pt'
      ..stableLang = 'Portuguese'
      ..route = '/cyber/aula'
      ..aulaSnapshot = _chatSnapshot(
        phase: const ClassroomPhase.reading(),
        imagem: _svgDataUrl(),
      );

    await tester.pumpWidget(
      MaterialApp(home: ChatAulaScreen(session: session)),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);

    expect(find.byKey(const Key('chat-aula-timeline')), findsOneWidget);
    final timeline = tester.widget<ChatAulaTimeline>(
      find.byType(ChatAulaTimeline),
    );
    expect(
      timeline.messages.map((message) => message.kind),
      containsAllInOrder([
        ChatLessonMessageKind.explanation,
        ChatLessonMessageKind.image,
        ChatLessonMessageKind.question,
        ChatLessonMessageKind.options,
      ]),
    );
    expect(
      find.byType(ChatAulaMessageBubble, skipOffstage: false),
      findsWidgets,
    );
    expect(
      find.text('Explicacao da aula em chat.', skipOffstage: false),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Alternativa B'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Qual alternativa está correta?'), findsOneWidget);
    final optionB = find.text('Alternativa B');
    expect(optionB, findsOneWidget);

    await tester.tap(optionB);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('B', skipOffstage: false), findsWidgets);
    final signalPrompt = find.text('Como voce se sente?', skipOffstage: false);
    expect(signalPrompt, findsOneWidget);

    final signal2 = find.text('2', skipOffstage: false);
    await tester.ensureVisible(signal2);
    await tester.tap(signal2);
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.text('Exato! Você domina este ponto.', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Próximo', skipOffstage: false), findsOneWidget);
  });
}

LessonRuntimeSnapshot _chatSnapshot({
  required ClassroomPhase phase,
  String? imagem,
}) {
  return LessonRuntimeSnapshot(
    authReady: true,
    authed: true,
    hasCurriculum: true,
    isDone: false,
    viewModel: LessonMainViewModel(
      progress: 25,
      headerLabel: 'aula_item_of:1/4:aula_layer_1',
      options: const [],
      locked:
          phase.type == ClassroomPhaseType.processando ||
          phase.type == ClassroomPhaseType.concluido ||
          phase.type == ClassroomPhaseType.carregando,
      nextLabel: phase.type == ClassroomPhaseType.concluido ? 'aula_next' : '',
    ),
    phase: phase,
    history: const [],
    conteudo: const LessonContent(
      explanation: 'Explicacao da aula em chat.',
      question: 'Qual alternativa está correta?',
      options: {
        AnswerLetter.A: 'Alternativa A',
        AnswerLetter.B: 'Alternativa B',
        AnswerLetter.C: 'Alternativa C',
      },
      correctAnswer: AnswerLetter.B,
    ),
    imagem: imagem,
    itemMarker: 'M1',
    itemText: 'Item de teste',
  );
}

String _svgDataUrl() {
  final svg = Uri.encodeComponent(
    '<svg viewBox="0 0 120 80"><rect width="120" height="80" fill="#fff"/>'
    '<circle cx="60" cy="40" r="20" fill="#111827"/></svg>',
  );
  return 'data:image/svg+xml;utf8,$svg';
}
