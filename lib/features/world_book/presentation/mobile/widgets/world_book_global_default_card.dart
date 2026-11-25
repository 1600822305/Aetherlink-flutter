import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/world_book_access.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_common.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 世界书页顶部的「全局默认」卡片：显示当前全局默认书数，点击打开多选面板。
///
/// 语义（写在卡片副标题里）：全局默认只对**没有绑定任何世界书的助手**生效；
/// 助手绑定了书则用助手的；话题可单独覆盖或关闭，优先级最高。
class WorldBookGlobalDefaultCard extends ConsumerWidget {
  const WorldBookGlobalDefaultCard({super.key, required this.books});

  final List<WorldBook> books;

  Future<void> _edit(BuildContext context, WidgetRef ref, List<String> ids) async {
    final chosen = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GlobalDefaultSheet(books: books, initial: ids),
    );
    if (chosen == null) return;
    await ref.read(worldBookGlobalDefaultProvider.notifier).setIds(chosen);
    if (context.mounted) {
      AppToast.success(
        context,
        chosen.isEmpty ? '已清空全局默认' : '全局默认已设为 ${chosen.length} 本',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ids =
        ref.watch(worldBookGlobalDefaultProvider).value ?? const <String>[];
    final known = {for (final b in books) b.id};
    final count = ids.where(known.contains).length;
    return WorldBookOutlinedCard(
      child: WorldBookTile(
        onTap: () => _edit(context, ref, ids),
        leading: const WorldBookIconTile(icon: LucideIcons.globe),
        title: count == 0 ? '全局默认：未设置' : '全局默认：$count 本',
        subtitle: const Text('用于未绑定世界书的助手；助手绑定优先，话题可单独覆盖或关闭'),
        subtitleMaxLines: 2,
        trailing: Icon(
          LucideIcons.chevronRight,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _GlobalDefaultSheet extends StatefulWidget {
  const _GlobalDefaultSheet({required this.books, required this.initial});

  final List<WorldBook> books;
  final List<String> initial;

  @override
  State<_GlobalDefaultSheet> createState() => _GlobalDefaultSheetState();
}

class _GlobalDefaultSheetState extends State<_GlobalDefaultSheet> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return WorldBookSheetScaffold(
      title: '全局默认世界书',
      confirmLabel: '保存',
      onConfirm: () => Navigator.of(context).pop([
        for (final b in widget.books)
          if (_selected.contains(b.id)) b.id,
      ]),
      children: [
        if (widget.books.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('还没有世界书')),
          ),
        for (final book in widget.books)
          CheckboxListTile(
            value: _selected.contains(book.id),
            onChanged: (v) => setState(
              () => v == true
                  ? _selected.add(book.id)
                  : _selected.remove(book.id),
            ),
            title: Text(
              book.name.isEmpty ? '未命名世界书' : book.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(book.enabled ? '已启用' : '已停用（不会注入）'),
          ),
      ],
    );
  }
}
