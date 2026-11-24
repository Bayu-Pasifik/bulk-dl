import 'package:bulk_dl/models.dart';
import 'package:bulk_dl/queue.dart';
import 'package:bulk_dl/queue_filter.dart';
import 'package:flutter_test/flutter_test.dart';

Task task(String title, Status s) => Task(
  VideoItem(id: title, path: '/$title', origin: 'https://x.test', title: title),
)..status = s;

void main() {
  final tasks = [
    task('Alpha Clip', Status.downloading),
    task('beta', Status.waiting),
    task('Gamma', Status.done),
    task('alpha two', Status.failed),
    task('Delta', Status.canceled),
    task('Eps', Status.resolving),
  ];
  List<String> names(List<Task> l) => l.map((t) => t.video.title).toList();

  test('all + empty query keeps everything in order', () {
    expect(names(filterTasks(tasks, '', QueueFilter.all)), names(tasks));
  });

  test('query is case-insensitive and trimmed', () {
    expect(names(filterTasks(tasks, '  ALPHA ', QueueFilter.all)), [
      'Alpha Clip',
      'alpha two',
    ]);
  });

  test('status filters', () {
    expect(names(filterTasks(tasks, '', QueueFilter.active)), [
      'Alpha Clip',
      'beta',
      'Eps',
    ]);
    expect(names(filterTasks(tasks, '', QueueFilter.done)), ['Gamma']);
    expect(names(filterTasks(tasks, '', QueueFilter.failed)), [
      'alpha two',
      'Delta',
    ]);
  });

  test('query and filter combine', () {
    expect(names(filterTasks(tasks, 'alpha', QueueFilter.failed)), [
      'alpha two',
    ]);
    expect(filterTasks(tasks, 'zzz', QueueFilter.all), isEmpty);
  });
}
