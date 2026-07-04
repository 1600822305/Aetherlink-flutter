import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/workspace/application/ssh_connection_pool.dart';
import 'package:aetherlink_flutter/features/workspace/data/local_saf_backend.dart';
import 'package:aetherlink_flutter/features/workspace/data/proot_local_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

part 'workspace_backend_provider.g.dart';

/// Single LocalSafBackend kept alive for the app's lifetime — used by the
/// 起始屏 directory picker (pickDirectory) and by [workspaceBackend] for SAF
/// workspaces. The plugin itself is stateless on the Dart side, so a
/// single instance is plenty.
@Riverpod(keepAlive: true)
LocalSafBackend localSafBackend(Ref ref) => LocalSafBackend();

/// Single ProotLocalBackend kept alive for the app's lifetime. The rootfs
/// lives in the app's private dir, so one instance serves every 内置终端
/// workspace (there is effectively only one).
@Riverpod(keepAlive: true)
ProotLocalBackend prootLocalBackend(Ref ref) => ProotLocalBackend();

/// Returns the [WorkspaceBackend] for an opened [workspace].
///
/// SAF returns the app-lifetime singleton. SSH (and Termux, which is just SSH
/// to a Termux `sshd` — 设计文档 §10.5) return the pooled [RemoteSshBackend] for
/// the workspace's `connectionId`, so workspaces on the same server share one
/// transport (the pool owns connect/close — 设计文档 §4.1).
@riverpod
WorkspaceBackend workspaceBackend(Ref ref, Workspace workspace) {
  switch (workspace.backendType) {
    case WorkspaceBackendType.localSaf:
      return ref.watch(localSafBackendProvider);
    case WorkspaceBackendType.prootLocal:
      return ref.watch(prootLocalBackendProvider);
    case WorkspaceBackendType.termux:
    case WorkspaceBackendType.ssh:
      final connectionId = workspace.connectionId;
      if (connectionId == null || connectionId.isEmpty) {
        throw StateError(
          'SSH/Termux workspace "${workspace.id}" has no connectionId; '
          'it must reference an SshConnection (设计文档 §5.1).',
        );
      }
      return ref.watch(sshBackendPoolProvider).backendFor(connectionId);
  }
}
