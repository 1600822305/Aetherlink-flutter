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

  /// Restores data from a backup file (ZIP or Web JSON format).
  /// Returns a [RestoreResult] with success/skipped/failed counts.
  Future<RestoreResult> restoreFromFile(
    File file, {
    RestoreMode mode = RestoreMode.overwrite,
  }) async {
    final ext = p.extension(file.path).toLowerCase();

    // Detect Web JSON backup format.
    if (ext == '.json') {
      return _restoreFromWebJson(file, mode);
    }

    // Default: ZIP backup.
    return _restoreFromZip(file, mode);
  }

  /// Restores from a Flutter ZIP backup.
  Future<RestoreResult> _restoreFromZip(
    File zipFile,
    RestoreMode mode,
  ) async {
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
    RestoreMode mode,
  ) async {
    final content = await jsonFile.readAsString();
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
      throw const FormatException(
        '不是有效的 AetherLink Web 备份文件',
      );
    }

    // Safety net.
    await createAutoBackup(reason: 'pre_restore');

    // Flatten nested structure.
    final flatData = _flattenWebBackup(root);

    // Write to database.
    return await _writeData(flatData, mode, db.schemaVersion);
  }

  /// Flattens a Web backup's nested JSON into the same flat structure
  /// used by Flutter's ZIP backup.
  _RawBackupData _flattenWebBackup(Map<String, dynamic> root) {
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

    return _RawBackupData(
      topics: topicsJson,
      messages: messagesJson,
      messageBlocks: blocksJson,
      assistants: assistantsJson,
      providers: providersJson,
      groups: const [],
      settings: settingsJson,
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
    // Model.fromJson requires: id (String), name (String), provider (String).
    final models = <Map<String, dynamic>>[];
    for (final m in json['models'] as List) {
      if (m is! Map<String, dynamic>) continue;
      final modelJson = Map<String, dynamic>.from(m);

      // id is required — skip models without one.
      final modelId = modelJson['id'];
      if (modelId == null || modelId.toString().isEmpty) continue;

      // name defaults to id if missing.
      modelJson['name'] ??= modelId.toString();

      // provider defaults to the parent provider's id.
      modelJson['provider'] ??= json['id'];

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

      models.add(modelJson);
    }
    json['models'] = models;

    // Strip web-only provider fields that don't exist in Flutter.
    json.remove('useCorsPlugin');
    json.remove('customModelEndpoint');

    return json;
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
    final root = jsonDecode(content) as Map<String, dynamic>;

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
