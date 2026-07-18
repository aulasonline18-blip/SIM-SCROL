import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_timeline_builder.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/learning_decision_engine.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_lesson_executor.dart';

void main() {
  group('regra oficial viva de avanco', () {
    test('L1 correto + sinal 1 vai direto para L3', () {
      final next = _answer(
        _state(layer: LessonLayer.l1),
        AnswerLetter.A,
        DecisionSignal.one,
      );

      expect(next.progress?.itemIdx, 0);
      expect(next.progress?.layer, LessonLayer.l3);
      expect(_decision(next), DecisionActionType.advanceLayer.name);
    });

    test('L1 correto + sinal 2 vai para L2', () {
      final next = _answer(
        _state(layer: LessonLayer.l1),
        AnswerLetter.A,
        DecisionSignal.two,
      );

      expect(next.progress?.itemIdx, 0);
      expect(next.progress?.layer, LessonLayer.l2);
      expect(_decision(next), DecisionActionType.advanceLayer.name);
    });

    test('L1 correto + sinal 3 vai para L2', () {
      final next = _answer(
        _state(layer: LessonLayer.l1),
        AnswerLetter.A,
        DecisionSignal.three,
      );

      expect(next.progress?.itemIdx, 0);
      expect(next.progress?.layer, LessonLayer.l2);
      expect(_decision(next), DecisionActionType.advanceLayer.name);
    });

    test('L1 erro + qualquer sinal vai para L2', () {
      for (final signal in DecisionSignal.values) {
        final next = _answer(
          _state(layer: LessonLayer.l1),
          AnswerLetter.B,
          signal,
        );

        expect(next.progress?.itemIdx, 0, reason: 'signal ${signal.value}');
        expect(next.progress?.layer, LessonLayer.l2, reason: signal.name);
        expect(_decision(next), DecisionActionType.advanceLayer.name);
      }
    });

    test('L2 qualquer resultado/sinal vai para L3', () {
      for (final signal in DecisionSignal.values) {
        for (final letter in [AnswerLetter.A, AnswerLetter.B]) {
          final next = _answer(_state(layer: LessonLayer.l2), letter, signal);

          expect(next.progress?.itemIdx, 0);
          expect(next.progress?.layer, LessonLayer.l3);
          expect(_decision(next), DecisionActionType.advanceLayer.name);
        }
      }
    });

    test('L3 qualquer resultado/sinal vai para proximo item L1', () {
      for (final signal in DecisionSignal.values) {
        for (final letter in [AnswerLetter.A, AnswerLetter.B]) {
          final next = _answer(_state(layer: LessonLayer.l3), letter, signal);

          expect(next.progress?.itemIdx, 1);
          expect(next.progress?.layer, LessonLayer.l1);
          expect(_decision(next), DecisionActionType.advanceItem.name);
        }
      }
    });

    test('qualificador nunca abre revisao ou recuperacao automaticamente', () {
      final next = _answer(
        _state(layer: LessonLayer.l2),
        AnswerLetter.B,
        DecisionSignal.three,
      );
      final events = next.events.map((event) => event.type).toList();
      final payload = next.events
          .lastWhere((event) => event.type == 'STUDENT_DECISION_APPLIED')
          .payload;

      expect(events.where((type) => type.startsWith('REVIEW_')), isEmpty);
      expect(events.where((type) => type.startsWith('RECOVERY_')), isEmpty);
      expect(payload['review'], isFalse);
      expect(payload['recovery'], isFalse);
      expect(payload['auxiliaryPolicy'], 'manual_only');
      expect(payload['blocked'], isFalse);
    });
  });

  test('feedback aparece em fase concluida antes de qualquer proxima acao', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: LessonRuntimeSnapshot(
          authReady: true,
          authed: true,
          hasCurriculum: true,
          isDone: false,
          viewModel: null,
          phase: const ClassroomPhase.completed(
            message: 'aula_fb_wrong_dont_know',
            wasCorrect: false,
            signal: DecisionSignal.three,
          ),
          history: const [],
          conteudo: _content,
          imagem: null,
          itemMarker: 'M1',
          itemText: 'Item 1',
        ),
        runtimeLoading: false,
        lessonLocalId: 'lesson-official-rule',
      ),
    );

    expect(
      messages.map((message) => message.kind),
      contains(ChatLessonMessageKind.feedback),
    );
    expect(
      messages.where((message) => message.kind == ChatLessonMessageKind.review),
      isEmpty,
    );
    expect(
      messages.where(
        (message) => message.kind == ChatLessonMessageKind.recovery,
      ),
      isEmpty,
    );
  });

  test('runtime nao contem rotas antigas de decisao pedagogica remota', () {
    final forbidden = [
      '/api/advance-gate',
      '/api/review',
      '/api/recovery',
      '/api/doubt',
      '/api/warmup',
    ];
    final runtimeText = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    for (final route in forbidden) {
      expect(runtimeText, isNot(contains(route)), reason: route);
    }
  });
}

const _content = LessonContent(
  explanation: 'Explicacao.',
  question: 'Pergunta?',
  options: {AnswerLetter.A: 'A', AnswerLetter.B: 'B', AnswerLetter.C: 'C'},
  correctAnswer: AnswerLetter.A,
);

StudentLearningState _state({required LessonLayer layer}) {
  const items = [
    CurriculumItem(marker: 'M1', text: 'Item 1'),
    CurriculumItem(marker: 'M2', text: 'Item 2'),
  ];
  return StudentLearningState.empty(lessonLocalId: 'official-advance').copyWith(
    curriculum: const StudentCurriculum(
      topic: 'Tema',
      totalItems: 2,
      generatedAt: 1,
      provisional: false,
      items: items,
    ),
    current: LessonCurrent(
      itemIdx: 0,
      marker: 'M1',
      layer: layer,
      amparoLvl: 0,
    ),
    progress: LessonProgress(
      itemIdx: 0,
      layer: layer,
      erros: 0,
      amparoLvl: 0,
      historia: const [],
      mainAdvances: 0,
      concluidos: const [],
      pendentesMarkers: const ['M1', 'M2'],
      totalItems: 2,
      pctAvanco: 0,
    ),
  );
}

StudentLearningState _answer(
  StudentLearningState state,
  AnswerLetter letter,
  DecisionSignal signal,
) {
  return processAnswerWithEngine(
    state,
    AnswerContext(letra: letter, sinal: signal, correctAnswer: AnswerLetter.A),
    now: signal.value,
  );
}

String? _decision(StudentLearningState state) {
  return state.events
          .lastWhere((event) => event.type == 'STUDENT_DECISION_APPLIED')
          .payload['decision']
      as String?;
}
