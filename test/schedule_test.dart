import 'package:bulk_dl/queue.dart';
import 'package:bulk_dl/scraper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

int m(int h, [int min = 0]) => h * 60 + min;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('inWindow', () {
    test('same-day window is [start, end)', () {
      expect(DownloadQueue.inWindow(m(9), m(9), m(17)), true);
      expect(DownloadQueue.inWindow(m(16, 59), m(9), m(17)), true);
      expect(DownloadQueue.inWindow(m(17), m(9), m(17)), false);
      expect(DownloadQueue.inWindow(m(8, 59), m(9), m(17)), false);
    });

    test('window wrapping midnight', () {
      expect(DownloadQueue.inWindow(m(23), m(22), m(6)), true);
      expect(DownloadQueue.inWindow(m(0), m(22), m(6)), true);
      expect(DownloadQueue.inWindow(m(5, 59), m(22), m(6)), true);
      expect(DownloadQueue.inWindow(m(6), m(22), m(6)), false);
      expect(DownloadQueue.inWindow(m(12), m(22), m(6)), false);
    });

    test('start == end means always', () {
      expect(DownloadQueue.inWindow(m(3), m(8), m(8)), true);
    });
  });

  group('queue schedule', () {
    DownloadQueue make(int hour) {
      final q = DownloadQueue(Scraper());
      q.concurrency = 0;
      q.clock = () => DateTime(2026, 1, 1, hour);
      return q;
    }

    test('off by default, never blocks', () {
      final q = make(12);
      expect(q.scheduleOn, false);
      expect(q.blocked, false);
    });

    test('blocks outside the window, opens inside', () {
      final q = make(12);
      q.setSchedule(on: true, start: m(22), end: m(6));
      expect(q.outsideSchedule, true);
      expect(q.blocked, true);
      expect(q.blockedByWifi, false);

      q.clock = () => DateTime(2026, 1, 1, 23);
      expect(q.blocked, false);
      q.dispose();
    });

    test('settings persist across instances', () async {
      make(12).setSchedule(on: true, start: m(1, 30), end: m(7, 15));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final q2 = make(12);
      await q2.loadSettings();
      expect(q2.scheduleOn, true);
      expect(q2.scheduleStart, m(1, 30));
      expect(q2.scheduleEnd, m(7, 15));
      q2.dispose();
    });
  });
}
