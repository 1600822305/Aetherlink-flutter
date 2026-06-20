import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/token_estimate.dart';

/// A compact `# 总/当前` token chip that opens a usage breakdown panel on tap.
///
/// Port of the web `TokenDisplay`: the chip shows the conversation's running
/// token total over the current message's tokens, and tapping it anchors a
/// small popover above the chip listing 输入 / 输出 / 速度 / 耗时 (when the message
/// carries provider [Usage] + [Metrics]) plus 当前消息 / 总 Token. Token counts
/// fall back to [estimateTokens] when no usage is recorded.
///
/// The total mirrors the web logic (Roo Code style): the most recent assistant
/// reply's `prompt + completion`, falling back to the summed estimate of every
/// message's text.
class TokenDisplay extends ConsumerStatefulWidget {
  const TokenDisplay({
    required this.view,
    this.showCurrentMessage = true,
    this.baseColor,
    super.key,
  });

  final ChatMessageView view;
  final bool showCurrentMessage;
  final Color? baseColor;

  @override
  ConsumerState<TokenDisplay> createState() => _TokenDisplayState();
}

class _TokenDisplayState extends ConsumerState<TokenDisplay> {
  final GlobalKey _chipKey = GlobalKey();
  final OverlayPortalController _portal = OverlayPortalController();

  void _toggle() => _portal.isShowing ? _portal.hide() : _portal.show();

  int _totalTokens(List<ChatMessageView> messages) {
    if (messages.isEmpty) return 0;
    for (var i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      if (message.role == MessageRole.assistant && message.usage != null) {
        return message.usage!.promptTokens + message.usage!.completionTokens;
      }
    }
    var total = 0;
    for (final message in messages) {
      total += estimateTokens(message.text);
    }
    return total;
  }

  int _currentMessageTokens() {
    final usage = widget.view.usage;
    if (usage != null && usage.totalTokens > 0) return usage.totalTokens;
    return estimateTokens(widget.view.text);
  }

  /// 1K/1.2K/1.0M-style abbreviation, matching the web `formatTokenCount`.
  String _format(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 10000) return '${(count / 1000).toStringAsFixed(1)}K';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(0)}K';
    return count.toString();
  }

  /// Thousands-grouped integer, matching the web `Number.toLocaleString()`.
  String _grouped(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final messages =
        ref.watch(chatControllerProvider).value?.messages ??
        const <ChatMessageView>[];

    final totalTokens = _totalTokens(messages);
    final currentMessageTokens = _currentMessageTokens();
    final displayText = widget.showCurrentMessage
        ? '${_format(totalTokens)}/${_format(currentMessageTokens)}'
        : _format(totalTokens);

    final hashColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);
    final textColor =
        widget.baseColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.8)
            : Colors.black.withValues(alpha: 0.7));

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (overlayContext) =>
          _buildPanel(overlayContext, isDark, totalTokens, currentMessageTokens),
      child: InkWell(
        key: _chipKey,
        borderRadius: BorderRadius.circular(4),
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.hash, size: 14, color: hashColor),
              const SizedBox(width: 4),
              Text(
                displayText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'monospace',
                  height: 1,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(
    BuildContext overlayContext,
    bool isDark,
    int totalTokens,
    int currentMessageTokens,
  ) {
    final chipBox = _chipKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(
      overlayContext,
    ).context.findRenderObject() as RenderBox?;
    if (chipBox == null || overlayBox == null || !chipBox.hasSize) {
      return const SizedBox.shrink();
    }
    final target =
        chipBox.localToGlobal(Offset.zero, ancestor: overlayBox) &
        chipBox.size;
    final mediaQuery = MediaQuery.of(overlayContext);

    final panel = Material(
      color: Colors.transparent,
      child: Container(
        // A compact popover (port of the web `minWidth: 180`). The max cap keeps
        // it small on mobile — without it the stretched column expands to the
        // near-full-screen width the layout delegate offers.
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFA232323)
              : Colors.white.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _statRows(totalTokens, currentMessageTokens),
        ),
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _portal.hide,
          ),
        ),
        CustomSingleChildLayout(
          delegate: _PopoverLayoutDelegate(
            target: target,
            padding: mediaQuery.padding,
          ),
          child: panel,
        ),
      ],
    );
  }

  List<Widget> _statRows(int totalTokens, int currentMessageTokens) {
    final usage = widget.showCurrentMessage ? widget.view.usage : null;
    final hasBreakdown =
        usage != null && (usage.promptTokens > 0 || usage.completionTokens > 0);
    final metrics = widget.showCurrentMessage ? widget.view.metrics : null;
    final latencySeconds = (metrics != null && metrics.latency > 0)
        ? metrics.latency / 1000
        : 0.0;
    final tokensPerSecond = (usage != null && latencySeconds > 0)
        ? usage.completionTokens / latencySeconds
        : 0.0;

    if (hasBreakdown) {
      return [
        _StatRow(
          icon: LucideIcons.arrowUp,
          label: '输入',
          value: '${_grouped(usage.promptTokens)} tokens',
        ),
        _StatRow(
          icon: LucideIcons.arrowDown,
          label: '输出',
          value: '${_grouped(usage.completionTokens)} tokens',
        ),
        if (latencySeconds > 0) ...[
          if (tokensPerSecond > 0)
            _StatRow(
              icon: LucideIcons.zap,
              label: '速度',
              value: '${tokensPerSecond.toStringAsFixed(1)} tok/s',
            ),
          _StatRow(
            icon: LucideIcons.clock,
            label: '耗时',
            value: '${latencySeconds.toStringAsFixed(1)}s',
          ),
        ],
        const Divider(height: 9, thickness: 1),
        _StatRow(
          icon: LucideIcons.sigma,
          label: '当前消息',
          value: _grouped(currentMessageTokens),
        ),
        _StatRow(
          icon: LucideIcons.hash,
          label: '总 Token',
          value: _grouped(totalTokens),
        ),
      ];
    }

    return [
      if (widget.showCurrentMessage)
        _StatRow(
          icon: LucideIcons.sigma,
          label: '当前消息',
          value: _grouped(currentMessageTokens),
        ),
      _StatRow(
        icon: LucideIcons.hash,
        label: '总 Token',
        value: _grouped(totalTokens),
      ),
    ];
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Positions the usage popover above the chip, horizontally centred on it and
/// clamped within the safe viewport, flipping below the chip when there isn't
/// room above. Mirrors the original MUI `Popover` (anchor top-center, transform
/// bottom-center) while staying on-screen on narrow mobile layouts.
class _PopoverLayoutDelegate extends SingleChildLayoutDelegate {
  _PopoverLayoutDelegate({required this.target, required this.padding});

  /// The chip's rect in the overlay's coordinate space.
  final Rect target;

  /// The viewport's safe-area insets, kept clear of the panel.
  final EdgeInsets padding;

  static const double _gap = 6;
  static const double _margin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: math.max(0.0, constraints.maxWidth - 2 * _margin),
      maxHeight: math.max(0.0, constraints.maxHeight - 2 * _margin),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = padding.left + _margin;
    final right = size.width - padding.right - _margin;
    final top = padding.top + _margin;
    final bottom = size.height - padding.bottom - _margin;

    final maxX = math.max(left, right - childSize.width);
    final x = (target.center.dx - childSize.width / 2).clamp(left, maxX);

    var y = target.top - _gap - childSize.height;
    if (y < top) {
      final below = target.bottom + _gap;
      y = (below + childSize.height <= bottom) ? below : top;
    }
    final maxY = math.max(top, bottom - childSize.height);
    final clampedY = y.clamp(top, maxY);

    return Offset(x.toDouble(), clampedY.toDouble());
  }

  @override
  bool shouldRelayout(_PopoverLayoutDelegate oldDelegate) =>
      target != oldDelegate.target || padding != oldDelegate.padding;
}
