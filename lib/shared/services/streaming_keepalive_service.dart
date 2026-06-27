import 'dart:io' show Platform;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the app process alive while an LLM reply is streaming so that switching
/// the app to the background doesn't let Android suspend the process / cut the
/// network mid-generation (the conversation keeps going in the background).
///
/// Backed by an Android foreground service with an ongoing notification. On iOS
/// this is best-effort — the OS only grants a short background grace period and
/// will suspend the app afterwards, which no app-level code can override.
class StreamingKeepAliveService {
  StreamingKeepAliveService._();

  static const String _channelId = 'aetherlink_streaming';
  static const int _serviceId = 451;

  static bool _initialized = false;

  static bool get _supported => Platform.isAndroid || Platform.isIOS;

  /// Configure the notification channel + task options. Idempotent.
  static void _ensureInit() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: '正在生成回复',
        channelDescription: '在后台保持 AI 回复生成不被系统中断',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  /// Start keeping the process alive. No-op when not running on a mobile
  /// platform or when the service is already running.
  static Future<void> begin() async {
    if (!_supported) return;
    _ensureInit();
    if (await FlutterForegroundTask.isRunningService) return;
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: [ForegroundServiceTypes.dataSync],
      notificationTitle: '正在生成回复…',
      notificationText: 'AetherLink 正在后台继续生成 AI 回复',
    );
  }

  /// Stop keeping the process alive. No-op when nothing is running.
  static Future<void> end() async {
    if (!_supported) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
  }
}
