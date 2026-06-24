import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// Manages local notifications for backup reminders.
class BackupNotificationService {
  static final BackupNotificationService _instance =
      BackupNotificationService._();
  factory BackupNotificationService() => _instance;
  BackupNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const int _backupReminderNotificationId = 1001;
  static const String _channelId = 'backup_reminder';
  static const String _channelName = '备份提醒';
  static const String _channelDescription = '定期提醒您备份数据';

  /// Initialize the notification plugin. Must be called once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Request notification permission (Android 13+).
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Schedule a backup reminder notification at the given [scheduledDate].
  Future<void> scheduleBackupReminder(DateTime scheduledDate) async {
    if (!_initialized) await initialize();

    final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);

    // Don't schedule in the past.
    if (tzScheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      _backupReminderNotificationId,
      '备份提醒',
      '您已经很久没有备份数据了，建议立即备份以防数据丢失',
      tzScheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
  }

  /// Cancel the pending backup reminder notification.
  Future<void> cancelBackupReminder() async {
    if (!_initialized) await initialize();
    await _plugin.cancel(_backupReminderNotificationId);
  }

  /// Show an immediate notification (e.g., when app is in foreground and
  /// reminder is due).
  Future<void> showImmediateReminder() async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      _backupReminderNotificationId,
      '备份提醒',
      '您已经很久没有备份数据了，建议立即备份以防数据丢失',
      details,
    );
  }
}
