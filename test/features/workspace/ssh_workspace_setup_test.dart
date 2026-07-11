// Tests the shared SSH persist helper (ssh_workspace_setup.dart) that both the
// SSH connection form and the Termux one-tap flow use to create a connection +
// store its secret. Runs against the in-memory Drift harness (设计文档 §5.2: the
// secret lands under the separate credential KV).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_credential_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_workspace_setup.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/domain/ssh_connection.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

void main() {
  ProviderContainer makeContainer() {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(ChatRepositoryImpl(db)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('persistSshConnection creates a profile and stores its private key',
      () async {
    final c = makeContainer();
    await c.read(sshConnectionStoreProvider.future);
    final connections = c.read(sshConnectionStoreProvider.notifier);
    final credentials = c.read(sshCredentialStoreProvider.notifier);

    const params = SshConnectParams(
      host: '127.0.0.1',
      port: 8022,
      username: 'termux',
      authType: SshAuthType.privateKey,
      privateKeyPem: '-----BEGIN OPENSSH PRIVATE KEY-----\nXX\n-----END OPENSSH PRIVATE KEY-----\n',
    );

    final conn = await persistSshConnection(
      connections: connections,
      credentials: credentials,
      label: 'Termux',
      params: params,
      fingerprint: 'SHA256:abc',
    );

    // Profile stored (non-secret) with the typed-in host/port/auth.
    final stored = connections.byId(conn.id);
    expect(stored, isNotNull);
    expect(stored!.host, '127.0.0.1');
    expect(stored.port, 8022);
    expect(stored.authType, SshAuthType.privateKey);
    expect(stored.hostKeyFingerprint, 'SHA256:abc');
    expect(stored.credentialKeyId, isNotEmpty);

    // Secret stored separately, keyed by the minted credentialKeyId.
    final secret = await credentials.read(conn.credentialKeyId);
    expect(secret?.privateKeyPem, params.privateKeyPem);
    expect(secret?.password, isNull);
  });

  test('persistSshConnection reuses the profile for the same endpoint',
      () async {
    final c = makeContainer();
    await c.read(sshConnectionStoreProvider.future);
    final connections = c.read(sshConnectionStoreProvider.notifier);
    final credentials = c.read(sshCredentialStoreProvider.notifier);

    const params = SshConnectParams(
      host: '127.0.0.1',
      port: 8022,
      username: 'termux',
      authType: SshAuthType.privateKey,
      privateKeyPem: 'KEY-1',
    );
    final first = await persistSshConnection(
      connections: connections,
      credentials: credentials,
      label: 'Termux',
      params: params,
      fingerprint: 'SHA256:a',
    );
    final second = await persistSshConnection(
      connections: connections,
      credentials: credentials,
      label: 'Termux',
      params: const SshConnectParams(
        host: '127.0.0.1',
        port: 8022,
        username: 'termux',
        authType: SshAuthType.privateKey,
        privateKeyPem: 'KEY-2',
      ),
      fingerprint: 'SHA256:b',
    );

    // 同 endpoint 不落新档案：复用同一条并覆写凭据 / 指纹。
    expect(second.id, first.id);
    expect(connections.state.value, hasLength(1));
    expect(connections.byId(first.id)!.hostKeyFingerprint, 'SHA256:b');
    final secret = await credentials.read(first.credentialKeyId);
    expect(secret?.privateKeyPem, 'KEY-2');
  });

  test('dedupeSshConnections merges duplicates and remaps workspaces',
      () async {
    final c = makeContainer();
    await c.read(sshConnectionStoreProvider.future);
    await c.read(workspaceStoreProvider.future);
    final connections = c.read(sshConnectionStoreProvider.notifier);
    final credentials = c.read(sshCredentialStoreProvider.notifier);
    final workspaces = c.read(workspaceStoreProvider.notifier);

    // 存量污染：同 endpoint 三条档案（历史 Termux 一键接入的产物）。
    final conns = <SshConnection>[];
    for (var i = 0; i < 3; i++) {
      final conn = await connections.add(
        label: 'Termux',
        host: '127.0.0.1',
        port: 8022,
        username: 'termux',
        authType: SshAuthType.privateKey,
      );
      await credentials.save(
        conn.credentialKeyId,
        SshCredential(privateKeyPem: 'KEY-$i'),
      );
      conns.add(conn);
    }
    final other = await connections.add(
      label: 'vps',
      host: '10.0.0.1',
      port: 22,
      username: 'root',
      authType: SshAuthType.password,
    );
    await workspaces.open(
      name: 'Termux',
      backendType: WorkspaceBackendType.termux,
      root: '.',
      connectionId: conns[0].id,
    );
    await workspaces.open(
      name: 'Termux',
      backendType: WorkspaceBackendType.termux,
      root: '.',
      connectionId: conns[1].id,
    );

    final removed = await dedupeSshConnections(
      connections: connections,
      credentials: credentials,
      workspaces: workspaces,
    );

    // 三合一（保留最后落库的），无关档案不动。
    expect(removed, 2);
    final remaining = connections.state.value!;
    expect(remaining, hasLength(2));
    expect(connections.byId(conns[2].id), isNotNull);
    expect(connections.byId(other.id), isNotNull);
    // 存活档案的凭据保留，被删档案的凭据清掉。
    expect(
      (await credentials.read(conns[2].credentialKeyId))?.privateKeyPem,
      'KEY-2',
    );
    expect(await credentials.read(conns[0].credentialKeyId), isNull);
    // 工作区改指存活档案，重复条目合并为一条。
    final ws = workspaces.state.value!;
    expect(ws, hasLength(1));
    expect(ws.single.connectionId, conns[2].id);
  });
}
