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
