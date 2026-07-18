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
import 'package:aetherlink_flutter/features/workspace/application/editor_auto_save.dart';
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
    this.syntaxHighlight = true,
    this.autoClosePairs = true,
    this.autoIndent = true,
    this.currentLineHighlight = true,
    this.autoSave = false,
    this.autoSaveDelaySecs = kAutoSaveDefaultDelaySecs,
  });

  /// 新打开文件的初始字体大小（缩放仍可临时调整单个文件）。
  final double fontSize;

  /// Tab 键 / 块缩进插入的空格数（2 / 4 / 8）。
  final int tabWidth;

  /// 编辑态强制软换行（无行号栏，不横向滚动）。
  final bool softWrap;

  /// 只读视图语法高亮（按文件名推断语言）。
  final bool syntaxHighlight;

  /// 括号/引号自动补全（含跳过右括号、成对删除）。
  final bool autoClosePairs;

  /// 回车后继承上一行缩进。
  final bool autoIndent;

  /// 编辑态当前行背景高亮。
  final bool currentLineHighlight;

  /// 自动保存：编辑停顿 [autoSaveDelaySecs] 秒后自动写盘，app 切后台也保存。
  final bool autoSave;

  /// 自动保存的停顿延时（秒），取值见 [kAutoSaveDelayOptions]。
  final int autoSaveDelaySecs;

  String get indentUnit => ' ' * tabWidth;

  EditorSettings copyWith({
    double? fontSize,
    int? tabWidth,
    bool? softWrap,
    bool? syntaxHighlight,
    bool? autoClosePairs,
    bool? autoIndent,
    bool? currentLineHighlight,
    bool? autoSave,
    int? autoSaveDelaySecs,
  }) =>
      EditorSettings(
        fontSize: fontSize ?? this.fontSize,
        tabWidth: tabWidth ?? this.tabWidth,
        softWrap: softWrap ?? this.softWrap,
        syntaxHighlight: syntaxHighlight ?? this.syntaxHighlight,
        autoClosePairs: autoClosePairs ?? this.autoClosePairs,
        autoIndent: autoIndent ?? this.autoIndent,
        currentLineHighlight: currentLineHighlight ?? this.currentLineHighlight,
        autoSave: autoSave ?? this.autoSave,
        autoSaveDelaySecs: autoSaveDelaySecs ?? this.autoSaveDelaySecs,
      );

  String encode() => jsonEncode({
        'fontSize': fontSize,
        'tabWidth': tabWidth,
        'softWrap': softWrap,
        'syntaxHighlight': syntaxHighlight,
        'autoClosePairs': autoClosePairs,
        'autoIndent': autoIndent,
        'currentLineHighlight': currentLineHighlight,
        'autoSave': autoSave,
        'autoSaveDelaySecs': autoSaveDelaySecs,
      });

  static EditorSettings? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;
      final fontSize = (map['fontSize'] as num?)?.toDouble() ?? 13;
      final tabWidth = (map['tabWidth'] as num?)?.toInt() ?? 2;
      final autoSaveDelay = (map['autoSaveDelaySecs'] as num?)?.toInt() ??
          kAutoSaveDefaultDelaySecs;
      return EditorSettings(
        fontSize: fontSize.clamp(8, 32).toDouble(),
        tabWidth: const [2, 4, 8].contains(tabWidth) ? tabWidth : 2,
        softWrap: map['softWrap'] == true,
        syntaxHighlight: map['syntaxHighlight'] != false,
        autoClosePairs: map['autoClosePairs'] != false,
        autoIndent: map['autoIndent'] != false,
        currentLineHighlight: map['currentLineHighlight'] != false,
        autoSave: map['autoSave'] == true,
        autoSaveDelaySecs: kAutoSaveDelayOptions.contains(autoSaveDelay)
            ? autoSaveDelay
            : kAutoSaveDefaultDelaySecs,
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

/// 查找栏的历史查询（最近在前，上限 [kMaxFindHistory]），持久化于
/// [kEditorFindHistoryKey]。在提交查询（回车 / 上一个下一个）时记录。
const int kMaxFindHistory = 20;

final findHistoryProvider =
    NotifierProvider<FindHistoryNotifier, List<String>>(
  FindHistoryNotifier.new,
);

class FindHistoryNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    ref
        .read(appSettingsStoreProvider)
        .getSetting(kEditorFindHistoryKey)
        .then((raw) {
      if (raw == null || raw.isEmpty) return;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          state = decoded.whereType<String>().toList();
        }
      } catch (_) {}
    });
    return const [];
  }

  void add(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    final next = [q, ...state.where((e) => e != q)];
    if (next.length > kMaxFindHistory) next.removeRange(kMaxFindHistory, next.length);
    if (next.length == state.length &&
        state.isNotEmpty &&
        state.first == q) {
      return;
    }
    state = next;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kEditorFindHistoryKey, jsonEncode(next));
  }

  void clear() {
    state = const [];
    ref.read(appSettingsStoreProvider).saveSetting(kEditorFindHistoryKey, '[]');
  }
}

/// 当前工作区的「最近打开」文件（最近在前，上限 [kMaxRecentFiles]）。
/// 持久化为 workspaceId → entries 的单个 JSON 对象（[kWorkspaceRecentFilesKey]），
/// 切换工作区时重新加载对应列表。
const int kMaxRecentFiles = 20;

final recentFilesProvider =
    NotifierProvider<RecentFilesNotifier, List<WorkspaceEntry>>(
  RecentFilesNotifier.new,
);

class RecentFilesNotifier extends Notifier<List<WorkspaceEntry>> {
  @override
  List<WorkspaceEntry> build() {
    final workspace = ref.watch(currentWorkspaceProvider);
    if (workspace != null) {
      ref
          .read(appSettingsStoreProvider)
          .getSetting(kWorkspaceRecentFilesKey)
          .then((raw) {
        final entries = _decodeMap(raw)[workspace.id];
        if (entries != null && entries.isNotEmpty) state = entries;
      });
    }
    return const [];
  }

  /// 记录一次打开（去重提前，超上限丢弃最旧）。
  void record(WorkspaceEntry entry) {
    final workspace = ref.read(currentWorkspaceProvider);
    if (workspace == null) return;
    final next = [entry, ...state.where((e) => e.path != entry.path)];
    if (next.length > kMaxRecentFiles) {
      next.removeRange(kMaxRecentFiles, next.length);
    }
    state = next;
    _persist(workspace.id, next);
  }

  Future<void> _persist(String workspaceId, List<WorkspaceEntry> entries) async {
    final store = ref.read(appSettingsStoreProvider);
    final map = _decodeMap(await store.getSetting(kWorkspaceRecentFilesKey));
    map[workspaceId] = entries;
    await store.saveSetting(
      kWorkspaceRecentFilesKey,
      jsonEncode({
        for (final e in map.entries)
          e.key: [for (final t in e.value) t.toJson()],
      }),
    );
  }

  static Map<String, List<WorkspaceEntry>> _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.key is String && e.value is List)
            e.key as String: [
              for (final item in e.value as List)
                if (item is Map)
                  WorkspaceEntry.fromJson(Map<String, dynamic>.from(item)),
            ],
      };
    } catch (_) {
      return {};
    }
  }
}

/// 当前工作区收藏（固定）的文件/目录（收藏顺序，上限 [kMaxPinnedFiles]）。
/// 持久化为 workspaceId → entries 的单个 JSON 对象
/// （[kWorkspacePinnedFilesKey]），切换工作区时重新加载对应列表。
const int kMaxPinnedFiles = 20;

final pinnedFilesProvider =
    NotifierProvider<PinnedFilesNotifier, List<WorkspaceEntry>>(
  PinnedFilesNotifier.new,
);

class PinnedFilesNotifier extends Notifier<List<WorkspaceEntry>> {
  /// 收藏条目的已知父目录（path → parent opaque path）。随收藏一起持久化，
  /// 应用重启后树的 parent 缓存尚未建立时作为兜底（副本/压缩等操作需要
  /// 父目录才能把产物放对位置）。
  final Map<String, String> _parents = {};

  @override
  List<WorkspaceEntry> build() {
    final workspace = ref.watch(currentWorkspaceProvider);
    _parents.clear();
    if (workspace != null) {
      ref
          .read(appSettingsStoreProvider)
          .getSetting(kWorkspacePinnedFilesKey)
          .then((raw) {
        final items = _decodeRaw(raw)[workspace.id];
        if (items == null || items.isEmpty) return;
        final entries = <WorkspaceEntry>[];
        for (final item in items) {
          entries.add(WorkspaceEntry.fromJson(item));
          final parent = item['parentPath'];
          if (parent is String) {
            _parents[item['path'] as String] = parent;
          }
        }
        state = entries;
      });
    }
    return const [];
  }

  bool isPinned(String path) => state.any((e) => e.path == path);

  /// 收藏条目的已持久化父目录（树缓存缺失时的兜底），未知返回 null。
  String? parentPathOf(String path) => _parents[path];

  /// 收藏/取消收藏切换；新收藏追加到末尾，超上限时拒绝并返回 `false`。
  /// [parentPath] 是条目当前的父目录（用于重启后的父目录兜底）。
  bool toggle(WorkspaceEntry entry, {String? parentPath}) {
    final workspace = ref.read(currentWorkspaceProvider);
    if (workspace == null) return false;
    List<WorkspaceEntry> next;
    if (isPinned(entry.path)) {
      next = [...state.where((e) => e.path != entry.path)];
      _parents.remove(entry.path);
    } else {
      if (state.length >= kMaxPinnedFiles) return false;
      next = [...state, entry];
      if (parentPath != null) _parents[entry.path] = parentPath;
    }
    state = next;
    _persist(workspace.id, next);
    return true;
  }

  /// 收藏条目被重命名/移动后同步（旧路径 → 新路径/新名，其余字段保留）。
  /// [newParentPath] 在移动时传入新的父目录；重命名不传（父目录不变）。
  void updatePath(
    String oldPath,
    String newPath,
    String newName, {
    String? newParentPath,
  }) {
    final workspace = ref.read(currentWorkspaceProvider);
    if (workspace == null || !isPinned(oldPath)) return;
    final next = [
      for (final e in state)
        e.path == oldPath
            ? WorkspaceEntry(
                name: newName,
                path: newPath,
                isDirectory: e.isDirectory,
                size: e.size,
                mtime: e.mtime,
                isHidden: e.isHidden,
              )
            : e,
    ];
    final parent = newParentPath ?? _parents[oldPath];
    _parents.remove(oldPath);
    if (parent != null) _parents[newPath] = parent;
    state = next;
    _persist(workspace.id, next);
  }

  /// 收藏条目被删除后移除（含被删目录内部的收藏子条目）。
  /// [parentOf] 用于 opaque 路径的祖先判断（树缓存 + 收藏持久化兜底）。
  void remove(String path, {String? Function(String)? parentOf}) {
    final workspace = ref.read(currentWorkspaceProvider);
    if (workspace == null) return;
    final next = [
      for (final e in state)
        if (e.path != path && !_isUnder(e.path, path, parentOf)) e,
    ];
    if (next.length == state.length) return;
    for (final e in state) {
      if (e.path == path || _isUnder(e.path, path, parentOf)) {
        _parents.remove(e.path);
      }
    }
    state = next;
    _persist(workspace.id, next);
  }

  /// 目录被移动/重命名后同步其内部的收藏子条目：POSIX 路径按前缀重写；
  /// opaque 路径无法推导新子路径，移除避免留下失效收藏。
  void moveDescendants(
    String oldDirPath,
    String newDirPath, {
    String? Function(String)? parentOf,
  }) {
    final workspace = ref.read(currentWorkspaceProvider);
    if (workspace == null) return;
    final posix = !oldDirPath.contains('://');
    final prefix = oldDirPath.endsWith('/') ? oldDirPath : '$oldDirPath/';
    final newBase = newDirPath.endsWith('/')
        ? newDirPath.substring(0, newDirPath.length - 1)
        : newDirPath;
    var changed = false;
    final next = <WorkspaceEntry>[];
    for (final e in state) {
      if (e.path == oldDirPath || !_isUnder(e.path, oldDirPath, parentOf)) {
        next.add(e);
        continue;
      }
      changed = true;
      if (posix && e.path.startsWith(prefix)) {
        final newPath = '$newBase/${e.path.substring(prefix.length)}';
        final oldParent = _parents.remove(e.path);
        _parents[newPath] = oldParent != null && oldParent.startsWith(prefix)
            ? '$newBase/${oldParent.substring(prefix.length)}'
            : (oldParent == oldDirPath || oldParent == null
                ? newDirPath
                : oldParent);
        next.add(
          WorkspaceEntry(
            name: e.name,
            path: newPath,
            isDirectory: e.isDirectory,
            size: e.size,
            mtime: e.mtime,
            isHidden: e.isHidden,
          ),
        );
      } else {
        _parents.remove(e.path);
      }
    }
    if (!changed) return;
    state = next;
    _persist(workspace.id, next);
  }

  // [path] 是否在目录 [dir] 内部：POSIX 路径按前缀判断；opaque 路径沿
  // [parentOf]（树缓存/收藏持久化）向上查找。
  bool _isUnder(String path, String dir, String? Function(String)? parentOf) {
    if (!dir.contains('://')) {
      final prefix = dir.endsWith('/') ? dir : '$dir/';
      if (path.startsWith(prefix)) return true;
    }
    var cursor = parentOf?.call(path) ?? _parents[path];
    var hops = 0;
    while (cursor != null && hops < 64) {
      if (cursor == dir) return true;
      cursor = parentOf?.call(cursor) ?? _parents[cursor];
      hops++;
    }
    return false;
  }

  Future<void> _persist(String workspaceId, List<WorkspaceEntry> entries) async {
    final store = ref.read(appSettingsStoreProvider);
    final map = _decodeRaw(await store.getSetting(kWorkspacePinnedFilesKey));
    map[workspaceId] = [
      for (final e in entries)
        {
          ...e.toJson(),
          if (_parents[e.path] != null) 'parentPath': _parents[e.path],
        },
    ];
    await store.saveSetting(kWorkspacePinnedFilesKey, jsonEncode(map));
  }

  /// 原始 JSON（保留 parentPath 等附加字段，其他工作区的数据原样透传）。
  static Map<String, List<Map<String, dynamic>>> _decodeRaw(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.key is String && e.value is List)
            e.key as String: [
              for (final item in e.value as List)
                if (item is Map) Map<String, dynamic>.from(item),
            ],
      };
    } catch (_) {
      return {};
    }
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
    if (!entry.isDirectory) {
      ref.read(recentFilesProvider.notifier).record(entry);
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

/// 文件树剪贴板的语义：剪切（粘贴后移动并清空剪贴板）或复制（可多次粘贴）。
enum FileClipboardMode { cut, copy }

/// 文件树剪贴板内容：一组条目 + 剪切/复制语义 + 所属工作区根。
///
/// 记录 [workspaceRoot] 是因为路径是各 backend 的 opaque 标识，跨工作区/
/// 跨 backend 粘贴不可行 — 切换工作区后剪贴板即失效。
class FileClipboardState {
  const FileClipboardState({
    required this.entries,
    required this.mode,
    required this.workspaceRoot,
  });

  final List<WorkspaceEntry> entries;
  final FileClipboardMode mode;
  final String workspaceRoot;
}

class FileTreeClipboard extends Notifier<FileClipboardState?> {
  @override
  FileClipboardState? build() => null;

  void set(
    List<WorkspaceEntry> entries,
    FileClipboardMode mode,
    String workspaceRoot,
  ) {
    state = FileClipboardState(
      entries: entries,
      mode: mode,
      workspaceRoot: workspaceRoot,
    );
  }

  void clear() => state = null;
}

/// 文件树的剪切/复制剪贴板（长按菜单「剪切/复制」→「粘贴到此」）。
final fileTreeClipboardProvider =
    NotifierProvider<FileTreeClipboard, FileClipboardState?>(
  FileTreeClipboard.new,
);
