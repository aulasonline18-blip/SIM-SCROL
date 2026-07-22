import '../media/lesson_image_api_contract.dart';
import '../state/live_entry_state.dart';
import '../state/student_learning_state.dart';
import 'lesson_content_validator.dart';
import 'lesson_models.dart';
import 'lesson_orchestrator.dart';

enum LessonReadinessStatus {
  readyFromState,
  readyFromMemoryCache,
  missing,
  stale,
  staleLocale,
  legacyLocale,
  invalid,
}

class LessonReadinessIdentity {
  const LessonReadinessIdentity({
    required this.lessonLocalId,
    required this.itemIdx,
    required this.marker,
    required this.layer,
  });

  final String lessonLocalId;
  final int itemIdx;
  final String? marker;
  final LessonLayer layer;

  String get preparedKey => preparedLessonMaterialKey(itemIdx, marker, layer);
}

class LessonReadinessResult {
  const LessonReadinessResult._({
    required this.status,
    this.lesson,
    this.discardedKey,
    this.safeReason,
  });

  const LessonReadinessResult.readyFromState(CompleteLesson lesson)
    : this._(status: LessonReadinessStatus.readyFromState, lesson: lesson);

  const LessonReadinessResult.readyFromMemoryCache(CompleteLesson lesson)
    : this._(
        status: LessonReadinessStatus.readyFromMemoryCache,
        lesson: lesson,
      );

  const LessonReadinessResult.missing()
    : this._(status: LessonReadinessStatus.missing);

  const LessonReadinessResult.stale(String key)
    : this._(status: LessonReadinessStatus.stale, discardedKey: key);

  const LessonReadinessResult.staleLocale(String key, String reason)
    : this._(
        status: LessonReadinessStatus.staleLocale,
        discardedKey: key,
        safeReason: reason,
      );

  const LessonReadinessResult.legacyLocale(String key, String reason)
    : this._(
        status: LessonReadinessStatus.legacyLocale,
        discardedKey: key,
        safeReason: reason,
      );

  const LessonReadinessResult.invalid(String key, String reason)
    : this._(
        status: LessonReadinessStatus.invalid,
        discardedKey: key,
        safeReason: reason,
      );

  final LessonReadinessStatus status;
  final CompleteLesson? lesson;
  final String? discardedKey;
  final String? safeReason;

  bool get isReady =>
      status == LessonReadinessStatus.readyFromState ||
      status == LessonReadinessStatus.readyFromMemoryCache;
}

class LessonReadinessResolver {
  const LessonReadinessResolver();

  LessonReadinessResult resolve({
    required StudentLearningState? state,
    required LessonOrchestrator orchestrator,
    required LessonReadinessIdentity identity,
    required CompleteLessonParams params,
  }) {
    final fromState = resolveFromState(
      state: state,
      identity: identity,
      params: params,
    );
    if (fromState.status == LessonReadinessStatus.readyFromState ||
        fromState.status == LessonReadinessStatus.invalid ||
        fromState.status == LessonReadinessStatus.stale ||
        fromState.status == LessonReadinessStatus.staleLocale ||
        fromState.status == LessonReadinessStatus.legacyLocale) {
      return fromState;
    }
    final cached = orchestrator.peekCachedLesson(lessonKeyFor(params));
    if (cached != null) {
      if (!_hasReadyText(cached)) {
        return LessonReadinessResult.invalid(
          identity.preparedKey,
          'cached lesson text incomplete',
        );
      }
      final localeStatus = validateLessonLocaleContract(
        actual: cached.localeContract,
        params: params,
      );
      if (localeStatus == LessonLocaleValidationStatus.legacyLocale) {
        return LessonReadinessResult.legacyLocale(
          lessonKeyFor(params),
          'cached lesson locale metadata missing',
        );
      }
      if (localeStatus == LessonLocaleValidationStatus.staleLocale) {
        return LessonReadinessResult.staleLocale(
          lessonKeyFor(params),
          'cached lesson locale incompatible',
        );
      }
      return LessonReadinessResult.readyFromMemoryCache(cached);
    }
    return const LessonReadinessResult.missing();
  }

  LessonReadinessResult resolveFromMemoryCache({
    required LessonOrchestrator orchestrator,
    required CompleteLessonParams params,
  }) {
    final cached = orchestrator.peekCachedLesson(lessonKeyFor(params));
    if (cached != null) {
      if (!_hasReadyText(cached)) {
        return LessonReadinessResult.invalid(
          preparedLessonMaterialKey(
            params.itemIdx ?? -1,
            params.marker,
            params.layer,
          ),
          'cached lesson text incomplete',
        );
      }
      final localeStatus = validateLessonLocaleContract(
        actual: cached.localeContract,
        params: params,
      );
      if (localeStatus == LessonLocaleValidationStatus.legacyLocale) {
        return LessonReadinessResult.legacyLocale(
          preparedLessonMaterialKey(
            params.itemIdx ?? -1,
            params.marker,
            params.layer,
          ),
          'cached lesson locale metadata missing',
        );
      }
      if (localeStatus == LessonLocaleValidationStatus.staleLocale) {
        return LessonReadinessResult.staleLocale(
          preparedLessonMaterialKey(
            params.itemIdx ?? -1,
            params.marker,
            params.layer,
          ),
          'cached lesson locale incompatible',
        );
      }
      return LessonReadinessResult.readyFromMemoryCache(cached);
    }
    return const LessonReadinessResult.missing();
  }

  LessonReadinessResult resolveFromState({
    required StudentLearningState? state,
    required LessonReadinessIdentity identity,
    required CompleteLessonParams params,
  }) {
    final key = identity.preparedKey;
    final material = state?.readyLessonMaterials[key];
    if (material == null) return const LessonReadinessResult.missing();
    if (material['text_status'] != 'ready') {
      return LessonReadinessResult.stale(key);
    }
    if (material['for_itemIdx'] != identity.itemIdx ||
        material['for_layer'] != identity.layer.name ||
        (material['for_marker'] as String?) != identity.marker) {
      return LessonReadinessResult.stale(key);
    }
    final localeContract = lessonLocaleContractFromMaterial(material);
    final localeStatus = validateLessonLocaleContract(
      actual: localeContract,
      params: params,
    );
    if (localeStatus == LessonLocaleValidationStatus.legacyLocale) {
      return LessonReadinessResult.legacyLocale(
        key,
        'state lesson locale metadata missing',
      );
    }
    if (localeStatus == LessonLocaleValidationStatus.staleLocale) {
      return LessonReadinessResult.staleLocale(
        key,
        'state lesson locale incompatible',
      );
    }
    try {
      final content = validatedLessonContentFromJson(JsonMap.from(material));
      return LessonReadinessResult.readyFromState(
        CompleteLesson(
          conteudo: content,
          imagem: _stringOrNull(material['imagem']),
          audioText: content.audioText,
          imageMetadata: LessonImageGenerationMetadata.fromJson(
            material['imageMetadata'],
          ),
          localeContract: localeContract,
        ),
      );
    } on LessonContentValidationException catch (error) {
      return LessonReadinessResult.invalid(key, error.message);
    }
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString();
    return text == null || text.trim().isEmpty ? null : text;
  }

  static bool _hasReadyText(CompleteLesson lesson) {
    final content = lesson.conteudo;
    return content.explanation.trim().isNotEmpty &&
        content.question.trim().isNotEmpty &&
        (content.options[AnswerLetter.A] ?? '').trim().isNotEmpty &&
        (content.options[AnswerLetter.B] ?? '').trim().isNotEmpty &&
        (content.options[AnswerLetter.C] ?? '').trim().isNotEmpty;
  }
}
