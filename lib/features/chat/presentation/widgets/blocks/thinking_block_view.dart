import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/thinking_settings_access.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/inline_tool_chip.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';
import 'package:aetherlink_flutter/shared/domain/thinking_settings.dart';
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
    final style = ref.watch(
      thinkingSettingsProvider.select((s) => s.displayStyle),
    );
    final inlineTools = widget.inlineToolBlocks.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < widget.inlineToolBlocks.length; i++) ...
                [
                  if (i > 0) const SizedBox(height: 6),
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
