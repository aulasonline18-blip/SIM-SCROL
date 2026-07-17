// Part III.4: runImageSequential + runBackgroundText queues
// D2.2: ensureFirstLessonPrepared + ensureLessonWindow
import 'dart:async';

import 'lesson_material_cache.dart';
import 'lesson_models.dart';
import 'lesson_orchestrator.dart';

/// Sequential image queue — runs at most one image fetch at a time.
/// Sequential image queue from the SIMAPP visual pipeline.
class ImageSequentialQueue {
  Future<void> _chain = Future.value();

  Future<T> run<T>(Future<T> Function() fn) {
    final next = _chain.then((_) => fn());
    _chain = next.then((_) {}).catchError((_) {});
    return next;
  }
}

/// Background text semaphore — allows at most 2 concurrent background fetches.
/// Dart translation of Web's runBackgroundText (Planta-Mãe III.4).
class BackgroundTextSemaphore {
  static const int _maxConcurrent = 2;

  int _active = 0;
  final List<Completer<void>> _waiters = [];

  Future<T> run<T>(Future<T> Function() fn) async {
    if (_active >= _maxConcurrent) {
      final c = Completer<void>();
      _waiters.add(c);
      await c.future;
    }
    _active++;
    try {
      return await fn();
    } finally {
      _active--;
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete();
      }
    }
  }
}

// ── D2.2 ─────────────────────────────────────────────────────────────────────

/// Enfileira o material da primeira aula como abastecimento, sem travar a sala.
/// Mirror de ensureFirstLessonPrepared (src/cyber/lesson-pipeline-runtime.ts).
Future<CompleteLesson?> ensureFirstLessonPrepared({
  required LessonOrchestrator orchestrator,
  required LessonMaterialCache cache,
  required CompleteLessonParams params,
}) async {
  final key = lessonKeyFor(params);
  final cached = cache.peek(key);
  if (cached != null) return cached;
  try {
    return await orchestrator.prefetchCompleteLesson(
      params,
      priority: 'background',
    );
  } catch (_) {
    return null;
  }
}

/// Mantém a janela viva de experiências pedagógicas pré-carregadas.
/// Mirror de ensureLessonWindow (src/cyber/lesson-pipeline-runtime.ts).
Future<void> ensureLessonWindow({
  required LessonOrchestrator orchestrator,
  required LessonMaterialCache cache,
  required List<CompleteLessonParams> window,
  int maxSlots = 4,
}) async {
  final needed = window.take(maxSlots).toList();
  await Future.wait(
    needed.map((params) async {
      final key = lessonKeyFor(params);
      if (cache.peek(key) != null) return;
      try {
        await orchestrator.prefetchCompleteLesson(params, priority: 'background');
      } catch (_) {
        // best-effort: erros individuais não bloqueiam a janela
      }
    }),
    eagerError: false,
  );
}
