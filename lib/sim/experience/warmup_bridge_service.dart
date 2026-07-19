import '../localization/sim_locale_contract.dart';
import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
import 'student_experience_types.dart';
import 'warmup_bridge_addendum.dart';

const String warmupWelcomeBridgeMode = 'WARMUP_WELCOME_BRIDGE';

class WarmupBridgeRequest {
  const WarmupBridgeRequest({
    required this.lessonLocalId,
    required this.objective,
    required this.ficha,
    required this.locale,
    required this.academic,
  });

  final String lessonLocalId;
  final String objective;
  final JsonMap ficha;
  final SimLocaleContract locale;
  final String academic;
}

class WarmupBridgeService {
  const WarmupBridgeService({required this.t02Client});

  final T02LessonClient t02Client;

  Future<SimWarmupLesson> prepare(WarmupBridgeRequest request) async {
    final objective = request.objective.trim();
    if (objective.length < 4) {
      throw const WarmupBridgeException('warmup_objective_required');
    }
    final ficha = _warmupFicha(request, objective);
    final material = await t02Client.completeLesson(
      T02LessonRequest(
        lessonLocalId: request.lessonLocalId,
        item: _firstText([
          ficha['target_topic'],
          ficha['subject'],
          ficha['learning_goal'],
          objective,
        ], fallback: 'boas-vindas'),
        lang: request.locale.explanationLanguage,
        academic: request.academic,
        layer: LessonLayer.l1,
        mode: 'warmup_welcome_bridge',
        errCount: 0,
        history: const [],
        marker: 'WARMUP',
        profile: ficha,
        addendum: warmupWelcomeBridgeAddendum,
        curriculumItems: const [],
        topic: _firstText([
          ficha['target_topic'],
          ficha['subject'],
          objective,
        ], fallback: objective),
        itemIdx: 0,
        interfaceLocale: request.locale.interfaceLocale,
        learningLocale: request.locale.learningLocale,
        explanationLanguage: request.locale.explanationLanguage,
        targetLanguage: request.locale.targetLanguage,
      ),
    );
    return _lessonFromMaterial(material);
  }

  JsonMap _warmupFicha(WarmupBridgeRequest request, String objective) {
    return {
      ...request.ficha,
      ...request.locale.toJson(),
      'lessonLocalId': request.lessonLocalId,
      'objective': objective,
      'learning_goal': _firstText([
        request.ficha['learning_goal'],
        objective,
      ], fallback: objective),
      'session_goal': _firstText([
        request.ficha['session_goal'],
        objective,
      ], fallback: objective),
      'target_topic': _firstText([
        request.ficha['target_topic'],
        request.ficha['subject'],
        objective,
      ], fallback: objective),
      'academic_level': request.academic,
      'mode': warmupWelcomeBridgeMode,
      'warmupMode': warmupWelcomeBridgeMode,
      'warmup_mode': warmupWelcomeBridgeMode,
      'lesson_mode': 'warmup_welcome_bridge',
      'officialCurriculum': false,
      'countsForMastery': false,
      'source_status': 'warmup_not_official_curriculum',
      'visual_policy': 'optional_media_text_first',
      'guidance_for_T02': _firstText([
        request.ficha['guidance_for_T02'],
        request.ficha['guidanceForT02'],
        'Use the student real ficha to create a non-evaluative welcome bridge while the official lesson is prepared.',
      ]),
    };
  }

  SimWarmupLesson _lessonFromMaterial(T02LessonMaterial material) {
    final options = <String, String>{
      'A': material.options[AnswerLetter.A]?.trim() ?? '',
      'B': material.options[AnswerLetter.B]?.trim() ?? '',
      'C': material.options[AnswerLetter.C]?.trim() ?? '',
    };
    final lesson = SimWarmupLesson.fromJson({
      'explanation': material.explanation,
      'question': material.question,
      'options': options,
      'correctAnswer': material.correctAnswer.name,
      'whyCorrect': material.whyCorrect,
      'whyWrong': material.whyWrong,
      'type': 'warmup',
      'mode': warmupWelcomeBridgeMode,
      'welcomeBridge': true,
      'officialCurriculum': false,
      'countsForMastery': false,
      'source': material.source,
    });
    if (lesson == null) {
      throw const WarmupBridgeException('warmup_t02_contract_invalid');
    }
    return lesson;
  }

  String _firstText(List<Object?> values, {String fallback = ''}) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }
}

class WarmupBridgeException implements Exception {
  const WarmupBridgeException(this.code);

  final String code;

  @override
  String toString() => code;
}
