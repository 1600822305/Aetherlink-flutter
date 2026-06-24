import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_file_item.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_manifest.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// Core backup/restore logic. Reads data from [AppDatabase], serializes to JSON,
/// packs into ZIP, and provides restore with transaction safety.
class BackupService {
  final AppDatabase db;

  /// Maximum number of auto-backups to retain.
  static const int _maxAutoBackups = 5;

  BackupService({required this.db});

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Creates a backup ZIP file and returns the [File] handle.
  /// The caller is responsible for sharing/uploading/moving it.
  Future<File> createBackup({
    bool includeMessages = true,
    bool includeProviders = true,
    bool includeSettings = true,
  }) async {
    // 1. Read all data inside a transaction for consistency.
    final data = await _readAllData(
      includeMessages: includeMessages,
      includeProviders: includeProviders,
      includeSettings: includeSettings,
    );

    // 2. Build manifest.
    final manifest = BackupManifest(
      createdAt: DateTime.now().toUtc().toIso8601String(),
      schemaVersion: db.schemaVersion,
      deviceInfo: await _deviceInfo(),
      stats: BackupStats(
        topics: data.topics.length,
        messages: data.messages.length,
        messageBlocks: data.messageBlocks.length,
        assistants: data.assistants.length,
        providers: data.providers.length,
        groups: data.groups.length,
        settings: data.settings.length,
      ),
      options: BackupOptions(
        includeMessages: includeMessages,
        includeProviders: includeProviders,
        includeSettings: includeSettings,
      ),
    );

    // 3. Serialize JSON strings.
    final topicsJson = jsonEncode(data.topics);
    final messagesJson = jsonEncode(data.messages);
    final blocksJson = jsonEncode(data.messageBlocks);
    final assistantsJson = jsonEncode(data.assistants);
    final providersJson = jsonEncode(data.providers);
    final groupsJson = jsonEncode(data.groups);
    final settingsJson = jsonEncode(data.settings);

    // 4. Compute checksum over data files.
    final allBytes = utf8.encode(
      '$topicsJson$messagesJson$blocksJson$assistantsJson$providersJson$groupsJson$settingsJson',
    );
    final checksumHex = sha256.convert(allBytes).toString();
    final manifestWithChecksum = BackupManifest(
      version: manifest.version,
      appVersion: manifest.appVersion,
      platform: manifest.platform,
      schemaVersion: manifest.schemaVersion,
      createdAt: manifest.createdAt,
      deviceInfo: manifest.deviceInfo,
      checksum: 'sha256:$checksumHex',
      stats: manifest.stats,
      options: manifest.options,
    );

    // 5. Pack ZIP in isolate.
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final backupDir = await _backupDirectory();
    final outPath = p.join(backupDir.path, 'aetherlink_backup_$timestamp.zip');

    await Isolate.run(() {
      _packZip(
        outPath: outPath,
        manifestJson: manifestWithChecksum.toJsonString(),
        topicsJson: topicsJson,
        messagesJson: messagesJson,
        blocksJson: blocksJson,
        assistantsJson: assistantsJson,
        providersJson: providersJson,
        groupsJson: groupsJson,
        settingsJson: settingsJson,
      );
    });

    return File(outPath);
  }

  /// Restores data from a ZIP backup file.
  /// Returns a [RestoreResult] with success/skipped/failed counts.
  Future<RestoreResult> restoreFromFile(
    File zipFile, {
    RestoreMode mode = RestoreMode.overwrite,
  }) async {
    // 1. Extract ZIP.
    final extractDir = await _extractZip(zipFile);

    try {
      // 2. Read and verify manifest.
      final manifestFile = File(p.join(extractDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        throw const FormatException('Invalid backup: manifest.json not found');
      }
      final manifest = BackupManifest.fromJsonString(
        await manifestFile.readAsString(),
      );

      // 3. Verify checksum.
      final verified = await _verifyChecksum(extractDir, manifest.checksum);
      if (!verified) {
        throw const FormatException(
          'Backup integrity check failed: checksum mismatch',
        );
      }

      // 4. Safety net: auto-backup current data before restoring.
      await createAutoBackup(reason: 'pre_restore');

      // 5. Parse all JSON data.
      final backupData = await _parseExtractedData(extractDir, manifest);

      // 6. Write to database in a transaction.
      return await _writeData(backupData, mode, manifest.schemaVersion);
    } finally {
      // Cleanup extracted directory.
      try {
        await extractDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Creates an automatic backup (safety net). Used before restore/migration.
  Future<void> createAutoBackup({required String reason}) async {
    final file = await createBackup();
    // Rename to indicate it's auto-created.
    final dir = file.parent;
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final newName = 'auto_${reason}_$timestamp.zip';
    await file.rename(p.join(dir.path, newName));

    // Prune old auto-backups.
    await _pruneAutoBackups();
  }

  /// Lists all local backup files (manual + auto).
  Future<List<BackupFileItem>> listLocalBackups() async {
    final dir = await _backupDirectory();
    if (!await dir.exists()) return const [];

    final items = <BackupFileItem>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.zip')) {
        final stat = await entity.stat();
        final name = p.basename(entity.path);
        items.add(
          BackupFileItem(
            href: entity.uri,
            displayName: name,
            size: stat.size,
            lastModified: stat.modified,
            isAuto: name.startsWith('auto_'),
          ),
        );
      }
    }
    // Most recent first.
    items.sort(
      (a, b) => (b.lastModified ?? DateTime(0)).compareTo(
        a.lastModified ?? DateTime(0),
      ),
    );
    return items;
  }

  /// Deletes a local backup file.
  Future<void> deleteLocalBackup(String filename) async {
    final dir = await _backupDirectory();
    final file = File(p.join(dir.path, filename));
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Returns the manifest from a backup file without restoring.
  Future<BackupManifest> peekManifest(File zipFile) async {
    final extractDir = await _extractZip(zipFile);
    try {
      final manifestFile = File(p.join(extractDir.path, 'manifest.json'));
      if (!await manifestFile.exists()) {
        throw const FormatException('Invalid backup: manifest.json not found');
      }
      return BackupManifest.fromJsonString(await manifestFile.readAsString());
    } finally {
      try {
        await extractDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Internal: Data reading
  // ---------------------------------------------------------------------------

  Future<_RawBackupData> _readAllData({
    required bool includeMessages,
    required bool includeProviders,
    required bool includeSettings,
  }) async {
    return await db.transaction(() async {
      final topics = await db.topicDao.getAll();
      final topicsJson = topics.map((t) => t.toJson()).toList();

      List<Map<String, dynamic>> messagesJson = [];
      List<Map<String, dynamic>> blocksJson = [];
      if (includeMessages) {
        final messages = await db.messageDao.getAll();
        messagesJson = messages.map((m) => m.toJson()).toList();
        final blocks = await db.messageBlockDao.getAll();
        blocksJson = blocks.map((b) => b.toJson()).toList();
      }

      final assistants = await db.assistantDao.getAll();
      final assistantsJson = assistants.map((a) => a.toJson()).toList();

      List<Map<String, dynamic>> providersJson = [];
      if (includeProviders) {
        final providers = await db.providerDao.getAll();
        providersJson = providers.map((p) => p.toJson()).toList();
      }

      final groups = await db.groupDao.getAll();
      final groupsJson = groups.map((g) => g.toJson()).toList();

      List<Map<String, dynamic>> settingsJson = [];
      if (includeSettings) {
        // Read all settings from the key-value store.
        final rows = await db.select(db.appSettingRows).get();
        settingsJson = rows
            .map((r) => {'key': r.key, 'value': r.value})
            .toList();
      }

      return _RawBackupData(
        topics: topicsJson,
        messages: messagesJson,
        messageBlocks: blocksJson,
        assistants: assistantsJson,
        providers: providersJson,
        groups: groupsJson,
        settings: settingsJson,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Internal: ZIP packing (runs in Isolate)
  // ---------------------------------------------------------------------------

  static void _packZip({
    required String outPath,
    required String manifestJson,
    required String topicsJson,
    required String messagesJson,
    required String blocksJson,
    required String assistantsJson,
    required String providersJson,
    required String groupsJson,
    required String settingsJson,
  }) {
    final archive = Archive();

    void addJson(String name, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addJson('manifest.json', manifestJson);
    addJson('topics.json', topicsJson);
    addJson('messages.json', messagesJson);
    addJson('message_blocks.json', blocksJson);
    addJson('assistants.json', assistantsJson);
    addJson('providers.json', providersJson);
    addJson('groups.json', groupsJson);
    addJson('settings.json', settingsJson);

    final zipData = ZipEncoder().encode(archive);
    if (zipData != null) {
      File(outPath).writeAsBytesSync(zipData);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal: ZIP extraction
  // ---------------------------------------------------------------------------

  Future<Directory> _extractZip(File zipFile) async {
    final tmpDir = await getTemporaryDirectory();
    final extractPath = p.join(
      tmpDir.path,
      'aetherlink_restore_${DateTime.now().millisecondsSinceEpoch}',
    );
    final extractDir = Directory(extractPath);
    await extractDir.create(recursive: true);

    final bytes = await zipFile.readAsBytes();
    await Isolate.run(() {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final outPath = p.join(extractPath, file.name);
        if (file.isFile) {
          File(outPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(outPath).createSync(recursive: true);
        }
      }
    });

    return extractDir;
  }

  // ---------------------------------------------------------------------------
  // Internal: Checksum verification
  // ---------------------------------------------------------------------------

  Future<bool> _verifyChecksum(Directory dir, String expected) async {
    if (expected.isEmpty) return true; // Old backups without checksum pass.

    final dataFiles = [
      'topics.json',
      'messages.json',
      'message_blocks.json',
      'assistants.json',
      'providers.json',
      'groups.json',
      'settings.json',
    ];

    final buffer = StringBuffer();
    for (final name in dataFiles) {
      final file = File(p.join(dir.path, name));
      if (await file.exists()) {
        buffer.write(await file.readAsString());
      }
    }

    final actual = 'sha256:${sha256.convert(utf8.encode(buffer.toString()))}';
    return actual == expected;
  }

  // ---------------------------------------------------------------------------
  // Internal: Data parsing and writing
  // ---------------------------------------------------------------------------

  Future<_RawBackupData> _parseExtractedData(
    Directory dir,
    BackupManifest manifest,
  ) async {
    Future<List<Map<String, dynamic>>> readJsonList(String filename) async {
      final file = File(p.join(dir.path, filename));
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }

    return _RawBackupData(
      topics: await readJsonList('topics.json'),
      messages: await readJsonList('messages.json'),
      messageBlocks: await readJsonList('message_blocks.json'),
      assistants: await readJsonList('assistants.json'),
      providers: await readJsonList('providers.json'),
      groups: await readJsonList('groups.json'),
      settings: await readJsonList('settings.json'),
    );
  }

  Future<RestoreResult> _writeData(
    _RawBackupData data,
    RestoreMode mode,
    int sourceSchema,
  ) async {
    int succeeded = 0;
    int skipped = 0;
    int failed = 0;

    await db.transaction(() async {
      if (mode == RestoreMode.overwrite) {
        // Clear all tables.
        await db.delete(db.appSettingRows).go();
        await db.delete(db.messageBlockRows).go();
        await db.delete(db.messageRows).go();
        await db.delete(db.topicRows).go();
        await db.delete(db.assistantRows).go();
        await db.delete(db.providerRows).go();
        await db.delete(db.groupRows).go();
      }

      // Write topics.
      for (final json in data.topics) {
        final id = json['id'] as String? ?? '';
        if (id.isEmpty) {
          skipped++;
          continue;
        }
        if (mode == RestoreMode.merge) {
          final existing = await db.topicDao.getById(id);
          if (existing != null) {
            skipped++;
            continue;
          }
        }
        if (await _rawInsertTopic(json)) {
          succeeded++;
        } else {
          failed++;
        }
      }

      // Write messages.
      for (final json in data.messages) {
        final id = json['id'] as String? ?? '';
        if (id.isEmpty) {
          skipped++;
          continue;
        }
        if (mode == RestoreMode.merge) {
          final existing = await db.messageDao.getById(id);
          if (existing != null) {
            skipped++;
            continue;
          }
        }
        if (await _rawInsertMessage(json)) {
          succeeded++;
        } else {
          failed++;
        }
      }

      // Write message blocks.
      for (final json in data.messageBlocks) {
        final id = json['id'] as String? ?? '';
        if (id.isEmpty) {
          skipped++;
          continue;
        }
        if (mode == RestoreMode.merge) {
          final existing = await db.messageBlockDao.getById(id);
          if (existing != null) {
            skipped++;
            continue;
          }
        }
        if (await _rawInsertMessageBlock(json)) {
          succeeded++;
        } else {
          failed++;
        }
      }

      // Write assistants.
      for (final json in data.assistants) {
        final id = json['id'] as String? ?? '';
        if (id.isEmpty) {
          skipped++;
          continue;
        }
        if (mode == RestoreMode.merge) {
          final existing = await db.assistantDao.getById(id);
          if (existing != null) {
            skipped++;
            continue;
          }
        }
        if (await _rawInsertAssistant(json)) {
          succeeded++;
        } else {
          failed++;
        }
      }

      // Write providers.
      for (final json in data.providers) {
        final id = json['id'] as String? ?? '';
        if (id.isEmpty) {
          skipped++;
          continue;
        }
        if (mode == RestoreMode.merge) {
          final existing = await db.providerDao.getById(id);
          if (existing != null) {
            skipped++;
            continue;
          }
        }
        if (await _rawInsertProvider(json)) {
          succeeded++;
        } else {
          failed++;
        }
      }

      // Write groups.
      for (final json in data.groups) {
        final id = json['id'] as String? ?? '';
        if (id.isEmpty) {
          skipped++;
          continue;
        }
        if (mode == RestoreMode.merge) {
          final existing = await db.groupDao.getById(id);
          if (existing != null) {
            skipped++;
            continue;
          }
        }
        if (await _rawInsertGroup(json)) {
          succeeded++;
        } else {
          failed++;
        }
      }

      // Write settings.
      for (final json in data.settings) {
        final key = json['key'] as String? ?? '';
        if (key.isEmpty) {
          skipped++;
          continue;
        }
        if (mode == RestoreMode.merge) {
          final existing = await db.appSettingDao.getValue(key);
          if (existing != null) {
            skipped++;
            continue;
          }
        }
        final value = json['value'] as String? ?? '';
        try {
          await db.appSettingDao.setValue(key, value);
          succeeded++;
        } catch (_) {
          failed++;
        }
      }
    });

    return RestoreResult(
      succeeded: succeeded,
      skipped: skipped,
      failed: failed,
    );
  }

  // Raw insert helpers. Returns true on success, false on failure.
  Future<bool> _rawInsertTopic(Map<String, dynamic> json) async {
    try {
      final topic = Topic.fromJson(json);
      await db.topicDao.upsert(topic);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _rawInsertMessage(Map<String, dynamic> json) async {
    try {
      final message = Message.fromJson(json);
      await db.messageDao.upsert(message);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _rawInsertMessageBlock(Map<String, dynamic> json) async {
    try {
      final block = MessageBlock.fromJson(json);
      await db.messageBlockDao.upsert(block);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _rawInsertAssistant(Map<String, dynamic> json) async {
    try {
      final assistant = Assistant.fromJson(json);
      await db.assistantDao.upsert(assistant);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _rawInsertProvider(Map<String, dynamic> json) async {
    try {
      final provider = ModelProvider.fromJson(json);
      await db.providerDao.upsert(provider);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _rawInsertGroup(Map<String, dynamic> json) async {
    try {
      final group = Group.fromJson(json);
      await db.groupDao.upsert(group);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal: Utilities
  // ---------------------------------------------------------------------------

  Future<Directory> _backupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(appDir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<void> _pruneAutoBackups() async {
    final dir = await _backupDirectory();
    final autoFiles = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File && p.basename(entity.path).startsWith('auto_')) {
        autoFiles.add(entity);
      }
    }
    if (autoFiles.length <= _maxAutoBackups) return;

    // Sort oldest first.
    autoFiles.sort((a, b) {
      final aStat = a.statSync();
      final bStat = b.statSync();
      return aStat.modified.compareTo(bStat.modified);
    });

    // Delete oldest until we're at the limit.
    final toDelete = autoFiles.length - _maxAutoBackups;
    for (var i = 0; i < toDelete; i++) {
      try {
        await autoFiles[i].delete();
      } catch (_) {}
    }
  }

  Future<String> _deviceInfo() async {
    // Best-effort device info. Returns empty string on failure.
    try {
      if (Platform.isAndroid) {
        return 'Android';
      } else if (Platform.isIOS) {
        return 'iOS';
      }
      return Platform.operatingSystem;
    } catch (_) {
      return '';
    }
  }
}

/// Result of a restore operation with record-level statistics.
class RestoreResult {
  final int succeeded;
  final int skipped;
  final int failed;

  const RestoreResult({this.succeeded = 0, this.skipped = 0, this.failed = 0});

  int get total => succeeded + skipped + failed;

  String get summary {
    final parts = <String>[];
    if (succeeded > 0) parts.add('成功 $succeeded');
    if (skipped > 0) parts.add('跳过 $skipped');
    if (failed > 0) parts.add('失败 $failed');
    return parts.join('，');
  }
}

// Private data container for raw JSON maps.
class _RawBackupData {
  final List<Map<String, dynamic>> topics;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> messageBlocks;
  final List<Map<String, dynamic>> assistants;
  final List<Map<String, dynamic>> providers;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> settings;

  const _RawBackupData({
    required this.topics,
    required this.messages,
    required this.messageBlocks,
    required this.assistants,
    required this.providers,
    required this.groups,
    required this.settings,
  });
}
