// Leaf widgets for the file editor body: the monospace text area (read-only or
// editable), the "too large → preview only" banner, and the read error state.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_text_area.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/find_replace_engine.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/read_only_code_view.dart';

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
    this.placeholderBuilder,
    this.findMatches = const <TextMatch>[],
    this.findIndex = -1,
  });

  final Future<void> ready;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool editing;
  final double fontSize;
  final ValueChanged<double> onFontSize;
  final VoidCallback onRetry;

  /// Live find state, forwarded to the read-only viewer for match
  /// highlighting and scroll-to-match (the editable field highlights via its
  /// own selection instead).
  final List<TextMatch> findMatches;
  final int findIndex;

  /// Returns a non-null widget (binary / too-large placeholder) to show instead
  /// of the text area once the load completes; null means "show the editor".
  final Widget? Function()? placeholderBuilder;

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
        final placeholder = placeholderBuilder?.call();
        if (placeholder != null) return placeholder;
        // View mode renders through the virtualized per-line viewer, so large
        // files scroll smoothly; the whole-document TextField is only paid
        // for when actually editing.
        if (!editing) {
          return ReadOnlyCodeView(
            controller: controller,
            fontSize: fontSize,
            onFontSize: onFontSize,
            findMatches: findMatches,
            findIndex: findIndex,
          );
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

/// IDE-style bottom status bar: total lines · characters · caret line:column
/// (and selection length when a range is selected). Listens to the controller
/// so it updates on both edits and caret moves, but rebuilds only itself (not
/// the whole editor) and recomputes the O(text) line/char counts solely when
/// the text actually changes — caret-only moves reuse the cached counts.
class EditorStatusBar extends StatefulWidget {
  const EditorStatusBar({super.key, required this.controller});

  final TextEditingController controller;

  @override
  State<EditorStatusBar> createState() => _EditorStatusBarState();
}

class _EditorStatusBarState extends State<EditorStatusBar> {
  String _cachedText = '\u0000__uncomputed__';
  int _lineCount = 1;
  int _charCount = 0;
  // Line start offsets, recomputed only when the text changes, so the caret
  // line/column is a binary search per caret move instead of an O(offset)
  // substring + rescan.
  List<int> _lineStarts = const [0];

  // 0-based index of the line containing [offset].
  int _lineOfOffset(int offset) {
    var lo = 0;
    var hi = _lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant EditorStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = widget.controller.value;
    final text = value.text;
    if (text != _cachedText) {
      _cachedText = text;
      final starts = <int>[0];
      for (var i = 0; i < text.length; i++) {
        if (text.codeUnitAt(i) == 0x0A) starts.add(i + 1);
      }
      _lineStarts = starts;
      _lineCount = starts.length;
      _charCount = text.characters.length;
    }
    final lineCount = _lineCount;
    final charCount = _charCount;

    final sel = value.selection;
    String caretLabel;
    if (sel.isValid) {
      final offset = sel.extentOffset.clamp(0, text.length);
      final lineIdx = _lineOfOffset(offset);
      final line = lineIdx + 1;
      final col = offset - _lineStarts[lineIdx] + 1;
      final selected = (sel.end - sel.start).abs();
      caretLabel = selected > 0
          ? '行 $line, 列 $col  (已选 $selected)'
          : '行 $line, 列 $col';
    } else {
      caretLabel = '—';
    }

    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text('$lineCount 行 · $charCount 字符', style: style),
          const Spacer(),
          Text(caretLabel, style: style),
        ],
      ),
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

/// Banner shown when the open file changed on disk (an in-app mutation from a
/// file-op or the `@aether/file-editor` agent). When the buffer has no unsaved
/// edits the editor re-syncs silently and this never appears; it only surfaces
/// when there's a conflict to resolve, or the file was deleted / moved.
///
/// [onReload] is null when there's nothing safe to reload to (deleted / moved /
/// non-editable kinds); [onDismiss] hides the banner without touching content.
class ExternalChangeBanner extends StatelessWidget {
  const ExternalChangeBanner({
    super.key,
    required this.text,
    this.onReload,
    required this.onDismiss,
  });

  final String text;
  final VoidCallback? onReload;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      child: Row(
        children: [
          Icon(
            LucideIcons.fileWarning,
            size: 16,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (onReload != null)
            TextButton(
              onPressed: onReload,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onErrorContainer,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('重新加载'),
            ),
          IconButton(
            tooltip: '忽略',
            visualDensity: VisualDensity.compact,
            color: theme.colorScheme.onErrorContainer,
            icon: const Icon(LucideIcons.x, size: 16),
            onPressed: onDismiss,
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
