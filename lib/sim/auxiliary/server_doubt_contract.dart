import '../state/student_learning_state.dart';

String _text(Object? value) => (value ?? '').toString().trim();

int _int(Object? value, [int fallback = 0]) {
  final parsed = value is num ? value.toInt() : int.tryParse(_text(value));
  return parsed ?? fallback;
}

JsonMap _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : {};

List<JsonMap> _listOfMaps(Object? value) => value is List
    ? value.whereType<Map>().map((entry) => _map(entry)).toList()
    : const [];

class ServerDoubtContext {
  const ServerDoubtContext({
    required this.lessonLocalId,
    required this.marker,
    required this.itemIdx,
    required this.layer,
    required this.currentQuestion,
    required this.currentOptions,
    required this.studentQuestion,
    required this.idempotencyKey,
    this.userId,
    this.sessionId,
    this.selectedOption,
    this.signal,
    this.currentFeedback = const {},
    this.attachment,
    this.language,
    this.interfaceLocale,
    this.learningLocale,
    this.explanationLanguage,
    this.currentState = const {},
    this.history = const [],
  });

  final String lessonLocalId;
  final String? userId;
  final String? sessionId;
  final String marker;
  final int itemIdx;
  final int layer;
  final String currentQuestion;
  final Map<String, String> currentOptions;
  final String? selectedOption;
  final int? signal;
  final JsonMap currentFeedback;
  final String studentQuestion;
  final JsonMap? attachment;
  final String? language;
  final String? interfaceLocale;
  final String? learningLocale;
  final String? explanationLanguage;
  final String idempotencyKey;
  final JsonMap currentState;
  final List<JsonMap> history;

  JsonMap toJson() => {
    'lessonLocalId': lessonLocalId,
    if (userId != null) 'userId': userId,
    if (sessionId != null) 'sessionId': sessionId,
    'marker': marker,
    'itemIdx': itemIdx,
    'layer': layer,
    'currentQuestion': currentQuestion,
    'currentOptions': currentOptions,
    if (selectedOption != null) 'selectedOption': selectedOption,
    if (signal != null) 'signal': signal,
    'currentFeedback': currentFeedback,
    'studentQuestion': studentQuestion,
    if (attachment != null) 'attachment': attachment,
    if (language != null) 'language': language,
    if (interfaceLocale != null) 'interfaceLocale': interfaceLocale,
    if (learningLocale != null) 'learningLocale': learningLocale,
    if (explanationLanguage != null) 'explanationLanguage': explanationLanguage,
    'idempotencyKey': idempotencyKey,
    'currentState': currentState,
    'history': history,
  };
}

class ServerDoubtResponse {
  const ServerDoubtResponse({
    required this.ok,
    required this.status,
    required this.duplicate,
    required this.doubtId,
    required this.lessonLocalId,
    required this.marker,
    required this.itemIdx,
    required this.layer,
    required this.answerText,
    required this.followUpAllowed,
    required this.source,
    required this.createdAt,
    required this.stateMutation,
    required this.mainProgressPreserved,
    required this.events,
    this.contractVersion = 'sim.auxiliary.doubt.v1',
    this.flow = 'doubt',
    this.nextAction = 'return_to_lesson',
    this.reason = '',
    this.humanError,
  });

  final bool ok;
  final String status;
  final bool duplicate;
  final String doubtId;
  final String lessonLocalId;
  final String marker;
  final int itemIdx;
  final int layer;
  final String answerText;
  final bool followUpAllowed;
  final String source;
  final String createdAt;
  final JsonMap stateMutation;
  final bool mainProgressPreserved;
  final List<JsonMap> events;
  final String contractVersion;
  final String flow;
  final String nextAction;
  final String reason;
  final JsonMap? humanError;

  bool get progressPreserved =>
      mainProgressPreserved &&
      stateMutation['progressChanged'] != true &&
      stateMutation['itemAdvanced'] != true &&
      stateMutation['layerChanged'] != true &&
      stateMutation['answerErased'] != true;

  bool get domainPreserved =>
      stateMutation['domainChanged'] != true &&
      stateMutation['masteryChanged'] != true &&
      stateMutation['weaknessChanged'] != true &&
      stateMutation['conquestChanged'] != true &&
      stateMutation['truthChanged'] != true;

  factory ServerDoubtResponse.fromJson(JsonMap json) => ServerDoubtResponse(
    ok: json['ok'] == true,
    status: _text(json['status']),
    duplicate: json['duplicate'] == true,
    doubtId: _text(json['doubtId']),
    lessonLocalId: _text(json['lessonLocalId']),
    marker: _text(json['marker']),
    itemIdx: _int(json['itemIdx']),
    layer: _int(json['layer'], 1),
    answerText: _text(json['answerText'] ?? json['answer']),
    followUpAllowed: json['followUpAllowed'] != false,
    source: _text(json['source']),
    createdAt: _text(json['createdAt']),
    stateMutation: _map(json['stateMutation']),
    mainProgressPreserved: json['mainProgressPreserved'] != false,
    events: _listOfMaps(json['events']),
    contractVersion: _text(json['contractVersion']).isEmpty
        ? 'sim.auxiliary.doubt.v1'
        : _text(json['contractVersion']),
    flow: _text(json['flow']).isEmpty ? 'doubt' : _text(json['flow']),
    nextAction: _text(json['nextAction']).isEmpty
        ? 'return_to_lesson'
        : _text(json['nextAction']),
    reason: _text(json['reason']),
    humanError: json['humanError'] is Map ? _map(json['humanError']) : null,
  );
}

abstract class ServerDoubtTransport {
  Future<JsonMap> postDoubt(JsonMap body);
}

class ServerDoubtClient {
  const ServerDoubtClient(this.transport);

  final ServerDoubtTransport transport;

  Future<ServerDoubtResponse> ask(ServerDoubtContext context) async {
    final json = await transport.postDoubt(context.toJson());
    return ServerDoubtResponse.fromJson(json);
  }
}
