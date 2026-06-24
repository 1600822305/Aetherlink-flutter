import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

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

/// Result of a Cherry Studio data import.
class CherryImportResult {
  final int providers;
  final int conversations;
  final int messages;
  const CherryImportResult({
    required this.providers,
    required this.conversations,
    required this.messages,
  });
}

/// Imports data from Cherry Studio backup format (.zip/.bak/.json) into the
/// app database.
///
/// Cherry Studio backup structure (JSON):
/// ```json
/// {
///   "localStorage": { "persist:cherry-studio": "..." },
///   "indexedDB": { "topics": [...], "files": [...], "message_blocks": [...] }
/// }
/// ```
class CherryImporter {
  CherryImporter._();

  /// Import from a Cherry Studio backup file.
  static Future<CherryImportResult> import({
    required File file,
    required RestoreMode mode,
    required AppDatabase db,
  }) async {
    final root = await _readCherryBackupFile(file);

    // Parse localStorage persist data
    final localStorage =
        (root['localStorage'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v),
        ) ??
        const <String, dynamic>{};
    final persistStr = (localStorage['persist:cherry-studio'] ?? '') as String;
    if (persistStr.isEmpty) {
      throw Exception('缺少 Cherry Studio 持久化数据（persist:cherry-studio）');
    }

    late Map<String, dynamic> persistObj;
    try {
      persistObj = jsonDecode(persistStr) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('无效的 Cherry Studio 持久化数据');
    }

    // Parse slices
    Map<String, dynamic> llmSlice = const {};
    try {
      final lStr = (persistObj['llm'] ?? '') as String;
      if (lStr.isNotEmpty) llmSlice = jsonDecode(lStr) as Map<String, dynamic>;
    } catch (_) {}

    Map<String, dynamic> assistantsSlice = const {};
    try {
      final aStr = (persistObj['assistants'] ?? '') as String;
      if (aStr.isNotEmpty) {
        assistantsSlice = jsonDecode(aStr) as Map<String, dynamic>;
      }
    } catch (_) {}

    final List<dynamic> cherryProviders =
        (llmSlice['providers'] as List?) ?? const <dynamic>[];
    final List<dynamic> cherryAssistants =
        (assistantsSlice['assistants'] as List?) ?? const <dynamic>[];

    // Parse IndexedDB
    final indexedDB =
        (root['indexedDB'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ??
        const <String, dynamic>{};
    final List<dynamic> cherryTopicsWithMessages =
        (indexedDB['topics'] as List?) ?? const <dynamic>[];
    final List<dynamic> cherryMessageBlocks =
        (indexedDB['message_blocks'] as List?) ?? const <dynamic>[];

    // Build topic metadata from assistants[].topics[]
    final Map<String, Map<String, dynamic>> topicMeta = {};
    for (final a in cherryAssistants) {
      if (a is! Map) continue;
      final topics = (a['topics'] as List?) ?? const <dynamic>[];
      for (final t in topics) {
        if (t is Map && t['id'] != null) {
          topicMeta[t['id'].toString()] = t.map(
            (k, v) => MapEntry(k.toString(), v),
          );
        }
      }
    }

    // Build topicId -> messages map
    final Map<String, List<Map<String, dynamic>>> topicMessages = {};
    for (final e in cherryTopicsWithMessages) {
      if (e is! Map) continue;
      final id = (e['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final msgs = (e['messages'] as List?) ?? const <dynamic>[];
      topicMessages[id] = [
        for (final m in msgs)
          if (m is Map) m.map((k, v) => MapEntry(k.toString(), v)),
      ];
    }

    // Build messageId -> reconstructed text from message_blocks
    final Map<String, String> blockTextByMessageId = {};
    for (final b in cherryMessageBlocks) {
      if (b is! Map) continue;
      final type = (b['type'] ?? '').toString();
      final messageId = (b['messageId'] ?? '').toString();
      if (messageId.isEmpty) continue;

      String? text;
      if (type == 'main_text') {
        text = (b['content'] ?? '').toString();
      } else if (type == 'code') {
        final code = (b['content'] ?? '').toString();
        final lang = (b['language'] ?? '').toString();
        if (code.isNotEmpty) text = '```$lang\n$code\n```';
      } else if (type == 'thinking') {
        final think = (b['content'] ?? '').toString();
        if (think.isNotEmpty) text = '<think>\n$think\n</think>';
      }

      if (text != null && text.isNotEmpty) {
        final prev = blockTextByMessageId[messageId];
        blockTextByMessageId[messageId] = prev == null || prev.isEmpty
            ? text
            : '$prev\n$text';
      }
    }

    return db.transaction(() async {
      if (mode == RestoreMode.overwrite) {
        await db.delete(db.messageBlockRows).go();
        await db.delete(db.messageRows).go();
        await db.delete(db.topicRows).go();
        await db.delete(db.providerRows).go();
      }

      final providerCount = await _importProviders(cherryProviders, mode, db);
      final convResult = await _importConversations(
        topicMeta: topicMeta,
        topicMessages: topicMessages,
        blockTexts: blockTextByMessageId,
        mode: mode,
        db: db,
      );

      return CherryImportResult(
        providers: providerCount,
        conversations: convResult.conversations,
        messages: convResult.messages,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // File reading (ZIP / plain JSON / GZIP)
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> _readCherryBackupFile(File file) async {
    final bytes = await file.readAsBytes();

    Map<String, dynamic>? tryParse(String text) {
      try {
        final obj = jsonDecode(text) as Map<String, dynamic>;
        if (obj.containsKey('localStorage') && obj.containsKey('indexedDB')) {
          return obj;
        }
      } catch (_) {}
      return null;
    }

    // 1) Plain JSON
    try {
      final content = utf8.decode(bytes, allowMalformed: true);
      final obj = tryParse(content);
      if (obj != null) return obj;
    } catch (_) {}

    // 2) ZIP archive
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final entry in archive) {
        if (!entry.isFile) continue;
        try {
          final content = utf8.decode(
            entry.content as List<int>,
            allowMalformed: true,
          );
          final obj = tryParse(content);
          if (obj != null) return obj;
        } catch (_) {}
      }
    } catch (_) {}

    // 3) GZIP
    try {
      final gunzipped = GZipDecoder().decodeBytes(bytes);
      final content = utf8.decode(gunzipped, allowMalformed: true);
      final obj = tryParse(content);
      if (obj != null) return obj;
    } catch (_) {}

    throw Exception('无法解析 Cherry Studio 备份文件');
  }

  // ---------------------------------------------------------------------------
  // Providers
  // ---------------------------------------------------------------------------

  static Future<int> _importProviders(
    List<dynamic> cherryProviders,
    RestoreMode mode,
    AppDatabase db,
  ) async {
    int count = 0;
    for (final p in cherryProviders) {
      if (p is! Map) continue;
      final id = (p['id'] ?? '').toString();
      if (id.isEmpty) continue;

      if (mode == RestoreMode.merge) {
        final existing = await db.providerDao.getById(id);
        if (existing != null) continue;
      }

      final type = (p['type'] ?? '').toString().toLowerCase();
      final name = (p['name'] ?? id).toString();
      final apiKey = (p['apiKey'] ?? '').toString().split(',').first.trim();
      final apiHost = (p['apiHost'] ?? '').toString().trim();

      String baseUrl = apiHost;
      if (baseUrl.isEmpty) {
        baseUrl = 'https://api.openai.com/v1';
      } else if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }

      String providerType;
      switch (type) {
        case 'anthropic':
          providerType = 'anthropic';
          break;
        case 'gemini':
          providerType = 'gemini';
          break;
        default:
          providerType = 'openai';
      }

      final provider = ModelProvider(
        id: id,
        name: name,
        avatar: name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'P',
        color: '#10a37f',
        isEnabled: apiKey.isNotEmpty,
        apiKey: apiKey.isNotEmpty ? apiKey : null,
        baseUrl: baseUrl,
        providerType: providerType,
      );

      try {
        await db.providerDao.upsert(provider);
        count++;
      } catch (_) {}
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Conversations
  // ---------------------------------------------------------------------------

  static Future<({int conversations, int messages})> _importConversations({
    required Map<String, Map<String, dynamic>> topicMeta,
    required Map<String, List<Map<String, dynamic>>> topicMessages,
    required Map<String, String> blockTexts,
    required RestoreMode mode,
    required AppDatabase db,
  }) async {
    int convCount = 0;
    int msgCount = 0;
    const defaultAssistantId = 'default';

    for (final entry in topicMessages.entries) {
      final topicId = entry.key;
      final messages = entry.value;
      if (messages.isEmpty) continue;

      final meta = topicMeta[topicId] ?? const {};
      final title = (meta['name'] ?? '').toString();
      final createdAtStr = (meta['createdAt'] ?? '').toString();
      final createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();

      final newTopicId = generateId('topic');
      final messageIds = <String>[];

      for (final msg in messages) {
        final role = (msg['role'] ?? '').toString().toLowerCase();
        final messageRole = _parseRole(role);
        if (messageRole == null) continue;

        // Get content: prefer direct content, fall back to reconstructed block text
        final cherryMsgId = (msg['id'] ?? '').toString();
        var content = (msg['content'] ?? '').toString();
        if (content.isEmpty && cherryMsgId.isNotEmpty) {
          content = blockTexts[cherryMsgId] ?? '';
        }
        if (content.isEmpty) continue;

        final msgCreatedAtStr = (msg['createdAt'] ?? '').toString();
        final msgCreatedAt = DateTime.tryParse(msgCreatedAtStr) ?? createdAt;

        final msgId = generateId('msg');
        final blockId = generateId('block');

        final block = MessageBlock.mainText(
          id: blockId,
          messageId: msgId,
          status: MessageBlockStatus.success,
          createdAt: msgCreatedAt,
          content: content,
        );
        await db.messageBlockDao.upsert(block);

        final message = Message(
          id: msgId,
          role: messageRole,
          assistantId: defaultAssistantId,
          topicId: newTopicId,
          createdAt: msgCreatedAt,
          status: MessageStatus.success,
          blocks: [blockId],
        );
        await db.messageDao.upsert(message);
        messageIds.add(msgId);
        msgCount++;
      }

      if (messageIds.isEmpty) continue;

      final topic = Topic(
        id: newTopicId,
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
