import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/onboarding/preparation_and_placement.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/auxiliary/doubt_input_sheet.dart';
import 'package:sim_mobile/sim/config/sim_environment.dart';
import 'package:sim_mobile/sim/experience/student_experience_types.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  test(
    'default API URL is HTTPS so release APK boots without manual define',
    () {
      expect(SimEnvironment.apiBaseUrl, 'https://gemini-aid-pal.lovable.app');
      expect(SimEnvironment.assertProductionSafe, returnsNormally);
    },
  );

  test(
    'curriculo tenta preparar aula sem redirecionar para login antes do T00',
    () async {
      var called = false;
      final session =
          LabSession(
              experiencePreparerOverride: (args) async {
                called = true;
                args.onStage?.call(StudentExperienceRouteStage.curriculum);
                args.onStage?.call(StudentExperienceRouteStage.lesson);
                args.onStage?.call(StudentExperienceRouteStage.ready);
                return const StudentExperienceResult(
                  destination: '/cyber/aula',
                  curriculum: StudentCurriculum(
                    topic: 'Matematica',
                    totalItems: 1,
                    generatedAt: null,
                    provisional: false,
                    items: [CurriculumItem(marker: 'M1', text: 'Frações')],
                  ),
                  startMarker: 'M1',
                  startItemIndex: 0,
                );
              },
            )
            ..selectedLanguageCode = 'pt'
            ..stableLang = 'pt-BR'
            ..freeText = 'Quero aprender frações começando do zero.';

      expect(session.saveObjectiveEntry(), isTrue);
      expect(session.route, '/cyber/curriculo');
      expect(session.authed, isFalse);
      expect(session.authReady, isFalse);

      await session.launchExperience();

      expect(called, isTrue);
      expect(session.entryStatus, 'primeira_aula_pronta');
      expect(session.entryError, isNull);
      expect(session.route, '/cyber/aula');
    },
  );

  testWidgets(
    'curriculo copia SimWeb e espera authReady/authed antes de chamar T00',
    (tester) async {
      var called = false;
      final session =
          LabSession(
              experiencePreparerOverride: (args) async {
                called = true;
                args.onStage?.call(StudentExperienceRouteStage.curriculum);
                args.onStage?.call(StudentExperienceRouteStage.lesson);
                args.onStage?.call(StudentExperienceRouteStage.ready);
                return const StudentExperienceResult(
                  destination: '/cyber/aula',
                  curriculum: StudentCurriculum(
                    topic: 'Matematica',
                    totalItems: 1,
                    generatedAt: null,
                    provisional: false,
                    items: [CurriculumItem(marker: 'M1', text: 'Frações')],
                  ),
                  startMarker: 'M1',
                  startItemIndex: 0,
                );
              },
            )
            ..selectedLanguageCode = 'pt'
            ..stableLang = 'pt-BR'
            ..freeText = 'Quero aprender frações começando do zero.';

      expect(session.saveObjectiveEntry(), isTrue);

      await tester.pumpWidget(
        MaterialApp(home: PhaseBoundaryScreen(session: session)),
      );
      await tester.pump();
      expect(called, isFalse);

      session
        ..authReady = true
        ..authed = true;
      session.setFreeText(session.freeText);

      await tester.pump();
      await tester.pump();

      expect(called, isTrue);
      expect(session.route, '/cyber/aula');
    },
  );

  test(
    'startNewLessonFromDrawer clears stale aula media and audio UI state',
    () {
      final session = LabSession()
        ..lessonLocalId = 'lesson-old'
        ..imageStatus = 'error'
        ..imageError = 'erro anterior'
        ..lessonImageOfferId = 'offer-old'
        ..lessonImageOfferLoading = true
        ..audioPlaying = true
        ..audioLoading = true
        ..aulaSnapshot = const LessonRuntimeSnapshot(
          authReady: true,
          authed: true,
          hasCurriculum: true,
          isDone: false,
          viewModel: LessonMainViewModel(
            progress: 0,
            headerLabel: 'aula_item_of:1/1:aula_layer_1',
            options: [],
            locked: false,
            nextLabel: '',
          ),
          phase: ClassroomPhase.reading(),
          history: [],
          conteudo: LessonContent(
            explanation: 'Explicacao',
            question: 'Pergunta?',
            options: {
              AnswerLetter.A: 'A',
              AnswerLetter.B: 'B',
              AnswerLetter.C: 'C',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: 'data:image/svg+xml;utf8,%3Csvg%3E%3C%2Fsvg%3E',
          itemMarker: 'M1',
          itemText: 'Item antigo',
        );

      session.startNewLessonFromDrawer();

      expect(session.lessonLocalId, isNull);
      expect(session.aulaSnapshot, isNull);
      expect(session.imageStatus, 'idle');
      expect(session.imageError, isNull);
      expect(session.lessonImageOfferId, isNull);
      expect(session.lessonImageOfferLoading, isFalse);
      expect(session.audioPlaying, isFalse);
      expect(session.audioLoading, isFalse);
      expect(session.route, '/cyber/aula');
    },
  );

  test('submitDoubt ignores duplicate submission while processing', () async {
    final session = LabSession()
      ..setDoubt(
        const DoubtState(status: DoubtStatus.processing, progress: 15),
      );

    await session.submitDoubt(const DoubtInputDraft(text: 'Nao entendi.'));

    expect(session.doubt.status, DoubtStatus.processing);
    expect(session.doubt.progress, 15);
  });

  test('LessonRuntimeSnapshot.copyWith can override and clear every field', () {
    final original = const LessonRuntimeSnapshot(
      authReady: true,
      authed: true,
      hasCurriculum: true,
      isDone: false,
      viewModel: LessonMainViewModel(
        progress: 20,
        headerLabel: 'aula_item_of:1/5:aula_layer_1',
        options: [],
        locked: false,
        nextLabel: '',
      ),
      phase: ClassroomPhase.reading(),
      history: [],
      conteudo: LessonContent(
        explanation: 'Explicacao',
        question: 'Pergunta?',
        options: {
          AnswerLetter.A: 'A',
          AnswerLetter.B: 'B',
          AnswerLetter.C: 'C',
        },
        correctAnswer: AnswerLetter.A,
      ),
      imagem: 'data:image/png;base64,AAAA',
      itemMarker: 'M1',
      itemText: 'Item 1',
    );

    final updated = original.copyWith(
      authReady: false,
      authed: false,
      hasCurriculum: false,
      isDone: true,
      viewModel: null,
      phase: const ClassroomPhase.loading(),
      history: const [
        QuestionHistoryEntry(
          id: 'q1',
          text: 'Q?',
          options: [],
          chosenOptionId: AnswerLetter.B,
          correct: false,
        ),
      ],
      conteudo: null,
      imagem: null,
      itemMarker: null,
      itemText: null,
    );

    expect(updated.authReady, isFalse);
    expect(updated.authed, isFalse);
    expect(updated.hasCurriculum, isFalse);
    expect(updated.isDone, isTrue);
    expect(updated.viewModel, isNull);
    expect(updated.phase.type, ClassroomPhaseType.carregando);
    expect(updated.history, hasLength(1));
    expect(updated.conteudo, isNull);
    expect(updated.imagem, isNull);
    expect(updated.itemMarker, isNull);
    expect(updated.itemText, isNull);
  });
}
