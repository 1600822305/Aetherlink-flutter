import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_credential_store.dart';
import 'package:aetherlink_flutter/features/workspace/data/remote_ssh_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/ssh_connection.dart';

part 'ssh_connection_pool.g.dart';

/// App-lifetime SSH connection pool. Holds one [RemoteSshBackend] (= one
/// SSHClient + SFTP channel) **per `connectionId`** so multiple workspaces on
/// the same server share a transport instead of re-handshaking (设计文档 §4.1).
/// Closes everything on disposal.
@Riverpod(keepAlive: true)
SshBackendPool sshBackendPool(Ref ref) {
  final pool = SshBackendPool(ref);
  ref.onDispose(pool.dispose);
  return pool;
}

class SshBackendPool {
  SshBackendPool(this._ref);

  final Ref _ref;
  final Map<String, RemoteSshBackend> _backends = {};

  /// The pooled backend for [connectionId], created (but not yet connected) on
  /// first request and reused thereafter. Connection is lazy (first IO).
  RemoteSshBackend backendFor(String connectionId) {
    return _backends.putIfAbsent(
      connectionId,
      () => RemoteSshBackend(
        connectionId,
        resolveParams: () => _resolve(connectionId),
        onLearnFingerprint: (fp) => _ref
            .read(sshConnectionStoreProvider.notifier)
            .setHostKeyFingerprint(connectionId, fp),
      ),
    );
  }

  Future<SshConnectParams> _resolve(String connectionId) async {
    await _ref.read(sshConnectionStoreProvider.future);
    final profile =
        _ref.read(sshConnectionStoreProvider.notifier).byId(connectionId);
    if (profile == null) {
      throw const SshBackendException('SSH 连接配置不存在或已删除');
    }
    final cred = await _ref
        .read(sshCredentialStoreProvider.notifier)
        .read(profile.credentialKeyId);
    return SshConnectParams(
      host: profile.host,
      port: profile.port,
      username: profile.username,
      authType: profile.authType,
      password: cred?.password,
      privateKeyPem: cred?.privateKeyPem,
      passphrase: cred?.passphrase,
      expectedFingerprint: profile.hostKeyFingerprint,
    );
  }

  /// Drops (and closes) the pooled backend for [connectionId] so the next
  /// access reconnects — call after editing a profile / rotating a credential.
  Future<void> invalidate(String connectionId) async {
    final backend = _backends.remove(connectionId);
    if (backend != null) await backend.dispose();
  }

  /// One-shot connection test for the connection form. Resolves nothing from
  /// the stores — the form passes the values the user just typed.
  Future<SshProbeResult> probe(
    SshConnectParams params, {
    String? rootToStat,
  }) =>
      RemoteSshBackend.probe(params, rootToStat: rootToStat);

  Future<void> dispose() async {
    for (final backend in _backends.values) {
      await backend.dispose();
    }
    _backends.clear();
  }
}
