import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/notes/application/notes_controller.dart';
import 'package:aetherlink_flutter/features/notes/domain/note_node.dart';

/// Embedded notes browser for the chat sidebar 笔记 Tab — a compact version of
/// [NotesPage] that reuses [notesControllerProvider]. Browse folders inline,
/// tap a note to open the editor. Advanced management (rename/delete/sort)
/// lives on the full page, reachable via the expand button.
///
/// [onNavigate] is invoked right before pushing a route so the host (the chat
/// sidebar) can close the drawer — the notes feature can't import chat's
/// `SidebarScope`, so the host passes the close callback down.
class NotesSidebarPanel extends ConsumerWidget {
  const NotesSidebarPanel({this.onNavigate, super.key});

  final VoidCallback? onNavigate;

  static const Color _folderColor = Color(0xFFF59E0B);
  static const Color _fileColor = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(notesControllerProvider);
    final controller = ref.read(notesControllerProvider.notifier);
    final folderName = state.isRoot
        ? '笔记'
        : state.currentPath.split('/').last;

    return Column(
      children: [
        // Compact header: back + current folder + new note + open full page.
        SizedBox(
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
                child: Text(
                  folderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.filePlus, size: 18),
                color: theme.colorScheme.onSurfaceVariant,
                tooltip: '新建笔记',
                onPressed: () => _newNote(context, ref),
              ),
              IconButton(
                icon: const Icon(LucideIcons.maximize2, size: 16),
                color: theme.colorScheme.onSurfaceVariant,
                tooltip: '打开完整笔记',
                onPressed: () {
                  onNavigate?.call();
                  context.push(AppRouter.notesPath);
                },
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        Expanded(child: _buildBody(context, ref, theme, state, controller)),
      ],
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            state.isRoot ? '还没有笔记，点上方 + 新建' : '此文件夹为空',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final node = state.items[index];
        return _PanelRow(
          node: node,
          onTap: () => _onTap(context, ref, controller, node),
          onToggleStar: () => controller.toggleStar(node),
        );
      },
    );
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    NotesController controller,
    NoteNode node,
  ) async {
    if (node.isDirectory) {
      controller.enterFolder(node);
      return;
    }
    onNavigate?.call();
    await context.push(AppRouter.noteEditorPath(node.relativePath, node.title));
    await controller.refresh();
  }

  Future<void> _newNote(BuildContext context, WidgetRef ref) async {
    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建笔记'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: '笔记名称'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, textController.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final controller = ref.read(notesControllerProvider.notifier);
    final relPath = await controller.createNote(name);
    if (!context.mounted) return;
    final title = name.toLowerCase().endsWith('.md')
        ? name.substring(0, name.length - 3)
        : name;
    onNavigate?.call();
    await context.push(AppRouter.noteEditorPath(relPath, title));
    await controller.refresh();
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({
    required this.node,
    required this.onTap,
    required this.onToggleStar,
  });

  final NoteNode node;
  final VoidCallback onTap;
  final VoidCallback onToggleStar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              node.isDirectory ? LucideIcons.folder : LucideIcons.fileText,
              size: 18,
              color: node.isDirectory
                  ? NotesSidebarPanel._folderColor
                  : NotesSidebarPanel._fileColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                node.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (!node.isDirectory)
              InkWell(
                onTap: onToggleStar,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    LucideIcons.star,
                    size: 16,
                    color: node.isStarred
                        ? const Color(0xFFF59E0B)
                        : theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.45),
                  ),
                ),
              )
            else
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }
}
