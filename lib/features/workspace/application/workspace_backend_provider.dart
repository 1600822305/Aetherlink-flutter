import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/workspace/data/local_saf_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

part 'workspace_backend_provider.g.dart';

/// Single LocalSafBackend kept alive for the app's lifetime — used by the
/// 起始屏 connectivity self-test and by [workspaceBackend] for SAF
/// workspaces. The plugin itself is stateless on the Dart side, so a
/// single instance is plenty.
@Riverpod(keepAlive: true)
LocalSafBackend localSafBackend(Ref ref) => LocalSafBackend();

/// Returns the [WorkspaceBackend] for an opened [workspace]. P0 only the
/// local SAF backend is real; Termux / SSH throw until those backends land
/// (设计构想 §2.3).
@riverpod
WorkspaceBackend workspaceBackend(Ref ref, Workspace workspace) {
  switch (workspace.backendType) {
    case WorkspaceBackendType.localSaf:
      return ref.watch(localSafBackendProvider);
    case WorkspaceBackendType.termux:
    case WorkspaceBackendType.ssh:
      throw UnsupportedError(
        'WorkspaceBackend for ${workspace.backendType.name} '
        'is not yet implemented.',
      );
  }
}
