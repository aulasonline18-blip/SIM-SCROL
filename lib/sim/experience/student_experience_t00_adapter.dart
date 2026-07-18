import 'dart:async';

import 'package:flutter/foundation.dart';

import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'curriculum_utils.dart';
import 'partial_curriculum_writer.dart';
import 'student_experience_store.dart';
import 'student_experience_types.dart';
import 't00_profile_writer.dart';

class StudentExperienceT00Adapter {
  StudentExperienceT00Adapter({
    required this.service,
    required this.client,
    this.onCurriculumExpanded,
  });

  final StudentLearningStateService service;
  final T00BootstrapClient client;
  final void Function({
    required String lessonLocalId,
    required String? topic,
    required int itemIdx,
    required LessonLayer layer,
    required String? marker,
    required String source,
  })?
  onCurriculumExpanded;
  final Set<String> _continuationInFlight = <String>{};

  Future<FirstCurriculumItem> startT00UntilFirstItem(
    StudentExperienceArgs args,
  ) async {
    final topic = (args.onboarding['objetivo'] ?? '').toString().trim();
    final existing = service.read(args.lessonLocalId)?.curriculum;
    if (existing != null &&
        existing.items.isNotEmpty &&
        normalizeStudyKey(existing.topic) == normalizeStudyKey(topic)) {
      final existingState = service.read(args.lessonLocalId);
      if (existingState != null) {
        _scheduleContinuationIfNeeded(
          sourceLessonLocalId: args.lessonLocalId,
          args: args,
        );
      }
      return _firstItemFrom(existing)!;
    }

    final partialItems = <CurriculumItem>[];
    final bootStartedAt = DateTime.now().millisecondsSinceEpoch;

    args.onStage?.call(StudentExperienceRouteStage.profile);
    writeStudentExperienceSnapshot(
      service,
      lessonLocalId: args.lessonLocalId,
      state: StudentExperienceState.t00Streaming,
    );
    publishStudentExperienceEvent(
      service,
      args.lessonLocalId,
      StudentExperienceEventType.objectiveSubmittedAt,
      {'at': bootStartedAt, 'topic': topic},
    );
    publishStudentExperienceEvent(
      service,
      args.lessonLocalId,
      StudentExperienceEventType.t00Started,
      {'topic': topic},
    );
    debugPrint('[SIM] T00_STARTED');

    service.mutate(args.lessonLocalId, (state) {
      return state.copyWith(
        profile: state.profile.copyWith(
          objetivo: topic,
          extra: {
            ...state.profile.extra,
            'lessonLocalId': args.lessonLocalId,
            'bootstrap_engine': 'StudentExperienceEngineV2:T00',
            'bootstrap_status': 'running',
          },
        ),
      );
    });

    // Completer liberado no primeiro item; stream T00 continua em background.
    final completer = Completer<FirstCurriculumItem>();
    unawaited(
      _drainT00Stream(
        args: args,
        topic: topic,
        bootStartedAt: bootStartedAt,
        partialItems: partialItems,
        completer: completer,
      ),
    );
    return completer.future;
  }

  Future<void> _drainT00Stream({
    required StudentExperienceArgs args,
    required String topic,
    required int bootStartedAt,
    required List<CurriculumItem> partialItems,
    required Completer<FirstCurriculumItem> completer,
  }) async {
    FirstCurriculumItem? first;
    try {
      await for (final chunk in client.runBootstrap(
        T00BootstrapRequest(
          lessonLocalId: args.lessonLocalId,
          onboarding: args.onboarding,
          lang: args.idioma,
          academic: args.academic,
          interfaceLocale: args.localeContract.interfaceLocale,
          learningLocale: args.localeContract.learningLocale,
          explanationLanguage: args.localeContract.explanationLanguage,
          targetLanguage: args.localeContract.targetLanguage,
        ),
      )) {
        switch (chunk.type) {
          case 't00_profile':
            persistT00ProfileEvent(
              service: service,
              lessonLocalId: args.lessonLocalId,
              event: T00ProfileEvent(
                profile: chunk.payload['profile'] as String?,
                fichaForNext: chunk.payload['ficha_for_next'] is Map
                    ? JsonMap.from(chunk.payload['ficha_for_next'] as Map)
                    : null,
              ),
              data: args.onboarding,
            );
            publishStudentExperienceEvent(
              service,
              args.lessonLocalId,
              StudentExperienceEventType.t00ProfilePartialReceived,
              {'hasFichaForNext': chunk.payload['ficha_for_next'] != null},
            );
            break;

          case 't00_item_partial':
          case 't01_item_partial':
            final raw = chunk.payload['item'];
            if (raw is Map) {
              final result = appendPartialCurriculumItemToState(
                service: service,
                raw: T00StreamItem.fromJson(JsonMap.from(raw)),
                partialItems: partialItems,
                lessonLocalId: args.lessonLocalId,
                objective: topic,
                bootStartedAt: bootStartedAt,
              );
              if (result != null && result.count == 1) {
                final curriculum = service.read(args.lessonLocalId)?.curriculum;
                first = curriculum == null ? null : _firstItemFrom(curriculum);
                debugPrint(
                  '[SIM] T00_FIRST_ITEM_RECEIVED marker=${result.marker}',
                );
                args.onStage?.call(StudentExperienceRouteStage.curriculum);
                writeStudentExperienceSnapshot(
                  service,
                  lessonLocalId: args.lessonLocalId,
                  state: StudentExperienceState.primeiroItemRecebido,
                  startMarker: first?.marker,
                  startItemIndex: first?.itemIndex ?? 0,
                );
                publishStudentExperienceEvent(
                  service,
                  args.lessonLocalId,
                  StudentExperienceEventType.t00FirstItemReceived,
                  {'marker': result.marker},
                );
                // Libera o fast-path; T00 continua em background.
                if (!completer.isCompleted && first != null) {
                  completer.complete(first);
                }
              } else if (result != null && result.count > 1) {
                _notifyCurriculumExpanded(
                  args.lessonLocalId,
                  topic,
                  'StudentExperienceEngineV2:t00_partial_expanded',
                );
              }
            }
            break;

          case 't00_partial_ready':
            publishStudentExperienceEvent(
              service,
              args.lessonLocalId,
              StudentExperienceEventType.t00PartialReady,
              {'count': chunk.payload['count'], 'ms': chunk.payload['ms']},
            );
            break;

          case 't00_quality_check':
            publishStudentExperienceEvent(
              service,
              args.lessonLocalId,
              StudentExperienceEventType.t00QualityCheckReceived,
              {'quality_check': chunk.payload['quality_check']},
            );
            break;

          case 't00_fallback_gateway_started':
          case 'fallback_gateway_started':
            publishStudentExperienceEvent(
              service,
              args.lessonLocalId,
              StudentExperienceEventType.t00FallbackGatewayStarted,
              {'error': _safeT00GatewayError(), 'ts': chunk.payload['ts']},
            );
            break;

          case 't00_fallback_gateway_succeeded':
          case 'fallback_gateway_succeeded':
            publishStudentExperienceEvent(
              service,
              args.lessonLocalId,
              StudentExperienceEventType.t00FallbackGatewaySucceeded,
              {'ts': chunk.payload['ts']},
            );
            break;

          case 't00_fallback_gateway_failed':
          case 'fallback_gateway_failed':
            publishStudentExperienceEvent(
              service,
              args.lessonLocalId,
              StudentExperienceEventType.t00FallbackGatewayFailed,
              {'error': _safeT00GatewayError(), 'ts': chunk.payload['ts']},
            );
            break;

          case 't00_final':
          case 't01_final':
            final rawCurriculum =
                chunk.payload['curriculo'] ?? chunk.payload['curriculum'];
            final finalItems = dedupeCurriculumBatchItems(
              normalizeCurriculumItems(rawCurriculum),
            );
            if (finalItems.isNotEmpty) {
              final globalPlan = normalizeCurriculumGlobalPlan(
                rawCurriculum: rawCurriculum,
                rawQualityCheck: chunk.payload['quality_check'],
                localItemCount: finalItems.length,
              );
              final curriculum = StudentCurriculum(
                topic: topic,
                totalItems: finalItems.length,
                generatedAt: DateTime.now().millisecondsSinceEpoch,
                provisional: false,
                items: finalItems,
                globalPlan: globalPlan,
              );
              service.mutate(args.lessonLocalId, (state) {
                var nextState = state.copyWith(
                  curriculum: curriculum,
                  curriculumStatus: StudentCurriculumStatus(
                    status: CurriculumStatusValue.expanded,
                    expansionStatus: CurriculumStatusValue.expanded,
                    updatedAt: DateTime.now().toIso8601String(),
                    objectiveKey: normalizeStudyKey(topic),
                    initialCount: partialItems.isEmpty
                        ? 1
                        : partialItems.length,
                    totalCount: curriculum.displayTotalItems,
                  ),
                  profile: state.profile.copyWith(
                    extra: {
                      ...state.profile.extra,
                      'bootstrap_status': 'complete',
                      if (globalPlan != null)
                        'curriculum_global_plan': globalPlan.toJson(),
                    },
                  ),
                  extra: {
                    ...state.extra,
                    'curriculumPlanRootLessonId':
                        state.extra['curriculumPlanRootLessonId'] ??
                        args.onboarding['rootLessonLocalId'] ??
                        args.lessonLocalId,
                    'curriculumPartNumber': globalPlan?.partNumber ?? 1,
                    if (args.onboarding['previousLessonLocalId'] != null)
                      'previousCurriculumPartLessonId':
                          args.onboarding['previousLessonLocalId'],
                  },
                );
                final request = buildCurriculumContinuationRequest(nextState);
                final nextPart = request == null
                    ? null
                    : request['partNumber'] as int?;
                if (request != null && nextPart != null) {
                  nextState = markCurriculumPartStatus(
                    state: nextState,
                    status: 'preparing',
                    nextLessonLocalId: curriculumPartLessonId(
                      curriculumPlanRootLessonId(nextState),
                      nextPart,
                    ),
                  );
                } else {
                  nextState = nextState.copyWith(
                    extra: {
                      ...nextState.extra,
                      'nextCurriculumPartStatus': 'none',
                    },
                  );
                }
                return nextState;
              });
              publishStudentExperienceEvent(
                service,
                args.lessonLocalId,
                StudentExperienceEventType.t00FinalCurriculumReceived,
                {
                  'items': finalItems.length,
                  if (globalPlan != null)
                    'curriculum_global_plan': globalPlan.toJson(),
                },
              );
              _notifyCurriculumExpanded(
                args.lessonLocalId,
                topic,
                'StudentExperienceEngineV2:t00_final_expanded',
              );
              _scheduleContinuationIfNeeded(
                sourceLessonLocalId: args.lessonLocalId,
                args: args,
              );
              first ??= _firstItemFrom(curriculum);
            }
            if (!completer.isCompleted && first != null) {
              completer.complete(first);
            }
            break;

          case 'done':
            // Sinaliza fim do stream; sem payload de currículo.
            if (!completer.isCompleted && first != null) {
              completer.complete(first);
            }
            break;

          case 'fatal':
            throw const StudentExperienceEngineException(
              StudentExperienceErrorInfo(
                kind: StudentExperienceErrorKind.generic,
                message: 'T00_PROVIDER_UNAVAILABLE',
              ),
            );
        }
      }

      // Stream encerrou — se ainda não completamos, tenta fallback.
      if (!completer.isCompleted) {
        final fallback = service.read(args.lessonLocalId)?.curriculum;
        final fallbackFirst = fallback == null
            ? null
            : _firstItemFrom(fallback);
        if (fallbackFirst != null) {
          completer.complete(fallbackFirst);
        } else {
          completer.completeError(Exception('curriculo sem primeiro item'));
        }
      }
    } catch (error) {
      service.mutate(args.lessonLocalId, (state) {
        return state.copyWith(
          profile: state.profile.copyWith(
            extra: {...state.profile.extra, 'bootstrap_status': 'failed'},
          ),
        );
      });
      if (!completer.isCompleted) {
        if (partialItems.isNotEmpty) {
          final partial = service.read(args.lessonLocalId)?.curriculum;
          final partialFirst = partial == null ? null : _firstItemFrom(partial);
          if (partialFirst != null) {
            writeStudentExperienceSnapshot(
              service,
              lessonLocalId: args.lessonLocalId,
              state: StudentExperienceState.providerFailedAfterPartial,
              startMarker: partialFirst.marker,
              startItemIndex: partialFirst.itemIndex,
            );
            publishStudentExperienceEvent(
              service,
              args.lessonLocalId,
              StudentExperienceEventType.t00ProviderFailedAfterPartial,
              {'items': partialItems.length, 'error': _safeT00GatewayError()},
            );
            completer.complete(partialFirst);
            return;
          }
        }
        completer.completeError(error);
      }
    }
  }

  String _safeT00GatewayError() => 'T00_PROVIDER_UNAVAILABLE';

  FirstCurriculumItem? _firstItemFrom(StudentCurriculum curriculum) {
    if (curriculum.items.isEmpty) return null;
    final item = curriculum.items.first;
    return FirstCurriculumItem(
      curriculum: curriculum,
      item: item,
      itemIndex: 0,
      marker: item.marker,
    );
  }

  void _scheduleContinuationIfNeeded({
    required String sourceLessonLocalId,
    required StudentExperienceArgs args,
  }) {
    final sourceState = service.read(sourceLessonLocalId);
    if (sourceState == null) return;
    final request = buildCurriculumContinuationRequest(sourceState);
    if (request == null) return;
    final partNumber = request['partNumber'] as int?;
    if (partNumber == null || partNumber <= 1) return;

    final rootId = curriculumPlanRootLessonId(sourceState);
    final nextLessonLocalId = curriculumPartLessonId(rootId, partNumber);
    final existingNext = service.read(nextLessonLocalId);
    if (existingNext?.curriculum?.items.isNotEmpty == true) {
      service.mutate(sourceLessonLocalId, (state) {
        return markCurriculumPartStatus(
          state: state,
          status: 'ready',
          nextLessonLocalId: nextLessonLocalId,
        );
      });
      return;
    }

    final inFlightKey = '$sourceLessonLocalId->$nextLessonLocalId';
    if (!_continuationInFlight.add(inFlightKey)) return;

    service.mutate(sourceLessonLocalId, (state) {
      return markCurriculumPartStatus(
        state: state,
        status: 'preparing',
        nextLessonLocalId: nextLessonLocalId,
      );
    });

    unawaited(
      _prefetchContinuation(
        sourceState: sourceState,
        request: request,
        args: args,
        nextLessonLocalId: nextLessonLocalId,
        inFlightKey: inFlightKey,
      ),
    );
  }

  Future<void> _prefetchContinuation({
    required StudentLearningState sourceState,
    required JsonMap request,
    required StudentExperienceArgs args,
    required String nextLessonLocalId,
    required String inFlightKey,
  }) async {
    try {
      final continuationOnboarding = _buildContinuationOnboarding(
        sourceState: sourceState,
        request: request,
        args: args,
        nextLessonLocalId: nextLessonLocalId,
      );
      await startT00UntilFirstItem(
        StudentExperienceArgs(
          academic: args.academic,
          idioma: args.idioma,
          lessonLocalId: nextLessonLocalId,
          onboarding: continuationOnboarding,
          localeContract: args.localeContract,
        ),
      );
      service.mutate(sourceState.lessonLocalId, (state) {
        return markCurriculumPartStatus(
          state: state,
          status: 'ready',
          nextLessonLocalId: nextLessonLocalId,
        );
      });
    } catch (error) {
      service.mutate(sourceState.lessonLocalId, (state) {
        return markCurriculumPartStatus(
          state: state,
          status: 'failed',
          nextLessonLocalId: nextLessonLocalId,
          error: _safeT00GatewayError(),
        );
      });
    } finally {
      _continuationInFlight.remove(inFlightKey);
    }
  }

  JsonMap _buildContinuationOnboarding({
    required StudentLearningState sourceState,
    required JsonMap request,
    required StudentExperienceArgs args,
    required String nextLessonLocalId,
  }) {
    final topic = sourceState.curriculum?.topic.trim();
    final objetivo = topic?.isNotEmpty == true
        ? topic!
        : (args.onboarding['objetivo'] ?? args.onboarding['free_text'] ?? '')
              .toString();
    return {
      ...args.onboarding,
      ...request,
      'lessonLocalId': nextLessonLocalId,
      'rootLessonLocalId': curriculumPlanRootLessonId(sourceState),
      'previousLessonLocalId': sourceState.lessonLocalId,
      'curriculum_continuation': true,
      'objetivo': objetivo,
      'free_text': objetivo,
      'target_topic': args.onboarding['target_topic'] ?? objetivo,
      'TARGET_TOPIC': args.onboarding['TARGET_TOPIC'] ?? objetivo,
      'previous_batch': request['previousBatch'],
      'next_global_item_to_request': request['nextGlobalItemToRequest'],
      'global_total_items': request['globalTotalItems'],
      'units_pending': request['unitsPending'],
      'continuation_instruction': request['continuationInstruction'],
      'part_number': request['partNumber'],
    };
  }

  void _notifyCurriculumExpanded(
    String lessonLocalId,
    String topic,
    String source,
  ) {
    service.mutate(lessonLocalId, (state) {
      final progress = state.progress;
      final totalItems = state.curriculum?.items.length ?? 0;
      if (progress == null || totalItems <= progress.totalItems) {
        return state;
      }
      final pctAvanco = totalItems == 0
          ? 0
          : ((progress.mainAdvances / totalItems) * 100).round().clamp(0, 100);
      return state.copyWith(
        progress: progress.copyWith(
          totalItems: totalItems,
          pctAvanco: pctAvanco.toInt(),
        ),
      );
    });
    final callback = onCurriculumExpanded;
    if (callback == null) return;
    final state = service.read(lessonLocalId);
    final current = state?.current;
    final progress = state?.progress;
    final itemIdx = current?.itemIdx ?? progress?.itemIdx ?? 0;
    final layer = current?.layer ?? progress?.layer ?? LessonLayer.l1;
    final items = state?.curriculum?.items ?? const <CurriculumItem>[];
    final marker =
        current?.marker ??
        (itemIdx >= 0 && itemIdx < items.length ? items[itemIdx].marker : null);
    callback(
      lessonLocalId: lessonLocalId,
      topic: topic,
      itemIdx: itemIdx,
      layer: layer,
      marker: marker,
      source: source,
    );
  }
}
