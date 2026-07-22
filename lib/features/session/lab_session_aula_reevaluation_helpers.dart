part of 'lab_session.dart';

bool _isAulaStateReevaluationEcho(String type) {
  return type == 'INSTANT_EXPERIENCE_MEASURED' ||
      type == 'LOCAL_PENDING_ADVANCE_DISPLAYED' ||
      type == 'INSTANT_ADVANCE_RECOVERED';
}
