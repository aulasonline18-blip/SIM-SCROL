import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
import 'aux_room_addendums.dart';
import 'aux_room_models.dart';
import 'doubt_input_sheet.dart';

class DoubtT02Caller {
  const DoubtT02Caller({required this.client});

  final T02LessonClient client;

  Future<DoubtResponse> call({
    required String lessonLocalId,
    required AuxRoomProfile profile,
    required String itemText,
    required String currentContent,
    required LessonLayer layer,
    required int itemIdx,
    String? currentQuestion,
    Map<AnswerLetter, String> currentOptions = const {},
    String? marker,
    String? studentDoubt,
    DoubtImagePayload? doubtImage,
  }) async {
    final draft = DoubtInputDraft(text: studentDoubt ?? '', image: doubtImage);
    final validation = draft.validate();
    if (validation != null) {
      throw ArgumentError(validation);
    }
    final text = draft.cleanText;
    final addon = getAuxRoomAddon(AuxRoomMode.doubt);
    final currentContentPayload = _currentContentPayload(
      explanation: currentContent,
      question: currentQuestion,
      options: currentOptions,
    );
    final locale = profile.effectiveLocaleContract;
    final profilePayload = profile.toJson();
    final material = await client.doubt(
      T02LessonRequest(
        lessonLocalId: lessonLocalId,
        item: itemText,
        lang: locale.explanationLanguage,
        academic: profile.academicLevel ?? 'ensino_medio',
        layer: layer,
        mode: AuxRoomMode.doubt.name,
        errCount: 0,
        history: [currentContent, text],
        marker: marker,
        profile: {
          ...profilePayload,
          'lessonLocalId': lessonLocalId,
          'mode': AuxRoomMode.doubt.name,
          'aux_mode': AuxRoomMode.doubt.name,
          'stable_lang': locale.explanationLanguage,
          'localeContract': locale.toJson(),
          'interfaceLocale': locale.interfaceLocale,
          'learningLocale': locale.learningLocale,
          'explanationLanguage': locale.explanationLanguage,
          if (locale.targetLanguage != null)
            'targetLanguage': locale.targetLanguage,
          'mediaTextLanguage': locale.mediaTextLanguage,
          'academic_level': profile.academicLevel ?? 'ensino_medio',
          if (profile.preferredName != null)
            'preferred_name': profile.preferredName,
          'student_profile_internal':
              profile.extra['student_profile_internal'] ?? profilePayload,
          'item': itemText,
          'marker': marker,
          'itemIdx': itemIdx,
          'layer': layer.value,
          'current_content': currentContentPayload,
          'current_explanation': currentContent,
          if ((currentQuestion ?? '').trim().isNotEmpty)
            'current_question': currentQuestion!.trim(),
          if (currentOptions.isNotEmpty)
            'current_options': _optionsPayload(currentOptions),
          'student_doubt': text,
          if (doubtImage != null)
            'doubt_image': {
              'name': doubtImage.name,
              'type': doubtImage.type,
              'size': doubtImage.size,
              'dataUrl': doubtImage.dataUrl,
              'hasDataUrl': doubtImage.dataUrl.isNotEmpty,
            },
        },
        addendum: addon,
        itemIdx: itemIdx,
        interfaceLocale: locale.interfaceLocale,
        learningLocale: locale.learningLocale,
        explanationLanguage: locale.explanationLanguage,
        targetLanguage: locale.targetLanguage,
        localeContract: locale,
      ),
    );
    final explanation = material.explanation.trim();
    if (explanation.isEmpty) throw const FormatException('empty explanation');
    return DoubtResponse(
      explanation: explanation,
      visualTrigger: normalizeDoubtVisualTrigger(material.visualTrigger),
    );
  }
}

JsonMap _currentContentPayload({
  required String explanation,
  String? question,
  Map<AnswerLetter, String> options = const {},
}) {
  return {
    'explanation': explanation,
    if ((question ?? '').trim().isNotEmpty) 'question': question!.trim(),
    if (options.isNotEmpty) 'options': _optionsPayload(options),
  };
}

JsonMap _optionsPayload(Map<AnswerLetter, String> options) => {
  'A': options[AnswerLetter.A] ?? '',
  'B': options[AnswerLetter.B] ?? '',
  'C': options[AnswerLetter.C] ?? '',
};

JsonMap normalizeDoubtVisualTrigger(Object? value) {
  final map = value is Map ? JsonMap.from(value) : const <String, dynamic>{};
  return {
    'needs_image': map['needs_image'] == true,
    'pedagogical_need': (map['pedagogical_need'] ?? 'none').toString(),
    'render_strategy': (map['render_strategy'] ?? 'software').toString(),
    'svg_payload': (map['svg_payload'] ?? '').toString(),
    'topic': (map['topic'] ?? '').toString(),
    'visual_type': (map['visual_type'] ?? 'none').toString(),
    'key_elements': map['key_elements'] is List
        ? List<Object?>.from(map['key_elements'] as List)
        : const <Object?>[],
    'color_legend': map['color_legend'] is List
        ? List<Object?>.from(map['color_legend'] as List)
        : const <Object?>[],
    'highlight_focus': (map['highlight_focus'] ?? '').toString(),
    'complexity': (map['complexity'] ?? 'simple').toString(),
    'image_prompt': (map['image_prompt'] ?? '').toString(),
  };
}
