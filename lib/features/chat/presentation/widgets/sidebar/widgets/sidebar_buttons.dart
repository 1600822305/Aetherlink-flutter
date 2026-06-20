// Shared sidebar buttons: pill, muted icon, two-tap confirm-delete.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/presentation/widgets/sidebar/sidebar_tokens.dart';

/// An outlined, pill-ish action button (创建分组 / 添加助手 / 新建话题):
/// `border 1px text.secondary`, radius 8, label 14px / 600, 16px start icon.
class SidebarPillButton extends StatelessWidget {
  const SidebarPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        side: BorderSide(color: theme.colorScheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A compact icon button mirroring MUI's `IconButton` sizing (`box` = the
/// 话题删除按钮:两次点击确认(1.5s 超时),像素级复刻原版
/// `TopicItem.handleDeleteClick`。默认态 [`LucideIcons.trash`] / opacity 0.6;
/// 确认态 [`LucideIcons.alertTriangle`] / opacity 1 / 红色。
class SidebarConfirmDeleteButton extends StatefulWidget {
  const SidebarConfirmDeleteButton({
    super.key,
    required this.size,
    required this.box,
    required this.color,
    required this.onConfirm,
  });

  final double size;
  final double box;
  final Color color;
  final VoidCallback onConfirm;

  @override
  State<SidebarConfirmDeleteButton> createState() =>
      _ConfirmDeleteButtonState();
}

class _ConfirmDeleteButtonState extends State<SidebarConfirmDeleteButton> {
  bool _pending = false;
  Timer? _timer;

  void _handleTap() {
    if (_pending) {
      _reset();
      widget.onConfirm();
    } else {
      setState(() => _pending = true);
      _timer = Timer(const Duration(milliseconds: 1500), _reset);
    }
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _pending = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final danger = _pending;
    return IconButton(
      onPressed: _handleTap,
      iconSize: widget.size,
      color: danger ? kSidebarDanger : widget.color,
      padding: EdgeInsets.all((widget.box - widget.size) / 2),
      constraints: BoxConstraints.tightFor(
        width: widget.box,
        height: widget.box,
      ),
      splashRadius: widget.box / 2,
      icon: Opacity(
        opacity: danger ? 1 : 0.6,
        child: Icon(danger ? LucideIcons.alertTriangle : LucideIcons.trash),
      ),
    );
  }
}

/// A compact icon button mirroring MUI's `IconButton` sizing (`box` = the
/// square tap area, `size` = the glyph).
class SidebarMutedIconButton extends StatelessWidget {
  const SidebarMutedIconButton({
    super.key,
    required this.icon,
    required this.size,
    required this.box,
    this.color = kSidebarMutedIcon,
    this.onPressed,
  });

  final IconData icon;
  final double size;
  final double box;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      // Settings-tab icons stay appearance-only; default to an enabled no-op so
      // they keep the original full-color tint (a null handler greys them out).
      onPressed: onPressed ?? () {},
      iconSize: size,
      color: color,
      padding: EdgeInsets.all((box - size) / 2),
      constraints: BoxConstraints.tightFor(width: box, height: box),
      splashRadius: box / 2,
      icon: Icon(icon),
    );
  }
}
