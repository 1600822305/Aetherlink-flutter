import 'dart:convert';
import 'dart:io';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// Result of a ChatboxAI data import.
class ChatboxImportResult {
  final int providers;
  final int conversations;
  final int messages;
  const ChatboxImportResult({
    required this.providers,
    required this.conversations,
    required this.messages,
  });
}

/// Imports data from ChatboxAI backup JSON format into the app database.
///
/// ChatboxAI export format:
/// ```json
/// {
///   "settings": { "providers": { "openai": { "apiKey": "...", ... } } },
///   "chat-sessions-list": [ { "id": "...", "name": "..." } ],
///   "session:<id>": { "messages": [ { "role": "user", "content": "..." } ] }
/// }
/// ```
class ChatboxImporter {
  ChatboxImporter._();

  /// Import from a ChatboxAI export file (.json).
  static Future<ChatboxImportResult> import({
    required File file,
    required RestoreMode mode,
    required AppDatabase db,
  }) async {
    final root = await _readFile(file);

    return db.transaction(() async {
      if (mode == RestoreMode.overwrite) {
        await db.delete(db.messageBlockRows).go();
        await db.delete(db.messageRows).go();
        await db.delete(db.topicRows).go();
        await db.delete(db.providerRows).go();
      }

      final providerCount = await _importProviders(root, mode, db);
      final convResult = await _importConversations(root, mode, db);
      return ChatboxImportResult(
        providers: providerCount,
        conversations: convResult.conversations,
        messages: convResult.messages,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // File parsing
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> _readFile(File file) async {
    if (!await file.exists()) {
      throw Exception('ChatboxAI 备份文件不存在');
    }
    final text = await file.readAsString();
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw Exception('无效的 ChatboxAI 备份格式：需要 JSON 对象');
    }
    final root = decoded.map((k, v) => MapEntry(k.toString(), v));

    final hasSessions = root['chat-sessions-list'] is List;
    final settings = root['settings'];
    final hasProviders = settings is Map && (settings['providers'] is Map);
    if (!hasSessions && !hasProviders) {
      throw Exception(
        '不是有效的 ChatboxAI 导出文件（缺少 "chat-sessions-list" 或 "settings.providers"）',
      );
    }
    return root.cast<String, dynamic>();
  }

  // ---------------------------------------------------------------------------
  // Providers
  // ---------------------------------------------------------------------------

  static Future<int> _importProviders(
    Map<String, dynamic> root,
    RestoreMode mode,
    AppDatabase db,
  ) async {
    final rawSettings = root['settings'];
    if (rawSettings is! Map) return 0;
    final providers = rawSettings['providers'];
    if (providers is! Map) return 0;

    int count = 0;
    for (final entry in providers.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty || key == 'chatbox-ai') continue;
      final cfg = entry.value;
      if (cfg is! Map) continue;

      final apiKey = (cfg['apiKey'] ?? '').toString();
      final apiHost = (cfg['apiHost'] ?? '').toString();

      if (mode == RestoreMode.merge) {
        final existing = await db.providerDao.getById(key);
        if (existing != null) continue;
      }

      final provider = ModelProvider(
        id: key,
        name: key,
        avatar: key.substring(0, 1).toUpperCase(),
        color: '#10a37f',
        isEnabled: apiKey.trim().isNotEmpty,
        apiKey: apiKey.isNotEmpty ? apiKey : null,
        baseUrl: apiHost.isNotEmpty ? apiHost : 'https://api.openai.com',
        providerType: 'openai',
      );

      try {
        await db.providerDao.upsert(provider);
        count++;
      } catch (_) {}
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Conversations / Messages
  // ---------------------------------------------------------------------------

  static Future<({int conversations, int messages})> _importConversations(
    Map<String, dynamic> root,
    RestoreMode mode,
    AppDatabase db,
  ) async {
    final sessionsList = root['chat-sessions-list'];
    if (sessionsList is! List || sessionsList.isEmpty) {
      return (conversations: 0, messages: 0);
    }

    int convCount = 0;
    int msgCount = 0;
    const defaultAssistantId = 'default';

    for (final meta in sessionsList) {
      if (meta is! Map) continue;
      final id = (meta['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;

      final sessionData = root['session:$id'];
      if (sessionData is! Map) continue;

      final title = (meta['name'] ?? meta['title'] ?? '').toString();
      final createdAtMs = (meta['createdAt'] as num?)?.toInt();
      final createdAt = createdAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
          : DateTime.now();

      final topicId = generateId('topic');

      if (mode == RestoreMode.merge) {
        // Skip if a topic with same original ID exists (use id as name check)
        // Since IDs won't match, we just append in merge mode.
      }

      // Import messages first to build block list
      final messages = sessionData['messages'];
      if (messages is! List) continue;

      final messageIds = <String>[];
      for (final msg in messages) {
        if (msg is! Map) continue;
        final role = (msg['role'] ?? '').toString().toLowerCase();
        final messageRole = _parseRole(role);
        if (messageRole == null) continue;

        final content = (msg['content'] ?? '').toString();
        if (content.isEmpty) continue;

        final msgCreatedAtMs = (msg['createdAt'] as num?)?.toInt();
        final msgCreatedAt = msgCreatedAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(msgCreatedAtMs)
            : createdAt;

        final msgId = generateId('msg');
        final blockId = generateId('block');

        // Create message block
        final block = MessageBlock.mainText(
          id: blockId,
          messageId: msgId,
          status: MessageBlockStatus.success,
          createdAt: msgCreatedAt,
          content: content,
        );
        await db.messageBlockDao.upsert(block);

        // Create message
        final message = Message(
          id: msgId,
          role: messageRole,
          assistantId: defaultAssistantId,
          topicId: topicId,
          createdAt: msgCreatedAt,
          status: MessageStatus.success,
          blocks: [blockId],
        );
        await db.messageDao.upsert(message);
        messageIds.add(msgId);
        msgCount++;
      }

      if (messageIds.isEmpty) continue;

      // Create topic
      final topic = Topic(
        id: topicId,
        assistantId: defaultAssistantId,
        name: title.isNotEmpty ? title : '导入的对话',
        createdAt: createdAt,
        updatedAt: createdAt,
        messageIds: messageIds,
        messageCount: messageIds.length,
      );
      await db.topicDao.upsert(topic);
      convCount++;
    }

    return (conversations: convCount, messages: msgCount);
  }

  static MessageRole? _parseRole(String role) {
    switch (role) {
      case 'user':
        return MessageRole.user;
      case 'assistant':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      default:
        return null;
    }
  }
}
