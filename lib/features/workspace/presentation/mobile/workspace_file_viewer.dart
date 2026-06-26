// The middle page in "file open" state: shows the content of the file selected
// in the left tree, read-only. P0 reads from the shared preview backend
// (mock); swapping in the real SAF backend later only changes the provider.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

class WorkspaceFileViewer extends ConsumerStatefulWidget {
  const WorkspaceFileViewer({
    super.key,
    required this.entry,
    required this.topInset,
  });

  final WorkspaceEntry entry;
  final double topInset;

  @override
  ConsumerState<WorkspaceFileViewer> createState() =>
      _WorkspaceFileViewerState();
}

class _WorkspaceFileViewerState extends ConsumerState<WorkspaceFileViewer> {
  late Future<String> _content;

  @override
  void initState() {
    super.initState();
    _content = _read();
  }

  @override
  void didUpdateWidget(WorkspaceFileViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Tapping a different file reuses this widget — refetch for the new path.
    if (oldWidget.entry.path != widget.entry.path) {
      _content = _read();
    }
  }

  Future<String> _read() =>
      ref.read(workspacePreviewBackendProvider).readFile(widget.entry.path);

  void _close() =>
      ref.read(selectedWorkspaceFileProvider.notifier).clear();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPad = MediaQuery.paddingOf(context).top + widget.topInset + 8;

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12, topPad, 8, 8),
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
                          widget.entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.entry.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '关闭',
                    icon: const Icon(LucideIcons.x, size: 18),
                    color: theme.colorScheme.onSurfaceVariant,
                    onPressed: _close,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: FutureBuilder<String>(
                future: _content,
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
                    return _ErrorBody(
                      message: '${snap.error}',
                      onRetry: () => setState(() => _content = _read()),
                    );
                  }
                  return _ContentBody(text: snap.data ?? '');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentBody extends StatelessWidget {
  const _ContentBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (text.isEmpty) {
      return Center(
        child: Text(
          '(空文件)',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Scrollbar(
      child: SingleChildScrollView(
        primary: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SelectableText(
          text,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

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
            Text(
              '读取失败',
              style: theme.textTheme.titleSmall,
            ),
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
