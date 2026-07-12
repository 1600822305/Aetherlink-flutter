import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_git_status.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

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
                isDir
                    ? (expanded ? LucideIcons.folderOpen : LucideIcons.folder)
                    : _fileIcon(entry.name),
                size: 18,
                color: isDir || selected
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
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

  static const Map<String, IconData> _extIcons = {
    // 代码
    'dart': LucideIcons.code,
    'js': LucideIcons.fileCode,
    'mjs': LucideIcons.fileCode,
    'cjs': LucideIcons.fileCode,
    'ts': LucideIcons.fileCode,
    'tsx': LucideIcons.fileCode,
    'jsx': LucideIcons.fileCode,
    'py': LucideIcons.fileCode,
    'java': LucideIcons.fileCode,
    'kt': LucideIcons.fileCode,
    'swift': LucideIcons.fileCode,
    'c': LucideIcons.fileCode,
    'h': LucideIcons.fileCode,
    'cpp': LucideIcons.fileCode,
    'hpp': LucideIcons.fileCode,
    'cs': LucideIcons.fileCode,
    'go': LucideIcons.fileCode,
    'rs': LucideIcons.fileCode,
    'rb': LucideIcons.fileCode,
    'php': LucideIcons.fileCode,
    'lua': LucideIcons.fileCode,
    // 网页/样式
    'html': LucideIcons.globe,
    'htm': LucideIcons.globe,
    'css': LucideIcons.palette,
    'scss': LucideIcons.palette,
    'less': LucideIcons.palette,
    // 脚本/终端
    'sh': LucideIcons.fileTerminal,
    'bash': LucideIcons.fileTerminal,
    'zsh': LucideIcons.fileTerminal,
    'bat': LucideIcons.fileTerminal,
    'ps1': LucideIcons.fileTerminal,
    // 配置/数据
    'yaml': LucideIcons.settings,
    'yml': LucideIcons.settings,
    'toml': LucideIcons.settings,
    'ini': LucideIcons.settings,
    'env': LucideIcons.settings,
    'properties': LucideIcons.settings,
    'gradle': LucideIcons.settings,
    'json': LucideIcons.fileJson,
    'jsonc': LucideIcons.fileJson,
    'xml': LucideIcons.fileCode2,
    'csv': LucideIcons.fileSpreadsheet,
    'tsv': LucideIcons.fileSpreadsheet,
    'xls': LucideIcons.fileSpreadsheet,
    'xlsx': LucideIcons.fileSpreadsheet,
    'sql': LucideIcons.database,
    'db': LucideIcons.database,
    'sqlite': LucideIcons.database,
    // 文档
    'md': LucideIcons.fileText,
    'txt': LucideIcons.fileText,
    'rst': LucideIcons.fileText,
    'log': LucideIcons.fileText,
    'pdf': LucideIcons.fileText,
    'doc': LucideIcons.fileText,
    'docx': LucideIcons.fileText,
    // 图片
    'png': LucideIcons.image,
    'jpg': LucideIcons.image,
    'jpeg': LucideIcons.image,
    'gif': LucideIcons.image,
    'svg': LucideIcons.image,
    'webp': LucideIcons.image,
    'bmp': LucideIcons.image,
    'ico': LucideIcons.image,
    // 音视频
    'mp3': LucideIcons.fileAudio,
    'wav': LucideIcons.fileAudio,
    'flac': LucideIcons.fileAudio,
    'ogg': LucideIcons.fileAudio,
    'm4a': LucideIcons.fileAudio,
    'mp4': LucideIcons.fileVideo,
    'mkv': LucideIcons.fileVideo,
    'avi': LucideIcons.fileVideo,
    'mov': LucideIcons.fileVideo,
    'webm': LucideIcons.fileVideo,
    // 压缩包/安装包
    'zip': LucideIcons.fileArchive,
    'rar': LucideIcons.fileArchive,
    '7z': LucideIcons.fileArchive,
    'tar': LucideIcons.fileArchive,
    'gz': LucideIcons.fileArchive,
    'bz2': LucideIcons.fileArchive,
    'xz': LucideIcons.fileArchive,
    'apk': LucideIcons.package2,
    'aab': LucideIcons.package2,
    'jar': LucideIcons.package2,
    'deb': LucideIcons.package2,
    // 证书/密钥
    'pem': LucideIcons.fileKey,
    'key': LucideIcons.fileKey,
    'crt': LucideIcons.fileKey,
    'keystore': LucideIcons.fileKey,
    'jks': LucideIcons.fileKey,
    // 字体
    'ttf': LucideIcons.fileType,
    'otf': LucideIcons.fileType,
    'woff': LucideIcons.fileType,
    'woff2': LucideIcons.fileType,
  };

  IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower == 'dockerfile' || lower == 'makefile') {
      return LucideIcons.fileCog;
    }
    if (lower.startsWith('.git')) return LucideIcons.gitBranch;
    final dot = lower.lastIndexOf('.');
    if (dot < 0 || dot == lower.length - 1) return LucideIcons.file;
    return _extIcons[lower.substring(dot + 1)] ?? LucideIcons.file;
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
