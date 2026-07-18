import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// The long-press menu actions for a file-tree entry. Which ones show depends
/// on the entry (file/dir), the backend's writability and protection flags —
/// see [EntryActionSheet].
enum FileEntryAction {
  newFile,
  newFolder,
  rename,
  cut,
  copyToClipboard,
  paste,
  duplicate,
  move,
  copy,
  copyPath,
  details,
  gitDiff,
  fileHistory,
  share,
  delete,
}

/// The bottom-sheet body for an entry's long-press menu. Pops the picked
/// [FileEntryAction] as the sheet's result.
class EntryActionSheet extends StatelessWidget {
  const EntryActionSheet({
    super.key,
    required this.entry,
    this.protected = false,
    this.writable = true,
    this.canPaste = false,
    this.showGitDiff = false,
    this.showFileHistory = false,
    this.showShare = false,
  });

  final WorkspaceEntry entry;

  /// Protected entries (storage mount points) hide the destructive actions.
  final bool protected;

  /// Read-only backends only get the non-mutating actions (复制路径/详情).
  final bool writable;

  /// Whether the file-tree clipboard holds something pasteable here (writable
  /// backend + clipboard from the same workspace). 目录粘贴到其内部，文件
  /// 粘贴到其所在目录。
  final bool canPaste;

  /// Whether to offer 「Git 对比」 (the entry has a git working-tree status).
  final bool showGitDiff;

  /// Whether to offer 「文件历史」（应用级 checkpoint 快照，files only）。
  final bool showFileHistory;

  /// Whether to offer 「用其他应用打开/分享」 (files only).
  final bool showShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDir = entry.isDirectory;
    // 写操作组（新建/重命名/移动/复制到…）与「复制路径/详情」信息组之间加
    // 分隔线；有写操作时才需要分隔。
    final hasWriteGroup = writable && (isDir || !protected);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (writable && isDir) ...[
            const _ActionTile(
              icon: LucideIcons.filePlus,
              label: '在此新建文件',
              action: FileEntryAction.newFile,
            ),
            const _ActionTile(
              icon: LucideIcons.folderPlus,
              label: '在此新建文件夹',
              action: FileEntryAction.newFolder,
            ),
          ],
          if (writable && !protected) ...[
            const _ActionTile(
              icon: LucideIcons.pencil,
              label: '重命名',
              action: FileEntryAction.rename,
            ),
            const _ActionTile(
              icon: LucideIcons.scissors,
              label: '剪切',
              action: FileEntryAction.cut,
            ),
          ],
          if (writable) ...[
            const _ActionTile(
              icon: LucideIcons.files,
              label: '复制',
              action: FileEntryAction.copyToClipboard,
            ),
            if (canPaste)
              _ActionTile(
                icon: LucideIcons.clipboardPaste,
                label: isDir ? '粘贴到此' : '粘贴到所在目录',
                action: FileEntryAction.paste,
              ),
            const _ActionTile(
              icon: LucideIcons.copyPlus,
              label: '创建副本',
              action: FileEntryAction.duplicate,
            ),
          ],
          if (writable && !protected)
            const _ActionTile(
              icon: LucideIcons.cornerUpRight,
              label: '移动到…',
              action: FileEntryAction.move,
            ),
          if (writable)
            const _ActionTile(
              icon: LucideIcons.copy,
              label: '复制到…',
              action: FileEntryAction.copy,
            ),
          if (hasWriteGroup) const _MenuDivider(),
          const _ActionTile(
            icon: LucideIcons.clipboardCopy,
            label: '复制路径',
            action: FileEntryAction.copyPath,
          ),
          const _ActionTile(
            icon: LucideIcons.info,
            label: '详情',
            action: FileEntryAction.details,
          ),
          if (showGitDiff)
            const _ActionTile(
              icon: LucideIcons.fileDiff,
              label: 'Git 对比',
              action: FileEntryAction.gitDiff,
            ),
          if (showFileHistory)
            const _ActionTile(
              icon: LucideIcons.history,
              label: '文件历史',
              action: FileEntryAction.fileHistory,
            ),
          if (showShare)
            const _ActionTile(
              icon: LucideIcons.share2,
              label: '用其他应用打开/分享',
              action: FileEntryAction.share,
            ),
          if (writable && !protected) ...[
            const _MenuDivider(),
            const _ActionTile(
              icon: LucideIcons.trash2,
              label: '删除',
              action: FileEntryAction.delete,
              destructive: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Thin inset divider between the action-sheet's groups.
class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 20, endIndent: 20);
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.action,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final FileEntryAction action;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : null;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      minLeadingWidth: 0,
      horizontalTitleGap: 12,
      leading: Icon(icon, size: 19, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: () => Navigator.of(context).pop(action),
    );
  }
}
