import '../state/student_learning_state.dart';
import 'placement_blocks.dart';

enum PlacementStatus {
  idle,
  choosing,
  requested,
  intro,
  waitingPreparation,
  running,
  scoring,
  done,
  skipped,
  failed,
}

class PlacementState {
  const PlacementState({
    required this.status,
    required this.blocks,
    required this.answers,
    required this.result,
    required this.startMarker,
    required this.startItemIdx,
    required this.index,
    required this.choice,
    required this.source,
    required this.confidence,
    required this.reason,
    required this.limited,
    required this.startedAt,
    required this.finishedAt,
    required this.updatedAt,
  });

  final PlacementStatus status;
  final List<PlacementBlock> blocks;
  final List<PlacementAnswer> answers;
  final PlacementResult? result;
  final String? startMarker;
  final int? startItemIdx;
  final int index;
  final String? choice;
  final String? source;
  final String? confidence;
  final String? reason;
  final bool limited;
  final int? startedAt;
  final int? finishedAt;
  final int? updatedAt;

  factory PlacementState.empty() => const PlacementState(
    status: PlacementStatus.idle,
    blocks: [],
    answers: [],
    result: null,
    startMarker: null,
    startItemIdx: null,
    index: 0,
    choice: null,
    source: null,
    confidence: null,
    reason: null,
    limited: false,
    startedAt: null,
    finishedAt: null,
    updatedAt: null,
  );

  PlacementState copyWith({
    PlacementStatus? status,
    List<PlacementBlock>? blocks,
    List<PlacementAnswer>? answers,
    PlacementResult? result,
    String? startMarker,
    int? startItemIdx,
    int? index,
    String? choice,
    String? source,
    String? confidence,
    String? reason,
    bool? limited,
    int? startedAt,
    int? finishedAt,
    int? updatedAt,
    bool clearResult = false,
    bool clearStartMarker = false,
    bool clearStartItemIdx = false,
  }) {
    return PlacementState(
      status: status ?? this.status,
      blocks: blocks ?? this.blocks,
      answers: answers ?? this.answers,
      result: clearResult ? null : result ?? this.result,
      startMarker: clearStartMarker ? null : startMarker ?? this.startMarker,
      startItemIdx: clearStartItemIdx
          ? null
          : startItemIdx ?? this.startItemIdx,
      index: index ?? this.index,
      choice: choice ?? this.choice,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      reason: reason ?? this.reason,
      limited: limited ?? this.limited,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  JsonMap toJson() => {
    'status': status.name,
    'blocks': blocks.map((block) => block.toJson()).toList(),
    'answers': answers.map((answer) => answer.toJson()).toList(),
    'result': result?.toJson(),
    'start_marker': startMarker,
    'start_item_idx': startItemIdx,
    'index': index,
    'choice': choice,
    'source': source,
    'confidence': confidence,
    'reason': reason,
    'limited': limited,
    'started_at': startedAt,
    'finished_at': finishedAt,
    'updated_at': updatedAt,
  };

  factory PlacementState.fromJson(JsonMap json) => PlacementState(
    status: PlacementStatus.values.firstWhere(
      (status) => status.name == json['status'],
      orElse: () => PlacementStatus.idle,
    ),
    blocks: (json['blocks'] as List? ?? const [])
        .whereType<Map>()
        .map((block) => PlacementBlock.fromJson(JsonMap.from(block)))
        .toList(),
    answers: (json['answers'] as List? ?? const [])
        .whereType<Map>()
        .map((answer) => PlacementAnswer.fromJson(JsonMap.from(answer)))
        .toList(),
    result: json['result'] is Map
        ? PlacementResult.fromJson(JsonMap.from(json['result'] as Map))
        : null,
    startMarker: json['start_marker'] as String?,
    startItemIdx: (json['start_item_idx'] as num?)?.toInt(),
    index: (json['index'] as num?)?.toInt() ?? 0,
    choice: json['choice'] as String?,
    source: json['source'] as String?,
    confidence: json['confidence'] as String?,
    reason: json['reason'] as String?,
    limited: json['limited'] == true,
    startedAt: (json['started_at'] as num?)?.toInt(),
    finishedAt: (json['finished_at'] as num?)?.toInt(),
    updatedAt: (json['updated_at'] as num?)?.toInt(),
  );
}
