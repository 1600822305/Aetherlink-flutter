import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/workspace/application/mock_workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

part 'workspace_backend_provider.g.dart';

/// The active [WorkspaceBackend] the file-tree UI reads from.
///
/// P0 always returns [MockWorkspaceBackend] (fake in-memory tree). Once the
/// real backends land this resolves to the backend matching the currently
/// open workspace's `backendType` — the UI keeps depending only on
/// [WorkspaceBackend], so nothing here forces a UI rewrite.
@Riverpod(keepAlive: true)
WorkspaceBackend workspaceBackend(Ref ref) => MockWorkspaceBackend();
