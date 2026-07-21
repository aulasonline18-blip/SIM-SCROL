import 'dart:async';

import '../external_ai/sim_ai_server_config.dart';
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

class ReadyWindowWorker {
  ReadyWindowWorker({required this.service, required this.processor});

  final StudentLearningStateService service;
  final ReadyWindowWorkerProcessor processor;

  // F3.5: Map em vez de Set para armazenar o Future em andamento
  final Map<String, Future<List<bool>>> _inflight = {};
  final Set<String> _pendingDrain = {};

  // F3.4: controle do worker auto-ativo
  String? _activeLessonLocalId;
  void Function()? _unsubscribe;

  // F3.4: inicia o worker que escuta writes e drena automaticamente
  void startReadyWindowWorker({String? activeLessonLocalId}) {
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
    _unsubscribe?.call();
    _unsubscribe = null;
  }

  void _scheduleConditionalDrain(String id) {
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
          Timer(Duration(milliseconds: delay), () {
            drainReadyWindowJobs(id);
          });
        }
      }
    }
  }

  // F3.5: retorna Future existente se drain em andamento; marca pendingDrain
  Future<List<bool>> drainReadyWindowJobs(String lessonLocalId) {
    final existing = _inflight[lessonLocalId];
    if (existing != null) {
      if (_hasQueuedHotLocalReadyWindow(lessonLocalId)) {
        return _dodrainReadyWindowJobs(lessonLocalId);
      }
      _pendingDrain.add(lessonLocalId);
      return existing;
    }
    final future = _dodrainReadyWindowJobs(lessonLocalId);
    _inflight[lessonLocalId] = future;
    return future.whenComplete(() {
      _inflight.remove(lessonLocalId);
      // F3.5: re-dispara se houve write durante o drain
      if (_pendingDrain.remove(lessonLocalId)) {
        drainReadyWindowJobs(lessonLocalId);
      }
    });
  }

  bool _hasQueuedHotLocalReadyWindow(String lessonLocalId) {
    final state = service.read(lessonLocalId);
    if (state == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    return state.queuedActions.any(
      (job) =>
          job['type'] == 'PREPARE_READY_WINDOW' &&
          job['status'] == 'queued' &&
          job['priority'] == 'hot-local' &&
          ((job['next_retry_at'] as num?)?.toInt() ?? 0) <= now,
    );
  }

  Future<List<bool>> _dodrainReadyWindowJobs(String lessonLocalId) async {
    final all = <bool>[];
    while (true) {
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
        final now = DateTime.now().millisecondsSinceEpoch;
        final retryDelayMs = _retryDelayMs(newAttempts, error);
        final retryAt = now + retryDelayMs;
        service.mutate(lessonLocalId, (current) {
          return current.copyWith(
            queuedActions: current.queuedActions.map((cur) {
              if (cur['job_id'] != jobId) return cur;
              return {
                ...cur,
                'status': 'queued',
                'finished_at': null,
                'attempts': newAttempts,
                'max_attempts': null,
                'next_retry_at': retryAt,
                'error_code': error is SimExternalAiException
                    ? error.code ?? 'READY_WINDOW_JOB_RETRYABLE'
                    : 'READY_WINDOW_JOB_RETRYABLE',
              };
            }).toList(),
          );
        });
        service.appendEvent(
          lessonLocalId,
          StudentLearningEvent(
            type: 'READY_WINDOW_JOB_RETRY_SCHEDULED',
            ts: now,
            payload: {
              'job_id': jobId,
              'attempt': newAttempts,
              'retry_at': retryAt,
              'delay_ms': retryDelayMs,
            },
          ),
        );
        Timer(Duration(milliseconds: retryDelayMs), () {
          drainReadyWindowJobs(lessonLocalId);
        });
      }
    }
    return all;
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
    // ignore: avoid_print
    print('[ReadyWindowWorker] $msg');
  }
}
