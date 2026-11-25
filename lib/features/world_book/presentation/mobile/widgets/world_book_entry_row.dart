// 条目列表行：名称 / 关键词标签·位置摘要 / 启用开关 / 更多菜单。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_common.dart';

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

  /// 最多展示的关键词标签数，其余折成「+N」。
  static const int _maxKeywordChips = 3;

  String _position() => entry.position == WorldBookInjectionPosition.atDepth
      ? '深度 ${entry.injectDepth}'
      : worldBookPositionLabel(entry.position);

  Widget _summary(ThemeData theme) {
    final position = _position();
    final prefix = entry.enabled ? '' : '已关闭 · ';
    if (entry.constantActive) return Text('$prefix$position');
    if (entry.keywords.isEmpty) return Text('$prefix无关键词 · $position');
    final shown = entry.keywords.take(_maxKeywordChips).toList();
    final rest = entry.keywords.length - shown.length;
    return Text.rich(
      TextSpan(
        children: [
          if (prefix.isNotEmpty) TextSpan(text: prefix),
          for (final k in shown)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _KeywordChip(k),
            ),
          TextSpan(text: '${rest > 0 ? '+$rest ' : ''}· $position'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WorldBookTile(
      onTap: onOpen,
      dimmed: !entry.enabled,
      leading: WorldBookIconTile(
        icon: entry.constantActive ? LucideIcons.pin : LucideIcons.fileText,
        active: entry.enabled,
      ),
      title: entry.name.isEmpty ? '未命名条目' : entry.name,
      titleBadges: [
        if (entry.constantActive)
          const WorldBookBadge('常驻', color: Color(0xFF10B981)),
      ],
      subtitle: _summary(theme),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomSwitch(value: entry.enabled, onChanged: onToggle),
          const SizedBox(width: 4),
          WorldBookMoreMenu<WorldBookEntryAction>(
            onSelected: onAction,
            items: const [
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

class _KeywordChip extends StatelessWidget {
  const _KeywordChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 11,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
