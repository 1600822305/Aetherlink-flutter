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

  bool get isHealthy =>
      issues.isEmpty && orphanedMessages == 0 && orphanedBlocks == 0;
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

  /// Run a full diagnostic on the database using SQL COUNT/JOIN queries
  /// to avoid loading all records into memory.
  Future<DiagnosticResult> runDiagnostic() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docDir.path, 'aetherlink.sqlite');
    final dbFile = File(dbPath);
    final dbSize = await dbFile.exists() ? await dbFile.length() : 0;

    // Count records via SQL
    final topicCount = await _countTable('topic_rows');
    final messageCount = await _countTable('message_rows');
    final blockCount = await _countTable('message_block_rows');
    final providerCount = await _countTable('provider_rows');
    final assistantCount = await _countTable('assistant_rows');
    final groupCount = await _countTable('group_rows');
    final settingCount = await _countTable('app_setting_rows');

    // Find orphaned messages via LEFT JOIN
    final orphanedMessages = await _countOrphanedMessages();

    // Find orphaned blocks via LEFT JOIN
    final orphanedBlocks = await _countOrphanedBlocks();

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

  /// Remove orphaned messages and blocks using SQL DELETE with subqueries.
  Future<RepairResult> repair() async {
    final removedMessages = await _deleteOrphanedMessages();
    final removedBlocks = await _deleteOrphanedBlocks();

    return RepairResult(
      orphanedMessagesRemoved: removedMessages,
      orphanedBlocksRemoved: removedBlocks,
    );
  }

  Future<int> _countTable(String tableName) async {
    try {
      final result = await db
          .customSelect('SELECT COUNT(*) AS cnt FROM $tableName')
          .getSingle();
      return result.read<int>('cnt');
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countOrphanedMessages() async {
    try {
      final result = await db
          .customSelect(
            'SELECT COUNT(*) AS cnt FROM message_rows m '
            'LEFT JOIN topic_rows t ON m.topic_id = t.id '
            'WHERE t.id IS NULL',
          )
          .getSingle();
      return result.read<int>('cnt');
    } catch (_) {
      return 0;
    }
  }

  Future<int> _countOrphanedBlocks() async {
    try {
      final result = await db
          .customSelect(
            'SELECT COUNT(*) AS cnt FROM message_block_rows b '
            'LEFT JOIN message_rows m ON b.message_id = m.id '
            'WHERE m.id IS NULL',
          )
          .getSingle();
      return result.read<int>('cnt');
    } catch (_) {
      return 0;
    }
  }

  Future<int> _deleteOrphanedMessages() async {
    try {
      final count = await _countOrphanedMessages();
      if (count == 0) return 0;
      await db.customStatement(
        'DELETE FROM message_rows WHERE id IN ('
        '  SELECT m.id FROM message_rows m '
        '  LEFT JOIN topic_rows t ON m.topic_id = t.id '
        '  WHERE t.id IS NULL'
        ')',
      );
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _deleteOrphanedBlocks() async {
    try {
      final count = await _countOrphanedBlocks();
      if (count == 0) return 0;
      await db.customStatement(
        'DELETE FROM message_block_rows WHERE id IN ('
        '  SELECT b.id FROM message_block_rows b '
        '  LEFT JOIN message_rows m ON b.message_id = m.id '
        '  WHERE m.id IS NULL'
        ')',
      );
      return count;
    } catch (_) {
      return 0;
    }
  }
}
