import 'dart:convert';

/// Metadata embedded in every backup ZIP as `manifest.json`.
class BackupManifest {
  /// Manifest format version (for future-proofing the manifest structure itself).
  final int version;

  /// Application version string (e.g. "1.0.0").
  final String appVersion;

  /// Platform identifier ("flutter", "web", etc.).
  final String platform;

  /// Corresponds to [AppDatabase.schemaVersion] at backup creation time.
  final int schemaVersion;

  /// ISO-8601 timestamp of backup creation.
  final String createdAt;

  /// Human-readable device description (e.g. "Xiaomi 14 Pro / Android 15").
  final String deviceInfo;

  /// SHA-256 checksum of all data files (hex string prefixed with "sha256:").
  final String checksum;

  /// Record counts per table for user confirmation before restore.
  final BackupStats stats;

  /// Options that were active when this backup was created.
  final BackupOptions options;

  const BackupManifest({
    this.version = 1,
    this.appVersion = '1.0.0',
    this.platform = 'flutter',
    this.schemaVersion = 4,
    required this.createdAt,
    this.deviceInfo = '',
    this.checksum = '',
    required this.stats,
    this.options = const BackupOptions(),
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'appVersion': appVersion,
    'platform': platform,
    'schemaVersion': schemaVersion,
    'createdAt': createdAt,
    'deviceInfo': deviceInfo,
    'checksum': checksum,
    'stats': stats.toJson(),
    'options': options.toJson(),
  };

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      version: json['version'] as int? ?? 1,
      appVersion: json['appVersion'] as String? ?? '1.0.0',
      platform: json['platform'] as String? ?? 'unknown',
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      createdAt: json['createdAt'] as String? ?? '',
      deviceInfo: json['deviceInfo'] as String? ?? '',
      checksum: json['checksum'] as String? ?? '',
      stats: json['stats'] != null
          ? BackupStats.fromJson(json['stats'] as Map<String, dynamic>)
          : const BackupStats(),
      options: json['options'] != null
          ? BackupOptions.fromJson(json['options'] as Map<String, dynamic>)
          : const BackupOptions(),
    );
  }

  factory BackupManifest.fromJsonString(String s) {
    final map = jsonDecode(s) as Map<String, dynamic>;
    return BackupManifest.fromJson(map);
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Record counts per table stored in the manifest.
class BackupStats {
  final int topics;
  final int messages;
  final int messageBlocks;
  final int assistants;
  final int providers;
  final int groups;
  final int settings;

  /// 知识库个数（一个库连同其条目/正文作为一条记录导出，见 knowledge.json）。
  final int knowledge;

  const BackupStats({
    this.topics = 0,
    this.messages = 0,
    this.messageBlocks = 0,
    this.assistants = 0,
    this.providers = 0,
    this.groups = 0,
    this.settings = 0,
    this.knowledge = 0,
  });

  Map<String, dynamic> toJson() => {
    'topics': topics,
    'messages': messages,
    'messageBlocks': messageBlocks,
    'assistants': assistants,
    'providers': providers,
    'groups': groups,
    'settings': settings,
    'knowledge': knowledge,
  };

  factory BackupStats.fromJson(Map<String, dynamic> json) {
    return BackupStats(
      topics: json['topics'] as int? ?? 0,
      messages: json['messages'] as int? ?? 0,
      messageBlocks: json['messageBlocks'] as int? ?? 0,
      assistants: json['assistants'] as int? ?? 0,
      providers: json['providers'] as int? ?? 0,
      groups: json['groups'] as int? ?? 0,
      settings: json['settings'] as int? ?? 0,
      knowledge: json['knowledge'] as int? ?? 0,
    );
  }
}

/// Options that control what data is included in a backup.
class BackupOptions {
  final bool includeMessages;
  final bool includeProviders;
  final bool includeSettings;

  const BackupOptions({
    this.includeMessages = true,
    this.includeProviders = true,
    this.includeSettings = true,
  });

  Map<String, dynamic> toJson() => {
    'includeMessages': includeMessages,
    'includeProviders': includeProviders,
    'includeSettings': includeSettings,
  };

  factory BackupOptions.fromJson(Map<String, dynamic> json) {
    return BackupOptions(
      includeMessages: json['includeMessages'] as bool? ?? true,
      includeProviders: json['includeProviders'] as bool? ?? true,
      includeSettings: json['includeSettings'] as bool? ?? true,
    );
  }
}
