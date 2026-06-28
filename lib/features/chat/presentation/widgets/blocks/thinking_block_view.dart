import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/thinking_settings_access.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/inline_tool_chip.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/tool_renderer_registry.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';
import 'package:aetherlink_flutter/shared/domain/thinking_settings.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_confirmation_service.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';
import 'package:aetherlink_flutter/shared/widgets/thinking_styled_view.dart';

/// Renders a `THINKING` block, mirroring `ThinkingBlock.tsx`.
///
/// Owns the live timer, the expanded / copied state and the duration, then
/// delegates the visual to [ThinkingStyledView] in the chosen display style.
/// Reads 思考过程设置 ([ThinkingSettings]) via the app/di seam so the style and
/// the auto-collapse behaviour follow 外观设置 → 思考过程设置 live. The practical
/// subset of the original's 17 styles is ported — 紧凑 (default) / 完整 / 极简 /
/// 气泡 / 卡片 / 隐藏; the novelty styles are intentionally dropped.
class ThinkingBlockView extends ConsumerStatefulWidget {
  const ThinkingBlockView({
    required this.block,
    this.inlineToolBlocks = const [],
    super.key,
  });

  final ThinkingBlock block;

  /// Tool blocks that occurred during this thinking phase, to be rendered
  /// inline as lightweight chips (mirrors `inlineToolBlocks` in the web).
  final List<ToolBlock> inlineToolBlocks;

  @override
  ConsumerState<ThinkingBlockView> createState() => _ThinkingBlockViewState();
}

class _ThinkingBlockViewState extends ConsumerState<ThinkingBlockView> {
  late bool _expanded;
  bool _copied = false;
  Timer? _timer;

  /// Cached preview to avoid re-scanning content lines 10×/sec during streaming.
  String? _cachedPreview;
  String _lastContentForPreview = '';

  /// Last displayed seconds label to skip rebuilds when the timer ticks but
  /// the rounded display value hasn't changed.
  String _lastSecondsLabel = '';

  bool get _isThinking => widget.block.status == MessageBlockStatus.streaming;

  @override
  void initState() {
    super.initState();
    // Seed the expanded state from 自动折叠 (mirrors the web `useState(!auto)`).
    _expanded = !ref.read(thinkingSettingsProvider).thoughtAutoCollapse;
    _syncTimer();
  }

  @override
  void didUpdateWidget(ThinkingBlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    if (_isThinking && _timer == null) {
      _lastSecondsLabel = _thinkingSeconds().toStringAsFixed(1);
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        final newLabel = _thinkingSeconds().toStringAsFixed(1);
        if (newLabel != _lastSecondsLabel) {
          _lastSecondsLabel = newLabel;
          setState(() {});
        }
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

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

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
    await AppToast.copy(context, widget.block.content);
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  /// The latest "step" of the reasoning, mirroring `ThinkingCompactStyle`'s
  /// `previewContent`: everything from the last Markdown heading / bold line.
  ///
  /// Cached so the regex scan doesn't repeat on every timer-driven rebuild.
  String _previewContent() {
    final content = widget.block.content;
    if (content == _lastContentForPreview && _cachedPreview != null) {
      return _cachedPreview!;
    }
    _lastContentForPreview = content;
    if (content.isEmpty) {
      _cachedPreview = '';
      return '';
    }
    final lines = content.split('\n');
    for (var i = lines.length - 1; i >= 0; i--) {
      if (_headingOrBold.hasMatch(lines[i].trim())) {
        _cachedPreview = lines.sublist(i).join('\n');
        return _cachedPreview!;
      }
    }
    _cachedPreview = content;
    return content;
  }

  static final RegExp _headingOrBold = RegExp(r'^(#{1,6}\s|\*\*.+\*\*$)');

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(
      thinkingSettingsProvider.select((s) => s.displayStyle),
    );

    // Auto-expand when an inline tool is awaiting confirmation, so its confirm
    // buttons aren't trapped behind a collapsed thinking body (devin / 极简 /
    // 紧凑 / 气泡 / 卡片 styles render inline tools only when expanded). Without
    // this the user has to expand first, then confirm — an extra step. Mirrors
    // ToolBlockView's auto-expand.
    final pending = ref.watch(toolConfirmationProvider);
    final hasPendingConfirmation =
        widget.inlineToolBlocks.any((b) => pending.containsKey(b.id));
    if (hasPendingConfirmation && !_expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_expanded) setState(() => _expanded = true);
      });
    }

    final inlineTools = widget.inlineToolBlocks.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.inlineToolBlocks.length; i++) ...
                [
                  if (i > 0) const SizedBox(height: 6),
                  // Reuse the tool's special renderer (file-editor diff card,
                  // web-search card, …) so a tool called during the thinking
                  // phase looks the same inline as it does top-level; only tools
                  // without a special renderer fall back to the compact chip.
                  buildSpecialToolBlock(widget.inlineToolBlocks[i]) ??
                      InlineToolChip(block: widget.inlineToolBlocks[i]),
                ],
            ],
          );

    return ThinkingStyledView(
      style: style,
      content: widget.block.content,
      isThinking: _isThinking,
      seconds: _thinkingSeconds(),
      expanded: _expanded,
      copied: _copied,
      onToggleExpanded: _toggleExpanded,
      onCopy: _copy,
      previewContent: _previewContent(),
      inlineTools: inlineTools,
      markdownBuilder: (context, content, style) =>
          AppMarkdown(content: content, style: style),
    );
  }
}
