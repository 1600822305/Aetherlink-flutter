import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import 'package:aetherlink_flutter/features/backup/data/backup_reminder_service.dart';
import 'package:aetherlink_flutter/features/backup/data/backup_service.dart';
import 'package:aetherlink_flutter/features/backup/data/s3_client.dart';
import 'package:aetherlink_flutter/features/backup/data/webdav_client.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_file_item.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_manifest.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';

part 'backup_controller.g.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum BackupStatus { idle, working, success, error }

class BackupState {
  final BackupStatus status;
  final String message;
  final WebDavConfig webDavConfig;
  final S3Config s3Config;
  final List<BackupFileItem> localBackups;
  final List<BackupFileItem> remoteBackups;
  final List<BackupFileItem> s3Backups;
  final bool reminderEnabled;
  final int reminderIntervalDays;
  final int? reminderMinutesOfDay;
  final DateTime? lastBackupAt;
  final DateTime? nextReminderAt;

  const BackupState({
    this.status = BackupStatus.idle,
    this.message = '',
    this.webDavConfig = const WebDavConfig(),
    this.s3Config = const S3Config(),
    this.localBackups = const [],
    this.remoteBackups = const [],
    this.s3Backups = const [],
    this.reminderEnabled = false,
    this.reminderIntervalDays = 7,
    this.reminderMinutesOfDay,
    this.lastBackupAt,
    this.nextReminderAt,
  });

  BackupState copyWith({
    BackupStatus? status,
    String? message,
    WebDavConfig? webDavConfig,
    S3Config? s3Config,
    List<BackupFileItem>? localBackups,
    List<BackupFileItem>? remoteBackups,
    List<BackupFileItem>? s3Backups,
    bool? reminderEnabled,
    int? reminderIntervalDays,
    int? Function()? reminderMinutesOfDay,
    DateTime? Function()? lastBackupAt,
    DateTime? Function()? nextReminderAt,
  }) {
    return BackupState(
      status: status ?? this.status,
      message: message ?? this.message,
      webDavConfig: webDavConfig ?? this.webDavConfig,
      s3Config: s3Config ?? this.s3Config,
      localBackups: localBackups ?? this.localBackups,
      remoteBackups: remoteBackups ?? this.remoteBackups,
      s3Backups: s3Backups ?? this.s3Backups,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderIntervalDays: reminderIntervalDays ?? this.reminderIntervalDays,
      reminderMinutesOfDay: reminderMinutesOfDay != null
          ? reminderMinutesOfDay()
          : this.reminderMinutesOfDay,
      lastBackupAt: lastBackupAt != null ? lastBackupAt() : this.lastBackupAt,
      nextReminderAt:
          nextReminderAt != null ? nextReminderAt() : this.nextReminderAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class BackupController extends _$BackupController {
  late final BackupService _service;
  final S3BackupClient _s3Client = const S3BackupClient();
  final BackupReminderService _reminder = BackupReminderService();

  @override
  BackupState build() {
    final db = ref.read(appDatabaseProvider);
    _service = BackupService(db: db);
    _loadInitialState();
    return const BackupState();
  }

  Future<void> _loadInitialState() async {
    try {
      final locals = await _service.listLocalBackups();
      final savedWebDav = await _loadWebDavConfig();
      final savedS3 = await _loadS3Config();
      await _reminder.load();
      state = state.copyWith(
        localBackups: locals,
        webDavConfig: savedWebDav,
        s3Config: savedS3,
        reminderEnabled: _reminder.enabled,
        reminderIntervalDays: _reminder.intervalDays,
        reminderMinutesOfDay: () => _reminder.reminderMinutesOfDay,
        lastBackupAt: () => _reminder.lastBackupAt,
        nextReminderAt: () => _reminder.nextReminderAt,
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Local backup
  // ---------------------------------------------------------------------------

  /// Creates a backup ZIP and shares it via the system share sheet.
  Future<void> createAndShareBackup() async {
    state = state.copyWith(status: BackupStatus.working, message: '正在创建备份...');
    try {
      final file = await _service.createBackup(
        includeMessages: true,
        includeProviders: true,
        includeSettings: true,
      );
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
      await _reminder.recordBackupCompleted();
      final locals = await _service.listLocalBackups();
      state = state.copyWith(
        status: BackupStatus.success,
        message: '备份创建成功',
        localBackups: locals,
        lastBackupAt: () => _reminder.lastBackupAt,
        nextReminderAt: () => _reminder.nextReminderAt,
      );
    } catch (e) {
      state = state.copyWith(
        status: BackupStatus.error,
        message: '备份失败: $e',
      );
    }
  }

  /// Picks a local ZIP file and restores from it.
  Future<BackupManifest?> pickAndPeekBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.first.path;
    if (path == null) return null;

    try {
      return await _service.peekManifest(File(path));
    } catch (e) {
      state = state.copyWith(
        status: BackupStatus.error,
        message: '无法读取备份文件: $e',
      );
      return null;
    }
  }

  /// Restores from a locally picked file with the given mode.
  Future<void> restoreFromLocal(String filePath, RestoreMode mode) async {
    state = state.copyWith(status: BackupStatus.working, message: '正在恢复数据...');
    try {
      await _service.restoreFromFile(File(filePath), mode: mode);
      final locals = await _service.listLocalBackups();
      state = state.copyWith(
        status: BackupStatus.success,
        message: '数据恢复成功',
        localBackups: locals,
      );
    } catch (e) {
      state = state.copyWith(
        status: BackupStatus.error,
        message: '恢复失败: $e',
      );
    }
  }

  /// Deletes a local backup file.
  Future<void> deleteLocalBackup(String filename) async {
    await _service.deleteLocalBackup(filename);
    final locals = await _service.listLocalBackups();
    state = state.copyWith(localBackups: locals);
  }

  // ---------------------------------------------------------------------------
  // WebDAV
  // ---------------------------------------------------------------------------

  void updateWebDavConfig(WebDavConfig config) {
    state = state.copyWith(webDavConfig: config);
    _saveWebDavConfig(config);
  }

  Future<void> testWebDavConnection() async {
    state = state.copyWith(status: BackupStatus.working, message: '正在测试连接...');
    try {
      final client = WebDavClient(config: state.webDavConfig);
      await client.testConnection();
      state = state.copyWith(
        status: BackupStatus.success,
        message: '连接成功',
      );
    } catch (e) {
      state = state.copyWith(
        status: BackupStatus.error,
        message: '连接失败: $e',
      );
    }
  }

  Future<void> backupToWebDav() async {
    state = state.copyWith(status: BackupStatus.working, message: '正在备份到 WebDAV...');
    try {
      final file = await _service.createBackup();
      final client = WebDavClient(config: state.webDavConfig);
      await client.upload(file);
      await _reminder.recordBackupCompleted();
      final remotes = await client.listFiles();
      final locals = await _service.listLocalBackups();
      state = state.copyWith(
        status: BackupStatus.success,
        message: 'WebDAV 备份成功',
        remoteBackups: remotes,
        localBackups: locals,
        lastBackupAt: () => _reminder.lastBackupAt,
        nextReminderAt: () => _reminder.nextReminderAt,
      );
    } catch (e) {
      state = state.copyWith(
        status: BackupStatus.error,
        message: 'WebDAV 备份失败: $e',
      );
    }
  }

  Future<void> loadRemoteBackups() async {
    try {
      final client = WebDavClient(config: state.webDavConfig);
      final remotes = await client.listFiles();
      state = state.copyWith(remoteBackups: remotes);
    } catch (e) {
      state = state.copyWith(
        status: BackupStatus.error,
        message: '加载远程备份列表失败: $e',
      );
    }
  }

  Future<void> restoreFromWebDav(BackupFileItem item, RestoreMode mode) async {
    state =
        state.copyWith(status: BackupStatus.working, message: '正在从 WebDAV 恢复...');
    try {
      final client = WebDavClient(config: state.webDavConfig);
      final file = await client.download(item);
      try {
        await _service.restoreFromFile(file, mode: mode);
      } finally {
        try {
          await file.delete();
          await file.parent.delete();
        } catch (_) {}
      }
      final locals = await _service.listLocalBackups();
      state = state.copyWith(
        status: BackupStatus.success,
        message: '从 WebDAV 恢复成功',
        localBackups: locals,
      );
    } catch (e) {
      state = state.copyWith(
        status: BackupStatus.error,
        message: '从 WebDAV 恢复失败: $e',
      );
    }
  }

  Future<void> deleteRemoteBackup(BackupFileItem item) async {
    try {
      final client = WebDavClient(config: state.webDavConfig);
      await client.delete(item);
      final remotes = await client.listFiles();
      state = state.copyWith(remoteBackups: remotes);
    } catch (e) {
      state = state.copyWith(
        status: BackupStatus.error,
        message: '删除远程备份失败: $e',
      );
    }
  }

  void clearStatus() {
    state = state.copyWith(status: BackupStatus.idle, message: '');
  }

  // ---------------------------------------------------------------------------
  // S3 cloud storage
  // ---------------------------------------------------------------------------

  void updateS3Config(S3Config config) {
    state = state.copyWith(s3Config: config);
    _saveS3Config(config);
  }

  Future<void> testS3Connection() async {
    state = state.copyWith(status: BackupStatus.working, message: '正在测试 S3 连接...');
    try {
      await _s3Client.test(state.s3Config);
      state = state.copyWith(
        status: BackupStatus.success,
        message: 'S3 连接成功',
      );
    } catch (e) {
      state = state.copyWith(
        status: BackupStatus.error,
        message: 'S3 连接失败: $e',
      );
    }
  }

  Future<void> backupToS3() async {
    state = state.copyWith(status: BackupStatus.working, message: '正在备份到 S3...');
    try {
      final file = await _service.createBackup(
        includeMessages: state.s3Config.includeMessages,
        includeProviders: state.s3Config.includeProviders,
        includeSettings: state.s3Config.includeSettings,
      );
      final prefix = _normalizeS3Prefix(state.s3Config.prefix);
      final key = '$prefix${p.basename(file.path)}';
      await _s3Client.uploadFile(state.s3Config, key: key, file: file);
      await _reminder.recordBackupCompleted();
      final s3List = await _s3Client.listObjects(state.s3Config);
      final locals = await _service.listLocalBackups();
      state = state.copyWith(
        status: BackupStatus.success,
        message: 'S3 备份成功',
        s3Backups: s3List,
        localBackups: locals,
        lastBackupAt: () => _reminder.lastBackupAt,
        nextReminderAt: () => _reminder.nextReminderAt,
      );
    } catch (e) {
      state = state.copyWith(
        status: BackupStatus.error,
        message: 'S3 备份失败: $e',
      );
    }
  }

  Future<void> loadS3Backups() async {
    try {
      final items = await _s3Client.listObjects(state.s3Config);
      state = state.copyWith(s3Backups: items);
    } catch (e) {
      state = state.copyWith(
        status: BackupStatus.error,
        message: '加载 S3 备份列表失败: $e',
      );
    }
  }

  Future<void> restoreFromS3(BackupFileItem item, RestoreMode mode) async {
    state = state.copyWith(status: BackupStatus.working, message: '正在从 S3 恢复...');
    File? file;
    try {
      final key = item.href.pathSegments.join('/');
      final tmp = await getTemporaryDirectory();
      file = File(p.join(tmp.path, item.displayName));
      await _s3Client.downloadToFile(state.s3Config, key: key, destination: file);
      await _service.restoreFromFile(file, mode: mode);
      final locals = await _service.listLocalBackups();
      state = state.copyWith(
        status: BackupStatus.success,
        message: '从 S3 恢复成功',
        localBackups: locals,
      );
    } catch (e) {
      state = state.copyWith(
        status: BackupStatus.error,
        message: '从 S3 恢复失败: $e',
      );
    } finally {
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Future<void> deleteS3Backup(BackupFileItem item) async {
    try {
      final key = item.href.pathSegments.join('/');
      await _s3Client.deleteObject(state.s3Config, key: key);
      final items = await _s3Client.listObjects(state.s3Config);
      state = state.copyWith(s3Backups: items);
    } catch (e) {
      state = state.copyWith(
        status: BackupStatus.error,
        message: '删除 S3 备份失败: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Backup reminder
  // ---------------------------------------------------------------------------

  Future<void> saveReminderSchedule({
    required bool enabled,
    required int intervalDays,
    required int minutesOfDay,
  }) async {
    await _reminder.saveSchedule(
      enabled: enabled,
      intervalDays: intervalDays,
      reminderMinutesOfDay: minutesOfDay,
    );
    state = state.copyWith(
      reminderEnabled: _reminder.enabled,
      reminderIntervalDays: _reminder.intervalDays,
      reminderMinutesOfDay: () => _reminder.reminderMinutesOfDay,
      lastBackupAt: () => _reminder.lastBackupAt,
      nextReminderAt: () => _reminder.nextReminderAt,
    );
  }

  Future<void> setReminderEnabled(bool value) async {
    await _reminder.setEnabled(value);
    state = state.copyWith(
      reminderEnabled: _reminder.enabled,
      nextReminderAt: () => _reminder.nextReminderAt,
    );
  }

  void snoozeReminder() {
    _reminder.snoozeForSession();
  }

  bool get shouldShowReminder => _reminder.shouldShowReminder;

  // ---------------------------------------------------------------------------
  // Config persistence (stored in AppSettingRows)
  // ---------------------------------------------------------------------------

  Future<WebDavConfig> _loadWebDavConfig() async {
    final db = ref.read(appDatabaseProvider);
    final json = await db.appSettingDao.getValue('webdav_config');
    if (json == null) return const WebDavConfig();
    return WebDavConfig.fromJsonString(json);
  }

  Future<void> _saveWebDavConfig(WebDavConfig config) async {
    final db = ref.read(appDatabaseProvider);
    await db.appSettingDao.setValue('webdav_config', config.toJsonString());
  }

  Future<S3Config> _loadS3Config() async {
    final db = ref.read(appDatabaseProvider);
    final json = await db.appSettingDao.getValue('s3_config');
    if (json == null) return const S3Config();
    return S3Config.fromJsonString(json);
  }

  Future<void> _saveS3Config(S3Config config) async {
    final db = ref.read(appDatabaseProvider);
    await db.appSettingDao.setValue('s3_config', config.toJsonString());
  }

  static String _normalizeS3Prefix(String prefix) {
    var s = prefix.trim().replaceAll(RegExp(r'^/+'), '');
    if (s.isEmpty) return '';
    if (!s.endsWith('/')) s = '$s/';
    return s;
  }
}


