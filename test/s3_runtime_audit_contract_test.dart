import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remote sync unavailable marks pending test', () {
    final session = _read('lib/features/session/lab_session.dart');

    expect(session, contains('REMOTE_SYNC_UNAVAILABLE'));
    expect(session, contains('REMOTE_IDENTITY_MISSING'));
    expect(session, contains('REMOTE_HYDRATION_FAILED'));
    expect(session, contains("'code': 'remote_hydration_failed'"));
  });

  test('drawer cloud reconcile failure is audited test', () {
    final flows = _read('lib/features/session/lab_session_flows.dart');

    expect(flows, contains('DRAWER_CLOUD_RECONCILE_FAILED'));
    expect(flows, contains('REMOTE_IDENTITY_MISSING'));
  });

  test('remote hydration failure is sanitized test', () {
    final session = _read('lib/features/session/lab_session.dart');

    expect(session, contains("'code': 'remote_hydration_failed'"));
    expect(session, isNot(contains("'message': error.toString()")));
  });

  test('runtime select without position is reconciled before action test', () {
    final runtime = _read('lib/sim/classroom/lesson_runtime_engine.dart');
    final flows = _read('lib/features/session/lab_session_flows.dart');

    expect(runtime, contains('bool select(AnswerLetter letter)'));
    expect(runtime, contains('if (position == null) return false;'));
    expect(flows, contains('hasLivePositionForSnapshot'));
    expect(flows, contains('ANSWER_BLOCKED_RUNTIME_NOT_READY'));
    expect(flows, contains('_PendingLocalAnswer'));
    expect(flows, contains('_reconcileAnswerInBackground'));
    expect(flows, isNot(contains('LabSession.chooseAulaAnswer.position')));
    expect(flows, isNot(contains('LabSession.chooseAulaAnswer.select_false')));
    expect(flows, isNot(contains('ANSWER_REJECTED_NO_POSITION')));
  });

  test('chat merge is debounced and image fingerprints are light test', () {
    final screen = _read('lib/features/classroom/chat_aula_screen.dart');

    final mergeStart = screen.indexOf(
      'List<ChatLessonMessage> _mergeConversationMessages',
    );
    final mergeEnd = screen.indexOf(
      'List<ChatLessonMessage> _restoredMessagesAsProjection',
    );
    final merge = screen.substring(mergeStart, mergeEnd);

    expect(screen, contains('_schedulePersistConversationSnapshot'));
    expect(merge, isNot(contains('unawaited(_persistConversationSnapshot')));
    expect(screen, contains('_imageFingerprint(message.imageData)'));
    expect(screen, isNot(contains('message.imageData ??')));
  });

  test('answer history does not store inline images test', () {
    final controller = _read(
      'lib/sim/classroom/lesson_answer_progress_controller.dart',
    );
    final timeline = _read(
      'lib/features/classroom/chat_aula_timeline_builder.dart',
    );

    expect(controller, isNot(contains('imageUrl: position.imagem')));
    expect(controller, contains('imageUrl: null'));
    expect(timeline, isNot(contains('imageData: entry.imageUrl')));
  });

  test('invalid decision signal is rejected test', () {
    final flows = _read('lib/features/session/lab_session_flows.dart');

    expect(flows, contains('SIGNAL_REJECTED_INVALID_VALUE'));
    expect(flows, isNot(contains('_ => DecisionSignal.one')));
  });

  test('manual advance priority over auto pending test', () {
    final flows = _read('lib/features/session/lab_session_flows.dart');
    final drain = flows.substring(
      flows.indexOf('void _drainPendingAulaIntents'),
      flows.indexOf('void setDeleteConfirmation'),
    );
    final manualIndex = drain.indexOf('if (_pendingManualAdvance)');
    final autoIndex = drain.indexOf('if (_pendingAutoAdvanceAfterFeedback)');

    expect(manualIndex, greaterThanOrEqualTo(0));
    expect(autoIndex, greaterThanOrEqualTo(0));
    expect(manualIndex, lessThan(autoIndex));
    expect(flows, contains('MANUAL_ADVANCE_PRIORITY_OVER_AUTO_PENDING'));
  });

  test('auto advance retries after loading finishes test', () {
    final flows = _read('lib/features/session/lab_session_flows.dart');

    expect(flows, contains('AUTO_ADVANCE_DEFERRED_BY_LOADING'));
    expect(flows, contains('_drainPendingAulaIntents(active)'));
  });

  test('advance error is classified and retryable test', () {
    final flows = _read('lib/features/session/lab_session_flows.dart');

    expect(flows, contains('ADVANCE_ERROR_CLASSIFIED'));
    expect(flows, contains("'retryable': true"));
    expect(flows, contains('humanErrorMessage(error)'));
  });

  test('background resolved stale generation is audited test', () {
    final flows = _read('lib/features/session/lab_session_flows.dart');

    expect(flows, contains('BACKGROUND_RESOLVED_STALE_GENERATION_IGNORED'));
    expect(flows, contains("'reason': 'generation_or_lesson_mismatch'"));
  });

  test('media update key mismatch records event test', () {
    final flows = _read('lib/features/session/lab_session_flows.dart');

    expect(flows, contains('MEDIA_UPDATE_KEY_MISMATCH'));
  });

  test('advance reevaluation preserves latest identity test', () {
    final session = _read('lib/features/session/lab_session.dart');
    final flows = _read('lib/features/session/lab_session_flows.dart');

    expect(session, contains('_advancePendingReevaluationLessonId'));
    expect(session, contains('_advancePendingReevaluationGeneration'));
    expect(session, contains('_advancePendingReevaluationReason'));
    expect(flows, contains('ADVANCE_REEVALUATION_COALESCED'));
  });

  test('lesson text ready with material change rebuilds ui test', () {
    final flows = _read('lib/features/session/lab_session_flows.dart');

    expect(flows, isNot(contains("type == 'LESSON_TEXT_READY' ||")));
    expect(flows, contains('_notifyFromChild()'));
  });

  test('next part retry timeout sets error test', () {
    final flows = _read('lib/features/session/lab_session_flows.dart');

    expect(flows, contains('NEXT_PART_RETRY_TIMEOUT'));
    expect(flows, contains('aulaRuntimeError'));
  });

  test('launch retry records new intent after inflight test', () {
    final entry = _read('lib/features/session/lab_session_entry_flows.dart');

    expect(entry, contains('_launchExperienceInFlight'));
    expect(entry, contains('await inFlight'));
  });

  test('loading does not clear visible content before replacement test', () {
    final flows = _read('lib/features/session/lab_session_flows.dart');

    expect(flows, contains('previousSnapshot: aulaSnapshot'));
    expect(flows, contains('aulaOpeningTransition'));
  });

  test('placement prefetch failure records event test', () {
    final warmup = _read('lib/features/session/lab_session_warmup_flows.dart');

    expect(warmup, contains('PLACEMENT_PREFETCH_FAILURE'));
  });

  test('aux prefetch failure records event test', () {
    final aux = _read('lib/features/session/lab_session_aux_flows.dart');

    expect(aux, contains('AUX_PREFETCH_FAILURE'));
  });

  test('amparo route failure returns to previous state test', () {
    final amparo = _read('lib/features/session/lab_session_amparo_flows.dart');

    expect(amparo, contains('AMPARO_ROUTE_FAILURE'));
    expect(amparo, contains('Sua aula foi preservada.'));
  });
}

String _read(String path) => File(path).readAsStringSync();
