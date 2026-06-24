import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:aetherlink_flutter/features/backup/data/backup_service.dart';
import 'package:aetherlink_flutter/features/backup/data/webdav_client.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';

/// Preset sync interval options in minutes.
const List<int> kAutoSyncIntervalOptions = [15, 30, 60, 120, 360, 720, 1440];

/// Manages periodic automatic backup to WebDAV.
class WebDavAutoSyncService {
  static final WebDavAutoSyncService _instance = WebDavAutoSyncService._();
  factory WebDavAutoSyncService() => _instance;
  WebDavAutoSyncService._();

  static const String _enabledKey = 'webdav_auto_sync_enabled_v1';
  static const String _intervalMinutesKey = 'webdav_auto_sync_interval_v1';
  static const String _lastSyncAtKey = 'webdav_auto_sync_last_at_v1';
  static const String _maxBackupsKey = 'webdav_auto_sync_max_backups_v1';

  Timer? _timer;
  bool _syncing = false;
  bool _enabled = false;
  int _intervalMinutes = 60;
  int _maxBackups = 5;
  DateTime? _lastSyncAt;
  String? _lastError;

  BackupService? _backupService;
  WebDavConfig? _webDavConfig;

  bool get enabled => _enabled;
  int get intervalMinutes => _intervalMinutes;
  int get maxBackups => _maxBackups;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastError => _lastError;
  bool get isSyncing => _syncing;

  /// Load persisted state from SharedPreferences.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _intervalMinutes = prefs.getInt(_intervalMinutesKey) ?? 60;
    _maxBackups = prefs.getInt(_maxBackupsKey) ?? 5;
    final lastStr = prefs.getString(_lastSyncAtKey);
    _lastSyncAt = lastStr != null ? DateTime.tryParse(lastStr) : null;
  }

  /// Configure runtime dependencies.
  void configure({
    required BackupService backupService,
    required WebDavConfig webDavConfig,
  }) {
    _backupService = backupService;
    _webDavConfig = webDavConfig;
  }

  /// Save settings and start/stop the timer accordingly.
  Future<void> saveSettings({
    required bool enabled,
    required int intervalMinutes,
    required int maxBackups,
  }) async {
    _enabled = enabled;
    _intervalMinutes = intervalMinutes.clamp(1, 10080);
    _maxBackups = maxBackups.clamp(1, 100);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, _enabled);
    await prefs.setInt(_intervalMinutesKey, _intervalMinutes);
    await prefs.setInt(_maxBackupsKey, _maxBackups);

    if (_enabled) {
      _startTimer();
    } else {
      _stopTimer();
    }
  }

  /// Resume auto-sync if previously enabled (call at app startup).
  void resumeIfEnabled() {
    if (_enabled && _webDavConfig != null && _webDavConfig!.isConfigured) {
      _startTimer();
    }
  }

  /// Perform an immediate sync (can be triggered manually from UI).
  Future<bool> syncNow() async {
    if (_syncing) return false;
    if (_backupService == null || _webDavConfig == null) return false;
    if (!_webDavConfig!.isConfigured) return false;

    _syncing = true;
    _lastError = null;

    try {
      final file = await _backupService!.createBackup();
      final client = WebDavClient(config: _webDavConfig!);
      await client.upload(file);

      _lastSyncAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncAtKey, _lastSyncAt!.toIso8601String());

      await _cleanupOldBackups(client);
      _syncing = false;
      return true;
    } catch (e) {
      _lastError = e.toString();
      _syncing = false;
      return false;
    }
  }

  void dispose() {
    _stopTimer();
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  void _startTimer() {
    _stopTimer();
    final duration = Duration(minutes: _intervalMinutes);
    _timer = Timer.periodic(duration, (_) => syncNow());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _cleanupOldBackups(WebDavClient client) async {
    if (_maxBackups <= 0) return;
    try {
      final files = await client.listFiles();
      if (files.length <= _maxBackups) return;

      // Sort newest first by date.
      files.sort(
        (a, b) => (b.lastModified ?? DateTime(0)).compareTo(
          a.lastModified ?? DateTime(0),
        ),
      );
      final toDelete = files.sublist(_maxBackups);
      for (final item in toDelete) {
        await client.delete(item);
      }
    } catch (_) {}
  }
}
