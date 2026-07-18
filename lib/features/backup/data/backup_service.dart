import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_file_item.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_manifest.dart';
import 'package:aetherlink_flutter/features/backup/domain/restore_plan.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_base.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_chunking.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_scope.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';
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

  /// KV setting keys excluded from backup export. SSH credentials are stored
  /// plaintext (设计文档 §5.2), so they must never leave the device through a
  /// backup/export (the one real leak surface of the plaintext approach). The
  /// literal mirrors `kSshCredentialsKey` in the workspace feature — duplicated
  /// here on purpose because the cross-feature import-boundary rule forbids
  /// backup from importing workspace's `application`.
  static const Set<String> _excludedSettingKeys = {
    'workspace_ssh_credentials',
  };

  /// How many records to write between progress emits / event-loop yields when
  /// restoring a category. Keeps the UI responsive and bounds work per tick on
  /// large backups (the "流式" part of the import).
  static const int _restoreBatchSize = 100;

  /// Web backup top-level keys Flutter has no table for, mapped to a display
  /// name. Surfaced in the scan as [UnsupportedCategory] so the user knows
  /// what a restore will drop instead of silently losing it.
  static const Map<String, String> _unsupportedWebKeys = {
    'knowledgeBases': '知识库',
    'knowledge': '知识库',
    'quickPhrases': '快捷短语',
    'files': '文件',
    'images': '生成的图片',
    'generatedImages': '生成的图片',
    'agents': '智能体',
    'skills': '技能',
    'documents': '文档',
  };

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
        knowledge: data.knowledge.length,
      ),
      options: BackupOptions(
        includeMessages: includeMessages,
        includeProviders: includeProviders,
        includeSettings: includeSettings,
      ),
    );

    // 3. Pick the output path (cheap, stays on the UI isolate).
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final backupDir = await _backupDirectory();
    final outPath = p.join(backupDir.path, 'aetherlink_backup_$timestamp.zip');

    // 4. Serialize JSON, compute the checksum and pack the ZIP — all inside one
    // isolate so a large database never blocks the UI on jsonEncode / sha256.
    // `data` is plain Map/List and `manifest` is a plain value, so both copy
    // across the isolate boundary safely.
    await Isolate.run(() {
      final topicsJson = jsonEncode(data.topics);
      final messagesJson = jsonEncode(data.messages);
      final blocksJson = jsonEncode(data.messageBlocks);
      final assistantsJson = jsonEncode(data.assistants);
      final providersJson = jsonEncode(data.providers);
      final groupsJson = jsonEncode(data.groups);
      final settingsJson = jsonEncode(data.settings);
      final knowledgeJson = jsonEncode(data.knowledge);

      final allBytes = utf8.encode(
        '$topicsJson$messagesJson$blocksJson$assistantsJson$providersJson$groupsJson$settingsJson$knowledgeJson',
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
        knowledgeJson: knowledgeJson,
      );
    });

    return File(outPath);
  }

  /// Restores data from a backup file (ZIP or Web JSON format).
  ///
  /// When [selection] is provided, only the chosen [BackupCategory] values are
  /// imported (and, in overwrite mode, only those tables are cleared); a null
  /// selection imports everything. [onProgress] streams per-category progress
  /// for the UI. Returns a [RestoreResult] carrying per-category reconciliation
  /// stats (`byCategory`) alongside the aggregate counts.
  Future<RestoreResult> restoreFromFile(
    File file, {
    RestoreMode mode = RestoreMode.overwrite,
    RestoreSelection? selection,
    void Function(RestoreProgress)? onProgress,
  }) async {
    final ext = p.extension(file.path).toLowerCase();

    // Detect Web JSON backup format.
    if (ext == '.json') {
      return _restoreFromWebJson(
        file,
        mode,
        selection: selection,
        onProgress: onProgress,
      );
    }

    // Default: ZIP backup.
    return _restoreFromZip(
      file,
      mode,
      selection: selection,
      onProgress: onProgress,
    );
  }

  /// Scans a backup file without importing it, returning the per-category
  /// importable counts and any unsupported categories. Drives the pre-restore
  /// selection checklist.
  Future<BackupScan> scanBackup(File file) async {
    final ext = p.extension(file.path).toLowerCase();
    if (ext == '.json') return _scanWebJson(file);
    return _scanZip(file);
  }

  /// Restores from a Flutter ZIP backup.
  Future<RestoreResult> _restoreFromZip(
    File zipFile,
    RestoreMode mode, {
    RestoreSelection? selection,
    void Function(RestoreProgress)? onProgress,
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
      return await _writeData(
        backupData,
        mode,
        manifest.schemaVersion,
        selection: selection,
        onProgress: onProgress,
      );
    } finally {
      // Cleanup extracted directory.
      try {
        await extractDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Restores from a Web-created JSON backup.
  ///
  /// Web backup structure:
  /// ```json
  /// {
  ///   "topics": [ { ..., "messages": [ { ..., "blocks": [...] } ] } ],
  ///   "assistants": [...],
  ///   "settings": { ... },
  ///   "localStorage": { ... },
  ///   "appInfo": { "version": "...", "name": "AetherLink", "backupVersion": N },
  ///   "timestamp": 123456
  /// }
  /// ```
  ///
  /// The key difference from Flutter's ZIP format: messages and blocks are
  /// nested inside topics instead of stored in flat separate files.
  Future<RestoreResult> _restoreFromWebJson(
    File jsonFile,
    RestoreMode mode, {
    RestoreSelection? selection,
    void Function(RestoreProgress)? onProgress,
  }) async {
    final content = await jsonFile.readAsString();
    final _RawBackupData flatData;
    try {
      // Decode + validate + flatten inside a single isolate: the raw string and
      // the (far larger) decoded JSON tree never live on the UI isolate, and
      // only the flattened result — exactly what _writeData consumes — crosses
      // back. This roughly halves peak memory versus decoding the tree on / and
      // copying it to the UI isolate, which is what OOM-crashed large imports.
      flatData = await Isolate.run<_RawBackupData>(
        () => _decodeAndFlattenWebJson(content),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('无法解析 JSON 备份文件');
    }

    // Safety net.
    await createAutoBackup(reason: 'pre_restore');

    // Write to database.
    return await _writeData(
      flatData,
      mode,
      db.schemaVersion,
      selection: selection,
      onProgress: onProgress,
    );
  }

  /// Scans a Flutter ZIP backup, deriving per-category counts from its
  /// manifest (no full extraction of data files needed).
  Future<BackupScan> _scanZip(File file) async {
    final manifest = await peekManifest(file);
    final s = manifest.stats;
    return BackupScan(
      isWebFormat: false,
      manifest: manifest,
      available: {
        BackupCategory.topics: s.topics,
        BackupCategory.messages: s.messages,
        BackupCategory.messageBlocks: s.messageBlocks,
        BackupCategory.assistants: s.assistants,
        BackupCategory.providers: s.providers,
        BackupCategory.groups: s.groups,
        BackupCategory.settings: s.settings,
        BackupCategory.knowledge: s.knowledge,
      },
    );
  }

  /// Scans a Web JSON backup. Reuses [_flattenWebBackup] so the reported counts
  /// match exactly what a restore would import, then collects the categories
  /// Flutter has no table for.
  Future<BackupScan> _scanWebJson(File file) async {
    final content = await file.readAsString();
    try {
      // Decode + flatten + tally entirely inside one isolate so neither the raw
      // string nor the decoded/flattened trees ever live on the UI isolate;
      // only the compact BackupScan crosses back. Previously the scan decoded
      // the whole tree twice (once here, once again on the UI isolate inside
      // _peekWebJsonManifest), which OOM-crashed large (~20MB) backups on
      // lower-memory devices.
      return await Isolate.run<BackupScan>(() => _buildWebScan(content));
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('无法解析 JSON 备份文件');
    }
  }

  /// Decodes, validates and flattens raw Web JSON [content] into the flat
  /// backup structure. Runs inside an isolate (see [_restoreFromWebJson]);
  /// references only static helpers so it captures no instance state. Throws a
  /// [FormatException] with a user-facing message on invalid input.
  static _RawBackupData _decodeAndFlattenWebJson(String content) {
    final Map<String, dynamic> root;
    try {
      root = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('无法解析 JSON 备份文件');
    }
    // Validate: must have topics or assistants or appInfo or modelConfig.
    final hasTopics = root['topics'] is List;
    final hasAssistants = root['assistants'] is List;
    final hasAppInfo = root['appInfo'] is Map;
    final hasModelConfig = root['modelConfig'] is Map;
    final hasUserSettings = root['userSettings'] is Map;
    if (!hasTopics && !hasAssistants && !hasAppInfo && !hasModelConfig &&
        !hasUserSettings) {
      throw const FormatException('不是有效的 AetherLink Web 备份文件');
    }
    return _flattenWebBackup(root);
  }

  /// Builds a [BackupScan] from raw Web JSON [content]. Runs inside an isolate
  /// (see [_scanWebJson]); references only static helpers so it captures no
  /// instance state.
  static BackupScan _buildWebScan(String content) {
    final root = jsonDecode(content) as Map<String, dynamic>;
    final flat = _flattenWebBackup(root);
    final importableMemories = flat.memories
        .where((m) =>
            m['isDeleted'] != true && (m['id'] ?? '').toString().isNotEmpty)
        .length;

    return BackupScan(
      isWebFormat: true,
      manifest: _webManifestFromRoot(root),
      available: {
        BackupCategory.topics: flat.topics.length,
        BackupCategory.messages: flat.messages.length,
        BackupCategory.messageBlocks: flat.messageBlocks.length,
        BackupCategory.assistants: flat.assistants.length,
        BackupCategory.providers: flat.providers.length,
        BackupCategory.groups: flat.groups.length,
        BackupCategory.settings: flat.settings.length,
        BackupCategory.memories: importableMemories,
      },
      unsupported: _collectUnsupported(root),
    );
  }

  /// Collects Web backup sections Flutter cannot import (see
  /// [_unsupportedWebKeys]) so the scan can show them greyed out.
  static List<UnsupportedCategory> _collectUnsupported(
    Map<String, dynamic> root,
  ) {
    final result = <UnsupportedCategory>[];
    final seen = <String>{};
    for (final entry in _unsupportedWebKeys.entries) {
      final value = root[entry.key];
      final count = value is List ? value.length : (value is Map ? value.length : 0);
      if (count <= 0 || seen.contains(entry.value)) continue;
      seen.add(entry.value);
      result.add(UnsupportedCategory(
        name: entry.value,
        count: count,
        reason: 'Flutter 暂无对应存储，导入时会忽略',
      ));
    }
    return result;
  }

  /// Flattens a Web backup's nested JSON into the same flat structure
  /// used by Flutter's ZIP backup.
  static _RawBackupData _flattenWebBackup(Map<String, dynamic> root) {
    final topicsJson = <Map<String, dynamic>>[];
    final messagesJson = <Map<String, dynamic>>[];
    final blocksJson = <Map<String, dynamic>>[];
    final assistantsJson = <Map<String, dynamic>>[];
    final settingsJson = <Map<String, dynamic>>[];

    // --- Topics + Messages + Blocks ---
    final rawTopics = root['topics'] as List<dynamic>? ?? [];
    for (final rawTopic in rawTopics) {
      if (rawTopic is! Map<String, dynamic>) continue;
      final topicId = (rawTopic['id'] ?? '').toString();
      if (topicId.isEmpty) continue;

      // Extract nested messages before stripping them from the topic.
      final rawMessages = rawTopic['messages'] as List<dynamic>? ?? [];
      final messageIds = <String>[];

      for (final rawMsg in rawMessages) {
        if (rawMsg is! Map<String, dynamic>) continue;
        final msgId = (rawMsg['id'] ?? '').toString();
        if (msgId.isEmpty) continue;

        messageIds.add(msgId);

        // Extract nested blocks from the message.
        final rawBlocks = rawMsg['blocks'];
        final blockIds = <String>[];

        if (rawBlocks is List) {
          for (final rawBlock in rawBlocks) {
            if (rawBlock is Map<String, dynamic>) {
              // Full block object — flatten it.
              final blockId = (rawBlock['id'] ?? '').toString();
              if (blockId.isEmpty) continue;

              // Ensure messageId is set on the block.
              final blockJson = Map<String, dynamic>.from(rawBlock);
              blockJson['messageId'] = msgId;

              // Normalize status.
              blockJson['status'] =
                  _normalizeStatus(blockJson['status']?.toString());

              // Ensure createdAt is present.
              blockJson['createdAt'] ??=
                  rawMsg['createdAt'] ?? DateTime.now().toIso8601String();

              blocksJson.add(blockJson);
              blockIds.add(blockId);
            } else if (rawBlock is String) {
              // Block is just an ID reference (shouldn't happen in Web
              // backup, but handle gracefully).
              blockIds.add(rawBlock);
            }
          }
        }

        // Build flat message (blocks = list of IDs only).
        final msgJson = Map<String, dynamic>.from(rawMsg);
        msgJson.remove('messages'); // remove any nested messages (shouldn't exist but be safe)
        msgJson['blocks'] = blockIds;
        msgJson['topicId'] = topicId;

        // Normalize role.
        msgJson['role'] ??= 'user';

        // Normalize status.
        msgJson['status'] = _normalizeStatus(msgJson['status']?.toString());

        // Ensure createdAt is present.
        msgJson['createdAt'] ??= DateTime.now().toIso8601String();

        // Ensure assistantId is present.
        msgJson['assistantId'] ??=
            rawTopic['assistantId'] ?? 'default';

        // Handle versions — flatten block objects inside versions.
        if (msgJson['versions'] is List) {
          final versions = (msgJson['versions'] as List).map((v) {
            if (v is! Map<String, dynamic>) return v;
            final vJson = Map<String, dynamic>.from(v);
            // Version blocks may be full objects or just IDs.
            if (vJson['blocks'] is List) {
              final vBlockIds = <String>[];
              for (final vb in vJson['blocks'] as List) {
                if (vb is Map<String, dynamic>) {
                  final vbId = (vb['id'] ?? '').toString();
                  if (vbId.isNotEmpty) {
                    final vbJson = Map<String, dynamic>.from(vb);
                    vbJson['messageId'] = msgId;
                    vbJson['status'] =
                        _normalizeStatus(vbJson['status']?.toString());
                    vbJson['createdAt'] ??= DateTime.now().toIso8601String();
                    blocksJson.add(vbJson);
                    vBlockIds.add(vbId);
                  }
                } else if (vb is String) {
                  vBlockIds.add(vb);
                }
              }
              vJson['blocks'] = vBlockIds;
            }
            return vJson;
          }).toList();
          msgJson['versions'] = versions;
        }

        messagesJson.add(msgJson);
      }

      // Build flat topic (messageIds = list of IDs, no nested messages).
      final topicJson = Map<String, dynamic>.from(rawTopic);
      topicJson.remove('messages');
      topicJson['messageIds'] = messageIds;

      // Map Web's 'name'/'title' to Flutter's 'name'.
      topicJson['name'] ??= topicJson['title'] ?? '未命名对话';
      topicJson.remove('title');

      // Ensure required fields.
      topicJson['assistantId'] ??= 'default';
      topicJson['createdAt'] ??= DateTime.now().toIso8601String();
      topicJson['updatedAt'] ??= topicJson['createdAt'];

      topicsJson.add(topicJson);
    }

    // --- Assistants ---
    final rawAssistants = root['assistants'] as List<dynamic>? ?? [];
    for (final rawAst in rawAssistants) {
      if (rawAst is! Map<String, dynamic>) continue;
      final astId = (rawAst['id'] ?? '').toString();
      if (astId.isEmpty) continue;

      final astJson = Map<String, dynamic>.from(rawAst);
      // Drop Web-only fields that don't exist in Flutter model.
      astJson.remove('icon'); // ReactNode, not serializable
      astJson.remove('topics'); // Runtime-only in Web

      assistantsJson.add(astJson);
    }

    // --- Providers ---
    // Full backup: providers live inside settings.providers
    // Selective backup: providers live inside modelConfig.providers
    final providersJson = <Map<String, dynamic>>[];

    final rawSettings = root['settings'];
    final rawModelConfig = root['modelConfig'];

    // Extract providers from full backup (settings.providers)
    if (rawSettings is Map<String, dynamic>) {
      final settingsProviders = rawSettings['providers'] as List<dynamic>?;
      if (settingsProviders != null) {
        for (final p in settingsProviders) {
          if (p is Map<String, dynamic>) {
            providersJson.add(_normalizeWebProvider(p));
          }
        }
      }
    }

    // Extract providers from selective backup (modelConfig.providers)
    // Only if we didn't already get them from settings
    if (providersJson.isEmpty && rawModelConfig is Map<String, dynamic>) {
      final mcProviders = rawModelConfig['providers'] as List<dynamic>?;
      if (mcProviders != null) {
        for (final p in mcProviders) {
          if (p is Map<String, dynamic>) {
            providersJson.add(_normalizeWebProvider(p));
          }
        }
      }
    }

    // Merge the top-level models registry (full: settings.models, selective:
    // modelConfig.models) into the matching providers — Flutter stores models
    // only nested under their provider.
    List<dynamic>? rawModels;
    if (rawSettings is Map<String, dynamic> && rawSettings['models'] is List) {
      rawModels = rawSettings['models'] as List<dynamic>;
    } else if (rawModelConfig is Map<String, dynamic> &&
        rawModelConfig['models'] is List) {
      rawModels = rawModelConfig['models'] as List<dynamic>;
    }
    if (rawModels != null && rawModels.isNotEmpty) {
      _mergeTopLevelModels(providersJson, rawModels);
    }

    // --- Settings / localStorage → KV pairs ---
    // Web stores settings as a JSON object + localStorage object.
    // Flutter stores them in app_setting_rows (key-value table).
    if (rawSettings is Map<String, dynamic>) {
      // Store the whole settings object as a single KV entry for reference.
      settingsJson.add({
        'key': 'web_settings',
        'value': jsonEncode(rawSettings),
      });
      // Also extract individual user settings as dedicated KV pairs
      // so the Flutter app can actually read them.
      _extractUserSettings(rawSettings, settingsJson);
    }

    // Handle selective backup's userSettings field
    final rawUserSettings = root['userSettings'];
    if (rawUserSettings is Map<String, dynamic>) {
      _extractUserSettings(rawUserSettings, settingsJson);
    }

    final rawLocalStorage = root['localStorage'];
    if (rawLocalStorage is Map<String, dynamic>) {
      for (final entry in rawLocalStorage.entries) {
        final key = entry.key;
        final value = entry.value;
        settingsJson.add({
          'key': key,
          'value': value is String ? value : jsonEncode(value),
        });
      }
    }

    // --- sidebarSettings (compound JSON blob) ---
    // The web sidebar 设置 tab fields are spread across the redux `settings`
    // slice (full backup), the `userSettings` blob (selective backup) and the
    // localStorage `appSettings` object. Merge them (lower priority first) and
    // map onto Flutter's `SidebarSettings`, the only place these settings are
    // actually read.
    final sidebarSource = <String, dynamic>{};
    void mergeSidebarSource(dynamic src) {
      if (src is Map<String, dynamic>) sidebarSource.addAll(src);
    }

    mergeSidebarSource(rawSettings);
    if (rawLocalStorage is Map<String, dynamic>) {
      final appSettings = rawLocalStorage['appSettings'];
      if (appSettings is String) {
        try {
          mergeSidebarSource(jsonDecode(appSettings));
        } catch (_) {
          // Ignore malformed appSettings; the rest of the restore continues.
        }
      } else {
        mergeSidebarSource(appSettings);
      }
    }
    mergeSidebarSource(rawUserSettings);

    final sidebarJson = _mapSidebarSettings(sidebarSource);
    if (sidebarJson.isNotEmpty) {
      settingsJson.add({
        'key': 'sidebarSettings',
        'value': jsonEncode(sidebarJson),
      });
    }

    // --- Memories (Web `memories` table → Flutter MemoryRows) ---
    final memoriesJson = <Map<String, dynamic>>[];
    final rawMemories = root['memories'];
    if (rawMemories is List) {
      for (final m in rawMemories) {
        if (m is Map<String, dynamic>) memoriesJson.add(m);
      }
    }

    return _RawBackupData(
      topics: topicsJson,
      messages: messagesJson,
      messageBlocks: blocksJson,
      assistants: assistantsJson,
      providers: providersJson,
      groups: const [],
      settings: settingsJson,
      memories: memoriesJson,
    );
  }

  /// Accepted ModelType enum wire values (see `shared/domain/model_type.dart`).
  static const _knownModelTypes = <String>{
    'chat', 'vision', 'audio', 'embedding', 'tool', 'reasoning',
    'image_gen', 'video_gen', 'function_calling', 'web_search',
    'rerank', 'code_gen', 'translation', 'transcription',
  };

  /// Accepted TopToolbarComponent enum names (see
  /// `shared/domain/top_toolbar_settings.dart`).
  static const _knownToolbarComponents = <String>{
    'menuButton', 'topicName', 'newTopicButton', 'clearButton',
    'searchButton', 'modelSelector', 'settingsButton',
    'condenseButton', 'miniMapButton',
  };

  /// Normalizes a Web ModelProvider JSON to match Flutter's ModelProvider shape.
  ///
  /// `ModelProvider.fromJson` requires `id`, `name`, `avatar`, `color` and
  /// each nested `Model.fromJson` requires `id`, `name`, `provider`. If any
  /// model is missing these the ENTIRE provider deserialization throws, so we
  /// filter invalid models and fill defaults for the provider itself.
  static Map<String, dynamic> _normalizeWebProvider(Map<String, dynamic> p) {
    final json = Map<String, dynamic>.from(p);

    // Ensure required provider fields (all required String in ModelProvider).
    json['id'] ??= '';
    json['name'] ??= (json['id'] ?? '').toString().isNotEmpty
        ? json['id']
        : 'Unknown';
    json['avatar'] ??= (json['name'] ?? 'P').toString().isNotEmpty
        ? (json['name'] ?? 'P').toString().substring(0, 1).toUpperCase()
        : 'P';
    json['color'] ??= '#10a37f';
    json['isEnabled'] ??= false;

    // Ensure models is a List (not null).
    if (json['models'] is! List) {
      json['models'] = <dynamic>[];
    }

    // Normalize each model, filtering out entries that would crash fromJson.
    final models = <Map<String, dynamic>>[];
    for (final m in json['models'] as List) {
      final modelJson = _normalizeWebModel(m, json['id']);
      if (modelJson != null) models.add(modelJson);
    }
    json['models'] = models;

    // Strip web-only provider fields that don't exist in Flutter.
    json.remove('useCorsPlugin');
    json.remove('customModelEndpoint');

    return json;
  }

  /// Normalizes a single Web Model JSON to match Flutter's Model shape.
  ///
  /// `Model.fromJson` requires `id`, `name`, `provider`; returns null for
  /// entries that would crash deserialization (missing id).
  static Map<String, dynamic>? _normalizeWebModel(
    dynamic m,
    Object? providerId,
  ) {
    if (m is! Map<String, dynamic>) return null;
    final modelJson = Map<String, dynamic>.from(m);

    // id is required — skip models without one.
    final modelId = modelJson['id'];
    if (modelId == null || modelId.toString().isEmpty) return null;

    // name defaults to id if missing.
    modelJson['name'] ??= modelId.toString();

    // provider defaults to the owning provider's id.
    modelJson['provider'] ??= providerId;

    // Filter modelTypes to known enum values to prevent fromJson crash.
    // ModelType enum only accepts specific string values; unknown values
    // would cause the entire Model.fromJson to throw.
    if (modelJson['modelTypes'] is List) {
      modelJson['modelTypes'] = (modelJson['modelTypes'] as List)
          .where((t) => _knownModelTypes.contains(t))
          .toList();
    }

    // Strip web-only model fields.
    modelJson.remove('useCorsPlugin');

    return modelJson;
  }

  /// Merges Web's top-level `models` registry into [providersJson].
  ///
  /// Web keeps a flat `settings.models` / `modelConfig.models` list alongside
  /// each provider's embedded `models`. Flutter stores models only nested under
  /// their provider, so models that live solely in the flat list are otherwise
  /// lost. Each model is appended to the provider matching its `provider` field
  /// (deduplicated by id); models whose provider is absent are grouped into a
  /// new minimal provider so nothing is dropped.
  static void _mergeTopLevelModels(
    List<Map<String, dynamic>> providersJson,
    List<dynamic> rawModels,
  ) {
    final providersById = <String, Map<String, dynamic>>{};
    for (final p in providersJson) {
      final id = p['id']?.toString() ?? '';
      if (id.isNotEmpty) providersById[id] = p;
    }

    for (final m in rawModels) {
      if (m is! Map<String, dynamic>) continue;
      final providerId = (m['provider'] ?? '').toString();
      final model = _normalizeWebModel(m, providerId);
      if (model == null) continue;
      final modelId = model['id'].toString();

      var provider = providersById[providerId];
      if (provider == null) {
        // Orphan model — synthesize a minimal provider to hold it.
        provider = _normalizeWebProvider({
          'id': providerId,
          'models': <dynamic>[],
        });
        providersById[providerId] = provider;
        providersJson.add(provider);
      }

      final existing = (provider['models'] as List).cast<Map<String, dynamic>>();
      final alreadyPresent = existing.any(
        (e) => e['id']?.toString() == modelId,
      );
      if (!alreadyPresent) existing.add(model);
    }
  }

  /// Extracts user settings from a Web settings/userSettings map and composes
  /// them into the compound JSON blob keys that Flutter's settings controllers
  /// actually read.
  ///
  /// Flutter stores settings as compound JSON objects under specific keys
  /// (e.g. `behaviorSettings`, `messageBubbleSettings`) — NOT as individual
  /// scalar keys like the web does. This method maps web fields into the
  /// correct Flutter compound structures.
  static void _extractUserSettings(
    Map<String, dynamic> settings,
    List<Map<String, dynamic>> settingsJson,
  ) {
    // --- Direct scalar keys (Flutter reads these individually) ---
    _addScalar(settingsJson, 'theme', settings['theme']);
    _addScalar(settingsJson, 'fontSize', settings['fontSize']);
    _addScalar(settingsJson, 'defaultModelId', settings['defaultModelId']);
    _addScalar(settingsJson, 'currentModelId', settings['currentModelId']);
    _addScalar(settingsJson, 'inputBoxStyle', settings['inputBoxStyle']);

    // Input box button layout (stored as JSON arrays of button ids)
    final leftButtons = settings['integratedInputLeftButtons'];
    if (leftButtons is List) {
      settingsJson.add({
        'key': 'integratedInputLeftButtons',
        'value': jsonEncode(leftButtons),
      });
    }
    final rightButtons = settings['integratedInputRightButtons'];
    if (rightButtons is List) {
      settingsJson.add({
        'key': 'integratedInputRightButtons',
        'value': jsonEncode(rightButtons),
      });
    }

    // --- behaviorSettings (compound JSON blob) ---
    final behaviorJson = <String, dynamic>{};
    if (settings['sendWithEnter'] != null) {
      behaviorJson['sendWithEnter'] = settings['sendWithEnter'];
    }
    if (settings['enableNotifications'] != null) {
      behaviorJson['enableNotifications'] = settings['enableNotifications'];
    }
    if (settings['mobileInputMethodEnterAsNewline'] != null) {
      behaviorJson['mobileInputMethodEnterAsNewline'] =
          settings['mobileInputMethodEnterAsNewline'];
    }
    if (settings['hapticFeedback'] is Map) {
      behaviorJson['hapticFeedback'] = settings['hapticFeedback'];
    }
    if (behaviorJson.isNotEmpty) {
      settingsJson.add({
        'key': 'behaviorSettings',
        'value': jsonEncode(behaviorJson),
      });
    }

    // --- messageBubbleSettings (compound JSON blob) ---
    final bubbleJson = <String, dynamic>{};
    if (settings['messageActionMode'] != null) {
      bubbleJson['messageActionMode'] = settings['messageActionMode'];
    }
    if (settings['showMicroBubbles'] != null) {
      bubbleJson['showMicroBubbles'] = settings['showMicroBubbles'];
    }
    if (settings['showTTSButton'] != null) {
      bubbleJson['showTTSButton'] = settings['showTTSButton'];
    }
    if (settings['versionSwitchStyle'] != null) {
      bubbleJson['versionSwitchStyle'] = settings['versionSwitchStyle'];
    }
    if (settings['messageBubbleMaxWidth'] != null) {
      bubbleJson['messageBubbleMaxWidth'] = settings['messageBubbleMaxWidth'];
    }
    if (settings['userMessageMaxWidth'] != null) {
      bubbleJson['userMessageMaxWidth'] = settings['userMessageMaxWidth'];
    }
    if (settings['messageBubbleMinWidth'] != null) {
      bubbleJson['messageBubbleMinWidth'] = settings['messageBubbleMinWidth'];
    }
    if (settings['showUserAvatar'] != null) {
      bubbleJson['showUserAvatar'] = settings['showUserAvatar'];
    }
    if (settings['showUserName'] != null) {
      bubbleJson['showUserName'] = settings['showUserName'];
    }
    if (settings['showModelAvatar'] != null) {
      bubbleJson['showModelAvatar'] = settings['showModelAvatar'];
    }
    if (settings['showModelName'] != null) {
      bubbleJson['showModelName'] = settings['showModelName'];
    }
    if (settings['hideUserBubble'] != null) {
      bubbleJson['hideUserBubble'] = settings['hideUserBubble'];
    }
    if (settings['hideAIBubble'] != null) {
      bubbleJson['hideAIBubble'] = settings['hideAIBubble'];
    }
    if (settings['customBubbleColors'] is Map) {
      bubbleJson['customBubbleColors'] = settings['customBubbleColors'];
    }
    if (bubbleJson.isNotEmpty) {
      settingsJson.add({
        'key': 'messageBubbleSettings',
        'value': jsonEncode(bubbleJson),
      });
    }

    // --- thinkingSettings (compound JSON blob) ---
    final thinkingJson = <String, dynamic>{};
    if (settings['thinkingDisplayStyle'] != null) {
      // Web key is 'thinkingDisplayStyle', Flutter field is 'displayStyle'
      thinkingJson['displayStyle'] = settings['thinkingDisplayStyle'];
    }
    if (settings['thoughtAutoCollapse'] != null) {
      thinkingJson['thoughtAutoCollapse'] = settings['thoughtAutoCollapse'];
    }
    if (settings['thinkingToolInline'] != null) {
      thinkingJson['thinkingToolInline'] = settings['thinkingToolInline'];
    }
    if (thinkingJson.isNotEmpty) {
      settingsJson.add({
        'key': 'thinkingSettings',
        'value': jsonEncode(thinkingJson),
      });
    }

    // --- chatInterfaceSettings (compound JSON blob) ---
    final chatIfJson = <String, dynamic>{};
    if (settings['multiModelDisplayStyle'] != null) {
      chatIfJson['multiModelDisplayStyle'] =
          settings['multiModelDisplayStyle'];
    }
    if (settings['showToolDetails'] != null) {
      chatIfJson['showToolDetails'] = settings['showToolDetails'];
    }
    if (settings['showCitationDetails'] != null) {
      chatIfJson['showCitationDetails'] = settings['showCitationDetails'];
    }
    if (settings['showSystemPromptBubble'] != null) {
      chatIfJson['showSystemPromptBubble'] =
          settings['showSystemPromptBubble'];
    }
    if (settings['chatBackground'] is Map) {
      chatIfJson['background'] = settings['chatBackground'];
    }
    if (chatIfJson.isNotEmpty) {
      settingsJson.add({
        'key': 'chatInterfaceSettings',
        'value': jsonEncode(chatIfJson),
      });
    }

    // --- topToolbarSettings (compound JSON blob) ---
    final webToolbar = settings['topToolbar'];
    if (webToolbar is Map<String, dynamic>) {
      final toolbarJson = <String, dynamic>{};
      // Map componentPositions → positions (Flutter field name).
      // Filter to known components only — TopToolbarComponent is a required
      // enum field, so unknown ids would crash fromJson.
      final positions = webToolbar['componentPositions'];
      if (positions is List) {
        toolbarJson['positions'] = [
          for (final p in positions)
            if (p is Map<String, dynamic> &&
                p['id'] != null &&
                _knownToolbarComponents.contains(p['id']))
              {
                'component': p['id'],
                'x': (p['x'] as num?)?.toDouble() ?? 50.0,
                'y': (p['y'] as num?)?.toDouble() ?? 50.0,
              },
        ];
      }
      if (webToolbar['modelSelectorDisplayStyle'] != null) {
        toolbarJson['modelSelectorDisplayStyle'] =
            webToolbar['modelSelectorDisplayStyle'];
      }
      if (toolbarJson.isNotEmpty) {
        settingsJson.add({
          'key': 'topToolbarSettings',
          'value': jsonEncode(toolbarJson),
        });
      }
    }

    // --- systemPromptVariables (direct JSON blob) ---
    if (settings['systemPromptVariables'] is Map) {
      settingsJson.add({
        'key': 'systemPromptVariables',
        'value': jsonEncode(settings['systemPromptVariables']),
      });
    }
  }

  /// Maps a merged web settings map onto Flutter's `SidebarSettings` JSON.
  ///
  /// The web spreads the 设置 tab fields across the redux `settings` slice, the
  /// selective `userSettings` blob and localStorage `appSettings`, and the
  /// selective export renames some of them (and inverts one). This accepts both
  /// the canonical slice names and the selective aliases, coercing types so the
  /// resulting blob round-trips through `SidebarSettings.fromJson`.
  static Map<String, dynamic> _mapSidebarSettings(Map<String, dynamic> s) {
    final out = <String, dynamic>{};

    void boolKey(String flutterKey, List<String> webKeys) {
      for (final k in webKeys) {
        final v = s[k];
        if (v is bool) {
          out[flutterKey] = v;
          return;
        }
      }
    }

    void intKey(String flutterKey, List<String> webKeys) {
      for (final k in webKeys) {
        final v = s[k];
        if (v is num) {
          out[flutterKey] = v.toInt();
          return;
        }
      }
    }

    boolKey('showMessageDivider', ['showMessageDivider']);
    boolKey('copyableCodeBlocks', ['copyableCodeBlocks']);
    boolKey('renderUserInputAsMarkdown', [
      'renderUserInputAsMarkdown',
      'renderInputMessageAsMarkdown',
    ]);
    boolKey('autoScrollToBottom', ['autoScrollToBottom']);
    boolKey('pasteLongTextAsFile', ['pasteLongTextAsFile']);
    intKey('pasteLongTextThreshold', ['pasteLongTextThreshold']);
    boolKey('codeShowLineNumbers', ['codeShowLineNumbers']);
    boolKey('codeCollapsible', ['codeCollapsible']);
    boolKey('codeWrappable', ['codeWrappable', 'codeWrapping']);
    boolKey('mermaidEnabled', ['mermaidEnabled']);
    boolKey('mathEnableSingleDollar', ['mathEnableSingleDollar']);
    intKey('contextWindowSize', ['contextWindowSize']);
    intKey('contextCount', ['contextCount']);
    intKey('maxOutputTokens', ['maxOutputTokens']);
    boolKey('enableMaxOutputTokens', ['enableMaxOutputTokens']);

    // messageStyle is a required enum on the Flutter side — only forward known
    // values so an unexpected string can't throw in fromJson.
    final messageStyle = s['messageStyle'];
    if (messageStyle == 'plain' || messageStyle == 'bubble') {
      out['messageStyle'] = messageStyle;
    }

    // codeDefaultCollapsed: the slice stores it directly; the selective export
    // renames it to the inverted `codeCollapsibleDefaultOpen`.
    final codeDefaultCollapsed = s['codeDefaultCollapsed'];
    if (codeDefaultCollapsed is bool) {
      out['codeDefaultCollapsed'] = codeDefaultCollapsed;
    } else {
      final defaultOpen = s['codeCollapsibleDefaultOpen'];
      if (defaultOpen is bool) {
        out['codeDefaultCollapsed'] = !defaultOpen;
      }
    }

    return out;
  }

  /// Adds a scalar setting to [settingsJson] if non-null.
  static void _addScalar(
    List<Map<String, dynamic>> settingsJson,
    String key,
    Object? value,
  ) {
    if (value == null) return;
    settingsJson.add({
      'key': key,
      'value': value is String ? value : jsonEncode(value),
    });
  }

  /// Normalizes Web status values to Flutter-compatible status strings.
  static String _normalizeStatus(String? status) {
    switch (status) {
      case 'success':
      case 'pending':
      case 'processing':
      case 'streaming':
      case 'error':
      case 'paused':
        return status!;
      case 'complete':
        return 'success';
      case 'sending':
        return 'success';
      case 'searching':
        return 'processing';
      case null:
      case '':
        return 'success';
      default:
        return 'success';
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
  /// Supports both ZIP and Web JSON formats.
  Future<BackupManifest> peekManifest(File file) async {
    final ext = p.extension(file.path).toLowerCase();

    // Web JSON backup — synthesize a manifest from the JSON content.
    if (ext == '.json') {
      return _peekWebJsonManifest(file);
    }

    // ZIP backup.
    final extractDir = await _extractZip(file);
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

  /// Synthesizes a [BackupManifest] from a Web JSON backup for preview.
  Future<BackupManifest> _peekWebJsonManifest(File jsonFile) async {
    final content = await jsonFile.readAsString();
    // Decode off the UI isolate; only the compact manifest crosses back.
    return Isolate.run<BackupManifest>(
      () => _webManifestFromRoot(jsonDecode(content) as Map<String, dynamic>),
    );
  }

  /// Synthesizes a [BackupManifest] from an already-decoded Web backup root.
  static BackupManifest _webManifestFromRoot(Map<String, dynamic> root) {
    final rawTopics = root['topics'] as List<dynamic>? ?? [];
    final rawAssistants = root['assistants'] as List<dynamic>? ?? [];

    // Count messages and blocks by walking the nested structure.
    int messageCount = 0;
    int blockCount = 0;
    for (final t in rawTopics) {
      if (t is! Map) continue;
      final msgs = t['messages'] as List<dynamic>? ?? [];
      messageCount += msgs.length;
      for (final m in msgs) {
        if (m is! Map) continue;
        final blocks = m['blocks'];
        if (blocks is List) blockCount += blocks.length;
      }
    }

    final appInfo = root['appInfo'] as Map<String, dynamic>? ?? {};
    final timestamp = root['timestamp'];
    String createdAt;
    if (timestamp is int) {
      createdAt =
          DateTime.fromMillisecondsSinceEpoch(timestamp).toUtc().toIso8601String();
    } else {
      createdAt = DateTime.now().toUtc().toIso8601String();
    }

    return BackupManifest(
      createdAt: createdAt,
      schemaVersion: appInfo['backupVersion'] as int? ?? 1,
      deviceInfo: 'Web (${appInfo['name'] ?? 'AetherLink'})',
      stats: BackupStats(
        topics: rawTopics.length,
        messages: messageCount,
        messageBlocks: blockCount,
        assistants: rawAssistants.length,
        providers: 0,
        groups: 0,
        settings: (root['localStorage'] as Map?)?.length ?? 0,
      ),
      options: const BackupOptions(
        includeMessages: true,
        includeProviders: false,
        includeSettings: true,
      ),
    );
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
        // Read all settings from the key-value store, minus secret-bearing
        // keys that must not be exported (see [_excludedSettingKeys]).
        final rows = await db.select(db.appSettingRows).get();
        settingsJson = rows
            .where((r) => !_excludedSettingKeys.contains(r.key))
            .map((r) => {'key': r.key, 'value': r.value})
            .toList();
      }

      // 知识库只导权威数据（库 + 条目 + 正文，设计文档 §11.2）；派生的切块/向量
      // 可从正文重建，不进备份。一个库连同其条目打包成一条记录，恢复时整库原子写入。
      final baseRows = await db.select(db.knowledgeBaseRows).get();
      final itemRows = await db.select(db.knowledgeItemRows).get();
      final contentRows = await db.select(db.knowledgeContentRows).get();
      final contentByItem = {for (final c in contentRows) c.itemId: c};
      final knowledgeJson = <Map<String, dynamic>>[
        for (final base in baseRows)
          {
            'id': base.id,
            'name': base.name,
            'embeddingModelKey': base.embeddingModelKey,
            'dimensions': base.dimensions,
            'chunkSize': base.chunkSize,
            'chunkOverlap': base.chunkOverlap,
            'chunkStrategy': base.chunkStrategy,
            'chunkSeparator': base.chunkSeparator,
            'searchMode': base.searchMode,
            'threshold': base.threshold,
            'topK': base.topK,
            'scope': base.scope.toJson(),
            'status': base.status,
            'createdAt': base.createdAt,
            'items': [
              for (final item in itemRows)
                if (item.baseId == base.id)
                  {
                    'id': item.id,
                    'type': item.type,
                    'source': item.source,
                    'conceptId': item.conceptId,
                    'title': item.title,
                    'status': item.status,
                    'error': item.error,
                    'sourceFingerprint': item.sourceFingerprint,
                    'createdAt': item.createdAt,
                    'content': contentByItem[item.id]?.content,
                    'contentHash': contentByItem[item.id]?.contentHash,
                  },
            ],
          },
      ];

      return _RawBackupData(
        topics: topicsJson,
        messages: messagesJson,
        messageBlocks: blocksJson,
        assistants: assistantsJson,
        providers: providersJson,
        groups: groupsJson,
        settings: settingsJson,
        knowledge: knowledgeJson,
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
    required String knowledgeJson,
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
    addJson('knowledge.json', knowledgeJson);

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
      final rootPath = p.canonicalize(extractPath);
      for (final file in archive) {
        // Zip-slip guard: an entry name like `../../x` (or an absolute path)
        // must never escape the extraction directory.
        final outPath = p.canonicalize(p.join(extractPath, file.name));
        if (outPath != rootPath && !p.isWithin(rootPath, outPath)) {
          throw FormatException('备份包含非法路径条目: ${file.name}');
        }
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
      'knowledge.json',
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
      knowledge: await readJsonList('knowledge.json'),
    );
  }

  Future<RestoreResult> _writeData(
    _RawBackupData data,
    RestoreMode mode,
    int sourceSchema, {
    RestoreSelection? selection,
    void Function(RestoreProgress)? onProgress,
  }) async {
    bool selected(BackupCategory c) =>
        selection == null || selection.includes(c);

    final stats = <BackupCategory, CategoryStat>{};

    await db.transaction(() async {
      if (mode == RestoreMode.overwrite) {
        // Clear only the tables for the categories being restored. Child tables
        // first to respect referential order.
        if (selected(BackupCategory.settings)) {
          await db.delete(db.appSettingRows).go();
        }
        if (selected(BackupCategory.messageBlocks)) {
          await db.delete(db.messageBlockRows).go();
        }
        if (selected(BackupCategory.messages)) {
          await db.delete(db.messageRows).go();
        }
        if (selected(BackupCategory.topics)) {
          await db.delete(db.topicRows).go();
        }
        if (selected(BackupCategory.assistants)) {
          await db.delete(db.assistantRows).go();
        }
        if (selected(BackupCategory.providers)) {
          await db.delete(db.providerRows).go();
        }
        if (selected(BackupCategory.groups)) {
          await db.delete(db.groupRows).go();
        }
        // Only clear memories when the backup actually carries them, so that
        // restoring a native Flutter backup (which has none) doesn't wipe them.
        if (selected(BackupCategory.memories) && data.memories.isNotEmpty) {
          await db.delete(db.memoryRows).go();
        }
        // 同理：旧备份没有 knowledge.json，不能拿空集把现有知识库清掉。清表顺序
        // 先派生后权威，孤儿嵌入在写入完成后统一 GC。
        if (selected(BackupCategory.knowledge) && data.knowledge.isNotEmpty) {
          await db.delete(db.kbChunkRows).go();
          await db.delete(db.knowledgeContentRows).go();
          await db.delete(db.knowledgeItemRows).go();
          await db.delete(db.knowledgeBaseRows).go();
        }
      }

      if (selected(BackupCategory.topics)) {
        stats[BackupCategory.topics] = await _restoreList(
          BackupCategory.topics,
          data.topics,
          mode,
          exists: (id) async => await db.topicDao.getById(id) != null,
          insert: _rawInsertTopic,
          onProgress: onProgress,
        );
      }
      if (selected(BackupCategory.messages)) {
        stats[BackupCategory.messages] = await _restoreList(
          BackupCategory.messages,
          data.messages,
          mode,
          exists: (id) async => await db.messageDao.getById(id) != null,
          insert: _rawInsertMessage,
          onProgress: onProgress,
        );
      }
      if (selected(BackupCategory.messageBlocks)) {
        stats[BackupCategory.messageBlocks] = await _restoreList(
          BackupCategory.messageBlocks,
          data.messageBlocks,
          mode,
          exists: (id) async => await db.messageBlockDao.getById(id) != null,
          insert: _rawInsertMessageBlock,
          onProgress: onProgress,
        );
      }
      if (selected(BackupCategory.assistants)) {
        stats[BackupCategory.assistants] = await _restoreList(
          BackupCategory.assistants,
          data.assistants,
          mode,
          exists: (id) async => await db.assistantDao.getById(id) != null,
          insert: _rawInsertAssistant,
          onProgress: onProgress,
        );
      }
      if (selected(BackupCategory.providers)) {
        stats[BackupCategory.providers] = await _restoreList(
          BackupCategory.providers,
          data.providers,
          mode,
          exists: (id) async => await db.providerDao.getById(id) != null,
          insert: _rawInsertProvider,
          onProgress: onProgress,
        );
      }
      if (selected(BackupCategory.groups)) {
        stats[BackupCategory.groups] = await _restoreList(
          BackupCategory.groups,
          data.groups,
          mode,
          exists: (id) async => await db.groupDao.getById(id) != null,
          insert: _rawInsertGroup,
          onProgress: onProgress,
        );
      }
      if (selected(BackupCategory.settings)) {
        stats[BackupCategory.settings] = await _restoreList(
          BackupCategory.settings,
          data.settings,
          mode,
          idOf: (json) => json['key'] as String? ?? '',
          exists: (key) async => await db.appSettingDao.getValue(key) != null,
          insert: (json) async {
            try {
              await db.appSettingDao
                  .setValue(json['key'] as String, json['value'] as String? ?? '');
              return true;
            } catch (_) {
              return false;
            }
          },
          onProgress: onProgress,
        );
      }
      if (selected(BackupCategory.memories) && data.memories.isNotEmpty) {
        stats[BackupCategory.memories] = await _restoreList(
          BackupCategory.memories,
          data.memories,
          mode,
          exists: (id) async => await db.memoryDao.getById(id) != null,
          insert: _rawInsertMemory,
          // Skip rows soft-deleted on the web side.
          skipWhen: (json) => json['isDeleted'] == true,
          onProgress: onProgress,
        );
      }
      if (selected(BackupCategory.knowledge) && data.knowledge.isNotEmpty) {
        stats[BackupCategory.knowledge] = await _restoreList(
          BackupCategory.knowledge,
          data.knowledge,
          mode,
          exists: (id) async =>
              await db.knowledgeDao.getBase(id) != null,
          insert: _rawInsertKnowledgeBase,
          onProgress: onProgress,
        );
        // 重建完成后回收不再被任何切块引用的孤儿嵌入（设计文档 §11.1）。
        await db.knowledgeDao.gcOrphanEmbeddings();
      }
    });

    int succeeded = 0;
    int skipped = 0;
    int failed = 0;
    for (final s in stats.values) {
      succeeded += s.succeeded;
      skipped += s.skipped;
      failed += s.failed;
    }

    return RestoreResult(
      succeeded: succeeded,
      skipped: skipped,
      failed: failed,
      byCategory: stats,
    );
  }

  /// Writes one category's records with conflict handling, reconciliation
  /// counting and streamed progress.
  ///
  /// Records are processed in [_restoreBatchSize] chunks; after each chunk the
  /// loop emits progress and yields to the event loop so large imports don't
  /// freeze the UI. Returns the category's [CategoryStat] for 对数校验.
  Future<CategoryStat> _restoreList(
    BackupCategory category,
    List<Map<String, dynamic>> records,
    RestoreMode mode, {
    required Future<bool> Function(String id) exists,
    required Future<bool> Function(Map<String, dynamic> json) insert,
    String Function(Map<String, dynamic> json)? idOf,
    bool Function(Map<String, dynamic> json)? skipWhen,
    void Function(RestoreProgress)? onProgress,
  }) async {
    final total = records.length;
    final id = idOf ?? (json) => json['id'] as String? ?? '';
    int succeeded = 0;
    int skipped = 0;
    int failed = 0;
    int done = 0;

    onProgress?.call(RestoreProgress(category, 0, total));

    for (final json in records) {
      final recordId = id(json);
      if (recordId.isEmpty || (skipWhen?.call(json) ?? false)) {
        skipped++;
      } else if (mode == RestoreMode.merge && await exists(recordId)) {
        skipped++;
      } else if (await insert(json)) {
        succeeded++;
      } else {
        failed++;
      }

      done++;
      if (done % _restoreBatchSize == 0 || done == total) {
        onProgress?.call(RestoreProgress(category, done, total));
        // Yield so the UI can paint between batches.
        await Future<void>.delayed(Duration.zero);
      }
    }

    return CategoryStat(
      source: total,
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

  /// Builds a Flutter [MemoryItem] from a Web `memories` record and upserts it.
  ///
  /// Web's shape differs from Flutter's (web `memory` → Flutter `content`, ISO
  /// timestamps → epoch millis, `assistantId` → owner scope, `metadata.*` →
  /// category/source), so the entity is composed field by field rather than via
  /// `fromJson`.
  Future<bool> _rawInsertMemory(Map<String, dynamic> json) async {
    try {
      final id = (json['id'] ?? '').toString();
      final content = (json['memory'] ?? json['content'] ?? '').toString();
      if (id.isEmpty || content.isEmpty) return false;

      final ownerId = (json['assistantId'] as String?)?.trim();
      final hasOwner = ownerId != null && ownerId.isNotEmpty;

      final metadata = json['metadata'];
      String? category;
      String? source;
      if (metadata is Map<String, dynamic>) {
        final c = metadata['category'];
        if (c is String && c.isNotEmpty) category = c;
        final s = metadata['source'];
        if (s is String) source = s;
      }

      final embedding = json['embedding'];
      final embeddingList = embedding is List
          ? embedding.whereType<num>().map((n) => n.toDouble()).toList()
          : null;

      final item = MemoryItem(
        id: id,
        content: content,
        level: hasOwner ? MemoryLevel.owner : MemoryLevel.global,
        ownerId: hasOwner ? ownerId : null,
        category: category,
        source: source == 'manual' ? MemorySource.manual : MemorySource.auto,
        createdAt: _epochMillis(json['createdAt']),
        updatedAt: _epochMillis(json['updatedAt']),
        embedding: (embeddingList?.isEmpty ?? true) ? null : embeddingList,
      );
      await db.memoryDao.upsert(item);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 恢复一个知识库（设计文档 §11.2）：写回权威行（库 + 条目 + 正文），并用库的
  /// 切块参数从正文重建派生 `kb_chunk`——`embeddingKey` 留空，关键词检索立即可用，
  /// 向量索引由重试补嵌 / refresh 惰性回填（不在恢复路径里联网调嵌入 API）。
  Future<bool> _rawInsertKnowledgeBase(Map<String, dynamic> json) async {
    try {
      final id = (json['id'] ?? '').toString();
      final name = (json['name'] ?? '').toString();
      if (id.isEmpty || name.isEmpty) return false;
      final chunkSize = (json['chunkSize'] as num?)?.toInt() ?? 1000;
      final chunkOverlap = (json['chunkOverlap'] as num?)?.toInt() ?? 200;
      final chunkStrategy = KnowledgeChunkStrategy.fromName(
        json['chunkStrategy'] as String?,
      );
      final chunkSeparator =
          (json['chunkSeparator'] as String?) ??
          KnowledgeBase.kDefaultChunkSeparator;
      final scopeJson = json['scope'];
      final scope = scopeJson is Map<String, dynamic>
          ? KnowledgeScope.fromJson(scopeJson)
          : const KnowledgeScope();

      await db.into(db.knowledgeBaseRows).insertOnConflictUpdate(
        KnowledgeBaseRowsCompanion.insert(
          id: id,
          name: name,
          embeddingModelKey: Value(json['embeddingModelKey'] as String?),
          dimensions: Value((json['dimensions'] as num?)?.toInt()),
          chunkSize: Value(chunkSize),
          chunkOverlap: Value(chunkOverlap),
          chunkStrategy: Value(chunkStrategy.name),
          chunkSeparator: Value(chunkSeparator),
          searchMode: Value((json['searchMode'] ?? 'keyword').toString()),
          threshold: Value((json['threshold'] as num?)?.toDouble()),
          topK: Value((json['topK'] as num?)?.toInt() ?? 5),
          scope: scope,
          status: Value((json['status'] ?? 'idle').toString()),
          createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
        ),
      );

      final items = json['items'];
      if (items is! List) return true;
      for (final raw in items) {
        if (raw is! Map<String, dynamic>) continue;
        final itemId = (raw['id'] ?? '').toString();
        final content = raw['content'] as String?;
        if (itemId.isEmpty) continue;
        await db.into(db.knowledgeItemRows).insertOnConflictUpdate(
          KnowledgeItemRowsCompanion.insert(
            id: itemId,
            baseId: id,
            type: (raw['type'] ?? 'note').toString(),
            source: (raw['source'] ?? '').toString(),
            conceptId: (raw['conceptId'] ?? itemId).toString(),
            title: Value(raw['title'] as String?),
            status: Value((raw['status'] ?? 'idle').toString()),
            error: Value(raw['error'] as String?),
            sourceFingerprint: Value(raw['sourceFingerprint'] as String?),
            createdAt: (raw['createdAt'] as num?)?.toInt() ?? 0,
          ),
        );
        if (content == null) continue;
        final contentHash = (raw['contentHash'] ?? '').toString();
        await db.into(db.knowledgeContentRows).insertOnConflictUpdate(
          KnowledgeContentRowsCompanion.insert(
            itemId: itemId,
            content: content,
            contentHash: contentHash,
          ),
        );
        // 派生切块：先清后建，保证 merge 模式下重复恢复也幂等。
        await (db.delete(db.kbChunkRows)
              ..where((t) => t.itemId.equals(itemId)))
            .go();
        for (final chunk in chunkText(
          content,
          size: chunkSize,
          overlap: chunkOverlap,
          strategy: chunkStrategy,
          separator: chunkSeparator,
        )) {
          await db.into(db.kbChunkRows).insert(
            KbChunkRowsCompanion.insert(
              chunkId: '$itemId#${chunk.unitIndex}',
              baseId: id,
              itemId: itemId,
              unitIndex: chunk.unitIndex,
              charStart: chunk.charStart,
              charEnd: chunk.charEnd,
              content: chunk.text,
              contentHash: contentHash,
            ),
          );
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Coerces a Web timestamp (ISO-8601 string or epoch number) to epoch millis;
  /// returns 0 when absent or unparseable.
  static int _epochMillis(Object? value) {
    if (value is num) return value.toInt();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
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

  /// Per-category reconciliation stats (源/目标/跳过/失败). Empty for callers
  /// that don't request a selective restore.
  final Map<BackupCategory, CategoryStat> byCategory;

  const RestoreResult({
    this.succeeded = 0,
    this.skipped = 0,
    this.failed = 0,
    this.byCategory = const {},
  });

  int get total => succeeded + skipped + failed;

  /// True when every restored category reconciled (no failures, write count
  /// covered the non-skipped source records).
  bool get reconciled => byCategory.values.every((s) => s.reconciled);

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

  /// Long-term memory records (Web `memories` table). Empty for native Flutter
  /// backups, which don't carry memories.
  final List<Map<String, dynamic>> memories;

  /// 知识库权威数据（设计文档 §11.2）：每条记录是一个库连同其条目/正文；派生的
  /// 切块/向量不进备份，恢复时从正文重建。旧备份没有这一段时为空。
  final List<Map<String, dynamic>> knowledge;

  const _RawBackupData({
    required this.topics,
    required this.messages,
    required this.messageBlocks,
    required this.assistants,
    required this.providers,
    required this.groups,
    required this.settings,
    this.memories = const [],
    this.knowledge = const [],
  });
}
