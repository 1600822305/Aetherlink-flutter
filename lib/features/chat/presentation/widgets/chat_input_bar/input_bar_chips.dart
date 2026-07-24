import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';

class MentionChips extends StatelessWidget {
  const MentionChips({
    super.key,
    required this.mentions,
    required this.onRemove,
    required this.onClear,
  });

  final List<CurrentModel> mentions;
  final void Function(String providerId, String modelId) onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          Icon(
            Icons.compare_arrows,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in mentions)
                  InputChip(
                    label: Text(m.model.name, style: theme.textTheme.bodySmall),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onDeleted: () => onRemove(m.provider.id, m.model.id),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

/// The 建议模型 follow-up suggestion bubbles shown above the composer. Tap a
/// bubble to send it as a new message; long-press to fill it into the field for
/// editing first (the "两者都要" behavior). Hidden when there are no suggestions.
class SuggestionBubbles extends StatelessWidget {
  const SuggestionBubbles({
    super.key,
    required this.suggestions,
    required this.onTap,
    required this.onLongPress,
  });

  final List<String> suggestions;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onLongPress;

  @override
  Widget build(BuildContext context) {
    final visible = <String>[
      for (final s in suggestions)
        if (s.trim().isNotEmpty) s.trim(),
    ];
    if (visible.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : cs.primaryContainer.withValues(alpha: 0.42);
    final textColor = cs.onSurface.withValues(alpha: isDark ? 0.92 : 0.88);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in visible)
              Semantics(
                button: true,
                label: suggestion,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onTap(suggestion),
                  onLongPress: () => onLongPress(suggestion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      suggestion,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The pending-attachment chips shown above the field: one compact chip per
/// staged file (icon + name + size) with a ✕ to drop it. Mirrors the original's
/// converted-file chips in the input box.
class ComposerAttachmentChips extends StatelessWidget {
  const ComposerAttachmentChips({
    super.key,
    required this.attachments,
    required this.onRemove,
  });

  final List<ComposerAttachment> attachments;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final attachment in attachments)
          Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _leading(theme, attachment),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    attachment.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatBytes(attachment.size),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 2),
                InkResponse(
                  radius: 14,
                  onTap: () => onRemove(attachment.id),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      LucideIcons.x,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// The chip's leading affordance: a small thumbnail for an image attachment,
  /// else a type icon (binary file vs text/document).
  Widget _leading(ThemeData theme, ComposerAttachment attachment) {
    if (attachment.kind == ComposerAttachmentKind.image) {
      final data = attachment.base64Data;
      if (data != null && data.isNotEmpty) {
        try {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(
              base64Decode(data),
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          );
        } on FormatException {
          // fall through to the icon
        }
      }
    }
    return Icon(
      attachment.kind == ComposerAttachmentKind.file
          ? LucideIcons.file
          : LucideIcons.fileText,
      size: 16,
      color: theme.colorScheme.primary,
    );
  }

  /// Human-readable byte size (port of the FILE block's `formatFileSize`).
  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    final value = unit == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
    return '$value ${units[unit]}';
  }
}
