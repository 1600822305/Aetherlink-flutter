// P0 view-state for the mobile workspace shell, shared between the left
// file-tree page and the middle file-viewer page.
//
// Both are separate widgets inside the same horizontal PageView, so the
// "which file is open" state and the backend that reads it have to live above
// them. P0 uses a single [MockWorkspaceBackend] (fake in-memory tree) so the
// tree → viewer interaction can be exercised before the real SAF backend
// lands; swapping in [LocalSafBackend] later only touches this file.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/application/mock_workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// The [WorkspaceBackend] the P0 mobile shell reads from. Kept as a provider
/// (instead of `final _backend = MockWorkspaceBackend()` inside a widget) so
/// the tree and the viewer share one instance and one cache. When real
/// workspace selection lands this becomes a lookup of the opened workspace's
/// backend; the widgets don't change.
final workspacePreviewBackendProvider = Provider<WorkspaceBackend>(
  (ref) => MockWorkspaceBackend(),
);

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
