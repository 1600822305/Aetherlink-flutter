import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

import 'package:aetherlink_flutter/features/backup/data/backup_service.dart';
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
  final List<BackupFileItem> localBackups;
  final List<BackupFileItem> remoteBackups;

  const BackupState({
    this.status = BackupStatus.idle,
    this.message = '',
    this.webDavConfig = const WebDavConfig(),
    this.localBackups = const [],
    this.remoteBackups = const [],
  });

  BackupState copyWith({
    BackupStatus? status,
    String? message,
    WebDavConfig? webDavConfig,
    List<BackupFileItem>? localBackups,
    List<BackupFileItem>? remoteBackups,
  }) {
    return BackupState(
      status: status ?? this.status,
      message: message ?? this.message,
      webDavConfig: webDavConfig ?? this.webDavConfig,
      localBackups: localBackups ?? this.localBackups,
      remoteBackups: remoteBackups ?? this.remoteBackups,
    );
  }
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class BackupController extends _$BackupController {
  late final BackupService _service;

  @override
  BackupState build() {
    final db = ref.read(appDatabaseProvider);
    _service = BackupService(db: db);
    // Load saved WebDAV config and local backups on init.
    _loadInitialState();
    return const BackupState();
  }

  Future<void> _loadInitialState() async {
    try {
      final locals = await _service.listLocalBackups();
      final savedConfig = await _loadWebDavConfig();
      state = state.copyWith(
        localBackups: locals,
        webDavConfig: savedConfig,
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
      final locals = await _service.listLocalBackups();
      state = state.copyWith(
        status: BackupStatus.success,
        message: '备份创建成功',
        localBackups: locals,
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
      // Refresh remote list.
      final remotes = await client.listFiles();
      final locals = await _service.listLocalBackups();
      state = state.copyWith(
        status: BackupStatus.success,
        message: 'WebDAV 备份成功',
        remoteBackups: remotes,
        localBackups: locals,
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
}


