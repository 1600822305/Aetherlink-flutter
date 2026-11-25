// 「世界书」页 (设置 → 数据与知识 → 世界书, route /settings/world-book).
//
// 与知识库页同理放在 world_book feature 内：页面直接依赖本 feature 的
// application，settings 只通过 AppRouter 的路由字符串引用它。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/world_book/application/world_books_controller.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/world_book_actions.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/world_book_settings_page.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_common.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_global_default_card.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_list.dart';

class WorldBookPage extends ConsumerWidget {
  const WorldBookPage({super.key});

  void _onAction(
    BuildContext context,
    WidgetRef ref,
    WorldBook book,
    WorldBookRowAction action,
    List<String> groups,
  ) {
    switch (action) {
      case WorldBookRowAction.rename:
        renameWorldBook(context, ref, book);
      case WorldBookRowAction.group:
        pickWorldBookGroup(context, ref, book, groups);
      case WorldBookRowAction.export:
        exportWorldBook(context, book);
      case WorldBookRowAction.delete:
        deleteWorldBook(context, ref, book);
    }
  }

  Widget _card(
    BuildContext context,
    WidgetRef ref,
    List<WorldBook> books,
    List<String> groups,
  ) {
    return WorldBookListCard(
      books: books,
      onOpen: (b) => context.push(
        AppRouter.worldBookDetailPath.replaceFirst(
          ':bookId',
          Uri.encodeComponent(b.id),
        ),
      ),
      onToggle: (b, enabled) => ref
          .read(worldBooksControllerProvider.notifier)
          .setBookEnabled(b.id, enabled),
      onAction: (b, action) => _onAction(context, ref, b, action, groups),
      onReorder: (ids) =>
          ref.read(worldBooksControllerProvider.notifier).reorderBooks(ids),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(worldBooksControllerProvider);
    final books = booksAsync.asData?.value ?? const <WorldBook>[];

    // 按分组名聚合：具名分组按名排序在前，未分组殿后（同知识库页）。
    final groups = {
      for (final b in books)
        if (b.groupName != null) b.groupName!,
    }.toList()..sort();
    final ungrouped = [
      for (final b in books)
        if (b.groupName == null) b,
    ];

    return Scaffold(
      appBar: buildWorldBookAppBar(
        context,
        title: '世界书',
        onBack: () => context.canPop()
            ? context.pop()
            : context.go(AppRouter.settingsPath),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings, size: 20),
            color: Theme.of(context).colorScheme.primary,
            tooltip: '全局设置',
            onPressed: () => showWorldBookSettingsPage(context),
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus, size: 22),
            color: Theme.of(context).colorScheme.primary,
            tooltip: '新建或导入世界书',
            onPressed: () => showAddWorldBookSheet(context, ref),
          ),
        ],
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败 · $err')),
        data: (_) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            WorldBookGlobalDefaultCard(books: books),
            const SizedBox(height: 16),
            WorldBookSectionHeader(title: '世界书 (${books.length})'),
            if (books.isEmpty)
              WorldBooksEmptyHint(
                onCreate: () => createWorldBook(context, ref),
                onImport: () => importWorldBook(context, ref),
              )
            else ...[
              for (final group in groups) ...[
                WorldBookGroupHeader(
                  name: group,
                  count: books.where((b) => b.groupName == group).length,
                  onRename: () => renameWorldBookGroup(context, ref, group),
                  onDissolve: () => dissolveWorldBookGroup(context, ref, group),
                ),
                _card(context, ref, [
                  for (final b in books)
                    if (b.groupName == group) b,
                ], groups),
                const SizedBox(height: 12),
              ],
              if (ungrouped.isNotEmpty) ...[
                if (groups.isNotEmpty)
                  WorldBookGroupHeader(name: '未分组', count: ungrouped.length),
                _card(context, ref, ungrouped, groups),
              ],
              const WorldBookHint(
                '关闭的世界书对所有助手和话题都不注入；列表顺序即注入顺序，'
                '长按拖动可调整。',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
