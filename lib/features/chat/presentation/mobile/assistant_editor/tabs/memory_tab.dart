import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/presentation/mobile/assistant_editor/editor_card.dart';
import 'package:aetherlink_flutter/features/memory/presentation/mobile/assistant_memory_index_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

// ── 记忆 ─────────────────────────────────────────────────────────────────────

class MemoryTab extends StatelessWidget {
  const MemoryTab({
    super.key,
    required this.assistantId,
    required this.assistantName,
    required this.enabled,
    required this.onChanged,
  });

  final String assistantId;
  final String assistantName;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EditorCard(
          child: Row(
            children: [
              Icon(
                LucideIcons.brain,
                size: 20,
                color: theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '启用记忆功能',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '开启后，助手会记住与你的对话内容',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              CustomSwitch(value: enabled, onChanged: onChanged),
            ],
          ),
        ),
        if (enabled) ...[
          const SizedBox(height: 16),
          Material(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: assistantId.isEmpty
                  ? null
                  : () => context.push(
                      AssistantMemoryRoute.pathFor(assistantId),
                      extra: assistantName,
                    ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.bookOpen,
                      size: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '私有记忆',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '管理该助手的私有记忆：添加 / 搜索 / 编辑 / 删除',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
