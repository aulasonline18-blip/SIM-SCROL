import '../lesson/lesson_models.dart';
import '../state/student_learning_state.dart';

enum AuxRoomMode { review, recovery, doubt, amparo }

enum ReviewRoomStatus {
  choose,
  preparing,
  ready,
  answering,
  result,
  done,
  failed,
}

enum RecoveryRoomStatus {
  intro,
  ready,
  answering,
  result,
  preparing,
  done,
  failed,
}

enum AmparoRoomStatus { preparing, ready, answering, result, done, failed }

enum DoubtStatus { idle, processing, explaining, error }

class AuxRoomProfile {
  const AuxRoomProfile({
    this.stableLang,
    this.academicLevel,
    this.preferredName,
    this.notes,
    this.extra = const {},
  });

  final String? stableLang;
  final String? academicLevel;
  final String? preferredName;
  final String? notes;
  final JsonMap extra;

  JsonMap toJson() => {
    ...extra,
    if (stableLang != null) 'stableLang': stableLang,
    if (academicLevel != null) 'academicLevel': academicLevel,
    if (preferredName != null) 'preferredName': preferredName,
    if (notes != null) 'notes': notes,
  };
}

class AuxRoomItem {
  const AuxRoomItem({this.marker, this.text, this.itemIdx});

  final String? marker;
  final String? text;
  final int? itemIdx;
}

class AuxRoomContent {
  const AuxRoomContent({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.explanation = '',
  });

  final String question;
  final Map<AnswerLetter, String> options;
  final AnswerLetter correctAnswer;
  final String explanation;

  factory AuxRoomContent.fromLesson(LessonContent content) => AuxRoomContent(
    question: content.question,
    options: content.options,
    correctAnswer: content.correctAnswer,
    explanation: content.explanation,
  );
}

class ReviewRoomContext {
  const ReviewRoomContext({
    required this.lessonLocalId,
    required this.topic,
    required this.items,
    required this.fallbackStartIdx,
    required this.layer,
    required this.profile,
  });

  final String lessonLocalId;
  final String topic;
  final List<AuxRoomItem> items;
  final int fallbackStartIdx;
  final LessonLayer layer;
  final AuxRoomProfile profile;
}

class RecoveryRoomContext {
  const RecoveryRoomContext({
    required this.lessonLocalId,
    required this.topic,
    required this.items,
    required this.layer,
    required this.profile,
  });

  final String lessonLocalId;
  final String topic;
  final List<AuxRoomItem> items;
  final LessonLayer layer;
  final AuxRoomProfile profile;
}

class AmparoStation {
  const AmparoStation({
    required this.marker,
    required this.title,
    required this.purpose,
    required this.layer,
    required this.amparoType,
  });

  final String marker;
  final String title;
  final String purpose;
  final LessonLayer layer;
  final String amparoType;

  JsonMap toJson() => {
    'marker': marker,
    'title': title,
    'purpose': purpose,
    'layer': layer.value,
    'amparo_type': amparoType,
  };
}

class AmparoRoomContext {
  const AmparoRoomContext({
    required this.lessonLocalId,
    required this.topic,
    required this.items,
    required this.itemIdx,
    required this.marker,
    required this.layer,
    required this.profile,
    this.currentExplanation = '',
    this.currentQuestion = '',
    this.currentOptions = const {},
    this.selectedAnswer,
    this.correctAnswer,
    this.signal,
  });

  final String lessonLocalId;
  final String topic;
  final List<AuxRoomItem> items;
  final int itemIdx;
  final String? marker;
  final LessonLayer layer;
  final AuxRoomProfile profile;
  final String currentExplanation;
  final String currentQuestion;
  final Map<AnswerLetter, String> currentOptions;
  final AnswerLetter? selectedAnswer;
  final AnswerLetter? correctAnswer;
  final DecisionSignal? signal;
}

class ReviewRoomView {
  const ReviewRoomView({
    required this.status,
    required this.count,
    required this.queue,
    required this.idx,
    this.conteudo,
    this.letra,
    this.sinal,
    this.resultCorrect,
    this.resultMsg,
    this.errMsg,
    this.serverReviewId,
    this.serverMarker,
  });

  final ReviewRoomStatus status;
  final int count;
  final List<String> queue;
  final int idx;
  final AuxRoomContent? conteudo;
  final AnswerLetter? letra;
  final DecisionSignal? sinal;
  final bool? resultCorrect;
  final String? resultMsg;
  final String? errMsg;
  final String? serverReviewId;
  final String? serverMarker;

  ReviewRoomView copyWith({
    ReviewRoomStatus? status,
    int? count,
    List<String>? queue,
    int? idx,
    AuxRoomContent? conteudo,
    AnswerLetter? letra,
    DecisionSignal? sinal,
    bool? resultCorrect,
    String? resultMsg,
    String? errMsg,
    String? serverReviewId,
    String? serverMarker,
  }) {
    return ReviewRoomView(
      status: status ?? this.status,
      count: count ?? this.count,
      queue: queue ?? this.queue,
      idx: idx ?? this.idx,
      conteudo: conteudo ?? this.conteudo,
      letra: letra ?? this.letra,
      sinal: sinal ?? this.sinal,
      resultCorrect: resultCorrect ?? this.resultCorrect,
      resultMsg: resultMsg ?? this.resultMsg,
      errMsg: errMsg ?? this.errMsg,
      serverReviewId: serverReviewId ?? this.serverReviewId,
      serverMarker: serverMarker ?? this.serverMarker,
    );
  }
}

class RecoveryRoomView {
  const RecoveryRoomView({
    required this.status,
    required this.queue,
    required this.idx,
    this.conteudo,
    this.letra,
    this.sinal,
    this.resultCorrect,
    this.resultMsg,
    this.errMsg,
    this.restartRequired = false,
    this.serverRecoveryId,
    this.serverMarker,
  });

  final RecoveryRoomStatus status;
  final List<String> queue;
  final int idx;
  final AuxRoomContent? conteudo;
  final AnswerLetter? letra;
  final DecisionSignal? sinal;
  final bool? resultCorrect;
  final String? resultMsg;
  final String? errMsg;
  final bool restartRequired;
  final String? serverRecoveryId;
  final String? serverMarker;

  RecoveryRoomView copyWith({
    RecoveryRoomStatus? status,
    List<String>? queue,
    int? idx,
    AuxRoomContent? conteudo,
    AnswerLetter? letra,
    DecisionSignal? sinal,
    bool? resultCorrect,
    String? resultMsg,
    String? errMsg,
    bool? restartRequired,
    String? serverRecoveryId,
    String? serverMarker,
  }) {
    return RecoveryRoomView(
      status: status ?? this.status,
      queue: queue ?? this.queue,
      idx: idx ?? this.idx,
      conteudo: conteudo ?? this.conteudo,
      letra: letra ?? this.letra,
      sinal: sinal ?? this.sinal,
      resultCorrect: resultCorrect ?? this.resultCorrect,
      resultMsg: resultMsg ?? this.resultMsg,
      errMsg: errMsg ?? this.errMsg,
      restartRequired: restartRequired ?? this.restartRequired,
      serverRecoveryId: serverRecoveryId ?? this.serverRecoveryId,
      serverMarker: serverMarker ?? this.serverMarker,
    );
  }
}

class AmparoRoomView {
  const AmparoRoomView({
    required this.status,
    required this.stations,
    required this.idx,
    required this.amparoLvl,
    this.conteudo,
    this.letra,
    this.sinal,
    this.resultCorrect,
    this.resultMsg,
    this.errMsg,
  });

  final AmparoRoomStatus status;
  final List<AmparoStation> stations;
  final int idx;
  final int amparoLvl;
  final AuxRoomContent? conteudo;
  final AnswerLetter? letra;
  final DecisionSignal? sinal;
  final bool? resultCorrect;
  final String? resultMsg;
  final String? errMsg;

  AmparoRoomView copyWith({
    AmparoRoomStatus? status,
    List<AmparoStation>? stations,
    int? idx,
    int? amparoLvl,
    AuxRoomContent? conteudo,
    AnswerLetter? letra,
    DecisionSignal? sinal,
    bool? resultCorrect,
    String? resultMsg,
    String? errMsg,
  }) {
    return AmparoRoomView(
      status: status ?? this.status,
      stations: stations ?? this.stations,
      idx: idx ?? this.idx,
      amparoLvl: amparoLvl ?? this.amparoLvl,
      conteudo: conteudo ?? this.conteudo,
      letra: letra ?? this.letra,
      sinal: sinal ?? this.sinal,
      resultCorrect: resultCorrect ?? this.resultCorrect,
      resultMsg: resultMsg ?? this.resultMsg,
      errMsg: errMsg ?? this.errMsg,
    );
  }
}

class DoubtImagePayload {
  const DoubtImagePayload({
    required this.name,
    required this.type,
    required this.size,
    required this.dataUrl,
  });

  final String name;
  final String type;
  final int size;
  final String dataUrl;
}

class DoubtResponse {
  const DoubtResponse({
    required this.explanation,
    this.visualTrigger = const {},
  });

  final String explanation;
  final JsonMap visualTrigger;
}

class DoubtState {
  const DoubtState({
    required this.status,
    required this.progress,
    this.sheetOpen = false,
    this.error,
    this.response,
  });

  final DoubtStatus status;
  final int progress;
  final bool sheetOpen;
  final String? error;
  final DoubtResponse? response;

  static const idle = DoubtState(status: DoubtStatus.idle, progress: 0);

  DoubtState copyWith({
    DoubtStatus? status,
    int? progress,
    bool? sheetOpen,
    String? error,
    DoubtResponse? response,
  }) {
    return DoubtState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      sheetOpen: sheetOpen ?? this.sheetOpen,
      error: error,
      response: response ?? this.response,
    );
  }
}
