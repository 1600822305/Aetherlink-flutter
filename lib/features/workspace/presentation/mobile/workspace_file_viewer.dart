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
