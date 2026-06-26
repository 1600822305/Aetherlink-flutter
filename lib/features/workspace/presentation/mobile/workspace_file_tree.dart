import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/data/local_saf_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/workspace_file_ops.dart';

/// The left page: a lazily-loaded file tree over [WorkspaceBackend], rooted at
/// the opened workspace ([currentWorkspaceProvider]). When nothing is open it
/// shows an empty state pointing back to the 起始屏.
///
/// Directories load their children on first expand and cache them. Tapping a
/// file writes it to [selectedWorkspaceFileProvider]; the middle page swaps to
/// the file viewer and the shell animates over to it.
class WorkspaceFileTree extends ConsumerStatefulWidget {
  const WorkspaceFileTree({super.key, required this.topInset});

  final double topInset;

  @override
  ConsumerState<WorkspaceFileTree> createState() => _WorkspaceFileTreeState();
}

class _WorkspaceFileTreeState extends ConsumerState<WorkspaceFileTree> {
  // The tree root — the opened workspace's `root` (a `content://` URI for
  // SAF). `null` until a workspace is opened.
  String? _root;

  // Resolved from [currentWorkspaceProvider]; `null` until a workspace opens.
  WorkspaceBackend? get _backend => ref.read(workspacePreviewBackendProvider);

  final Set<String> _expanded = {};
  final Set<String> _loading = {};
  final Map<String, List<WorkspaceEntry>> _children = {};

  @override
  void initState() {
    super.initState();
    _bindWorkspace(ref.read(currentWorkspaceProvider));
  }

  // Resets the tree to a new workspace root (or none) and loads the root.
  void _bindWorkspace(Workspace? workspace) {
    _root = workspace?.root;
    _expanded.clear();
    _children.clear();
    _loading.clear();
    final root = _root;
    if (root != null) {
      _expanded.add(root);
      _load(root);
    }
  }

  Future<void> _load(String path) async {
    final backend = _backend;
    if (backend == null) return;
    if (_children.containsKey(path) || _loading.contains(path)) return;
    setState(() => _loading.add(path));
    try {
      final entries = await backend.listDir(path);
      if (!mounted) return;
      setState(() {
        _loading.remove(path);
        _children[path] = entries;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading.remove(path));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('列目录失败 · $e')),
      );
    }
  }

  void _toggleDir(WorkspaceEntry entry) {
    final path = entry.path;
    if (_expanded.contains(path)) {
      setState(() => _expanded.remove(path));
    } else {
      setState(() => _expanded.add(path));
      _load(path);
    }
  }

  // Re-lists a single directory (after a write op) and refreshes its rows,
  // bypassing the load-once cache guard.
  Future<void> _reload(String path) async {
    final backend = _backend;
    if (backend == null) return;
    setState(() => _loading.add(path));
    try {
      final entries = await backend.listDir(path);
      if (!mounted) return;
      setState(() {
        _loading.remove(path);
        _children[path] = entries;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading.remove(path));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('列目录失败 · $e')),
      );
    }
  }

  // Ensures a directory is expanded so freshly-created/moved children show.
  void _ensureExpanded(String path) {
    if (_expanded.contains(path)) return;
    setState(() => _expanded.add(path));
    _load(path);
  }

  // The cached parent directory of an entry. Paths are opaque `content://`
  // URIs, so the parent can only be recovered from the loaded tree structure.
  String? _parentOf(String childPath) {
    for (final entry in _children.entries) {
      if (entry.value.any((e) => e.path == childPath)) return entry.key;
    }
    return null;
  }

  // Drops every cached listing and reloads the root, so the tree reflects any
  // out-of-band changes. Expand state for still-present directories is kept.
  void _refresh() {
    final root = _root;
    if (root == null) return;
    setState(() {
      _children.clear();
      _loading.clear();
    });
    _load(root);
  }

  // Collapses everything back to the root. Cached children stay so re-expanding
  // is instant.
  void _collapseAll() {
    final root = _root;
    setState(() {
      _expanded.clear();
      if (root != null) _expanded.add(root);
    });
  }

  // Walks the cached tree depth-first into flat rows the ListView renders.
  void _appendRows(String path, int depth, List<_TreeRow> out) {
    final entries = _children[path];
    if (entries == null) return;
    for (final entry in entries) {
      final expanded = _expanded.contains(entry.path);
      out.add(_TreeRow(entry: entry, depth: depth, expanded: expanded));
      if (entry.isDirectory && expanded) {
        if (_loading.contains(entry.path)) {
          out.add(_TreeRow.loading(depth + 1));
        } else {
          _appendRows(entry.path, depth + 1, out);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPad = MediaQuery.paddingOf(context).top + widget.topInset + 8;
    final selectedPath = ref.watch(selectedWorkspaceFileProvider)?.path;

    // Re-bind whenever the opened workspace changes (open / switch / close).
    final workspace = ref.watch(currentWorkspaceProvider);
    if (workspace?.root != _root) {
      _bindWorkspace(workspace);
    }

    final root = _root;
    final rows = <_TreeRow>[];
    if (root != null) {
      _appendRows(root, 0, rows);
    }
    final rootLoading = root != null && _loading.contains(root) && rows.isEmpty;

    final backend = _backend;
    final ops = (root != null && backend is LocalSafBackend)
        ? WorkspaceFileOps(
            context: context,
            backend: backend,
            rootPath: root,
            rootName: workspace?.name ?? '工作区',
            reloadDir: _reload,
            ensureExpanded: _ensureExpanded,
            parentOf: _parentOf,
          )
        : null;

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, topPad, 8, 4),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.folderTree,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      workspace?.name ?? '工作区',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Row(
                children: [
                  _ToolbarButton(
                    icon: LucideIcons.filePlus,
                    tooltip: '新建文件',
                    enabled: ops != null,
                    onTap: () => ops?.newFile(ops.rootPath),
                  ),
                  _ToolbarButton(
                    icon: LucideIcons.folderPlus,
                    tooltip: '新建文件夹',
                    enabled: ops != null,
                    onTap: () => ops?.newFolder(ops.rootPath),
                  ),
                  const Spacer(),
                  _ToolbarButton(
                    icon: LucideIcons.refreshCw,
                    tooltip: '刷新',
                    enabled: root != null,
                    onTap: _refresh,
                  ),
                  _ToolbarButton(
                    icon: LucideIcons.chevronsDownUp,
                    tooltip: '全部折叠',
                    enabled: root != null,
                    onTap: _collapseAll,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: root == null
                  ? _EmptyTree(theme: theme)
                  : rootLoading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final row = rows[i];
                        if (row.isLoading) {
                          return _LoadingRow(depth: row.depth);
                        }
                        final entry = row.entry!;
                        return _FileRow(
                          entry: entry,
                          depth: row.depth,
                          expanded: row.expanded,
                          selected: selectedPath == entry.path,
                          onTap: () {
                            if (entry.isDirectory) {
                              _toggleDir(entry);
                            } else {
                              ref
                                  .read(selectedWorkspaceFileProvider.notifier)
                                  .select(entry);
                            }
                          },
                          onLongPress: ops == null
                              ? null
                              : () => ops.showEntryMenu(entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeRow {
  const _TreeRow({
    required this.entry,
    required this.depth,
    required this.expanded,
  }) : isLoading = false;

  const _TreeRow.loading(this.depth)
      : entry = null,
        expanded = false,
        isLoading = true;

  final WorkspaceEntry? entry;
  final int depth;
  final bool expanded;
  final bool isLoading;
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.entry,
    required this.depth,
    required this.expanded,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final WorkspaceEntry entry;
  final int depth;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDir = entry.isDirectory;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        padding: EdgeInsets.only(
          left: 12.0 + depth * 16,
          right: 12,
          top: 8,
          bottom: 8,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              child: isDir
                  ? Icon(
                      expanded
                          ? LucideIcons.chevronDown
                          : LucideIcons.chevronRight,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : null,
            ),
            Icon(
              isDir
                  ? (expanded ? LucideIcons.folderOpen : LucideIcons.folder)
                  : _fileIcon(entry.name),
              size: 18,
              color: isDir
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isDir ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.dart')) return LucideIcons.code;
    if (lower.endsWith('.md')) return LucideIcons.fileText;
    if (lower.endsWith('.yaml') ||
        lower.endsWith('.yml') ||
        lower.endsWith('.json')) {
      return LucideIcons.settings;
    }
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.svg') ||
        lower.endsWith('.webp')) {
      return LucideIcons.image;
    }
    return LucideIcons.file;
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.depth});

  final int depth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12.0 + depth * 16 + 18,
        top: 8,
        bottom: 8,
      ),
      child: const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = enabled
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface.withValues(alpha: 0.30);
    return IconButton(
      onPressed: enabled ? onTap : null,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      icon: Icon(icon, color: color),
    );
  }
}

class _EmptyTree extends StatelessWidget {
  const _EmptyTree({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.folderOpen,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              '还没有打开工作区',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '右滑到起始屏，点「打开本地文件夹」选择一个目录',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
