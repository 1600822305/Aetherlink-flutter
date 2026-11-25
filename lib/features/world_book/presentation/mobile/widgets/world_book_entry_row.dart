// 条目列表行：名称 / 关键词标签·位置摘要 / 启用开关 / 更多菜单。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_import.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_timed_selection.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_common.dart';

enum WorldBookEntryAction { moveUp, moveDown, duplicate, moveToBook, delete }

/// 注入位置的中文标签（列表与编辑页共用），对应 ST 的 8 个位置。
String worldBookPositionLabel(WorldBookInjectionPosition position) =>
    switch (position) {
      WorldBookInjectionPosition.beforeSystemPrompt => '系统提示词之前',
      WorldBookInjectionPosition.afterSystemPrompt => '系统提示词之后',
      WorldBookInjectionPosition.authorNoteTop => '作者注释顶部',
      WorldBookInjectionPosition.authorNoteBottom => '作者注释底部',
      WorldBookInjectionPosition.atDepth => '指定深度',
      WorldBookInjectionPosition.examplesBefore => '示例消息之前',
      WorldBookInjectionPosition.examplesAfter => '示例消息之后',
      WorldBookInjectionPosition.outlet => 'Outlet',
    };

/// 指定深度的角色标签。
String worldBookRoleLabel(WorldBookInjectionRole role) => switch (role) {
  WorldBookInjectionRole.system => '系统',
  WorldBookInjectionRole.user => '用户',
  WorldBookInjectionRole.assistant => '助手',
};

class WorldBookEntryRow extends StatelessWidget {
  const WorldBookEntryRow({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onToggle,
    required this.onAction,
    this.canMoveToBook = true,
  });

  /// 有其他世界书时才显示「移到其他世界书」。
  final bool canMoveToBook;

  final WorldBookEntry entry;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;
  final ValueChanged<WorldBookEntryAction> onAction;

  /// 最多展示的关键词标签数，其余折成「+N」。
  static const int _maxKeywordChips = 3;

  String _position() => switch (entry.position) {
    WorldBookInjectionPosition.atDepth =>
      '深度 ${entry.depth} · ${worldBookRoleLabel(entry.role)}',
    WorldBookInjectionPosition.outlet =>
      'Outlet ${entry.outletName.isEmpty ? '' : '「${entry.outletName}」'}'
          .trim(),
    _ => worldBookPositionLabel(entry.position),
  };

  /// 行尾的小字：大约多少 token。
  String _size() => '约 ${worldBookRoughTokens(entry.content)} tokens';

  Widget _summary(ThemeData theme) {
    final position = '${_position()} · ${_size()}';
    final prefix = entry.enabled ? '' : '已关闭 · ';
    if (entry.constant) return Text('$prefix$position');
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
        icon: entry.constant ? LucideIcons.pin : LucideIcons.fileText,
        active: entry.enabled,
      ),
      title: entry.displayTitle.isEmpty ? '未命名条目' : entry.displayTitle,
      titleBadges: [
        if (entry.constant)
          const WorldBookBadge('常驻', color: Color(0xFF10B981)),
        if (entry.useProbability && entry.probability < 100)
          WorldBookBadge('${entry.probability}%'),
        if ((entry.sticky ?? 0) > 0 ||
            (entry.cooldown ?? 0) > 0 ||
            (entry.delay ?? 0) > 0)
          const WorldBookBadge('计时'),
        if (entry.groups.isNotEmpty) WorldBookBadge('组·${entry.groups.first}'),
        if (worldBookPendingFeatures(entry).isNotEmpty)
          const WorldBookBadge('部分不生效', color: Color(0xFFF59E0B)),
      ],
      subtitle: _summary(theme),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomSwitch(value: entry.enabled, onChanged: onToggle),
          const SizedBox(width: 4),
          WorldBookMoreMenu<WorldBookEntryAction>(
            onSelected: onAction,
            items: [
              const PopupMenuItem(
                value: WorldBookEntryAction.moveUp,
                child: Text('上移'),
              ),
              const PopupMenuItem(
                value: WorldBookEntryAction.moveDown,
                child: Text('下移'),
              ),
              const PopupMenuItem(
                value: WorldBookEntryAction.duplicate,
                child: Text('复制'),
              ),
              if (canMoveToBook)
                const PopupMenuItem(
                  value: WorldBookEntryAction.moveToBook,
                  child: Text('移到其他世界书'),
                ),
              const PopupMenuItem(
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
