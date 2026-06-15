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

    final row = Padding(
      padding: _rowPadding,
      child: Row(
        children: [
          Icon(icon, size: _iconSize, color: theme.colorScheme.onSurface),
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
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );

    if (!enabled) {
      return Opacity(opacity: 0.5, child: row);
    }
    return InkWell(onTap: onTap, child: row);
  }
}
