// Placeholder bodies shown instead of the text field when a file can't (or
// shouldn't) be opened in the editor: binary content, or a file over the hard
// size cap. Both reuse the [WorkspaceEntry] metadata the file tree already
// carries (name / size / type / mtime) — no extra backend round-trip.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// A centered "can't show this file" panel with an icon, a reason, and a small
/// metadata table. Used for both the binary and the too-large cases.
class UnsupportedFilePlaceholder extends StatelessWidget {
  const UnsupportedFilePlaceholder({
    super.key,
    required this.entry,
    required this.icon,
    required this.title,
    required this.message,
    this.onOpenExternally,
  });

  final WorkspaceEntry entry;
  final IconData icon;
  final String title;
  final String message;

  /// When set, shows a 「用其他应用打开」 escape hatch that exports the file
  /// to the OS share sheet.
  final VoidCallback? onOpenExternally;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: _InfoTable(entry: entry),
            ),
            if (onOpenExternally != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                icon: const Icon(LucideIcons.externalLink, size: 16),
                label: const Text('用其他应用打开'),
                onPressed: onOpenExternally,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoTable extends StatelessWidget {
  const _InfoTable({required this.entry});

  final WorkspaceEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, String)>[
      ('名称', entry.name),
      ('大小', formatBytes(entry.size)),
      ('类型', fileTypeLabel(entry)),
      ('修改时间', formatMtime(entry.mtime)),
    ];
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Human-readable byte size (B / KB / MB), mirroring the editor's own format.
String formatBytes(int n) {
  if (n >= 1 << 20) return '${(n / (1 << 20)).toStringAsFixed(1)} MB';
  if (n >= 1 << 10) return '${(n / (1 << 10)).toStringAsFixed(1)} KB';
  return '$n B';
}

/// A coarse type label derived from the file name's extension (we don't carry
/// a MIME type through [WorkspaceEntry]); falls back to a generic label.
String fileTypeLabel(WorkspaceEntry entry) {
  if (entry.isDirectory) return '文件夹';
  final name = entry.name;
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return '文件';
  return '${name.substring(dot + 1).toUpperCase()} 文件';
}

/// Formats an epoch-millis [mtime] as a local `YYYY-MM-DD HH:MM`; `0` (the
/// "provider didn't supply it" sentinel) renders as a dash.
String formatMtime(int mtime) {
  if (mtime <= 0) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(mtime).toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} '
      '${two(d.hour)}:${two(d.minute)}';
}

/// Convenience builders for the two placeholder variants.
class EditorPlaceholders {
  const EditorPlaceholders._();

  static Widget binary(
    WorkspaceEntry entry, {
    VoidCallback? onOpenExternally,
  }) =>
      UnsupportedFilePlaceholder(
        entry: entry,
        icon: LucideIcons.fileX,
        title: '二进制文件',
        message: '该文件包含非文本内容,暂不支持查看/编辑。',
        onOpenExternally: onOpenExternally,
      );

  static Widget tooLarge(
    WorkspaceEntry entry, {
    VoidCallback? onOpenExternally,
  }) =>
      UnsupportedFilePlaceholder(
        entry: entry,
        icon: LucideIcons.fileWarning,
        title: '文件过大',
        message: '该文件超过可打开上限,暂不支持查看/编辑。',
        onOpenExternally: onOpenExternally,
      );
}
