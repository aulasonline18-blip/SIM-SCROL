import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_t02_caller.dart';
import 'package:sim_mobile/sim/auxiliary/doubt_t02_caller.dart';
import 'package:sim_mobile/sim/localization/sim_locale_contract.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

const _locale = SimLocaleContract(
  interfaceLocale: 'en',
  learningLocale: 'es',
  explanationLanguage: 'English',
  mediaTextLanguage: 'English',
  targetLanguage: 'Spanish',
  source: SimLocaleSource.userSelected,
);

void main() {
  test('amparo/revisao envia localeContract e explanationLanguage', () async {
    final client = _RecordingT02Client();
    final caller = AuxRoomT02Caller(client: client);

    await caller.call(
      lessonLocalId: 'lesson-1',
      mode: AuxRoomMode.amparo,
      profile: const AuxRoomProfile(
        stableLang: 'English',
        academicLevel: 'base',
        localeContract: _locale,
      ),
      marker: 'M1',
      item: 'Item 1',
      signal: DecisionSignal.three,
      confirmEnabled: true,
    );

    expect(client.lastRequest?.lang, 'English');
    expect(client.lastRequest?.localeContract, _locale);
    expect(client.lastRequest?.profile['localeContract'], isA<Map>());
    expect(client.lastRequest?.profile['targetLanguage'], 'Spanish');
  });

  test('duvida envia localeContract e nao usa Portuguese implicito', () async {
    final client = _RecordingT02Client();
    final caller = DoubtT02Caller(client: client);

    await caller.call(
      lessonLocalId: 'lesson-1',
      profile: const AuxRoomProfile(
        stableLang: 'English',
        academicLevel: 'base',
        localeContract: _locale,
      ),
      itemText: 'Item 1',
      currentContent: 'Current explanation',
      layer: LessonLayer.l1,
      itemIdx: 0,
      studentDoubt: 'Why?',
    );

    expect(client.lastRequest?.lang, 'English');
    expect(client.lastRequest?.profile['stable_lang'], 'English');
    expect(client.lastRequest?.profile['localeContract'], isA<Map>());
    expect(client.lastRequest?.profile.values, isNot(contains('Portuguese')));
  });
}

class _RecordingT02Client implements T02LessonClient {
  T02LessonRequest? lastRequest;

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) async {
    lastRequest = request;
    return _material();
  }

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) async {
    lastRequest = request;
    return _material();
  }

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async =>
      _material();

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) async =>
      _material();
}

T02LessonMaterial _material() => T02LessonMaterial(
  explanation: 'Explanation',
  question: 'Question',
  options: const {
    AnswerLetter.A: 'A',
    AnswerLetter.B: 'B',
    AnswerLetter.C: 'C',
  },
  correctAnswer: AnswerLetter.A,
  whyCorrect: 'Because',
  whyWrong: const {},
  generatedAt: DateTime(2026, 7, 22),
  source: 'fake',
);
