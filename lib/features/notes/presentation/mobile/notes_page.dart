import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/notes_ai_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/core/platform/platform_providers.dart';
import 'package:aetherlink_flutter/features/notes/application/notes_controller.dart';
import 'package:aetherlink_flutter/features/notes/application/notes_search_controller.dart';
import 'package:aetherlink_flutter/features/notes/domain/note_node.dart';
import 'package:aetherlink_flutter/features/notes/domain/note_search_result.dart';
import 'package:aetherlink_flutter/features/notes/presentation/mobile/note_image_export.dart';
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

    return Scaffold(
      appBar: ModelSettingsAppBar(
        title: '笔记',
        onBack: () => context.canPop()
            ? context.pop()
            : context.go(AppRouter.settingsPath),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings, size: 20),
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: '笔记设置',
            onPressed: () => context.push(AppRouter.notesSettingsPath),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildFileCard(context, ref, theme)),
            const SizedBox(height: 8),
            Text(
              '注意：笔记功能依赖于本地文件系统访问权限。请确保已授予应用相应的存储权限。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The web 「笔记文件」 management card: a header toolbar (new note /
  /// new folder / sort / favorites / search), an inline breadcrumb, the file
  /// list and a bottom import affordance — all inside one rounded card.
  Widget _buildFileCard(BuildContext context, WidgetRef ref, ThemeData theme) {
    final state = ref.watch(notesControllerProvider);
    final controller = ref.read(notesControllerProvider.notifier);
    final search = ref.watch(notesSearchControllerProvider);
    final searchCtrl = ref.read(notesSearchControllerProvider.notifier);
    final searching = search.active && search.hasQuery;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
              child: Row(
                children: [
                  Text(
                    '笔记文件',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.filePlus, size: 18),
                    color: theme.colorScheme.onSurfaceVariant,
                    tooltip: '新建笔记',
                    onPressed: () =>
                        _promptCreate(context, ref, isFolder: false),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.folderPlus, size: 18),
                    color: theme.colorScheme.onSurfaceVariant,
                    tooltip: '新建文件夹',
                    onPressed: () =>
                        _promptCreate(context, ref, isFolder: true),
                  ),
                  _SortMenu(
                    current: state.sort,
                    onSelected: controller.setSort,
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.star, size: 18),
                    color: theme.disabledColor,
                    tooltip: '收藏（即将推出）',
                    onPressed: null,
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.search, size: 18),
                    color: search.active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    tooltip: '搜索',
                    onPressed: () =>
                        search.active ? searchCtrl.close() : searchCtrl.open(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            if (search.active)
              _SearchBar(
                loading: search.loading,
                onChanged: searchCtrl.search,
                onClose: searchCtrl.close,
              ),
            if (searching)
              Expanded(child: _buildSearchResults(context, ref, theme, search))
            else ...[
              _Breadcrumbs(
                state: state,
                controller: controller,
                onMoveTo: (dragged, destPath) =>
                    _move(context, ref, dragged, destPath),
              ),
              Divider(height: 1, color: theme.dividerColor),
              Expanded(
                child: _buildBody(context, ref, theme, state, controller),
              ),
              Divider(height: 1, color: theme.dividerColor),
              _ImportArea(onTap: () => _importMenu(context, ref)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    NotesSearchState search,
  ) {
    if (search.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (search.results.isEmpty) {
      return Center(
        child: Text(
          '未找到匹配的笔记',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: search.results.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: theme.dividerColor),
      itemBuilder: (context, index) {
        final result = search.results[index];
        return _SearchResultRow(
          result: result,
          onTap: () => _openEditor(context, ref, result.node),
        );
      },
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
              state.isRoot ? '还没有笔记，点击上方 + 新建' : '此文件夹为空',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
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
          onMenu: () => _showItemMenu(context, ref, node),
          onAcceptDrop: node.isDirectory
              ? (dragged) => _move(context, ref, dragged, node.relativePath)
              : null,
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
      await context.push(AppRouter.noteEditorPath(relPath, _titleOf(name)));
      await ref.read(notesControllerProvider.notifier).refresh();
    }
  }

  /// Lets the user import notes into the current folder, either by picking one
  /// or more `.md` files or a whole folder (subtree preserved, `.md` only).
  Future<void> _importMenu(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.fileText, color: _fileColor),
              title: const Text('导入 Markdown 文件'),
              subtitle: const Text('可多选 .md 文件'),
              onTap: () {
                Navigator.pop(sheetContext);
                _importFiles(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.folderOpen, color: _folderColor),
              title: const Text('导入文件夹'),
              subtitle: const Text('保留子目录层级（仅导入 .md）'),
              onTap: () {
                Navigator.pop(sheetContext);
                _importFolder(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFiles(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['md'],
      dialogTitle: '选择要导入的 Markdown 文件',
    );
    if (result == null) return; // cancelled
    final paths = [
      for (final f in result.files)
        if (f.path != null) f.path!,
    ];
    if (paths.isEmpty) return;
    try {
      final count = await ref
          .read(notesControllerProvider.notifier)
          .importFiles(paths);
      if (context.mounted) {
        _toast(context, count > 0 ? '已导入 $count 个笔记' : '没有可导入的笔记');
      }
    } catch (e) {
      if (context.mounted) _toast(context, '导入失败：$e');
    }
  }

  Future<void> _importFolder(BuildContext context, WidgetRef ref) async {
    final dir = await FilePicker.getDirectoryPath(dialogTitle: '选择要导入的文件夹');
    if (dir == null) return; // cancelled
    try {
      final count = await ref
          .read(notesControllerProvider.notifier)
          .importFolder(dir);
      if (context.mounted) {
        _toast(context, count > 0 ? '已导入 $count 个笔记' : '该文件夹内没有 .md 文件');
      }
    } catch (e) {
      if (context.mounted) _toast(context, '导入失败：$e');
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
            if (!node.isDirectory)
              ListTile(
                leading: const Icon(LucideIcons.sparkles),
                title: const Text('AI 命名'),
                subtitle: const Text('用辅助模型根据内容生成标题'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _aiRename(context, ref, node);
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
            if (!node.isDirectory)
              ListTile(
                leading: const Icon(LucideIcons.share2),
                title: const Text('导出'),
                subtitle: const Text('分享 Markdown 文件或复制内容'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _exportNote(context, ref, node);
                },
              ),
            ListTile(
              leading: Icon(
                LucideIcons.trash2,
                color: Theme.of(context).colorScheme.error,
              ),
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

  Future<void> _aiRename(
    BuildContext context,
    WidgetRef ref,
    NoteNode node,
  ) async {
    final messenger = ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('正在生成标题…'),
          duration: Duration(seconds: 30),
        ),
      );
    try {
      final content = await ref
          .read(notesFileStoreProvider)
          .read(node.relativePath);
      final title = await ref
          .read(notesAiServiceProvider)
          .generateTitle(content);
      messenger.clearSnackBars();
      if (title == null || title.isEmpty) {
        if (context.mounted) {
          _toast(context, '未能生成标题（请检查辅助模型/标题模型配置）');
        }
        return;
      }
      await ref.read(notesControllerProvider.notifier).rename(node, title);
      if (context.mounted) _toast(context, '已重命名为「$title」');
    } catch (e) {
      messenger.clearSnackBars();
      if (context.mounted) _toast(context, 'AI 命名失败：$e');
    }
  }

  /// Exports a note: save the `.md` to a user-chosen location, or copy its
  /// Markdown to the clipboard. First slice of phase-3 export (Cherry's export
  /// ships many formats; Markdown is the baseline). Image / other formats later.
  Future<void> _exportNote(
    BuildContext context,
    WidgetRef ref,
    NoteNode node,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.download),
              title: const Text('另存为 Markdown 文件'),
              subtitle: const Text('选择保存位置'),
              onTap: () {
                Navigator.pop(sheetContext);
                _saveNoteFile(context, ref, node);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('导出为图片'),
              subtitle: const Text('渲染预览并保存 PNG'),
              onTap: () {
                Navigator.pop(sheetContext);
                _exportNoteImage(context, ref, node);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.copy),
              title: const Text('复制 Markdown 到剪贴板'),
              onTap: () {
                Navigator.pop(sheetContext);
                _copyNoteMarkdown(context, ref, node);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNoteFile(
    BuildContext context,
    WidgetRef ref,
    NoteNode node,
  ) async {
    try {
      final content = await ref
          .read(notesFileStoreProvider)
          .read(node.relativePath);
      final bytes = utf8.encode(content);
      final path = await FilePicker.saveFile(
        dialogTitle: '导出笔记',
        fileName: '${node.title}.md',
        type: FileType.custom,
        allowedExtensions: const ['md'],
        bytes: Uint8List.fromList(bytes),
      );
      if (path == null) return; // cancelled
      // On desktop, FilePicker.saveFile doesn't write bytes — write manually.
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await File(path).writeAsString(content);
      }
      if (context.mounted) _toast(context, '已导出');
    } catch (e) {
      if (context.mounted) _toast(context, '导出失败：$e');
    }
  }

  Future<void> _exportNoteImage(
    BuildContext context,
    WidgetRef ref,
    NoteNode node,
  ) async {
    try {
      final content = await ref
          .read(notesFileStoreProvider)
          .read(node.relativePath);
      if (content.trim().isEmpty) {
        if (context.mounted) _toast(context, '空白笔记，无内容可导出');
        return;
      }
      if (!context.mounted) return;
      final bytes = await renderNoteAsPngBytes(
        context,
        title: node.title,
        markdown: content,
      );
      if (bytes == null) {
        if (context.mounted) _toast(context, '渲染图片失败');
        return;
      }
      final path = await FilePicker.saveFile(
        dialogTitle: '导出为图片',
        fileName: '${node.title}.png',
        type: FileType.custom,
        allowedExtensions: const ['png'],
        bytes: bytes,
      );
      if (path == null) return; // cancelled
      // On desktop, FilePicker.saveFile doesn't write bytes — write manually.
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await File(path).writeAsBytes(bytes);
      }
      if (context.mounted) _toast(context, '已导出图片');
    } catch (e) {
      if (context.mounted) _toast(context, '导出图片失败：$e');
    }
  }

  Future<void> _copyNoteMarkdown(
    BuildContext context,
    WidgetRef ref,
    NoteNode node,
  ) async {
    try {
      final content = await ref
          .read(notesFileStoreProvider)
          .read(node.relativePath);
      await ref.read(clipboardApiProvider).copyText(content);
      if (context.mounted) _toast(context, '已复制到剪贴板');
    } catch (e) {
      if (context.mounted) _toast(context, '复制失败：$e');
    }
  }

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    NoteNode dragged,
    String destFolderRel,
  ) async {
    try {
      await ref
          .read(notesControllerProvider.notifier)
          .move(dragged, destFolderRel);
      if (context.mounted) _toast(context, '已移动「${dragged.title}」');
    } catch (e) {
      if (context.mounted) _toast(context, '移动失败：$e');
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
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
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

  static String _titleOf(String name) => name.toLowerCase().endsWith('.md')
      ? name.substring(0, name.length - 3)
      : name;

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({
    required this.state,
    required this.controller,
    required this.onMoveTo,
  });

  final NotesState state;
  final NotesController controller;

  /// Drop a dragged node onto a crumb to move it into that folder.
  final void Function(NoteNode dragged, String destPath) onMoveTo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crumbs = state.breadcrumbs;
    final parentPath = crumbs.length >= 2 ? crumbs[crumbs.length - 2].path : '';
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          if (!state.isRoot)
            DragTarget<NoteNode>(
              onWillAcceptWithDetails: (d) => _canMoveInto(d.data, parentPath),
              onAcceptWithDetails: (d) => onMoveTo(d.data, parentPath),
              builder: (context, candidate, rejected) => Container(
                decoration: candidate.isNotEmpty
                    ? BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        shape: BoxShape.circle,
                      )
                    : null,
                child: IconButton(
                  icon: const Icon(LucideIcons.arrowLeft, size: 18),
                  color: theme.colorScheme.onSurfaceVariant,
                  tooltip: '返回上级',
                  onPressed: controller.goUp,
                ),
              ),
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
                final labelColor = isLast
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant;
                final button = TextButton(
                  onPressed: isLast ? null : () => controller.goTo(crumb.path),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index == 0) ...[
                        Icon(LucideIcons.house, size: 14, color: labelColor),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        crumb.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isLast
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: labelColor,
                        ),
                      ),
                    ],
                  ),
                );
                return Row(
                  children: [
                    if (index > 0)
                      Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    DragTarget<NoteNode>(
                      onWillAcceptWithDetails: (d) =>
                          _canMoveInto(d.data, crumb.path),
                      onAcceptWithDetails: (d) => onMoveTo(d.data, crumb.path),
                      builder: (context, candidate, rejected) => Container(
                        decoration: candidate.isNotEmpty
                            ? BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              )
                            : null,
                        child: button,
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

/// Whether [dragged] may be moved into the folder at [destFolderRel] (root when
/// empty): not a no-op (already there / itself) and never a folder into its own
/// subtree.
bool _canMoveInto(NoteNode dragged, String destFolderRel) {
  if (dragged.relativePath == destFolderRel) return false;
  final src = dragged.relativePath;
  final parent = src.contains('/')
      ? src.substring(0, src.lastIndexOf('/'))
      : '';
  if (parent == destFolderRel) return false; // already in this folder
  if (dragged.isDirectory &&
      (destFolderRel == src || destFolderRel.startsWith('$src/'))) {
    return false; // into itself / a descendant
  }
  return true;
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.node,
    required this.onTap,
    required this.onMenu,
    this.onAcceptDrop,
  });

  final NoteNode node;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  /// Called with the dragged node when something is dropped onto this row.
  /// Non-null only for folder rows (drop = move into this folder).
  final ValueChanged<NoteNode>? onAcceptDrop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = InkWell(
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
            if (node.isStarred)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(
                  LucideIcons.star,
                  size: 16,
                  color: Color(0xFFF59E0B),
                ),
              ),
            if (node.isDirectory)
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
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

    final draggable = LongPressDraggable<NoteNode>(
      data: node,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragChip(node: node),
      childWhenDragging: Opacity(opacity: 0.4, child: row),
      child: row,
    );

    final accept = onAcceptDrop;
    if (accept == null) return draggable; // files aren't drop targets
    return DragTarget<NoteNode>(
      onWillAcceptWithDetails: (d) => _canMoveInto(d.data, node.relativePath),
      onAcceptWithDetails: (d) => accept(d.data),
      builder: (context, candidate, rejected) => Container(
        color: candidate.isNotEmpty
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : null,
        child: draggable,
      ),
    );
  }

  static String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}

/// The floating label shown under the finger while dragging a note/folder.
class _DragChip extends StatelessWidget {
  const _DragChip({required this.node});

  final NoteNode node;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.primary),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              node.isDirectory ? LucideIcons.folder : LucideIcons.fileText,
              size: 18,
              color: node.isDirectory
                  ? NotesPage._folderColor
                  : NotesPage._fileColor,
            ),
            const SizedBox(width: 8),
            Text(node.title, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.loading,
    required this.onChanged,
    required this.onClose,
  });

  final bool loading;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.search,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              autofocus: true,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: theme.textTheme.bodyMedium,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '搜索笔记名称或内容…',
              ),
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 18),
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: '关闭搜索',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// Dashed-border drop zone at the bottom of the file card. Mobile has no
/// drag-and-drop, so tapping opens the import picker instead.
class _ImportArea extends StatelessWidget {
  const _ImportArea({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.uploadCloud,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '点按导入 .md 文件或文件夹',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.result, required this.onTap});

  final NoteSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final node = result.node;
    final snippet = result.matches.isNotEmpty ? result.matches.first : null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                LucideIcons.fileText,
                size: 20,
                color: NotesPage._fileColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          node.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (result.matchType == NoteMatchType.both) ...[
                        const SizedBox(width: 6),
                        _MatchBadge(),
                      ],
                    ],
                  ),
                  if (node.relativePath.contains('/')) ...[
                    const SizedBox(height: 2),
                    Text(
                      node.relativePath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                  if (snippet != null) ...[
                    const SizedBox(height: 4),
                    _HighlightedSnippet(match: snippet),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '全',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }
}

class _HighlightedSnippet extends StatelessWidget {
  const _HighlightedSnippet({required this.match});

  final NoteSearchMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final text = match.context;
    final start = match.matchStart.clamp(0, text.length);
    final end = match.matchEnd.clamp(start, text.length);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: base?.copyWith(
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.18,
              ),
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
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
