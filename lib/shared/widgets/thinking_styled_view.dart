import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/domain/thinking_settings.dart';

/// Builds the Markdown body for the reasoning content. Injected so this shared
/// widget stays free of any feature dependency: the chat thinking block passes
/// the rich `AppMarkdown` (code blocks + links), while the settings preview
/// passes a plain Markdown widget.
typedef ThinkingMarkdownBuilder =
    Widget Function(BuildContext context, String content, TextStyle? style);

/// Renders a reasoning ("thinking") panel in one of the ported display styles —
/// 紧凑 `compact` / 完整 `full` / 极简 `minimal` / 气泡 `bubble` / 卡片 `card` /
/// 隐藏 `hidden` — a port of `ThinkingDisplayRenderer.tsx`.
///
/// Pure presentation over primitives (no [MessageBlock] / no provider), so both
/// the chat thinking block and the 思考过程设置 live preview can share it without
/// crossing a feature boundary. The expanded / copied state and the duration are
/// owned by the caller.
class ThinkingStyledView extends StatelessWidget {
  const ThinkingStyledView({
    required this.style,
    required this.content,
    required this.isThinking,
    required this.seconds,
    required this.expanded,
    required this.copied,
    required this.onToggleExpanded,
    required this.onCopy,
    required this.markdownBuilder,
    this.previewContent,
    this.inlineTools,
    super.key,
  });

  /// The display style to render in.
  final ThinkingDisplayStyle style;

  /// The full reasoning text.
  final String content;

  /// Whether the block is still streaming (drives the amber accent + labels).
  final bool isThinking;

  /// Elapsed reasoning time in seconds (already computed by the caller).
  final double seconds;

  /// Whether the collapsible body is expanded.
  final bool expanded;

  /// Whether the copy button is in its transient "copied" state.
  final bool copied;

  final VoidCallback onToggleExpanded;
  final VoidCallback onCopy;
  final ThinkingMarkdownBuilder markdownBuilder;

  /// The trailing slice shown in the compact streaming preview; defaults to the
  /// full [content].
  final String? previewContent;

  /// Optional widget showing tool calls made during the thinking phase.
  final Widget? inlineTools;

  Color get _amber => Colors.amber.shade700;

  String get _secondsLabel => seconds.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case ThinkingDisplayStyle.hidden:
        return const SizedBox.shrink();
      case ThinkingDisplayStyle.full:
        return _buildFull(context);
      case ThinkingDisplayStyle.minimal:
        return _buildMinimal(context);
      case ThinkingDisplayStyle.bubble:
        return _buildBubble(context);
      case ThinkingDisplayStyle.card:
        return _buildCard(context);
      case ThinkingDisplayStyle.compact:
        return _ThinkingCompactView(
          content: content,
          isThinking: isThinking,
          seconds: seconds,
          expanded: expanded,
          copied: copied,
          onToggleExpanded: onToggleExpanded,
          onCopy: onCopy,
          markdownBuilder: markdownBuilder,
          previewContent: previewContent,
          inlineTools: inlineTools,
        );
    }
  }

  // ------------------------------------------------------------------ helpers

  Widget _copyButton(ThemeData theme, {double size = 14}) {
    return InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          copied ? LucideIcons.check : LucideIcons.copy,
          size: size,
          color: copied ? Colors.green : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _chevron(ThemeData theme) {
    return AnimatedRotation(
      turns: expanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 250),
      child: Icon(
        LucideIcons.chevronDown,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  // -------------------------------------------------------------- 紧凑 compact
  // Extracted to _ThinkingCompactView (StatefulWidget) for inner collapse state.

  // ------------------------------------------------------------------ 完整 full

  Widget _buildFull(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glassBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.85);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: glassBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.lightbulb,
                  size: 20,
                  color: isThinking ? _amber : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  isThinking ? '正在深度思考...' : '深度思考过程',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: '${_secondsLabel}s',
                  color: isThinking ? _amber : theme.colorScheme.primary,
                  filled: true,
                ),
                const Spacer(),
                _copyButton(theme, size: 16),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                markdownBuilder(
                  context,
                  content,
                  TextStyle(color: theme.colorScheme.onSurface),
                ),
                if (inlineTools != null) ...[
                  const SizedBox(height: 8),
                  inlineTools!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- 极简 minimal

  Widget _buildMinimal(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isThinking
        ? _amber.withValues(alpha: 0.18)
        : theme.colorScheme.onSurface.withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Tooltip(
            message: '思考过程 (${_secondsLabel}s)',
            child: InkWell(
              onTap: onToggleExpanded,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(
                  LucideIcons.lightbulb,
                  size: 16,
                  color: isThinking
                      ? _amber
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        if (expanded)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: theme.dividerColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '思考过程 (${_secondsLabel}s)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      _copyButton(theme, size: 16),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      markdownBuilder(
                        context,
                        content,
                        TextStyle(color: theme.colorScheme.onSurface),
                      ),
                      if (inlineTools != null) ...[
                        const SizedBox(height: 8),
                        inlineTools!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------- 气泡 bubble

  Widget _buildBubble(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isThinking ? _amber : theme.colorScheme.primary,
            ),
            child: const Icon(LucideIcons.brain, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onTap: onToggleExpanded,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isThinking ? '💭 思考中...' : '💭 思考完成',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Chip(
                          label: '${_secondsLabel}s',
                          color: theme.colorScheme.onSurfaceVariant,
                          dense: true,
                        ),
                        const SizedBox(width: 4),
                        _copyButton(theme),
                      ],
                    ),
                    if (expanded) ...[
                      const SizedBox(height: 8),
                      markdownBuilder(
                        context,
                        content,
                        TextStyle(color: theme.colorScheme.onSurface),
                      ),
                      if (inlineTools != null) ...[
                        const SizedBox(height: 8),
                        inlineTools!,
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ 卡片 card

  Widget _buildCard(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.06),
            secondary.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: primary.withValues(alpha: 0.12), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggleExpanded,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isThinking ? _amber : primary,
                    ),
                    child: const Icon(
                      LucideIcons.sparkles,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isThinking ? '🧠 AI 正在深度思考' : '✨ 思考过程完成',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '耗时 $_secondsLabel 秒',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _copyButton(theme, size: 16),
                  _chevron(theme),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      markdownBuilder(
                        context,
                        content,
                        TextStyle(color: theme.colorScheme.onSurface),
                      ),
                      if (inlineTools != null) ...[
                        const SizedBox(height: 8),
                        inlineTools!,
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact thinking style with two-level expand/collapse, mirroring
/// `ThinkingCompactStyle.tsx` from the web version.
///
/// Outer level: [expanded] controls the entire panel (thinking text + tools).
/// Inner level: [_thinkingExpanded] controls just the thinking text when
/// inlineTools exist, allowing users to collapse the text while keeping
/// tool chips visible.
class _ThinkingCompactView extends StatefulWidget {
  const _ThinkingCompactView({
    required this.content,
    required this.isThinking,
    required this.seconds,
    required this.expanded,
    required this.copied,
    required this.onToggleExpanded,
    required this.onCopy,
    required this.markdownBuilder,
    this.previewContent,
    this.inlineTools,
  });

  final String content;
  final bool isThinking;
  final double seconds;
  final bool expanded;
  final bool copied;
  final VoidCallback onToggleExpanded;
  final VoidCallback onCopy;
  final ThinkingMarkdownBuilder markdownBuilder;
  final String? previewContent;
  final Widget? inlineTools;

  @override
  State<_ThinkingCompactView> createState() => _ThinkingCompactViewState();
}

class _ThinkingCompactViewState extends State<_ThinkingCompactView> {
  bool _thinkingExpanded = true;

  Color get _amber => Colors.amber.shade700;
  String get _secondsLabel => widget.seconds.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chipLabel = widget.isThinking
        ? '思考中… ${_secondsLabel}s'
        : '已深度思考 ${_secondsLabel}s';
    final glassBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.85);
    final border = isDark ? Colors.white12 : Colors.black12;
    final hasTools = widget.inlineTools != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: glassBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          InkWell(
            onTap: widget.onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.lightbulb,
                    size: 16,
                    color: widget.isThinking
                        ? _amber
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '思考过程',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: widget.isThinking ? _amber : theme.dividerColor,
                      ),
                    ),
                    child: Text(
                      chipLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: widget.isThinking
                            ? _amber
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildCopyButton(theme),
                  _buildChevron(theme),
                ],
              ),
            ),
          ),

          // --- Expanded state ---
          if (widget.expanded) ...[
            // Inner collapse header (only when inline tools exist)
            if (hasTools)
              InkWell(
                onTap: () =>
                    setState(() => _thinkingExpanded = !_thinkingExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '思考内容',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _thinkingExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          LucideIcons.chevronDown,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Thinking text (collapsible when tools exist)
            if (!hasTools || _thinkingExpanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: widget.markdownBuilder(
                  context,
                  widget.content,
                  TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
            // Tool chips (always visible when expanded)
            if (hasTools)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  _thinkingExpanded ? 0 : 6,
                  12,
                  10,
                ),
                child: widget.inlineTools!,
              ),
          ]
          // --- Collapsed + streaming ---
          else if (widget.isThinking) ...[
            // Preview text
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.02),
              child: SingleChildScrollView(
                reverse: true,
                child: widget.markdownBuilder(
                  context,
                  widget.previewContent ?? widget.content,
                  TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            // Tool chips visible during streaming even when collapsed
            if (hasTools)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                child: widget.inlineTools!,
              ),
          ],
          // --- Collapsed + not thinking: no extra content (matches web) ---
        ],
      ),
    );
  }

  Widget _buildCopyButton(ThemeData theme) {
    return InkWell(
      onTap: widget.onCopy,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          widget.copied ? LucideIcons.check : LucideIcons.copy,
          size: 14,
          color: widget.copied
              ? Colors.green
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildChevron(ThemeData theme) {
    return AnimatedRotation(
      turns: widget.expanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 250),
      child: Icon(
        LucideIcons.chevronDown,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A small pill chip used by the full / bubble thinking styles. [filled] draws a
/// tinted background; otherwise it's an outlined chip.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    this.filled = false,
    this.dense = false,
  });

  final String label;
  final Color color;
  final bool filled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: 1),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.16) : null,
        borderRadius: BorderRadius.circular(9),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: dense ? 10 : 11, color: color),
      ),
    );
  }
}
