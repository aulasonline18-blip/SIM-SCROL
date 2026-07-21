part of '../student_learning_state.dart';

class StudentLearningEvent {
  const StudentLearningEvent({
    required this.type,
    required this.ts,
    required this.payload,
  });

  final String type;
  final int ts;
  final JsonMap payload;

  JsonMap toJson() => {'type': type, 'ts': ts, 'payload': payload};
}

typedef StudentEvent = StudentLearningEvent;

class StudentEventLog {
  const StudentEventLog({required this.events, this.maxEvents = 500});

  final List<StudentLearningEvent> events;
  final int maxEvents;

  StudentEventLog add(StudentLearningEvent event) {
    final next = [...events, event];
    if (next.length > maxEvents) {
      next.removeRange(0, next.length - maxEvents);
    }
    return StudentEventLog(events: next, maxEvents: maxEvents);
  }

  List<StudentLearningEvent> getRecent(int count) {
    final start = events.length - count;
    return events.sublist(start > 0 ? start : 0);
  }

  JsonMap toJson() => {
    'events': events.map((event) => event.toJson()).toList(),
    'maxEvents': maxEvents,
  };

  factory StudentEventLog.fromJson(JsonMap json) {
    return StudentEventLog(
      events: (json['events'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (event) => StudentLearningEvent(
              type: (event['type'] ?? '').toString(),
              ts: (event['ts'] as num?)?.toInt() ?? 0,
              payload: event['payload'] is Map
                  ? JsonMap.from(event['payload'] as Map)
                  : const {},
            ),
          )
          .toList(),
      maxEvents: (json['maxEvents'] as num?)?.toInt() ?? 500,
    );
  }
}
