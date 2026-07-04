/// 预设助手选择面板 — a fixed-height bottom sheet listing [kAssistantPresets]
/// with internal scrolling. Returns the selected [Assistant] preset (or `null`
/// on dismiss) so the caller can pre-fill the create-assistant form.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/assistant_presets.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';

/// Shows the preset assistant picker as a modal bottom sheet with a fixed
/// height (60% of screen) and internal scrolling.
///
/// Returns the selected [Assistant] preset, or `null` if dismissed.
Future<Assistant?> showAssistantPresetSheet(BuildContext context) {
  return showModalBottomSheet<Assistant>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _AssistantPresetSheet(),
  );
}

class _AssistantPresetSheet extends StatelessWidget {
  const _AssistantPresetSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenHeight * 0.6,
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Icon(
                  LucideIcons.sparkles,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '选择预设助手',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '选择一个预设来快速填充助手配置，之后你仍可自由修改',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 1),
          // Scrollable preset list
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.only(
                top: 8,
                bottom: 8 + MediaQuery.of(context).padding.bottom,
              ),
              itemCount: kAssistantPresets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, index) {
                final preset = kAssistantPresets[index];
                return _PresetTile(
                  preset: preset,
                  onTap: () => Navigator.of(context).pop(preset),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.preset, required this.onTap});

  final Assistant preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          preset.emoji ?? '🤖',
          style: const TextStyle(fontSize: 22),
        ),
      ),
      title: Text(
        preset.name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: preset.description == null
          ? null
          : Text(
              preset.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: Icon(
        LucideIcons.chevronRight,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
