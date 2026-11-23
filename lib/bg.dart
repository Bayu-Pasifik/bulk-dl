import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() => FlutterForegroundTask.setTaskHandler(_Handler());

/// No-op handler: downloads run in the main isolate, the foreground service
/// only keeps the process alive and shows the notification.
class _Handler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class BgService {
  static bool _running = false;
  static String _last = '';

  static void init() {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'bulk_dl_download',
        channelName: 'Downloads',
        channelDescription: 'Shows download progress',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> requestPermissions() async {
    if (await FlutterForegroundTask.checkNotificationPermission() !=
        NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  /// Start/update/stop the service to match the queue state.
  static Future<void> sync({required int active, required String text}) async {
    if (active == 0) {
      if (_running) {
        _running = false;
        _last = '';
        await FlutterForegroundTask.stopService();
      }
      return;
    }
    if (text == _last) return;
    _last = text;
    if (_running) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Bulk DL',
        notificationText: text,
      );
    } else {
      _running = true;
      final r = await FlutterForegroundTask.startService(
        serviceId: 7001,
        notificationTitle: 'Bulk DL',
        notificationText: text,
        serviceTypes: [ForegroundServiceTypes.dataSync],
        callback: startCallback,
      );
      if (r is ServiceRequestFailure) _running = false;
    }
  }
}
