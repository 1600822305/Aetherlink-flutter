// 单本世界书详情页 (route /settings/world-book/:bookId)：条目列表 + 搜索 +
// 增删改 + 复制 / 移到其他书 + 上下移动 + 导出。

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

class WorldBookDetailPage extends ConsumerStatefulWidget {
  const WorldBookDetailPage({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<WorldBookDetailPage> createState() =>
      _WorldBookDetailPageState();
}

/// 条目多于这个数时显示搜索框。
const int _kSearchThreshold = 6;

class _WorldBookDetailPageState extends ConsumerState<WorldBookDetailPage> {
  final _search = TextEditingController();
  String _query = '';

  String get bookId => widget.bookId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 按标题、关键词、内容搜索（不区分大小写）。
  bool _hit(WorldBookEntry e) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return e.name.toLowerCase().contains(q) ||
        e.content.toLowerCase().contains(q) ||
        e.keywords.any((k) => k.toLowerCase().contains(q)) ||
        e.secondaryKeywords.any((k) => k.toLowerCase().contains(q));
  }

  Future<void> _duplicate(BuildContext context, WidgetRef ref, WorldBookEntry entry) async {
    await _controller(ref).saveEntry(
      bookId,
      entry.copyWith(
        id: '',
        name: entry.name.isEmpty ? '' : '${entry.name}（副本）',
      ),
    );
    if (context.mounted) AppToast.success(context, '已复制条目');
  }

  Future<void> _moveToBook(BuildContext context, WidgetRef ref, WorldBookEntry entry) async {
    final books = [
      for (final b in ref.read(worldBooksControllerProvider).asData?.value ??
          const <WorldBook>[])
        if (b.id != bookId) b,
    ];
    if (books.isEmpty) return;
    final target = await showModalBottomSheet<WorldBook>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('移到哪本世界书？'),
            ),
            for (final b in books)
              ListTile(
                leading: const Icon(LucideIcons.bookOpen, size: 18),
                title: Text(b.name.isEmpty ? '未命名世界书' : b.name),
                subtitle: Text('${b.entries.length} 个条目'),
                onTap: () => Navigator.of(ctx).pop(b),
              ),
          ],
        ),
      ),
    );
    if (target == null) return;
    // 目标书里重新分配 uid；先存进去再从原书删除，失败时不会丢条目。
    await _controller(ref).saveEntry(target.id, entry.copyWith(id: ''));
    await _controller(ref).deleteEntry(bookId, entry.id);
    if (context.mounted) {
      AppToast.success(
        context,
        '已移到「${target.name.isEmpty ? '未命名世界书' : target.name}」',
      );
    }
  }

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
      message: '将删除「${entry.displayTitle.isEmpty ? '未命名条目' : entry.displayTitle}」。',
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
      case WorldBookEntryAction.duplicate:
        _duplicate(context, ref, entry);
      case WorldBookEntryAction.moveToBook:
        _moveToBook(context, ref, entry);
      case WorldBookEntryAction.delete:
        _deleteEntry(context, ref, entry);
    }
  }

  Widget _body(BuildContext context, WidgetRef ref, WorldBook book) {
    final theme = Theme.of(context);
    final constantCount = book.entries.where((e) => e.constant).length;
    final keywordCount = book.entries.length - constantCount;
    final shown = [
      for (final e in book.entries)
        if (_hit(e)) e,
    ];
    final hasOtherBooks =
        (ref.watch(worldBooksControllerProvider).asData?.value.length ?? 0) > 1;
    final searching = _query.trim().isNotEmpty;
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
        if (book.entries.length > _kSearchThreshold) ...[
          TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              hintText: '搜索标题、关键词或内容',
              suffixIcon: searching
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
        ],
        WorldBookSectionHeader(
          title: searching
              ? '找到 ${shown.length} 个条目'
              : '条目 (${book.enabledEntryCount}/${book.entries.length})',
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
        else if (shown.isEmpty)
          WorldBookOutlinedCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '没有匹配「${_query.trim()}」的条目',
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
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: theme.dividerColor),
                  WorldBookEntryRow(
                    entry: shown[i],
                    canMoveToBook: hasOtherBooks,
                    onOpen: () => showWorldBookEntryEditPage(
                      context,
                      bookId: bookId,
                      entry: shown[i],
                    ),
                    onToggle: (v) => _controller(
                      ref,
                    ).setEntryEnabled(bookId, shown[i].id, v),
                    onAction: (a) => _onEntryAction(context, ref, shown[i], a),
                  ),
                ],
              ],
            ),
          ),
        if (book.entries.length > 1)
          const WorldBookHint('注入先后由每个条目的「顺序」决定（小的在前、大的更靠近末尾），列表顺序只影响显示。'),
        if (!book.enabled) const WorldBookHint('这本世界书已关闭，条目不会被注入。'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
