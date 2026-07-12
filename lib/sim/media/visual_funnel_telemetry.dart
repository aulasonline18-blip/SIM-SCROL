class VisualFunnelEvent {
  const VisualFunnelEvent({
    required this.lessonKey,
    required this.outcome,
    required this.source,
    this.n2Reason,
    this.detail,
    String? ts,
  }) : ts = ts ?? '';

  final String lessonKey;
  final String outcome;
  final String source;
  final String? n2Reason;
  final String? detail;
  final String ts;

  Map<String, Object?> toJson() => {
    'lessonKey': lessonKey,
    'outcome': outcome,
    'source': source,
    'n2Reason': n2Reason,
    'detail': detail,
    'ts': ts,
  };
}

class VisualFunnelSnapshot {
  const VisualFunnelSnapshot({required this.events});

  final List<VisualFunnelEvent> events;

  Map<String, Object?> toJson() => {
    'events': events.map((event) => event.toJson()).toList(),
  };
}

class VisualFunnelTelemetry {
  VisualFunnelTelemetry({this.maxEvents = 200});

  final int maxEvents;
  final List<VisualFunnelEvent> _events = [];

  void record(VisualFunnelEvent event) {
    final enriched = VisualFunnelEvent(
      lessonKey: event.lessonKey,
      outcome: event.outcome,
      source: event.source,
      n2Reason: event.n2Reason,
      detail: event.detail,
      ts: event.ts.isEmpty ? DateTime.now().toIso8601String() : event.ts,
    );
    _events.add(enriched);
    if (_events.length > maxEvents) {
      _events.removeRange(0, _events.length - maxEvents);
    }
  }

  VisualFunnelSnapshot snapshot() =>
      VisualFunnelSnapshot(events: List.unmodifiable(_events));
}
