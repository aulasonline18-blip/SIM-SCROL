import '../state/student_learning_state.dart';
import 'aux_room_models.dart';
import 'doubt_input_sheet.dart';
import 'doubt_t02_caller.dart';

const String defaultDoubtError =
    'Nao consegui carregar a explicacao, tente novamente.';

typedef DoubtScopeStillCurrent = bool Function(DoubtRequestScope scope);

class DoubtRequestScope {
  const DoubtRequestScope({
    required this.lessonLocalId,
    required this.marker,
    required this.itemIdx,
    required this.layer,
  });

  final String lessonLocalId;
  final String? marker;
  final int itemIdx;
  final LessonLayer layer;

  String get key => '$lessonLocalId|${marker ?? ''}|$itemIdx|${layer.value}';
}

class LessonDoubtController {
  LessonDoubtController({required this.caller}) : state = DoubtState.idle;

  final DoubtT02Caller caller;
  DoubtState state;
  int _requestGeneration = 0;

  String get progressLabel {
    if (state.progress < 30) return 'Enviando sua dúvida...';
    if (state.progress < 60) return 'Professor esta analisando...';
    if (state.progress < 90) return 'Preparando explicacao...';
    return 'Quase pronto...';
  }

  void askDoubt() {
    if (state.status == DoubtStatus.processing) return;
    state = state.copyWith(sheetOpen: true, error: null);
  }

  void dismissDoubt() {
    _requestGeneration++;
    state = state.copyWith(sheetOpen: false);
  }

  void reset() {
    _requestGeneration++;
    state = DoubtState.idle;
  }

  Future<void> submitDoubt({
    required String lessonLocalId,
    required AuxRoomProfile profile,
    required String itemText,
    required String currentContent,
    required LessonLayer layer,
    required int itemIdx,
    String? currentQuestion,
    Map<AnswerLetter, String> currentOptions = const {},
    String? marker,
    required DoubtInputDraft input,
    DoubtScopeStillCurrent? isScopeStillCurrent,
  }) async {
    if (state.status == DoubtStatus.processing) return;
    final validation = input.validate();
    if (validation != null) {
      state = state.copyWith(
        status: DoubtStatus.error,
        progress: 0,
        sheetOpen: true,
        error: validation,
      );
      return;
    }
    final generation = ++_requestGeneration;
    final scope = DoubtRequestScope(
      lessonLocalId: lessonLocalId,
      marker: marker,
      itemIdx: itemIdx,
      layer: layer,
    );
    bool stale() =>
        generation != _requestGeneration ||
        isScopeStillCurrent != null && !isScopeStillCurrent(scope);
    state = const DoubtState(
      status: DoubtStatus.processing,
      progress: 15,
      sheetOpen: false,
    );
    try {
      if (stale()) return;
      state = state.copyWith(progress: 60);
      final response = await caller.call(
        lessonLocalId: lessonLocalId,
        profile: profile,
        itemText: itemText,
        currentContent: currentContent,
        layer: layer,
        itemIdx: itemIdx,
        currentQuestion: currentQuestion,
        currentOptions: currentOptions,
        marker: marker,
        studentDoubt: input.cleanText,
        doubtImage: input.image,
      );
      if (stale()) return;
      state = DoubtState(
        status: DoubtStatus.explaining,
        progress: 100,
        response: response,
      );
    } catch (_) {
      if (stale()) return;
      state = const DoubtState(
        status: DoubtStatus.error,
        progress: 0,
        error: defaultDoubtError,
      );
    }
  }
}
