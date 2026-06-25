import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';

/// Markdown builder injected so this shared widget stays free of feature deps.
typedef TimelineMarkdownBuilder =
    Widget Function(BuildContext context, String content, TextStyle? style);

// ---------------------------------------------------------------------------
// Data types for the timeline steps
// ---------------------------------------------------------------------------

/// A single step in the chain-of-thought timeline.
sealed class TimelineStep {
  const TimelineStep();
}

/// A reasoning/thinking segment.
class ReasoningTimelineStep extends TimelineStep {
  const ReasoningTimelineStep({
    required this.content,
    required this.seconds,
    required this.isThinking,
    this.createdAt,
  });

  final String content;
  final double seconds;
  final bool isThinking;
  final DateTime? createdAt;
}

/// A tool call step.
class ToolTimelineStep extends TimelineStep {
  const ToolTimelineStep({required this.block});

  final ToolBlock block;
}

// ---------------------------------------------------------------------------
// ThinkingTimelineView — the main timeline widget
// ---------------------------------------------------------------------------

/// Renders reasoning + tool steps as a vertical timeline with a connecting line,
/// auto-collapsing when steps exceed [collapsedVisibleCount].
///
/// Inspired by RikkaHub's `ChainOfThought` component.
class ThinkingTimelineView extends StatefulWidget {
  const ThinkingTimelineView({
    required this.thinkingContent,
    required this.thinkingSeconds,
    required this.isThinking,
    required this.markdownBuilder,
    this.inlineToolBlocks = const [],
    this.thoughtAutoCollapse = true,
    super.key,
  });

  final String thinkingContent;
  final double thinkingSeconds;
  final bool isThinking;
  final TimelineMarkdownBuilder markdownBuilder;
  final List<ToolBlock> inlineToolBlocks;
  final bool thoughtAutoCollapse;

  @override
  State<ThinkingTimelineView> createState() => _ThinkingTimelineViewState();
}

class _ThinkingTimelineViewState extends State<ThinkingTimelineView> {
  bool _allStepsExpanded = false;
  static const int _collapsedVisibleCount = 2;

  /// Build the list of timeline steps by interleaving reasoning segments and
  /// tool calls. If there are tool calls, we split the thinking content around
  /// them to create the illusion of "thought → tool → thought → tool" flow.
  List<TimelineStep> _buildSteps() {
    final tools = widget.inlineToolBlocks;

    if (tools.isEmpty) {
      // Single reasoning node, no tools
      return [
        ReasoningTimelineStep(
          content: widget.thinkingContent,
          seconds: widget.thinkingSeconds,
          isThinking: widget.isThinking,
        ),
      ];
    }

    // Interleave reasoning and tool steps.
    // Strategy: split the thinking content into N+1 segments where N = number
    // of tool calls. Each segment is the reasoning that happened before / between
    // / after each tool call. Since we don't have exact split points in the text,
    // we show the full thinking content as the first reasoning node, then
    // alternate tool nodes after it.
    //
    // However, if there are multiple tool calls, we can try to be smarter:
    // put reasoning before the first tool, then each tool, then remaining reasoning.
    final steps = <TimelineStep>[];

    // First reasoning segment (the thinking content)
    if (widget.thinkingContent.isNotEmpty) {
      // Calculate approximate per-segment time
      final reasoningTime = tools.isEmpty
          ? widget.thinkingSeconds
          : widget.thinkingSeconds * 0.6; // ~60% for reasoning
      steps.add(ReasoningTimelineStep(
        content: widget.thinkingContent,
        seconds: reasoningTime,
        isThinking: widget.isThinking && tools.every(_isToolPending),
      ));
    }

    // Tool steps
    for (final tool in tools) {
      steps.add(ToolTimelineStep(block: tool));
    }

    // If still thinking (streaming) and all tools are done, add a trailing
    // "thinking..." node to show active reasoning after tools.
    if (widget.isThinking &&
        tools.isNotEmpty &&
        tools.every(_isToolDone)) {
      steps.add(const ReasoningTimelineStep(
        content: '',
        seconds: 0,
        isThinking: true,
      ));
    }

    return steps;
  }

  static bool _isToolPending(ToolBlock b) =>
      b.status == MessageBlockStatus.pending ||
      b.status == MessageBlockStatus.processing ||
      b.status == MessageBlockStatus.streaming;

  static bool _isToolDone(ToolBlock b) =>
      b.status == MessageBlockStatus.success ||
      b.status == MessageBlockStatus.error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final steps = _buildSteps();
    final canCollapse = steps.length > _collapsedVisibleCount;
    final visibleSteps = (_allStepsExpanded || !canCollapse)
        ? steps
        : steps.sublist(steps.length - _collapsedVisibleCount);

    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.85);
    final border = isDark ? Colors.white12 : Colors.black12;
    final lineColor = theme.colorScheme.outlineVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Collapse / expand control (top)
            if (canCollapse)
              _CollapseControl(
                expanded: _allStepsExpanded,
                hiddenCount: steps.length - _collapsedVisibleCount,
                onTap: () =>
                    setState(() => _allStepsExpanded = !_allStepsExpanded),
              ),

            // Timeline with vertical line
            CustomPaint(
              foregroundPainter: _TimelineLinePainter(
                color: lineColor,
                nodeX: 12,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < visibleSteps.length; i++)
                    _buildStep(visibleSteps[i], theme, i == 0, i == visibleSteps.length - 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(TimelineStep step, ThemeData theme, bool isFirst, bool isLast) {
    switch (step) {
      case ReasoningTimelineStep():
        return _ReasoningNode(
          step: step,
          markdownBuilder: widget.markdownBuilder,
          autoCollapse: widget.thoughtAutoCollapse,
        );
      case ToolTimelineStep():
        return _ToolNode(step: step);
    }
  }
}

// ---------------------------------------------------------------------------
// Timeline line painter
// ---------------------------------------------------------------------------

class _TimelineLinePainter extends CustomPainter {
  _TimelineLinePainter({required this.color, required this.nodeX});

  final Color color;
  final double nodeX;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height < 40) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    // Draw vertical line from top offset to bottom offset (avoiding extremes)
    const topOffset = 18.0;
    final bottomOffset = size.height - 18.0;
    if (bottomOffset > topOffset) {
      canvas.drawLine(
        Offset(nodeX, topOffset),
        Offset(nodeX, bottomOffset),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TimelineLinePainter old) =>
      old.color != color || old.nodeX != nodeX;
}

// ---------------------------------------------------------------------------
// Collapse / expand control at the top
// ---------------------------------------------------------------------------

class _CollapseControl extends StatelessWidget {
  const _CollapseControl({
    required this.expanded,
    required this.hiddenCount,
    required this.onTap,
  });

  final bool expanded;
  final int hiddenCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Center(
                child: Icon(
                  expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              expanded ? '收起步骤' : '显示更多 $hiddenCount 个步骤',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reasoning node
// ---------------------------------------------------------------------------

class _ReasoningNode extends StatefulWidget {
  const _ReasoningNode({
    required this.step,
    required this.markdownBuilder,
    required this.autoCollapse,
  });

  final ReasoningTimelineStep step;
  final TimelineMarkdownBuilder markdownBuilder;
  final bool autoCollapse;

  @override
  State<_ReasoningNode> createState() => _ReasoningNodeState();
}

class _ReasoningNodeState extends State<_ReasoningNode> {
  late bool _expanded;
  bool _copied = false;
  Timer? _timer;
  String _lastSecondsLabel = '';

  @override
  void initState() {
    super.initState();
    // If auto-collapse is on, start collapsed unless actively thinking
    _expanded = widget.step.isThinking || !widget.autoCollapse;
    _syncTimer();
  }

  @override
  void didUpdateWidget(_ReasoningNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If stopped thinking and auto-collapse is on, collapse
    if (oldWidget.step.isThinking && !widget.step.isThinking && widget.autoCollapse) {
      _expanded = false;
    }
    _syncTimer();
  }

  void _syncTimer() {
    if (widget.step.isThinking && _timer == null) {
      _lastSecondsLabel = widget.step.seconds.toStringAsFixed(1);
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        final newLabel = widget.step.seconds.toStringAsFixed(1);
        if (newLabel != _lastSecondsLabel) {
          _lastSecondsLabel = newLabel;
          setState(() {});
        }
      });
    } else if (!widget.step.isThinking && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.step.content));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = widget.step;
    final amber = Colors.amber.shade700;
    final secondsLabel = step.seconds.toStringAsFixed(1);
    final hasContent = step.content.isNotEmpty;
    final isEmptyThinking = step.isThinking && !hasContent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: icon + label + time + expand/collapse
        InkWell(
          onTap: hasContent ? () => setState(() => _expanded = !_expanded) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // Icon node (24dp wide, covers the vertical line)
                SizedBox(
                  width: 24,
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: isEmptyThinking
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: amber,
                              ),
                            )
                          : Icon(
                              LucideIcons.lightbulb,
                              size: 14,
                              color: step.isThinking
                                  ? amber
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Label
                Expanded(
                  child: Text(
                    isEmptyThinking
                        ? '继续思考中...'
                        : (step.isThinking
                            ? '思考中... ${secondsLabel}s'
                            : '深度思考 ${secondsLabel}s'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: step.isThinking
                          ? amber
                          : theme.colorScheme.secondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Copy button
                if (hasContent)
                  InkWell(
                    onTap: _copy,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        _copied ? LucideIcons.check : LucideIcons.copy,
                        size: 14,
                        color: _copied
                            ? Colors.green
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                // Expand/collapse indicator
                if (hasContent)
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Expanded content or streaming preview
        if (_expanded && hasContent)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 4, bottom: 8),
            child: widget.markdownBuilder(
              context,
              widget.step.content,
              TextStyle(color: theme.colorScheme.onSurface),
            ),
          )
        else if (!_expanded && step.isThinking && hasContent)
          // Streaming preview: show last few lines with a fade
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 8),
            child: _FadedPreview(
              markdownBuilder: widget.markdownBuilder,
              content: _previewContent(step.content),
            ),
          ),
      ],
    );
  }

  /// Extract the trailing part of the content for the streaming preview.
  static String _previewContent(String content) {
    if (content.isEmpty) return '';
    final lines = content.split('\n');
    for (var i = lines.length - 1; i >= 0; i--) {
      if (_headingOrBold.hasMatch(lines[i].trim())) {
        return lines.sublist(i).join('\n');
      }
    }
    // Fallback: last ~6 lines
    if (lines.length > 6) return lines.sublist(lines.length - 6).join('\n');
    return content;
  }

  static final RegExp _headingOrBold = RegExp(r'^(#{1,6}\s|\*\*.+\*\*$)');
}

// ---------------------------------------------------------------------------
// Faded preview (used during streaming when collapsed)
// ---------------------------------------------------------------------------

class _FadedPreview extends StatelessWidget {
  const _FadedPreview({
    required this.markdownBuilder,
    required this.content,
  });

  final TimelineMarkdownBuilder markdownBuilder;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fadeBg = isDark ? const Color(0xFF121212) : Colors.white;

    return Container(
      constraints: const BoxConstraints(maxHeight: 100),
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fadeBg.withValues(alpha: 0), fadeBg],
          stops: const [0.5, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.srcOver,
        child: SingleChildScrollView(
          reverse: true,
          physics: const NeverScrollableScrollPhysics(),
          child: markdownBuilder(
            context,
            content,
            TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tool node
// ---------------------------------------------------------------------------

class _ToolNode extends StatefulWidget {
  const _ToolNode({required this.step});

  final ToolTimelineStep step;

  @override
  State<_ToolNode> createState() => _ToolNodeState();
}

class _ToolNodeState extends State<_ToolNode> {
  bool _expanded = false;

  // Cached formatted strings
  String? _cachedParams;
  String? _cachedResult;
  Object? _lastArgs;
  Object? _lastContent;

  ToolBlock get _block => widget.step.block;

  bool get _isProcessing =>
      _block.status == MessageBlockStatus.streaming ||
      _block.status == MessageBlockStatus.processing ||
      _block.status == MessageBlockStatus.pending;

  bool get _hasError => _block.status == MessageBlockStatus.error;

  String get _toolName => _block.toolName ?? '工具调用';

  Color _statusColor(ThemeData theme) {
    if (_hasError) return theme.colorScheme.error;
    if (_isProcessing) return Colors.amber.shade700;
    return Colors.green;
  }

  IconData get _statusIcon {
    if (_hasError) return LucideIcons.circleAlert;
    if (_isProcessing) return LucideIcons.loader; // placeholder, we use spinner
    return LucideIcons.circleCheck;
  }

  String _formatParams() {
    final args = _block.arguments;
    if (args == null || args.isEmpty) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(args);
    } catch (_) {
      return args.toString();
    }
  }

  String _formatResult() {
    final content = _block.content;
    if (content == null) return '';
    if (content is String) {
      if (content.isEmpty) return '';
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
    final statusColor = _statusColor(theme);
    final isDark = theme.brightness == Brightness.dark;

    if (!identical(_block.arguments, _lastArgs)) {
      _lastArgs = _block.arguments;
      _cachedParams = _formatParams();
    }
    if (!identical(_block.content, _lastContent)) {
      _lastContent = _block.content;
      _cachedResult = _formatResult();
    }
    final params = _cachedParams ?? '';
    final result = _cachedResult ?? '';
    final hasDetails = params.isNotEmpty || result.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        InkWell(
          onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // Icon node
                SizedBox(
                  width: 24,
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: _isProcessing
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: statusColor,
                              ),
                            )
                          : Icon(
                              LucideIcons.wrench,
                              size: 13,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Tool name
                Expanded(
                  child: Text(
                    _toolName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Status icon
                if (!_isProcessing)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(_statusIcon, size: 13, color: statusColor),
                  ),
                // Expand indicator
                if (hasDetails)
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
            ),
          ),
        ),

        // Expanded details
        if (_expanded && hasDetails)
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.25),
                ),
                color: statusColor.withValues(alpha: isDark ? 0.08 : 0.05),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (params.isNotEmpty)
                    _ToolDetailSection(
                      label: '参数',
                      content: params,
                    ),
                  if (params.isNotEmpty && result.isNotEmpty)
                    Divider(height: 1, color: statusColor.withValues(alpha: 0.15)),
                  if (result.isNotEmpty)
                    _ToolDetailSection(
                      label: '结果',
                      content: result,
                      isError: _hasError,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tool detail section (params / result)
// ---------------------------------------------------------------------------

class _ToolDetailSection extends StatelessWidget {
  const _ToolDetailSection({
    required this.label,
    required this.content,
    this.isError = false,
  });

  final String label;
  final String content;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isError
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () =>
                    Clipboard.setData(ClipboardData(text: content)),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    LucideIcons.copy,
                    size: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
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
                  color: isError
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
