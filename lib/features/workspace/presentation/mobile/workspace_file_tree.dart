import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// The left page: a lazily-loaded file tree over [WorkspaceBackend]. P0 reads
/// the mock backend (fake in-memory tree) so expand/collapse, indentation and
/// icons can be exercised before the real SAF/Termux/SSH backends exist.
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
  static const String _rootPath = '';

  // P0 reads a shared fake backend (see [workspacePreviewBackendProvider]) so
  // the tree and the middle-page viewer hit one instance/cache before a real
  // backend is wired to an opened workspace.
  WorkspaceBackend get _backend => ref.read(workspacePreviewBackendProvider);

  final Set<String> _expanded = {_rootPath};
  final Set<String> _loading = {};
  final Map<String, List<WorkspaceEntry>> _children = {};

  @override
  void initState() {
    super.initState();
    _load(_rootPath);
  }

  Future<void> _load(String path) async {
    if (_children.containsKey(path) || _loading.contains(path)) return;
    setState(() => _loading.add(path));
    final entries = await _backend.listDir(path);
    if (!mounted) return;
    setState(() {
      _loading.remove(path);
      _children[path] = entries;
    });
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

  // Drops every cached listing and reloads the root, so the tree reflects any
  // out-of-band changes. Expand state for still-present directories is kept.
  void _refresh() {
    setState(() {
      _children.clear();
      _loading.clear();
    });
    _load(_rootPath);
  }

  // Collapses everything back to the root. Cached children stay so re-expanding
  // is instant.
  void _collapseAll() {
    setState(() {
      _expanded
        ..clear()
        ..add(_rootPath);
    });
  }

  // New file / new folder need a writable backend (DocumentFile for SAF), which
  // is not built yet — surface that instead of silently doing nothing.
  void _notImplemented(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action 需要 SAF 插件,开发中')),
    );
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

    final rows = <_TreeRow>[];
    _appendRows(_rootPath, 0, rows);
    final rootLoading = _loading.contains(_rootPath) && rows.isEmpty;

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
                      '示例工作区',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const _MockBadge(),
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
                    enabled: false,
                    onTap: () => _notImplemented('新建文件'),
                  ),
                  _ToolbarButton(
                    icon: LucideIcons.folderPlus,
                    tooltip: '新建文件夹',
                    enabled: false,
                    onTap: () => _notImplemented('新建文件夹'),
                  ),
                  const Spacer(),
                  _ToolbarButton(
                    icon: LucideIcons.refreshCw,
                    tooltip: '刷新',
                    onTap: _refresh,
                  ),
                  _ToolbarButton(
                    icon: LucideIcons.chevronsDownUp,
                    tooltip: '全部折叠',
                    onTap: _collapseAll,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: rootLoading
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
  });

  final WorkspaceEntry entry;
  final int depth;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDir = entry.isDirectory;

    return InkWell(
      onTap: onTap,
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
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      icon: Icon(icon, color: color),
    );
  }
}

class _MockBadge extends StatelessWidget {
  const _MockBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '示例数据',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
