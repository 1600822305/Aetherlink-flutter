import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/file_editor_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/file_editor_result.dart';

/// Aggregates a run of consecutive `@aether/file-editor` write tool calls into
/// a single "本次改动 · N 个文件" card (Cursor/Windsurf changeset), with each
/// file's edit card nested inside and an aggregate `+X −M` badge.
class FileEditorChangesetView extends StatefulWidget {
  const FileEditorChangesetView({required this.blocks, super.key});

  final List<ToolBlock> blocks;

  @override
  State<FileEditorChangesetView> createState() =>
      _FileEditorChangesetViewState();
}

class _FileEditorChangesetViewState extends State<FileEditorChangesetView> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headerBg = isDark
        ? theme.colorScheme.surface.withValues(alpha: 0.5)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    var added = 0;
    var removed = 0;
    for (final b in widget.blocks) {
      final r = parseFileEditorResult(b);
      added += r.addedOrZero;
      removed += r.removedOrZero;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              color: headerBg,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(LucideIcons.filePen, size: 15,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '本次改动 · ${widget.blocks.length} 个文件',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (added > 0)
                    Text('+$added',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF22863A),
                            fontWeight: FontWeight.w700,
                            fontSize: 11)),
                  if (added > 0 && removed > 0) const SizedBox(width: 5),
                  if (removed > 0)
                    Text('−$removed',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFCB2431),
                            fontWeight: FontWeight.w700,
                            fontSize: 11)),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(LucideIcons.chevronRight, size: 14,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final b in widget.blocks)
                    FileEditorBlockView(block: b, key: ValueKey(b.id)),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
