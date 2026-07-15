import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_git_status.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_tree/file_tree_icons.dart';

/// A single entry row in the workspace file tree: expand chevron (dirs),
/// type icon, name with git tint, git badge and the multi-select check.
class FileTreeRow extends StatelessWidget {
  const FileTreeRow({
    super.key,
    required this.entry,
    required this.depth,
    required this.expanded,
    required this.selected,
    required this.onTap,
    this.gitStatus,
    this.onLongPress,
    this.checked,
  });

  final WorkspaceEntry entry;
  final int depth;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  /// Git working-tree state for the badge / name tint (null ⇒ clean).
  final GitFileStatus? gitStatus;
  final VoidCallback? onLongPress;

  /// Multi-select state: null ⇒ not selecting; true/false ⇒ the row shows a
  /// trailing check indicator.
  final bool? checked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDir = entry.isDirectory;

    final scheme = theme.colorScheme;
    final accent = selected ? scheme.primary : Colors.transparent;
    final gitColor = switch (gitStatus) {
      null => null,
      GitFileStatus.modified => Colors.orange,
      GitFileStatus.added || GitFileStatus.untracked => Colors.green,
      GitFileStatus.renamed => Colors.blue,
      GitFileStatus.deleted || GitFileStatus.conflicted => scheme.error,
    };
    final treeIcon = isDir
        ? fileTreeDirIcon(entry.name, expanded: expanded)
        : fileTreeFileIcon(entry.name);
    final gitLetter = switch (gitStatus) {
      null => '',
      GitFileStatus.modified => 'M',
      GitFileStatus.added => 'A',
      GitFileStatus.untracked => 'U',
      GitFileStatus.deleted => 'D',
      GitFileStatus.renamed => 'R',
      GitFileStatus.conflicted => 'C',
    };
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 9.0 + depth * 16,
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
                        color: scheme.onSurfaceVariant,
                      )
                    : null,
              ),
              Icon(
                treeIcon.icon,
                size: 18,
                color: selected
                    ? scheme.primary
                    : treeIcon.color ?? scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected ? scheme.primary : gitColor,
                    fontWeight: isDir || selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (gitColor != null) ...[
                const SizedBox(width: 6),
                Text(
                  isDir ? '•' : gitLetter,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: gitColor,
                  ),
                ),
              ],
              if (checked != null) ...[
                const SizedBox(width: 8),
                Icon(
                  checked!
                      ? LucideIcons.squareCheck
                      : LucideIcons.square,
                  size: 17,
                  color: checked!
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}

/// The spinner row shown under a directory while its listing loads.
class FileTreeLoadingRow extends StatelessWidget {
  const FileTreeLoadingRow({super.key, required this.depth});

  final int depth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 12.0 + depth * 16 + 18, top: 8, bottom: 8),
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
