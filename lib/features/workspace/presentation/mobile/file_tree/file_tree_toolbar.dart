import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_tree_sort.dart';

/// The tree toolbar in normal mode: new file/folder, enter multi-select,
/// sort menu, hidden-files toggle, refresh and collapse-all.
class FileTreeToolbar extends StatelessWidget {
  const FileTreeToolbar({
    super.key,
    required this.hasRoot,
    required this.canWrite,
    required this.canCreate,
    required this.showHidden,
    required this.sortMode,
    required this.onNewFile,
    required this.onNewFolder,
    required this.onEnterSelect,
    required this.onOpenTrash,
    required this.onSortSelected,
    required this.onToggleHidden,
    required this.onRefresh,
    required this.onCollapseAll,
  });

  final bool hasRoot;
  final bool canWrite;

  /// Whether the new-file/new-folder buttons are enabled (ops built + writable).
  final bool canCreate;
  final bool showHidden;
  final TreeSortMode sortMode;
  final VoidCallback onNewFile;
  final VoidCallback onNewFolder;
  final VoidCallback onEnterSelect;
  final VoidCallback onOpenTrash;
  final ValueChanged<TreeSortMode> onSortSelected;
  final VoidCallback onToggleHidden;
  final VoidCallback onRefresh;
  final VoidCallback onCollapseAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FileTreeToolbarButton(
          icon: LucideIcons.filePlus,
          tooltip: '新建文件',
          enabled: canCreate,
          onTap: onNewFile,
        ),
        FileTreeToolbarButton(
          icon: LucideIcons.folderPlus,
          tooltip: '新建文件夹',
          enabled: canCreate,
          onTap: onNewFolder,
        ),
        FileTreeToolbarButton(
          icon: LucideIcons.squareCheck,
          tooltip: '多选',
          enabled: hasRoot && canWrite,
          onTap: onEnterSelect,
        ),
        FileTreeToolbarButton(
          icon: LucideIcons.trash2,
          tooltip: '回收站',
          enabled: hasRoot && canWrite,
          onTap: onOpenTrash,
        ),
        const Spacer(),
        FileTreeSortMenuButton(
          mode: sortMode,
          enabled: hasRoot,
          onSelected: onSortSelected,
        ),
        FileTreeToolbarButton(
          icon: showHidden ? LucideIcons.eye : LucideIcons.eyeOff,
          tooltip: showHidden ? '隐藏隐藏文件' : '显示隐藏文件',
          enabled: hasRoot,
          onTap: onToggleHidden,
        ),
        FileTreeToolbarButton(
          icon: LucideIcons.refreshCw,
          tooltip: '刷新',
          enabled: hasRoot,
          onTap: onRefresh,
        ),
        FileTreeToolbarButton(
          icon: LucideIcons.chevronsDownUp,
          tooltip: '全部折叠',
          enabled: hasRoot,
          onTap: onCollapseAll,
        ),
      ],
    );
  }
}

/// The tree toolbar in multi-select mode: selection count + batch
/// move/copy/delete and the exit button.
class FileTreeSelectionToolbar extends StatelessWidget {
  const FileTreeSelectionToolbar({
    super.key,
    required this.selectedCount,
    required this.actionsEnabled,
    required this.onMove,
    required this.onCopy,
    required this.onDelete,
    required this.onExit,
  });

  final int selectedCount;

  /// Whether the batch actions are enabled (writable backend + selection).
  final bool actionsEnabled;
  final VoidCallback onMove;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(
            '已选 $selectedCount 项',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        FileTreeToolbarButton(
          icon: LucideIcons.cornerUpRight,
          tooltip: '移动到…',
          enabled: actionsEnabled,
          onTap: onMove,
        ),
        FileTreeToolbarButton(
          icon: LucideIcons.copy,
          tooltip: '复制到…',
          enabled: actionsEnabled,
          onTap: onCopy,
        ),
        FileTreeToolbarButton(
          icon: LucideIcons.trash2,
          tooltip: '删除（移入回收站）',
          enabled: actionsEnabled,
          onTap: onDelete,
        ),
        FileTreeToolbarButton(
          icon: LucideIcons.x,
          tooltip: '退出多选',
          onTap: onExit,
        ),
      ],
    );
  }
}

class FileTreeToolbarButton extends StatelessWidget {
  const FileTreeToolbarButton({
    super.key,
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

/// 排序方式下拉菜单（名称/修改时间/大小，目录始终优先）。
class FileTreeSortMenuButton extends StatelessWidget {
  const FileTreeSortMenuButton({
    super.key,
    required this.mode,
    required this.enabled,
    required this.onSelected,
  });

  final TreeSortMode mode;
  final bool enabled;
  final ValueChanged<TreeSortMode> onSelected;

  static const _labels = {
    TreeSortMode.nameAsc: '名称',
    TreeSortMode.mtimeDesc: '修改时间',
    TreeSortMode.sizeDesc: '大小',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = enabled
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface.withValues(alpha: 0.30);
    return PopupMenuButton<TreeSortMode>(
      tooltip: '排序：${_labels[mode]}',
      enabled: enabled,
      initialValue: mode,
      onSelected: onSelected,
      icon: Icon(LucideIcons.arrowDownUp, size: 18, color: color),
      iconSize: 18,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      itemBuilder: (context) => [
        for (final m in TreeSortMode.values)
          PopupMenuItem(
            value: m,
            height: 40,
            child: Row(
              children: [
                Icon(
                  LucideIcons.check,
                  size: 16,
                  color: m == mode
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                ),
                const SizedBox(width: 8),
                Text(_labels[m]!),
              ],
            ),
          ),
      ],
    );
  }
}
