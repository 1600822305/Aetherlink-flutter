import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/workspace/data/local_saf_backend.dart';
import 'package:aetherlink_flutter/features/workspace/data/remote_ssh_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

part 'workspace_backend_provider.g.dart';

/// Single LocalSafBackend kept alive for the app's lifetime — used by the
/// 起始屏 directory picker (pickDirectory) and by [workspaceBackend] for SAF
/// workspaces. The plugin itself is stateless on the Dart side, so a
/// single instance is plenty.
@Riverpod(keepAlive: true)
LocalSafBackend localSafBackend(Ref ref) => LocalSafBackend();

/// Returns the [WorkspaceBackend] for an opened [workspace].
///
/// SAF returns the app-lifetime singleton. SSH (and Termux, which is just SSH
/// to a Termux `sshd` — 设计文档 §10.5) return a [RemoteSshBackend] keyed by
/// the workspace's `connectionId`. **SSH-0:** that backend is an unconnected
/// skeleton — lookup no longer throws, but its IO calls fail with a clear
/// "not connected" error until the connection lifecycle lands in SSH-1.
@riverpod
WorkspaceBackend workspaceBackend(Ref ref, Workspace workspace) {
  switch (workspace.backendType) {
    case WorkspaceBackendType.localSaf:
      return ref.watch(localSafBackendProvider);
    case WorkspaceBackendType.termux:
    case WorkspaceBackendType.ssh:
      final connectionId = workspace.connectionId;
      if (connectionId == null || connectionId.isEmpty) {
        throw StateError(
          'SSH/Termux workspace "${workspace.id}" has no connectionId; '
          'it must reference an SshConnection (设计文档 §5.1).',
        );
      }
      final backend = RemoteSshBackend(connectionId);
      ref.onDispose(backend.dispose);
      return backend;
  }
}
