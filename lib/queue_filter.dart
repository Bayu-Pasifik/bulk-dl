import 'queue.dart';

enum QueueFilter { all, active, done, failed }

bool _matches(Task t, QueueFilter f) {
  switch (f) {
    case QueueFilter.all:
      return true;
    case QueueFilter.active:
      return t.status == Status.waiting ||
          t.status == Status.resolving ||
          t.status == Status.downloading;
    case QueueFilter.done:
      return t.status == Status.done;
    case QueueFilter.failed:
      return t.status == Status.failed || t.status == Status.canceled;
  }
}

/// Tasks whose title contains [query] (case-insensitive, trimmed) and that
/// match [filter]. Keeps the queue order.
List<Task> filterTasks(List<Task> tasks, String query, QueueFilter filter) {
  final q = query.trim().toLowerCase();
  return [
    for (final t in tasks)
      if (_matches(t, filter) &&
          (q.isEmpty || t.video.title.toLowerCase().contains(q)))
        t,
  ];
}
