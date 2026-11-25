// 条目列表行：名称 / 位置·关键词摘要 / 启用开关 / 更多菜单。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

enum WorldBookEntryAction { moveUp, moveDown, delete }

/// 注入位置的中文标签（列表与编辑页共用）。
String worldBookPositionLabel(WorldBookInjectionPosition position) =>
    switch (position) {
      WorldBookInjectionPosition.beforeSystemPrompt => '系统提示词之前',
      WorldBookInjectionPosition.afterSystemPrompt => '系统提示词之后',
      WorldBookInjectionPosition.topOfChat => '聊天顶部',
      WorldBookInjectionPosition.bottomOfChat => '聊天底部',
      WorldBookInjectionPosition.atDepth => '指定深度',
    };

class WorldBookEntryRow extends StatelessWidget {
  const WorldBookEntryRow({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onToggle,
    required this.onAction,
  });

  final WorldBookEntry entry;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;
  final ValueChanged<WorldBookEntryAction> onAction;

  String _summary() {
    final position = entry.position == WorldBookInjectionPosition.atDepth
        ? '深度 ${entry.injectDepth}'
        : worldBookPositionLabel(entry.position);
    final trigger = entry.constantActive
        ? '常驻'
        : entry.keywords.isEmpty
        ? '无关键词'
        : entry.keywords.join('、');
    return '$position · $trigger';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onOpen,
      leading: Icon(
        entry.constantActive ? LucideIcons.pin : LucideIcons.fileText,
        size: 20,
        color: entry.enabled
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        entry.name.isEmpty ? '未命名条目' : entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _summary(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomSwitch(value: entry.enabled, onChanged: onToggle),
          PopupMenuButton<WorldBookEntryAction>(
            popUpAnimationStyle: AnimationStyle.noAnimation,
            icon: Icon(
              LucideIcons.ellipsis,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: '更多操作',
            onSelected: onAction,
            itemBuilder: (ctx) => const [
              PopupMenuItem(
                value: WorldBookEntryAction.moveUp,
                child: Text('上移'),
              ),
              PopupMenuItem(
                value: WorldBookEntryAction.moveDown,
                child: Text('下移'),
              ),
              PopupMenuItem(
                value: WorldBookEntryAction.delete,
                child: Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
