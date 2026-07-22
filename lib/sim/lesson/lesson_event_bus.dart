import '../runtime/sim_runtime_audit.dart';
import 'lesson_models.dart';

typedef LessonListener = void Function(CompleteLesson lesson);

class LessonEventBus {
  final Map<String, Set<LessonListener>> _subscribers = {};
  final Map<String, CompleteLesson> _latestLessons = {};

  void Function() subscribe(String key, LessonListener listener) {
    final set = _subscribers.putIfAbsent(key, () => <LessonListener>{});
    set.add(listener);
    if (_latestLessons.containsKey(key)) {
      try {
        listener(_latestLessons[key]!);
      } catch (error, stackTrace) {
        SimRuntimeAudit.report(
          code: 'listener_failed',
          source: 'LessonEventBus.subscribe.replay',
          details: {'key': key},
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return () {
      set.remove(listener);
      if (set.isEmpty) _subscribers.remove(key);
    };
  }

  void notify(String key, CompleteLesson lesson) {
    _latestLessons[key] = lesson;
    final set = _subscribers[key];
    if (set == null) return;
    for (final listener in List<LessonListener>.from(set)) {
      try {
        listener(lesson);
      } catch (error, stackTrace) {
        SimRuntimeAudit.report(
          code: 'listener_failed',
          source: 'LessonEventBus.notify',
          details: {'key': key},
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
