// The middle page when files are open: an IDE-style multi-tab editor.
//
// A horizontal [FileTabStrip] sits at the top (next to the back button); below
// it an IndexedStack holds one live [FileEditor] per open tab, keyed by path so
// each keeps its own edit / scroll / zoom state while hidden. Closing a tab
// with unsaved edits prompts save/discard via the editor's registered handle.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_body.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_registry.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/file_editor.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/file_tab_strip.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/recent_files_sheet.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

class WorkspaceFileViewer extends ConsumerWidget {
  const WorkspaceFileViewer({
    super.key,
    required this.tabs,
    required this.onBack,
    required this.topInset,
  });

  final WorkspaceTabsState tabs;
  final VoidCallback onBack;
  final double topInset;

  Future<void> _close(BuildContext context, WidgetRef ref, String path) async {
    final dirty = ref.read(dirtyFilesProvider).contains(path);
    if (dirty) {
      final handle = ref.read(editorRegistryProvider)[path];
      final name = tabs.tabs
          .firstWhere((t) => t.path == path, orElse: () => tabs.tabs.first)
          .name;
      final action = await showUnsavedDialog(context, name);
      if (action == null || action == LeaveAction.cancel) return;
      if (action == LeaveAction.save) {
        if (handle == null || !await handle.save()) return;
      } else {
        handle?.discard();
      }
    }
    ref.read(openWorkspaceFilesProvider.notifier).close(path);
  }

  // 保存所有脏 tab（逐个走各自编辑器的 save 钩子，静默），结果统一 toast。
  Future<void> _saveAll(BuildContext context, WidgetRef ref) async {
    final registry = ref.read(editorRegistryProvider);
    final dirty = ref.read(dirtyFilesProvider).toList();
    var saved = 0;
    var failed = 0;
    for (final path in dirty) {
      final handle = registry[path];
      if (handle == null) continue;
      if (await handle.save(notify: false)) {
        saved++;
      } else {
        failed++;
      }
    }
    if (!context.mounted) return;
    if (failed > 0) {
      AppToast.error(context, '已保存 $saved 个文件，$failed 个失败');
    } else if (saved > 0) {
      AppToast.info(context, '已保存 $saved 个文件');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dirtyPaths = ref.watch(dirtyFilesProvider);
    final topPad = MediaQuery.paddingOf(context).top + topInset + 4;

    var activeIndex = tabs.tabs.indexWhere((t) => t.path == tabs.activePath);
    if (activeIndex < 0) activeIndex = 0;

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(top: topPad, left: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(LucideIcons.arrowLeft, size: 20),
                    onPressed: onBack,
                  ),
                  Expanded(
                    child: FileTabStrip(
                      tabs: tabs.tabs,
                      activePath: tabs.activePath,
                      dirtyPaths: dirtyPaths,
                      onSelect: (p) => ref
                          .read(openWorkspaceFilesProvider.notifier)
                          .activate(p),
                      onClose: (p) => _close(context, ref, p),
                    ),
                  ),
                  if (dirtyPaths.length > 1)
                    IconButton(
                      tooltip: '全部保存',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(LucideIcons.saveAll, size: 18),
                      onPressed: () => _saveAll(context, ref),
                    ),
                  IconButton(
                    tooltip: '最近打开',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(LucideIcons.history, size: 18),
                    onPressed: () => showRecentFilesSheet(context, ref),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: IndexedStack(
                index: activeIndex,
                sizing: StackFit.expand,
                children: [
                  for (final entry in tabs.tabs)
                    FileEditor(key: ValueKey(entry.path), entry: entry),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
