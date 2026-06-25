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

sealed class TimelineStep {
  const TimelineStep();
}

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

class ToolTimelineStep extends TimelineStep {
  const ToolTimelineStep({required this.block});

  final ToolBlock block;
}

// ---------------------------------------------------------------------------
// RikkaHub-style ReasoningCardState (three states)
// ---------------------------------------------------------------------------

enum ReasoningCardState {
  collapsed(expanded: false),
  preview(expanded: true),
  expanded(expanded: true);

  const ReasoningCardState({required this.expanded});
  final bool expanded;
}

// ---------------------------------------------------------------------------
// Tool icon/title registry (ToolUIRegistry equivalent)
// ---------------------------------------------------------------------------

class _ToolUIInfo {
  const _ToolUIInfo({required this.icon, required this.title});
  final IconData icon;
  final String title;
}

_ToolUIInfo _resolveToolUI(String toolName) {
  final lower = toolName.toLowerCase();

  // Search tools
  if (lower.contains('search') || lower.contains('搜索')) {
    return _ToolUIInfo(icon: LucideIcons.search, title: toolName);
  }
  if (lower.contains('scrape') || lower.contains('fetch') || lower.contains('browse') || lower.contains('crawl')) {
    return _ToolUIInfo(icon: LucideIcons.globe, title: toolName);
  }
  // File tools
  if (lower.contains('read_file') || lower.contains('readfile')) {
    return _ToolUIInfo(icon: LucideIcons.fileText, title: toolName);
  }
  if (lower.contains('write_file') || lower.contains('writefile') || lower.contains('edit_file')) {
    return _ToolUIInfo(icon: LucideIcons.filePen, title: toolName);
  }
  // Shell / command
  if (lower.contains('shell') || lower.contains('exec') || lower.contains('command') || lower.contains('terminal')) {
    return _ToolUIInfo(icon: LucideIcons.terminal, title: toolName);
  }
  // Memory
  if (lower.contains('memory') || lower.contains('remember')) {
    return _ToolUIInfo(icon: LucideIcons.brain, title: toolName);
  }
  // Clipboard
  if (lower.contains('clipboard') || lower.contains('copy') || lower.contains('paste')) {
    return _ToolUIInfo(icon: LucideIcons.clipboard, title: toolName);
  }
  // TTS / speech
  if (lower.contains('speech') || lower.contains('tts') || lower.contains('voice')) {
    return _ToolUIInfo(icon: LucideIcons.volume2, title: toolName);
  }
  // Code / programming
  if (lower.contains('code') || lower.contains('python') || lower.contains('javascript')) {
    return _ToolUIInfo(icon: LucideIcons.code, title: toolName);
  }
  // Image / vision
  if (lower.contains('image') || lower.contains('vision') || lower.contains('画')) {
    return _ToolUIInfo(icon: LucideIcons.image, title: toolName);
  }
  // Calculator / math
  if (lower.contains('calc') || lower.contains('math')) {
    return _ToolUIInfo(icon: LucideIcons.calculator, title: toolName);
  }
  // Database
  if (lower.contains('database') || lower.contains('sql') || lower.contains('query')) {
    return _ToolUIInfo(icon: LucideIcons.database, title: toolName);
  }

  // Default fallback
  return _ToolUIInfo(icon: LucideIcons.wrench, title: toolName);
}

// ---------------------------------------------------------------------------
// extractThinkingTitle — RikkaHub's extractThinkingTitle equivalent
// ---------------------------------------------------------------------------

final RegExp _boldLinePattern = RegExp(r'^\*\*(.+?)\*\*$');

String? _extractThinkingTitle(String content) {
  if (content.isEmpty) return null;
  final lines = content.split('\n');
  for (var i = lines.length - 1; i >= 0; i--) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final match = _boldLinePattern.firstMatch(line);
    if (match != null) {
      final title = match.group(1)?.trim();
      if (title != null && title.isNotEmpty) return title;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// ThinkingTimelineView — the main timeline widget
// ---------------------------------------------------------------------------

class ThinkingTimelineView extends StatefulWidget {
  const ThinkingTimelineView({
    required this.thinkingContent,
    required this.thinkingSeconds,
    required this.isThinking,
    required this.markdownBuilder,
    this.inlineToolBlocks = const [],
    this.thoughtAutoCollapse = true,
    this.showThinkingContent = true,
    super.key,
  });

  final String thinkingContent;
  final double thinkingSeconds;
  final bool isThinking;
  final TimelineMarkdownBuilder markdownBuilder;
  final List<ToolBlock> inlineToolBlocks;
  final bool thoughtAutoCollapse;
  final bool showThinkingContent;

  @override
  State<ThinkingTimelineView> createState() => _ThinkingTimelineViewState();
}

class _ThinkingTimelineViewState extends State<ThinkingTimelineView> {
  bool _allStepsExpanded = false;
  static const int _collapsedVisibleCount = 2;

  List<TimelineStep> _buildSteps() {
    final tools = widget.inlineToolBlocks;

    if (tools.isEmpty) {
      return [
        ReasoningTimelineStep(
          content: widget.thinkingContent,
          seconds: widget.thinkingSeconds,
          isThinking: widget.isThinking,
        ),
      ];
    }

    final steps = <TimelineStep>[];

    if (widget.thinkingContent.isNotEmpty) {
      final reasoningTime = tools.isEmpty
          ? widget.thinkingSeconds
          : widget.thinkingSeconds * 0.6;
      steps.add(ReasoningTimelineStep(
        content: widget.thinkingContent,
        seconds: reasoningTime,
        isThinking: widget.isThinking && tools.every(_isToolPending),
      ));
    }

    for (final tool in tools) {
      steps.add(ToolTimelineStep(block: tool));
    }

    if (widget.isThinking && tools.isNotEmpty && tools.every(_isToolDone)) {
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
    final isReasoningOnly = steps.every((s) => s is ReasoningTimelineStep);
    final canCollapse = steps.length > _collapsedVisibleCount;
    final visibleSteps = (_allStepsExpanded || !canCollapse)
        ? steps
        : steps.sublist(steps.length - _collapsedVisibleCount);

    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.85);
    final border = isDark ? Colors.white12 : Colors.black12;
    final lineColor = theme.colorScheme.outlineVariant;

    // collapsedAdaptiveWidth: when reasoning-only and collapsed, don't force full width
    final useAdaptiveWidth = isReasoningOnly && !_allStepsExpanded;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: useAdaptiveWidth ? null : const BoxConstraints(minWidth: double.infinity),
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
            mainAxisSize: useAdaptiveWidth ? MainAxisSize.min : MainAxisSize.max,
            children: [
              if (canCollapse)
                _CollapseControl(
                  expanded: _allStepsExpanded,
                  hiddenCount: steps.length - _collapsedVisibleCount,
                  onTap: () =>
                      setState(() => _allStepsExpanded = !_allStepsExpanded),
                ),
              CustomPaint(
                foregroundPainter: _TimelineLinePainter(
                  color: lineColor,
                  nodeX: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < visibleSteps.length; i++)
                      _buildStep(visibleSteps[i]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(TimelineStep step) {
    switch (step) {
      case ReasoningTimelineStep():
        return _ReasoningNode(
          step: step,
          markdownBuilder: widget.markdownBuilder,
          autoCollapse: widget.thoughtAutoCollapse,
          showThinkingContent: widget.showThinkingContent,
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
// Reasoning node — with three-state ReasoningCardState + extractThinkingTitle
// ---------------------------------------------------------------------------

class _ReasoningNode extends StatefulWidget {
  const _ReasoningNode({
    required this.step,
    required this.markdownBuilder,
    required this.autoCollapse,
    required this.showThinkingContent,
  });

  final ReasoningTimelineStep step;
  final TimelineMarkdownBuilder markdownBuilder;
  final bool autoCollapse;
  final bool showThinkingContent;

  @override
  State<_ReasoningNode> createState() => _ReasoningNodeState();
}

class _ReasoningNodeState extends State<_ReasoningNode> {
  ReasoningCardState _state = ReasoningCardState.collapsed;
  bool _copied = false;
  Timer? _timer;
  String _lastSecondsLabel = '';

  @override
  void initState() {
    super.initState();
    if (widget.step.isThinking && widget.showThinkingContent) {
      _state = ReasoningCardState.preview;
    } else if (!widget.autoCollapse && widget.step.content.isNotEmpty) {
      _state = ReasoningCardState.expanded;
    }
    _syncTimer();
  }

  @override
  void didUpdateWidget(_ReasoningNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.isThinking && !widget.step.isThinking) {
      // Finished thinking
      if (_state.expanded) {
        _state = widget.autoCollapse
            ? ReasoningCardState.collapsed
            : ReasoningCardState.expanded;
      }
    } else if (!oldWidget.step.isThinking && widget.step.isThinking) {
      // Started thinking
      if (!_state.expanded && widget.showThinkingContent) {
        _state = ReasoningCardState.preview;
      }
    }
    _syncTimer();
  }

  void _onExpandedChange(bool nextExpanded) {
    setState(() {
      if (widget.step.isThinking) {
        _state = nextExpanded
            ? ReasoningCardState.expanded
            : ReasoningCardState.preview;
      } else {
        _state = nextExpanded
            ? ReasoningCardState.expanded
            : ReasoningCardState.collapsed;
      }
    });
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

    // extractThinkingTitle
    final thinkingTitle = step.isThinking ? _extractThinkingTitle(step.content) : null;
    final showThinkingTitle = step.isThinking && thinkingTitle != null;

    final isContentVisible = _state != ReasoningCardState.collapsed;
    final isPreview = _state == ReasoningCardState.preview;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          InkWell(
            onTap: hasContent
                ? () => _onExpandedChange(_state == ReasoningCardState.collapsed)
                : null,
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
                  // Label — with AnimatedSwitcher for thinking title
                  Expanded(
                    child: showThinkingTitle
                        ? AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 1),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: _ShimmerText(
                              key: ValueKey(thinkingTitle),
                              text: thinkingTitle,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.secondary,
                              ),
                              isLoading: true,
                            ),
                          )
                        : _ShimmerText(
                            text: isEmptyThinking
                                ? '继续思考中...'
                                : (step.isThinking
                                    ? '思考中... ${secondsLabel}s'
                                    : '深度思考 ${secondsLabel}s'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: step.isThinking
                                  ? amber
                                  : theme.colorScheme.secondary,
                            ),
                            isLoading: step.isThinking,
                          ),
                  ),
                  // Extra: duration when showing title
                  if (showThinkingTitle && step.seconds > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _ShimmerText(
                        text: '${secondsLabel}s',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                        ),
                        isLoading: true,
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
                      turns: _state == ReasoningCardState.expanded ? 0.5 : 0,
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

          // Content area
          if (isContentVisible && hasContent)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4, bottom: 8),
              child: isPreview
                  ? _FadedPreview(
                      markdownBuilder: widget.markdownBuilder,
                      content: step.content,
                    )
                  : widget.markdownBuilder(
                      context,
                      step.content,
                      TextStyle(color: theme.colorScheme.onSurface),
                    ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer text widget
// ---------------------------------------------------------------------------

class _ShimmerText extends StatefulWidget {
  const _ShimmerText({
    required this.text,
    required this.style,
    required this.isLoading,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final bool isLoading;

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isLoading) _controller.repeat();
  }

  @override
  void didUpdateWidget(_ShimmerText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isLoading && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return ShaderMask(
          shaderCallback: (bounds) {
            final color = widget.style?.color ?? Colors.grey;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                color,
                color.withValues(alpha: 0.3),
                color,
              ],
              stops: [
                (value - 0.3).clamp(0.0, 1.0),
                value,
                (value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: child!,
        );
      },
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Faded preview — RikkaHub-style dual-direction gradient with BlendMode.dstIn
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

    return Container(
      constraints: const BoxConstraints(maxHeight: 100),
      child: ShaderMask(
        shaderCallback: (bounds) {
          final fadeHeight = 64.0;
          final fadeRatioTop = (fadeHeight / bounds.height).clamp(0.0, 0.5);
          final fadeRatioBottom = (1.0 - fadeHeight / bounds.height).clamp(0.5, 1.0);
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, fadeRatioTop, fadeRatioBottom, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
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
// Tool node — with BottomSheet detail + ToolUIRegistry icons
// ---------------------------------------------------------------------------

class _ToolNode extends StatefulWidget {
  const _ToolNode({required this.step});

  final ToolTimelineStep step;

  @override
  State<_ToolNode> createState() => _ToolNodeState();
}

class _ToolNodeState extends State<_ToolNode> {
  bool _summaryExpanded = true;

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
    if (_isProcessing) return LucideIcons.loader;
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

  String _buildSummary() {
    final result = _cachedResult ?? '';
    if (result.isEmpty) return '';
    // Try to extract a short summary from the result
    final lines = result.split('\n');
    if (lines.length <= 3) return result.length > 120 ? '${result.substring(0, 120)}...' : result;
    return '${lines.take(3).join('\n')}...';
  }

  void _showDetailSheet(BuildContext context, String params, String result) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(theme);
    final isDark = theme.brightness == Brightness.dark;
    final toolUI = _resolveToolUI(_toolName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(toolUI.icon, size: 20, color: statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _toolName,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_isProcessing)
                        Icon(_statusIcon, size: 16, color: statusColor),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (params.isNotEmpty)
                        _ToolDetailSection(
                          label: '参数',
                          content: params,
                        ),
                      if (params.isNotEmpty && result.isNotEmpty)
                        const SizedBox(height: 12),
                      if (result.isNotEmpty)
                        _ToolDetailSection(
                          label: '结果',
                          content: result,
                          isError: _hasError,
                          maxHeight: double.infinity,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(theme);
    final toolUI = _resolveToolUI(_toolName);

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
    final summary = _buildSummary();
    final hasSummary = summary.isNotEmpty && !_isProcessing;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          InkWell(
            onTap: hasDetails ? () => _showDetailSheet(context, params, result) : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // Icon node — uses registered tool icon
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
                                toolUI.icon,
                                size: 13,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tool name with shimmer when loading
                  Expanded(
                    child: _ShimmerText(
                      text: _toolName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                      isLoading: _isProcessing,
                    ),
                  ),
                  // Status icon
                  if (!_isProcessing)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(_statusIcon, size: 13, color: statusColor),
                    ),
                  // Arrow indicator: right arrow for onClick (BottomSheet)
                  if (hasDetails)
                    Icon(
                      LucideIcons.arrowRight,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),

          // Inline summary (like RikkaHub's Summary)
          if (hasSummary)
            Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 8),
              child: Text(
                summary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
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
    this.maxHeight = 160,
  });

  final String label;
  final String content;
  final bool isError;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                color: isError
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已复制'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
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
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          constraints: maxHeight.isFinite
              ? BoxConstraints(maxHeight: maxHeight)
              : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
          ),
          child: SingleChildScrollView(
            child: Text(
              content,
              style: TextStyle(
                fontSize: 11,
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
    );
  }
}
