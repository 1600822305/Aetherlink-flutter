import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/workspace/domain/ssh_connection.dart';

part 'ssh_connection_store.g.dart';

/// KV key for the persisted SSH connection profiles (a JSON array), stored in
/// the same Drift-backed store as other prefs. **Non-secret only** — the
/// profile carries [SshConnection.credentialKeyId], never the secret itself.
const String kSshConnectionsKey = 'workspace_ssh_connections';

/// The reusable SSH connection profiles (设计文档 §5.1 方案 C). Workspaces
/// reference these by `connectionId`, so one edit propagates everywhere.
/// Hydrated from the KV store on first build and written through on every
/// change.
///
/// **Scope note (SSH-0):** this store manages the non-secret profile list only.
/// The credential secrets (password / private key / passphrase) live under
/// independent KV keys referenced by [SshConnection.credentialKeyId] and land
/// with the connection form in SSH-1 — together with their backup-export
/// exclusion (设计文档 §5.2). Keeping secrets out of this JSON now means that
/// later move needs no migration of the profile list.
@Riverpod(keepAlive: true)
class SshConnectionStore extends _$SshConnectionStore {
  @override
  Future<List<SshConnection>> build() async {
    final raw =
        await ref.read(appSettingsStoreProvider).getSetting(kSshConnectionsKey);
    return _decode(raw);
  }

  List<SshConnection> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            SshConnection.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _persist(List<SshConnection> connections) async {
    state = AsyncData(connections);
    await ref.read(appSettingsStoreProvider).saveSetting(
          kSshConnectionsKey,
          jsonEncode([for (final c in connections) c.toJson()]),
        );
  }

  /// The connection with [id], or null when unknown.
  SshConnection? byId(String id) {
    for (final c in state.value ?? const <SshConnection>[]) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Adds a new connection profile, minting its [SshConnection.id] (and, when
  /// blank, its [SshConnection.credentialKeyId]). Returns the stored profile.
  Future<SshConnection> add({
    required String label,
    required String host,
    int port = 22,
    required String username,
    required SshAuthType authType,
    String? credentialKeyId,
    String? hostKeyFingerprint,
  }) async {
    final id = generateId('ssh');
    final entry = SshConnection(
      id: id,
      label: label,
      host: host,
      port: port,
      username: username,
      authType: authType,
      credentialKeyId:
          (credentialKeyId == null || credentialKeyId.isEmpty)
              ? generateId('sshcred')
              : credentialKeyId,
      hostKeyFingerprint: hostKeyFingerprint,
    );
    final current = state.value ?? const <SshConnection>[];
    await _persist([...current, entry]);
    return entry;
  }

  /// Replaces the stored profile [connection] (matched by id). No-op when the
  /// id is unknown. (Named `save` rather than `update` to avoid colliding with
  /// the generated AsyncNotifier's `update`.)
  Future<void> save(SshConnection connection) async {
    final current = state.value ?? const <SshConnection>[];
    if (!current.any((c) => c.id == connection.id)) return;
    await _persist([
      for (final c in current)
        if (c.id == connection.id) connection else c,
    ]);
  }

  /// Records the TOFU host key fingerprint for connection [id].
  Future<void> setHostKeyFingerprint(String id, String fingerprint) async {
    final existing = byId(id);
    if (existing == null) return;
    await save(existing.copyWith(hostKeyFingerprint: fingerprint));
  }

  /// Removes the connection profile [id].
  Future<void> remove(String id) async {
    final current = state.value ?? const <SshConnection>[];
    await _persist([
      for (final c in current)
        if (c.id != id) c,
    ]);
  }
}
