import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/ssh_credential_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/ssh_connection.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

/// Shared "create an SSH connection + its workspace" helpers, factored out of
/// the SSH connection form so the Termux one-tap flow (设计文档 §10.5 / Termux-A)
/// reuses the exact same persist path instead of copy-pasting it.

/// Persists an [SshConnection] profile and its secret. The profile (non-
/// secret) lands in the connections list; the secret goes to the separate
/// credential KV that is excluded from backup export (设计文档 §5.2). Returns the
/// stored profile (with its minted id + credentialKeyId).
///
/// 同 endpoint（host / port / username / authType）已有档案时复用它：
/// 刷新指纹并覆写凭据，不落新条目——Termux 一键接入每次都指向
/// 127.0.0.1:8022，否则每跑一次就多一条重复连接。
///
/// Takes the two notifiers directly (rather than a `WidgetRef`) so it is plain
/// to unit-test with a `ProviderContainer`.
Future<SshConnection> persistSshConnection({
  required SshConnectionStore connections,
  required SshCredentialStore credentials,
  required String label,
  required SshConnectParams params,
  String? fingerprint,
}) async {
  final existing = connections.findByEndpoint(
    host: params.host,
    port: params.port,
    username: params.username,
    authType: params.authType,
  );
  final SshConnection connection;
  if (existing != null) {
    connection = existing.copyWith(hostKeyFingerprint: fingerprint);
    await connections.save(connection);
  } else {
    connection = await connections.add(
      label: label,
      host: params.host,
      port: params.port,
      username: params.username,
      authType: params.authType,
      hostKeyFingerprint: fingerprint,
    );
  }
  await credentials.save(
    connection.credentialKeyId,
    SshCredential(
      password: params.password,
      privateKeyPem: params.privateKeyPem,
      passphrase: params.passphrase,
    ),
  );
  return connection;
}

/// 一次性清理存量重复连接：同 endpoint（host / port / username / authType）
/// 的多条档案合并为一条（保留最后落库的——其凭据最新），引用被删档案的
/// 工作区改指到存活档案，孤儿凭据一并删除。返回删掉的档案数。
Future<int> dedupeSshConnections({
  required SshConnectionStore connections,
  required SshCredentialStore credentials,
  required WorkspaceStore workspaces,
}) async {
  final all = connections.all();
  final survivors = <String, SshConnection>{};
  for (final c in all) {
    // 后来者覆盖：保留最后落库的。
    survivors['${c.host}|${c.port}|${c.username}|${c.authType.name}'] = c;
  }
  if (survivors.length == all.length) return 0;
  final idMap = <String, String>{};
  var removed = 0;
  for (final c in all) {
    final survivor =
        survivors['${c.host}|${c.port}|${c.username}|${c.authType.name}']!;
    if (c.id == survivor.id) continue;
    idMap[c.id] = survivor.id;
    await connections.remove(c.id);
    if (c.credentialKeyId != survivor.credentialKeyId) {
      await credentials.delete(c.credentialKeyId);
    }
    removed++;
  }
  await workspaces.remapConnections(idMap);
  return removed;
}

/// Opens (or refreshes) a workspace pointing at [connection] rooted at [root]
/// and switches into it (clearing open tabs so the shell lands on the tree).
/// Shared by the SSH form (create / reuse) and the Termux flow; [backendType]
/// distinguishes a Termux workspace from a plain SSH one for display.
/// [name] overrides the display name (defaults to the connection label) and
/// [scope] / [isolatedHome] carry the 项目模式 picker's choices（双作用域
/// 设计稿 §2.1）。
Future<Workspace> openAndSwitchSshWorkspace(
  WidgetRef ref,
  SshConnection connection, {
  required String root,
  WorkspaceBackendType backendType = WorkspaceBackendType.ssh,
  WorkspaceScope scope = WorkspaceScope.project,
  bool isolatedHome = false,
  String? name,
}) async {
  final workspace = await ref.read(workspaceStoreProvider.notifier).open(
        name: name ?? connection.label,
        backendType: backendType,
        scope: scope,
        isolatedHome: isolatedHome,
        root: root,
        displayPath: '${connection.username}@${connection.host}:$root',
        connectionId: connection.id,
      );
  ref.read(currentWorkspaceProvider.notifier).open(workspace);
  ref.read(openWorkspaceFilesProvider.notifier).reset();
  return workspace;
}
