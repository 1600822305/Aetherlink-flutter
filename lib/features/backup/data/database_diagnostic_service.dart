import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';

/// Database diagnostic result.
class DiagnosticResult {
  final String databasePath;
  final int databaseSizeBytes;
  final int topicCount;
  final int messageCount;
  final int messageBlockCount;
  final int providerCount;
  final int assistantCount;
  final int groupCount;
  final int settingCount;
  final int orphanedMessages;
  final int orphanedBlocks;
  final List<String> issues;

  const DiagnosticResult({
    required this.databasePath,
    required this.databaseSizeBytes,
    required this.topicCount,
    required this.messageCount,
    required this.messageBlockCount,
    required this.providerCount,
    required this.assistantCount,
    required this.groupCount,
    required this.settingCount,
    required this.orphanedMessages,
    required this.orphanedBlocks,
    required this.issues,
  });

  String get databaseSizeDisplay {
    if (databaseSizeBytes < 1024) return '$databaseSizeBytes B';
    if (databaseSizeBytes < 1024 * 1024) {
      return '${(databaseSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(databaseSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get isHealthy => issues.isEmpty && orphanedMessages == 0 && orphanedBlocks == 0;
}

/// Repair result.
class RepairResult {
  final int orphanedMessagesRemoved;
  final int orphanedBlocksRemoved;
  const RepairResult({
    required this.orphanedMessagesRemoved,
    required this.orphanedBlocksRemoved,
  });
}

/// Service for diagnosing and repairing the app database.
class DatabaseDiagnosticService {
  final AppDatabase db;

  DatabaseDiagnosticService({required this.db});

  /// Run a full diagnostic on the database.
  Future<DiagnosticResult> runDiagnostic() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docDir.path, 'aetherlink.sqlite');
    final dbFile = File(dbPath);
    final dbSize = await dbFile.exists() ? await dbFile.length() : 0;

    // Count records
    final topics = await db.topicDao.getAll();
    final topicCount = topics.length;
    final topicIds = topics.map((t) => t.id).toSet();

    final messages = await db.messageDao.getAll();
    final messageCount = messages.length;

    final blocks = await db.messageBlockDao.getAll();
    final blockCount = blocks.length;

    final providers = await db.providerDao.getAll();
    final providerCount = providers.length;

    final assistants = await db.assistantDao.getAll();
    final assistantCount = assistants.length;

    final groups = await db.groupDao.getAll();
    final groupCount = groups.length;

    // Count settings
    final settingCount = await _countSettings();

    // Find orphaned messages (topicId references a non-existent topic)
    int orphanedMessages = 0;
    for (final msg in messages) {
      if (!topicIds.contains(msg.topicId)) {
        orphanedMessages++;
      }
    }

    // Find orphaned blocks (messageId references a non-existent message)
    final messageIds = messages.map((m) => m.id).toSet();
    int orphanedBlocks = 0;
    for (final block in blocks) {
      if (!messageIds.contains(block.messageId)) {
        orphanedBlocks++;
      }
    }

    // Identify issues
    final issues = <String>[];
    if (orphanedMessages > 0) {
      issues.add('发现 $orphanedMessages 条孤立消息（所属对话已不存在）');
    }
    if (orphanedBlocks > 0) {
      issues.add('发现 $orphanedBlocks 个孤立消息块（所属消息已不存在）');
    }
    if (topicCount == 0 && messageCount > 0) {
      issues.add('存在消息但没有对话记录');
    }

    return DiagnosticResult(
      databasePath: dbPath,
      databaseSizeBytes: dbSize,
      topicCount: topicCount,
      messageCount: messageCount,
      messageBlockCount: blockCount,
      providerCount: providerCount,
      assistantCount: assistantCount,
      groupCount: groupCount,
      settingCount: settingCount,
      orphanedMessages: orphanedMessages,
      orphanedBlocks: orphanedBlocks,
      issues: issues,
    );
  }

  /// Remove orphaned messages and blocks.
  Future<RepairResult> repair() async {
    final topics = await db.topicDao.getAll();
    final topicIds = topics.map((t) => t.id).toSet();

    final messages = await db.messageDao.getAll();
    final messageIds = messages.map((m) => m.id).toSet();

    int removedMessages = 0;
    int removedBlocks = 0;

    // Remove orphaned messages
    for (final msg in messages) {
      if (!topicIds.contains(msg.topicId)) {
        await db.messageDao.deleteById(msg.id);
        removedMessages++;
      }
    }

    // Remove orphaned blocks
    final blocks = await db.messageBlockDao.getAll();
    for (final block in blocks) {
      if (!messageIds.contains(block.messageId)) {
        await db.messageBlockDao.deleteById(block.id);
        removedBlocks++;
      }
    }

    return RepairResult(
      orphanedMessagesRemoved: removedMessages,
      orphanedBlocksRemoved: removedBlocks,
    );
  }

  Future<int> _countSettings() async {
    try {
      final result = await db.customSelect(
        'SELECT COUNT(*) AS cnt FROM app_setting_rows',
      ).getSingle();
      return result.read<int>('cnt');
    } catch (_) {
      return 0;
    }
  }
}
