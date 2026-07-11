import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_widgets.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/experience/curriculum_utils.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  setUp(() => setSimActiveLanguage('pt'));

  test('parser and state preserve unit from T00EF curriculum items', () {
    final items = normalizeCurriculumItems({
      'items': [
        {
          'marker': 'M0007',
          'unit': 'Movimento uniforme',
          'title': 'Velocidade constante',
          'microitem_for_teacher': 'Conceito de velocidade constante.',
        },
      ],
    });

    expect(items.single.unit, 'Movimento uniforme');
    expect(items.single.marker, 'M0007');
    expect(items.single.title, 'Velocidade constante');

    final restored = CurriculumItem.fromJson(items.single.toJson());
    expect(restored.unit, 'Movimento uniforme');
    expect(restored.marker, 'M0007');
    expect(restored.title, 'Velocidade constante');
  });

  test(
    'view model carries unit marker and title to the lesson runtime layer',
    () {
      const item = PlannedItem(
        marker: 'M0007',
        unit: 'Movimento uniforme',
        title: 'Velocidade constante',
        text: 'Conceito de velocidade constante.',
      );

      final vm = buildLessonMainViewModel(
        baseItems: const [item],
        mainAdvances: 0,
        isReviewAtivo: false,
        itemAtivo: item,
        itemIdx: 0,
        layer: LessonLayer.l1,
        phase: const ClassroomPhase.reading(),
        conteudo: const LessonContent(
          explanation: 'Um corpo em movimento uniforme mantém velocidade.',
          question: 'O que permanece constante?',
          options: {},
          correctAnswer: AnswerLetter.A,
        ),
        items: const [item],
      );

      expect(vm.itemUnit, 'Movimento uniforme');
      expect(vm.itemMarker, 'M0007');
      expect(vm.itemTitle, 'Velocidade constante');
    },
  );

  testWidgets('explanation card shows live pedagogical header with unit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAulaTimeline(
            messages: const [
              ChatLessonMessage(
                id: 'exp',
                role: ChatLessonMessageRole.sim,
                kind: ChatLessonMessageKind.explanation,
                text: 'Um corpo em movimento uniforme mantém velocidade.',
                marker: 'M0007',
                unit: 'Movimento uniforme',
                title: 'Velocidade constante',
                isActionable: false,
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

    expect(find.text('TEORIA · Movimento uniforme'), findsOneWidget);
    expect(find.text('M0007 · Velocidade constante'), findsOneWidget);
    expect(
      find.text('Um corpo em movimento uniforme mantém velocidade.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'old curriculum items without unit keep safe marker/title fallback',
    (tester) async {
      final old = CurriculumItem.fromJson({
        'marker': 'M1',
        'title': 'Frações equivalentes',
        'text': 'Frações equivalentes',
      });
      expect(old.unit, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatAulaTimeline(
              messages: [
                ChatLessonMessage(
                  id: 'exp-old',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.explanation,
                  text: 'Explicacao antiga preservada.',
                  marker: old.marker,
                  title: old.title,
                  isActionable: false,
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

      expect(find.text('TEORIA · M1 · Frações equivalentes'), findsOneWidget);
      expect(find.text('TEORIA ·'), findsNothing);
    },
  );
}
