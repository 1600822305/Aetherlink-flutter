import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// A modal bottom sheet that lets the user pick a destination directory for a
/// move/copy. It lazily lists directories over [backend] starting at [rootPath],
/// independent of the main tree's cache so the two never fight over state.
///
/// Returns the picked directory path, or `null` when dismissed. [disabledPath]
/// (and its subtree, when known) can't be chosen — used to stop moving a
/// directory into itself.
Future<String?> pickDestinationDirectory(
  BuildContext context, {
  required WorkspaceBackend backend,
  required String rootPath,
  required String rootName,
  String? disabledPath,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return _DirectoryPicker(
        backend: backend,
        rootPath: rootPath,
        rootName: rootName,
        disabledPath: disabledPath,
      );
    },
  );
}

class _DirectoryPicker extends StatefulWidget {
  const _DirectoryPicker({
    required this.backend,
    required this.rootPath,
    required this.rootName,
    required this.disabledPath,
  });

  final WorkspaceBackend backend;
  final String rootPath;
  final String rootName;
  final String? disabledPath;

  @override
  State<_DirectoryPicker> createState() => _DirectoryPickerState();
}

class _DirectoryPickerState extends State<_DirectoryPicker> {
  final Set<String> _expanded = {};
  final Set<String> _loading = {};
  final Map<String, List<WorkspaceEntry>> _children = {};

  @override
  void initState() {
    super.initState();
    _expanded.add(widget.rootPath);
    _load(widget.rootPath);
  }

  Future<void> _load(String path) async {
    if (_children.containsKey(path) || _loading.contains(path)) return;
    setState(() => _loading.add(path));
    try {
      final entries = await widget.backend.listDir(path);
      if (!mounted) return;
      setState(() {
        _loading.remove(path);
        _children[path] = [for (final e in entries) if (e.isDirectory) e];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading.remove(path));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('列目录失败 · $e')),
      );
    }
  }

  void _toggle(String path) {
    if (_expanded.contains(path)) {
      setState(() => _expanded.remove(path));
    } else {
      setState(() => _expanded.add(path));
      _load(path);
    }
  }

  void _appendRows(String path, int depth, List<_PickerRow> out) {
    final entries = _children[path];
    if (entries == null) return;
    for (final entry in entries) {
      final expanded = _expanded.contains(entry.path);
      out.add(_PickerRow(entry: entry, depth: depth, expanded: expanded));
      if (expanded && !_loading.contains(entry.path)) {
        _appendRows(entry.path, depth + 1, out);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <_PickerRow>[];
    _appendRows(widget.rootPath, 1, rows);
    final rootExpanded = _expanded.contains(widget.rootPath);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                '选择目标文件夹',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _PickerTile(
                    name: widget.rootName,
                    depth: 0,
                    expanded: rootExpanded,
                    loading: _loading.contains(widget.rootPath),
                    enabled: widget.disabledPath != widget.rootPath,
                    onToggle: () => _toggle(widget.rootPath),
                    onPick: () =>
                        Navigator.of(context).pop(widget.rootPath),
                  ),
                  for (final row in rows)
                    _PickerTile(
                      name: row.entry.name,
                      depth: row.depth,
                      expanded: row.expanded,
                      loading: _loading.contains(row.entry.path),
                      enabled: widget.disabledPath != row.entry.path,
                      onToggle: () => _toggle(row.entry.path),
                      onPick: () =>
                          Navigator.of(context).pop(row.entry.path),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerRow {
  const _PickerRow({
    required this.entry,
    required this.depth,
    required this.expanded,
  });

  final WorkspaceEntry entry;
  final int depth;
  final bool expanded;
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.name,
    required this.depth,
    required this.expanded,
    required this.loading,
    required this.enabled,
    required this.onToggle,
    required this.onPick,
  });

  final String name;
  final int depth;
  final bool expanded;
  final bool loading;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled ? onPick : null,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12.0 + depth * 16,
          right: 12,
          top: 10,
          bottom: 10,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: onToggle,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      icon: Icon(
                        expanded
                            ? LucideIcons.chevronDown
                            : LucideIcons.chevronRight,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
            Icon(
              expanded ? LucideIcons.folderOpen : LucideIcons.folder,
              size: 18,
              color: enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? null
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
