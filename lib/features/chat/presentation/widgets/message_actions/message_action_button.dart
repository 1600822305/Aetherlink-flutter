import 'dart:async';

import 'package:flutter/material.dart';

/// A single message-action icon button shared by every action surface.
///
/// Port of the original `_ToolbarIconButton`: opacity 0.8 at rest, brightening
/// to 1 and scaling to 1.1 on hover. Destructive actions ([confirmTwice]) reuse
/// the original toolbar's two-step confirmation — the first tap arms the button
/// (error color + 「再次点击确认删除」 tooltip, held bright/scaled) and a second
/// tap within [_confirmResetDelay] runs [onTap]; otherwise it disarms.
class MessageActionButton extends StatefulWidget {
  const MessageActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.confirmTwice = false,
    this.confirmColor,
    this.confirmTooltip,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  /// Whether this is a destructive action requiring a two-tap confirmation.
  final bool confirmTwice;

  /// The color shown while awaiting confirmation (typically the error color).
  final Color? confirmColor;

  /// The tooltip shown while awaiting confirmation.
  final String? confirmTooltip;

  @override
  State<MessageActionButton> createState() => _MessageActionButtonState();
}

class _MessageActionButtonState extends State<MessageActionButton> {
  static const Duration _confirmResetDelay = Duration(seconds: 3);

  bool _hovering = false;
  bool _confirming = false;
  Timer? _confirmTimer;

  @override
  void dispose() {
    _confirmTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.confirmTwice) {
      widget.onTap();
      return;
    }
    if (!_confirming) {
      setState(() => _confirming = true);
      _confirmTimer?.cancel();
      _confirmTimer = Timer(_confirmResetDelay, () {
        if (mounted) setState(() => _confirming = false);
      });
      return;
    }
    _confirmTimer?.cancel();
    setState(() => _confirming = false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final active = _hovering || _confirming;
    final color = _confirming
        ? (widget.confirmColor ?? widget.color)
        : widget.color;
    final tooltip = _confirming
        ? (widget.confirmTooltip ?? widget.tooltip)
        : widget.tooltip;

    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          child: AnimatedScale(
            scale: active ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              opacity: active ? 1.0 : 0.8,
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(widget.icon, size: 16, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
