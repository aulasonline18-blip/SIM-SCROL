part of 'student_lesson_material_service.dart';

extension StudentLessonMaterialFailures on StudentLessonMaterialService {
  void appendBackgroundMaterialFailed(
    ResolveLessonMaterialInput input,
    Object error,
  ) {
    stateService.appendEvent(
      input.lessonLocalId,
      StudentLearningEvent(
        type: 'LESSON_BACKGROUND_MATERIAL_FAILED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'lessonLocalId': input.lessonLocalId,
          'itemIdx': input.itemIdx,
          'marker': input.marker,
          'layer': input.layer.value,
          'mode': input.params.mode.name,
          'operation': 'resolveLessonMaterialFromStateOrEngine',
          'recoverable': true,
          'retryAvailable': true,
          'errorCode': lessonMaterialFailureCode(error),
        },
      ),
    );
  }

  String lessonMaterialFailureCode(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('contract') || text.contains('invalid')) {
      return 'CONTRACT_INVALID';
    }
    if (text.contains('401') || text.contains('403')) {
      return 'AUTH_REQUIRED';
    }
    if (text.contains('402') || text.contains('credit')) {
      return 'CREDIT_REQUIRED';
    }
    if (text.contains('429')) return 'RATE_LIMITED';
    if (text.contains('timeout') || text.contains('408')) return 'TIMEOUT';
    if (text.contains('500') ||
        text.contains('502') ||
        text.contains('503') ||
        text.contains('504')) {
      return 'SERVER_UNAVAILABLE';
    }
    return 'REQUEST_FAILED';
  }
}
