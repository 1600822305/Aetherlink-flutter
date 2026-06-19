import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';

Widget _card(BuildContext context, {required Widget child}) {
  final theme = Theme.of(context);
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: theme.dividerColor),
    ),
    child: child,
  );
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

const Color _toolSuccessColor = Color(0xFF2E7D32);

/// Renders a `TOOL` block, mirroring `ToolBlock.tsx`: a collapsible card whose
/// header carries a status-driven icon + colour (执行中 转圈 / 错误 / 成功) and
/// the `@toolName` in monospace. Expanding reveals the JSON-pretty-printed
/// 请求参数 and 执行结果 (错误标红), each copyable, separated by a dashed divider.
class ToolBlockView extends StatefulWidget {
  const ToolBlockView({required this.block, super.key});

  final ToolBlock block;

  @override
  State<ToolBlockView> createState() => _ToolBlockViewState();
}

class _ToolBlockViewState extends State<ToolBlockView> {
  bool _expanded = false;

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

    final statusColor = hasError
        ? theme.colorScheme.error
        : isDone
        ? _toolSuccessColor
        : theme.colorScheme.primary;

    final params = _prettyArgs(block.arguments);
    final result = _formatResult(block.content);

    final headerBg = isDark
        ? theme.colorScheme.surface.withValues(alpha: 0.5)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
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
                  _ToolStatusIcon(status: status, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '@$name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (isDone && !hasError) ...[
                    const Text(
                      '✓',
                      style: TextStyle(
                        color: _toolSuccessColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      LucideIcons.chevronRight,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _content(
              context,
              params: params,
              result: result,
              isProcessing: isProcessing,
              hasError: hasError,
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

  Widget _content(
    BuildContext context, {
    required String params,
    required String result,
    required bool isProcessing,
    required bool hasError,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (params.isNotEmpty) _ToolSection(label: '请求参数', text: params),
          if (params.isNotEmpty && (result.isNotEmpty || isProcessing))
            const _DashedDivider(),
          if (isProcessing)
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

/// Status-driven leading glyph for [ToolBlockView]: a spinner while running,
/// an alert circle on error, a check on success.
class _ToolStatusIcon extends StatelessWidget {
  const _ToolStatusIcon({required this.status, required this.color});

  final MessageBlockStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageBlockStatus.error:
        return Icon(LucideIcons.circleAlert, size: 14, color: color);
      case MessageBlockStatus.success:
        return Icon(LucideIcons.check, size: 14, color: color);
      case MessageBlockStatus.paused:
        return Icon(LucideIcons.pause, size: 14, color: color);
      case MessageBlockStatus.pending:
      case MessageBlockStatus.processing:
      case MessageBlockStatus.streaming:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        );
    }
  }
}

/// A labelled, copyable monospace section (请求参数 / 执行结果) inside a tool block.
class _ToolSection extends StatefulWidget {
  const _ToolSection({
    required this.label,
    required this.text,
    this.isError = false,
  });

  final String label;
  final String text;
  final bool isError;

  @override
  State<_ToolSection> createState() => _ToolSectionState();
}

class _ToolSectionState extends State<_ToolSection> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = widget.isError
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: labelColor,
              ),
            ),
            InkWell(
              onTap: _copy,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  _copied ? LucideIcons.check : LucideIcons.copy,
                  size: 12,
                  color: _copied
                      ? _toolSuccessColor
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _ToolPre(text: widget.text, isError: widget.isError),
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
                : theme.colorScheme.onSurfaceVariant,
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
class CitationBlockView extends StatelessWidget {
  const CitationBlockView({required this.block, super.key});

  final CitationBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = <({String title, String? url})>[
      for (final s in block.webSearch ?? const []) (title: s.title, url: s.url),
      for (final s in block.sources ?? const [])
        (title: s.title ?? s.url ?? '', url: s.url),
    ];

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.quote,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '引用来源',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (block.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            AppMarkdown(content: block.content),
          ],
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InkWell(
                onTap: (entries[i].url ?? '').isEmpty
                    ? null
                    : () => _openUrl(entries[i].url!),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}. ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entries[i].title.isEmpty
                            ? (entries[i].url ?? '')
                            : entries[i].title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Renders a `CHART` block. Chart rendering needs a charting dependency (later
/// slice); for now this shows a placeholder card labelled with the chart type.
class ChartBlockView extends StatelessWidget {
  const ChartBlockView({required this.block, super.key});

  final ChartBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _card(
      context,
      child: Row(
        children: [
          Icon(
            LucideIcons.chartColumn,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '图表（${block.chartType.name}）· 即将支持',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a legacy `KNOWLEDGE_REFERENCE` block, mirroring
/// `KnowledgeReferenceBlock.tsx`: the reference content with its source and
/// similarity score.
class KnowledgeReferenceBlockView extends StatelessWidget {
  const KnowledgeReferenceBlockView({required this.block, super.key});

  final KnowledgeReferenceBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = block.source;
    final similarity = block.similarity;
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.bookOpen,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '知识库引用',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (similarity != null)
                Text(
                  '相似度 ${(similarity * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AppMarkdown(content: block.content),
          if (source != null && source.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '来源：$source',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
