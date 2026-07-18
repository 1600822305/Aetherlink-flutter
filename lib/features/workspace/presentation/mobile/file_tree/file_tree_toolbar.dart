import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_tree_sort.dart';

/// The tree toolbar in normal mode: the high-frequency actions (new
/// file/folder, search, git review) stay pinned; everything low-frequency
/// (multi-select, trash, sort, hidden-files toggle, refresh, collapse-all)
/// lives in the trailing overflow menu.
class FileTreeToolbar extends StatelessWidget {
  const FileTreeToolbar({
    super.key,
    required this.hasRoot,
    required this.canWrite,
    required this.canCreate,
    required this.showHidden,
    required this.sortMode,
    required this.gitEnabled,
    required this.gitChangeCount,
    required this.onOpenGit,
    required this.onNewFile,
    required this.onNewFolder,
    required this.onOpenSearch,
    required this.onEnterSelect,
    required this.onOpenTrash,
    required this.onSortSelected,
    required this.onToggleHidden,
    required this.onRefresh,
    required this.onCollapseAll,
    this.canPaste = false,
    this.onPasteToRoot,
    this.onToggleFilter,
    this.onImportToRoot,
  });

  final bool hasRoot;
  final bool canWrite;

  /// Whether the file-tree clipboard holds something pasteable — shows the
  /// 「粘贴到根目录」 overflow item.
  final bool canPaste;
  final VoidCallback? onPasteToRoot;

  /// Toggles the quick-filter bar under the toolbar (树内按名过滤).
  final VoidCallback? onToggleFilter;

  /// 从系统文件选择器导入文件到工作区根目录。
  final VoidCallback? onImportToRoot;

  /// Whether the new-file/new-folder buttons are enabled (ops built + writable).
  final bool canCreate;
  final bool showHidden;
  final TreeSortMode sortMode;

  /// Whether the workspace root sits inside a git repo (exec backend +
  /// resolved status snapshot) — gates the git button.
  final bool gitEnabled;

  /// Number of changed files shown as the git button's badge (0 hides it).
  final int gitChangeCount;
  final VoidCallback onOpenGit;
  final VoidCallback onNewFile;
  final VoidCallback onNewFolder;
  final VoidCallback onOpenSearch;
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
          icon: LucideIcons.search,
          tooltip: '搜索文件',
          enabled: hasRoot,
          onTap: onOpenSearch,
        ),
        FileTreeGitButton(
          enabled: gitEnabled,
          changeCount: gitChangeCount,
          onTap: onOpenGit,
        ),
        const Spacer(),
        FileTreeOverflowMenuButton(
          hasRoot: hasRoot,
          canWrite: canWrite,
          canPaste: canPaste,
          onPasteToRoot: onPasteToRoot,
          onToggleFilter: onToggleFilter,
          onImportToRoot: onImportToRoot,
          showHidden: showHidden,
          sortMode: sortMode,
          onEnterSelect: onEnterSelect,
          onOpenTrash: onOpenTrash,
          onSortSelected: onSortSelected,
          onToggleHidden: onToggleHidden,
          onRefresh: onRefresh,
          onCollapseAll: onCollapseAll,
        ),
      ],
    );
  }
}

/// The trailing `⋯` menu holding the low-frequency tree actions: multi-select,
/// trash, refresh, collapse-all, the hidden-files toggle and the sort modes.
class FileTreeOverflowMenuButton extends StatelessWidget {
  const FileTreeOverflowMenuButton({
    super.key,
    required this.hasRoot,
    required this.canWrite,
    required this.showHidden,
    required this.sortMode,
    this.canPaste = false,
    this.onPasteToRoot,
    this.onToggleFilter,
    this.onImportToRoot,
    required this.onEnterSelect,
    required this.onOpenTrash,
    required this.onSortSelected,
    required this.onToggleHidden,
    required this.onRefresh,
    required this.onCollapseAll,
  });

  final bool hasRoot;
  final bool canWrite;
  final bool showHidden;
  final TreeSortMode sortMode;

  /// Shows the 「粘贴到根目录」 item when the clipboard holds something.
  final bool canPaste;
  final VoidCallback? onPasteToRoot;

  /// Toggles the quick-filter bar (树内按名过滤).
  final VoidCallback? onToggleFilter;

  /// 从系统文件选择器导入文件到工作区根目录。
  final VoidCallback? onImportToRoot;
  final VoidCallback onEnterSelect;
  final VoidCallback onOpenTrash;
  final ValueChanged<TreeSortMode> onSortSelected;
  final VoidCallback onToggleHidden;
  final VoidCallback onRefresh;
  final VoidCallback onCollapseAll;

  static const _sortLabels = {
    TreeSortMode.nameAsc: '名称',
    TreeSortMode.mtimeDesc: '修改时间',
    TreeSortMode.sizeDesc: '大小',
  };

  PopupMenuItem<VoidCallback> _action(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return PopupMenuItem(
      value: onTap,
      enabled: enabled,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = hasRoot
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface.withValues(alpha: 0.30);
    return PopupMenuButton<VoidCallback>(
      popUpAnimationStyle: AnimationStyle.noAnimation,
      tooltip: '更多',
      enabled: hasRoot,
      onSelected: (action) => action(),
      icon: Icon(LucideIcons.ellipsis, size: 18, color: color),
      iconSize: 18,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      itemBuilder: (context) => [
        if (canPaste && onPasteToRoot != null)
          _action(
            LucideIcons.clipboardPaste,
            '粘贴到根目录',
            onPasteToRoot!,
            enabled: canWrite,
          ),
        if (onToggleFilter != null)
          _action(LucideIcons.listFilter, '过滤', onToggleFilter!),
        if (onImportToRoot != null)
          _action(
            LucideIcons.import,
            '导入文件',
            onImportToRoot!,
            enabled: canWrite,
          ),
        _action(
          LucideIcons.squareCheck,
          '多选',
          onEnterSelect,
          enabled: canWrite,
        ),
        _action(
          LucideIcons.trash2,
          '回收站',
          onOpenTrash,
          enabled: canWrite,
        ),
        _action(LucideIcons.refreshCw, '刷新', onRefresh),
        _action(LucideIcons.chevronsDownUp, '全部折叠', onCollapseAll),
        _action(
          showHidden ? LucideIcons.eyeOff : LucideIcons.eye,
          showHidden ? '隐藏隐藏文件' : '显示隐藏文件',
          onToggleHidden,
        ),
        const PopupMenuDivider(),
        for (final m in TreeSortMode.values)
          PopupMenuItem(
            value: () => onSortSelected(m),
            height: 40,
            child: Row(
              children: [
                Icon(
                  LucideIcons.check,
                  size: 16,
                  color: m == sortMode
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                ),
                const SizedBox(width: 10),
                Text('排序：${_sortLabels[m]}'),
              ],
            ),
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

/// Git 变更入口按钮：带改动数角标，仅在工作区位于 git 仓库内时可点。
class FileTreeGitButton extends StatelessWidget {
  const FileTreeGitButton({
    super.key,
    required this.enabled,
    required this.changeCount,
    required this.onTap,
  });

  final bool enabled;
  final int changeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final button = FileTreeToolbarButton(
      icon: LucideIcons.gitBranch,
      tooltip: 'Git 变更',
      enabled: enabled,
      onTap: onTap,
    );
    if (!enabled || changeCount <= 0) return button;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          right: 4,
          top: 4,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minWidth: 14),
              child: Text(
                changeCount > 99 ? '99+' : '$changeCount',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

