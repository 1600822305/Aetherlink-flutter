import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';

/// Renders a `THINKING` block in the default 「紧凑」 style, mirroring
/// `ThinkingBlock.tsx` + `ThinkingCompactStyle.tsx`.
///
/// A rounded, glassy card: a Lightbulb (amber while thinking) + 「思考过程」 +
/// a duration chip (思考中 / 已深度思考), a copy button and a chevron. Collapsed
/// while thinking it shows a scrolling preview of the latest content; tapping
/// expands the full reasoning. The duration ticks live while the block streams
/// and freezes at the recorded `thinking_millsec` (or createdAt→updatedAt) once
/// terminal.
///
/// The 16 alternative display styles and inline-tool grouping are later slices.
class ThinkingBlockView extends StatefulWidget {
  const ThinkingBlockView({required this.block, super.key});

  final ThinkingBlock block;

  @override
  State<ThinkingBlockView> createState() => _ThinkingBlockViewState();
}

class _ThinkingBlockViewState extends State<ThinkingBlockView> {
  bool _expanded = false;
  bool _copied = false;
  Timer? _timer;

  bool get _isThinking => widget.block.status == MessageBlockStatus.streaming;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(ThinkingBlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    if (_isThinking && _timer == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) setState(() {});
      });
    } else if (!_isThinking && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double _thinkingSeconds() {
    final ms = widget.block.thinkingMillsec;
    if (ms != null && ms > 0) return ms / 1000;
    final start = widget.block.createdAt;
    final end = _isThinking
        ? DateTime.now()
        : (widget.block.updatedAt ?? widget.block.createdAt);
    final diff = end.difference(start).inMilliseconds;
    return diff <= 0 ? 0 : diff / 1000;
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.block.content));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  /// The latest "step" of the reasoning, mirroring `ThinkingCompactStyle`'s
  /// `previewContent`: everything from the last Markdown heading / bold line.
  String _previewContent() {
    final content = widget.block.content;
    if (content.isEmpty) return '';
    final lines = content.split('\n');
    final headingOrBold = RegExp(r'^(#{1,6}\s|\*\*.+\*\*$)');
    for (var i = lines.length - 1; i >= 0; i--) {
      if (headingOrBold.hasMatch(lines[i].trim())) {
        return lines.sublist(i).join('\n');
      }
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isThinking = _isThinking;
    final amber = Colors.amber.shade700;
    final seconds = _thinkingSeconds().toStringAsFixed(1);
    final chipLabel = isThinking ? '思考中… ${seconds}s' : '已深度思考 ${seconds}s';
    final glassBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.85);
    final border = isDark ? Colors.white12 : Colors.black12;

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
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.lightbulb,
                    size: 16,
                    color: isThinking
                        ? amber
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
                        color: isThinking ? amber : theme.dividerColor,
                      ),
                    ),
                    child: Text(
                      chipLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isThinking
                            ? amber
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
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
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
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
          if (_expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: AppMarkdown(content: widget.block.content),
            )
          else if (isThinking)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.02),
              child: SingleChildScrollView(
                reverse: true,
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: AppMarkdown(
                    content: _previewContent(),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
