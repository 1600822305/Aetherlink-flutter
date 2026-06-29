import 'dart:convert';
import 'dart:io';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/backup/domain/backup_config.dart';
import 'package:aetherlink_flutter/features/chat/data/message_tree_backfill.dart';
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
/// Supports both legacy and v1.21+ formats including:
/// - `contentParts` (text / image / tool-call)
/// - `reasoningContent` (thinking blocks)
/// - Error messages
/// - Multi-thread sessions (`threads` array)
/// - Message forks (`messageForksHash`)
/// - File and link attachments
/// - New format detection (`__exported_items` / `__exported_at`)
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
    final hasExportedItems = root['__exported_items'] is List;
    final hasExportedAt = root['__exported_at'] is String;
    if (!hasSessions && !hasProviders && !hasExportedItems && !hasExportedAt) {
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
      final createdAtMs = (meta['createdAt'] as num?)?.toInt() ??
          (sessionData['createdAt'] as num?)?.toInt();
      final createdAt = createdAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
          : DateTime.now();

      // Collect all messages from the session (main + threads + forks)
      final allMsgMaps = _collectAllMessages(sessionData, title);

      for (final group in allMsgMaps) {
        final topicId = generateId('topic');
        final messageIds = <String>[];

        for (final msg in group.messages) {
          final role = (msg['role'] ?? '').toString().toLowerCase();
          final messageRole = _parseRole(role);
          if (messageRole == null) continue;

          final msgCreatedAtMs = (msg['timestamp'] as num?)?.toInt() ??
              (msg['createdAt'] as num?)?.toInt();
          final msgCreatedAt = msgCreatedAtMs != null
              ? DateTime.fromMillisecondsSinceEpoch(msgCreatedAtMs)
              : createdAt;

          final msgId = generateId('msg');

          // Create blocks from contentParts / content / reasoningContent / error
          final blocks = _createBlocks(msg, msgId, msgCreatedAt);
          if (blocks.isEmpty) continue;

          final blockIds = <String>[];
          for (final block in blocks) {
            await db.messageBlockDao.upsert(block);
            blockIds.add(block.id);
          }

          final hasError = msg['error'] != null &&
              msg['error'].toString().trim().isNotEmpty;
          final message = Message(
            id: msgId,
            role: messageRole,
            assistantId: defaultAssistantId,
            topicId: topicId,
            createdAt: msgCreatedAt,
            status: hasError ? MessageStatus.error : MessageStatus.success,
            blocks: blockIds,
          );
          await db.messageDao.upsert(message);
          messageIds.add(msgId);
          msgCount++;
        }

        if (messageIds.isEmpty) continue;

        final topic = Topic(
          id: topicId,
          assistantId: defaultAssistantId,
          name: group.name.isNotEmpty ? group.name : '导入的对话',
          createdAt: createdAt,
          updatedAt: createdAt,
          messageIds: messageIds,
          messageCount: messageIds.length,
        );
        await db.topicDao.upsert(topic);
        // Link the flat imported messages into the tree shape (virtual root +
        // parentId + activeNodeId) so the branch graph and active path are
        // correct; without this every node is an orphan root.
        await linkTopicMessageTree(db, topic);
        convCount++;
      }
    }

    return (conversations: convCount, messages: msgCount);
  }

  // ---------------------------------------------------------------------------
  // Collect all messages (main thread + historical threads + forks)
  // ---------------------------------------------------------------------------

  static List<_MessageGroup> _collectAllMessages(
    Map sessionData,
    String sessionTitle,
  ) {
    final groups = <_MessageGroup>[];

    // Check for multi-thread sessions
    final threads = sessionData['threads'];
    if (threads is List && threads.length > 1) {
      // Multi-thread: create separate topic per thread
      for (final thread in threads) {
        if (thread is! Map) continue;
        final threadName = (thread['name'] ?? '').toString();
        final threadMessages = thread['messages'];
        if (threadMessages is! List || threadMessages.isEmpty) continue;

        final name = threadName.isNotEmpty
            ? '$sessionTitle - $threadName'
            : sessionTitle;
        groups.add(_MessageGroup(
          name: name,
          messages: threadMessages.cast<Map>(),
        ));
      }

      // Also include main messages if present
      final mainMessages = sessionData['messages'];
      if (mainMessages is List && mainMessages.isNotEmpty) {
        groups.add(_MessageGroup(
          name: sessionTitle,
          messages: mainMessages.cast<Map>(),
        ));
      }

      if (groups.isNotEmpty) return groups;
    }

    // Single thread or no threads: use main messages
    final mainMessages = sessionData['messages'];
    if (mainMessages is List && mainMessages.isNotEmpty) {
      final allMsgs = <Map>[...mainMessages.cast<Map>()];

      // Also include single-thread messages if present
      if (threads is List && threads.length == 1) {
        final thread = threads[0];
        if (thread is Map) {
          final threadMessages = thread['messages'];
          if (threadMessages is List) {
            allMsgs.addAll(threadMessages.cast<Map>());
          }
        }
      }

      // Collect fork messages from messageForksHash
      _collectForkMessages(mainMessages, allMsgs);

      groups.add(_MessageGroup(name: sessionTitle, messages: allMsgs));
    }

    return groups;
  }

  /// Recursively collect messages from messageForksHash fields.
  static void _collectForkMessages(List mainMessages, List<Map> allMsgs) {
    for (final msg in mainMessages) {
      if (msg is! Map) continue;
      final forks = msg['messageForksHash'];
      if (forks is! Map) continue;

      for (final forkEntry in forks.values) {
        if (forkEntry is! Map) continue;
        final lists = forkEntry['lists'];
        if (lists is! List) continue;

        for (final fork in lists) {
          if (fork is! Map) continue;
          final forkMessages = fork['messages'];
          if (forkMessages is! List) continue;

          allMsgs.addAll(forkMessages.cast<Map>());
          // Recurse into fork messages that may also have forks
          _collectForkMessages(forkMessages, allMsgs);
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Block creation from a single ChatboxAI message
  // ---------------------------------------------------------------------------

  static List<MessageBlock> _createBlocks(
    Map msg,
    String messageId,
    DateTime createdAt,
  ) {
    final blocks = <MessageBlock>[];

    // 1. Process contentParts (new format)
    final contentParts = msg['contentParts'];
    bool hasMainText = false;

    if (contentParts is List && contentParts.isNotEmpty) {
      for (final part in contentParts) {
        if (part is! Map) continue;
        final partType = (part['type'] ?? '').toString();

        switch (partType) {
          case 'text':
            final text = (part['text'] ?? '').toString().trim();
            if (text.isNotEmpty) {
              blocks.add(MessageBlock.mainText(
                id: generateId('block'),
                messageId: messageId,
                status: MessageBlockStatus.success,
                createdAt: createdAt,
                content: text,
              ));
              hasMainText = true;
            }
            break;

          case 'image':
            final url = (part['url'] ?? '').toString();
            final storageKey = (part['storageKey'] ?? '').toString();
            blocks.add(MessageBlock.image(
              id: generateId('block'),
              messageId: messageId,
              status: MessageBlockStatus.success,
              createdAt: createdAt,
              url: url.isNotEmpty ? url : storageKey,
              mimeType: 'image/png',
              metadata: {
                if (storageKey.isNotEmpty) 'storageKey': storageKey,
                if (url.isNotEmpty) 'originalUrl': url,
              },
            ));
            break;

          case 'tool-call':
            final toolCallId =
                (part['toolCallId'] ?? generateId('tool')).toString();
            final toolName = (part['toolName'] ?? '').toString();
            blocks.add(MessageBlock.tool(
              id: generateId('block'),
              messageId: messageId,
              status: part['result'] != null
                  ? MessageBlockStatus.success
                  : MessageBlockStatus.processing,
              createdAt: createdAt,
              toolId: toolCallId,
              toolName: toolName.isNotEmpty ? toolName : null,
              arguments: part['args'] is Map
                  ? Map<String, dynamic>.from(part['args'] as Map)
                  : null,
              content: part['result'],
            ));
            break;
        }
      }
    }

    // 2. Fallback: legacy `content` field (if no main_text from contentParts)
    if (!hasMainText) {
      final content = (msg['content'] ?? '').toString().trim();
      if (content.isNotEmpty) {
        blocks.add(MessageBlock.mainText(
          id: generateId('block'),
          messageId: messageId,
          status: MessageBlockStatus.success,
          createdAt: createdAt,
          content: content,
        ));
        hasMainText = true;
      }
    }

    // 3. Reasoning / thinking content
    final reasoning = (msg['reasoningContent'] ?? '').toString().trim();
    if (reasoning.isNotEmpty) {
      blocks.add(MessageBlock.thinking(
        id: generateId('block'),
        messageId: messageId,
        status: MessageBlockStatus.success,
        createdAt: createdAt,
        content: reasoning,
      ));
    }

    // 4. Error messages
    final errorMsg = (msg['error'] ?? '').toString().trim();
    if (errorMsg.isNotEmpty) {
      final errorCode = msg['errorCode'];
      blocks.add(MessageBlock.error(
        id: generateId('block'),
        messageId: messageId,
        status: MessageBlockStatus.error,
        createdAt: createdAt,
        content: errorMsg,
        message: errorMsg,
        code: errorCode != null ? errorCode.toString() : null,
      ));
    }

    // 5. File attachments
    final files = msg['files'];
    if (files is List) {
      for (final f in files) {
        if (f is! Map) continue;
        final fileName = (f['name'] ?? '').toString();
        final fileUrl =
            (f['url'] ?? f['storageKey'] ?? '').toString();
        final fileType = (f['fileType'] ?? 'application/octet-stream').toString();
        if (fileName.isEmpty && fileUrl.isEmpty) continue;

        blocks.add(MessageBlock.file(
          id: generateId('block'),
          messageId: messageId,
          status: MessageBlockStatus.success,
          createdAt: createdAt,
          name: fileName.isNotEmpty ? fileName : 'file',
          url: fileUrl,
          mimeType: fileType,
        ));
      }
    }

    // 6. Links as metadata on the main text block (no dedicated link block type)
    final links = msg['links'];
    if (links is List && links.isNotEmpty && blocks.isNotEmpty) {
      // Attach link metadata to the first main_text block
      for (int i = 0; i < blocks.length; i++) {
        final b = blocks[i];
        if (b is MainTextBlock) {
          final linkData = <Map<String, dynamic>>[];
          for (final link in links) {
            if (link is! Map) continue;
            linkData.add({
              'url': (link['url'] ?? '').toString(),
              'title': (link['title'] ?? '').toString(),
            });
          }
          blocks[i] = b.copyWith(
            metadata: {
              ...?b.metadata,
              'importedLinks': linkData,
            },
          );
          break;
        }
      }
    }

    // 7. If no blocks at all, create a placeholder
    if (blocks.isEmpty) {
      blocks.add(MessageBlock.mainText(
        id: generateId('block'),
        messageId: messageId,
        status: MessageBlockStatus.success,
        createdAt: createdAt,
        content: '[空消息]',
        metadata: {'isEmpty': true},
      ));
    }

    return blocks;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static MessageRole? _parseRole(String role) {
    switch (role) {
      case 'user':
        return MessageRole.user;
      case 'assistant':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      case 'tool':
        return MessageRole.assistant;
      default:
        return null;
    }
  }
}

/// A group of messages to be imported as a single topic.
class _MessageGroup {
  final String name;
  final List<Map> messages;
  const _MessageGroup({required this.name, required this.messages});
}
