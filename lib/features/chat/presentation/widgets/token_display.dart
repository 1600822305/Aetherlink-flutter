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
  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();

  bool get _anchorRight => widget.view.role == MessageRole.assistant;

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

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) =>
            _buildPanel(isDark, totalTokens, currentMessageTokens),
        child: InkWell(
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
      ),
    );
  }

  Widget _buildPanel(bool isDark, int totalTokens, int currentMessageTokens) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _portal.hide,
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: _anchorRight ? Alignment.topRight : Alignment.topLeft,
          followerAnchor: _anchorRight
              ? Alignment.bottomRight
              : Alignment.bottomLeft,
          offset: const Offset(0, -6),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(minWidth: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF232323) : Colors.white,
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
          ),
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
