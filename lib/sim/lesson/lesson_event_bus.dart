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
      } catch (_) {
        // isolate listener failures so other subscribers still receive events
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
      } catch (_) {
        // isolate listener failures so other subscribers still receive the event
      }
    }
  }

}
