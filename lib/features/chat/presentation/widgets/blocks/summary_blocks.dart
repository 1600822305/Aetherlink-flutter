import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/context_condense_service.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// Renders a `CONTEXT_SUMMARY` block: a compact card with the summary text
/// and compression stats. Defaults to collapsed (2-line preview + stats);
/// tapping the header expands to show the full summary.
/// Includes a "restore original" button when original message data is available.
class ContextSummaryBlockView extends ConsumerStatefulWidget {
  const ContextSummaryBlockView({required this.block, super.key});

  final ContextSummaryBlock block;

  @override
  ConsumerState<ContextSummaryBlockView> createState() =>
      _ContextSummaryBlockViewState();
}

class _ContextSummaryBlockViewState
    extends ConsumerState<ContextSummaryBlockView> {
  bool _showingSummary = false;
  bool _showingOriginal = false;
  bool _isRestoring = false;

  List<Map<String, dynamic>> get _originalMessages {
    final original = widget.block.metadata?['originalMessages'];
    if (original is List) return original.cast<Map<String, dynamic>>();
    return [];
  }

  bool get _canRestore => _originalMessages.isNotEmpty;

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复原文'),
        content: const Text('确定要恢复被压缩的原始消息吗？摘要将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRestoring = true);
    final service = ref.read(contextCondenseServiceProvider);
    final result = await service.restore(block: widget.block);
    if (!mounted) return;

    if (!result.success) {
      setState(() => _isRestoring = false);
      AppToast.error(context, result.error ?? '恢复失败');
    }
  }

  /// Build a formatted preview of the original messages.
  Widget _buildOriginalPreview(ThemeData theme, ColorScheme cs) {
    final messages = _originalMessages;
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final msg in messages) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg['role'] == 'user' ? '用户' : 'AI',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: msg['role'] == 'user'
                            ? cs.primary
                            : cs.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (msg['content'] as String? ?? '').length > 500
                          ? '${(msg['content'] as String).substring(0, 500)}…'
                          : msg['content'] as String? ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outline.withValues(alpha: 0.1)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (tappable to toggle summary)
          GestureDetector(
            onTap: () => setState(() {
              _showingSummary = !_showingSummary;
              if (_showingSummary) _showingOriginal = false;
            }),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(LucideIcons.scrollText, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '上下文摘要',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _showingSummary
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),

          // Stats bar
          const SizedBox(height: 6),
          Text(
            '${widget.block.originalMessageCount} 条消息 → '
            '${widget.block.compressedTokens} tokens'
            '（节省 ${widget.block.tokensSaved}）',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),

          // Expanded summary content (tapping header toggles this)
          if (_showingSummary) ...[
            Divider(height: 16, color: cs.primary.withValues(alpha: 0.15)),
            AppMarkdown(content: widget.block.content),
          ],

          // Expanded original messages preview
          if (_showingOriginal) ...[
            Divider(height: 16, color: cs.primary.withValues(alpha: 0.15)),
            _buildOriginalPreview(theme, cs),
          ],

          // Action buttons
          if (_canRestore) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                // Preview original button
                InkWell(
                  onTap: () => setState(() {
                    _showingOriginal = !_showingOriginal;
                    if (_showingOriginal) _showingSummary = false;
                  }),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showingOriginal
                              ? LucideIcons.eyeOff
                              : LucideIcons.eye,
                          size: 14,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showingOriginal ? '收起原文' : '预览原文',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Restore button
                _isRestoring
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : InkWell(
                        onTap: _restore,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.undo2,
                                size: 14,
                                color: cs.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '恢复原文',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders a `MEMORY_INJECTION` block: a compact chip showing how many
/// long-term memories were injected into this turn's system prompt. Defaults to
/// collapsed; tapping expands to list the injected memory contents so the user
/// can see exactly what the model was given — the 对话内「本轮注入 N 条记忆」块.
class MemoryInjectionBlockView extends StatefulWidget {
  const MemoryInjectionBlockView({required this.block, super.key});

  final MemoryInjectionBlock block;

  @override
  State<MemoryInjectionBlockView> createState() =>
      _MemoryInjectionBlockViewState();
}

class _MemoryInjectionBlockViewState extends State<MemoryInjectionBlockView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final memories = widget.block.memories;
    final hasDetail = memories.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: hasDetail
                ? () => setState(() => _expanded = !_expanded)
                : null,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(LucideIcons.brain, size: 15, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '本轮注入 ${widget.block.count} 条记忆',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                if (hasDetail)
                  Icon(
                    _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 15,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
          if (_expanded && hasDetail) ...[
            Divider(height: 14, color: cs.primary.withValues(alpha: 0.15)),
            for (var i = 0; i < memories.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      LucideIcons.dot,
                      size: 14,
                      color: cs.primary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      memories[i],
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
