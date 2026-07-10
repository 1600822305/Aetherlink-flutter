import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// A single settings hub row (the original `SettingItem`): a lucide icon, a
/// title with an optional description, and a trailing chevron.
///
/// [enabled] mirrors the original's disabled state — a not-yet-implemented row
/// renders at half opacity and does not respond to taps ([onTap] is ignored
/// when disabled). Colors are theme tokens only; icon size, row padding and the
/// arrow size are layout constants (ADR-0008/0009).
class SettingItem extends StatelessWidget {
  const SettingItem({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String title;

  /// Shown in detailed mode only; `null` in compact mode (titles only).
  final String? description;
  final bool enabled;
  final VoidCallback? onTap;

  static const double _iconSize = 24;
  static const double _arrowSize = 20;
  static const EdgeInsets _rowPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = this.description;
    // 禁用态直接用半透明颜色绘制，而不是包一层 Opacity——Opacity 会触发
    // saveLayer 离屏合成，设置页每个占位行一层，raster 开销明显。
    final onSurface = enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final onSurfaceVariant = enabled
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    final row = Padding(
      padding: _rowPadding,
      child: Row(
        children: [
          Icon(icon, size: _iconSize, color: onSurface),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            LucideIcons.chevronRight,
            size: _arrowSize,
            color: onSurfaceVariant,
          ),
        ],
      ),
    );

    if (!enabled) {
      return row;
    }
    return InkWell(onTap: onTap, child: row);
  }
}
