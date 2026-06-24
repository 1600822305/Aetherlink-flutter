import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Manages backup reminder scheduling and notification state.
/// Tracks when the last backup was performed and determines
/// whether to show a reminder based on user-configured intervals.
class BackupReminderService {
  static const List<int> presetIntervals = [1, 3, 7, 14, 30];

  static const String _enabledKey = 'backup_reminder_enabled_v1';
  static const String _intervalDaysKey = 'backup_reminder_interval_days_v1';
  static const String _minutesOfDayKey = 'backup_reminder_minutes_of_day_v1';
  static const String _enabledAtKey = 'backup_reminder_enabled_at_v1';
  static const String _lastBackupAtKey = 'backup_reminder_last_backup_at_v1';

  bool _loaded = false;
  bool _enabled = false;
  int _intervalDays = 7;
  int? _reminderMinutesOfDay;
  DateTime? _enabledAt;
  DateTime? _lastBackupAt;
  bool _snoozedForSession = false;
  Timer? _timer;

  bool get loaded => _loaded;
  bool get enabled => _enabled;
  int get intervalDays => _intervalDays;
  int? get reminderMinutesOfDay => _reminderMinutesOfDay;
  DateTime? get enabledAt => _enabledAt;
  DateTime? get lastBackupAt => _lastBackupAt;

  bool get shouldShowReminder {
    if (!_enabled || _snoozedForSession) return false;
    final next = nextReminderAt;
    if (next == null) return false;
    return !DateTime.now().isBefore(next);
  }

  DateTime? get nextReminderAt {
    if (!_enabled || _reminderMinutesOfDay == null) return null;
    final anchor = _lastBackupAt ?? _enabledAt;
    if (anchor == null) return null;
    final date = DateTime(
      anchor.year,
      anchor.month,
      anchor.day + _intervalDays,
    );
    final minutes = _reminderMinutesOfDay!;
    return DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _intervalDays = _normalizeInterval(prefs.getInt(_intervalDaysKey) ?? 7);
    _reminderMinutesOfDay = _normalizeMinutes(prefs.getInt(_minutesOfDayKey));
    _enabledAt = _parseDate(prefs.getString(_enabledAtKey));
    _lastBackupAt = _parseDate(prefs.getString(_lastBackupAtKey));
    _loaded = true;
  }

  Future<void> saveSchedule({
    required bool enabled,
    required int intervalDays,
    required int reminderMinutesOfDay,
  }) async {
    final normalizedInterval = intervalDays.clamp(1, 365);
    final normalizedMinutes = reminderMinutesOfDay.clamp(0, 24 * 60 - 1);
    final now = DateTime.now();
    final wasEnabled = _enabled;

    _enabled = enabled;
    _intervalDays = normalizedInterval;
    _reminderMinutesOfDay = normalizedMinutes;
    if (enabled && (!wasEnabled || _enabledAt == null)) {
      _enabledAt = now;
    }
    if (!enabled) {
      _snoozedForSession = false;
    }
    await _persist();
  }

  Future<void> setEnabled(bool value) async {
    if (value && _reminderMinutesOfDay == null) return;
    if (!value) {
      _enabled = false;
      _snoozedForSession = false;
      await _persist();
      return;
    }
    await saveSchedule(
      enabled: true,
      intervalDays: _intervalDays,
      reminderMinutesOfDay: _reminderMinutesOfDay!,
    );
  }

  Future<void> recordBackupCompleted() async {
    _lastBackupAt = DateTime.now();
    _snoozedForSession = false;
    await _persist();
  }

  void snoozeForSession() {
    _snoozedForSession = true;
  }

  void startPeriodicCheck(void Function() onDue) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (shouldShowReminder) onDue();
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, _enabled);
    await prefs.setInt(_intervalDaysKey, _intervalDays);
    if (_reminderMinutesOfDay == null) {
      await prefs.remove(_minutesOfDayKey);
    } else {
      await prefs.setInt(_minutesOfDayKey, _reminderMinutesOfDay!);
    }
    await _setDate(prefs, _enabledAtKey, _enabledAt);
    await _setDate(prefs, _lastBackupAtKey, _lastBackupAt);
  }

  static int _normalizeInterval(int value) => value.clamp(1, 365);

  static int? _normalizeMinutes(int? value) {
    if (value == null) return null;
    if (value < 0 || value >= 24 * 60) return null;
    return value;
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static Future<void> _setDate(
    SharedPreferences prefs,
    String key,
    DateTime? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value.toIso8601String());
    }
  }
}
