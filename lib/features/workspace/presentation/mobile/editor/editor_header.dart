// Header row for the middle-page file editor: file name + opaque path on the
// left, caller-supplied action buttons (edit/save/find) plus a close button on
// the right. Pure presentation — all behavior lives in the parent editor.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class EditorHeader extends StatelessWidget {
  const EditorHeader({
    super.key,
    required this.name,
    required this.path,
    required this.dirty,
    required this.topPad,
    required this.actions,
    required this.onClose,
  });

  final String name;
  final String path;

  /// Shows a leading dot before the name when there are unsaved edits.
  final bool dirty;
  final double topPad;
  final List<Widget> actions;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, topPad, 4, 8),
      child: Row(
        children: [
          Icon(
            LucideIcons.fileText,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dirty ? '• $name' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ...actions,
          IconButton(
            tooltip: '关闭',
            icon: const Icon(LucideIcons.x, size: 18),
            color: theme.colorScheme.onSurfaceVariant,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
