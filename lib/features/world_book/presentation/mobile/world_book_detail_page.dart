// 单本世界书详情页 (route /settings/world-book/:bookId)：条目列表 + 增删改 +
// 上下移动 + 导出。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/world_book/application/world_books_controller.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/world_book_actions.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/world_book_entry_edit_page.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_common.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_entry_row.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

class WorldBookDetailPage extends ConsumerWidget {
  const WorldBookDetailPage({super.key, required this.bookId});

  final String bookId;

  WorldBooksController _controller(WidgetRef ref) =>
      ref.read(worldBooksControllerProvider.notifier);

  Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    WorldBookEntry entry,
  ) async {
    final ok = await confirmWorldBookAction(
      context,
      title: '删除条目',
      message: '将删除「${entry.name.isEmpty ? '未命名条目' : entry.name}」。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) return;
    await _controller(ref).deleteEntry(bookId, entry.id);
    if (context.mounted) AppToast.success(context, '已删除条目');
  }

  void _onEntryAction(
    BuildContext context,
    WidgetRef ref,
    WorldBookEntry entry,
    WorldBookEntryAction action,
  ) {
    switch (action) {
      case WorldBookEntryAction.moveUp:
        _controller(ref).moveEntry(bookId, entry.id, -1);
      case WorldBookEntryAction.moveDown:
        _controller(ref).moveEntry(bookId, entry.id, 1);
      case WorldBookEntryAction.delete:
        _deleteEntry(context, ref, entry);
    }
  }

  Widget _body(BuildContext context, WidgetRef ref, WorldBook book) {
    final theme = Theme.of(context);
    final constantCount = book.entries.where((e) => e.constantActive).length;
    final keywordCount = book.entries.length - constantCount;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (book.description.isNotEmpty) ...[
          WorldBookOutlinedCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      book.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        height: 1.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (book.groupName != null) WorldBookBadge(book.groupName!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        WorldBookSectionHeader(
          title: '条目 (${book.enabledEntryCount}/${book.entries.length})',
          trailing: book.entries.isEmpty
              ? null
              : Text('常驻 $constantCount · 关键词 $keywordCount'),
        ),
        if (book.entries.isEmpty)
          WorldBookOutlinedCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '还没有条目，点右上角 ＋ 新建',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          WorldBookOutlinedCard(
            child: Column(
              children: [
                for (var i = 0; i < book.entries.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: theme.dividerColor),
                  WorldBookEntryRow(
                    entry: book.entries[i],
                    onOpen: () => showWorldBookEntryEditPage(
                      context,
                      bookId: bookId,
                      entry: book.entries[i],
                    ),
                    onToggle: (v) => _controller(
                      ref,
                    ).setEntryEnabled(bookId, book.entries[i].id, v),
                    onAction: (a) =>
                        _onEntryAction(context, ref, book.entries[i], a),
                  ),
                ],
              ],
            ),
          ),
        if (book.entries.length > 1)
          const WorldBookHint('同优先级的条目按列表顺序注入，可在「⋯」里上移 / 下移。'),
        if (!book.enabled) const WorldBookHint('这本世界书已关闭，条目不会被注入。'),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(worldBookByIdProvider(bookId));
    final book = bookAsync.asData?.value;
    return Scaffold(
      appBar: buildWorldBookAppBar(
        context,
        title: book == null
            ? '世界书'
            : (book.name.isEmpty ? '未命名世界书' : book.name),
        onBack: () => context.canPop()
            ? context.pop()
            : context.go(AppRouter.worldBookPath),
        actions: [
          if (book != null) ...[
            IconButton(
              icon: const Icon(LucideIcons.squarePen, size: 20),
              color: Theme.of(context).colorScheme.primary,
              tooltip: '编辑名称与描述',
              onPressed: () => renameWorldBook(context, ref, book),
            ),
            IconButton(
              icon: const Icon(LucideIcons.download, size: 20),
              color: Theme.of(context).colorScheme.primary,
              tooltip: '导出 JSON',
              onPressed: () => exportWorldBook(context, book),
            ),
            IconButton(
              icon: const Icon(LucideIcons.plus, size: 22),
              color: Theme.of(context).colorScheme.primary,
              tooltip: '新建条目',
              onPressed: () =>
                  showWorldBookEntryEditPage(context, bookId: bookId),
            ),
          ],
        ],
      ),
      body: bookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败 · $err')),
        data: (book) => book == null
            ? const Center(child: Text('世界书不存在或已被删除'))
            : _body(context, ref, book),
      ),
    );
  }
}
