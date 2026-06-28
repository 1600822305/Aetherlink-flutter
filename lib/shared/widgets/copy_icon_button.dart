import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// A compact, reusable copy button: tap to copy [text] to the clipboard, briefly
/// swap its icon to a ✓ (for [revertAfter]), and show an [AppToast] confirmation.
///
/// Replaces the many ad-hoc `bool _copied` + `Future.delayed` implementations
/// scattered across message blocks, code blocks, etc.
class CopyIconButton extends StatefulWidget {
  const CopyIconButton({
    super.key,
    required this.text,
    this.size = 14,
    this.color,
    this.copiedColor,
    this.copyTooltip = '复制',
    this.copiedTooltip = '已复制',
    this.toastMessage = '已复制',
    this.padding = const EdgeInsets.all(4),
    this.borderRadius = 6,
    this.revertAfter = const Duration(seconds: 2),
  });

  /// The text placed on the clipboard. Empty text is a no-op.
  final String text;

  /// Icon size in logical pixels.
  final double size;

  /// Idle icon color. Defaults to `colorScheme.onSurfaceVariant`.
  final Color? color;

  /// Icon color while showing the ✓ confirmation. Defaults to a green.
  final Color? copiedColor;

  final String copyTooltip;
  final String copiedTooltip;

  /// Toast message shown after copying.
  final String toastMessage;

  final EdgeInsetsGeometry padding;
  final double borderRadius;

  /// How long the ✓ confirmation icon stays before reverting to the copy icon.
  final Duration revertAfter;

  @override
  State<CopyIconButton> createState() => _CopyIconButtonState();
}

class _CopyIconButtonState extends State<CopyIconButton> {
  bool _copied = false;
  Timer? _revertTimer;

  @override
  void dispose() {
    _revertTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleCopy() async {
    if (widget.text.isEmpty) return;
    await AppToast.copy(context, widget.text, message: widget.toastMessage);
    if (!mounted) return;
    setState(() => _copied = true);
    _revertTimer?.cancel();
    _revertTimer = Timer(widget.revertAfter, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idleColor = widget.color ?? theme.colorScheme.onSurfaceVariant;
    final doneColor = widget.copiedColor ?? const Color(0xFF10B981);
    return Tooltip(
      message: _copied ? widget.copiedTooltip : widget.copyTooltip,
      child: InkWell(
        onTap: _handleCopy,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Padding(
          padding: widget.padding,
          child: Icon(
            _copied ? LucideIcons.check : LucideIcons.copy,
            size: widget.size,
            color: _copied ? doneColor : idleColor,
          ),
        ),
      ),
    );
  }
}
