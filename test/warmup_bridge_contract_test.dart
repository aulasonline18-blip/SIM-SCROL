import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/experience/student_experience_types.dart';
import 'package:sim_mobile/sim/experience/warmup_bridge_addendum.dart';
import 'package:sim_mobile/sim/experience/warmup_bridge_service.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  group('Warmup welcome bridge constitucional', () {
    test('chama T02 com adendo e ficha real do aluno', () async {
      final t02 = _RecordingWarmupT02();
      final service = WarmupBridgeService(t02Client: t02);

      final lesson = await service.prepare(
        const WarmupBridgeRequest(
          lessonLocalId: 'lesson-warmup',
          objective: 'Kiribati conversation for real situations',
          ficha: {
            'preferred_name': 'Joel',
            'target_topic': 'Kiribati conversation',
            'known_weaknesses': 'starting from zero',
          },
          locale: SimLocaleContract(
            interfaceLocale: 'pt-BR',
            learningLocale: 'en',
            explanationLanguage: 'English',
          ),
          academic: 'adulto',
        ),
      );

      final request = t02.requests.single;
      expect(request.addendum, warmupWelcomeBridgeAddendum);
      expect(request.addendum, contains('WARMUP_WELCOME_BRIDGE'));
      expect(request.mode, 'warmup_welcome_bridge');
      expect(request.marker, 'WARMUP');
      expect(request.curriculumItems, isEmpty);
      expect(request.profile['preferred_name'], 'Joel');
      expect(request.profile['target_topic'], 'Kiribati conversation');
      expect(request.profile['officialCurriculum'], false);
      expect(request.profile['countsForMastery'], false);
      expect(lesson.options.keys, ['A', 'B', 'C']);
      expect(lesson.toJson()['officialCurriculum'], false);
      expect(lesson.toJson()['countsForMastery'], false);
      expect(lesson.toJson()['mode'], 'WARMUP_WELCOME_BRIDGE');
      expect(lesson.toJson()['welcomeBridge'], true);
    });

    test('resposta do warmup salva so extra e nao altera progresso', () {
      final session =
          LabSession(
              warmupBridgeService: WarmupBridgeService(
                t02Client: _RecordingWarmupT02(),
              ),
            )
            ..selectedLanguageCode = 'pt'
            ..stableLang = 'pt-BR'
            ..freeText =
                'Quero aprender deslocamento em física começando do zero.';

      expect(session.saveObjectiveEntry(), isTrue);
      final id = session.lessonLocalId!;
      final before = session.canonicalStore!.readState(id);
      session.warmupLesson = const SimWarmupLesson(
        explanation: 'Ponte real.',
        question: 'Como começar?',
        options: {'A': 'Com calma', 'B': 'Prova', 'C': 'Bloqueio'},
        correctAnswer: 'A',
      );

      session.chooseWarmupAnswer('A');

      final after = session.canonicalStore!.readState(id);
      expect(after.extra['warmup'], isA<Map>());
      expect((after.extra['warmup'] as Map)['selectedAnswer'], 'A');
      expect(after.current, before.current);
      expect(after.progress, before.progress);
      expect(after.attempts, before.attempts);
      expect(after.truth.toJson(), before.truth.toJson());
    });

    test(
      'abre warmup antes da oficial e navega para aula uma unica vez',
      () async {
        final officialReady = Completer<void>();
        final session =
            LabSession(
                warmupBridgeService: WarmupBridgeService(
                  t02Client: _RecordingWarmupT02(),
                ),
                experiencePreparerOverride: (args) async {
                  args.onStage?.call(StudentExperienceRouteStage.curriculum);
                  args.onStage?.call(StudentExperienceRouteStage.lesson);
                  await officialReady.future;
                  args.onStage?.call(StudentExperienceRouteStage.ready);
                  return _result();
                },
              )
              ..selectedLanguageCode = 'pt'
              ..stableLang = 'pt-BR'
              ..freeText =
                  'Quero aprender deslocamento em física começando do zero.';

        expect(session.saveObjectiveEntry(), isTrue);
        expect(session.route, '/cyber/placement');
        session.skipPlacement();
        final placement = session.canonicalStore!.readState(
          session.lessonLocalId!,
        );
        expect(placement.placement?['status'], 'skipped');
        expect(placement.placement?['choice'], 'start_from_zero');
        final launch = session.launchExperience();
        await Future<void>.delayed(Duration.zero);

        expect(session.route, '/cyber/curriculo');
        expect(session.warmupLesson, isNotNull);
        await session.continueFromPreparationToWarmup();
        expect(session.route, '/cyber/warmup');
        await session.continueFromWarmupToAula();
        expect(session.route, '/cyber/warmup');
        expect(session.warmupWaitingForOfficialLesson, isTrue);
        expect(session.aulaSnapshot, isNull);

        officialReady.complete();
        await launch;
        await Future<void>.delayed(Duration.zero);

        expect(session.route, '/cyber/aula');
        expect(session.warmupWaitingForOfficialLesson, isFalse);
        expect(session.aulaSnapshot, isNotNull);
        await session.continueFromWarmupToAula();
        expect(session.route, '/cyber/aula');
      },
    );

    test(
      'escolha encontrar ponto vai para curriculo, depois warmup e volta ao nivelamento com teste',
      () async {
        final officialReady = Completer<void>();
        final session =
            LabSession(
                warmupBridgeService: WarmupBridgeService(
                  t02Client: _RecordingWarmupT02(),
                ),
                experiencePreparerOverride: (args) async {
                  args.onStage?.call(StudentExperienceRouteStage.curriculum);
                  args.onStage?.call(StudentExperienceRouteStage.lesson);
                  await officialReady.future;
                  args.onStage?.call(StudentExperienceRouteStage.ready);
                  return _result();
                },
              )
              ..selectedLanguageCode = 'pt'
              ..stableLang = 'pt-BR'
              ..freeText =
                  'Quero aprender deslocamento em física começando do zero.';

        expect(session.saveObjectiveEntry(), isTrue);
        final launch = session.launchExperience();
        await Future<void>.delayed(Duration.zero);

        session.choosePlacementFindMyPointThenPreparation();
        expect(session.route, '/cyber/curriculo');
        expect(
          session.canonicalStore!
              .readState(session.lessonLocalId!)
              .placement?['choice'],
          'find_my_point',
        );

        expect(session.warmupLesson, isNotNull);
        await session.continueFromPreparationToWarmup();
        expect(session.route, '/cyber/warmup');
        await session.continueFromWarmupToAula();
        expect(session.route, '/cyber/warmup');

        officialReady.complete();
        await launch;
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final state = session.canonicalStore!.readState(session.lessonLocalId!);
        expect(session.route, '/cyber/placement');
        expect(state.placement?['status'], 'requested');
        expect(state.placement?['choice'], 'find_my_point');
      },
    );

    test('falha do warmup nao bloqueia aula oficial', () async {
      final session =
          LabSession(
              warmupBridgeService: WarmupBridgeService(
                t02Client: _FailingWarmupT02(),
              ),
              experiencePreparerOverride: (args) async {
                args.onStage?.call(StudentExperienceRouteStage.curriculum);
                args.onStage?.call(StudentExperienceRouteStage.lesson);
                args.onStage?.call(StudentExperienceRouteStage.ready);
                return _result();
              },
            )
            ..selectedLanguageCode = 'pt'
            ..stableLang = 'pt-BR'
            ..freeText =
                'Quero aprender deslocamento em física começando do zero.';

      expect(session.saveObjectiveEntry(), isTrue);
      expect(session.route, '/cyber/placement');
      session.skipPlacement();
      expect(session.route, '/cyber/curriculo');
      await session.launchExperience();
      await Future<void>.delayed(Duration.zero);

      expect(session.warmupLesson, isNull);
      expect(session.warmupError, isNotNull);
      expect(session.route, '/cyber/aula');
      expect(session.aulaSnapshot, isNotNull);
    });
  });
}

class _RecordingWarmupT02 implements T02LessonClient {
  final requests = <T02LessonRequest>[];

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    requests.add(request);
    return T02LessonMaterial(
      explanation:
          'Hello, Joel. While I prepare your full lesson, let us begin gently.',
      question: 'Which first step is a welcome bridge?',
      options: const {
        AnswerLetter.A: 'Start gently',
        AnswerLetter.B: 'Take a final exam',
        AnswerLetter.C: 'Block progress',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'A gentle start prepares the official lesson.',
      whyWrong: const {'B': 'This is not an assessment.'},
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'fake-warmup-t02',
    );
  }

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) {
    return completeLesson(request);
  }

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) {
    return completeLesson(request);
  }

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) {
    return completeLesson(request);
  }
}

class _FailingWarmupT02 extends _RecordingWarmupT02 {
  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) {
    requests.add(request);
    throw StateError('T02 down');
  }
}

StudentExperienceResult _result() {
  return const StudentExperienceResult(
    destination: '/cyber/aula',
    curriculum: StudentCurriculum(
      topic: 'Fisica',
      totalItems: 1,
      generatedAt: null,
      provisional: false,
      items: [CurriculumItem(marker: 'M1', text: 'Força')],
    ),
    startMarker: 'M1',
    startItemIndex: 0,
  );
}
