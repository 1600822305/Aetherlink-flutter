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

/// S3-compatible storage configuration (AWS S3, Cloudflare R2, MinIO, etc.).
class S3Config {
  final String endpoint;
  final String region;
  final String bucket;
  final String accessKeyId;
  final String secretAccessKey;
  final String sessionToken;
  final String prefix;
  final bool pathStyle;
  final bool includeMessages;
  final bool includeProviders;
  final bool includeSettings;

  const S3Config({
    this.endpoint = '',
    this.region = 'us-east-1',
    this.bucket = '',
    this.accessKeyId = '',
    this.secretAccessKey = '',
    this.sessionToken = '',
    this.prefix = 'aetherlink_backups',
    this.pathStyle = true,
    this.includeMessages = true,
    this.includeProviders = true,
    this.includeSettings = true,
  });

  bool get isConfigured =>
      endpoint.trim().isNotEmpty &&
      bucket.trim().isNotEmpty &&
      accessKeyId.trim().isNotEmpty &&
      secretAccessKey.isNotEmpty;

  S3Config copyWith({
    String? endpoint,
    String? region,
    String? bucket,
    String? accessKeyId,
    String? secretAccessKey,
    String? sessionToken,
    String? prefix,
    bool? pathStyle,
    bool? includeMessages,
    bool? includeProviders,
    bool? includeSettings,
  }) {
    return S3Config(
      endpoint: endpoint ?? this.endpoint,
      region: region ?? this.region,
      bucket: bucket ?? this.bucket,
      accessKeyId: accessKeyId ?? this.accessKeyId,
      secretAccessKey: secretAccessKey ?? this.secretAccessKey,
      sessionToken: sessionToken ?? this.sessionToken,
      prefix: prefix ?? this.prefix,
      pathStyle: pathStyle ?? this.pathStyle,
      includeMessages: includeMessages ?? this.includeMessages,
      includeProviders: includeProviders ?? this.includeProviders,
      includeSettings: includeSettings ?? this.includeSettings,
    );
  }

  Map<String, dynamic> toJson() => {
        'endpoint': endpoint,
        'region': region,
        'bucket': bucket,
        'accessKeyId': accessKeyId,
        'secretAccessKey': secretAccessKey,
        'sessionToken': sessionToken,
        'prefix': prefix,
        'pathStyle': pathStyle,
        'includeMessages': includeMessages,
        'includeProviders': includeProviders,
        'includeSettings': includeSettings,
      };

  factory S3Config.fromJson(Map<String, dynamic> json) {
    return S3Config(
      endpoint: (json['endpoint'] as String?)?.trim() ?? '',
      region: (json['region'] as String?)?.trim().isNotEmpty == true
          ? (json['region'] as String).trim()
          : 'us-east-1',
      bucket: (json['bucket'] as String?)?.trim() ?? '',
      accessKeyId: (json['accessKeyId'] as String?)?.trim() ?? '',
      secretAccessKey: (json['secretAccessKey'] as String?) ?? '',
      sessionToken: (json['sessionToken'] as String?) ?? '',
      prefix: (json['prefix'] as String?)?.trim().isNotEmpty == true
          ? (json['prefix'] as String).trim()
          : 'aetherlink_backups',
      pathStyle: json['pathStyle'] as bool? ?? true,
      includeMessages: json['includeMessages'] as bool? ?? true,
      includeProviders: json['includeProviders'] as bool? ?? true,
      includeSettings: json['includeSettings'] as bool? ?? true,
    );
  }

  factory S3Config.fromJsonString(String s) {
    try {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return S3Config.fromJson(map);
    } catch (_) {
      return const S3Config();
    }
  }

  String toJsonString() => jsonEncode(toJson());
}
