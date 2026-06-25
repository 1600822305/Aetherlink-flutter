import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/notes/application/notes_controller.dart';
import 'package:aetherlink_flutter/features/notes/domain/note_node.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// The notes hub — a file-tree browser over the on-device notes directory.
///
/// Reached from the settings hub「笔记设置」row. Tapping a folder descends into
/// it; tapping a note opens the editor. Create / rename / delete / star / sort
/// are wired; search / import / 自选目录 are later phases and surface as
/// "即将推出" placeholders (mirroring the app's existing disabled-placeholder
/// convention). All styling uses theme tokens + lucide icons (ADR-0008/0009).
class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  static const Color _folderColor = Color(0xFFF59E0B);
  static const Color _fileColor = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(notesControllerProvider);
    final controller = ref.read(notesControllerProvider.notifier);

    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: '笔记',
        onBack: () => context.canPop()
            ? context.pop()
            : context.go(AppRouter.settingsPath),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.search, size: 20),
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: '搜索',
            onPressed: () => _comingSoon(context, '笔记搜索'),
          ),
          _SortMenu(
            current: state.sort,
            onSelected: controller.setSort,
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings, size: 20),
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: '笔记设置',
            onPressed: () => context.push(AppRouter.notesSettingsPath),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateMenu(context, ref),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(LucideIcons.plus),
      ),
      body: Column(
        children: [
          _Breadcrumbs(state: state, controller: controller),
          Divider(height: 1, color: theme.dividerColor),
          Expanded(child: _buildBody(context, ref, theme, state, controller)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    NotesState state,
    NotesController controller,
  ) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.fileText,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              state.isRoot ? '还没有笔记，点击右下角新建' : '此文件夹为空',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.only(bottom: 96 + MediaQuery.paddingOf(context).bottom),
      itemCount: state.items.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: theme.dividerColor),
      itemBuilder: (context, index) {
        final node = state.items[index];
        return _NoteRow(
          node: node,
          onTap: () {
            if (node.isDirectory) {
              controller.enterFolder(node);
            } else {
              _openEditor(context, ref, node);
            }
          },
          onToggleStar: () => controller.toggleStar(node),
          onMenu: () => _showItemMenu(context, ref, node),
        );
      },
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    NoteNode node,
  ) async {
    await context.push(AppRouter.noteEditorPath(node.relativePath, node.title));
    // Returning from the editor may have changed mtime / content.
    await ref.read(notesControllerProvider.notifier).refresh();
  }

  void _showCreateMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.filePlus, color: _fileColor),
              title: const Text('新建笔记'),
              onTap: () {
                Navigator.pop(sheetContext);
                _promptCreate(context, ref, isFolder: false);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.folderPlus, color: _folderColor),
              title: const Text('新建文件夹'),
              onTap: () {
                Navigator.pop(sheetContext);
                _promptCreate(context, ref, isFolder: true);
              },
            ),
            const ListTile(
              enabled: false,
              leading: Icon(LucideIcons.upload),
              title: Text('导入笔记'),
              subtitle: Text('即将支持'),
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptCreate(
    BuildContext context,
    WidgetRef ref, {
    required bool isFolder,
  }) async {
    final name = await _textInputDialog(
      context,
      title: isFolder ? '新建文件夹' : '新建笔记',
      hint: isFolder ? '文件夹名称' : '笔记名称',
    );
    if (name == null || name.trim().isEmpty) return;
    final controller = ref.read(notesControllerProvider.notifier);
    if (isFolder) {
      await controller.createFolder(name);
    } else {
      final relPath = await controller.createNote(name);
      if (!context.mounted) return;
      await context.push(
        AppRouter.noteEditorPath(relPath, _titleOf(name)),
      );
      await ref.read(notesControllerProvider.notifier).refresh();
    }
  }

  void _showItemMenu(BuildContext context, WidgetRef ref, NoteNode node) {
    final controller = ref.read(notesControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!node.isDirectory)
              ListTile(
                leading: Icon(
                  node.isStarred ? LucideIcons.starOff : LucideIcons.star,
                ),
                title: Text(node.isStarred ? '取消收藏' : '收藏'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  controller.toggleStar(node);
                },
              ),
            ListTile(
              leading: const Icon(LucideIcons.pencil),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(sheetContext);
                _promptRename(context, ref, node);
              },
            ),
            const ListTile(
              enabled: false,
              leading: Icon(LucideIcons.share2),
              title: Text('导出'),
              subtitle: Text('即将支持'),
              onTap: null,
            ),
            ListTile(
              leading: Icon(LucideIcons.trash2, color: Theme.of(context).colorScheme.error),
              title: Text(
                '删除',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(context, ref, node);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptRename(
    BuildContext context,
    WidgetRef ref,
    NoteNode node,
  ) async {
    final name = await _textInputDialog(
      context,
      title: '重命名',
      hint: '新名称',
      initial: node.title,
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(notesControllerProvider.notifier).rename(node, name);
    } catch (e) {
      if (context.mounted) _toast(context, '重命名失败：$e');
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    NoteNode node,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          node.isDirectory
              ? '确定删除文件夹「${node.title}」及其全部内容吗？此操作不可撤销。'
              : '确定删除笔记「${node.title}」吗？此操作不可撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(notesControllerProvider.notifier).delete(node);
  }

  Future<String?> _textInputDialog(
    BuildContext context, {
    required String title,
    required String hint,
    String? initial,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  static String _titleOf(String name) =>
      name.toLowerCase().endsWith('.md')
      ? name.substring(0, name.length - 3)
      : name;

  void _comingSoon(BuildContext context, String label) =>
      _toast(context, '$label 即将推出');

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.state, required this.controller});

  final NotesState state;
  final NotesController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crumbs = state.breadcrumbs;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          if (!state.isRoot)
            IconButton(
              icon: const Icon(LucideIcons.arrowLeft, size: 18),
              color: theme.colorScheme.onSurfaceVariant,
              tooltip: '返回上级',
              onPressed: controller.goUp,
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: crumbs.length,
              itemBuilder: (context, index) {
                final crumb = crumbs[index];
                final isLast = index == crumbs.length - 1;
                return Row(
                  children: [
                    if (index > 0)
                      Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                    TextButton(
                      onPressed: isLast ? null : () => controller.goTo(crumb.path),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        crumb.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
                          color: isLast
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.node,
    required this.onTap,
    required this.onToggleStar,
    required this.onMenu,
  });

  final NoteNode node;
  final VoidCallback onTap;
  final VoidCallback onToggleStar;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              node.isDirectory ? LucideIcons.folder : LucideIcons.fileText,
              size: 22,
              color: node.isDirectory
                  ? NotesPage._folderColor
                  : NotesPage._fileColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    node.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (!node.isDirectory) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(node.modifiedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!node.isDirectory)
              IconButton(
                icon: Icon(
                  node.isStarred ? LucideIcons.star : LucideIcons.star,
                  size: 18,
                  color: node.isStarred
                      ? const Color(0xFFF59E0B)
                      : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                tooltip: node.isStarred ? '取消收藏' : '收藏',
                onPressed: onToggleStar,
              ),
            IconButton(
              icon: Icon(
                LucideIcons.ellipsisVertical,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: '更多',
              onPressed: onMenu,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.current, required this.onSelected});

  final NotesSortType current;
  final ValueChanged<NotesSortType> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<NotesSortType>(
      icon: Icon(
        LucideIcons.arrowDownUp,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      tooltip: '排序',
      initialValue: current,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final sort in NotesSortType.values)
          PopupMenuItem<NotesSortType>(
            value: sort,
            child: Row(
              children: [
                Icon(
                  LucideIcons.check,
                  size: 16,
                  color: sort == current
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                ),
                const SizedBox(width: 8),
                Text(sort.label),
              ],
            ),
          ),
      ],
    );
  }
}
