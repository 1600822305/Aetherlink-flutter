import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:aetherlink_flutter/features/knowledge/application/knowledge_providers.dart';
import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_item.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 回收站面板（功能缺口⑩）：展示本库软删除条目，每条可恢复（从保留正文重建
/// 索引）或彻底删除，并支持一键清空。
class KnowledgeTrashSheet extends ConsumerWidget {
  const KnowledgeTrashSheet({super.key, required this.baseId});

  final String baseId;

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    KnowledgeItem item,
  ) async {
    try {
      await ref
          .read(knowledgeItemsControllerProvider(baseId).notifier)
          .restoreItem(item.id);
      if (context.mounted) {
        AppToast.success(context, '已恢复「${item.title ?? item.source}」');
      }
    } catch (e) {
      if (context.mounted) AppToast.error(context, '恢复失败：$e');
    }
  }

  Future<void> _purge(
    BuildContext context,
    WidgetRef ref,
    KnowledgeItem item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('彻底删除'),
        content: Text('将彻底删除「${item.title ?? item.source}」及其正文。此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('彻底删除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref
          .read(knowledgeItemsControllerProvider(baseId).notifier)
          .purgeItem(item.id);
      if (context.mounted) {
        AppToast.success(context, '已彻底删除「${item.title ?? item.source}」');
      }
    } catch (e) {
      if (context.mounted) AppToast.error(context, '删除失败：$e');
    }
  }

  Future<void> _emptyTrash(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空回收站'),
        content: const Text('将彻底删除回收站里的全部条目。此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final count = await ref
          .read(knowledgeItemsControllerProvider(baseId).notifier)
          .emptyTrash();
      if (context.mounted) AppToast.success(context, '已清空回收站（$count 个条目）');
    } catch (e) {
      if (context.mounted) AppToast.error(context, '清空失败：$e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trashAsync = ref.watch(knowledgeTrashProvider(baseId));
    final items = trashAsync.asData?.value ?? const <KnowledgeItem>[];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        // 标题行（含「清空」）固定，条目列表在下方滚动。
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '回收站 (${items.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (items.isNotEmpty)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      onPressed: () => _emptyTrash(context, ref),
                      child: const Text('清空'),
                    ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (trashAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          '回收站是空的',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    for (final item in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          LucideIcons.trash2,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          item.title ?? item.source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: item.deletedAt == null
                            ? null
                            : Text(
                                '删除于 ${_formatTime(item.deletedAt!)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(LucideIcons.undo2, size: 18),
                              color: theme.colorScheme.primary,
                              tooltip: '恢复',
                              onPressed: () => _restore(context, ref, item),
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.x, size: 18),
                              color: theme.colorScheme.error,
                              tooltip: '彻底删除',
                              onPressed: () => _purge(context, ref, item),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) {
    String pad(int v) => v.toString().padLeft(2, '0');
    return '${time.year}-${pad(time.month)}-${pad(time.day)} '
        '${pad(time.hour)}:${pad(time.minute)}';
  }
}
