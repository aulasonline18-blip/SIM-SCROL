import 'dart:async';

import '../external_ai/sim_ai_server_config.dart';
import '../utils/secure_logger.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';

typedef ReadyWindowWorkerProcessor =
    Future<List<bool>> Function({
      required String lessonLocalId,
      required String source,
      int? maxSlots,
      bool returnMode,
      int? itemIdx,
      LessonLayer? layer,
      String? marker,
      String? topic,
    });

const int readyWindowWorkerMaxAttempts = 3;
const int readyWindowWorkerMaxJobsPerDrain = 15;

class ReadyWindowWorker {
  ReadyWindowWorker({required this.service, required this.processor});

  final StudentLearningStateService service;
  final ReadyWindowWorkerProcessor processor;

  // F3.5: Map em vez de Set para armazenar o Future em andamento
  final Map<String, Future<List<bool>>> _inflight = {};
  final Set<String> _pendingDrain = {};
  final Map<String, Timer> _retryTimers = {};
  bool _acceptingWork = true;

  // F3.4: controle do worker auto-ativo
  String? _activeLessonLocalId;
  void Function()? _unsubscribe;

  // F3.4: inicia o worker que escuta writes e drena automaticamente
  void startReadyWindowWorker({String? activeLessonLocalId}) {
    _acceptingWork = true;
    _activeLessonLocalId = activeLessonLocalId;
    _unsubscribe?.call();
    debugLog(
      'READY_WINDOW_WORKER_STARTED activeLessonLocalId=$activeLessonLocalId',
    );
    _unsubscribe = service.subscribe((id) {
      _scheduleConditionalDrain(id);
    });
  }

  void stopReadyWindowWorker() {
    _acceptingWork = false;
    _unsubscribe?.call();
    _unsubscribe = null;
    _activeLessonLocalId = null;
    _pendingDrain.clear();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
  }

  void _scheduleConditionalDrain(String id) {
    if (!_acceptingWork) return;
    final state = service.read(id);
    if (state == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final jobs = List<JsonMap>.from(state.queuedActions);

    final hasHotLocalReady = jobs.any(
      (job) =>
          job['type'] == 'PREPARE_READY_WINDOW' &&
          job['status'] == 'queued' &&
          job['priority'] == 'hot-local' &&
          ((job['next_retry_at'] as num?)?.toInt() ?? 0) <= now,
    );

    final hasBackgroundReady = jobs.any(
      (job) =>
          job['type'] == 'PREPARE_READY_WINDOW' &&
          job['status'] == 'queued' &&
          job['priority'] == 'background' &&
          ((job['next_retry_at'] as num?)?.toInt() ?? 0) <= now,
    );

    if (hasHotLocalReady ||
        (hasBackgroundReady && id == _activeLessonLocalId)) {
      drainReadyWindowJobs(id);
    } else {
      final nextJob = jobs
          .where(
            (job) =>
                job['type'] == 'PREPARE_READY_WINDOW' &&
                job['status'] == 'queued',
          )
          .firstOrNull;
      if (nextJob != null) {
        final retryAt = (nextJob['next_retry_at'] as num?)?.toInt() ?? now;
        final delay = retryAt - now;
        if (delay > 0) {
          _scheduleDrain(id, Duration(milliseconds: delay));
        }
      }
    }
  }

  // F3.5: retorna Future existente se drain em andamento; marca pendingDrain
  Future<List<bool>> drainReadyWindowJobs(String lessonLocalId) {
    if (!_acceptingWork) return Future.value(const <bool>[]);
    final existing = _inflight[lessonLocalId];
    if (existing != null) {
      _pendingDrain.add(lessonLocalId);
      return existing;
    }
    final future = _dodrainReadyWindowJobs(lessonLocalId);
    _inflight[lessonLocalId] = future;
    return future.whenComplete(() {
      _inflight.remove(lessonLocalId);
      // F3.5: re-dispara se houve write durante o drain
      if (_acceptingWork && _pendingDrain.remove(lessonLocalId)) {
        drainReadyWindowJobs(lessonLocalId);
      }
    });
  }

  Future<List<bool>> _dodrainReadyWindowJobs(String lessonLocalId) async {
    final all = <bool>[];
    for (
      var processedJobs = 0;
      processedJobs < readyWindowWorkerMaxJobsPerDrain && _acceptingWork;
      processedJobs += 1
    ) {
      final state = service.read(lessonLocalId);
      final jobs = List<JsonMap>.from(state?.queuedActions ?? const []);
      final job = _eligibleJob(jobs);
      if (state == null || job == null) break;
      final jobId = job['job_id'];
      service.mutate(lessonLocalId, (current) {
        return current.copyWith(
          queuedActions: current.queuedActions.map((cur) {
            if (cur['job_id'] != jobId) return cur;
            return {
              ...cur,
              'status': 'running',
              'started_at': DateTime.now().millisecondsSinceEpoch,
              'error': null,
            };
          }).toList(),
        );
      });

      try {
        final payload = JsonMap.from(job['payload'] as Map? ?? const {});
        final result = await processor(
          lessonLocalId: lessonLocalId,
          source: 'job:${job['source']}',
          maxSlots: payload['maxSlots'] as int?,
          returnMode: payload['returnMode'] == true,
          itemIdx: (payload['itemIdx'] as num?)?.toInt(),
          layer: LessonLayerValue.fromValue(payload['layer']),
          marker: payload['marker'] as String?,
          topic: payload['topic'] as String?,
        );
        all.addAll(result);
        service.mutate(lessonLocalId, (current) {
          return current.copyWith(
            queuedActions: current.queuedActions.map((cur) {
              if (cur['job_id'] != jobId) return cur;
              return {
                ...cur,
                'status': 'done',
                'finished_at': DateTime.now().millisecondsSinceEpoch,
                'error': null,
              };
            }).toList(),
          );
        });
      } catch (error) {
        final attempts = (job['attempts'] as num?)?.toInt() ?? 0;
        final newAttempts = attempts + 1;
        final maxAttempts =
            (job['max_attempts'] as num?)?.toInt() ??
            readyWindowWorkerMaxAttempts;
        final retryable =
            error is SimExternalAiException && error.retryable == true;
        final shouldRetry =
            _acceptingWork && retryable && newAttempts < maxAttempts;
        final now = DateTime.now().millisecondsSinceEpoch;
        final retryDelayMs = shouldRetry
            ? _retryDelayMs(newAttempts, error)
            : 0;
        final retryAt = shouldRetry ? now + retryDelayMs : null;
        service.mutate(lessonLocalId, (current) {
          return current.copyWith(
            queuedActions: current.queuedActions.map((cur) {
              if (cur['job_id'] != jobId) return cur;
              return {
                ...cur,
                'status': shouldRetry ? 'queued' : 'failed',
                'finished_at': shouldRetry ? null : now,
                'attempts': newAttempts,
                'max_attempts': maxAttempts,
                'next_retry_at': retryAt,
                'error_code': error is SimExternalAiException
                    ? error.code ?? 'READY_WINDOW_JOB_RETRYABLE'
                    : 'READY_WINDOW_JOB_FAILED',
              };
            }).toList(),
          );
        });
        service.appendEvent(
          lessonLocalId,
          StudentLearningEvent(
            type: shouldRetry
                ? 'READY_WINDOW_JOB_RETRY_SCHEDULED'
                : 'READY_WINDOW_JOB_FAILED_PERMANENTLY',
            ts: now,
            payload: {
              'job_id': jobId,
              'attempt': newAttempts,
              'max_attempts': maxAttempts,
              'retry_at': retryAt,
              if (shouldRetry) 'delay_ms': retryDelayMs,
            },
          ),
        );
        if (shouldRetry) {
          _scheduleDrain(lessonLocalId, Duration(milliseconds: retryDelayMs));
        }
      }
    }
    return all;
  }

  void _scheduleDrain(String lessonLocalId, Duration delay) {
    if (!_acceptingWork) return;
    _retryTimers.remove(lessonLocalId)?.cancel();
    _retryTimers[lessonLocalId] = Timer(delay, () {
      _retryTimers.remove(lessonLocalId);
      if (!_acceptingWork) return;
      drainReadyWindowJobs(lessonLocalId);
    });
  }

  JsonMap? _eligibleJob(List<JsonMap> jobs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final queued = jobs
        .where(
          (job) =>
              job['type'] == 'PREPARE_READY_WINDOW' &&
              job['status'] == 'queued' &&
              ((job['next_retry_at'] as num?)?.toInt() ?? 0) <= now,
        )
        .toList();
    queued.sort((a, b) {
      final ap = a['priority'] == 'hot-local' ? 0 : 1;
      final bp = b['priority'] == 'hot-local' ? 0 : 1;
      if (ap != bp) return ap.compareTo(bp);
      return ((a['created_at'] as num?)?.toInt() ?? 0).compareTo(
        (b['created_at'] as num?)?.toInt() ?? 0,
      );
    });
    return queued.isEmpty ? null : queued.first;
  }

  static int _retryDelayMs(int attempt, Object error) {
    if (error is SimExternalAiException && error.retryAfter != null) {
      return error.retryAfter!.inMilliseconds.clamp(1000, 300000);
    }
    const delays = [2000, 5000, 15000, 60000, 300000];
    return delays[(attempt - 1).clamp(0, delays.length - 1)];
  }

  static void debugLog(String msg) {
    SecureLogger.log('ReadyWindowWorker', msg);
  }
}
