// 世界书列表页的交互动作（弹面板 → 调 controller → toast），从页面拆出以控制
// 单文件体量。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/world_book/application/world_book_io_service.dart';
import 'package:aetherlink_flutter/features/world_book/application/world_books_controller.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/sheets/world_book_edit_sheet.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/sheets/world_book_group_sheets.dart';
import 'package:aetherlink_flutter/features/world_book/presentation/mobile/widgets/world_book_common.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

WorldBooksController _controller(WidgetRef ref) =>
    ref.read(worldBooksControllerProvider.notifier);

/// 列表页右上角 ＋：一个入口给出「新建空白 / 导入 JSON」两种方式。
Future<void> showAddWorldBookSheet(BuildContext context, WidgetRef ref) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      Widget item(String value, IconData icon, String title, String subtitle) =>
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            horizontalTitleGap: 12,
            minLeadingWidth: 20,
            leading: Icon(icon, size: 18, color: theme.colorScheme.primary),
            title: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
            ),
            subtitle: Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            onTap: () => Navigator.of(ctx).pop(value),
          );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '添加世界书',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            item('create', LucideIcons.squarePen, '新建空白世界书', '填写名称和描述'),
            item(
              'import',
              LucideIcons.upload,
              '导入 JSON',
              '支持 SillyTavern / RikkaHub 导出的文件',
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'create':
      await createWorldBook(context, ref);
    case 'import':
      await importWorldBook(context, ref);
  }
}

Future<void> createWorldBook(BuildContext context, WidgetRef ref) async {
  final result = await showModalBottomSheet<WorldBookEditResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => const WorldBookEditSheet(title: '新建世界书'),
  );
  if (result == null) return;
  await _controller(
    ref,
  ).createBook(result.name, description: result.description);
  if (context.mounted) AppToast.success(context, '已创建「${result.name}」');
}

Future<void> renameWorldBook(
  BuildContext context,
  WidgetRef ref,
  WorldBook book,
) async {
  final result = await showModalBottomSheet<WorldBookEditResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => WorldBookEditSheet(
      title: '编辑世界书',
      initialName: book.name,
      initialDescription: book.description,
    ),
  );
  if (result == null) return;
  await _controller(ref).renameBook(book.id, result.name, result.description);
}

Future<void> deleteWorldBook(
  BuildContext context,
  WidgetRef ref,
  WorldBook book,
) async {
  final ok = await confirmWorldBookAction(
    context,
    title: '删除世界书',
    message: '将删除「${book.name}」及其全部 ${book.entries.length} 个条目。此操作不可撤销。',
    confirmLabel: '删除',
    destructive: true,
  );
  if (!ok) return;
  await _controller(ref).deleteBook(book.id);
  if (context.mounted) AppToast.success(context, '已删除「${book.name}」');
}

Future<void> importWorldBook(BuildContext context, WidgetRef ref) async {
  try {
    final outcome = await pickWorldBookFile();
    switch (outcome) {
      case WorldBookPickCancelled():
        return;
      case WorldBookPickInvalid(:final message):
        if (context.mounted) AppToast.warning(context, '导入失败：$message');
        return;
      case WorldBookPickParsed(:final result):
        final saved = await _controller(ref).importBook(result);
        if (!context.mounted) return;
        final count = saved.book.entries.length;
        final pending = saved.pendingEntryCount;
        if (pending > 0) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('导入完成'),
              content: Text(
                '已导入「${saved.book.name}」，共 $count 个条目。\n\n'
                '其中 $pending 条用到了暂未生效的 SillyTavern 功能'
                '（如概率、包含组、递归、作者注释位置等）。这些设置已完整保存，'
                '条目照常启用，相关功能上线后会自动生效。',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('知道了'),
                ),
              ],
            ),
          );
        } else {
          AppToast.success(context, '已导入「${saved.book.name}」，共 $count 个条目');
        }
    }
  } catch (e) {
    if (context.mounted) AppToast.error(context, '导入失败：$e');
  }
}

/// 导出为 SillyTavern 原生世界书（可直接导入酒馆，也能无损导回本应用）。
Future<void> exportWorldBook(BuildContext context, WorldBook book) async {
  try {
    final saved = await exportWorldBookFile(book);
    if (saved && context.mounted) AppToast.success(context, '已导出「${book.name}」');
  } catch (e) {
    if (context.mounted) AppToast.error(context, '导出失败：$e');
  }
}

Future<void> pickWorldBookGroup(
  BuildContext context,
  WidgetRef ref,
  WorldBook book,
  List<String> groups,
) async {
  final result = await showModalBottomSheet<WorldBookGroupPickResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) =>
        WorldBookGroupPickerSheet(current: book.groupName, groups: groups),
  );
  if (result == null) return;
  await _controller(ref).setBookGroup(book.id, result.groupName);
  if (context.mounted) {
    AppToast.success(
      context,
      result.groupName == null
          ? '已将「${book.name}」移出分组'
          : '已将「${book.name}」移入「${result.groupName}」',
    );
  }
}

Future<void> renameWorldBookGroup(
  BuildContext context,
  WidgetRef ref,
  String group,
) async {
  final name = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => WorldBookGroupNameSheet(title: '重命名分组', initial: group),
  );
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == group) return;
  await _controller(ref).renameGroup(group, trimmed);
  if (context.mounted) AppToast.success(context, '已重命名为「$trimmed」');
}

Future<void> dissolveWorldBookGroup(
  BuildContext context,
  WidgetRef ref,
  String group,
) async {
  final ok = await confirmWorldBookAction(
    context,
    title: '解散分组',
    message: '将解散「$group」，组内世界书移回未分组（书本身保留）。',
    confirmLabel: '解散',
  );
  if (!ok) return;
  await _controller(ref).dissolveGroup(group);
  if (context.mounted) AppToast.success(context, '已解散「$group」');
}
