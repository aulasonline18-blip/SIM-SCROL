import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_widgets.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  tearDown(() => setSimActiveLanguage('pt-BR'));

  testWidgets('aula mostra loading e retry em ingles', (tester) async {
    setSimActiveLanguage('en');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'menu-lesson-arriving-active',
                role: ChatLessonMessageRole.system,
                kind: ChatLessonMessageKind.loading,
              ),
              ChatLessonMessage(
                id: 'engine-error',
                role: ChatLessonMessageRole.system,
                kind: ChatLessonMessageKind.error,
                actionKey: 'retry-menu-lesson',
              ),
            ],
            onChooseAnswer: (_) {},
            onSignal: (_) {},
            onRetry: () {},
            onNext: () {},
            onOpenDoubt: () {},
          ),
        ),
      ),
    );

    expect(
      find.text('You chose this lesson. I am fetching it.'),
      findsOneWidget,
    );
    expect(find.text('I could not prepare the lesson now.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('aula mostra loading e retry em espanhol', (tester) async {
    setSimActiveLanguage('es');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'menu-lesson-arriving-active',
                role: ChatLessonMessageRole.system,
                kind: ChatLessonMessageKind.loading,
              ),
              ChatLessonMessage(
                id: 'engine-error',
                role: ChatLessonMessageRole.system,
                kind: ChatLessonMessageKind.error,
                actionKey: 'retry-menu-lesson',
              ),
            ],
            onChooseAnswer: (_) {},
            onSignal: (_) {},
            onRetry: () {},
            onNext: () {},
            onOpenDoubt: () {},
          ),
        ),
      ),
    );

    expect(
      find.text('Elegiste esta clase. La estoy buscando.'),
      findsOneWidget,
    );
    expect(find.text('No pude preparar la clase ahora.'), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('conteudo pedagogico da aula nao e traduzido pela UI locale', (
    tester,
  ) async {
    setSimActiveLanguage('en');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'exp',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.explanation,
                text: 'Explicação gerada em português',
              ),
            ],
            onChooseAnswer: (_) {},
            onSignal: (_) {},
            onRetry: () {},
            onNext: () {},
            onOpenDoubt: () {},
          ),
        ),
      ),
    );

    expect(find.text('Explicação gerada em português'), findsOneWidget);
  });
}
