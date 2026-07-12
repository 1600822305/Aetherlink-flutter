// P0 view-state for the mobile workspace shell, shared between the left
// file-tree page and the middle file-viewer page.
//
// Both are separate widgets inside the same horizontal PageView, so the
// "which workspace is open" and "which files are open" state — plus the backend
// that reads it — have to live above them. [currentWorkspaceProvider] holds the
// opened workspace; [workspacePreviewBackendProvider] resolves it to the right
// [WorkspaceBackend] so the tree and the viewer share one instance;
// [openWorkspaceFilesProvider] holds the IDE-style open file tabs.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_tree_sort.dart';
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

/// 聊天里的终端工具块「在终端中查看」→ 跳转工作区终端页时要聚焦的
/// AI 会话 ID。终端页消费（打开对应 AI 会话 tab）后清空。
final terminalFocusSessionProvider =
    NotifierProvider<TerminalFocusSession, String?>(TerminalFocusSession.new);

class TerminalFocusSession extends Notifier<String?> {
  @override
  String? build() => null;

  void request(String sessionId) => state = sessionId;

  void clear() => state = null;
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

/// A pending 「打开到指定行」 request ([line] is 1-based). Set by
/// [OpenWorkspaceFiles.open] when a caller passes `line:`; the matching
/// [path]'s editor consumes and clears it once the file has loaded.
class EditorJumpRequest {
  const EditorJumpRequest(this.path, this.line);

  final String path;
  final int line;
}

final editorJumpProvider = NotifierProvider<EditorJump, EditorJumpRequest?>(
  EditorJump.new,
);

class EditorJump extends Notifier<EditorJumpRequest?> {
  @override
  EditorJumpRequest? build() => null;

  void request(String path, int line) => state = EditorJumpRequest(path, line);

  void clear() => state = null;
}

/// Whether the file tree shows hidden entries ([WorkspaceEntry.isHidden]).
/// Persisted under [kWorkspaceShowHiddenKey]; defaults to off.
final showHiddenFilesProvider = NotifierProvider<ShowHiddenFiles, bool>(
  ShowHiddenFiles.new,
);

class ShowHiddenFiles extends Notifier<bool> {
  @override
  bool build() {
    ref
        .read(appSettingsStoreProvider)
        .getSetting(kWorkspaceShowHiddenKey)
        .then((raw) {
      if (raw == 'true' && !state) state = true;
    });
    return false;
  }

  void toggle() {
    state = !state;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kWorkspaceShowHiddenKey, state ? 'true' : 'false');
  }
}

/// 文件树排序方式，持久化于 [kWorkspaceTreeSortKey]；默认名称升序。
final treeSortModeProvider =
    NotifierProvider<TreeSortModeNotifier, TreeSortMode>(
  TreeSortModeNotifier.new,
);

class TreeSortModeNotifier extends Notifier<TreeSortMode> {
  @override
  TreeSortMode build() {
    ref
        .read(appSettingsStoreProvider)
        .getSetting(kWorkspaceTreeSortKey)
        .then((raw) {
      final mode = TreeSortMode.fromName(raw);
      if (mode != state) state = mode;
    });
    return TreeSortMode.nameAsc;
  }

  void set(TreeSortMode mode) {
    state = mode;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kWorkspaceTreeSortKey, mode.name);
  }
}

/// 终端字体大小，持久化于 [kTerminalFontSizeKey]；默认 13（xterm 默认），
/// 范围 [kTerminalFontSizeMin]–[kTerminalFontSizeMax]。
const double kTerminalFontSizeMin = 8;
const double kTerminalFontSizeMax = 28;

final terminalFontSizeProvider =
    NotifierProvider<TerminalFontSizeNotifier, double>(
  TerminalFontSizeNotifier.new,
);

class TerminalFontSizeNotifier extends Notifier<double> {
  @override
  double build() {
    ref
        .read(appSettingsStoreProvider)
        .getSetting(kTerminalFontSizeKey)
        .then((raw) {
      final size = double.tryParse(raw ?? '');
      if (size != null && size != state) {
        state = size.clamp(kTerminalFontSizeMin, kTerminalFontSizeMax);
      }
    });
    return 13;
  }

  void adjust(double delta) {
    state = (state + delta).clamp(kTerminalFontSizeMin, kTerminalFontSizeMax);
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kTerminalFontSizeKey, state.toString());
  }
}

/// 编辑器偏好（默认字体大小 / Tab 缩进宽度 / 软换行），持久化于
/// [kEditorSettingsKey]（单个 JSON 对象）。
class EditorSettings {
  const EditorSettings({
    this.fontSize = 13,
    this.tabWidth = 2,
    this.softWrap = false,
  });

  /// 新打开文件的初始字体大小（缩放仍可临时调整单个文件）。
  final double fontSize;

  /// Tab 键 / 块缩进插入的空格数（2 / 4 / 8）。
  final int tabWidth;

  /// 编辑态强制软换行（无行号栏，不横向滚动）。
  final bool softWrap;

  String get indentUnit => ' ' * tabWidth;

  EditorSettings copyWith({double? fontSize, int? tabWidth, bool? softWrap}) =>
      EditorSettings(
        fontSize: fontSize ?? this.fontSize,
        tabWidth: tabWidth ?? this.tabWidth,
        softWrap: softWrap ?? this.softWrap,
      );

  String encode() => jsonEncode({
        'fontSize': fontSize,
        'tabWidth': tabWidth,
        'softWrap': softWrap,
      });

  static EditorSettings? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final fontSize = (map['fontSize'] as num?)?.toDouble() ?? 13;
      final tabWidth = (map['tabWidth'] as num?)?.toInt() ?? 2;
      return EditorSettings(
        fontSize: fontSize.clamp(8, 32).toDouble(),
        tabWidth: const [2, 4, 8].contains(tabWidth) ? tabWidth : 2,
        softWrap: map['softWrap'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

final editorSettingsProvider =
    NotifierProvider<EditorSettingsNotifier, EditorSettings>(
  EditorSettingsNotifier.new,
);

class EditorSettingsNotifier extends Notifier<EditorSettings> {
  @override
  EditorSettings build() {
    ref
        .read(appSettingsStoreProvider)
        .getSetting(kEditorSettingsKey)
        .then((raw) {
      final settings = EditorSettings.decode(raw);
      if (settings != null) state = settings;
    });
    return const EditorSettings();
  }

  void update(EditorSettings settings) {
    state = settings;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kEditorSettingsKey, settings.encode());
  }
}

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
  ///
  /// [line]（1 起）：打开后定位到该行（全局搜索 / 报错跳转），已打开的
  /// tab 也会重新滚动定位。
  void open(
    WorkspaceEntry entry, {
    Set<String> dirtyPaths = const {},
    int? line,
  }) {
    if (line != null) {
      ref.read(editorJumpProvider.notifier).request(entry.path, line);
    }
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
