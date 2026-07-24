import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_confirmation_service.dart';
import 'package:aetherlink_flutter/shared/widgets/copy_icon_button.dart';

const Color _toolSuccessColor = Color(0xFF2E7D32);

/// Renders a `TOOL` block as a minimal timeline row: a thin vertical rail
/// with a status dot (执行中 转圈 / 错误 / 成功) beside the tool name in
/// monospace—consecutive tool rows visually chain into a timeline. Tapping
/// expands an inset panel with the JSON-pretty-printed 请求参数 and 执行结果
/// (错误标红), each copyable.
class ToolBlockView extends ConsumerStatefulWidget {
  const ToolBlockView({required this.block, super.key});

  final ToolBlock block;

  @override
  ConsumerState<ToolBlockView> createState() => _ToolBlockViewState();
}

class _ToolBlockViewState extends ConsumerState<ToolBlockView> {
  bool _expanded = false;

  // Cached formatted strings to avoid JSON re-encoding on every rebuild.
  String? _cachedParams;
  String? _cachedResult;
  Object? _lastArgs;
  Object? _lastContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final block = widget.block;
    final name = block.toolName ?? block.toolId;
    final status = block.status;
    final isProcessing =
        status == MessageBlockStatus.pending ||
        status == MessageBlockStatus.processing ||
        status == MessageBlockStatus.streaming;
    final hasError = status == MessageBlockStatus.error;
    final isDone = status == MessageBlockStatus.success;

    // Check if this block is awaiting user confirmation.
    final needsConfirmation =
        block.metadata?['needsConfirmation'] == true && isProcessing;
    final pending = needsConfirmation
        ? ref.watch(toolConfirmationProvider)[block.id]
        : null;

    // Auto-expand when a confirmation request is visible.
    if (pending != null && !_expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _expanded = true);
      });
    }

    final statusColor = needsConfirmation
        ? const Color(0xFFF59E0B)
        : hasError
        ? theme.colorScheme.error
        : isDone
        ? _toolSuccessColor
        : theme.colorScheme.primary;

    // Pretty-printing (JSON encode of possibly huge tool results) and the
    // body's text layout are only paid when the card is actually expanded —
    // a collapsed card costs just its header row.
    if (_expanded) {
      if (!identical(block.arguments, _lastArgs)) {
        _lastArgs = block.arguments;
        _cachedParams = _prettyArgs(block.arguments);
      }
      if (!identical(block.content, _lastContent)) {
        _lastContent = block.content;
        _cachedResult = _formatResult(block.content);
      }
    }
    final params = _cachedParams ?? '';
    final result = _cachedResult ?? '';

    final railColor = theme.dividerColor.withValues(alpha: isDark ? 0.5 : 0.7);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 时间线导轨：贯穿整行的竖线 + 状态点，相邻工具行自然连成一条。
            SizedBox(
              width: 14,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned.fill(
                    child: Center(
                      child: Container(width: 1.5, color: railColor),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    child: _TimelineStatusDot(
                      status: status,
                      color: statusColor,
                      needsConfirmation: needsConfirmation,
                      background: theme.colorScheme.surface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                                fontSize: 11.5,
                                color: hasError
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (needsConfirmation) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '需要确认',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 3),
                          AnimatedRotation(
                            turns: _expanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              LucideIcons.chevronRight,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: _expanded
                        ? _content(
                            context,
                            params: params,
                            result: result,
                            isProcessing: isProcessing,
                            hasError: hasError,
                            confirmationRequest: pending,
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context, {
    required String params,
    required String result,
    required bool isProcessing,
    required bool hasError,
    ToolConfirmationRequest? confirmationRequest,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2, bottom: 6, right: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.25,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (params.isNotEmpty) _ToolSection(label: '请求参数', text: params),
          if (params.isNotEmpty &&
              (result.isNotEmpty ||
                  isProcessing ||
                  confirmationRequest != null))
            const _DashedDivider(),
          if (confirmationRequest != null)
            _ConfirmationSection(
              request: confirmationRequest,
              onApprove: (grace) => ref
                  .read(toolConfirmationProvider.notifier)
                  .respond(
                    confirmationRequest.id,
                    approved: true,
                    grace: grace,
                  ),
              onReject: () => ref
                  .read(toolConfirmationProvider.notifier)
                  .respond(confirmationRequest.id, approved: false),
            )
          else if (isProcessing)
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '执行中...',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            )
          else if (result.isNotEmpty)
            _ToolSection(label: '执行结果', text: result, isError: hasError),
        ],
      ),
    );
  }
}

/// Inline confirmation UI for tools that need user approval.
class _ConfirmationSection extends StatelessWidget {
  const _ConfirmationSection({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final ToolConfirmationRequest request;

  /// Approve the operation. [ConfirmationGrace.none] runs it once;
  /// [ConfirmationGrace.fiveMinutes] additionally opens a 5-minute 免确认
  /// window for this same tool.
  final void Function(ConfirmationGrace grace) onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const warningColor = Color(0xFFF59E0B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: warningColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: warningColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.shieldAlert,
                size: 16,
                color: warningColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            _ConfirmButton(
              label: '拒绝',
              color: theme.colorScheme.onSurfaceVariant,
              filled: false,
              onTap: onReject,
            ),
            _ConfirmButton(
              label: '5 分钟内免确认',
              color: theme.colorScheme.primary,
              filled: false,
              onTap: () => onApprove(ConfirmationGrace.fiveMinutes),
            ),
            _ConfirmButton(
              label: '确认执行',
              color: warningColor,
              filled: true,
              onTap: () => onApprove(ConfirmationGrace.none),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: filled ? color : color.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

/// Timeline status dot for [ToolBlockView]: a tiny spinner while running,
/// a shield while awaiting confirmation, otherwise a status-coloured dot.
/// [background] paints a halo so the dot sits cleanly on the rail.
class _TimelineStatusDot extends StatelessWidget {
  const _TimelineStatusDot({
    required this.status,
    required this.color,
    required this.needsConfirmation,
    required this.background,
  });

  final MessageBlockStatus status;
  final Color color;
  final bool needsConfirmation;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final Widget core;
    if (needsConfirmation) {
      core = Icon(LucideIcons.shieldAlert, size: 11, color: color);
    } else {
      switch (status) {
        case MessageBlockStatus.pending:
        case MessageBlockStatus.processing:
        case MessageBlockStatus.streaming:
          core = SizedBox(
            width: 9,
            height: 9,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
          );
        case MessageBlockStatus.error:
        case MessageBlockStatus.success:
        case MessageBlockStatus.paused:
          core = Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          );
      }
    }
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, color: background),
      child: core,
    );
  }
}

/// A labelled, copyable monospace section (请求参数 / 执行结果) inside a tool block.
class _ToolSection extends StatelessWidget {
  const _ToolSection({
    required this.label,
    required this.text,
    this.isError = false,
  });

  final String label;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = isError
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: labelColor,
              ),
            ),
            CopyIconButton(
              text: text,
              size: 12,
              padding: const EdgeInsets.all(2),
              copiedColor: _toolSuccessColor,
            ),
          ],
        ),
        const SizedBox(height: 4),
        _ToolPre(text: text, isError: isError),
      ],
    );
  }
}

/// The monospace, height-capped, scrollable result/params box (`<Pre>` parity).
class _ToolPre extends StatelessWidget {
  const _ToolPre({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 200),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.25)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.5,
            color: isError
                ? theme.colorScheme.error
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// A thin dashed horizontal rule separating 请求参数 from 执行结果.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _DashedLinePainter(Theme.of(context).dividerColor),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const dashGap = 3.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Pretty-prints tool-call arguments as indented JSON (empty when there are
/// none). Mirrors the web `formatParams`.
String _prettyArgs(Map<String, dynamic>? args) {
  if (args == null || args.isEmpty) return '';
  try {
    return const JsonEncoder.withIndent('  ').convert(args);
  } catch (_) {
    return args.toString();
  }
}

/// Formats a tool result for display: JSON-looking strings are pretty-printed,
/// objects are encoded, everything else is shown as-is. Mirrors the web
/// `formatContent` (the Flutter result is already flattened to text/JSON).
String _formatResult(Object? content) {
  if (content == null) return '';
  if (content is String) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';
    return _maybePrettyJson(trimmed);
  }
  try {
    return const JsonEncoder.withIndent('  ').convert(content);
  } catch (_) {
    return content.toString();
  }
}

String _maybePrettyJson(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is Map || decoded is List) {
      return const JsonEncoder.withIndent('  ').convert(decoded);
    }
  } catch (_) {
    // Not JSON — fall through and show the raw text.
  }
  return source;
}

/// Renders a `CITATION` block, mirroring `CitationBlock.tsx`: the citation text
/// plus a numbered list of sources (web search / generic), each opening its URL.
