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
import 'package:aetherlink_flutter/shared/domain/topic.dart';

/// Result of a ChatboxAI TXT data import.
class ChatboxTxtImportResult {
  final int conversations;
  final int messages;
  const ChatboxTxtImportResult({
    required this.conversations,
    required this.messages,
  });
}

/// Detects whether [content] looks like a ChatboxAI TXT export.
///
/// ChatboxAI TXT format markers (latest v1.21+):
/// - Header: `==================================== [[sessionName]] ====================================`
/// - Footer: `Chatbox AI (https://chatboxai.app)`
/// - Message prefixes: `▶ USER:`, `▶ ASSISTANT:`, `▶ SYSTEM:`
bool isChatboxTxtFormat(String content) {
  final hasHeader = content.contains('====================================');
  final hasFooter = content.contains('Chatbox AI (https://chatboxai.app)');
  final hasUserMsg = content.contains('▶ USER:');
  final hasAssistantMsg = content.contains('▶ ASSISTANT:');
  return hasHeader && hasFooter && (hasUserMsg || hasAssistantMsg);
}

/// Imports data from a ChatboxAI TXT export file into the app database.
///
/// ChatboxAI TXT format (v1.21+):
/// ```
/// ==================================== [[Session Name]] ====================================
///
/// ------------------------------ [1. Thread Name] ------------------------------
///
/// ▶ USER:
///
/// message text
///
/// ▶ ASSISTANT:
///
/// response text
///
///   Attachments:
///     - file.png
///
/// ========================================================================
///
/// Chatbox AI (https://chatboxai.app)
/// ```
class ChatboxTxtImporter {
  ChatboxTxtImporter._();

  /// Import from a ChatboxAI TXT export file.
  static Future<ChatboxTxtImportResult> import({
    required File file,
    required RestoreMode mode,
    required AppDatabase db,
  }) async {
    if (!await file.exists()) {
      throw Exception('ChatboxAI TXT 文件不存在');
    }
    final content = await file.readAsString();

    if (!isChatboxTxtFormat(content)) {
      throw Exception(
        '不是有效的 ChatboxAI TXT 导出文件（缺少特征标记）',
      );
    }

    final parsed = _parseTxt(content);

    return db.transaction(() async {
      if (mode == RestoreMode.overwrite) {
        await db.delete(db.messageBlockRows).go();
        await db.delete(db.messageRows).go();
        await db.delete(db.topicRows).go();
      }

      int convCount = 0;
      int msgCount = 0;
      const defaultAssistantId = 'default';

      for (final session in parsed) {
        final topicId = generateId('topic');
        final now = DateTime.now();
        final messageIds = <String>[];

        for (final msg in session.messages) {
          final role = _parseRole(msg.role);
          if (role == null) continue;
          if (msg.content.isEmpty) continue;

          final msgId = generateId('msg');
          final blockId = generateId('block');

          final block = MessageBlock.mainText(
            id: blockId,
            messageId: msgId,
            status: MessageBlockStatus.success,
            createdAt: now,
            content: msg.content,
          );
          await db.messageBlockDao.upsert(block);

          final message = Message(
            id: msgId,
            role: role,
            assistantId: defaultAssistantId,
            topicId: topicId,
            createdAt: now,
            status: MessageStatus.success,
            blocks: [blockId],
          );
          await db.messageDao.upsert(message);
          messageIds.add(msgId);
          msgCount++;
        }

        if (messageIds.isEmpty) continue;

        final topic = Topic(
          id: topicId,
          assistantId: defaultAssistantId,
          name: session.name.isNotEmpty ? session.name : '导入的对话',
          createdAt: now,
          updatedAt: now,
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

      return ChatboxTxtImportResult(
        conversations: convCount,
        messages: msgCount,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // TXT Parsing
  // ---------------------------------------------------------------------------

  /// Parsed message from TXT content.
  static List<_ParsedSession> _parseTxt(String content) {
    // Extract session name from header:
    // ==================================== [[Session Name]] ====================================
    final sessionNameMatch = RegExp(
      r'={4,}\s*\[\[(.*?)\]\]\s*={4,}',
    ).firstMatch(content);
    final sessionName = sessionNameMatch?.group(1)?.trim() ?? '导入的对话';

    // Check for thread separators (v1.21+ format with named threads):
    // ------------------------------ [1. Thread Name] ------------------------------
    final threadPattern = RegExp(
      r'-{4,}\s*\[(\d+)\.\s*(.*?)\]\s*-{4,}',
    );
    final threadMatches = threadPattern.allMatches(content).toList();

    if (threadMatches.length > 1) {
      // Multi-thread session: create a separate topic for each thread
      final sessions = <_ParsedSession>[];
      for (int i = 0; i < threadMatches.length; i++) {
        final threadName = threadMatches[i].group(2)?.trim() ?? '';
        final start = threadMatches[i].end;
        final end = (i + 1 < threadMatches.length)
            ? threadMatches[i + 1].start
            : content.length;
        final threadContent = content.substring(start, end);
        final messages = _parseMessages(threadContent);
        if (messages.isNotEmpty) {
          final name = threadName.isNotEmpty
              ? '$sessionName - $threadName'
              : sessionName;
          sessions.add(_ParsedSession(name: name, messages: messages));
        }
      }
      return sessions.isNotEmpty
          ? sessions
          : [
              _ParsedSession(
                name: sessionName,
                messages: _parseMessages(content),
              ),
            ];
    }

    // Single thread or old format: parse entire content as one session
    return [
      _ParsedSession(
        name: sessionName,
        messages: _parseMessages(content),
      ),
    ];
  }

  /// Parse messages from a TXT content block.
  ///
  /// Message pattern:
  /// ```
  /// ▶ ROLE:
  ///
  /// message content
  /// ```
  static List<_ParsedMessage> _parseMessages(String content) {
    final messages = <_ParsedMessage>[];

    // Split by message markers: `▶ ROLE: `
    // The regex matches: ▶ (SYSTEM|USER|ASSISTANT):
    // followed by message content until next marker or end-of-session footer
    final messagePattern = RegExp(
      r'▶\s*(SYSTEM|USER|ASSISTANT)\s*:\s*\n',
      caseSensitive: false,
    );

    final matches = messagePattern.allMatches(content).toList();

    for (int i = 0; i < matches.length; i++) {
      final role = matches[i].group(1)!.toLowerCase();
      final start = matches[i].end;
      final end = (i + 1 < matches.length)
          ? matches[i + 1].start
          : content.length;

      var messageContent = content.substring(start, end);

      // Remove trailing footer/separator if present
      messageContent = messageContent
          .replaceAll(
            RegExp(r'={8,}.*$', dotAll: true),
            '',
          )
          .replaceAll(
            RegExp(r'-{8,}\s*\[.*?\]\s*-{8,}.*$', dotAll: true),
            '',
          );

      // Remove attachment section (but preserve the message text before it)
      messageContent = messageContent.replaceAll(
        RegExp(r'\n\s*Attachments:\n(?:\s*-\s*.*\n?)*'),
        '',
      );

      // Remove tool call blocks (indented with "    Tool Call: ...")
      messageContent = messageContent.replaceAll(
        RegExp(
          r'\s*Tool Call:\s*\S+.*?(?=\n\s*▶|\n\s*={8,}|\n\s*-{8,}|$)',
          dotAll: true,
        ),
        '',
      );

      messageContent = messageContent.trim();

      if (messageContent.isNotEmpty) {
        messages.add(_ParsedMessage(role: role, content: messageContent));
      }
    }

    return messages;
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

/// Internal representation of a parsed session.
class _ParsedSession {
  final String name;
  final List<_ParsedMessage> messages;
  const _ParsedSession({required this.name, required this.messages});
}

/// Internal representation of a parsed message.
class _ParsedMessage {
  final String role;
  final String content;
  const _ParsedMessage({required this.role, required this.content});
}
