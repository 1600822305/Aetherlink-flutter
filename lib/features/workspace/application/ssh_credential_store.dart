import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/workspace/domain/ssh_connection.dart';

part 'ssh_credential_store.g.dart';

/// KV key holding **all** SSH secrets as one JSON map keyed by
/// `credentialKeyId` → [SshCredential] JSON. Deliberately separate from the
/// (backed-up) connection-profile list and **excluded from backup export**
/// (see backup_service `_kBackupExcludedSettingKeys`) — this is the one real
/// leak surface of the plaintext-KV approach (设计文档 §5.2).
///
/// First-party plaintext store for now (consistent with how LLM API keys are
/// stored). A future hardening swaps the read/write here for
/// `flutter_secure_storage` without touching callers or [SshConnection].
const String kSshCredentialsKey = 'workspace_ssh_credentials';

/// Stores/retrieves SSH secrets by `credentialKeyId`. Kept off the riverpod
/// `state` surface (returns values from method calls instead of exposing the
/// secret map as provider state) so secrets aren't accidentally watched/leaked
/// into widget rebuilds; each op reads the current blob fresh.
@Riverpod(keepAlive: true)
class SshCredentialStore extends _$SshCredentialStore {
  @override
  void build() {}

  Future<Map<String, dynamic>> _readMap() async {
    final raw =
        await ref.read(appSettingsStoreProvider).getSetting(kSshCredentialsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } on FormatException {
      return {};
    }
  }

  Future<void> _writeMap(Map<String, dynamic> map) async {
    await ref
        .read(appSettingsStoreProvider)
        .saveSetting(kSshCredentialsKey, jsonEncode(map));
  }

  /// The secret stored under [credentialKeyId], or null when absent.
  Future<SshCredential?> read(String credentialKeyId) async {
    final map = await _readMap();
    final entry = map[credentialKeyId];
    if (entry is Map) {
      return SshCredential.fromJson(Map<String, dynamic>.from(entry));
    }
    return null;
  }

  /// Stores (or overwrites) the secret for [credentialKeyId].
  Future<void> save(String credentialKeyId, SshCredential credential) async {
    final map = await _readMap();
    map[credentialKeyId] = credential.toJson();
    await _writeMap(map);
  }

  /// Removes the secret for [credentialKeyId] (called when a connection is
  /// deleted). No-op when absent.
  Future<void> delete(String credentialKeyId) async {
    final map = await _readMap();
    if (map.remove(credentialKeyId) != null) await _writeMap(map);
  }
}
