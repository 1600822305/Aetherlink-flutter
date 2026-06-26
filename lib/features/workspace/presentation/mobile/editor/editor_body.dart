// Leaf widgets for the file editor body: the monospace text area (read-only or
// editable), the "too large → preview only" banner, and the read error state.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_text_area.dart';

/// Outcome of the unsaved-changes prompt shown when leaving a dirty file.
enum LeaveAction { save, discard, cancel }

Future<LeaveAction?> showUnsavedDialog(BuildContext context, String name) {
  return showDialog<LeaveAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('未保存的修改'),
      content: Text('文件「$name」有未保存的修改,如何处理?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(LeaveAction.cancel),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(LeaveAction.discard),
          child: const Text('放弃'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(LeaveAction.save),
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

/// The editor's main content: loading spinner, read error, or the text area.
class EditorContent extends StatelessWidget {
  const EditorContent({
    super.key,
    required this.ready,
    required this.controller,
    required this.focusNode,
    required this.editing,
    required this.fontSize,
    required this.onFontSize,
    required this.onRetry,
  });

  final Future<void> ready;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool editing;
  final double fontSize;
  final ValueChanged<double> onFontSize;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: ready,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snap.hasError) {
          return EditorErrorBody(message: '${snap.error}', onRetry: onRetry);
        }
        return EditorTextArea(
          controller: controller,
          focusNode: focusNode,
          editing: editing,
          fontSize: fontSize,
          onFontSize: onFontSize,
        );
      },
    );
  }
}

class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(
            LucideIcons.fileWarning,
            size: 16,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EditorErrorBody extends StatelessWidget {
  const EditorErrorBody({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.triangleAlert,
              size: 28,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text('读取失败', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
