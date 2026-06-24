import 'dart:convert';

/// How to handle conflicts when restoring data.
enum RestoreMode {
  /// Clear all local data, then write backup data.
  overwrite,

  /// Keep local data; only add records whose ID doesn't exist locally.
  merge,
}

/// WebDAV server configuration for cloud backup.
class WebDavConfig {
  final String url;
  final String username;
  final String password;
  final String path;
  final bool includeMessages;
  final bool includeProviders;
  final bool includeSettings;

  const WebDavConfig({
    this.url = '',
    this.username = '',
    this.password = '',
    this.path = 'aetherlink_backups',
    this.includeMessages = true,
    this.includeProviders = true,
    this.includeSettings = true,
  });

  bool get isConfigured =>
      url.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.isNotEmpty;

  WebDavConfig copyWith({
    String? url,
    String? username,
    String? password,
    String? path,
    bool? includeMessages,
    bool? includeProviders,
    bool? includeSettings,
  }) {
    return WebDavConfig(
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      path: path ?? this.path,
      includeMessages: includeMessages ?? this.includeMessages,
      includeProviders: includeProviders ?? this.includeProviders,
      includeSettings: includeSettings ?? this.includeSettings,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'username': username,
        'password': password,
        'path': path,
        'includeMessages': includeMessages,
        'includeProviders': includeProviders,
        'includeSettings': includeSettings,
      };

  factory WebDavConfig.fromJson(Map<String, dynamic> json) {
    return WebDavConfig(
      url: (json['url'] as String?)?.trim() ?? '',
      username: (json['username'] as String?)?.trim() ?? '',
      password: (json['password'] as String?) ?? '',
      path: (json['path'] as String?)?.trim().isNotEmpty == true
          ? (json['path'] as String).trim()
          : 'aetherlink_backups',
      includeMessages: json['includeMessages'] as bool? ?? true,
      includeProviders: json['includeProviders'] as bool? ?? true,
      includeSettings: json['includeSettings'] as bool? ?? true,
    );
  }

  factory WebDavConfig.fromJsonString(String s) {
    try {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return WebDavConfig.fromJson(map);
    } catch (_) {
      return const WebDavConfig();
    }
  }

  String toJsonString() => jsonEncode(toJson());
}
