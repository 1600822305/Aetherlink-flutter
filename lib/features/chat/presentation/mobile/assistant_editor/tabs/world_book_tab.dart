import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/world_book_access.dart';
import 'package:aetherlink_flutter/features/chat/presentation/mobile/assistant_editor/editor_card.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';

// ── 世界书 ───────────────────────────────────────────────────────────────────

/// 助手编辑器的世界书绑定 tab（结构同 [SkillsTab]）：多选书，保存时写入
/// `Assistant.worldBookIds`。话题可在聊天页单独覆盖。
class WorldBookTab extends ConsumerWidget {
  const WorldBookTab({
    super.key,
    required this.worldBookIds,
    required this.onToggle,
  });

  final List<String> worldBookIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final books =
        ref.watch(worldBookLibraryProvider).asData?.value ??
        const <WorldBook>[];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EditorCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.bookMarked,
                    size: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '绑定世界书',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '对话中出现条目关键词时，把设定注入发给模型的上下文；'
                '一本都不绑定时使用「世界书 → 全局默认」；'
                '单个话题可在聊天页「扩展 → 世界书」中覆盖或关闭',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (books.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                '暂无世界书，请先在设置 → 世界书中创建或导入',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final book in books) _bookRow(theme, book),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '已绑定 ${worldBookIds.length} 本世界书',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bookRow(ThemeData theme, WorldBook book) {
    final checked = worldBookIds.contains(book.id);
    final subtitle = book.enabled
        ? '已启用 ${book.enabledEntryCount}/${book.entries.length} 条'
        : '已在世界书设置中停用';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: checked
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onToggle(book.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: checked ? theme.colorScheme.primary : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: checked,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (_) => onToggle(book.id),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.name.isEmpty ? '未命名世界书' : book.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
