class VisualFunnelEvent {
  const VisualFunnelEvent({
    required this.lessonKey,
    required this.outcome,
    required this.source,
    this.n2Reason,
    this.detail,
  });

  final String lessonKey;
  final String outcome;
  final String source;
  final String? n2Reason;
  final String? detail;
}

class VisualFunnelSnapshot {
  const VisualFunnelSnapshot({
    required this.total,
    required this.software,
    required this.paidOffer,
    required this.paidReady,
    required this.noImage,
    required this.failed,
  });

  final int total;
  final int software;
  final int paidOffer;
  final int paidReady;
  final int noImage;
  final int failed;

  double get softwareRate => total == 0 ? 0 : software / total;
}

class VisualFunnelTelemetry {
  VisualFunnelTelemetry({this.maxEvents = 80});

  final int maxEvents;
  final List<VisualFunnelEvent> _events = [];

  List<VisualFunnelEvent> get events => List.unmodifiable(_events);

  void record(VisualFunnelEvent event) {
    _events.add(event);
    if (_events.length > maxEvents) {
      _events.removeRange(0, _events.length - maxEvents);
    }
  }

  VisualFunnelSnapshot snapshot() {
    var software = 0;
    var paidOffer = 0;
    var paidReady = 0;
    var noImage = 0;
    var failed = 0;
    for (final event in _events) {
      switch (event.outcome) {
        case 'software':
          software += 1;
        case 'paid_offer':
          paidOffer += 1;
        case 'paid_ready':
          paidReady += 1;
        case 'no_image':
          noImage += 1;
        case 'failed':
          failed += 1;
      }
    }
    return VisualFunnelSnapshot(
      total: _events.length,
      software: software,
      paidOffer: paidOffer,
      paidReady: paidReady,
      noImage: noImage,
      failed: failed,
    );
  }
}
