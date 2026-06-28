import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/shared/widgets/copy_icon_button.dart';

/// Lightweight chip that renders a tool call inside a thinking block.
///
/// Mirrors `InlineToolChip.tsx`: tool name + status icon in a compact row,
/// tappable to expand and show arguments / result JSON.
class InlineToolChip extends StatefulWidget {
  const InlineToolChip({required this.block, super.key});

  final ToolBlock block;

  @override
  State<InlineToolChip> createState() => _InlineToolChipState();
}

class _InlineToolChipState extends State<InlineToolChip> {
  bool _expanded = false;

  // Cached formatted strings to avoid JSON re-encoding on every rebuild
  // (InlineToolChip lives inside ThinkingBlock which rebuilds frequently).
  String? _cachedParams;
  String? _cachedResult;
  Object? _lastArgs;
  Object? _lastContent;

  bool get _isProcessing =>
      widget.block.status == MessageBlockStatus.streaming ||
      widget.block.status == MessageBlockStatus.processing ||
      widget.block.status == MessageBlockStatus.pending;

  bool get _hasError => widget.block.status == MessageBlockStatus.error;

  String get _toolName => widget.block.toolName ?? '工具调用';

  Color _statusColor(ThemeData theme) {
    if (_hasError) return theme.colorScheme.error;
    if (_isProcessing) return Colors.amber.shade700;
    return Colors.green;
  }

  String _formatParams() {
    final args = widget.block.arguments;
    if (args == null || args.isEmpty) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(args);
    } catch (_) {
      return args.toString();
    }
  }

  String _formatResult() {
    final content = widget.block.content;
    if (content == null) return '';
    if (content is String) {
      if (content.isEmpty) return '';
      // Try pretty-printing if it's JSON
      try {
        final decoded = jsonDecode(content);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        return content;
      }
    }
    try {
      return const JsonEncoder.withIndent('  ').convert(content);
    } catch (_) {
      return content.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _statusColor(theme);
    if (!identical(widget.block.arguments, _lastArgs)) {
      _lastArgs = widget.block.arguments;
      _cachedParams = _formatParams();
    }
    if (!identical(widget.block.content, _lastContent)) {
      _lastContent = widget.block.content;
      _cachedResult = _formatResult();
    }
    final params = _cachedParams ?? '';
    final result = _cachedResult ?? '';
    final hasDetails = params.isNotEmpty || result.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
        color: statusColor.withValues(alpha: isDark ? 0.08 : 0.05),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          InkWell(
            onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.wrench,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _toolName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _StatusIcon(
                    isProcessing: _isProcessing,
                    hasError: _hasError,
                    color: statusColor,
                  ),
                  if (hasDetails) ...[
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expandable details
          if (_expanded && hasDetails)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (params.isNotEmpty) ...[
                    _DetailSection(
                      label: '参数',
                      content: params,
                      theme: theme,
                    ),
                    if (result.isNotEmpty) const SizedBox(height: 6),
                  ],
                  if (result.isNotEmpty)
                    _DetailSection(
                      label: '结果',
                      content: result,
                      theme: theme,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Spinning loader / check / error icon for the tool status.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({
    required this.isProcessing,
    required this.hasError,
    required this.color,
  });

  final bool isProcessing;
  final bool hasError;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (isProcessing) {
      return SizedBox(
        width: 13,
        height: 13,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
      );
    }
    if (hasError) {
      return Icon(LucideIcons.circleAlert, size: 13, color: color);
    }
    return Icon(LucideIcons.circleCheck, size: 13, color: color);
  }
}

/// A labeled pre-formatted code section with a copy button.
class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.label,
    required this.content,
    required this.theme,
  });

  final String label;
  final String content;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            CopyIconButton(
              text: content,
              size: 11,
              padding: const EdgeInsets.all(2),
              borderRadius: 4,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(maxHeight: 160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
          ),
          child: SingleChildScrollView(
            child: Text(
              content,
              style: TextStyle(
                fontSize: 10.5,
                fontFamily: 'monospace',
                height: 1.4,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
