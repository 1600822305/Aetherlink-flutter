// 世界书列表页的列表小部件：分组标题 / 书卡片 / 书行 / 空状态。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_common.dart';

/// 书行菜单动作。
enum WorldBookRowAction { rename, moveUp, moveDown, group, export, delete }

class WorldBookListCard extends StatelessWidget {
  const WorldBookListCard({
    super.key,
    required this.books,
    required this.onOpen,
    required this.onToggle,
    required this.onAction,
  });

  final List<WorldBook> books;
  final ValueChanged<WorldBook> onOpen;
  final void Function(WorldBook book, bool enabled) onToggle;
  final void Function(WorldBook book, WorldBookRowAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WorldBookOutlinedCard(
      child: Column(
        children: [
          for (var i = 0; i < books.length; i++) ...[
            if (i > 0) Divider(height: 1, color: theme.dividerColor),
            WorldBookListRow(
              book: books[i],
              onOpen: () => onOpen(books[i]),
              onToggle: (v) => onToggle(books[i], v),
              onAction: (a) => onAction(books[i], a),
            ),
          ],
        ],
      ),
    );
  }
}

class WorldBookListRow extends StatelessWidget {
  const WorldBookListRow({
    super.key,
    required this.book,
    required this.onOpen,
    required this.onToggle,
    required this.onAction,
  });

  final WorldBook book;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;
  final ValueChanged<WorldBookRowAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = StringBuffer(
      '已启用 ${book.enabledEntryCount}/${book.entries.length} 条',
    );
    if (book.description.isNotEmpty) subtitle.write(' · ${book.description}');
    return ListTile(
      onTap: onOpen,
      leading: Icon(
        LucideIcons.bookMarked,
        color: book.enabled
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        book.name.isEmpty ? '未命名世界书' : book.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle.toString(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomSwitch(value: book.enabled, onChanged: onToggle),
          PopupMenuButton<WorldBookRowAction>(
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
                value: WorldBookRowAction.rename,
                child: Text('重命名'),
              ),
              PopupMenuItem(value: WorldBookRowAction.moveUp, child: Text('上移')),
              PopupMenuItem(
                value: WorldBookRowAction.moveDown,
                child: Text('下移'),
              ),
              PopupMenuItem(
                value: WorldBookRowAction.group,
                child: Text('移动到分组'),
              ),
              PopupMenuItem(
                value: WorldBookRowAction.export,
                child: Text('导出 JSON'),
              ),
              PopupMenuItem(
                value: WorldBookRowAction.delete,
                child: Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 分组小标题：名称 + 数量，具名分组带重命名 / 解散菜单。
class WorldBookGroupHeader extends StatelessWidget {
  const WorldBookGroupHeader({
    super.key,
    required this.name,
    required this.count,
    this.onRename,
    this.onDissolve,
  });

  final String name;
  final int count;
  final VoidCallback? onRename;
  final VoidCallback? onDissolve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMenu = onRename != null || onDissolve != null;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Icon(
            LucideIcons.folder,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$name ($count)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (hasMenu)
            PopupMenuButton<String>(
              popUpAnimationStyle: AnimationStyle.noAnimation,
              icon: Icon(
                LucideIcons.ellipsis,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: '分组操作',
              onSelected: (value) {
                if (value == 'rename') onRename?.call();
                if (value == 'dissolve') onDissolve?.call();
              },
              itemBuilder: (ctx) => [
                if (onRename != null)
                  const PopupMenuItem(value: 'rename', child: Text('重命名分组')),
                if (onDissolve != null)
                  const PopupMenuItem(value: 'dissolve', child: Text('解散分组')),
              ],
            )
          else
            const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class WorldBooksEmptyHint extends StatelessWidget {
  const WorldBooksEmptyHint({
    super.key,
    required this.onCreate,
    required this.onImport,
  });

  final VoidCallback onCreate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WorldBookOutlinedCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Icon(
              LucideIcons.bookMarked,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text('还没有世界书', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '世界书在对话出现关键词时，把设定文本注入给模型',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('新建'),
                ),
                OutlinedButton.icon(
                  onPressed: onImport,
                  icon: const Icon(LucideIcons.upload, size: 16),
                  label: const Text('导入 JSON'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
