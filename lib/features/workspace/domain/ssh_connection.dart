/// How an [SshConnection] authenticates to its host.
///
/// - [password]    : username + password.
/// - [privateKey]  : username + a private key (optionally passphrase-protected).
///
/// The secret itself (password / key / passphrase) is **never** stored on the
/// connection — only [SshConnection.credentialKeyId] points at it in a separate
/// KV entry (see docs/SSH工作区后端-设计文档.md §5.2), so a future move to
/// secure storage swaps the secret store without touching this model.
enum SshAuthType {
  password,
  privateKey;

  static SshAuthType fromName(String? name) {
    for (final type in SshAuthType.values) {
      if (type.name == name) return type;
    }
    return SshAuthType.password;
  }
}

/// A reusable SSH connection profile (设计文档 §5.1 方案 C). Multiple
/// [Workspace]s reference one of these by `connectionId`, so changing a port or
/// credential takes effect everywhere at once — the connection is a first-class,
/// poolable citizen (cf. VS Code Remote-SSH / JetBrains Gateway / Termius).
///
/// **No secrets live here.** [credentialKeyId] is an opaque pointer into the
/// independent secret KV; [hostKeyFingerprint] is the TOFU-remembered host key
/// (public, not a secret). The constructor only carries the non-secret profile
/// so the whole object is safe to serialize into the (backed-up) connections
/// list. Reserved extension points (jump host, keep-alive, …) are intentionally
/// omitted for now per §5.1.
class SshConnection {
  const SshConnection({
    required this.id,
    required this.label,
    required this.host,
    required this.port,
    required this.username,
    required this.authType,
    required this.credentialKeyId,
    this.hostKeyFingerprint,
  });

  factory SshConnection.fromJson(Map<String, dynamic> json) {
    return SshConnection(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      host: (json['host'] ?? '').toString(),
      port: (json['port'] as num?)?.toInt() ?? 22,
      username: (json['username'] ?? '').toString(),
      authType: SshAuthType.fromName((json['authType'] ?? '').toString()),
      credentialKeyId: (json['credentialKeyId'] ?? '').toString(),
      hostKeyFingerprint:
          (json['hostKeyFingerprint'] as Object?)?.toString(),
    );
  }

  /// Stable id, e.g. `generateId('ssh')`.
  final String id;

  /// Human-friendly display name, e.g. "我的 VPS".
  final String label;

  final String host;

  /// TCP port; defaults to 22.
  final int port;

  final String username;

  final SshAuthType authType;

  /// Opaque pointer into the independent secret KV — **not** the secret itself.
  final String credentialKeyId;

  /// The TOFU-remembered host key fingerprint (public, not a secret); null
  /// until the first successful connection records it.
  final String? hostKeyFingerprint;

  SshConnection copyWith({
    String? label,
    String? host,
    int? port,
    String? username,
    SshAuthType? authType,
    String? credentialKeyId,
    String? hostKeyFingerprint,
  }) {
    return SshConnection(
      id: id,
      label: label ?? this.label,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      credentialKeyId: credentialKeyId ?? this.credentialKeyId,
      hostKeyFingerprint: hostKeyFingerprint ?? this.hostKeyFingerprint,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'host': host,
        'port': port,
        'username': username,
        'authType': authType.name,
        'credentialKeyId': credentialKeyId,
        if (hostKeyFingerprint != null)
          'hostKeyFingerprint': hostKeyFingerprint,
      };
}
