// P0 view-state for the mobile workspace shell, shared between the left
// file-tree page and the middle file-viewer page.
//
// Both are separate widgets inside the same horizontal PageView, so the
// "which workspace is open" and "which files are open" state — plus the backend
// that reads it — have to live above them. [currentWorkspaceProvider] holds the
// opened workspace; [workspacePreviewBackendProvider] resolves it to the right
// [WorkspaceBackend] so the tree and the viewer share one instance;
// [openWorkspaceFilesProvider] holds the IDE-style open file tabs.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_store.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// Cap on simultaneously open tabs. Every open tab keeps a live editor (its
/// own controller + watch subscription) in the middle page's IndexedStack, so
/// memory grows linearly with tab count; past the cap the oldest clean,
/// non-active tab is evicted (dirty tabs are never dropped silently).
const int kMaxOpenTabs = 12;

/// The workspace currently open in the shell, or `null` when nothing is open
/// (the left tree shows its empty state). Set by auto-restore on entry or by
/// the 「打开文件夹」 button in the file-tree header.
final currentWorkspaceProvider = NotifierProvider<CurrentWorkspace, Workspace?>(
  CurrentWorkspace.new,
);

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

/// Whether the three-page horizontal pager is locked. When `true` the shell
/// disables page swiping so pinch-zoom / drag inside the editor can't
/// accidentally flip pages. Toggled from the editor header's lock button.
final workspacePageLockProvider =
    NotifierProvider<WorkspacePageLock, bool>(WorkspacePageLock.new);

class WorkspacePageLock extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// Immutable state of the middle-page tab strip: the open file tabs and which
/// one is active.
class WorkspaceTabsState {
  const WorkspaceTabsState({this.tabs = const [], this.activePath});

  final List<WorkspaceEntry> tabs;
  final String? activePath;

  bool get isEmpty => tabs.isEmpty;

  WorkspaceEntry? get active {
    final path = activePath;
    if (path == null) return null;
    for (final t in tabs) {
      if (t.path == path) return t;
    }
    return null;
  }

  WorkspaceTabsState copyWith({
    List<WorkspaceEntry>? tabs,
    String? activePath,
  }) => WorkspaceTabsState(
    tabs: tabs ?? this.tabs,
    activePath: activePath ?? this.activePath,
  );
}

/// The IDE-style open file tabs for the middle page. Opening a file appends a
/// tab (or switches to it if already open); closing removes it. The set + the
/// active tab are persisted per workspace so re-entry restores the session.
final openWorkspaceFilesProvider =
    NotifierProvider<OpenWorkspaceFiles, WorkspaceTabsState>(
      OpenWorkspaceFiles.new,
    );

class OpenWorkspaceFiles extends Notifier<WorkspaceTabsState> {
  @override
  WorkspaceTabsState build() => const WorkspaceTabsState();

  /// Opens [entry] in a tab: switches to it if already open, otherwise appends
  /// it and makes it active. Past [kMaxOpenTabs] the oldest clean, non-active
  /// tab is evicted; [dirtyPaths] (from the caller's dirty-files state) marks
  /// tabs that must never be dropped silently.
  void open(WorkspaceEntry entry, {Set<String> dirtyPaths = const {}}) {
    if (state.tabs.any((t) => t.path == entry.path)) {
      state = state.copyWith(activePath: entry.path);
    } else {
      final tabs = [...state.tabs, entry];
      if (tabs.length > kMaxOpenTabs) {
        final evict = tabs.indexWhere(
          (t) =>
              t.path != entry.path &&
              t.path != state.activePath &&
              !dirtyPaths.contains(t.path),
        );
        if (evict >= 0) tabs.removeAt(evict);
      }
      state = WorkspaceTabsState(tabs: tabs, activePath: entry.path);
    }
    _persist();
  }

  /// Makes an already-open tab active.
  void activate(String path) {
    if (state.activePath == path) return;
    if (!state.tabs.any((t) => t.path == path)) return;
    state = state.copyWith(activePath: path);
    _persist();
  }

  /// Closes the tab for [path], picking a sensible neighbour as the new active
  /// tab when the closed one was active.
  void close(String path) {
    final idx = state.tabs.indexWhere((t) => t.path == path);
    if (idx < 0) return;
    final tabs = [...state.tabs]..removeAt(idx);
    String? active = state.activePath;
    if (active == path) {
      if (tabs.isEmpty) {
        active = null;
      } else {
        active = tabs[idx < tabs.length ? idx : tabs.length - 1].path;
      }
    }
    state = WorkspaceTabsState(tabs: tabs, activePath: active);
    _persist();
  }

  /// Clears all tabs (e.g. when switching to a different workspace).
  void reset() {
    state = const WorkspaceTabsState();
    _persist();
  }

  /// Restores a previously-persisted set of tabs (auto-restore on entry).
  void restore(List<WorkspaceEntry> tabs, String? activePath) {
    state = WorkspaceTabsState(
      tabs: tabs,
      activePath: activePath ?? (tabs.isNotEmpty ? tabs.last.path : null),
    );
    _persist();
  }

  void _persist() {
    final workspace = ref.read(currentWorkspaceProvider);
    if (workspace == null) return;
    final session = WorkspaceSession(
      workspaceId: workspace.id,
      tabs: state.tabs,
      activePath: state.activePath,
    );
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kWorkspaceSessionKey, session.encode());
  }
}
