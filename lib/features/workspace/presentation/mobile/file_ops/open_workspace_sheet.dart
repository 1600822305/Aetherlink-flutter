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
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/file_ops/ssh_connection_form_sheet.dart';

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
            // SSH is live (read-only browse, SSH-1). Termux stays a placeholder
            // until its one-tap setup lands (设计文档 §10.5 / Termux-A).
            const SizedBox(height: 4),
            Material(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                leading: Icon(
                  LucideIcons.server,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('SSH / 远程'),
                subtitle: const Text('连接远程机器，浏览其文件 (Remote-SSH)'),
                onTap: () async {
                  // Capture the navigator before popping this sheet — its own
                  // context is defunct afterwards but navigator.context stays
                  // valid for showing the form sheet.
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  await showSshConnectionFormSheet(navigator.context, parentRef);
                },
              ),
            ),
            const _ComingSoonTile(
              icon: LucideIcons.terminal,
              title: 'Termux',
              subtitle: '同机 Termux 路径，文件 + 终端',
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

/// A disabled backend entry shown with a 「敬请期待」 badge. Tapping closes the
/// sheet and surfaces a snackbar; no workspace is opened. Placeholder for the
/// not-yet-implemented Termux / SSH backends.
class _ComingSoonTile extends StatelessWidget {
  const _ComingSoonTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListTile(
      leading: Icon(icon, color: muted),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '敬请期待',
          style: theme.textTheme.labelSmall?.copyWith(color: muted),
        ),
      ),
      onTap: () {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(content: Text('$title 敬请期待')),
        );
      },
    );
  }
}
