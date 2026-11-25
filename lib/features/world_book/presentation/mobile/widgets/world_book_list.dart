// 世界书列表页的列表小部件：分组标题 / 书卡片 / 书行 / 空状态。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_common.dart';

/// 书行菜单动作。
enum WorldBookRowAction { rename, group, export, delete }

class WorldBookListCard extends StatelessWidget {
  const WorldBookListCard({
    super.key,
    required this.books,
    required this.onOpen,
    required this.onToggle,
    required this.onAction,
    required this.onReorder,
  });

  final List<WorldBook> books;
  final ValueChanged<WorldBook> onOpen;
  final void Function(WorldBook book, bool enabled) onToggle;
  final void Function(WorldBook book, WorldBookRowAction action) onAction;

  /// 长按拖动后这张卡片里书的新顺序（id）。
  final ValueChanged<List<String>> onReorder;

  @override
  Widget build(BuildContext context) {
    return WorldBookReorderableCard(
      itemCount: books.length,
      itemKey: (i) => ValueKey(books[i].id),
      onReorder: (oldIndex, newIndex) {
        final ids = [for (final b in books) b.id];
        ids.insert(newIndex, ids.removeAt(oldIndex));
        onReorder(ids);
      },
      itemBuilder: (_, i) => WorldBookListRow(
        book: books[i],
        onOpen: () => onOpen(books[i]),
        onToggle: (v) => onToggle(books[i], v),
        onAction: (a) => onAction(books[i], a),
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

  String _subtitle() {
    final count = '${book.enabledEntryCount}/${book.entries.length} 条启用';
    final parts = <String>[
      if (!book.enabled) '已关闭',
      count,
      if (book.description.isNotEmpty) book.description,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return WorldBookTile(
      onTap: onOpen,
      dimmed: !book.enabled,
      leading: WorldBookIconTile(
        icon: LucideIcons.bookMarked,
        active: book.enabled,
      ),
      title: book.name.isEmpty ? '未命名世界书' : book.name,
      subtitle: Text(_subtitle()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomSwitch(value: book.enabled, onChanged: onToggle),
          const SizedBox(width: 4),
          WorldBookMoreMenu<WorldBookRowAction>(
            onSelected: onAction,
            items: const [
              PopupMenuItem(
                value: WorldBookRowAction.rename,
                child: Text('重命名'),
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

/// 分组小标题：名称 + 数量徽标；具名分组带重命名 / 解散菜单。
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
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            WorldBookBadge('$count'),
            const Spacer(),
            if (hasMenu)
              WorldBookMoreMenu<String>(
                tooltip: '分组操作',
                onSelected: (value) {
                  if (value == 'rename') onRename?.call();
                  if (value == 'dissolve') onDissolve?.call();
                },
                items: [
                  if (onRename != null)
                    const PopupMenuItem(value: 'rename', child: Text('重命名分组')),
                  if (onDissolve != null)
                    const PopupMenuItem(value: 'dissolve', child: Text('解散分组')),
                ],
              ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 14),
        child: Column(
          children: [
            Icon(
              LucideIcons.bookMarked,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              '还没有世界书',
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '对话中出现关键词时，世界书会把对应的设定文本注入给模型',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
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
