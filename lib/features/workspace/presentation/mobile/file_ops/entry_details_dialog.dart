import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_placeholders.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/readable_path.dart';

/// The 「详情」 dialog: name / type / size / mtime / readable path, plus a
/// copy-path shortcut. The path shown is the display-only readable form.
class EntryDetailsDialog extends StatelessWidget {
  const EntryDetailsDialog({
    super.key,
    required this.entry,
    required this.onCopyPath,
  });

  final WorkspaceEntry entry;
  final VoidCallback onCopyPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <(String, String)>[
      ('名称', entry.name),
      ('类型', fileTypeLabel(entry)),
      if (!entry.isDirectory) ('大小', formatBytes(entry.size)),
      ('修改时间', formatMtime(entry.mtime)),
      ('路径', readableWorkspacePath(entry.path)),
    ];
    return AlertDialog(
      title: const Text('详情'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
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
                      child: Text(value, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCopyPath();
          },
          child: const Text('复制路径'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
