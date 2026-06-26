// 「打开文件夹」 entry, moved off the old start screen onto the file-tree header.
//
// Shows a bottom sheet with "打开本地文件夹" (real SAF picker) plus the "最近打开"
// list, and owns the open/switch logic: record the workspace in the recent
// store, reset the open tabs (a different workspace starts a fresh session) and
// set it as current. Only LocalSafBackend's neutral pickDirectory is touched —
// the plugin is never imported here (spec §1).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

/// Opens the workspace picker sheet (recent list + 「打开本地文件夹」).
Future<void> showOpenWorkspaceSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _OpenWorkspaceSheet(parentRef: ref),
  );
}

class _OpenWorkspaceSheet extends ConsumerWidget {
  const _OpenWorkspaceSheet({required this.parentRef});

  /// The page's ref — used for opening so provider writes outlive the sheet.
  final WidgetRef parentRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recent = ref.watch(workspaceStoreProvider);
    final current = ref.watch(currentWorkspaceProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                '打开文件夹',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Material(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: Icon(
                  LucideIcons.folderOpen,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('打开本地文件夹'),
                subtitle: const Text('授权手机上的一个目录 (SAF)'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await openLocalFolder(context, parentRef);
                },
              ),
            ),
            if (recent.asData?.value.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '最近打开',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final w in recent.asData!.value)
                ListTile(
                  leading: Icon(
                    LucideIcons.folder,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    w.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    w.displayPath ?? w.root,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: w.id == current?.id
                      ? Icon(
                          LucideIcons.check,
                          color: theme.colorScheme.primary,
                        )
                      : IconButton(
                          icon: const Icon(LucideIcons.x, size: 18),
                          onPressed: () => ref
                              .read(workspaceStoreProvider.notifier)
                              .remove(w.id),
                        ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await openRecent(parentRef, w);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Picks a folder via SAF, records it and opens it as the current workspace.
Future<void> openLocalFolder(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final picked = await ref.read(localSafBackendProvider).pickDirectory();
    if (picked == null) return; // 用户取消
    final workspace = await ref
        .read(workspaceStoreProvider.notifier)
        .open(
          name: picked.name,
          backendType: WorkspaceBackendType.localSaf,
          root: picked.root,
          displayPath: picked.displayPath,
        );
    _switchTo(ref, workspace);
  } on PlatformException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('打开失败 · ${e.code}: ${e.message ?? ''}')),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('打开失败 · $e')));
  }
}

/// Re-opens a "最近打开" entry as the current workspace.
Future<void> openRecent(WidgetRef ref, Workspace workspace) async {
  final stored = await ref
      .read(workspaceStoreProvider.notifier)
      .open(
        name: workspace.name,
        backendType: workspace.backendType,
        root: workspace.root,
        displayPath: workspace.displayPath,
      );
  _switchTo(ref, stored);
}

// Switching workspaces starts a fresh editor session: clear tabs first (so the
// shell stays on the tree page) then set the new current workspace.
void _switchTo(WidgetRef ref, Workspace workspace) {
  ref.read(currentWorkspaceProvider.notifier).open(workspace);
  ref.read(openWorkspaceFilesProvider.notifier).reset();
}
