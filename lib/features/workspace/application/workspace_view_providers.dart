// P0 view-state for the mobile workspace shell, shared between the left
// file-tree page and the middle file-viewer page.
//
// Both are separate widgets inside the same horizontal PageView, so the
// "which workspace is open" and "which file is open" state — plus the backend
// that reads it — have to live above them. [currentWorkspaceProvider] holds the
// opened workspace; [workspacePreviewBackendProvider] resolves it to the right
// [WorkspaceBackend] so the tree and the viewer share one instance.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// The workspace currently open in the shell, or `null` when nothing is open
/// (the middle page shows the 起始屏 and the left tree shows its empty state).
/// Set by tapping 「打开本地文件夹」 or a 「最近打开」 tile on the 起始屏.
final currentWorkspaceProvider =
    NotifierProvider<CurrentWorkspace, Workspace?>(CurrentWorkspace.new);

class CurrentWorkspace extends Notifier<Workspace?> {
  @override
  Workspace? build() => null;

  void open(Workspace workspace) => state = workspace;

  void close() => state = null;
}

/// The [WorkspaceBackend] the left tree and middle viewer read from, resolved
/// from [currentWorkspaceProvider]. `null` until a workspace is opened — both
/// pages render their empty state in that case. Kept as a provider so the tree
/// and the viewer share one backend instance / cache.
final workspacePreviewBackendProvider = Provider<WorkspaceBackend?>((ref) {
  final workspace = ref.watch(currentWorkspaceProvider);
  if (workspace == null) return null;
  return ref.watch(workspaceBackendProvider(workspace));
});

/// The file currently opened in the middle viewer page, or `null` when the
/// middle page should show the 起始屏. Set by tapping a file in the left tree.
final selectedWorkspaceFileProvider =
    NotifierProvider<SelectedWorkspaceFile, WorkspaceEntry?>(
  SelectedWorkspaceFile.new,
);

class SelectedWorkspaceFile extends Notifier<WorkspaceEntry?> {
  @override
  WorkspaceEntry? build() => null;

  void select(WorkspaceEntry entry) => state = entry;

  void clear() => state = null;
}
