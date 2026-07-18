import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
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
    final material = await client.doubt(
      T02LessonRequest(
        lessonLocalId: lessonLocalId,
        item: itemText,
        lang: profile.stableLang ?? 'Portuguese',
        academic: profile.academicLevel ?? 'ensino_medio',
        layer: layer,
        mode: AuxRoomMode.doubt.name,
        errCount: 0,
        history: [currentContent, text],
        marker: marker,
        profile: {
          ...profile.toJson(),
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
        addendum: getAuxRoomAddonReference(AuxRoomMode.doubt),
      ),
    );
    return DoubtResponse(explanation: material.explanation);
  }
}
